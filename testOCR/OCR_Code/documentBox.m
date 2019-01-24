//
//  documentBox.m
//  testOCR
//
//  Created by Dave Scruton on 1/20/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import "documentBox.h"

@implementation documentBox

//=============(documentRox)=====================================================
-(instancetype) init
{
    if (self = [super init])
    {
        _frame = CGRectZero;
        _items = [[NSMutableArray alloc] init];
    }
    return self;
}


//=============(documentRox)=====================================================
-(void) dump
{
    NSLog(@" docbox %@",NSStringFromCGRect(_frame));
    NSLog(@" array %@",_items);
}


@end
