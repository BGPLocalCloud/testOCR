//
//    ____      _    ___  _     _           _
//   / ___|__ _| |_ / _ \| |__ (_) ___  ___| |_
//  | |   / _` | __| | | | '_ \| |/ _ \/ __| __|
//  | |__| (_| | |_| |_| | |_) | |  __/ (__| |_
//   \____\__,_|\__|\___/|_.__// |\___|\___|\__|
//                            |__/
//
//  Created by Dave Scruton on 12/19/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import "CatObject.h"

@implementation CatObject

- (id) initWithCategory : (NSString*) c : (NSString*) i : (NSString*) p : (NSString*) l : (NSString*) u
{
    if (self = [super init])
    {
        _category  = c.lowercaseString;
        //Items with commas have colons replacing commas in the data file, to avoid CSV confusion...
        //  restore commas here
        _item      = [i.lowercaseString stringByReplacingOccurrencesOfString:@":" withString:@","];
        _processed = p.lowercaseString;
        _local     = l.lowercaseString;
        _uom       = u.lowercaseString;
        if ([_processed isEqualToString:@"processed"])
        {
            _isProcessed = TRUE;
            _processed   = @"PROCESSED";
        }
        else if ([_processed isEqualToString:@"unprocessed"])
        {
            _isProcessed = FALSE;
            _processed   = @"UNPROCESSED";
        }
        else if ([_processed isEqualToString:@"n/a"])
        {
            _isProcessed = FALSE;
            _processed   = @"N/A";
        }
        else //Bad data from CSV?
            NSLog(@" bogus CSV processed entry :%@",_item);

        //Local or imported?
        if ([_local isEqualToString:@"yes"])
        {
            _isLocal = TRUE;
            _local   = @"YES";
        }
        else if ([_local isEqualToString:@"no"])
        {
            _isLocal = FALSE;
            _local   = @"NO";
        }
        else if ([_local isEqualToString:@"n/a"])
        {
            _isLocal = FALSE;
            _local   = @"N/A";
        }
        else //Bad data from CSV?
            NSLog(@" bogus CSV local entry :%@",_item);

    }
    return self;
}




@end
