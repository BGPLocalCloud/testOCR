//
//   _______  ______   ___  _     _           _
//  | ____\ \/ /  _ \ / _ \| |__ (_) ___  ___| |_
//  |  _|  \  /| |_) | | | | '_ \| |/ _ \/ __| __|
//  | |___ /  \|  __/| |_| | |_) | |  __/ (__| |_
//  |_____/_/\_\_|    \___/|_.__// |\___|\___|\__|
//                             |__/
//
//  EXPObject.m
//  testOCR
//
//  Created by Dave Scruton on 12/17/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import "EXPObject.h"

@implementation EXPObject

//DHS 1/23-----------------------
-(void) dump
{
    NSLog(@" dump ExpObject-------");
    NSLog(@"  ID %@ Date %@",_objectId,_expdate);
    NSLog(@"  cat %@ mon %@ item %@",_category,_month,_item);
    NSLog(@"  uom %@ bulk %@ vendor %@",_uom,_bulk,_vendor);
    NSLog(@"  pname %@ processed %@ local %@",_productName,_processed,_local);
    NSLog(@"  cat %@ mon %@ item %@",_category,_month,_item);
    NSLog(@"  line %@ invoice %@ quantity %@",_lineNumber,_invoiceNumber,_quantity);
    NSLog(@"  total %@ price %@ batch %@",_total,_pricePerUOM,_batch);
    NSLog(@"  err %@ pdf %@ page %@",_errStatus,_PDFFile,_page);
}
@end
