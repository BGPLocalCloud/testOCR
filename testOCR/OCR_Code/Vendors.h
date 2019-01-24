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

#import <Foundation/Foundation.h>
#import <Parse/Parse.h>
#import <UIKit/UIKit.h>
#import "DBKeys.h"

@protocol VendorsDelegate;

#define MAX_POSSIBLE_VENDORS 16

@interface Vendors : NSObject
{
    
}
@property (nonatomic , strong) NSMutableArray* vNames;
@property (nonatomic , strong) NSMutableArray* vFolderNames;
@property (nonatomic , strong) NSMutableArray* vRotations;
@property (nonatomic , strong) NSMutableArray* vFileCounts;
@property (nonatomic , assign) BOOL loaded;

@property (nonatomic, unsafe_unretained) id <VendorsDelegate> delegate; // receiver of completion messages

+ (id)sharedInstance;
-(NSString *) getFolderName : (NSString *)vmatch;
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

