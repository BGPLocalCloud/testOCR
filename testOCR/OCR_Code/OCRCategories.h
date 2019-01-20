//
//    ___   ____ ____   ____      _                        _
//   / _ \ / ___|  _ \ / ___|__ _| |_ ___  __ _  ___  _ __(_) ___  ___
//  | | | | |   | |_) | |   / _` | __/ _ \/ _` |/ _ \| '__| |/ _ \/ __|
//  | |_| | |___|  _ <| |__| (_| | ||  __/ (_| | (_) | |  | |  __/\__ \
//   \___/ \____|_| \_\\____\__,_|\__\___|\__, |\___/|_|  |_|\___||___/
//                                        |___/
//
//  OCRCategories.h
//  testOCR
//
//  Created by Dave Scruton on 12/19/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CatObject.h"


#define BEVERAGE_CATEGORY @"BEVERAGE"
#define BREAD_CATEGORY @"BREAD"
#define DAIRY_CATEGORY @"DAIRY"
#define DRY_GOODS_CATEGORY @"DRY GOODS"
#define EQUIPMENT_CATEGORY @"EQUIPMENT"
#define MISC_CATEGORY @"MISC"
#define PAPER_GOODS_CATEGORY @"PAPER GOODS"
#define PROTEIN_CATEGORY @"PROTEIN"
#define PRODUCE_CATEGORY @"PRODUCE"
#define SNACKS_CATEGORY @"SNACKS"
#define SUPPLEMENTS_CATEGORY @"SUPPLEMENTS"
#define SUPPLIES_CATEGORY @"SUPPLIES"

@interface OCRCategories : NSObject
{
    
    NSMutableArray *catCSV;
//    int dog;
//    NSString *tableName;
//    NSString *packedOIDs;
    
}
@property (nonatomic , strong) NSMutableArray* catProducts;


+ (id)sharedInstance;
-(NSArray *)matchCategory : (NSString *)product;

@end

