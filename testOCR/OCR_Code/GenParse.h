//
//  GenParse.h
//  testOCR
//
//  Created by Dave Scruton on 1/29/19.
//  Copyright © 2019 huedoku. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Parse/Parse.h>
@protocol GenParseDelegate;

@interface GenParse : NSObject

@property (nonatomic, unsafe_unretained) id <GenParseDelegate> delegate; // receiver of completion messages

-(void) deleteAllByTableAndKey : (NSString *)tableName  : (NSString *)key   : (NSString *)kval;

@end

@protocol GenParseDelegate <NSObject>
@required
@optional
- (void)didDeleteAllByTableAndKey : (NSString *)s1 : (NSString *)s2 : (NSString *)s3;
- (void)errorDeletingAllByTableAndKey : (NSString *)s1 : (NSString *)s2 : (NSString *)s3;
@end
