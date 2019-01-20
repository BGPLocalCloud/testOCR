//
//    ___   ____ ____  ____
//   / _ \ / ___|  _ \| __ )  _____  __
//  | | | | |   | |_) |  _ \ / _ \ \/ /
//  | |_| | |___|  _ <| |_) | (_) >  <
//   \___/ \____|_| \_\____/ \___/_/\_\
//
//  OCRBox.h
//  testOCR
//
//  Created by Dave Scruton on 12/5/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


@interface OCRBox : NSObject
{
    NSMutableArray *tags;
}
@property (nonatomic , strong) NSString* fieldName;
@property (nonatomic , strong) NSString* fieldFormat;
@property (nonatomic , assign) CGRect frame;
@property (nonatomic , strong) NSString* stringValue;
@property (nonatomic , strong) NSNumber* numericValue;

-(void) addTag : (NSString *)tag;
-(void) clearTags;
-(void) deleteTag : (NSString *)tag;
-(NSString*) getAllTags;
-(NSString*) getTag : (int) index;
-(int) getTagCount;

-(void) dump;

@end

