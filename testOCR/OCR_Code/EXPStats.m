//
//   _______  ______  ____  _        _
//  | ____\ \/ /  _ \/ ___|| |_ __ _| |_ ___
//  |  _|  \  /| |_) \___ \| __/ _` | __/ __|
//  | |___ /  \|  __/ ___) | || (_| | |_\__ \
//  |_____/_/\_\_|   |____/ \__\__,_|\__|___/
//
//  EXPStats.m
//  testOCR
//
//  Created by Dave Scruton on 2/2/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import "EXPStats.h"

@implementation EXPStats

//=============(EXPStats)=====================================================
-(instancetype) init
{
    if (self = [super init])
    {
        vv  = [Vendors sharedInstance];
        NSLog(@" estats init vendors %@",vv);
        smartp = [[smartProducts alloc] init];
        //_versionNumber    = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
        [self loadConstants];
        [self clear];
    }
    return self;
}

//=============(EXPStats)=====================================================
-(void) clear
{
    for (int i=0;i<MAX_CVENDORS;i++)
    {
        amounts[i] = 0;
        counts[i] = 0;
        amounts[i] = 0;
        lcounts[i] = 0;
        lamounts[i] = 0;
        pcounts[i] = 0;
        pamounts[i] = 0;
        fcounts[i] = 0;
        famounts[i] = 0;
        for (int j=0;j<MAX_CCATEGORIES;j++)
        {
            catPRAmounts[i][j] = 0;
            catPRCounts[i][j] = 0;
            catNPRAmounts[i][j] = 0;
            catNPRCounts[i][j] = 0;
        }
    }
    for (int j=0;j<MAX_CCATEGORIES;j++)
    {
        catPRSums[j]  = 0;
        catPRCSums[j] = 0;
        catNPRSums[j]  = 0;
        catNPRCSums[j] = 0;
    }
    foodSum = processedSum = localSum = 0;
    nonprocessedSum = nonlocalSum = 0;

} //end clear


//=============(EXPStats)=====================================================
-(void) loadConstants
{
    categories = @[
                   @"beverage",
                   @"bread",
                   @"dairy",
                   @"drygoods",
                   @"produce",
                   @"protein",
                   @"snacks",
                   @"labor",
                   @"misc",
                   @"papergoods",
                   @"supplement",
                   @"supplies"
                   ];
    foodCategories = @[
                   @"beverage",
                   @"bread",
                   @"dairy",
                   @"drygoods",
                   @"produce",
                   @"protein",
                   @"snacks"
                   ];
    monthNames = @[
                   @"01-JUL",
                   @"02-AUG",
                   @"03-SEP",
                   @"04-OCT",
                   @"05-NOV",
                   @"06-DEC",
                   @"07-JAN",
                   @"08-FEB",
                   @"09-MAR",
                   @"10-APR",
                   @"11-MAY",
                   @"12-JUN"
                  ];

} //end loadConstants

//=============(EXPStats)=====================================================
-(NSUInteger) getCategoryIndex : (NSString*) catstr
{
    return [categories indexOfObject:catstr.lowercaseString];
}

//=============(EXPStats)=====================================================
-(NSString *) getMonthName : (int) index1To12
{
    if (index1To12 < 1 || index1To12 > 12) return @"";
    return monthNames[index1To12-1];
}


//=============(EXPStats)=====================================================
-(BOOL) isIndexLegal : (int) index
{
    if (index < 0) return FALSE;
    if (index >=MAX_CVENDORS) return FALSE;
    return TRUE;
}

//=============(EXPStats)=====================================================
-(BOOL) isCatIndexLegal : (int) index
{
    if (index < 0) return FALSE;
    if (index >=MAX_CCATEGORIES) return FALSE;
    return TRUE;
}

//=============(EXPStats)=====================================================
-(void) addAmount : (int) index : (int) a
{
    if ([self isIndexLegal:index])
    {
        amounts[index] += a;
        counts[index]++;
    }
}

//=============(EXPStats)=====================================================
-(void) addLAmount : (int) index : (int) a
{
    if ([self isIndexLegal:index])
    {
        lamounts[index] += a;
        lcounts[index]++;
        localSum+=a;

    }
}

//=============(EXPStats)=====================================================
-(void) addPAmount : (int) index : (int) a
{
    if ([self isIndexLegal:index])
    {
        pamounts[index] += a;
        pcounts[index]++;
        processedSum+=a;
    }
}

//=============(EXPStats)=====================================================
// Food/NonFood
-(void) addFAmount : (int) index : (int) a
{
    if ([self isIndexLegal:index])
    {
        famounts[index] += a;
        fcounts[index]++;
        foodSum+=a;
    }
}


//=============(EXPStats)=====================================================
-(void) addCatAmount : (int) vindex : (int) cindex : (int) a : (BOOL) proFlag
{
    if ([self isIndexLegal:vindex] && [self isCatIndexLegal:cindex])
    {
        if (proFlag)
        {
            catPRAmounts[vindex][cindex]+=a;
            catPRCounts[vindex][cindex]++;
            catPRSums[cindex]+=a;
            catPRCSums[cindex]++;
        }
        else
        {
            catNPRAmounts[vindex][cindex]+=a;
            catNPRCounts[vindex][cindex]++;
            catNPRSums[cindex]+=a;
            catNPRCSums[cindex]++;
        }
    }
}

//=============(EXPStats)=====================================================
-(BOOL) isFoodItem : (NSString *) cat
{
    return ([foodCategories indexOfObject:cat.lowercaseString] != NSNotFound);
}

//=============(EXPStats)=====================================================
-(void) dump
{
    //Dumpit
    NSLog(@" dump Stats... %d/%d",_month,_year);
    NSString *tstr;
    NSString *tstr2;
    for (int i=0;i<MAX_CVENDORS;i++)
    {
        if (amounts[i] > 0) //Got somethign for this vendor?
        {
            NSLog(@"Vendor: %@",vv.vNames[i]);
            float ftotal = (float)amounts[i] / 100.0;
            tstr = [smartp getDollarsAndCentsString:ftotal];
            NSLog(@" Total $%@",tstr);
            //int lct  = lcounts[i];
            int lam  = (float)lamounts[i] / 100.0;
            int nlam = (float)(amounts[i]-lamounts[i])/ 100.0;
            tstr = [smartp getDollarsAndCentsString:lam];
            tstr2 = [smartp getDollarsAndCentsString:nlam];
            NSLog(@" Local:$%@ vs NonLocal:$%@",tstr,tstr2);
            //int pct  = pcounts[i];
            int pam  = (float)pamounts[i] / 100.0;
            int npam = (float)(amounts[i]-pamounts[i])/ 100.0;
            tstr = [smartp getDollarsAndCentsString:pam];
            tstr2 = [smartp getDollarsAndCentsString:npam];
            NSLog(@" Processed:$%@ vs NonProcessed:$%@",tstr,tstr2);
            int fam = (float)famounts[i] / 100.0;
            int fct = fcounts[i];
            tstr = [smartp getDollarsAndCentsString:fam];
            NSLog(@" Food Items %d : $%@",fct,tstr);
            tstr = [smartp getDollarsAndCentsString:(ftotal-fam)];
            NSLog(@" Non-Food Items %d : $%@",counts[i]-fct,tstr);

            float cPRtotal = 0.0;
            float cNPRtotal = 0.0;
            float fPRtotal = 0.0;
            float fNPRtotal = 0.0;
            for (int j=0;j<(int)categories.count;j++)
            {
                fPRtotal = (float)catPRAmounts[i][j]/ 100.0;
                fNPRtotal = (float)catNPRAmounts[i][j]/ 100.0;
                if (fPRtotal > 0 || fNPRtotal > 0) //Only print out if there is data
                {
                    cPRtotal += fPRtotal;
                    cNPRtotal += fNPRtotal;
                    tstr = [smartp getDollarsAndCentsString:fPRtotal];
                    NSLog(@"  ...Cat[%@] processed amount     $%@",categories[j],tstr);
                    tstr = [smartp getDollarsAndCentsString:fNPRtotal];
                    NSLog(@"  ...Cat[%@] non-processed amount $%@",categories[j],tstr);
                }
            } //end for j
            tstr = [smartp getDollarsAndCentsString:cPRtotal];
            NSLog(@"  Processed Total: $%@",tstr);
            tstr = [smartp getDollarsAndCentsString:cNPRtotal];
            NSLog(@"  Non-Processed Total: $%@",tstr);

        }    //end if amounts..
    }       //end for i
    NSLog(@"  Category sums:");
    for (int j=0;j<(int)categories.count;j++)
    {
        float ftotal,fsum;
        NSString *catstr = categories[j];
        NSLog(@"   Cat[%@] ........... ",catstr);
        ftotal = fsum = 0.0;
        if ([self isFoodItem:catstr])
        {
            fsum   = (float)(catPRSums[j] + catNPRSums[j])/ 100.0;
            tstr = [smartp getDollarsAndCentsString:fsum];
            NSLog(@"  ... Total             $%@",tstr);
            ftotal = (float)catPRSums[j]/ 100.0;
            tstr = [smartp getDollarsAndCentsString:ftotal];
            NSLog(@"  ... Processed     sum $%@",tstr);
            ftotal = (float)catNPRSums[j]/ 100.0;
            tstr = [smartp getDollarsAndCentsString:ftotal];
            NSLog(@"  ... Non-Processed sum $%@",tstr);
        }
        else{
            ftotal = (float)catNPRSums[j]/ 100.0;
            tstr = [smartp getDollarsAndCentsString:ftotal];
            NSLog(@"  ...Cat[%@]sum $%@",catstr,tstr);
        }
    }
    
    NSLog(@"    ........... ");
    float prtotal = (float)processedSum/ 100.0;
    tstr  = [smartp getDollarsAndCentsString:prtotal];
    NSLog(@" Overall Processed sum : %@",tstr);
    float lototal = (float)localSum/ 100.0;
    tstr = [smartp getDollarsAndCentsString:lototal];
    NSLog(@" Overall Local    sum : %@",tstr);
    float fototal = (float)foodSum/ 100.0;
    tstr = [smartp getDollarsAndCentsString:fototal];
    NSLog(@" Overall Food     sum : %@",tstr);

    
} //end dump


@end
