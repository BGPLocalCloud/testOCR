//
//                            _   ____                _            _
//   ___ _ __ ___   __ _ _ __| |_|  _ \ _ __ ___   __| |_   _  ___| |_ ___
//  / __| '_ ` _ \ / _` | '__| __| |_) | '__/ _ \ / _` | | | |/ __| __/ __|
//  \__ \ | | | | | (_| | |  | |_|  __/| | | (_) | (_| | |_| | (__| |_\__ \
//  |___/_| |_| |_|\__,_|_|   \__|_|   |_|  \___/ \__,_|\__,_|\___|\__|___/
//
//
//  smartProducts.h
//  testOCR
//
//  Created by Dave Scruton on 12/12/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCRCategories.h"
#import <Parse/Parse.h>
#import "DBKeys.h"

NS_ASSUME_NONNULL_BEGIN




#define ANALYZER_BAD_PRICE_COLUMNS  1001
#define ANALYZER_MATH_ERROR         1002
#define ANALYZER_NO_PRODUCT_FOUND   1003
#define ANALYZER_ZERO_AMOUNT        1004
#define ANALYZER_ZERO_PRICE         1005
#define ANALYZER_ZERO_QUANTITY      1006
#define ANALYZER_NONPRODUCT         1007
#define ANALYZER_BAD_MATH           1008


@interface smartProducts : NSObject
{
    //These tables of product listings get loaded from DB
    NSString *fullProductName;
    NSString *vendor;
    NSString *price;
    NSString *uom;
    NSString *amount;
    NSString *quantity;
    BOOL processed;
    BOOL local;
    BOOL bulk;
    int lineNumber;
    //Built-in values
    NSArray *beverageNames;
    NSArray *breadNames;
    NSArray *dairyNames;
    NSArray *dryGoodsNames;
    NSArray *miscNames;
    NSArray *proteinNames;
    NSArray *produceNames;
    NSArray *snacksNames;
    NSArray *suppliesNames;
    NSArray *nonProducts;
    NSArray *categories;
    NSMutableArray *typos;
    NSMutableArray *fixed;
    NSMutableArray *splits;
    NSMutableArray *joined;
    NSMutableArray *wilds;
    NSMutableArray *notwilds;
    
    NSMutableDictionary *keywords;
    BOOL didInitAlready;
    OCRCategories* occ; //Categories / processed / local lookup table
}
//These props get set by analyze for public access...
@property (nonatomic , strong) NSString* analyzedDateString;
@property (nonatomic , strong) NSString* analyzedCategory;
@property (nonatomic , strong) NSString* analyzedUOM;
@property (nonatomic , strong) NSString* analyzedBulkOrIndividual;
@property (nonatomic , strong) NSString* analyzedQuantity;
@property (nonatomic , strong) NSString* analyzedPricePerUOM;
@property (nonatomic , strong) NSString* analyzedPrice;
@property (nonatomic , strong) NSString* analyzedProductName;
@property (nonatomic , strong) NSString* analyzedAmount;
@property (nonatomic , strong) NSString* analyzedProcessed;
@property (nonatomic , strong) NSString* analyzedLocal;
@property (nonatomic , strong) NSString* analyzedVendor;
@property (nonatomic , strong) NSString* analyzedLineNumber; //String?
@property (nonatomic , strong) NSDate* invoiceDate;
@property (nonatomic , strong) NSString* invoiceDateString;
@property (nonatomic , assign) BOOL analyzeOK;
@property (nonatomic , assign) int  minorError;
@property (nonatomic , assign) int  majorError;
@property (nonatomic , assign) BOOL nonProduct;
@property (nonatomic , assign) BOOL intQuantity;



-(void) clear;
-(void) addProductName : (NSString*)pname;
-(void) addVendor : (NSString*)vname;
-(void) addDate : (NSDate*)ndate;
-(void) addLineNumber : (int)n;
-(void) addAmount : (NSString*)price;
-(void) addPrice : (NSString*)price;
-(void) addUOM : (NSString*)uom;
-(void) addQuantity : (NSString*)qstr;
-(int) analyze;
//-(void) dump;
-(NSString*) getErrDescription : (int) aerr;
-(NSString*) getDollarsAndCentsString : (float) fin;
-(NSString*) getMinorErrorString;
-(NSString*) getMajorErrorString;

-(NSString*) getKeyword : (NSString*)category : (int) index;
-(int) getKeywordCount : (NSString*)category;
-(void) saveKeywordsAndTyposToParse;


@end

NS_ASSUME_NONNULL_END
