//
//    ____          _
//   / ___|   _ ___| |_ ___  _ __ ___   ___ _ __ ___
//  | |  | | | / __| __/ _ \| '_ ` _ \ / _ \ '__/ __|
//  | |__| |_| \__ \ || (_) | | | | | |  __/ |  \__ \
//   \____\__,_|___/\__\___/|_| |_| |_|\___|_|  |___/
//
//  Customers.h
//  testOCR
//
//  Created by Dave Scruton on 3/13/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Parse/Parse.h>
#import <UIKit/UIKit.h>
#import "DBKeys.h"

@protocol CustomersDelegate;

@interface Customers : NSObject
{
    
}

@property (nonatomic, unsafe_unretained) id <CustomersDelegate> delegate; // receiver of completion messages
@property (nonatomic , assign) BOOL loaded;
@property (nonatomic , strong) NSMutableArray* customerNames;

+ (id)sharedInstance;


@end


@protocol CustomersDelegate <NSObject>
@required
@optional
-(void) didReadCustomersFromParse;
-(void) errorReadingCustomersFromParse;
@end

