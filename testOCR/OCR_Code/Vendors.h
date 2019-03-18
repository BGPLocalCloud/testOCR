//
//  __     __             _
//  \ \   / /__ _ __   __| | ___  _ __ ___
//   \ \ / / _ \ '_ \ / _` |/ _ \| '__/ __|
//    \ V /  __/ | | | (_| | (_) | |  \__ \
//     \_/ \___|_| |_|\__,_|\___/|_|  |___/
//
//  Vendors.h
//  
//  Created by Dave Scruton on 12/21/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
//  3/6 replace multiple arrays with array of VendorObjects
//
#import <Foundation/Foundation.h>
#import <Parse/Parse.h>
#import <UIKit/UIKit.h>
#import "DBKeys.h"
#import "VendorObject.h"

@protocol VendorsDelegate;

#define MAX_POSSIBLE_VENDORS 16

@interface Vendors : NSObject
{
    NSMutableArray* vNamesLC;
    VendorObject* vo;
}
@property (nonatomic , strong) NSMutableArray* vobjs;
@property (nonatomic , strong) NSMutableArray* vFileCounts;
@property (nonatomic , assign) BOOL loaded;
@property (nonatomic , assign) int  vcount;

@property (nonatomic, unsafe_unretained) id <VendorsDelegate> delegate; // receiver of completion messages

+ (id)sharedInstance;
-(NSString *) getFolderName : (NSString *)vmatch;
-(NSString *) getNameByIndex : (int)index;
-(NSString *) getFoldernameByIndex : (int)index;
-(NSString *) getRotationByIndex : (int)index;
-(NSString *) getIntQuantityByIndex : (int)index;
-(NSString *) getTLAnchorByVendor : (NSString *)vmatch;
-(NSString *) getTRAnchorByVendor : (NSString *)vmatch;
-(int)  getVendorIndex : (NSString *)vname;
-(void) readFromParse;
-(int) stringHasVendorName : (NSString *)s;
-(NSString *) getRotationByVendorName : (NSString *)vname;
@end

@protocol VendorsDelegate <NSObject>
@required
@optional
-(void) didReadVendorsFromParse;
-(void) errorReadingVendorsFromParse;
@end

