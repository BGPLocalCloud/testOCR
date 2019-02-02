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

        it = [[invoiceTable alloc] init];     // Parse DB: invoice storage
        it.delegate = self;
        et = [[EXPTable alloc] init];   // Parse DB: EXP line item storage
        et.delegate = self;
        act = [[ActivityTable alloc] init];


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
    [od computeScaling : tlTemplate : trTemplate];
    
    if (page == 0) //DHS 1/31 ONLY clear on first page!
    {
        _invoiceNumber   = 0L;
        _invoiceDate     = nil;
        _invoiceCustomer = nil;
        _invoiceVendor   = nil;
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
    int headerY = 0;
    int columnDataTop = 0;
    for (int i=0;i<[ot getBoxCount];i++) //Loop over our boxes...
    {
        //OK, let's go and get the field name to figure out what to do w data...
        NSString* fieldName = [ot getBoxFieldName:i];
        CGRect rr = [ot getBoxRect:i]; //In document coords!
        NSMutableArray *a = [od findAllWordsInRect:rr];
        //NSLog(@" [%@] fieldname is [%@], %d items",_imageFileName,fieldName,(int)a.count);
        if (a.count > 0) //Found a match!
        {
            if (page == 0 && [fieldName isEqualToString:INVOICE_NUMBER_FIELD]) //Looking for a number?
            {
                _invoiceNumber = [od findLongInArrayOfFields:a];
                //This will have to be more robust
                _invoiceNumberString = [NSString stringWithFormat:@"%ld",_invoiceNumber];
                NSLog(@" invoice# %ld [%@]",_invoiceNumber,_invoiceNumberString);
            }
            else if (page == 0 && [fieldName isEqualToString:INVOICE_DATE_FIELD]) //Looking for a date?
            {
                NSDate* testDate = [od findDateInArrayOfFields:a]; //Find date-like string?
                if (testDate == nil) //Bogus?  1/27 redid
                {
                    if (page == 0) _invoiceDate = [NSDate date]; //1st page? Nothing to go on, use current date
                }
                else _invoiceDate = testDate;
                NSLog(@" invoice date %@",_invoiceDate);
            }
            else if (page == 0 && [fieldName isEqualToString:INVOICE_CUSTOMER_FIELD]) //Looking for Customer?
            {
                _invoiceCustomer = [od findTopStringInArrayOfFields:a]; //Just get first line of template area
                NSLog(@" Customer %@",_invoiceCustomer);
            }
            else if (page == 0 && [fieldName isEqualToString:INVOICE_SUPPLIER_FIELD]) //Looking for Supplier?
            {
                _invoiceVendor = [od findTopStringInArrayOfFields:a]; //Just get first line of template area
                BOOL matches = [ot isSupplierAMatch:_invoiceVendor]; //Check for rough match
                NSLog(@" Supplier %@, match %d",_invoiceVendor,matches);
            }
            else if ([fieldName isEqualToString:INVOICE_HEADER_FIELD]) //Header is SPECIAL!
            {
                //headerY = [od autoFindHeader];
                // Get header ypos (document coords!!)
                headerY = [od findHeader:rr :300]; //1/30 changed expandby to 300
                if (headerY == -1)
                {
                    [self->_delegate errorPerformingOCR:@"Missing Invoice Header"];
                    return;
                }
                columnDataTop = [od doc2templateY:headerY] + 1.5*od.glyphHeight;
                headerY -= 10;  //littie jiggle up...
                rr.origin.y = [od doc2templateY:headerY];  //Adjust our header rect to new header position!
                a = [od findAllWordsInRect:rr]; //Do another search now...
                headerRect = rr; //Save our header rect for later...
                _columnHeaders = [od getHeaderNames];
            }
            //1/31 Invoice total: only look at last page!
            else if ([fieldName isEqualToString:INVOICE_TOTAL_FIELD])
            {
                //[od dumpArrayFull:a];
                _invoiceTotal = [od findPriceInArrayOfFields:a];
                NSLog(@" invoice Total %4.2f [%@]",_invoiceTotal,[NSString stringWithFormat:@"%4.2f",_invoiceTotal]);
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
            //CGRect dr = [od template2DocRect:rr];
            //NSLog(@"templateRect %@",NSStringFromCGRect(rr));
            //NSLog(@"documentRect %@",NSStringFromCGRect(dr));
            //NSLog(@" column found==================");
            //[od dumpArrayFull:a];
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
        //NSLog(@" column[%d] %@",i,NSStringFromCGRect(rc));
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
        
        NSMutableArray *cleanedUpArray = [od cleanUpPriceColumns : i : [ot getColumnType:i] : stringArray ];
        [od addColumnStringData:cleanedUpArray];
        NSLog(@" col[%d] cleanup %@",i,cleanedUpArray);
    }
    
    //Now, columns are ready: let's dig them out!
    if (od.longestColumn < 2) //Must be an error? Not enough rows!
    {
        [self->_delegate errorPerformingOCR:@"Missing Invoice Rows"];
        return;
    }

    [rowItems removeAllObjects];
    for (int i=0;i<od.longestColumn;i++)
    {
        NSMutableArray *ac = [od getRowFromColumnStringData : i];
        //NSLog(@"annnd row %d is %@",i,ac);
        NSString *rowString = @"";
        for (int j=0;j<(int)ac.count;j++)
        {
            NSString *formatStr = @"%@,";
            if (j == (int)ac.count-1) formatStr = @"%@"; //last field
            rowString = [rowString stringByAppendingString:
                         [NSString stringWithFormat:formatStr,[ac objectAtIndex:j]]];
        }
        [rowItems addObject:rowString];
    }
    
    //Report errs as needed... any or all may be possible! 1/27 append filename if possible
    if (_invoiceNumber   == 0L)
        [self->_delegate errorPerformingOCR:[@"Missing Invoice Number:" stringByAppendingString :_imageFileName ]];
    if (_invoiceDate     == nil)
        [self->_delegate errorPerformingOCR:[@"Missing Invoice Date:" stringByAppendingString :_imageFileName ]];
    if (_invoiceCustomer     == nil)
         [self->_delegate errorPerformingOCR:[@"Missing Invoice Customer:" stringByAppendingString :_imageFileName ]];
//Ignore for now
//    if (_invoiceVendor     == nil)
//        [self->_delegate errorPerformingOCR:@"Missing Invoice Vendor"];
    
    //NSLog(@" OTO:invoice rows %@",rowItems);
    //DEBUG [self dumpResults];
    
} //end applyTemplate


//=============(OCRTopObject)=====================================================
// passes buck down to exptable. unique record count throughout batch
-(void) clearEXPBatchCounter
{
    [et clearBatchCounter];
}


//=============(OCRTopObject)=====================================================
// Retreives data from a column in the array w/ limit checking.
-(NSString *)getLineItem : (int) index  : (int) licount : (NSArray *)a
{
    NSString *result = @"EMPTY";
    if (index >= licount) NSLog(@" ...get lineitem %d past end!",index);
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
        NSLog(@" error reading CSV file %@",fname);
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
                NSLog(@" titles... %@",s);
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
                NSLog(@" fnc %d dc %d lic %d",filenameColumn,dateColumn,lineItemsColumn);
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
                //NSString *livendor      = avendor;
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
                        [et addRecord:smartp.invoiceDate : smartp.analyzedCategory : smartp.analyzedShortDateString :
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
        NSLog(@" save CSV to EXP table, PAGE STUBBED!!!");
        [et saveToParse : 0 : TRUE]; //page count 0 based, # pages
        _totalLines += smartCount;
    }
    return;
} //end loadCSVFileFromDocParser



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
// Sends a JPG to the OCR server, and receives JSON text data back...
- (void)performOCROnImage : (NSString *)fname : (UIImage *)imageToOCR : (OCRTemplate *)ot
{
    // Image file and parameters, use hi compression quality?
    NSData *imageData = UIImagePNGRepresentation(imageToOCR);
    CGRect r = CGRectMake(0, 0, imageToOCR.size.width, imageToOCR.size.height);
    _imageFileName = fname;
    [self performOCROnData: fname : imageData : r : ot];
} //end performOCROnImage


//=============(OCRTopObject)=====================================================
// Sends a JPG to the OCR server, and receives JSON text data back...
//  OCR handles multiple pages from PDF data!
- (void)performOCROnData : (NSString *)fname : (NSData *)imageDataToOCR : (CGRect) r :  (OCRTemplate *)ot
{
    //First, check cache: may already have downloaded OCR raw txt for this file...
    if ([oc txtExistsByID:fname])
    {
        NSLog(@" OCR Cache HIT: %@",fname);
        [self.delegate batchUpdate : [NSString stringWithFormat:@"OCR Cache HIT:%@",fname]];
        rawOCRResult  = [oc getTxtByID:fname];  //Raw OCR'ed text, needs to goto JSON
        r             = [oc getRectByID:fname]; //Get cached image size too...
        NSData *jsonData = [rawOCRResult dataUsingEncoding:NSUTF8StringEncoding];
        NSError *e;
        OCRJSONResult = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingMutableContainers error:&e];
        if (e != nil) NSLog(@" ....json err? %@",e.localizedDescription);
        [self performFinalOCROnDocument : r : ot ]; //This calls delegate when done
        return; //Bail!
    }
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
    NSLog(@" send OCR request... %@",_imageFileName);
    [self.delegate batchUpdate : [NSString stringWithFormat:@"Send OCR Request:%@",_imageFileName]];

    [request setHTTPBody:data];
    
    // Start data session
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSError* myError;
        NSLog(@" ...OCR response from server...");
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
            if (isErr.boolValue)
            {
                //1/27 pass fname AND error back...
                [self->_delegate fatalErrorPerformingOCR:[NSString stringWithFormat:@"%@ %@",errMsg,self->_imageFileName]];
            }
            else
            {
                //1/19 don't save to cache unless there are NO ERRORS
                [self->oc addOCRTxtWithRect:fname :r:self->rawOCRResult];
                NSLog(@" annnnd result from OCR server is %@",self->OCRJSONResult);
                [self performFinalOCROnDocument : r : ot]; //This calls delegate when done
            }
        }
    }];
    [task resume];
} //end performOCROnData

//=============(OCRTopObject)=====================================================
// JSON result may be from OCR server return OR from cache hit. needs template.
//  informs delegate when done... called by performOCROnData
// NOTE: document may have multiple pages!
-(void) performFinalOCROnDocument : (CGRect) r : (OCRTemplate *)ot
{
    if (ot != nil) //Template needs to be applied?
    {
        NSLog(@" ...final OCR");
        pagesReturned = 0;
        // This eats up the json and creates a set of OCR boxes, in
        //  an array: one set per page...
        [od setupDocumentWithRect : r : OCRJSONResult ];
        pageCount = od.numPages; //OK! now we know how many pages we have
        _totalLines = 0; //Overall line count...
        for (int page = 0;page<pageCount;page++)
        {
            NSLog(@" Final OCR Page %d",page);
            //Hand progress up to parent for UI update...
            [self.delegate batchUpdate : [NSString stringWithFormat:@"...Page %d/%d -> OCR",page+1,od.numPages]];
            [od setupPage:page];
            [self applyTemplate : ot : page];   //Does OCR analysis
            if (od.longestColumn != 0) //1/30 NOT Empty Page??
               [self writeEXPToParse : page];      // asdf Saves all EXP rows, then invoice as well
            else // 1/30 Empty Page? Tell delegate to continue...
            {
                NSLog(@" empty page %d/%d, jump to next page/document",page,pageCount);
                [self->_delegate didSaveOCRDataToParse:_invoiceNumberString];  // -> BatchObject (bbb)
            }
        } //end for page
    }
    [self->_delegate didPerformOCR:@"OCR OK?"];

}

//=============(OCRTopObject)=====================================================
-(void) stubbedOCR: (NSString*)imageName : (UIImage *)imageToOCR : (OCRTemplate *)ot
{
    NSString * stubbedDocName = @"lilbeef";
    _imageFileName = imageName; //selectFnameForTemplate;
    OCRJSONResult = [self readTxtToJSON:stubbedDocName];
    [self setupTestDocumentJSON:OCRJSONResult];
    CGRect r = CGRectMake(0, 0, imageToOCR.size.width, imageToOCR.size.height);
    [od setupDocumentWithRect : r : OCRJSONResult ];
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
    NSLog(@" setup doc...");
    [od setupDocumentWithRect : r : OCRJSONResult ];
}


//=============(OCRTopObject)=====================================================
// DOES FULL CLEANUP AND saves to EXP...
// Assumes invoice prices are in cleaned-up post OCR area...
//  also smartCount must be set!
-(void) writeEXPToParse : (int) page
{
    smartCount  = 0;
    [et clear]; //Set up EXP for new entries...
    NSLog(@"  writeEXP/cleanup...");
    if (page == pageCount-1) [self.delegate batchUpdate : [NSString stringWithFormat:@"Save EXP Records..."]];

    for (int i=0;i<od.longestColumn;i++) //OK this does multiple parse saves at once!
    {
        NSMutableArray *ac = [od getRowFromColumnStringData : i];
        if (ac.count < 5)
        {
            NSLog(@" bad row pulled in EXP save!");
            return;
        }
        //item,description ... Note: these columns are determined at runtime!
        //NSString *item        = ac[od.itemColumn];
        NSString *productName = ac[od.descriptionColumn];  
        [smartp clear];
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
        //NSLog(@" analyze OK %d [%@]->%@",smartp.analyzeOK,productName, smartp.analyzedProductName);
        
        if ([smartp.analyzedProductName containsString:@"chips"])
            NSLog(@" chippie");
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
            //OCR: Tons of args: adds allll this shit to the next EXP table entry for saving to parse...
            [et addRecord:smartp.invoiceDate : smartp.analyzedCategory : smartp.analyzedShortDateString :
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
                    NSLog(@" ---->ERROR: bad product name %@",productName);
                    NSString *s = [NSString stringWithFormat:@"E:Bad Product Name (%@)",productName];
                    [self->_delegate errorSavingEXP:s:@"n/a":productName];
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
    NSLog(@"dump[%@]",r);
    return r;
    //[self alertMessage:@"Invoice Dump" :r];
    
}

#pragma mark - EXPTableDelegate
//=============(OCRTopObject)=====================================================
// An EXP table set gets saved EACH PAGE. When we have done all the pages,
//  then the invoice gets saved!
- (void)didSaveEXPTable  : (NSArray *)a
{
    NSLog(@"didSaveEXPTable, page %d of %d",pagesReturned,pageCount);
    if (pagesReturned == 0) //First page, set up invoice
    {
        NSLog(@"First page return: invoice init");
        //Time to setup invoice object too!
        [it clear];
        [it setupVendorTableName : _vendor];
        [it setupVendorTableName:_vendor];
        //Note: Total field is empty, we don't necessarily have it on first page!
        NSString *pcs = [NSString stringWithFormat:@"%d",pageCount];
        if (_invoiceCustomer == nil) _invoiceCustomer = @"No Customer"; //DHS 1/28 no nils!
        [it setBasicFields:_invoiceDate : _invoiceNumberString : @"" : _vendor : _invoiceCustomer : _imageFileName : pcs];
    }
    pagesReturned++;
    NSString *astr = [NSString stringWithFormat:@"...saved EXP page %d of %d",pagesReturned,pageCount];
    [act saveActivityToParse : astr : _invoiceNumberString];
} //end didSaveEXPTable


//=============(OCRTopObject)=====================================================
// called when Allll exps are saved in one invoice from all the pages
- (void)didFinishAllEXPRecords : (NSArray *)a;
{
    //Compile list of invoice ptrs -> EXP table...
    for (NSString *objID in a) [it addInvoiceItemByObjectID : objID];
    NSLog(@"didFinishAllEXPRecords, save invoice");
    //For every page, add entries to invoice...asdf
    [self.delegate batchUpdate : [NSString stringWithFormat:@"saved Invoice %@",_invoiceNumberString]];
    [act saveActivityToParse:@"...saved Invoice" : _invoiceNumberString];
    NSString *its = [NSString stringWithFormat:@"%4.2f",_invoiceTotal];
    its = [od cleanupPrice:its]; //Make sure total is formatted!
    [it updateInvoice : _vendor : _invoiceNumberString : _batchID];

}

//=============(OCRTopObject)=====================================================
- (void)didReadEXPTableAsStrings : (NSString *)s
{
    //spinner.hidden = TRUE;
    //[spinner stopAnimating];
    
    //[self mailit: s];
}


//=============OCR VC=====================================================
// Error in an EXP record; pass on to batch for storage
- (void)errorInEXPRecord : (NSString *)err : (NSString *)oid : (NSString *)productName
{
    [self->_delegate errorSavingEXP : err : oid : productName];  // -> BatchObject (bbb)
}


#pragma mark - invoiceTableDelegate
//=============(invoiceTableDelegate)=====================================================
- (void)didSaveInvoiceTable:(NSString *) s
{
    [self->_delegate didSaveOCRDataToParse:s];  // -> BatchObject (bbb)
}

//=============(invoiceTableDelegate)=====================================================
- (void)errorSavingInvoiceTable:(NSString *) s
{
    [self->_delegate errorSavingOCRDataToParse:s];  // -> BatchObject (bbb)
}

//=============(invoiceTableDelegate)=====================================================
- (void)didUpdateInvoiceTable:(NSString *) s
{
    NSLog(@" ok, updated invoice %@",s);
    [self->_delegate didSaveOCRDataToParse:s];  // -> BatchObject (bbb)
}


@end
