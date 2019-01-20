//
//     ___   ____ ______        __            _
//    / _ \ / ___|  _ \ \      / /__  _ __ __| |
//   | | | | |   | |_) \ \ /\ / / _ \| '__/ _` |
//   | |_| | |___|  _ < \ V  V / (_) | | | (_| |
//    \___/ \____|_| \_\ \_/\_/ \___/|_|  \__,_|
//
//  OCRWord.h
//  testOCR
//
//  Created by Dave Scruton on 12/5/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OCRWord : NSObject
{
    
}

@property (nonatomic , strong) NSNumber* height;
@property (nonatomic , strong) NSNumber* width;
@property (nonatomic , strong) NSNumber* left;
@property (nonatomic , strong) NSNumber* top;
@property (nonatomic , strong) NSString* wordtext;

-(void) packFromDictionary : (NSDictionary*)d;
-(void) dump;
@end




NS_ASSUME_NONNULL_END
