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

#import "invoiceTable.h"

@implementation invoiceTable

//=============(invoiceTable)=====================================================
-(instancetype) init
{
    if (self = [super init])
    {
        iobjs = [[NSMutableArray alloc] init]; //Invoice Objects
        tableName = @"";
        recordStrings = [[NSMutableArray alloc] init]; //Invoice string results
       // bbb = [BatchObject sharedInstance];

        _versionNumber    = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
    }
    return self;
}

//=============(invoiceTable)=====================================================
-(void) clear
{
    [iobjs removeAllObjects];
}

//=============(invoiceTable)=====================================================
-(void) addInvoiceItemByObjectID:(NSString *)oid
{
    //Overkill: this object only has one field for now...
    //NSLog(@" add invoice iod %@",oid);
    invoiceObject *io = [[invoiceObject alloc] init];
    io.objectID = oid;
    [iobjs addObject: io];
}

//=============(invoiceTable)=====================================================
-(int) getItemCount
{
    return (int)iobjs.count;
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
    [iobjs removeAllObjects];
    NSArray *sitems =  [packedOIDs componentsSeparatedByString:@","];
    for (NSString *s in sitems)
    {
        invoiceObject *io = [[invoiceObject alloc] init];
        io.objectID = s;
        [iobjs addObject:io];
    }
} //end unpackInvoiceOids

//=============(invoiceTable)=====================================================
-(void) packInvoiceOids
{
    packedOIDs =  @"";
    int i = 0;
    for (invoiceObject *io in iobjs)
    {
        packedOIDs = [packedOIDs stringByAppendingString:io.objectID];
        if (i < iobjs.count-1)
            packedOIDs = [packedOIDs stringByAppendingString:@","];
        i++;
    }
    
} //end packInvoiceOids

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
                self->_idate         = pfo[PInv_Date_key];
                self->_inumber       = pfo[PInv_InvoiceNumber_key];
                self->_icustomer     = pfo[PInv_CustomerKey];
                self->_ivendor       = pfo[PInv_Vendor_key];
                self->_versionNumber = pfo[PInv_VersionNumber];
                self->packedOIDs     = pfo[PInv_EXPObjectID_key];
                [self unpackInvoiceOids];
            }
            [self->_delegate didReadInvoiceTable];
        }
    }];
    
} //end readFromParse

//=============(invoiceTable)=====================================================
//Reads all invoices, packs to strings for now
-(void) readFromParseAsStrings : (NSString *)vendor  : batch
{
    [self setupVendorTableName:vendor];
    if (tableName.length < 1) return; //No table name!
    PFQuery *query = [PFQuery queryWithClassName:tableName];
    //Wildcards means get everything...
    if (![batch isEqualToString:@"*"])  [query whereKey:@"BatchID" equalTo:batch];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) { //Query came back...
            [self->recordStrings removeAllObjects];
            [self->iobjs removeAllObjects];
            for( PFObject *pfo in objects) //Should only be one?
            {
                invoiceObject *iobj = [[invoiceObject alloc] init];
                iobj.objectID       = iobj.objectID;
                iobj.date           = [pfo objectForKey:PInv_Date_key];
                iobj.expObjectID    = [pfo objectForKey:PInv_EXPObjectID_key];
                iobj.invoiceNumber  = [pfo objectForKey:PInv_InvoiceNumber_key];
                iobj.customer       = [pfo objectForKey:PInv_CustomerKey];
                iobj.batchID        = [pfo objectForKey:PInv_BatchID_key];
                iobj.vendor         = vendor;
                [self->iobjs addObject:iobj];

                NSDate *date = pfo[PInv_Date_key];
                NSString *ds = [self getDateAsString:date];
                NSString*s = [NSString stringWithFormat:@"[%@](%@):%@",ds,pfo[PInv_InvoiceNumber_key],pfo[PInv_CustomerKey]];
                [self->recordStrings addObject:s];
            }
            [self->_delegate didReadInvoiceTableAsStrings:self->iobjs];
        }
    }];
    
} //end readFromParse


//=============(invoiceTable)=====================================================
-(void) saveToParse
{
    if (tableName.length < 1) return; //No table name!
    [self packInvoiceOids]; //Set up packedOIDs string
    AppDelegate *iappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    PFObject *iRecord = [PFObject objectWithClassName:tableName];
    iRecord[PInv_Date_key]          = _idate;
    iRecord[PInv_InvoiceNumber_key] = _inumber;
    iRecord[PInv_CustomerKey]       = _icustomer;
    iRecord[PInv_Vendor_key]        = _ivendor;
    iRecord[PInv_EXPObjectID_key]   = packedOIDs;
    iRecord[PInv_BatchID_key]       = iappDelegate.batchID;
    iRecord[PInv_VersionNumber]     = _versionNumber;
    //NSLog(@" itable savetoParse...");
    [iRecord saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            NSLog(@" ...invoiceTable [vendor:%@]->parse",self->_ivendor);
            //NSString *objID = iRecord.objectId;
            // HMM this is broken. maybe we need to use NSNotification to send
            //  objectID's across objects over to the batchObject singleton.
            //AppDelegate *gappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            //[gappDelegate.bbb addOID:objID : self->tableName]; //Links current batcself->h to this record
            [self.delegate didSaveInvoiceTable:self->_inumber];
        } else {
            NSLog(@" ERROR: saving invoice: %@",error.localizedDescription);
        }
    }];
} //end saveToParse

//=============(invoiceTable)=====================================================
-(void) setBasicFields : (NSDate *) ddd : (NSString*)num : (NSString*)total : (NSString*)vendor : (NSString*)customer
{
    _idate  = ddd;
    _inumber    = num;
    _itotal     = total;
    _ivendor    = vendor;
    _icustomer  = customer;
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
//    NSString *r = @"Invoice Parsed Results\n";
//    r = [r stringByAppendingString:
//         [NSString stringWithFormat:@"Supplier %@\n",invoiceSupplier]];
//    r = [r stringByAppendingString:
//         [NSString stringWithFormat: @"Number %d  Date %@\n",invoiceNumber,invoiceDate]];
//    r = [r stringByAppendingString:
//         [NSString stringWithFormat:@"Customer %@  Total %f\n",invoiceCustomer,invoiceTotal]];
//    r = [r stringByAppendingString:
//         [NSString stringWithFormat:@"Columns:%@\n",columnHeaders]];
//    r = [r stringByAppendingString:@"Invoice Rows:\n"];
//    for (NSString *rowi in rowItems)
//    {
//        r = [r stringByAppendingString:[NSString stringWithFormat:@"[%@]\n",rowi]];
//    }
//    NSLog(@"dump[%@]",r);
//    [self alertMessage:@"Invoice Dump" :r];
    
}
@end
