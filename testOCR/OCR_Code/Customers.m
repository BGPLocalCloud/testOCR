//
//    ____          _
//   / ___|   _ ___| |_ ___  _ __ ___   ___ _ __ ___
//  | |  | | | / __| __/ _ \| '_ ` _ \ / _ \ '__/ __|
//  | |__| |_| \__ \ || (_) | | | | | |  __/ |  \__ \
//   \____\__,_|___/\__\___/|_| |_| |_|\___|_|  |___/
//
//  Customers.m
//  testOCR
//
//  Created by Dave Scruton on 3/13/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import "Customers.h"

@implementation Customers

static Customers *sharedInstance = nil;


//=============(Customers)=====================================================
// Get the shared instance and create it if necessary.
+ (Customers *)sharedInstance {
    if (sharedInstance == nil) {
        sharedInstance = [[super allocWithZone:NULL] init];
    }
    
    return sharedInstance;
}

//=============(Customers)=====================================================
-(instancetype) init
{
    if (self = [super init])
    {
        _customerNames      = [[NSMutableArray alloc] init]; // Customer names
        _fullNames          = [[NSMutableArray alloc] init]; // Customer names
        _ccount             = 0;
        _loaded             = FALSE;
        [self readFromParse];
    }
    return self;
}

//=============(Customers)=====================================================
-(NSString *) getNameByIndex : (int)index
{
    if (index < 0 || index >= _customerNames.count) return @"";
    return _customerNames[index];
} //end getNameByIndex


//=============(Customers)=====================================================
-(void) readFromParse
{
    if (_loaded) return; //No need to do 2x
    PFQuery *query = [PFQuery queryWithClassName:@"Customers"];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) { //Query came back...
            if (objects == nil || objects.count < 1)
            {
                NSLog(@" ERROR READING Vendors from DB!");
                [self.delegate errorReadingCustomersFromParse];
                return;
            }
            [self->_customerNames removeAllObjects];
            self->_ccount = 0;
            [self->_fullNames removeAllObjects];
            for( PFObject *pfo in objects)  //Save all our customer names...
            {
                [self->_customerNames addObject: [pfo objectForKey:PInv_CustomerName_key]];
                [self->_fullNames     addObject: [pfo objectForKey:PInv_FullName_key]];
                self->_ccount++;
            }
            //NSLog(@" ...loaded all customers");
            self->_loaded = TRUE;
            [self.delegate didReadCustomersFromParse];
        }
    }];
} //end readFromParse

@end
