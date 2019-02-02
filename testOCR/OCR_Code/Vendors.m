//
//  __     __             _
//  \ \   / /__ _ __   __| | ___  _ __ ___
//   \ \ / / _ \ '_ \ / _` |/ _ \| '__/ __|
//    \ V /  __/ | | | (_| | (_) | |  \__ \
//     \_/ \___|_| |_|\__,_|\___/|_|  |___/
//
//  Vendors.m
//  
//
//  Created by Dave Scruton on 12/21/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import "Vendors.h"

@implementation Vendors
static Vendors *sharedInstance = nil;


//=============(Vendors)=====================================================
// Get the shared instance and create it if necessary.
+ (Vendors *)sharedInstance {
    if (sharedInstance == nil) {
        sharedInstance = [[super allocWithZone:NULL] init];
    }
    
    return sharedInstance;
}

//=============(Vendors)=====================================================
-(instancetype) init
{
    if (self = [super init])
    {
        _vNames       = [[NSMutableArray alloc] init]; // Vendor names
        _vFolderNames = [[NSMutableArray alloc] init]; //  and matching folder names
        _vRotations   = [[NSMutableArray alloc] init]; //  invoices rotated?
        _vFileCounts  = [[NSMutableArray alloc] init]; //  runtime filecounts of PDF/CSV's to process
        vNamesLC      = [[NSMutableArray alloc] init]; // Vendor names
        _loaded       = FALSE;
        [self readFromParse];
    }
    return self;
}

//=============(Vendors)=====================================================
-(NSString *) getFolderName : (NSString *)vmatch
{
    NSInteger n = [_vNames indexOfObject:vmatch];
    if (n != NSNotFound) return [_vFolderNames objectAtIndex:n];
    return @"";
}

//=============(Vendors)=====================================================
-(int)  getVendorIndex : (NSString *)vname
{
    NSString *vlc = vname.lowercaseString;
    int i=0;
    for (NSString *vn in vNamesLC)
    {
        if ([vlc containsString:vn]) return i;//Match?
        i++;
    }
    return 0;
}


//=============(Vendors)=====================================================
-(NSString *) getRotationByVendorName : (NSString *)vname
{
    NSUInteger index = [_vNames indexOfObject:vname];
    if (index == NSNotFound) return @"0";
    return [_vRotations objectAtIndex:index];
}


//=============(Vendors)=====================================================
-(void) readFromParse
{
    if (_loaded) return; //No need to do 2x
    PFQuery *query = [PFQuery queryWithClassName:@"Vendors"];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) { //Query came back...
            if (objects == nil || objects.count < 1)
            {
                NSLog(@" ERROR READING Vendors from DB!");
                [self.delegate errorReadingVendorsFromParse];
                return;
            }
            [self->_vNames       removeAllObjects];
            [self->_vFolderNames removeAllObjects];
            [self->_vRotations   removeAllObjects];
            for( PFObject *pfo in objects)  //Save all our vendor names...
            {
                NSString *s = [pfo objectForKey:PInv_Vendor_key];
                [self->_vNames addObject:s];
                [self-> vNamesLC addObject:s.lowercaseString]; //Strings to match by
                //Generate a legal filename, too, no whitespace, dots, apostrophes or commas...
                NSString *sf = [s  stringByReplacingOccurrencesOfString:@" " withString:@"_"];
                sf = [sf stringByReplacingOccurrencesOfString:@"." withString:@"_"];
                sf = [sf stringByReplacingOccurrencesOfString:@"," withString:@"_"];
                sf = [sf stringByReplacingOccurrencesOfString:@"\'" withString:@"_"];
                [self->_vFolderNames addObject:sf];
                [self->_vRotations addObject:[pfo objectForKey:PInv_Rotated_key]];
            }
            NSLog(@" ...loaded all vendors");
            self->_loaded = TRUE;
            [self.delegate didReadVendorsFromParse];
        }
    }];
} //end readFromParse

//=============(Vendors)=====================================================
// Return index if matching, -1 for no match
-(int) stringHasVendorName : (NSString *)s
{
    int i = 0;
    for (NSString *ts in _vNames)
    {
        if ([s.lowercaseString containsString:ts.lowercaseString]) return i;
        i++;
    }
    return -1;
} //end stringHasVendorName

@end
