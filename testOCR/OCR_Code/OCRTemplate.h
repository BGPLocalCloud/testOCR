//
//    ___   ____ ____ _____                    _       _
//   / _ \ / ___|  _ \_   _|__ _ __ ___  _ __ | | __ _| |_ ___
//  | | | | |   | |_) || |/ _ \ '_ ` _ \| '_ \| |/ _` | __/ _ \
//  | |_| | |___|  _ < | |  __/ | | | | | |_) | | (_| | ||  __/
//   \___/ \____|_| \_\|_|\___|_| |_| |_| .__/|_|\__,_|\__\___|
//                                      |_|
//
//  OCRTemplate.h
//  testOCR
//
//  Created by Dave Scruton on 12/5/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Parse/Parse.h>
#import <UIKit/UIKit.h>
#import "OCRBox.h"
#import "DBKeys.h"
NS_ASSUME_NONNULL_BEGIN

@protocol OCRTemplateDelegate;


@interface OCRTemplate : NSObject
{
    NSMutableArray *ocrBoxes;
    NSString *fileLocation;
    NSString *fileWorkString;
    CGRect headerColumns[32]; //Overkill
    NSString * headerTypes[32];  
    int headerColumnCount;
    //Comes from templated document (original)
    CGRect tlDocRect,trDocRect;
    NSString *documentsDirectory;
    
    NSMutableArray *recordStrings;
    NSString * orientationWhenReadable;
    //Column x ranges and ptrs to box data
    int cxrange1[32],cxrange2[32],cptrs[32];
    int maxcptr;
    int headerY; 
}

#define INVOICE_NUMBER_FIELD                @"INVOICE_NUMBER"
#define INVOICE_DATE_FIELD                  @"INVOICE_DATE"
#define INVOICE_SUPPLIER_FIELD              @"INVOICE_SUPPLIER"
#define INVOICE_CUSTOMER_FIELD              @"INVOICE_CUSTOMER"
#define INVOICE_HEADER_FIELD                @"INVOICE_HEADER"
#define INVOICE_COLUMN_FIELD                @"INVOICE_COLUMN"
#define INVOICE_IGNORE_FIELD                @"INVOICE_IGNORE"
#define INVOICE_TOTAL_FIELD                 @"INVOICE_TOTAL"
#define INVOICE_COLUMN_ITEM_FIELD           @"INVOICE_COLUMN_ITEM"
#define INVOICE_COLUMN_DESCRIPTION_FIELD    @"INVOICE_COLUMN_DESCRIPTION"
#define INVOICE_COLUMN_QUANTITY_FIELD       @"INVOICE_COLUMN_QUANTITY"
#define INVOICE_COLUMN_PRICE_FIELD          @"INVOICE_COLUMN_PRICE"
#define INVOICE_COLUMN_AMOUNT_FIELD         @"INVOICE_COLUMN_AMOUNT"

@property (nonatomic , strong) NSString* versionNumber;
@property (nonatomic , strong) NSString* supplierName;
@property (nonatomic , strong) NSString* pdfFile;

@property (nonatomic, unsafe_unretained) id <OCRTemplateDelegate> delegate; // receiver of completion messages


-(void) addBox : (CGRect) frame : (NSString *)fname : (NSString *)format;
-(void) addTag : (int) index : (NSString*)tag;
-(void) clearFields;
-(void) clearHeaders;
-(void) clearTags : (int) index;
-(void) checkVendorTemplate : (NSString *)vendorMatch;
-(void) deleteBox : (int) index;
-(NSString *) getAllTags :(int) index;
-(int) getBoxCount;
-(CGRect) getBoxRect :(int) index;
-(NSString*) getBoxFieldName :(int) index;
-(NSString*) getBoxFieldFormat :(int) index;
-(NSString *) getColumnType : (int) column;
-(CGRect) getTLOriginalRect;
-(CGRect) getTROriginalRect;
-(int) getColumnCount;
-(CGRect) getColumnByIndex : (int) index;
-(CGRect) getColumnRect :(int) index;
-(int)  getTagCount : (int) index;
-(void) addHeaderColumnToSortedArray : (int) index : (NSString *)columnType : (int) y;
-(void) dump;
-(void) dumpBox : (int) index;
-(BOOL) isSupplierAMatch : (NSString *)stest;
-(void) loadTemplatesFromDisk : (NSString *)vendorName;
-(void) loadTemplateFromPFObject : (NSArray *) objects : (int) index;
-(void) setOriginalRects : (CGRect) tlr : (CGRect) trr;
-(void) setTemplateOrientation : (int)w : (int) h;
-(void) saveTemplatesToDisk : (NSString *)vendorName;
-(void) saveToParse   : (NSString *)vendorName;
-(void) readFromParse : (NSString *)vendorName;
-(void) readFromParseAsStrings ;
-(BOOL) gotFieldAlready : (NSString*)fname;
-(int) hitField :(int) tx : (int) ty;
@end

NS_ASSUME_NONNULL_END

@protocol OCRTemplateDelegate <NSObject>
@required
@optional
- (void)didCheckTemplate : (int) count;
- (void)errorCheckingTemplate : (NSString *)errmsg;
- (void)didReadTemplate: (NSArray*) a;
- (void)errorReadingTemplate : (NSString *)errmsg;
- (void)didReadTemplateTableAsStrings : (NSMutableArray*) a;
- (void)didSaveTemplate;
@end

