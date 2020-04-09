//
//   _                 _           ___  _     _           _
//  (_)_ ____   _____ (_) ___ ___ / _ \| |__ (_) ___  ___| |_
//  | | '_ \ \ / / _ \| |/ __/ _ \ | | | '_ \| |/ _ \/ __| __|
//  | | | | \ V / (_) | | (_|  __/ |_| | |_) | |  __/ (__| |_
//  |_|_| |_|\_/ \___/|_|\___\___|\___/|_.__// |\___|\___|\__|
//                                          |__/
//
//  invoiceObject.m
//  testOCR
//
//  Created by Dave Scruton on 12/17/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
//  4/3/20 init all fields, was crashing on PFObject writes w/ bogus invoice fields

#import "invoiceObject.h"

@implementation invoiceObject

//=============(invoiceObject)=====================================================
-(instancetype) init
{
    if (self = [super init])
    {
        //3/4/20 make sure all fields are initialized
        _date = [NSDate date];
        _objectID       = @"";
        _itotal         = @"";
        _packedEXPIDs   = @"";
        _invoiceNumber  = @"";
        _customer       = @"";
        _batchID        = @"";
        _vendor         = @"";
        _PDFFile        = @"";
        _pageCount      = @"";
        _page           = @"";

    }
    return self;
}

@end
