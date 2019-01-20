//
//     ___   ____ ______        __            _
//    / _ \ / ___|  _ \ \      / /__  _ __ __| |
//   | | | | |   | |_) \ \ /\ / / _ \| '__/ _` |
//   | |_| | |___|  _ < \ V  V / (_) | | | (_| |
//    \___/ \____|_| \_\ \_/\_/ \___/|_|  \__,_|
//
//  OCRWord.m
//  testOCR
//
//  Created by Dave Scruton on 12/5/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import "OCRWord.h"

@implementation OCRWord

//----OCRWord-------------------------------------------------------
-(void) packFromDictionary : (NSDictionary*)d
{
    _height   = [d objectForKey:@"Height"];
    _width    = [d objectForKey:@"Width"];
    _left     = [d objectForKey:@"Left"];
    _top      = [d objectForKey:@"Top"];
    _wordtext = [d objectForKey:@"WordText"];
}
//----OCRWord-------------------------------------------------------
-(void) dump
{
    NSLog(@" ocrword XY[%d,%d] WH[%d,%d],%@",
          _left.intValue,_top.intValue,
          _width.intValue,_height.intValue,_wordtext);
}


@end
