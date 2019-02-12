//
//  ActivityTable.h
//  testOCR
//
//  Created by Dave Scruton on 12/22/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Parse/Parse.h>
#import "DBKeys.h"


@protocol ActivityTableDelegate;

@interface ActivityTable : NSObject
{
    NSMutableArray *recordStrings;
    NSString *tableName;
    NSMutableArray *typeStrings;
    NSMutableArray *dataStrings;
    NSMutableArray *dates;
}

//@property (nonatomic , strong) NSString* itotal;

@property (nonatomic, unsafe_unretained) id <ActivityTableDelegate> delegate; // receiver of completion messages
@property (nonatomic , strong) NSString* objectID;
@property (nonatomic , strong) NSString* versionNumber;


-(NSString *) getType : (int) index;
-(NSString *) getData : (int) index;
-(NSDate *)   getDate : (int) index;
-(int) getReadCount;
-(BOOL) isFatalError : (int) index;

-(void) readActivitiesFromParse : (NSString*) actType : (NSString *)vendor;

//-(void) readFromParseAsStrings : (NSString *)vendor;
-(void) saveActivityToParse : (NSString*) actType : (NSString *)actData;

@end

@protocol ActivityTableDelegate <NSObject>
@required
@optional
- (void)didReadActivityTable;
- (void)errorReadingActivities : (NSString *)errmsg;
- (void)didSaveActivity;
@end
