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
-(instancetype) init
{
    if (self = [super init])
    {
        parseObjects = [[NSMutableArray alloc] init];
    }
    return self;
}

//=============(GenParse)=====================================================
// vendor = * means all
-(void) deleteAllByTableAndKey : (NSString *)tableName  : (NSString *)key   : (NSString *)kval
{
    [self deleteRows:0 :tableName :key :kval];
    return;
#ifdef OLDSTUFF
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
#endif
} //end deleteAllByTableAndKey

//=============(GenParse)=====================================================
//  3/20 WUPS. didn't handle large tables! this should do it...
-(void) deleteRows : (int) skip :  (NSString *)tableName  : (NSString *)key   : (NSString *)kval
{
    if (skip == 0) [parseObjects removeAllObjects];
    PFQuery *query = [PFQuery queryWithClassName:tableName];
    query.skip  = skip;
    query.limit = 100;
    //NSLog(@" dr skip %d",skip);
    //Wildcard? Don't select any vendor...
    if (![key isEqualToString:@"*"]) [query whereKey:key equalTo:kval];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            [self->parseObjects addObjectsFromArray:objects];
            if (objects.count == 100) //Just another block?go for more
            {
                [self deleteRows:skip+100 :tableName :key :kval];
            }
            else //Last bit? time for delete
            {
                [PFObject deleteAllInBackground:self->parseObjects block:^(BOOL succeeded, NSError * _Nullable error) {
                    [self.delegate didDeleteAllByTableAndKey : tableName : key : kval];
                    //NSLog(@" deleted %lu recs in %@ for %@=%@",
                    //      (unsigned long)self->parseObjects.count,tableName,key,kval);
                }];
            }
        }
        else {
            [self.delegate errorDeletingAllByTableAndKey  : tableName : key : kval];
            //NSLog(@"Error: %@ %@", error, [error userInfo]);
        }
    }];

} //end deleteRows


@end
