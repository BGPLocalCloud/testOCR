//
//   _                 _           ___  _     _           _
//  (_)_ ____   _____ (_) ___ ___ / _ \| |__ (_) ___  ___| |_
//  | | '_ \ \ / / _ \| |/ __/ _ \ | | | '_ \| |/ _ \/ __| __|
//  | | | | \ V / (_) | | (_|  __/ |_| | |_) | |  __/ (__| |_
//  |_|_| |_|\_/ \___/|_|\___\___|\___/|_.__// |\___|\___|\__|
//                                          |__/
//
//  invoiceObject.h
//  testOCR
//
//  Created by Dave Scruton on 12/17/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface invoiceObject : NSObject
{
}
@property (nonatomic , strong) NSDate* date;
@property (nonatomic , strong) NSString* objectID;
@property (nonatomic , strong) NSString* expObjectID;
@property (nonatomic , strong) NSString* invoiceNumber;
@property (nonatomic , strong) NSString* customer;
@property (nonatomic , strong) NSString* batchID;
@property (nonatomic , strong) NSString* vendor;


@end


