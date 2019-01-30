//
//  GenParse.m
//  testOCR
//
//  Created by Dave Scruton on 1/29/19.
//  Copyright © 2019 huedoku. All rights reserved.
//

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
            [PFObject deleteAllInBackground:objects];
            [self.delegate didDeleteAllByTableAndKey : tableName : key : kval];
            NSLog(@" deleted recs in %@ for %@=%@",tableName,key,kval);
        }
        else {
            [self.delegate errorDeletingAllByTableAndKey  : tableName : key : kval];
            NSLog(@"Error: %@ %@", error, [error userInfo]);
        }
    }];
} //end deleteObjectsByVendor


@end
