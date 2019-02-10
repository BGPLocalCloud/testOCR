//
//   _                 _         _____     _     _
//  (_)_ ____   _____ (_) ___ __|_   _|_ _| |__ | | ___
//  | | '_ \ \ / / _ \| |/ __/ _ \| |/ _` | '_ \| |/ _ \
//  | | | | \ V / (_) | | (_|  __/| | (_| | |_) | |  __/
//  |_|_| |_|\_/ \___/|_|\___\___||_|\__,_|_.__/|_|\___|
//
//  invoiceTable.m
//  testOCR
//
//  Created by Dave Scruton on 12/17/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
// New columns? PDF source URL?  OCR'ed TextDump? is this useful?
// 2/5  cleanup, use invoiceObject instead of property list
// 2/7  add debugMode for logging, add EXPIDs
// 2/8  add invoiceNumber to readFromParseAsStrings
//  2/9 add parentUp flag to avoid delegate callback crashes on dismissed VC
#import "invoiceTable.h"

@implementation invoiceTable

//=============(invoiceTable)=====================================================
-(instancetype) init
{
    if (self = [super init])
    {
        //2/7 ObjectIDs = [[NSMutableArray alloc] init]; //Object IDS for one invoice
        invoiceObjects   = [[NSMutableArray alloc] init];
        EXPIDs           = [[NSMutableArray alloc] init];  //incoming work area for EXP object ids
        
        tableName = @"";
        recordStrings = [[NSMutableArray alloc] init]; //Invoice string results

        AppDelegate *iappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        debugMode = iappDelegate.debugMode; //2/7 For dwbug logging, check every batch

        _versionNumber    = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
        _iobj = [[invoiceObject alloc] init];
        _parentUp = TRUE;
    }
    return self;
}

//=============(invoiceTable)=====================================================
-(void) clearObjectIds
{
    [EXPIDs removeAllObjects];
}

//=============(invoiceTable)=====================================================
-(void) addInvoiceItemByObjectID:(NSString *)oid
{
    //Overkill: this object only has one field for now...
//    if (debugMode) NSLog(@" add invoice iod %@",oid);
//    invoiceObject *io = [[invoiceObject alloc] init];
//    io.objectID = oid;
    [EXPIDs addObject: oid]; // 2/7
}

//=============(invoiceTable)=====================================================
-(int) getItemCount
{
    return (int)EXPIDs.count;
}


//=============(invoiceTable)=====================================================
// There is one table per vendor, its name comes from vendor name,
//  for example, "Hawaii Dawg" would be "I_Hawaii_Dawg".
// I is always there, and spaces are replaced with underbars
-(void) setupVendorTableName : (NSString *)vname
{
    NSString *v = [vname stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    tableName = [NSString stringWithFormat:@"I_%@",v];
}

//=============(invoiceTable)=====================================================
-(void) unpackInvoiceOids
{
    EXPIDs =  (NSMutableArray*)[packedOIDs componentsSeparatedByString:@","];
} //end unpackInvoiceOids

//=============(invoiceTable)=====================================================
-(void) packInvoiceOids
{ 
    packedOIDs = [EXPIDs componentsJoinedByString:@","];
} //end packInvoiceOids

//=============(invoiceTable)=====================================================
-(invoiceObject*) packFromPFObject : (PFObject *)pfo
{
    _iobj.objectID       = pfo.objectId;
    _iobj.date           = [pfo objectForKey:PInv_Date_key];
    _iobj.packedEXPIDs   = [pfo objectForKey:PInv_EXPObjectID_key];
    _iobj.invoiceNumber  = [pfo objectForKey:PInv_InvoiceNumber_key];
    _iobj.itotal         = [pfo objectForKey:PInv_ITotal_Key];
    _iobj.customer       = [pfo objectForKey:PInv_CustomerKey];
    _iobj.batchID        = [pfo objectForKey:PInv_BatchID_key];
    _iobj.PDFFile        = [pfo objectForKey:PInv_PDFFile_key];
    _iobj.pageCount      = [pfo objectForKey:PInv_PageCount_key];
    _iobj.vendor         = [pfo objectForKey:PInv_Vendor_key];
    [self unpackInvoiceOids]; //asdf
    return _iobj;
} //end packFromPFObject


//=============(invoiceTable)=====================================================
//Reads one invoice, using vendor and number
-(void) readFromParse : (NSString *)vendor : (NSString *)invoiceNumberstring
{
    [self setupVendorTableName:vendor];
    if (tableName.length < 1) return; //No table name!
    PFQuery *query = [PFQuery queryWithClassName:tableName];
    [query whereKey:PInv_InvoiceNumber_key equalTo:invoiceNumberstring];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) { //Query came back...
            for( PFObject *pfo in objects) //Should only be one?
            {
                self.iobj = [self packFromPFObject:pfo];
                [self unpackInvoiceOids];
            }
            [self->_delegate didReadInvoiceTable];
        }
    }];
    
} //end readFromParse

//=============(invoiceTable)=====================================================
//Reads all invoices, packs to strings for now
-(void) readFromParseAsStrings : (NSString *)vendor  : batch : invoiceNumberstring
{
    [self setupVendorTableName:vendor];
    if (tableName.length < 1) return; //No table name!
    PFQuery *query = [PFQuery queryWithClassName:tableName];
    //Wildcards means get everything...
    if (![batch               isEqualToString:@"*"]) [query whereKey:PInv_BatchID_key equalTo:batch];
    if (![invoiceNumberstring isEqualToString:@"*"]) [query whereKey:PInv_InvoiceNumber_key equalTo:invoiceNumberstring];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) { //Query came back...
            [self->recordStrings removeAllObjects];
            [self->invoiceObjects removeAllObjects];
            for( PFObject *pfo in objects) //Should only be one?
            {
                invoiceObject *iobj = [self packFromPFObject:pfo];
                [self->invoiceObjects addObject:iobj];
                NSDate *date = pfo[PInv_Date_key];
                NSString *ds = [self getDateAsString:date];
                NSString*s = [NSString stringWithFormat:@"[%@](%@):%@",ds,pfo[PInv_InvoiceNumber_key],pfo[PInv_CustomerKey]];
                [self->recordStrings addObject:s];
            }
            [self->_delegate didReadInvoiceTableAsStrings:self->invoiceObjects];
        }
    }];
    
} //end readFromParse


//=============(invoiceTable)=====================================================
// Saves first page of new invoice...
-(void) saveToParse : (BOOL)lastPage
{
    if (tableName.length < 1) return; //No table name!
    [self packInvoiceOids]; //Set up packedOIDs string
    PFObject *iRecord = [PFObject objectWithClassName:tableName];
    iRecord[PInv_Vendor_key]        = _iobj.vendor;
    iRecord[PInv_Date_key]          = _iobj.date;
    iRecord[PInv_InvoiceNumber_key] = _iobj.invoiceNumber;
    iRecord[PInv_CustomerKey]       = _iobj.customer;
    iRecord[PInv_ITotal_Key]        = _iobj.itotal;
    iRecord[PInv_EXPObjectID_key]   = packedOIDs; // This was assembled from EXP record save results
    iRecord[PInv_BatchID_key]       = _iobj.batchID;
    iRecord[PInv_VersionNumber]     = _versionNumber;
    iRecord[PInv_PDFFile_key]       = _iobj.PDFFile;
    iRecord[PInv_PageCount_key]     = _iobj.pageCount;

    if (debugMode) NSLog(@" itable savetoParse...");
    [iRecord saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            if (self->debugMode) NSLog(@" ...invoice [vendor:%@]->parse",self->_iobj.vendor);
            //NSString *objID = iRecord.objectId;
            if (self->_parentUp) [self.delegate didSaveInvoiceTable:self->_iobj.invoiceNumber : lastPage];
        } else {
            NSLog(@" ERROR: saving invoice: %@",error.localizedDescription);
            if (self->_parentUp) [self.delegate errorSavingInvoiceTable:error.localizedDescription : lastPage];
        }
    }];
} //end saveToParse

//=============(invoiceTable)=====================================================
// Gets invoice, if not there creates object.
//   if it exists, updates PInv_EXPObjectID_key field with new info and saves
-(void) updateInvoice : (NSString *)vendor : (NSString *)invoiceNumberstring : (NSString *)batchID : (BOOL)lastPage
{
    if (debugMode) NSLog(@" updateInvoice %@ lastpage %d",invoiceNumberstring,lastPage);
    [self setupVendorTableName:vendor];
    if (tableName.length < 1) return; //Error: no table name!
    PFQuery *query = [PFQuery queryWithClassName:tableName];
    [query whereKey:PInv_InvoiceNumber_key equalTo:invoiceNumberstring]; //Match invoice #
    [query whereKey:PInv_BatchID_key equalTo:batchID]; //DHS 1/28 match batch too!
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) { //Query came back...
            if (objects.count == 0) [self saveToParse : lastPage];  //Nothing? Just save
            else for( PFObject *pfo in objects)         //Exists? Update first object
            {
                NSString *pcs = pfo[PInv_PageCount_key];
                int newCount = pcs.intValue + 1;                                      //Update pagecount;
                pfo[PInv_PageCount_key] = [NSString stringWithFormat:@"%d",newCount];//  and save it!
                if (self->debugMode) NSLog(@" update invoice %@ count %d",invoiceNumberstring,newCount);
                [self packInvoiceOids]; //Set up packedOIDs string
                NSString *oldOIDs    = pfo[PInv_EXPObjectID_key];
                NSString *newOIDs    = self->packedOIDs;
                newOIDs              = [NSString stringWithFormat:@"%@,%@",oldOIDs,newOIDs];
                pfo[PInv_EXPObjectID_key] = newOIDs;
                [pfo saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                    if (succeeded) {
                        if (self->debugMode) NSLog(@" ...update save OKI");
                        if (self->_parentUp) [self.delegate didUpdateInvoiceTable:invoiceNumberstring : lastPage];
                    } else {
                        NSLog(@" ERROR: updating invoice: %@",error.localizedDescription);
                        if (self->_parentUp) [self.delegate errorSavingInvoiceTable:error.localizedDescription : lastPage];
                    }
                }];
                break; //Done after one
            } //end else
        }    //end !error
    }];     //end query
} //end updateInvoice


//=============(invoiceTable)=====================================================
-(void) setBasicFields : (NSDate *) ddd : (NSString*)num : (NSString*)total :
                    (NSString*)vendor : (NSString*)customer : (NSString*)PDFFile : (NSString*)pageCount
{
    _iobj.date          = ddd;
    _iobj.itotal        = total;
    _iobj.invoiceNumber = num;
    _iobj.vendor        = vendor;
    _iobj.customer      = customer;
    _iobj.PDFFile       = PDFFile;
    _iobj.pageCount     = pageCount;
    //Main delegate knows what batch is running
    AppDelegate *iappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    _iobj.batchID       = iappDelegate.batchID;
} //end setBasicFields

//=============(invoiceTable)=====================================================
-(NSString *)getDateAsString : (NSDate *) ndate
{
    NSDateFormatter * formatter =  [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"MM/dd/yy"];
    //    [formatter setDateFormat:@"yyyy-MMM-dd HH:mm:ss"];
    NSString *dateString = [formatter stringFromDate:ndate];//pass the date you get from UIDatePicker
    return dateString;
}


//=============OCR VC=====================================================
// Hmm... to really dump we need data from exp to get full product info!
-(void) dump
{
    for (invoiceObject *iobj in invoiceObjects)
    {
        NSLog(@" Invoice #%@ / date %@",iobj.invoiceNumber,iobj.date);
        NSLog(@"   batchID  %@ objectID  %@",iobj.batchID,iobj.objectID);
        NSLog(@"   customer %@ vendor    %@",iobj.customer,iobj.vendor);
        NSLog(@"   PDFFile  %@ pageCount %@",iobj.PDFFile,iobj.pageCount);
        NSLog(@"   total    %@",iobj.itotal);
        NSLog(@"   EXPOIDs  %@",packedOIDs);
    }
} //end dump
@end
