//
//  OCRTopObject.h
//  testOCR
//
//  Created by Dave Scruton on 12/22/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AppDelegate.h"
#import "DBKeys.h"
#import "ActivityTable.h"
#import "EXPTable.h"
#import "OCRWord.h"
#import "OCRCache.h"
#import "OCRDocument.h"
#import "OCRTemplate.h"
#import "smartProducts.h"
#import "invoiceTable.h"

@protocol OCRTopObjectDelegate;


//Tags: used to get hints about field placement
#define TOP_TAG_TYPE        @"TOP_TAG"
#define BOTTOM_TAG_TYPE     @"BOTTOM_TAG"
#define LEFT_TAG_TYPE       @"LEFT_TAG"
#define RIGHT_TAG_TYPE      @"RIGHT_TAG"
#define TOPMOST_TAG_TYPE    @"TOPMOST_TAG"
#define BOTTOMMOST_TAG_TYPE @"BOTTOMMOST_TAG"
#define LEFTMOST_TAG_TYPE   @"LEFTMOST_TAG"
#define RIGHTMOST_TAG_TYPE  @"RIGHTMOST_TAG"
#define ABOVE_TAG_TYPE      @"ABOVE_TAG"
#define BELOW_TAG_TYPE      @"BELOW_TAG"
#define LEFTOF_TAG_TYPE     @"LEFTOF_TAG"
#define RIGHTOF_TAG_TYPE    @"RIGHTOF_TAG"
#define HCENTER_TAG_TYPE    @"HCENTER_TAG"
#define HALIGN_TAG_TYPE     @"HALIGN_TAG"
#define VCENTER_TAG_TYPE    @"VCENTER_TAG"
#define VALIGN_TAG_TYPE     @"VALIGN_TAG"


@interface OCRTopObject : NSObject <invoiceTableDelegate,EXPTableDelegate>
{
    OCRDocument *od;
    invoiceTable *it;
    EXPTable *et;
    ActivityTable *act;

    smartProducts *smartp;
    int smartCount;
    int currentPage,pagesReturned,pageCount;
    //OCR'ed results...
    NSString *fieldName;
    NSString *fieldNameShort;
    NSString *fieldFormat;

    UIImage *fastIcon;
    UIImage *slowIcon;
    
    
    NSMutableArray *rowItems;
    
    NSString *rawOCRResult;
    NSDictionary *OCRJSONResult;
    NSString *parsedText;

    //CGRect tlRect,trRect;  //Absolute document boundary rects for text
    //CGRect blRect,brRect;
    OCRCache *oc;
    
    CGRect headerRect; 
    BOOL debugMode;   //2/7 For verbose logging...
    
}

@property (nonatomic , strong) NSString* vendor;
@property (nonatomic , strong) NSString* vendorFileName;
@property (nonatomic , strong) NSString* imageFileName;
@property (nonatomic , strong) NSString* batchID;
@property (nonatomic , strong) NSString* batchMonth;

//INvoice-read-in fields
@property (nonatomic , strong) NSDate* invoiceDate;
@property (nonatomic , strong) NSString* invoiceNumberString;
@property (nonatomic , strong) NSString* oldInvoiceNumberString;
@property (nonatomic , strong) NSString* invoiceCustomer;
@property (nonatomic , strong) NSString* invoiceVendor;
@property (nonatomic , assign) float invoiceTotal;
@property (nonatomic , assign) long invoiceNumber;
@property (nonatomic , strong) NSArray* columnHeaders;
@property (nonatomic , assign) int totalLines;
@property (nonatomic , strong) OCRTemplate* ot;
@property (nonatomic , assign) BOOL intQuantity;

@property (nonatomic, unsafe_unretained) id <OCRTopObjectDelegate> delegate; // receiver of completion messages

+ (id)sharedInstance;
- (NSString *) getRawResult;
- (NSString *) getParsedText;
- (void) clearEXPBatchCounter;
- (void) loadCSVFileFromDocParser : (NSString *)fname : (NSString *)vendor;
- (void) loadCSVValuesFromString : (NSString *)avendor : (NSString *)s;
- (void) performOCROnImage : (NSString *)fname : (UIImage *)imageToOCR ;
- (void) performOCROnData : (NSString *)fname : (NSData *)imageDataToOCR : (CGRect) r : (BOOL) isBatch ;
- (void) stubbedOCR: (NSString*)imageName : (UIImage *)imageToOCR : (OCRTemplate *)ot;
- (void) readCSVThenSaveToDropbox;
- (void) setDebugMode : (BOOL) mode;
- (void) setVisualDebug  : (UIViewController*) p : (NSString*)dbs;
- (void) setupTestDocumentJSON : (NSDictionary *) json;  //FOR TESTING ONLY
- (void) setupDocumentFrameAndParseJSON : (CGRect) r;
- (void) applyTemplate : (OCRTemplate *)ot : (int) page;             //FOR TESTING ONLY
- (void) writeEXPToParse : (int) page;
- (NSString *) dumpResults;


@end

@protocol OCRTopObjectDelegate <NSObject>
@required
@optional
- (void)batchUpdate : (NSString *) s;
- (void)didPerformOCR : (NSString *) result;
- (void)errorPerformingOCR : (NSString *) errMsg;
- (void)fatalErrorPerformingOCR : (NSString *) errMsg;
- (void)errorInEXPRecord : (NSString *) errMsg : (NSString*) objectID : (NSString*) productName;
- (void)errorSavingEXPToParse : (NSString *)err;
- (void)errorSavingInvoiceToParse : (NSString *)err;
- (void)didSaveOCRDataToParse : (NSString *) s;
- (void)didReadFullTableToCSV : (NSString *) s;
- (void)errorReadingFullTableToCSV : (NSString *) s;
- (void)errorSavingOCRDataToParse : (NSString *) s;
- (void)foundEmptyPage;
@end
