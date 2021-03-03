//
//   ____        _       _      ___  _     _           _
//  | __ )  __ _| |_ ___| |__  / _ \| |__ (_) ___  ___| |_
//  |  _ \ / _` | __/ __| '_ \| | | | '_ \| |/ _ \/ __| __|
//  | |_) | (_| | || (__| | | | |_| | |_) | |  __/ (__| |_
//  |____/ \__,_|\__\___|_| |_|\___/|_.__// |\___|\___|\__|
//                                      |__/
//
//  BatchObject.h
//  testOCR
//
//  Created by Dave Scruton on 12/22/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h>
#import <Parse/Parse.h>
#import "AppDelegate.h"
#import "ActivityTable.h"
#import "DropboxTools.h"
#import "GenParse.h"
#import "imageTools.h"
#import "OCRTemplate.h"
#import "Vendors.h"
#import "UIImageExtras.h"
#import "OCRTopObject.h"
#import "OCRCache.h"
#import "PDFCache.h"

@protocol batchObjectDelegate;


#define BATCH_STATUS_RUNNING    @"Running"
#define BATCH_STATUS_HALTED     @"Halted"
#define BATCH_STATUS_FAILED     @"Failed"
#define BATCH_STATUS_COMPLETED  @"Completed"

@interface BatchObject : NSObject <DropboxToolsDelegate,OCRTemplateDelegate,
                                    OCRTopObjectDelegate,GenParseDelegate>
{
    DropboxTools *dbt;
    Vendors *vv;
    OCRTemplate *ot;
    ActivityTable *act;
    OCRTopObject *oto;
    GenParse *gp;

    UIViewController *parent;
    
    BOOL gotTemplate;
    NSString *batchFolder;
    BOOL runAllBatches;
    int selectedVendor; //Chosen vendor to run batch on, stays constant
    int vendorIndex;  //Index to vendors object for currentbatch
    NSString *customerName; //3/20 multi-customer support
    NSString *vendorName; //Whose batch we're running
    NSString *vendorRotation; //Are pages rotated typically?
    NSString *vendorFolderName;  
    NSString *batchFiles; //CSV list of all files processed
    NSString *batchProgress;
    NSString *batchErrors;
    NSString *batchWarnings;
    NSString *batchFixed;
    NSString *cachesDirectory;
    NSString *cacheFolderPath;        //Where our cache lives

    NSString *lastFileProcessed;
    NSMutableArray *vendorFileCounts;
    NSMutableDictionary *vendorFolders;
    NSArray *pdfEntries;  //Fetched list of PDF files from batch folder
    NSMutableArray *errorList;
    NSMutableArray *warningList;
    NSMutableArray *fixedList;
    NSMutableArray *warningFixedList;
    NSMutableArray *errorReportList;
    NSMutableArray *warningReportList;
    int batchCount;
    int batchTotal;
    int batchPage;
    int batchTotalPages;
    NSString *batchTableName;
    NSString *expTableName;
    int returnCount;

    OCRCache *oc;
    PDFCache *pc;
    NSString *batchReportString;
    BOOL debugMode;   //2/7 For verbose logging...
    BOOL majorFileError;

}
@property (nonatomic , strong) NSString* batchID;
@property (nonatomic , assign) BOOL authorized;
@property (nonatomic , strong) NSString* versionNumber;
@property (nonatomic , strong) NSString* batchStatus;
@property (nonatomic , strong) NSString* batchMonth;

@property (nonatomic, unsafe_unretained) id <batchObjectDelegate> delegate; // receiver of completion messages

+ (id)sharedInstance;

-(void) addError : (NSString *) errDesc : (NSString *) objectID : (NSString*) productName;
-(void) clearAndRunBatches : (int) vindex;
-(int)  countCommas : (NSString *)s;
-(void) fixError : (int) index;
-(void) fixWarning : (int) index;
-(BOOL) isErrorFixed :(NSString *)errStr;
-(BOOL) isWarningFixed :(NSString *)errStr;
-(void) getBatchCounts;
-(NSMutableArray *) getErrors;
-(NSMutableArray *) getWarnings;
-(NSString *) getVendor;
-(void) haltBatch;
-(int)  getVendorFileCount : (NSString *)vfn;
-(void) readFromParseByID : (NSString *) bID;
-(void) readFromParseByIDs : (NSArray *) bIDs  : (int) skip;
-(void) runOneOrMoreBatches  : (int) vindex;
-(void) setParent : (UIViewController*) p;
-(void) setVisualDebug : (UIViewController*) p : (NSString*)dbs;
-(void) setupCustomerFolders;

-(void) updateParse;
-(void) writeBatchReport;

@end

@protocol batchObjectDelegate <NSObject>
@required
@optional
- (void)batchUpdate : (NSString *) s;
- (void)didGetBatchCounts;
- (void)didCompleteBatch;
- (void)didFailBatch;
- (void)didReadBatchByID : (NSString *)oid;
- (void)didUpdateBatchToParse;
- (void)errorReadingBatchByID : (NSString *)err;
@end


