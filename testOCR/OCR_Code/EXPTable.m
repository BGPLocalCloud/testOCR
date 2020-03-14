//
//   _______  ______ _____     _     _
//  | ____\ \/ /  _ \_   _|_ _| |__ | | ___
//  |  _|  \  /| |_) || |/ _` | '_ \| |/ _ \
//  | |___ /  \|  __/ | | (_| | |_) | |  __/
//  |_____/_/\_\_|    |_|\__,_|_.__/|_|\___|
//
//  EXPTable.m
//  testOCR
//
//  Created by Dave Scruton on 12/17/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
//  1/24 added batchCounter, removed batch_key
//  2/7 add debugMode for logging
//  2/8 add invoiceNumber to readFromParseAsStrings
//  2/9 add parentUp flag to avoid delegate callback crashes on dismissed VC
//  2/12 add productname to fixPrices...
//  3/20 add selectedCustomer support
//  3/22 missed some tableName changes
//  3/29 sort CSV output by PInv_BatchCounter_key (ascending)
//  5/1  add processCSV
#import "EXPTable.h"

@implementation EXPTable

#define FIELD_ERROR_STRING @"$ERR"

//=============(EXPTable)=====================================================
-(instancetype) init
{
    if (self = [super init])
    {
        _expos        = [[NSMutableArray alloc] init]; //Invoice Objects
        objectIDs     = [[NSMutableArray alloc] init]; //saved object ids, for matching invoice
        internalPFOs  = [[NSMutableArray alloc] init]; //saved object ids, for matching invoice
        csvList       = [[NSMutableArray alloc] init]; //saved object ids, for matching invoice
        _sortBy = @"*";
        _selectBy = @"*";
        tableName = @"EXP_KCH"; //3/20
        _parentUp = TRUE;

        AppDelegate *eappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        debugMode = eappDelegate.debugMode; //2/7 For dwbug logging, check every batch


        _versionNumber    = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
    }
    return self;
}

//=============(EXPTable)=====================================================
-(void) clear
{
    if (debugMode) NSLog(@" EXP Clear");
    [_expos removeAllObjects];
    //Clear EXP send/return counts...
    [objectIDs removeAllObjects]; //2/5 back here again
    //2/5
    totalSentCount = totalReturnCount = 0;
    allErrors = @"";
}


//=============(EXPTable)=====================================================
-(void) clearBatchCounter
{
    batchCounter = 0;
}

//=============(EXPTable)=====================================================
// 5/1 CSV support
-(void) loadCSVConstants
{
    pamHeaders  = @[  //Human-readable CSV headers from Excel
                    @"category", @"month", @"item", @"quantity",
                    @"unit of measure", @"bulk/ individual pack", @"vendor name", @"total price",
                    @"price/ uom", @"processed", @"local (l)", @"invoice date",
                    @"line #"
                    ];
    pamKeywords = @[  //matching PARSE column names
                    PInv_Category_key,PInv_Month_key,PInv_ProductName_key,PInv_Quantity_key,
                    PInv_UOM_key,PInv_Bulk_or_Individual_key,PInv_Vendor_key,PInv_TotalPrice_key,
                    PInv_PricePerUOM_key,PInv_Processed_key,PInv_Local_key,PInv_Date_key,
                    PInv_LineNumber_key
                    ];
    
    
} //end loadCSVConstants

//=============Comparison VC=====================================================
// 5/1 CSV support
//Can't break up a CSV string right if it has commas inside quoted names (like vendor!)
-(NSString *) stripCommasFromQuotedStrings : (NSString*) s
{
    NSString *result = @"";
    NSRange theRange;
    BOOL inQuotes = FALSE;
    for ( NSInteger i = 0; i < [s length]; i++) {
        theRange.location = i;
        theRange.length   = 1;
        NSString* nextChar = [s substringWithRange:theRange];
        if ([nextChar isEqualToString:@"\""]) //double quotes? toggle quotes flag
        {
            inQuotes = !inQuotes;
        }
        else if ([nextChar isEqualToString:@","]) //comma? don't append if inside quotes!
        {
            if (!inQuotes) result = [result stringByAppendingString:nextChar];
        } //Not a quote or comma..... just append
        else result = [result stringByAppendingString:nextChar];
    } //end for i
    return result;
} //end stripCommasFromQuotedStrings

// Sample Lines from CSV:
//CATEGORY,Month,Item,Quantity,Unit Of Measure,BULK/ INDIVIDUAL PACK,Vendor Name, Total Price ,PRICE/ UOM,PROCESSED ,Local (L),Invoice Date,Line #,,
//  PROTEIN,01-JUL,Ground Beef,80,lb,,"Hawaii Beef Producers, LLC", $236.80 ,$2.96,UNPROCESSED,Yes,07/03/2018,1,,

//=============Comparison VC=====================================================
// 5/1 CSV support
-(void) processCSV : (NSString *)s
{
    [self loadCSVConstants];
    NSLog(@" processing... get hdr info first:");
    //First check column ordering...
    NSArray  *csvItems = [s componentsSeparatedByString:@"\n"]; //Break up file into lines
    if (csvItems.count < 2)
    {
        NSLog(@" ERROR: no data in CSV File!");
        return;
    }
    NSMutableArray *columnKeys = [[NSMutableArray alloc] init];
    NSString *legend      = csvItems[0];
    NSArray  *legendItems = [legend componentsSeparatedByString:@","]; //Break up legend...
    for (NSString *nextHeader in legendItems)
    {
        NSString *hhh = [nextHeader stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSUInteger wherezit = [pamHeaders indexOfObject:hhh.lowercaseString];
        if (wherezit != NSNotFound)
        {
            [columnKeys addObject: [pamKeywords objectAtIndex:wherezit]];
        }
        else if (hhh.length > 1){
            NSLog(@" ERROR: unmatched CSV header title %@",nextHeader);
            return;
        }
    }
    //Work strings...
    BOOL firstRecord = TRUE;
    int writeCount,okCount,errCount,loadCount;
    writeCount = okCount = errCount = 0;
    loadCount  = (int)csvItems.count;
    [self clear];
    for (NSString *nextLine in csvItems)
    {
        if (!firstRecord) //Skip 1st record...
        {
            NSString* noQuotedCommas =  [self stripCommasFromQuotedStrings:nextLine];
            NSArray  *nlItems      = [noQuotedCommas componentsSeparatedByString:@","]; //Break up line...
            NSMutableArray *fields = [[NSMutableArray alloc] init];
            NSMutableArray *values = [[NSMutableArray alloc] init];
            NSDate *idate          = [NSDate date];
            for (int i=0;i<nlItems.count;i++) //Go thru fields...
            {
                if (i >= pamKeywords.count) break; //Out of bounds or extra args on line? skip!
                NSString *nextField = nlItems[i];
                NSString *nextPamKw = pamKeywords[i];
                if ([nextPamKw isEqualToString:PInv_Date_key])
                { //date format: 07/03/2018
                    NSDateFormatter * formatter =  [[NSDateFormatter alloc] init];
                    [formatter setDateFormat:@"MM/dd/yyyy"];
                    idate = [formatter dateFromString:nextField]; //Unpack date
                }
                else{
                    [fields addObject:nextPamKw];
                    [values addObject:nextField];
                }
            } //end for i
            if (values.count > 2) //Did we get something?
            {
                //OK ready to write!
                //if (writeCount % 100 == 0) NSLog(@" write %d/%d [%@]",writeCount,loadCount,values[2]);
                [self addRecordFromArrays : idate :  fields : values];
                writeCount++;
            }
        } //end !first...
        firstRecord = FALSE;
    } //end for loop
} //end processCSV

//=============(EXPTable)=====================================================
// vendor = * means all
-(void) deleteObjectsByVendor : (NSString *)vendor
{
    PFQuery *query = [PFQuery queryWithClassName:tableName];
    //Wildcard? Don't select any vendor...
    if (![vendor isEqualToString:@"*"]) [query whereKey:PInv_Vendor_key equalTo:vendor];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            [PFObject deleteAllInBackground:objects];
            if (self->debugMode) NSLog(@" deleted all EXP for %@",vendor);
        }
        else {
            NSLog(@"Error: %@ %@", error, [error userInfo]);
        }
    }];
} //end deleteObjectsByVendor


//=============(EXPTable)=====================================================
-(NSString *) TrackNilErrors :(NSString *)s : (NSString *)fieldName
{
    BOOL bing = FALSE;
    NSString *latestError;
    if (s == nil)
    {
        latestError = [NSString stringWithFormat:@"empty %@[%@]",fieldName,workProductName];
        bing = TRUE;
    }
    if ([s isEqualToString:@""] || [s isEqualToString:@" "])
    {
        latestError = [NSString stringWithFormat:@"blank %@[%@]",fieldName,workProductName];
        bing = TRUE;
    }
    if (bing)
    {
        latestError =  [latestError stringByAppendingString:[NSString stringWithFormat:@":%@:%@",
                                                           workPDFFile,workPage.stringValue]];
        //Send error to batch parent, stick in an error string indicator for this field
        s = FIELD_ERROR_STRING;
        allErrors =  [allErrors stringByAppendingString:latestError];
        errorsByLineNumber[workPage.intValue] = latestError;
    }
    return s;
} //end TrackNilErrors


//=============(EXPTable)=====================================================
-(void) addRecord : (NSDate*) fdate : (NSString *) category : (NSString *) month : (NSString *) item : (NSString *) uom : (NSString *) bulk : (NSString *) vendor : (NSString *) productName : (NSString *) processed : (NSString *) local : (NSString *) lineNumber : (NSString *) invoiceNumber : (NSString *) quantity : (NSString *) pricePerUOM : (NSString*) total : (NSString *) batch : (NSString *) errStatus : (NSString *) PDFFile : (NSNumber *) page  
{
    NSString *errstr = @"";
    workProductName = productName;
    workPDFFile     = PDFFile;
    workPage        = page;
    //ERR Check! Look for nils! Clumsy but it's all we can do w/ all these args!
    if (fdate == nil)
    {
        errstr = @"Null date";
        allErrors =  [allErrors stringByAppendingString:errstr];
        errorsByLineNumber[workPage.intValue] = FIELD_ERROR_STRING;
        fdate = [NSDate date]; //Just pass todays date...
    }
    //Fix nil strings, add error indicator as needed...
    category    = [self TrackNilErrors : category : PInv_Category_key];
    month       = [self TrackNilErrors : month : PInv_Month_key];
    item        = [self TrackNilErrors : item : PInv_Item_key];
    uom         = [self TrackNilErrors : uom : PInv_UOM_key];
    bulk        = [self TrackNilErrors : bulk : PInv_Bulk_or_Individual_key];
    vendor      = [self TrackNilErrors : vendor : PInv_Vendor_key];
    productName = [self TrackNilErrors : productName : PInv_ProductName_key];
    processed   = [self TrackNilErrors : processed : PInv_Processed_key];
    local       = [self TrackNilErrors : local : PInv_Local_key];
    lineNumber  = [self TrackNilErrors : lineNumber : PInv_Local_key];
    pricePerUOM = [self TrackNilErrors : pricePerUOM : PInv_PricePerUOM_key];
    total       = [self TrackNilErrors : total : PInv_TotalPrice_key];
    batch       = [self TrackNilErrors : batch : PInv_BatchID_key];
    errStatus   = [self TrackNilErrors : errStatus : PInv_ErrStatus_key];
    PDFFile     = [self TrackNilErrors : PDFFile : PInv_PDFFile_key];
    
    EXPObject *exo = [[EXPObject alloc] init];
    exo.expdate         = fdate;
    exo.category        = category;
    exo.month           = month;
    exo.item            = item;
    exo.uom             = uom;
    exo.bulk            = bulk;
    exo.vendor          = vendor;
    exo.productName     = productName;
    exo.processed       = processed;
    exo.local           = local;
    exo.lineNumber      = lineNumber;
    exo.invoiceNumber   = invoiceNumber;
    exo.quantity        = quantity;
    exo.pricePerUOM     = pricePerUOM;
    exo.total           = total;
    exo.batch           = batch;
    exo.errStatus       = errStatus;
    exo.PDFFile         = PDFFile;
    exo.page            = page;
    exo.batchCounter    = [NSString stringWithFormat:@"%@_%4.4d",batch,batchCounter];
    [_expos addObject:exo];
    batchCounter++;
    
} //end addRecord

//=============(EXPTable)=====================================================
// save everything in the expos table, only should be used for small datasets!
-(void) saveEXPOs
{
    NSLog(@" ...save all EXP records to %@, %d records",tableName,(int)_expos.count);
    [PFObject saveAllInBackground:_expos block:^(BOOL succeeded, NSError * _Nullable error) {
        if (succeeded) {
            if (self->_parentUp) [self.delegate didSaveEXPOs];
        }
        else{
            if (self->_parentUp) [self.delegate errorSavingEXPOs :
             [NSString stringWithFormat:@"saveEXPOs error:%@",error.localizedDescription]];
        }
    }];
} //end saveEXPOs


//=============(EXPTable)=====================================================
// Saves large (over 100 records) expos array...
-(void) saveExposBlocks : (int) skip
{
    NSLog(@" saveExposBlocks : %d",skip);
    int count = (int)_expos.count - skip; //Amount left to save...
    int saveCount = MIN(count,100);
    NSMutableArray *pfos = [[NSMutableArray alloc] init];
    for (int i=0;i<saveCount;i++) //Copy in next block of records to save
    {
        pfos[i] = _expos[skip+i];
    }
    //annd save it!
    [PFObject saveAllInBackground:pfos block:^(BOOL succeeded, NSError * _Nullable error) {
        if (succeeded) {
            if (saveCount < 100) //Last block? let delegate know we're done...
            {
                if (self->_parentUp) [self.delegate didSaveEXPOsBlocks];
            }
            else [self saveExposBlocks : skip+100]; //More ? recursively call self
        }
        else{
            if (self->_parentUp) [self.delegate errorSavingEXPOsBlocks :
                                  [NSString stringWithFormat:@"saveEXPOsBlocks error:%@",error.localizedDescription]];
        }
    }];
} //end saveExposBlocks


//=============(EXPTable)=====================================================
// Add record to EXPOS, for saving later...
-(void) addRecordFromArrays : (NSDate*) fdate : (NSMutableArray *) fields : (NSMutableArray*) values
{
    if (fields == nil || values == nil || fdate == nil) return;
    int fcount = (int) fields.count;
    int vcount = (int) values.count;
    if (fcount == 0 || vcount == 0 || fcount != vcount) return;
    PFObject *exoRecord = [PFObject objectWithClassName:tableName];
    for (int i=0;i<fcount;i++)
    {
        exoRecord[fields[i]] = values[i];
    }
    exoRecord[PInv_Date_key] = fdate; //ONLY column that ain't a String!
    [_expos addObject:exoRecord];
} //end addRecordFromArrays



//=============(EXPTable)=====================================================
-(NSString *) stringFromKeyedItems : (PFObject *)pfo : (NSArray *)kitems
{
    NSString *s = @"";
    int i = 0;
    int kc = (int)kitems.count;
    for (NSString *skey in kitems)
    {
        s = [s stringByAppendingString:
             [NSString stringWithFormat:@"%@",[pfo objectForKey:skey]]];
        if (i < kc-1)
             s = [s stringByAppendingString:@","];
        i++;
    }
    return s;
    
}


//=============(EXPTable)=====================================================
-(void) handleCSVInit : (BOOL) dumptoCSV : (BOOL) addErrStatus
{
    if (dumptoCSV) EXPDumpCSVList = @"CATEGORY,Month,Item,Quantity,Unit Of Measure,BULK/ INDIVIDUAL PACK,Vendor Name, Total Price ,PRICE/ UOM,PROCESSED ,Local (L),Invoice Date,Line #,Invoice #,\n";
    else EXPDumpCSVList = @"";
} //end handleCSVInit

//=============(EXPTable)=====================================================
-(void) handleCSVAdd : (BOOL) dumptoCSV : (NSString *)s
{
    self->EXPDumpCSVList = [self->EXPDumpCSVList stringByAppendingString: s];
    self->EXPDumpCSVList = [self->EXPDumpCSVList stringByAppendingString: @",\n"];
} //end handleCSVAdd


//=============(EXPTable)=====================================================
-(EXPObject*) getEXPObjectFromPFObject : (PFObject *)pfo
{
    EXPObject* e = [[EXPObject alloc] init];
    e.expdate           = [pfo objectForKey:PInv_Date_key];
    e.category          = pfo[PInv_Category_key];
    e.month             = pfo[PInv_Month_key];
    e.item              = pfo[PInv_Item_key];
    e.uom               = pfo[PInv_UOM_key];
    e.bulk              = pfo[PInv_Bulk_or_Individual_key];
    e.vendor            = pfo[PInv_Vendor_key];
    e.productName       = pfo[PInv_ProductName_key];
    e.processed         = pfo[PInv_Processed_key];
    e.local             = pfo[PInv_Local_key];
    e.lineNumber        = pfo[PInv_LineNumber_key];
    e.invoiceNumber     = pfo[PInv_InvoiceNumber_key];
    e.quantity          = pfo[PInv_Quantity_key];
    e.total             = pfo[PInv_TotalPrice_key];
    e.pricePerUOM       = pfo[PInv_PricePerUOM_key];
    e.batch             = pfo[PInv_BatchID_key];   //DHS 2/11 WTF? wasn't here!
    e.errStatus         = pfo[PInv_ErrStatus_key];
    e.PDFFile           = pfo[PInv_PDFFile_key];
    e.page              = pfo[PInv_Page_key];
    e.versionNumber     = pfo[PInv_VersionNumber];
    e.objectId = pfo.objectId;
    return e;
} //end getEXPObjectFromPFObject


//=============(EXPTable)=====================================================
-(PFObject *) getEXPO  : (int) index
{
    if (index < 0 || index >= _expos.count) return nil;
    return [_expos objectAtIndex:index];
}


//=============(EXPTable)=====================================================
// from expos, get amount at this index, in pennies
-(int) getAmount : (int) index
{
    PFObject *pfo = [self getEXPO:index];
    if (pfo == nil) return 0;
    NSString *as = [pfo objectForKey:PInv_TotalPrice_key];
    as = [as stringByReplacingOccurrencesOfString:@"$" withString:@""];
    as = [as stringByReplacingOccurrencesOfString:@" " withString:@""];

    int rint = floor((100.0 * as.floatValue) + 0.5);
    return rint;
}

//=============(EXPTable)=====================================================
-(BOOL) getLocal : (int) index
{
    PFObject *pfo = [self getEXPO:index];
    if (pfo == nil) return 0;
    NSString *wstr = [pfo objectForKey:PInv_Local_key];
    return ([wstr.lowercaseString isEqualToString:@"yes"]);
} //End getLocal

//=============(EXPTable)=====================================================
-(BOOL) getProcessed : (int) index
{
    PFObject *pfo = [self getEXPO:index];
    if (pfo == nil) return 0;
    NSString *wstr = [pfo objectForKey:PInv_Processed_key];
    return ([wstr.lowercaseString isEqualToString:@"processed"]);
}

//=============(EXPTable)=====================================================
-(NSString *) getMonth : (int) index
{
    PFObject *pfo = [self getEXPO:index];
    if (pfo == nil) return @"";
    return [pfo objectForKey:PInv_Month_key];
}

//=============(EXPTable)=====================================================
-(NSString *) getVendor : (int) index
{
    PFObject *pfo = [self getEXPO:index];
    if (pfo == nil) return @"";
    return [pfo objectForKey:PInv_Vendor_key];
}

//=============(EXPTable)=====================================================
-(NSString *) getCategory : (int) index
{
    PFObject *pfo = [self getEXPO:index];
    if (pfo == nil) return @"";
    return [pfo objectForKey:PInv_Category_key];
}


//=============(EXPTable)=====================================================
-(NSString *) getCSVFromObject : (PFObject *)pfo : (BOOL) addErrStatus
{
    NSArray *sitems1 = [NSArray arrayWithObjects:
                        PInv_Category_key,PInv_Month_key,PInv_ProductName_key,PInv_Quantity_key,
                        PInv_UOM_key,PInv_Bulk_or_Individual_key,PInv_Vendor_key,PInv_TotalPrice_key,
                        PInv_PricePerUOM_key,PInv_Processed_key,PInv_Local_key,
                        nil];
    NSString *s = [self stringFromKeyedItems : pfo :sitems1];
    //Inject date into this mess (it's special!)
    NSDateFormatter * formatter =  [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"MM/dd/yy"];
    NSString *sfd = [formatter stringFromDate:[pfo objectForKey:PInv_Date_key]];
    s = [s stringByAppendingString: [NSString stringWithFormat:@",%@",sfd]];
    NSArray *sitems2 = [NSArray arrayWithObjects:
                        PInv_LineNumber_key,PInv_InvoiceNumber_key,
                        nil];
    s = [s stringByAppendingString:
         [NSString stringWithFormat:@",%@",[self stringFromKeyedItems : pfo :sitems2]]];
    NSArray *sitems3 = [NSArray arrayWithObjects:
                        PInv_ErrStatus_key,
                        nil];
    if (addErrStatus) //Add extra error info...
    {
        s = [s stringByAppendingString:
             [NSString stringWithFormat:@",%@",[self stringFromKeyedItems : pfo :sitems3]]];
    }
    return s;
} //end getCSVFromObject

//=============OCR VC=====================================================
-(void) readFromParseByObjIDs : (BOOL) dumptoCSV : (NSString *)vendor : (NSString *)soids
{
    [self handleCSVInit:dumptoCSV:FALSE];
    NSMutableArray *a = [[NSMutableArray alloc] init];
    NSArray *sitems =  [soids componentsSeparatedByString:@","];
    PFQuery *query = [PFQuery queryWithClassName:tableName];
    for (NSString *s in sitems)  //incoming should look like X_OBJID,X_OBJID, etc
    {
        NSArray *s2 =  [s componentsSeparatedByString:@"_"];
        if (s2.count == 2)
        {
            NSString *oid = s2[1];  //THis should be the object ID
            [a addObject:oid];
            if (debugMode) NSLog(@" .. fetch objid [%@]",oid);
            PFObject *pfo = [query getObjectWithId:oid];  //Fetch by object ID,
            [self handleCSVAdd : dumptoCSV : [self getCSVFromObject:pfo : FALSE]];
        }
    }
    if (_parentUp) [self.delegate didReadEXPTableAsStrings : self->EXPDumpCSVList];
} //end readFromParseByObjIDs

//=============OCR VC=====================================================
// 2/12 add productname
-(void) fixPricesInObjectByID: (NSString *)oid  : (NSString *)productName : (NSString *)qt : (NSString *)pt : (NSString *)tt
{
    PFQuery *query = [PFQuery queryWithClassName:tableName];
    PFObject *pfo = [query getObjectWithId:oid];  //Fetch by object ID,
    if (pfo != nil)
    {
        if (debugMode) NSLog(@" fix field Item/Q/P/T = %@/%@/%@/%@  ",productName,qt,pt,tt);
        [pfo setObject:productName forKey:PInv_ProductName_key];
        [pfo setObject:qt forKey:PInv_Quantity_key];
        [pfo setObject:pt forKey:PInv_PricePerUOM_key];
        [pfo setObject:tt forKey:PInv_TotalPrice_key];
        [pfo saveInBackgroundWithBlock:^(BOOL succeeded, NSError * _Nullable error) {
            if (succeeded)
            {
                if (self->debugMode) NSLog(@" update qpt OK objID %@",oid);
                if (self->_parentUp) [self.delegate didFixPricesInObjectByID : oid];
            }
            else
            {
                if (self->_parentUp) [self.delegate errorFixingPricesInObjectByID : error.localizedDescription];
            }
        }];
    }
} //end fixPricesInObjectByID

//=============OCR VC=====================================================
-(void) fixFieldInObjectByID : (NSString *)oid : (NSString *)key : (NSString *)value
{
    PFQuery *query = [PFQuery queryWithClassName:tableName];
    PFObject *pfo = [query getObjectWithId:oid];  //Fetch by object ID,
    if (pfo != nil)
    {
        if (debugMode) NSLog(@" fix field [%@] = %@ ",key,value);
        [pfo setObject:value forKey:key];
        [pfo saveEventually]; //No Hurry, just assume the DB is fast enough
    }
}


//=============OCR VC=====================================================
//BROKEN! DOESN'T WORK! can't set IDs for some reason?
-(void) getObjectsByIDs : (NSArray *)oids
{
    if (debugMode) NSLog(@" getObjectsByIDs %@",oids);
    if (oids == nil || oids.count < 1) return;
    PFQuery *query = [PFQuery queryWithClassName:tableName];
    [query whereKey:@"objectId" containedIn:oids];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) { //Query came back...
            [self->_expos        removeAllObjects];
            NSMutableDictionary *d = [[NSMutableDictionary alloc] init];
            for( PFObject *pfo in objects)
            {
                EXPObject *e = [self getEXPObjectFromPFObject:pfo];
                [d setObject:e forKey:pfo.objectId];
                [self->_expos addObject: e];
                [e dump];
            }
            if (self->_parentUp) [self.delegate didGetObjectsByIds : d];
        }
    }];


}


//=============OCR VC=====================================================
-(void) getObjectByID : (NSString *)oid
{
    PFQuery *query = [PFQuery queryWithClassName:tableName];
    //2/11 NOTE: this is done in the foreground, the UI is waiting and it's a remote call!
    //  produces this warning: Warning: A long-running operation is being executed on the main thread.
    //  Break on warnBlockingOperationOnMainThread() to debug.
    PFObject *pfo = [query getObjectWithId:oid];  //Fetch by object ID,
    if (pfo != nil)
    {
        EXPObject *e = [self getEXPObjectFromPFObject:pfo];
        if (self->_parentUp) [self.delegate didReadEXPObjectByID:e:pfo];
    }
} //end getObjectByID

//=============OCR VC=====================================================
-(void) readFromParseAsStrings : (BOOL) dumptoCSV : (NSString *)vendor : (NSString *)batch : invoiceNumberstring
{
    [self handleCSVInit:TRUE:FALSE];
    PFQuery *query = [PFQuery queryWithClassName:tableName]; //3/20
    
    //Wildcards means get everything...
    if (![vendor               isEqualToString:@"*"]) [query whereKey:PInv_Vendor_key  equalTo:vendor];
    if (![batch                isEqualToString:@"*"]) [query whereKey:PInv_BatchID_key equalTo:batch]; //1/31 bug fix wrong key
    if (![invoiceNumberstring  isEqualToString:@"*"]) [query whereKey:PInv_InvoiceNumber_key equalTo:invoiceNumberstring]; //1/31 bug fix wrong key
    if (![_sortBy isEqualToString:@""] && debugMode) NSLog(@"...sort EXP by %@",_sortBy);
    NSString *sortkey = @"createdAt";
    if (_sortBy != nil)
    {
        if ([_sortBy isEqualToString:@"Invoice Number"])     sortkey = PInv_InvoiceNumber_key;
        else if ([_sortBy isEqualToString:@"Item"])          sortkey = PInv_Item_key;
        else if ([_sortBy isEqualToString:@"Vendor"])        sortkey = PInv_Vendor_key;
        else if ([_sortBy isEqualToString:@"Batch Counter"]) sortkey = PInv_BatchCounter_key;
        else if ([_sortBy isEqualToString:@"Product Name"])  sortkey = PInv_ProductName_key;
        else if ([_sortBy isEqualToString:@"Local"])         sortkey = PInv_Local_key;
        else if ([_sortBy isEqualToString:@"Processed"])     sortkey = PInv_Processed_key;
        else if ([_sortBy isEqualToString:@"Quantity"])      sortkey = PInv_Quantity_key;
        else if ([_sortBy isEqualToString:@"Price"])         sortkey = PInv_PricePerUOM_key;
        else if ([_sortBy isEqualToString:@"Total"])         sortkey = PInv_TotalPrice_key;
    }
    if (_sortAscending)
        [query orderByAscending:sortkey];  //Sort UP
    else
        [query orderByDescending:sortkey]; //Sort Down
    //Special Selects...
    if (![_selectBy isEqualToString:@"*"]) [query whereKey:_selectBy equalTo:_selectValue];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) { //Query came back...
            [self->_expos        removeAllObjects];
            for( PFObject *pfo in objects)
            {
                [self handleCSVAdd : dumptoCSV : [self getCSVFromObject : pfo : FALSE]];
                EXPObject *e = [self getEXPObjectFromPFObject:pfo];
                [self->_expos addObject: e];
            }
            if (self->_parentUp) [self.delegate didReadEXPTableAsStrings : self->EXPDumpCSVList];
        }
    }];
} //end readFromParseAsStrings


#define LIMIT_SIZE 100
//=============(EXPTable)=====================================================
// Loads in data LIMIT_SIZE recs at a time, uses "skip" for re=entrant call
-(void) readFullTableToCSV : (int) skip : (BOOL) addErrStatus : (NSString*)batchID
{
    if (skip == 0) //Start? Clear CSVList and add header
    {
        [csvList removeAllObjects];
        NSString *header = @"CATEGORY,Month,Item,Quantity,Unit Of Measure,BULK/ INDIVIDUAL PACK,Vendor Name, Total Price ,PRICE/ UOM,PROCESSED ,Local (L),Invoice Date,Line #,Invoice #";
        if (addErrStatus) header = [header stringByAppendingString:@",ErrStatus"];
        [csvList addObject:header];
    }
    PFQuery *query = [PFQuery queryWithClassName:tableName]; //3/20
    if (![batchID isEqualToString:@"*"]) [query whereKey:PInv_BatchID_key equalTo:batchID];
    if (debugMode) NSLog(@" read %d to %d",skip,skip+LIMIT_SIZE);
    query.skip = skip;
    query.limit = LIMIT_SIZE;
    [query orderByAscending : PInv_BatchCounter_key]; //3/29

    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            for( PFObject *pfo in objects)
            {
                [self->csvList addObject : [self getCSVFromObject : pfo : addErrStatus]];
            }
            if (objects.count == LIMIT_SIZE) //Maybe more?
            {
                [self readFullTableToCSV : skip+LIMIT_SIZE : addErrStatus : batchID];
            }
            else
            {
                self->EXPDumpCSVList = [self->csvList componentsJoinedByString:@"\n"];
                if (self->debugMode) NSLog(@" got %lu recs ",(unsigned long)self->csvList.count);
                if (self->_parentUp) [self.delegate didReadFullTableToCSV : self->EXPDumpCSVList];
            }
        }
        else
        {
            if (self->_parentUp) [self.delegate errorReadingFullTableToCSV : error.localizedDescription];
        }
    }];
} //end readFullTableToCSV

//=============(EXPTable)=====================================================
// 1/14 assumes CSV table loaded during last parse read...
-(NSString *) dumpToCSV
{
    return EXPDumpCSVList;
}

//=============(EXPTable)=====================================================
-(void) readFromParse : (NSString *) invoiceNumberstring
{
    
}

//=============(EXPTable)=====================================================
// lastPage flag indicates we are ready to do invoice after all EXPs are saved.
//  then a delegate callback tells parent when all object ID's are ready for invoice
-(void) saveToParse : (int) page :  (BOOL) lastPage
{
    if (debugMode) NSLog(@" ET savetoparse page %d last %d etcount %d",page,lastPage,(int)_expos.count);
    if (_expos.count < 1)
    {
        if (self->_parentUp) [self.delegate didSaveEXPTable : nil]; //Trigger next page..
        return; //Nothing to write!
    }
    int i=0;
    //Clear any old junk from past EXP save...
    if (debugMode) NSLog(@" SENT count for page %d is %d total is %d lp %d",page,sentCounts[page],totalSentCount,lastPage);
    for (EXPObject *exo in _expos)
    {
        PFObject *exoRecord = [PFObject objectWithClassName:tableName];
        exoRecord[PInv_Category_key]            = exo.category;
        exoRecord[PInv_Month_key]               = exo.month;
        exoRecord[PInv_Item_key]                = exo.item;
        exoRecord[PInv_UOM_key]                 = exo.uom;
        exoRecord[PInv_Bulk_or_Individual_key]  = exo.bulk;
        exoRecord[PInv_Vendor_key]              = exo.vendor;
        exoRecord[PInv_ProductName_key]         = exo.productName;
        exoRecord[PInv_Processed_key]           = exo.processed;
        exoRecord[PInv_Local_key]               = exo.local;
        exoRecord[PInv_Date_key]                = exo.expdate; //ONLY column that ain't a String!
        exoRecord[PInv_LineNumber_key]          = exo.lineNumber;
        exoRecord[PInv_InvoiceNumber_key]       = exo.invoiceNumber;
        exoRecord[PInv_Quantity_key]            = exo.quantity;
        exoRecord[PInv_TotalPrice_key]          = exo.total;
        exoRecord[PInv_PricePerUOM_key]         = exo.pricePerUOM;
        exoRecord[PInv_ErrStatus_key]           = exo.errStatus;
        exoRecord[PInv_PDFFile_key]             = exo.PDFFile;
        exoRecord[PInv_Page_key]                = exo.page;
        exoRecord[PInv_BatchID_key]             = exo.batch;
        exoRecord[PInv_BatchCounter_key]        = exo.batchCounter;
        exoRecord[PInv_VersionNumber]           = _versionNumber;
        totalSentCount++; //DHS 2/5

        if (debugMode) NSLog(@"EXP ->parse [%@] %@ x %@ = %@",exo.productName,exo.quantity,exo.pricePerUOM,exo.total);
        [exoRecord saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
            if (succeeded) {
                NSString *objID = exoRecord.objectId;
                [self->objectIDs addObject:objID];
                //self->returnCounts[page]++;
                self->totalReturnCount++;
                if (self->debugMode) NSLog(@" ...EXP[%d/%d] [%@/%@]->parse",self->totalReturnCount,self->totalSentCount,exo.vendor,exo.productName);
                //NSLog(@" ...  EXP: ids %@",self->objectIDs);
                //NSLog(@" for page[%d] sent %d return %d",page,self->sentCounts[page],self->returnCounts[page]);
                //NSLog(@" for page[%d] totalsent %d totalreturn %d",page,self->totalSentCount,self->totalReturnCount);
                if (self->totalReturnCount == self->totalSentCount)
                {
                    if (self->_parentUp) [self.delegate didSaveEXPTable : self->objectIDs];
                    if (lastPage)
                        if (self->_parentUp) [self.delegate didFinishAllEXPRecords : self->totalSentCount : self->objectIDs];

                }
                NSString *fieldErr = [exoRecord objectForKey:PInv_ErrStatus_key];
                if (fieldErr.length > 4) //may be blank or OK
                    if (self->_parentUp) [self.delegate errorInEXPRecord : fieldErr : objID :
                     [exoRecord objectForKey: PInv_ProductName_key]];
            } else {
                if (self->_parentUp) [self.delegate errorSavingEXPToParse : error.localizedDescription]; //2/10
            }
        }];
        i++;
    } //end for loop
} //end saveToParse

//=============(EXPTable)=====================================================
// WARNING: overrides original table name!  
-(void) setTableName : (NSString *)newName
{
    tableName = newName;
}

//=============(EXPTable)=====================================================
// 3/20 WARNING: overrides original table name!
-(void) setTableNameForCurrentCustomer  
{
    AppDelegate *eappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    tableName = [NSString stringWithFormat:@"EXP_%@",eappDelegate.selectedCustomer];
    //NSLog(@"   set EXP Table: %@",tableName);
}


@end

