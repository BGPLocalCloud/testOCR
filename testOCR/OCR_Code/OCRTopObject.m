//
//  OCRTopObject.m
//  testOCR
//
//  Created by Dave Scruton on 12/22/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
//  Main OCR object. Designed to load and process one single page.
//    Document is loaded in the od object, and Templates come in
//    as arguments to applyTemplate. Together ot and od produce a set of
//    line items saved to the EXP table and also to
//    a corresponding invoice in the I_VendorName table (one table/vendor)
//  This all revolves around OCR Space, an online free OCR system.
//   At higher data rates there is a fee, need more details
//   https://ocr.space/
//
//  12/28 integrated ocr cache
//  1/27  added page arg to performOCR...
//  1/30  handle empty pages
//  1/31  last minute check for 'quest' as bad product
//  2/4  add batch month
//  2/5  redid calls to updateInvoice, added oldInvoiceNumber, to
//        handle multiple invoices per PDF file
//        add handleNextPage, now page only gets OCR'ed after previous page is saved
//  2/7 add debugMode for logging
//  2/14 add int/float quantity support
//  2/15 add setDebugMode
//  2/23 add isBatch flag to performOCROnData
//  2/28 add E: to missing invoice fields for format matching in errorVC
//  3/4  add support for debugging invoice date from UI
//  3/12 add page field to invoice
//  3/20 add multi-customer support
//  2/25 moved getTLAnchorByVendor... calls to performOCROnData from applyTemplate,
//         now done in foreground, was getting internal crash in bkgd
//  4/5/20 only save LAST page update in activity
#import "OCRTopObject.h"

@implementation OCRTopObject

static OCRTopObject *sharedInstance = nil;

//=============(OCRTopObject)=====================================================
// Get the shared instance and create it if necessary.
+ (OCRTopObject *)sharedInstance {
    if (sharedInstance == nil) {
        sharedInstance = [[super allocWithZone:NULL] init];
    }
    return sharedInstance;
}


//=============(OCRTopObject)=====================================================
-(instancetype) init
{
    if (self = [super init])
    {
        smartp      = [[smartProducts alloc] init];    // Product categorization / error checks
        od          = [[OCRDocument alloc] init];     // Document object: handles OCR searches/parsing
        rowItems    = [[NSMutableArray alloc] init]; // Invoice rows end up here
        oc          = [OCRCache sharedInstance];    // Cache: local OCR storage
        pc          = [PDFCache sharedInstance];    // Cache: local OCR storage

        it = [[invoiceTable alloc] init];     // Parse DB: invoice storage
        it.delegate = self;
        et = [[EXPTable alloc] init];   // Parse DB: EXP line item storage
        et.delegate = self;
        act = [[ActivityTable alloc] init];


        _batchMonth = @"01-JUL"; //DHS this needs to be INPUT? from DB?ß
        
        debugMode = FALSE; //DHS 2/7
    }
    return self;
}



//=============(OCRTopObject)=====================================================
// Loop over template, find stuff in document?
// DOCUMENT MUST BE LOADED!!!
// 1/30 only look for top of invoice items on page 0
- (void)applyTemplate : (OCRTemplate *)ot : (int) page
{
    [ot clearHeaders];
    //Get invoice top left / top right limits from document, will be using
    // these to scale invoice by:
    CGRect tlTemplate = [ot getTLOriginalRect];
    CGRect trTemplate = [ot getTROriginalRect];
    //2/25/20 OUCH! oappDelegate should NOT be called from here, it looks like we are
    //  in the background when this happens.  The TLAnchor and TRAnchor should be set
    //  somewhere in the foreground, OR this object should have these two NSStrings
    //  set ahead of time from the foreground!
    // The items in question are in VendorObject: vTLTemplate and vTRTemplate
    // 2/25 moved to performOCROnData....
    // 2/25 AppDelegate *oappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    // 2/25 od.TLAnchor = [oappDelegate.vv getTLAnchorByVendor:_vendor]; //DHS 3/6 new for scaling
    // 2/25 od.TRAnchor = [oappDelegate.vv getTRAnchorByVendor:_vendor];
    [od computeScaling : tlTemplate : trTemplate];
    if (debugMode) NSLog(@"applyTemplate...");
    if (page == 0) //DHS 1/31 ONLY clear on first page!
    {
        _invoiceNumber       = 0L;
        _invoiceDate         = [NSDate date]; //DHS 3/6 clear to non-nils
        _invoiceCustomer     = @"";
        _invoiceVendor       = @"";
        _invoiceNumberString = @"";
        headerY = 0; //DHS 3/4
    }

    //First add any boxes of content to ignore...
    for (int i=0;i<[ot getBoxCount];i++) //Loop over our boxes...
    {
        NSString* fieldName = [ot getBoxFieldName:i];
        if ([fieldName isEqualToString:INVOICE_IGNORE_FIELD])
        {
            CGRect rr = [ot getBoxRect:i]; //In document coords!
            [od addIgnoreBoxItems:rr];
        }
    }
    int columnDataTop = 0;
    for (int i=0;i<[ot getBoxCount];i++) //Loop over our boxes...
    {
        //OK, let's go and get the field name to figure out what to do w data...
        NSString* fieldName = [ot getBoxFieldName:i];
        CGRect rr = [ot getBoxRect:i]; //In document coords!
        NSMutableArray *a = [od findAllWordsInTemplateRect:rr];
        if (debugMode) NSLog(@" [%@] fieldname is [%@], %d items docrect %@",
                             _imageFileName,fieldName,(int)a.count,NSStringFromCGRect([od template2DocRect:rr]));
        if (a.count > 0) //Found a match!
        {
            //DHS 2/5 look for invoice number / date EVERY PAGE
            if ( [fieldName isEqualToString:INVOICE_NUMBER_FIELD]) //Looking for a number?
            {
                if (debugMode) [od dumpArrayFull:a]; //DHS 8/11
                if ([debugString isEqualToString:@"number"])      //Debug? Convert our array to a bunch of strings...
                    [self displayDebugPrompt : debugString : a]; // and output it in a prompt
                long testNum = [od findLongInArrayOfFields:a];
                if (testNum != 0)
                {
                    _invoiceNumber = testNum;
                    //This will have to be more robust
                    _invoiceNumberString = [NSString stringWithFormat:@"%ld",_invoiceNumber];
                }
                else
                {
                    if (page == 0) _invoiceNumberString = @"ERRMISSING"; //2/28 ONLY flag error on page 1
                }
                if (debugMode)
                {
                    NSLog(@" invoice# %ld [%@]",_invoiceNumber,_invoiceNumberString);
                    [od dumpArrayFull:a];
                }
            }
            else if ( [fieldName isEqualToString:INVOICE_DATE_FIELD]) //Looking for a date?
            {
                //[od dumpArrayFull:a];
                if ([debugString isEqualToString:@"date"])      //Debug? Convert our array to a bunch of strings...
                    [self displayDebugPrompt : debugString : a]; // and output it in a prompt
                NSDate* testDate = [od findDateInArrayOfFields:a]; //Find date-like string?
                if (testDate == nil) //Bogus?  1/27 redid
                {
                    [self->_delegate errorPerformingOCR:@"E:Missing Invoice Date"];
                    if (page == 0) _invoiceDate = [NSDate date]; //1st page? Nothing to go on, use current date
                }
                else _invoiceDate = testDate;
                if (debugMode) NSLog(@" invoice date %@",_invoiceDate);
            }
            else if (page == 0 && [fieldName isEqualToString:INVOICE_CUSTOMER_FIELD]) //Looking for Customer?
            {
                if ([debugString isEqualToString:@"customer"])      //Debug? Convert our array to a bunch of strings...
                    [self displayDebugPrompt : debugString : a]; // and output it in a prompt
                _invoiceCustomer = [od findTopStringInArrayOfFields:a]; //Just get first line of template area
                if (debugMode) NSLog(@" Customer %@",_invoiceCustomer);
                if (_invoiceCustomer == nil) //DHS 2/22
                {
                    [self->_delegate errorPerformingOCR:@"E:Missing Invoice Customer"];
                    _invoiceCustomer = @"ERRMISSING";
                }
            }
            else if (page == 0 && [fieldName isEqualToString:INVOICE_SUPPLIER_FIELD]) //Looking for Supplier?
            {
                if ([debugString isEqualToString:@"supplier"])      //Debug? Convert our array to a bunch of strings...
                    [self displayDebugPrompt : debugString : a]; // and output it in a prompt
                _invoiceVendor = [od findTopStringInArrayOfFields:a]; //Just get first line of template area
                BOOL matches = [ot isSupplierAMatch:_invoiceVendor]; //Check for rough match
                if (debugMode) NSLog(@" Supplier %@, match %d",_invoiceVendor,matches);
                if (_invoiceVendor == nil) //DHS 2/22
                {
                    [self->_delegate errorPerformingOCR:@"E:Missing Invoice Supplier/Vendor"];
                    _invoiceVendor = @"ERRMISSING";
                }
            }
            else if ([fieldName isEqualToString:INVOICE_HEADER_FIELD]) //Header is SPECIAL!
            {
                //headerY = [od autoFindHeader];
                // Get header ypos (document coords!!)
                int testHeaderY = [od findHeader:rr :300]; //1/30 changed expandby to 300
                if (testHeaderY == -1)  //Missing header? will use 1st page headerY 
                {
                    [self->_delegate errorPerformingOCR:@"E:Missing Invoice Header"];
                    if (page == 0) return; //Wups! first page? Bail!
                }
                else headerY = testHeaderY;  //DHS 3/4
//              DHS 3/6 the 1.5 factor was too much for Hawaii Beef Producers!
                // THIS MAY have to vary by vendor!
//                columnDataTop = [od doc2templateY:headerY] + 1.5*od.glyphHeight;
                columnDataTop = [od doc2templateY:headerY] + 1.0*od.glyphHeight; // 3/7
                headerY -= 10;  //littie jiggle up...
                rr.origin.y = [od doc2templateY:headerY];  //Adjust our header rect to new header position!
                a = [od findAllWordsInTemplateRect:rr]; //Do another search now...
                headerRect = rr; //Save our header rect for later...
                _columnHeaders = [od getHeaderNames];
            }
            //1/31 Invoice total: only look at last page!
            else if ([fieldName isEqualToString:INVOICE_TOTAL_FIELD])
            {
                //[od dumpArrayFull:a];
                _invoiceTotal = [od findPriceInArrayOfFields:a];
                if (debugMode) NSLog(@" invoice Total %4.2f [%@]",_invoiceTotal,[NSString stringWithFormat:@"%4.2f",_invoiceTotal]);
            }
            
        } //end if a.count
        if ([fieldName isEqualToString:INVOICE_COLUMN_FIELD] ||
            [fieldName isEqualToString:INVOICE_COLUMN_ITEM_FIELD] ||
            [fieldName isEqualToString:INVOICE_COLUMN_DESCRIPTION_FIELD] ||
            [fieldName isEqualToString:INVOICE_COLUMN_QUANTITY_FIELD] ||
            [fieldName isEqualToString:INVOICE_COLUMN_PRICE_FIELD] ||
            [fieldName isEqualToString:INVOICE_COLUMN_AMOUNT_FIELD]
            ) //Columns: some are tagged by type, others assume I/Q/D/P/A distribution
        {
            if (debugMode) NSLog(@" column found==================");
            if (debugMode) [od dumpArrayFull:a];
            [ot addHeaderColumnToSortedArray : i : fieldName : headerY + od.glyphHeight];
        }
    }

    //Only now do we have enough info to figure out the header titles...
    NSMutableArray* colz = [[NSMutableArray alloc] init];
    for (int i=0;i<[ot getColumnCount];i++)
    {
        CGRect rc = [ot getColumnRect : i];
        NSValue *rectObj = [NSValue valueWithCGRect:rc];
        [colz addObject:rectObj];
    }
    [od parseHeaderColumns : colz : headerRect];

    //We can only do columns after they are all loaded
    [od clearAllColumnStringData];
    //Figure out where the rows actually are...
    [od  computeRowYpositions : [ot getColumnCount] :
                                [ot getColumnByIndex:od.priceColumn] :
                                [ot getColumnByIndex:od.amountColumn]];


    // Get columns,use Y positions above to find each row...
    for (int i=0;i<[ot getColumnCount];i++)
    {
        CGRect rr = [ot getColumnByIndex:i];
        rr.origin.y = columnDataTop; //Adjust Y according to found header!
        NSMutableArray *stringArray;
        stringArray = [od getColumnStrings : rr : i : [ot getColumnType:i]];
        
        NSMutableArray *cleanedUpArray = [od cleanUpRawColumns : i : [ot getColumnType:i] : stringArray ];
        [od addColumnStringData:cleanedUpArray];
        if (debugMode)
            NSLog(@" col[%d] cleanup %@ -> %@",i,stringArray,cleanedUpArray);
    }
    
    //Now, columns are ready: let's dig them out!
    if (od.longestColumn < 2) //Must be an error? Not enough rows!
    {
        [self->_delegate errorPerformingOCR:@"E:Missing Invoice Rows"];
        return;
    }

    [rowItems removeAllObjects];
    for (int i=0;i<od.longestColumn;i++)
    {
        NSMutableArray *ac = [od getRowFromColumnStringData : i];
        [rowItems addObject:[ac componentsJoinedByString:@","]]; //DHS 2/5 simplify
    }
} //end applyTemplate

//=============(OCRTopObject)=====================================================
-(void) displayDebugPrompt : (NSString*)fieldName : (NSArray *)a
{
    NSMutableArray *wa = [od  getArrayOfIndicesAsStrings : a];
    [self debugOutputPrompt : debugParent : [NSString stringWithFormat:@"Invoice %@",fieldName] :
                [wa componentsJoinedByString:@"\n"]];
}

//=============(OCRTopObject)=====================================================
// passes buck down to exptable. unique record count throughout batch
-(void) clearEXPBatchCounter
{
    [et clearBatchCounter];
}

//=============(OCRTopObject)=====================================================
// Used to dump debug info to window
-(void) debugOutputPrompt : (UIViewController*) p : (NSString *) dtitle : (NSString*) msg
{
    //2/25 This may be called on a bkgd thread!
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:dtitle
                                                                       message:msg
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *yesAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK",nil)
                                                            style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                            }];
        //DHS 3/13: Add owner's ability to delete puzzle
        [alert addAction:yesAction];
        [p presentViewController:alert animated:YES completion:nil];
    });
} //end debugOutputPrompt


//=============(OCRTopObject)=====================================================
// Retreives data from a column in the array w/ limit checking.
-(NSString *)getLineItem : (int) index  : (int) licount : (NSArray *)a
{
    NSString *result = @"EMPTY";
    if (index >= licount) NSLog(@" ...ERROR:get lineitem %d past end!",index);
    result  = a[index];
    return result;
} //end getLineItem



//=============(OCRTopObject)=====================================================
// DocParser hands  back a CSV file after eating invoices.  This breaks it into
//  lineitems after determining which fields are present (THIS WILL VARY BY VENDOR)
// Just eats canned file now...spits result out to EXP table, no invoice yet
//  Is there a way to get page# from docParser?
//  https://www.labnol.org/software/upload-dropbox-files-by-email/18526/
// Need to hook this up to dropbox delegate return after [dbt downloadCSV:whatever];
-(void) loadCSVFileFromDocParser : (NSString *)fname : (NSString *)vendor
{
    NSError *error;
    NSString *path = [[NSBundle mainBundle] pathForResource:fname ofType:@"csv" inDirectory:@"txt"];
    NSURL *url = [NSURL fileURLWithPath:path];
    NSString *fileContentsAscii = [NSString stringWithContentsOfURL:url encoding:NSASCIIStringEncoding error:&error];
    if (error != nil)
    {
        NSLog(@" ERROR reading CSV file %@",fname);
        return;
    }
    [self loadCSVValuesFromString: vendor :fileContentsAscii];

} //end loadCSVFileFromDocParser



//=============(OCRTopObject)=====================================================
// DocParser hands  back a CSV file after eating invoices.  This breaks it into
//  lineitems after determining which fields are present (THIS WILL VARY BY VENDOR)
// Just eats canned file now...spits result out to EXP table, no invoice yet
//  Is there a way to get page# from docParser?
//  https://www.labnol.org/software/upload-dropbox-files-by-email/18526/
// Need to hook this up to dropbox delegate return after [dbt downloadCSV:whatever];
-(void) loadCSVValuesFromString : (NSString *)avendor : (NSString *)s
{
    NSArray *sItems;
    
    if (debugMode) NSLog(@" loadCSVFromString, vendor:%@",avendor);
    _invoiceNumberString = @"stubbedInvoiceNumber";
    _invoiceCustomer     = @"stubbedCustomer";
    pagesReturned = 0; //What should this be??
    _vendor = avendor; //For invoice save...
    smartProducts *smartp = [[smartProducts alloc] init];
    sItems    = [s componentsSeparatedByString:@"\n"];
    
    int filenameColumn  = -1;
    int dateColumn      = -1;
    int lineItemsColumn = -1;
    
    BOOL firstRecord = TRUE;

    smartCount  = 0;
    [et clear]; //Set up EXP for new entries...
    
    for (NSString*s in sItems)
    {
        NSArray* lineItems = [s componentsSeparatedByString:@";"];
        int lccount        = (int) lineItems.count;
        if (lccount >= 4)
        {
            if (firstRecord) //Get titles for fields...
            {
                int column = 0;
                for (NSString *headerDescr in lineItems)
                {
                    if ([headerDescr.lowercaseString containsString:@"filename"] && filenameColumn == -1)
                        filenameColumn = column;
                    else if ([headerDescr.lowercaseString containsString:@"date"] && dateColumn == -1)
                        dateColumn = column;
                    else if ([headerDescr.lowercaseString containsString:@"line items"] && lineItemsColumn == -1)
                        lineItemsColumn = column;
                    column++;
                }
                //NSLog(@" fnc %d dc %d lic %d",filenameColumn,dateColumn,lineItemsColumn);
                firstRecord = FALSE;
            }
            else //Process CSV... (assume line items are Quantity , Price, Amount
            {
                NSString *liFname       = lineItems[filenameColumn];
                NSString *liLineNumber  = @"";
                NSString *liItem        = @"";
                NSString *liQtyOrdered  = @"";
                NSString *liQtyShipped  = @"";
                NSString *liUOM         = @"";
                NSString *liDescription = @"";
                NSString *liUnits       = @"";
                NSString *liPrice       = @"";
                NSString *liAmount      = @"";
                NSString *dateStr = @"";
                //NOTE: filename should include vendor name, there is no other way to ID!!!
                if ([avendor.lowercaseString isEqualToString:@"greco"]) //Greco Vendor is all we have now...
                {
                    //"Document ID";"Remote ID";Filename;"Received At";"Processed At";"Invoice Date Match";"Invoice Date Iso8601";"Totals Net";"Totals Tax";"Totals Total";"Totals Carriage";"Totals Confidence";"Line Items";"Line Items 1";"Line Items 2";"Line Items 3";"Line Items 4";"Line Items 5";"Line Items 6";"Line Items 7";"Line Items 8"
                    if (dateColumn < lccount) dateStr = lineItems[dateColumn];
                    int i = lineItemsColumn;
                    liLineNumber  = [self getLineItem:i++ :lccount :lineItems];
                    liItem        = [self getLineItem:i++ :lccount :lineItems];
                    liQtyOrdered  = [self getLineItem:i++ :lccount :lineItems];
                    liQtyShipped  = [self getLineItem:i++ :lccount :lineItems];
                    liUOM         = [self getLineItem:i++ :lccount :lineItems];
                    liDescription = [self getLineItem:i++ :lccount :lineItems];
                    liUnits       = [self getLineItem:i++ :lccount :lineItems];
                    liPrice       = [self getLineItem:i++ :lccount :lineItems];
                    liAmount      = [self getLineItem:i++ :lccount :lineItems];
                    
                    //Convert date...
                    NSString *dformat   = @"MM/dd/yy";
                    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                    [dateFormatter setDateFormat:dformat];
                    NSDate *liDate = [dateFormatter dateFromString:dateStr];
                    _invoiceDate = liDate; //This the right place?
                    [smartp clear];
                    smartp.intQuantity = _intQuantity; //DHS 3/24 was missing!
                    [smartp addVendor:avendor]; //Is this the right string?
                    [smartp addProductName:liDescription];
                    [smartp addDate:liDate];
                    [smartp addLineNumber:liItem.intValue];
                    [smartp addQuantity : liUnits];  //This seems to be the quantity paid for, NOT quantity shipped
                    [smartp addUOM:liUOM]; //This overrides internal UOM matching
                    [smartp addPrice: liPrice];
                    [smartp addAmount: liAmount];
                    int aError = [smartp analyze];
                    if (aError != 0)
                    {
                        NSLog(@" error analyzing %@",liDescription);
                    }
                    else if (smartp.minorError != 0)
                    {
                        NSLog(@" minor error %@",[smartp getMinorErrorString]);
                    }
                    else if (smartp.majorError != 0)
                    {
                        NSLog(@" major error %@",[smartp getMajorErrorString]);
                    }
                    
                    if (aError == 0) //Only save valid stuff!
                    {
                        NSString *errStatus = @"OK";
                        if (smartp.majorError != 0) //Major error trumps minor one...
                            errStatus = [NSString stringWithFormat:@"E:%@",[smartp getMajorErrorString]];
                        else if (smartp.minorError != 0) //Minor error? encode!
                            errStatus = [NSString stringWithFormat:@"W:%@",[smartp getMinorErrorString]];
                        smartCount++;
                        //Format line count to triple digits, max 999
                        NSString *lineString = [NSString stringWithFormat:@"%3.3d",(_totalLines + smartCount)];
                        //CSV: Tons of args: adds allll this shit to the next EXP table entry for saving to parse...
                        //vendor invoice# pdffile batch all nil!
                        [et addRecord:smartp.invoiceDate : smartp.analyzedCategory : _batchMonth :
                              liItem : smartp.analyzedUOM : smartp.analyzedBulkOrIndividual :
                              avendor : smartp.analyzedProductName : smartp.analyzedProcessed :
                              smartp.analyzedLocal : lineString : @"docparser" :
                              smartp.analyzedQuantity : smartp.analyzedPrice : smartp.analyzedAmount :
                            _batchID : errStatus : liFname : [NSNumber numberWithInt:0]  ]; //last arg is page..??
                    } //end analyzeOK
                    
                } //end greco
                
            } //end !firstrecord
            firstRecord = FALSE;
        } //end lccount > 4
    } //end for strings in file
    if (smartCount > 0) //Read in some lines OK? Ssave'em
    {
        if (debugMode) NSLog(@" save CSV to EXP table, PAGE STUBBED!!!");
        [et saveToParse : 0 : TRUE]; //page count 0 based, # pages
        _totalLines += smartCount;
    }
    return;
} //end loadCSVValuesFromString



//=============(OCRTopObject)=====================================================
-(NSString *) getParsedText
{
    return parsedText;
}


//=============(OCRTopObject)=====================================================
-(NSString *) getRawResult
{
    return rawOCRResult;
}

//=============(OCRTopObject)=====================================================
-(NSString*) getStrippedFilename : (NSString*) fname
{
    NSString* sfname = fname;
    NSArray *fItems    = [fname componentsSeparatedByString:@"/"];
    if (fItems.count > 1) //divided name w/ folders? just get last bit...
        sfname = fItems[fItems.count-1];
    return sfname;
} //end getStrippedFilename


//=============(OCRTopObject)=====================================================
// Sends a JPG to the OCR server, and receives JSON text data back...
- (void)performOCROnImage : (NSString *)fname : (UIImage *)imageToOCR
{
    // Image file and parameters, use hi compression quality?
    NSData *imageData = UIImagePNGRepresentation(imageToOCR);
    CGRect r = CGRectMake(0, 0, imageToOCR.size.width, imageToOCR.size.height);
    _imageFileName = fname;
    [self performOCROnData: fname : imageData : r : FALSE];
} //end performOCROnImage

//=============(OCRTopObject)=====================================================
// Sends a JPG to the OCR server, and receives JSON text data back...
//  OCR handles multiple pages from PDF data!
- (void)performOCROnData : (NSString *)fname : (NSData *)imageDataToOCR : (CGRect) r : (BOOL) isBatch
{
    //4/5 moved here from down below
    AppDelegate *oappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [et setTableNameForCurrentCustomer : oappDelegate.selectedCustomer];

    //First, check cache: may already have downloaded OCR raw txt for this file...
    if ([oc txtExistsByID:fname])
    {
        //if (debugMode)
            NSLog(@" OCR Cache HIT: %@",fname);
        [self.delegate batchUpdate : [NSString stringWithFormat:@"OCR Cache HIT:%@",fname]];
        rawOCRResult  = [oc getTxtByID:fname];  //Raw OCR'ed text, needs to goto JSON
        r             = [oc getRectByID:fname]; //Get cached image size too...
        NSData *jsonData = [rawOCRResult dataUsingEncoding:NSUTF8StringEncoding];
        NSError *e;
        OCRJSONResult = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingMutableContainers error:&e];
        if (e != nil) NSLog(@" ....json err? %@",e.localizedDescription);
        [self performFinalOCROnDocument : r : isBatch]; //This calls delegate when done
        return; //Bail!
    }
    else NSLog(@" OCR Cache MISS! %@",fname);
    // Create URL request (this is the :free: ocr server
//    NSURL *url = [NSURL URLWithString:@"https://api.ocr.space/Parse/Image"];
    // This is the PAID server (pro plan)
    NSURL *url = [NSURL URLWithString:@"https://apipro1.ocr.space/parse/image"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    NSString *boundary = @"randomString";
    [request addValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField:@"Content-Type"];
    
    NSURLSession *session = [NSURLSession sharedSession];
    
    NSDictionary *parametersDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                          //@"99bb6b410288957", @"apikey",  // :free: key
                                          @"PDMXB3665888A", @"apikey",    // :paid: key (pro plan)
                                          @"True", @"isOverlayRequired",
                                          @"True", @"isTable",
                                          @"True", @"scale",
                                          @"True", @"detectOrientation",
                                          @"eng", @"language", nil];
    
    // Create multipart form body
    //NOTE We could be passing PDF directly here, just using the NSData alone!
    //  the OCR handles raw PDF data too!!!
    NSData *data = [self createBodyWithBoundary:boundary
                                     parameters:parametersDictionary
                                      imageData:imageDataToOCR
                                       filename:_imageFileName ];  //@"dog.jpg"]; ///imageName];
    if (debugMode) NSLog(@" send OCR request... %@",_imageFileName);
    [self.delegate batchUpdate : [NSString stringWithFormat:@"OCR:%@",
                                 [self getStrippedFilename : _imageFileName]]];

    [request setHTTPBody:data];
    
    //2/25 need to get TL/TR anchors here, was attempting to get them from background process
    od.TLAnchor = [oappDelegate.vv getTLAnchorByVendor:_vendor];
    od.TRAnchor = [oappDelegate.vv getTRAnchorByVendor:_vendor];

    // Start data session
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSError* myError;
        if (self->debugMode) NSLog(@" ...OCR response from server, err %@",error);
        if (error != nil) //Task came back w/ error?
        {
            NSNumber* exitCode     = [self->OCRJSONResult valueForKey:@"OCRExitCode"];
            NSString* errDesc;
            switch(exitCode.intValue)
            {
                case 2: errDesc = @"OCR only parsed partially";break;
                case 3: errDesc = @"OCR failed to parse image";break;
                case 4: errDesc = @"OCR internal error";break;
            }
            if (errDesc == nil)errDesc = error.localizedDescription;
            //DHS 1/28 fail OCR!
            [self->_delegate fatalErrorPerformingOCR:[NSString stringWithFormat:@"%@ %@",errDesc,self->_imageFileName]];
            //DHS 2/22 lots of objects use this now
            [[NSNotificationCenter defaultCenter] postNotificationName:@"errorPerformingOCRNotification" object:errDesc userInfo:nil];
        }
        else
        {
            self->rawOCRResult = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            self->OCRJSONResult = [NSJSONSerialization JSONObjectWithData:data
                                                                  options:kNilOptions
                                                                    error:&myError];
            // Handle result: load up document and apply template here
            //OUCH! need to look for the IsErroredOnProcessing item here, and  ErrorMessage!
            //  bad files set this and then have bogus data which crashes OCR below!
            NSNumber *isErr = [self->OCRJSONResult valueForKey:@"IsErroredOnProcessing"];
            NSArray* ea = [self->OCRJSONResult valueForKey:@"ErrorMessage"];
            NSString* errMsg = ea[0];
            if (self->OCRJSONResult == nil) //DHS 3/4 WEIRD ERROR
            {
                errMsg = self->rawOCRResult; //Assume OCR has some info?
                [self->_delegate fatalErrorPerformingOCR:[NSString stringWithFormat:@"%@ %@",errMsg,self->_imageFileName]];
                //DHS 2/22 lots of objects use this now
                [[NSNotificationCenter defaultCenter] postNotificationName:@"errorPerformingOCRNotification" object:errMsg userInfo:nil];
            }
            else if (isErr.boolValue)
            {
                //1/27 pass fname AND error back...
                [self->_delegate fatalErrorPerformingOCR:[NSString stringWithFormat:@"%@ %@",errMsg,self->_imageFileName]];
                //DHS 2/22 lots of objects use this now
                [[NSNotificationCenter defaultCenter] postNotificationName:@"errorPerformingOCRNotification" object:errMsg userInfo:nil];
            }
            else //Success!
            {
                //1/19 don't save to cache unless there are NO ERRORS
                [self->oc addOCRTxtWithRect:fname :r:self->rawOCRResult];
                if (self->debugMode)
                    NSLog(@"  OCR result is %@",self->OCRJSONResult);
                [self performFinalOCROnDocument : r : isBatch]; //This calls delegate when done
            }
        }
    }];
    [task resume];
} //end performOCROnData

//=============(OCRTopObject)=====================================================
// JSON result may be from OCR server return OR from cache hit. needs template.
//  informs delegate when done... called by performOCROnData
// NOTE: document may have multiple pages!
-(void) performFinalOCROnDocument : (CGRect) r : (BOOL) isBatch
{
    if (!isBatch || _ot != nil) //Template needs to be applied? 2/23 change
    {
        if (debugMode) NSLog(@" ...Process OCR data...");
        pagesReturned = 0;
        // This eats up the json and creates a set of OCR boxes, in
        //  an array: one set per page...
        [od setupDocumentWithRectAndParseJSON : r : OCRJSONResult ];
        pageCount = od.numPages; //OK! now we know how many pages we have
        _totalLines = 0; //Overall line count...
        currentPage = 0; //asdf
        //DHS 2/22 lots of objects use this now
        [[NSNotificationCenter defaultCenter] postNotificationName:@"didPerformOCR" object:od userInfo:nil];
        if (isBatch) [self handleNextPage : FALSE];
    }
} //end performFinalOCR...

//=============(OCRTopObject)=====================================================
-(void) handleNextPage : (BOOL) increment
{
    if (increment) currentPage++;
    if (currentPage >= pageCount)
    {
        [self->_delegate didSaveOCRDataToParse:_invoiceNumberString];
        return;
    }
    
#ifdef TEST_SKEW
    NSLog(@" TEST SKEW ANGLES %@",_imageFileName);
    imageTools *it = [[imageTools alloc] init];
    UIImage *ii = [pc getImageByID : _imageFileName : currentPage+1];
    //OUCH! for HFM we need a page rotate of 90 degrees!
    if (ii != nil)
    {
        if ([_vendor.lowercaseString isEqualToString:@"hfm"])
            ii = [it imageRotatedByRadians:(CGFloat)(-M_PI/2) img:ii];
        double a = [it getSkewAngle:ii];
        NSLog(@" image page %d skew %f",currentPage+1,a);
    }
#endif

    
    if (debugMode)
        NSLog(@" handleNextPage.... %d/%d",currentPage,pageCount);
    //Hand progress up to parent for UI update...
    [self.delegate batchUpdate : [NSString stringWithFormat:@"...Page %d/%d -> OCR",currentPage+1,od.numPages]];
    [od setupPage:currentPage];
    [self applyTemplate : _ot : currentPage];   //Does OCR analysis
    if (od.longestColumn != 0) //1/30 NOT Empty Page??
        [self writeEXPToParse : currentPage];      // asdf Saves all EXP rows, then invoice as well
    else // 1/30 Empty Page? Tell delegate to continue...
    {
        if (debugMode) NSLog(@" empty page %d/%d, jump to next page/document",currentPage,pageCount);
        if (currentPage+1 == od.numPages)
            [self->_delegate didSaveOCRDataToParse:_invoiceNumberString];  // -> BatchObject (bbb)
        else{
            [self handleNextPage : TRUE];
        }
    }
} //end handleNextPage

//=============(OCRTopObject)=====================================================
- (void) readCSVThenSaveToDropbox
{
    [et readFullTableToCSV : 0 : TRUE : _batchID]; //delegate callback handles rest
}


//=============(OCRTopObject)=====================================================
-(void) setDebugMode : (BOOL) mode
{
    debugMode = mode;
    [od setDebugMode : mode]; //pass it down
}


//=============(OCRTopObject)=====================================================
// 2/13 send debug display info down to children..
-(void) setVisualDebug  : (UIViewController*) p : (NSString*)dbs
{
    debugString = dbs.lowercaseString;  //3/4
    debugParent = p;
    [od setVisualDebug : p : dbs];
}


//=============(OCRTopObject)=====================================================
-(void) stubbedOCR: (NSString*)imageName : (UIImage *)imageToOCR : (OCRTemplate *)ot
{
    NSString * stubbedDocName = @"lilbeef";
    _imageFileName = imageName; //selectFnameForTemplate;
    OCRJSONResult = [self readTxtToJSON:stubbedDocName];
    [self setupTestDocumentJSON:OCRJSONResult];
    CGRect r = CGRectMake(0, 0, imageToOCR.size.width, imageToOCR.size.height);
    [od setupDocumentWithRectAndParseJSON : r : OCRJSONResult ];
    [self applyTemplate:ot : 1];
    [self writeEXPToParse : 0];

}


//=============(OCRTopObject)=====================================================
// for testing only
-(NSDictionary*) readTxtToJSON : (NSString *) fname
{
    NSError *error;
    NSArray *sItems;
    NSString *fileContentsAscii;
    NSString *path = [[NSBundle mainBundle] pathForResource:fname ofType:@"txt" inDirectory:@"txt"];
    //NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *url = [NSURL fileURLWithPath:path];
    fileContentsAscii = [NSString stringWithContentsOfURL:url encoding:NSASCIIStringEncoding error:&error];
    sItems    = [fileContentsAscii componentsSeparatedByString:@"\n"];
    NSData *jsonData = [fileContentsAscii dataUsingEncoding:NSUTF8StringEncoding];
    NSError *e;
    NSDictionary *jdict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                          options:NSJSONReadingMutableContainers error:&e];
    if (e != nil) NSLog(@" Error: %@",e.localizedDescription);
    return jdict;
}

//=============(OCRTopObject)=====================================================
- (NSData *) createBodyWithBoundary:(NSString *)boundary parameters:(NSDictionary *)parameters imageData:(NSData*)data filename:(NSString *)filename
{
    NSMutableData *body = [NSMutableData data];
    
    if (data) {
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", @"file", filename] dataUsingEncoding:NSUTF8StringEncoding]];
        //DHS TEST FOR PDF DATA ONLY
        [body appendData:[@"Content-Type: image/pdf\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
//        [body appendData:[@"Content-Type: image/jpeg\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:data];
        [body appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    for (id key in parameters.allKeys) {
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"%@\r\n", parameters[key]] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    return body;
}

//=============(OCRTopObject)=====================================================
-(void) setupTestDocumentJSON : (NSDictionary *) json
{
    OCRJSONResult = json;
}

//=============(OCRTopObject)=====================================================
// Just a handoff to outer objects that don't have the json result...
-(void) setupDocumentFrameAndParseJSON : (CGRect) r
{
    if (debugMode) NSLog(@" setupDocumentFrameAndParseJSON...");
    [od setupDocumentWithRectAndParseJSON : r : OCRJSONResult ];
}


//=============(OCRTopObject)=====================================================
// DOES FULL CLEANUP AND saves to EXP...
// Assumes invoice prices are in cleaned-up post OCR area...
//  also smartCount must be set!
-(void) writeEXPToParse : (int) page
{
    smartCount  = 0;
    //Set up EXP for new entries...
    [et clear];
   //3/4 REDUNDANT? [et setTableNameForCurrentCustomer]; //3/13/20 need to make sure table OK, best place here?
    if (debugMode) NSLog(@"  save EXP->Parse");
    AppDelegate *oappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    NSString * tableName = [NSString stringWithFormat:@"EXP_%@",oappDelegate.selectedCustomer];

    [self.delegate batchUpdate : [NSString stringWithFormat:@"Save Records to %@...",tableName]];
    for (int i=0;i<od.longestColumn;i++) //OK this does multiple parse saves at once!
    {
        NSMutableArray *ac = [od getRowFromColumnStringData : i];
        if (ac.count < 5)
        {
            NSLog(@" ERROR:bad row pulled in EXP save!");
            return;
        }
        //item,description ... Note: these columns are determined at runtime!
        //NSString *item        = ac[od.itemColumn];
        NSString *productName = ac[od.descriptionColumn];  
        [smartp clear];
        smartp.intQuantity = _intQuantity; //DHS 3/24 was missing!
        [smartp addVendor:_vendor]; //Is this the right string?
        [smartp addProductName:productName];
        [smartp addDate:_invoiceDate];
        [smartp addLineNumber:i+1];
        [smartp addVendor:_vendor]; //Is this the right string?
        //Quantity,Price,Amount ... Note: these columns are determined at runtime!
        [smartp addPrice: ac[od.priceColumn]];
        [smartp addAmount: ac[od.amountColumn]];
        [smartp addQuantity : ac[od.quantityColumn]];
        int aError = [smartp analyze]; //fills out fields -> smartp.analyzed...
        if (debugMode)
            NSLog(@" analyze err:%d [%@]->%@",aError,productName, smartp.analyzedProductName);
        if (aError == 0) //Only save valid stuff!
        {
            NSString *errStatus = @"OK";
            //NSLog(@" majorerror %d minor %d",smartp.majorError,smartp.minorError);
            if (smartp.majorError != 0) //Major error trumps minor one...
                errStatus = [NSString stringWithFormat:@"E:%@",[smartp getMajorErrorString]];
            else if (smartp.minorError != 0) //Minor error? encode!
                errStatus = [NSString stringWithFormat:@"W:%@",[smartp getMinorErrorString]];
            smartCount++;
            //NSLog(@"[%d]>>>>>>>>>>>> item %@ status %@ ",smartCount,productName,errStatus);
            //Format line count to triple digits, max 999
            NSString *lineString = [NSString stringWithFormat:@"%3.3d",(_totalLines + smartCount)];
            //OCR: Tons of args: adds allll this shit to the next EXP table entry for saving to parse...
            [et addRecord:smartp.invoiceDate : smartp.analyzedCategory : _batchMonth :
             ac[od.itemColumn] : smartp.analyzedUOM : smartp.analyzedBulkOrIndividual :
             _vendor : smartp.analyzedProductName : smartp.analyzedProcessed :
             smartp.analyzedLocal : lineString : _invoiceNumberString :
             smartp.analyzedQuantity : smartp.analyzedPrice : smartp.analyzedAmount :
             _batchID : errStatus : _imageFileName : [NSNumber numberWithInt:page]  ];
        } //end analyzeOK
        else //Bad product ID? Report error
        {
            if (!smartp.nonProduct) //Ignore non-products (charges, etc) else report error
            {
                int skipRecord = FALSE;
                //1/31 Last minute check, look for crap like partial lines from other fields...
                if ([productName.lowercaseString containsString:@"quest"]) skipRecord = TRUE;
                if (!skipRecord && productName.length > 5) // Ignore short nonsense fields!
                {
                    NSString *s = [NSString stringWithFormat:@"E:Bad Product Name (%@)", //3/31 redo
                                   productName];
                    NSLog(@"%@",s); //4/6 DEBUG REMOVE
                    [self->_delegate errorInEXPRecord:s:@"n/a":productName];
                }
            }
        }
    } //end for loop
    BOOL lastPageToDo = (page == pageCount-1);
    [et saveToParse : page : lastPageToDo];
    _totalLines += smartCount;
} //end writeEXPToParse


//=============(OCRTopObject)=====================================================
-(NSString *) dumpResults
{
    NSString *r = @"Invoice Parsed Results\n";
    r = [r stringByAppendingString:
         [NSString stringWithFormat:@"Supplier %@\n",_vendor]];
    r = [r stringByAppendingString:
         [NSString stringWithFormat: @"Number %ld  Date %@\n",_invoiceNumber,_invoiceDate]];
    r = [r stringByAppendingString:
         [NSString stringWithFormat:@"Customer %@  Total %f\n",_invoiceCustomer,_invoiceTotal]];
    r = [r stringByAppendingString:
         [NSString stringWithFormat:@"Columns:%@\n",_columnHeaders]];
    r = [r stringByAppendingString:@"Invoice Rows:\n"];
    for (NSString *rowi in rowItems)
    {
        r = [r stringByAppendingString:[NSString stringWithFormat:@"[%@]\n",rowi]];
    }
    //NSLog(@"dump[%@]",r);
    return r;
    //[self alertMessage:@"Invoice Dump" :r];
    
}

#pragma mark - EXPTableDelegate
//=============<EXPTableDelegate>=====================================================
// An EXP table set gets saved EACH PAGE. When we have done all the pages,
//  then the invoice gets saved!
- (void)didSaveEXPTable  : (NSArray *)a
{
    pagesReturned++; //DHS 3/14
    if (a == nil || a.count == 0) //EMPTY page? go on to next one
    {
        [self handleNextPage : TRUE];
        return;
    }
    if (debugMode)
        NSLog(@"didSaveEXPTable, page %d of %d",pagesReturned,pageCount); //DHS 2/4 add +1 to page arg
    if (![_invoiceNumberString isEqualToString:_oldInvoiceNumberString]) //New invoice?
    {
        //2/5 need to check if invoice # is changing from page to page...
        if (debugMode)
            NSLog(@"New invoice:init %@ vs %@",_oldInvoiceNumberString,_invoiceNumberString);
        _totalLines = 0; //DHS 3/14 reset linecount accumulator
        //Time to setup invoice object too!
        [it setupVendorTableName : _vendor];
        if (_invoiceCustomer == nil) _invoiceCustomer = @"No Customer"; //DHS 1/28 no nils!
        [it setBasicFields:_invoiceDate : _invoiceNumberString : @"" : _vendor : _invoiceCustomer : _imageFileName :
            [NSString stringWithFormat:@"%d",currentPage]: @"1"];
        _oldInvoiceNumberString = _invoiceNumberString; //Remember our invoice for later checks...
    }
    [it clearObjectIds]; //clear object IDs
    for (NSString *objID in a) [it addInvoiceItemByObjectID : objID];
 //   NSLog(@" pr %d pc %d",pagesReturned,pageCount);
    //4/5/20 only save last page, too much info!
    if (currentPage+1 == pageCount)
    {
        NSString *astr = [NSString stringWithFormat:@"...saved EXP page %d of %d",pagesReturned,pageCount];
        [act saveActivityToParse : astr : _invoiceNumberString];
    }
    [it updateInvoice : _vendor : _invoiceNumberString : _batchID : (currentPage+1==pageCount)];
    [self.delegate batchUpdate : [NSString stringWithFormat:@"Update Invoice# %@",_invoiceNumberString]];

} //end didSaveEXPTable


//=============<EXPTableDelegate>=====================================================
// called when Allll exps are saved in one invoice from all the pages
- (void)didFinishAllEXPRecords : (int)count : (NSArray *)a;
{
    NSString *its = [NSString stringWithFormat:@"%4.2f",_invoiceTotal];
    its = [od cleanupPrice:its]; //Make sure total is formatted!
}

//=============<EXPTableDelegate>=====================================================
- (void)didReadEXPTableAsStrings : (NSString *)s
{
    //spinner.hidden = TRUE;
    //[spinner stopAnimating];
    
    //[self mailit: s];
}


//=============<EXPTableDelegate>=====================================================
// Error in an EXP record; pass on to batch for storage
- (void)errorInEXPRecord : (NSString *)err : (NSString *)oid : (NSString *)productName
{
    [self->_delegate errorInEXPRecord : err : oid : productName];  // -> BatchObject (bbb)
}

//=============<EXPTableDelegate>=====================================================
- (void)errorSavingEXPToParse : (NSString *)err
{
    [self->_delegate errorSavingEXPToParse : err ];  // -> BatchObject (bbb) 2/10
}


//=============<EXPTableDelegate>=====================================================
// 2/28 invoked indirectly from batchObject, final export of CSV after batch
- (void)didReadFullTableToCSV : (NSString *)s
{
    [self->_delegate didReadFullTableToCSV : s];  // 2/28 just pass buck up to batchObject
}
//=============<EXPTableDelegate>=====================================================
// 2/28 invoked indirectly from batchObject, final export of CSV after batch
- (void)errorReadingFullTableToCSV : (NSString *)err
{
    [self->_delegate errorReadingFullTableToCSV : err];   // 2/28 just pass buck up to batchObject
}


#pragma mark - invoiceTableDelegate
//=============(invoiceTableDelegate)=====================================================
- (void)didSaveInvoiceTable:(NSString *) s : (BOOL)lastPage
{
    [self handleNextPage : TRUE];
}

//=============(invoiceTableDelegate)=====================================================
// 2/5 added lastPage indicator so delegate knows when to do next document
- (void)errorSavingInvoiceToParse:(NSString *) err  : (BOOL)lastPage
{
    [self handleNextPage : TRUE];
    [self->_delegate errorSavingInvoiceToParse : err ];  // -> BatchObject (bbb) 2/10
}

//=============(invoiceTableDelegate)=====================================================
// 2/5 added lastPage indicator so delegate knows when to do next document
- (void)didUpdateInvoiceTable:(NSString *) s  : (BOOL)lastPage
{
    [self handleNextPage : TRUE];
}


@end
