//
//    ___   ____ ____  ____                                        _
//   / _ \ / ___|  _ \|  _ \  ___   ___ _   _ _ __ ___   ___ _ __ | |_
//  | | | | |   | |_) | | | |/ _ \ / __| | | | '_ ` _ \ / _ \ '_ \| __|
//  | |_| | |___|  _ <| |_| | (_) | (__| |_| | | | | | |  __/ | | | |_
//   \___/ \____|_| \_\____/ \___/ \___|\__,_|_| |_| |_|\___|_| |_|\__|
//
//  OCRDocument.h
//  testOCR
//
//  Created by Dave Scruton on 12/5/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#import "OCRWord.h"
#import "documentBox.h"

NS_ASSUME_NONNULL_BEGIN
#define MAX_QPA_ROWS 512
@interface OCRDocument : NSObject
{
    NSMutableArray *allPages;
    NSMutableArray *allWords;
    OCRWord *workWord;
    NSString *documentType;
    NSDictionary *rawJSONDict;
    NSString *parsedText;
    NSMutableArray *headerPairs;
    NSMutableArray *headerArray;

    NSMutableArray *columnStringData; //Array of Arrays...
    NSMutableArray *finalYs; //Y tops of each row across the invoice, computed
    NSString * postOCRQuantities[MAX_QPA_ROWS];
    NSString * postOCRPrices[MAX_QPA_ROWS];
    NSString * postOCRAmounts[MAX_QPA_ROWS];
    int        postOCRMinorErrors[MAX_QPA_ROWS]; 
    int currentYear; //For fixing bad date strings
    NSMutableArray *ignoreList;
    BOOL useIgnoreList;
    //Comes from templated original document...
    CGRect tlTemplateRect, trTemplateRect;
    CGRect tlDocumentRect, trDocumentRect;
    CGRect blDocumentRect, brDocumentRect;
    double hScale,vScale; //For document scaling after template is made
    BOOL unitScale;
    //Groups: Used to try to find fields if templates fail?
    NSMutableSet *gT10;   //Near top,bottom,left,right
    NSMutableSet *gB10;
    NSMutableSet *gL10;
    NSMutableSet *gR10;
    NSMutableSet *gH20; //Near H/V center
    NSMutableSet *gV20;
    NSMutableSet *gT50;   //Top half
    NSMutableSet *gL50;   //Left half
    CGRect topmostLeftRect;
    CGRect topmostRightRect;

    BOOL debugMode;   //2/7 For verbose logging...
    NSString* debugString; //2/13 for arbitrary debugging
    UIViewController *debugParent; //Top level VC for debug output
}
@property (nonatomic , strong) UIImage* scannedImage;
@property (nonatomic , strong) NSString* scannedName;

@property (nonatomic , assign) int width;
@property (nonatomic , assign) int height;
@property (nonatomic , assign) int glyphHeight;
@property (nonatomic , assign) int longestColumn;
@property (nonatomic , assign) CGRect docRect;
@property (nonatomic , assign) int headerYpos;

@property (nonatomic , assign) int itemColumn;
@property (nonatomic , assign) int quantityColumn;
@property (nonatomic , assign) int descriptionColumn;
@property (nonatomic , assign) int priceColumn;
@property (nonatomic , assign) int amountColumn;

@property (nonatomic , assign) int numPages;


-(void) clearAllColumnStringData;
-(void) addColumnStringData : (NSMutableArray*)stringArray;
-(void) addIgnoreBoxItems  : (CGRect )rr;
-(int)  autoFindHeader;
-(NSString*) cleanUpNumberString : (NSString *)nstr;
-(NSString *)cleanupPrice : (NSString *)s;
-(NSMutableArray *) cleanUpRawColumns : (int) index : (NSString *)ctype : (NSMutableArray*) a;
-(void) computeScaling: (CGRect )tlr : (CGRect )trr;
-(void) dumpArrayFull : (NSArray*)a;
-(void) dumpArray : (NSArray*)a;
-(void) dumpWordsInBox : (CGRect) rr;
-(int) doc2templateX : (int) x;
-(int) doc2templateY : (int) y;



-(NSMutableArray *) findAllWordsInRect : (CGRect )rr;
-(NSMutableArray *) findAllWordStringsInRect : (CGRect )rr;
-(int) findHeader : (CGRect)r : (int) expandYBy;
-(int) findIntInArrayOfFields : (NSArray*)aof;
-(long) findLongInArrayOfFields : (NSArray*)aof;
-(float) findPriceInArrayOfFields : (NSArray*)aof;
-(NSDate *) findDateInArrayOfFields : (NSArray*)aof;
-(NSString *) findTopStringInArrayOfFields : (NSArray*)aof;
-(NSMutableArray*)  getColumnStrings: (CGRect)rr : (int) index : (NSString*)ctype;
-(NSArray*)  getHeaderNames;
-(void) getWordHistogram : (int) ytop : (int) numLines;

-(CGRect) getDocRect;
-(CGRect) getTLRect;
-(CGRect) getTRRect;
-(CGRect) getBLRect;
-(CGRect) getBRRect;
-(void) setVisualDebug  : (UIViewController*) p : (NSString*)dbs;
-(void) setDebugMode : (BOOL) mode;
-(CGRect) template2DocRect  : (CGRect) r;

-(void) getAverageGlyphHeight;
-(int) computeRowYpositions : (int) numCols : (CGRect)rp : (CGRect)ra;
-(NSMutableArray *) getRowFromColumnStringData : (int)index;
-(NSMutableArray *) getColumnYPositionsInRect : (CGRect )rr : (BOOL) numeric;
-(void) parseJSONfromDict : (NSDictionary *)d;
-(NSDate *) isItADate : (NSString *)tstr;
-(void) parseHeaderColumns : (NSMutableArray*)rectz : (CGRect) hr ;
-(void) setupDocumentAndParseJDON : (NSString*) ifname : (NSDictionary *)d : (BOOL) flipped90;
-(void) setupDocumentWithRect : (CGRect) r : (NSDictionary *)d;
-(void) setupPage : (int) page;
@end

NS_ASSUME_NONNULL_END
