//
//  EXPStats.h
//  testOCR
//
//  Created by Dave Scruton on 2/2/19.
//  Copyright © 2019 huedoku. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "smartProducts.h"
#import "Vendors.h"

#define MAX_CVENDORS 64   //Expand as needed
#define MAX_CCATEGORIES 16 //Expand as needed

@interface EXPStats : NSObject
{
    Vendors *vv;
    smartProducts *smartp;

    //Statistics...
    int amounts[MAX_CVENDORS];
    int counts[MAX_CVENDORS];
    int lamounts[MAX_CVENDORS];  //Local sums/count
    int lcounts[MAX_CVENDORS];
    int pamounts[MAX_CVENDORS];  //Processed sums / count
    int pcounts[MAX_CVENDORS];
    int famounts[MAX_CVENDORS]; //Food sums / count
    int fcounts[MAX_CVENDORS];
    int foodSum;
    int processedSum;
    int nonprocessedSum;
    int localSum;
    int nonlocalSum;
    NSArray *categories;
    NSArray *foodCategories;
    NSArray *monthNames;

    int loadCount,writeCount,okCount,errCount;
    int catPRAmounts[MAX_CVENDORS][MAX_CCATEGORIES];
    int catPRCounts[MAX_CVENDORS][MAX_CCATEGORIES];
    int catNPRAmounts[MAX_CVENDORS][MAX_CCATEGORIES];
    int catNPRCounts[MAX_CVENDORS][MAX_CCATEGORIES];
    int catPRSums[MAX_CCATEGORIES];
    int catPRCSums[MAX_CCATEGORIES];
    int catNPRSums[MAX_CCATEGORIES];
    int catNPRCSums[MAX_CCATEGORIES];

}

@property (nonatomic , assign) int month;
@property (nonatomic , assign) int year;


-(void) addAmount : (int) index : (int) a ;
-(void) addLAmount : (int) index : (int) a ;
-(void) addPAmount : (int) index : (int) a ;
-(void) addFAmount : (int) index : (int) a;
-(void) addCatAmount : (int) vindex : (int) cindex : (int) a : (BOOL) proFlag;
-(void) clear;
-(void) dump;
-(NSUInteger) getCategoryIndex : (NSString*) catstr;
-(NSString *) getMonthName : (int) index1To12;
-(BOOL) isFoodItem : (NSString *) cat;

@end

