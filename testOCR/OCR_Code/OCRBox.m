//
//    ___   ____ ____  ____
//   / _ \ / ___|  _ \| __ )  _____  __
//  | | | | |   | |_) |  _ \ / _ \ \/ /
//  | |_| | |___|  _ <| |_) | (_) >  <
//   \___/ \____|_| \_\____/ \___/_/\_\
//
//  OCRBox.m
//  testOCR
//
//  Created by Dave Scruton on 12/5/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import "OCRBox.h"

@implementation OCRBox

//=============(OCRRox)=====================================================
-(instancetype) init
{
    if (self = [super init])
    {
        tags = [[NSMutableArray alloc] init];
    }
    return self;
}

//=============(OCRRox)=====================================================
-(void) addTag : (NSString *)tag
{
    [tags addObject:tag];
    [self dump];
}

//=============(OCRRox)=====================================================
-(void) clearTags
{
    [tags removeAllObjects];
}

//=============(OCRRox)=====================================================
-(NSString*) getAllTags
{
    NSString *s = @"";
    if (tags.count == 0) return @"no tags";
    for (NSString *tag in tags) s = [s stringByAppendingString:[NSString stringWithFormat:@"%@:",tag]];
    return s;
}

//=============(OCRRox)=====================================================
-(NSString*) getTag : (int) index
{
    if (index < 0 || index >= tags.count) return @"";
    return [tags objectAtIndex:index];
}

//=============(OCRRox)=====================================================
-(int) getTagCount
{
    return (int)tags.count;
}

//=============(OCRRox)=====================================================
-(void) deleteTag : (NSString *)tag
{
    NSUInteger index = [tags indexOfObject:tag];
    if (index != NSNotFound) //Tag exists
        [tags removeObjectAtIndex:index];
}


//=============(OCRRox)=====================================================
-(void) dump
{
    NSLog(@"  fname  %@",_fieldName);
    NSLog(@"  format %@",_fieldFormat);
    NSLog(@"  frame  (%d,%d) (%d,%d)",
          (int)_frame.origin.x  ,(int)_frame.origin.y,
          (int)_frame.size.width,(int)_frame.size.height);
    int index = 0;
    for (NSString* tag in tags)
    {
        NSLog(@"     tag[%d]:%@",index++,tag);
    }
}

@end
