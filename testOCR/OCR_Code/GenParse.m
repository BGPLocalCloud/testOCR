//
//    ____            ____
//   / ___| ___ _ __ |  _ \ __ _ _ __ ___  ___
//  | |  _ / _ \ '_ \| |_) / _` | '__/ __|/ _ \
//  | |_| |  __/ | | |  __/ (_| | |  \__ \  __/
//   \____|\___|_| |_|_|   \__,_|_|  |___/\___|
//
//  GenParse.m
//  testOCR
//
//  Created by Dave Scruton on 1/29/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
//  Maybe move in more general stuff?? from expTable, invTable, etc

#import "GenParse.h"

@implementation GenParse

//=============(GenParse)=====================================================
// vendor = * means all
-(void) deleteAllByTableAndKey : (NSString *)tableName  : (NSString *)key   : (NSString *)kval
{
    PFQuery *query = [PFQuery queryWithClassName:tableName];
    //Wildcard? Don't select any vendor...
    if (![key isEqualToString:@"*"]) [query whereKey:key equalTo:kval];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            [PFObject deleteAllInBackground:objects block:^(BOOL succeeded, NSError * _Nullable error) {
                [self.delegate didDeleteAllByTableAndKey : tableName : key : kval];
                //NSLog(@" deleted recs in %@ for %@=%@",tableName,key,kval);
            }];
        }
        else {
            [self.delegate errorDeletingAllByTableAndKey  : tableName : key : kval];
            NSLog(@"Error: %@ %@", error, [error userInfo]);
        }
    }];
} //end deleteObjectsByVendor


@end
