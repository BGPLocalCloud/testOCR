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
        _sortBy = @"*";
        _selectBy = @"*";
        tableName = @"EXPFullTable";
        _versionNumber    = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
    }
    return self;
}

//=============(EXPTable)=====================================================
-(void) clear
{
    NSLog(@" EXP Clear");
    [_expos removeAllObjects];
    //Clear EXP send/return counts...
    totalSentCount = totalReturnCount = 0;
    allErrors = @"";
    for (int i=0;i<32;i++)  returnCounts[i] = 0;
    for (int i=0;i<256;i++) errorsByLineNumber[i] = @"";
}

#define PInv_Local_key @"Local"
#define PInv_LineNumber_key @"LineNumber"


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
    if (fdate == nil)       errstr = PInv_Date_key;
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
    batch       = [self TrackNilErrors : batch : PInv_Batch_key];
    errStatus   = [self TrackNilErrors : errStatus : PInv_ErrStatus_key];
    PDFFile     = [self TrackNilErrors : PDFFile : PInv_PDFFile_key];
    if (allErrors.length > 1) //Got error(s)?
    {
        NSLog(@"%@",allErrors);
//        return;
    }
    
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
    [_expos addObject:exo];
    
} //end addRecord

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
-(void) handleCSVInit : (BOOL) dumptoCSV
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
    e.batch             = pfo[PInv_Batch_key];
    e.errStatus         = pfo[PInv_ErrStatus_key];
    e.PDFFile           = pfo[PInv_PDFFile_key];
    e.page              = pfo[PInv_Page_key];
    e.versionNumber     = pfo[PInv_VersionNumber];
    e.objectId = pfo.objectId;
    return e;
} //end getEXPObjectFromPFObject

//=============(EXPTable)=====================================================
-(NSString *) getCSVFromObject : (PFObject *)pfo
{
    NSArray *sitems1 = [NSArray arrayWithObjects:
                        PInv_Category_key,PInv_Month_key,PInv_Quantity_key,PInv_Item_key,
                        PInv_UOM_key,PInv_Bulk_or_Individual_key,PInv_Vendor_key,PInv_TotalPrice_key,
                        PInv_PricePerUOM_key,PInv_Processed_key,PInv_Local_key,PInv_LineNumber_key,
                        PInv_InvoiceNumber_key,
                        nil];
    NSString *s = [self stringFromKeyedItems : pfo :sitems1];
    //Inject date into this mess (it's special!)
    NSDateFormatter * formatter =  [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"MM/dd/yy"];
    NSString *sfd = [formatter stringFromDate:[pfo objectForKey:PInv_Date_key]];
    s = [s stringByAppendingString:
         [NSString stringWithFormat:@"%@,",sfd]];
    NSArray *sitems2 = [NSArray arrayWithObjects:
                        PInv_LineNumber_key,PInv_InvoiceNumber_key,
                        nil];
    s = [s stringByAppendingString:
         [NSString stringWithFormat:@",%@",[self stringFromKeyedItems : pfo :sitems2]]];
    return s;
}

//=============OCR VC=====================================================
-(void) readFromParseByObjIDs : (BOOL) dumptoCSV : (NSString *)vendor : (NSString *)soids
{
    [self handleCSVInit:dumptoCSV];
    NSMutableArray *a = [[NSMutableArray alloc] init];
    NSArray *sitems =  [soids componentsSeparatedByString:@","];
    PFQuery *query = [PFQuery queryWithClassName:@"EXPFullTable"];
    for (NSString *s in sitems)  //incoming should look like X_OBJID,X_OBJID, etc
    {
        NSArray *s2 =  [s componentsSeparatedByString:@"_"];
        if (s2.count == 2)
        {
            NSString *oid = s2[1];  //THis should be the object ID
            [a addObject:oid];
            NSLog(@" .. fetch objid [%@]",oid);
            PFObject *pfo = [query getObjectWithId:oid];  //Fetch by object ID,
            [self handleCSVAdd : dumptoCSV : [self getCSVFromObject:pfo]];
        }
    }
    [self.delegate didReadEXPTableAsStrings : self->EXPDumpCSVList];
} //end readFromParseByObjIDs

//=============OCR VC=====================================================
-(void) fixPricesInObjectByID : (NSString *)oid : (NSString *)qt : (NSString *)pt : (NSString *)tt
{
    PFQuery *query = [PFQuery queryWithClassName:@"EXPFullTable"];
    PFObject *pfo = [query getObjectWithId:oid];  //Fetch by object ID,
    if (pfo != nil)
    {
        NSLog(@" fix field [%@] = %@ ",PInv_Quantity_key,qt);
        NSLog(@" fix field [%@] = %@ ",PInv_PricePerUOM_key,pt);
        NSLog(@" fix field [%@] = %@ ",PInv_TotalPrice_key,tt);
        [pfo setObject:qt forKey:PInv_Quantity_key];
        [pfo setObject:pt forKey:PInv_PricePerUOM_key];
        [pfo setObject:tt forKey:PInv_TotalPrice_key];
        [pfo saveInBackgroundWithBlock:^(BOOL succeeded, NSError * _Nullable error) {
            if (succeeded)
            {
                NSLog(@" update qpt OK objID %@",oid);
                [self.delegate didFixPricesInObjectByID : oid];
            }
            else
            {
                NSLog(@" error updating quantity/price/total oid %@",oid);
            }
        }];
    }
} //end fixPricesInObjectByID

//=============OCR VC=====================================================
-(void) fixFieldInObjectByID : (NSString *)oid : (NSString *)key : (NSString *)value
{
    PFQuery *query = [PFQuery queryWithClassName:@"EXPFullTable"];
    PFObject *pfo = [query getObjectWithId:oid];  //Fetch by object ID,
    if (pfo != nil)
    {
        NSLog(@" fix field [%@] = %@ ",key,value);
        [pfo setObject:value forKey:key];
        [pfo saveEventually]; //No Hurry, just assume the DB is fast enough
    }
}


//=============OCR VC=====================================================
//BROKEN! DOESN'T WORK! can't set IDs for some reason?
-(void) getObjectsByIDs : (NSArray *)oids
{
    NSLog(@" gobi %@",oids);
    if (oids == nil || oids.count < 1) return;
    PFQuery *query = [PFQuery queryWithClassName:@"EXPFullTable"];
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
            }
            [self.delegate didGetObjectsByIds : d];
        }
    }];


}


//=============OCR VC=====================================================
-(void) getObjectByID : (NSString *)oid
{
    PFQuery *query = [PFQuery queryWithClassName:@"EXPFullTable"];
    PFObject *pfo = [query getObjectWithId:oid];  //Fetch by object ID,
    if (pfo != nil)
    {
        EXPObject *e = [self getEXPObjectFromPFObject:pfo];
        [self.delegate didReadEXPObjectByID:e:pfo];
    }
} //end getObjectByID

//=============OCR VC=====================================================
-(void) readFromParseAsStrings : (BOOL) dumptoCSV : (NSString *)vendor : (NSString *)batch
{
    [self handleCSVInit:TRUE];
    PFQuery *query = [PFQuery queryWithClassName:@"EXPFullTable"];
    //Wildcards means get everything...
    if (![vendor isEqualToString:@"*"]) [query whereKey:PInv_Vendor_key equalTo:vendor];
    if (![batch isEqualToString:@"*"])  [query whereKey:@"Batch" equalTo:batch];
    if (![_sortBy isEqualToString:@""]) NSLog(@"...sort EXP by %@",_sortBy);
    NSString *sortkey = @"createdAt";
    if (_sortBy != nil)
    {
        if ([_sortBy isEqualToString:@"Invoice Number"])    sortkey = PInv_InvoiceNumber_key;
        else if ([_sortBy isEqualToString:@"Item"])         sortkey = PInv_Item_key;
        else if ([_sortBy isEqualToString:@"Vendor"])       sortkey = PInv_Vendor_key;
        else if ([_sortBy isEqualToString:@"Vendor"])       sortkey = PInv_Vendor_key;
        else if ([_sortBy isEqualToString:@"Product Name"]) sortkey = PInv_ProductName_key;
        else if ([_sortBy isEqualToString:@"Local"])        sortkey = PInv_Local_key;
        else if ([_sortBy isEqualToString:@"Processed"])    sortkey = PInv_Processed_key;
        else if ([_sortBy isEqualToString:@"Quantity"])     sortkey = PInv_Quantity_key;
        else if ([_sortBy isEqualToString:@"Price"])        sortkey = PInv_PricePerUOM_key;
        else if ([_sortBy isEqualToString:@"Total"])        sortkey = PInv_TotalPrice_key;
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
                [self handleCSVAdd : dumptoCSV : [self getCSVFromObject:pfo]];
                EXPObject *e = [self getEXPObjectFromPFObject:pfo];
                [self->_expos addObject: e];
            }
            [self.delegate didReadEXPTableAsStrings : self->EXPDumpCSVList];
        }
    }];
} //end readFromParseAsStrings

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
    if (_expos.count < 1) return; //Nothing to write!
    int i=0;
    //Clear any old junk from past EXP save...
    if (page == 0)
    {
        [objectIDs removeAllObjects];
        for (int i=0;i<32;i++) sentCounts[i] = 0;
    }
    sentCounts[page]   = (int)_expos.count;
    returnCounts[page] = 0;
    if (lastPage) //Last page? Get a total of everything sent...
    {
        totalSentCount = 0;
        for (int i=0;i<32;i++) totalSentCount+=sentCounts[i];
    }
    AppDelegate *eappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
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
        exoRecord[PInv_Batch_key]               = exo.batch;
        exoRecord[PInv_ErrStatus_key]           = exo.errStatus;
        exoRecord[PInv_PDFFile_key]             = exo.PDFFile;
        exoRecord[PInv_Page_key]                = exo.page;
        exoRecord[PInv_BatchID_key]             = eappDelegate.batchID;
        exoRecord[PInv_VersionNumber]           = _versionNumber;
        //NSLog(@"EXP ->parse [%@] %@ x %@ = %@",exo.productName,exo.quantity,exo.pricePerUOM,exo.total);
        [exoRecord saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
            if (succeeded) {
                NSString *objID = exoRecord.objectId;
                [self->objectIDs addObject:objID];
                self->returnCounts[page]++;
                self->totalReturnCount++;
                //NSLog(@" ...EXP[%d] [%@/%@]->parse",i,exo.vendor,exo.productName);
                //NSLog(@" ...  EXP: ids %@",self->objectIDs);
                //NSLog(@" for page[%d] sent %d return %d",page,self->sentCounts[page],self->returnCounts[page]);
                //NSLog(@" for page[%d] totalsent %d totalreturn %d",page,self->totalSentCount,self->totalReturnCount);
                if (self->returnCounts[page] == self->sentCounts[page]) //Finish this page?
                    [self.delegate didSaveEXPTable : self->objectIDs];
                if (lastPage)
                {
                    if (self->totalReturnCount == self->totalSentCount) //All done w/ everything?
                        [self.delegate didFinishAllEXPRecords : self->objectIDs];
                }
                NSString *fieldErr = [exoRecord objectForKey:PInv_ErrStatus_key];
                if (fieldErr.length > 4) //may be blank or OK
                    [self.delegate errorInEXPRecord : fieldErr : objID :
                     [exoRecord objectForKey: PInv_ProductName_key]];
            } else {
                NSLog(@" ERROR: saving EXP: %@",error.localizedDescription);
            }
        }];
        i++;
    } //end for loop
} //end saveToParse



@end

