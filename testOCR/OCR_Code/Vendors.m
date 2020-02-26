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
        _vobjs          = [[NSMutableArray alloc] init]; // Vendor names
        _vFileCounts    = [[NSMutableArray alloc] init]; // Vendor names
        _loaded         = FALSE;
        [self readFromParse];
    }
    return self;
}

//=============(Vendors)=====================================================
// Given vendor name, find appropriate folder name
-(NSString *) getFolderName : (NSString *)vmatch
{
    for (VendorObject *vvo in _vobjs)
    {
        if ([vvo.vName isEqualToString:vmatch]) return vvo.vFolderName;
    }
    return @"";
} //end getFolderName

//=============(Vendors)=====================================================
-(NSString *) getTLAnchorByVendor : (NSString *)vmatch
{
    for (VendorObject *vvo in _vobjs)
    {
        if ([vvo.vName isEqualToString:vmatch]) return vvo.vTLTemplate;
    }
    return @"";
}

//=============(Vendors)=====================================================
-(NSString *) getTRAnchorByVendor : (NSString *)vmatch
{
    for (VendorObject *vvo in _vobjs)
    {
        if ([vvo.vName isEqualToString:vmatch]) return vvo.vTRTemplate;
    }
    return @"";
}


//=============(Vendors)=====================================================
// Given vendor name, find index to vobjs array
-(int)  getVendorIndex : (NSString *)vname
{
    int i=0;
    NSString *vlc = vname.lowercaseString;
    for (VendorObject *vvo in _vobjs)
    {
        if ([vvo.vNameLC isEqualToString:vlc]) return i;
        i++;
    }
    return 0;
} //end getVendorIndex

//=============(Vendors)=====================================================
-(NSString *) getIntQuantityByIndex : (int)index
{
    if (index < 0 || index >= _vobjs.count) return @"";
    VendorObject *vvo = _vobjs[index];
    return vvo.vIntQuantity;
} //end getNameByIndex


//=============(Vendors)=====================================================
-(NSString *) getNameByIndex : (int)index
{
    if (index < 0 || index >= _vobjs.count) return @"";
    VendorObject *vvo = _vobjs[index];
    return vvo.vName;
} //end getNameByIndex

//=============(Vendors)=====================================================
-(NSString *) getFoldernameByIndex : (int)index
{
    if (index < 0 || index >= _vobjs.count) return @"";
    VendorObject *vvo = _vobjs[index];
    return vvo.vFolderName;
} //end getNameByIndex

//=============(Vendors)=====================================================
-(NSString *) getRotationByIndex : (int)index
{
    if (index < 0 || index >= _vobjs.count) return @"";
    VendorObject *vvo = _vobjs[index];
    return vvo.vRotation;
} //end getRotationByIndex


//=============(Vendors)=====================================================
// Given vendor name, find typical invoice rotation
-(NSString *) getRotationByVendorName : (NSString *)vname
{
    NSString *vlc = vname.lowercaseString;
    for (VendorObject *vvo in _vobjs)
        if ([vvo.vNameLC isEqualToString:vlc]) return vvo.vRotation;
    return @"0";
} //end getRotationByVendorName


//=============(Vendors)=====================================================
// 3/6 loads up array of vendorObjects instead of multiple arrays now
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
            [self->_vobjs removeAllObjects];
            self->_vcount = 0;
            for( PFObject *pfo in objects)  //Save all our vendor names...
            {
                VendorObject *vvo = [[VendorObject alloc] init];
                NSString *s  = [pfo objectForKey:PInv_Vendor_key];
                vvo.vName    = s;
                vvo.vNameLC  = s.lowercaseString; //LC Strings to match by
                //Generate a legal filename, too, no whitespace, dots, apostrophes or commas...
                NSString *sf = [s  stringByReplacingOccurrencesOfString:@" " withString:@"_"];
                sf = [sf stringByReplacingOccurrencesOfString:@"." withString:@"_"];
                sf = [sf stringByReplacingOccurrencesOfString:@"," withString:@"_"];
                sf = [sf stringByReplacingOccurrencesOfString:@"\'" withString:@"_"];
                vvo.vFolderName  = sf;
                vvo.vRotation    = [pfo objectForKey:PInv_Rotated_key];
                vvo.vIntQuantity = [pfo objectForKey:PInv_IntQuantity_key];
                vvo.vTLTemplate  = [pfo objectForKey:PInv_TLTemplateAnchor];
                vvo.vTRTemplate  = [pfo objectForKey:PInv_TRTemplateAnchor];
                [self->_vobjs addObject:vvo];
                self->_vcount++;
            }
            //NSLog(@" ...loaded all vendors");
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
    for (VendorObject *vvo in _vobjs)
        if ([s.lowercaseString containsString : vvo.vNameLC]) return i;
    return -1;
} //end stringHasVendorName

@end
