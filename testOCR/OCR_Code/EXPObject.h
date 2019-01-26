//
//   _______  ______   ___  _     _           _
//  | ____\ \/ /  _ \ / _ \| |__ (_) ___  ___| |_
//  |  _|  \  /| |_) | | | | '_ \| |/ _ \/ __| __|
//  | |___ /  \|  __/| |_| | |_) | |  __/ (__| |_
//  |_____/_/\_\_|    \___/|_.__// |\___|\___|\__|
//                             |__/
//
//  EXPObject.h
//  testOCR
//
//  Created by Dave Scruton on 12/17/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface EXPObject : NSObject
{

}


@property (nonatomic , strong) NSDate* expdate;
@property (nonatomic , strong) NSString* objectId;
@property (nonatomic , strong) NSString* category;
@property (nonatomic , strong) NSString* month;
@property (nonatomic , strong) NSString* item;
@property (nonatomic , strong) NSString* uom;
@property (nonatomic , strong) NSString* bulk;
@property (nonatomic , strong) NSString* vendor;
@property (nonatomic , strong) NSString* productName;
@property (nonatomic , strong) NSString* processed;
@property (nonatomic , strong) NSString* local;
@property (nonatomic , strong) NSString* lineNumber;
@property (nonatomic , strong) NSString* invoiceNumber;
@property (nonatomic , strong) NSString* quantity;
@property (nonatomic , strong) NSString* total;
@property (nonatomic , strong) NSString* pricePerUOM;
@property (nonatomic , strong) NSString* batch;
@property (nonatomic , strong) NSString* errStatus;
@property (nonatomic , strong) NSString* PDFFile;
@property (nonatomic , strong) NSString* versionNumber;
@property (nonatomic , strong) NSNumber* page;
@property (nonatomic , strong) NSString* batchCounter;



-(void) dump;

@end
