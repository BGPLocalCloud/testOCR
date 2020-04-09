//
//  ActivityTable.m
//  testOCR
//
//  Created by Dave Scruton on 12/22/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
//  Should this be a singleton?
//  2/14 add username column
#import "ActivityTable.h"

@implementation ActivityTable


//=============(ActivityTable)=====================================================
-(instancetype) init
{
    if (self = [super init])
    {
        tableName       = @"activity";
        recordStrings   = [[NSMutableArray alloc] init]; //output area for table dump
        typeStrings     = [[NSMutableArray alloc] init]; //output area for table dump
        dataStrings     = [[NSMutableArray alloc] init]; //output area for table dump
        dates           = [[NSMutableArray alloc] init]; //output area for table dump
        _versionNumber  = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
    }
    return self;
}

//=============(ActivityTable)=====================================================
-(NSString *) getType : (int) index
{
    if (index < 0 || index >= typeStrings.count) return @"";
    return typeStrings[index];
}

//=============(ActivityTable)=====================================================
-(NSString *) getData : (int) index
{
    if (index < 0 || index >= dataStrings.count) return @"";
    return dataStrings[index];
}

//=============(ActivityTable)=====================================================
-(BOOL) isFatalError : (int) index
{
    if (index < 0 || index >= typeStrings.count) return FALSE;
    NSString *lct = typeStrings[index];
    return ([lct.lowercaseString containsString:@"fatal"]);
}

//=============(ActivityTable)=====================================================
-(NSDate *) getDate : (int) index
{
    if (index < 0 || index >= dates.count) return [NSDate date];
    return dates[index];
}


//=============(ActivityTable)=====================================================
-(int) getReadCount
{
    return (int)typeStrings.count;
}

//=============(ActivityTable)=====================================================
// Gets up to latest 100 records, loads into class members
-(void) readActivitiesFromParse : (NSString*) actType : (NSString *)vendor
{
    PFQuery *query = [PFQuery queryWithClassName:tableName];
    if (actType != nil) [query whereKey:PInv_ActivityType_key equalTo:actType];
    if (vendor != nil)  [query whereKey:PInv_ActivityData_key equalTo:vendor];
    [query orderByDescending:@"createdAt"];
    query.limit = 1000;

    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) { //Query came back...
            [self->typeStrings      removeAllObjects];
            [self->dataStrings      removeAllObjects];
            [self->dates            removeAllObjects];
            for (PFObject *pfo in objects)
            {
                [self->typeStrings addObject:[pfo objectForKey:PInv_ActivityType_key]];
                [self->dataStrings addObject:[pfo objectForKey:PInv_ActivityData_key]];
                [self->dates       addObject:[pfo createdAt]];
            } //end for pfo...
            [self.delegate didReadActivityTable];
        }    //end !error
        else{ //Error?
            [self.delegate errorReadingActivities:error.localizedDescription];
        } //end error
    }];     //end query find...
} //end readActivitiesFromParse


//=============(ActivityTable)=====================================================
-(void) saveActivityToParse : (NSString*) actType : (NSString *)actData
{
    PFObject *aRecord = [PFObject objectWithClassName:tableName];
    aRecord[PInv_ActivityType_key]     = actType;
    aRecord[PInv_ActivityData_key]     = actData;
    aRecord[PInv_VersionNumber    ]    = _versionNumber;
    NSString *uname = @"empty";  //DHS 2/14 add username column
    if ([PFUser currentUser] != nil) uname = [PFUser currentUser].username;
    aRecord[PInv_UserName_key]         = uname;
    //NSLog(@" activity savetoParse...");
    [aRecord saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            //NSLog(@" ...activity[%@]->parse",actType );
            [self.delegate didSaveActivity];
        } else {
            NSLog(@" ERROR: saving activity: %@",error.localizedDescription);
        }
    }];
} //end saveToParse



@end
