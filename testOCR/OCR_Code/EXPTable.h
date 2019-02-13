//
//   _______  ______ _____     _     _
//  | ____\ \/ /  _ \_   _|_ _| |__ | | ___
//  |  _|  \  /| |_) || |/ _` | '_ \| |/ _ \
//  | |___ /  \|  __/ | | (_| | |_) | |  __/
//  |_____/_/\_\_|    |_|\__,_|_.__/|_|\___|
//
//  EXPTable.h
//  testOCR
//
//  Created by Dave Scruton on 12/17/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Parse/Parse.h>
#import "AppDelegate.h"
#import "EXPObject.h"
#import "DBKeys.h"

@protocol EXPTableDelegate;

@interface EXPTable : NSObject
{
    NSMutableArray *objectIDs;
    NSString *tableName;
    NSString *EXPDumpCSVList;
    int totalSentCount;
    int totalReturnCount;
    int returnCounts[32]; //For up to 32 pages...
    int sentCounts[32]; //For up to 32 pages...
    NSString *allErrors;
    NSString *workProductName;
    NSString *workPDFFile;
    NSNumber *workPage;
    NSString *errorsByLineNumber[256];  // 256 invoice items?
    NSMutableArray* internalPFOs;
    NSMutableArray* csvList;

    int batchCounter;

    BOOL debugMode;   //2/7 For verbose logging...
}

@property (nonatomic, unsafe_unretained) id <EXPTableDelegate> delegate; // receiver of completion messages

@property (nonatomic , assign) BOOL sortAscending;
@property (nonatomic , strong) NSString* sortBy;
@property (nonatomic , strong) NSString* selectValue;
@property (nonatomic , strong) NSString* selectBy;
@property (nonatomic , strong) NSString* versionNumber;
@property (nonatomic , strong) NSMutableArray* expos;
@property (nonatomic , assign) BOOL      parentUp;

-(void) clear;

-(void) addRecord : (NSDate*) fdate : (NSString *) category : (NSString *) month : (NSString *) item : (NSString *) uom : (NSString *) bulk : (NSString *) vendor : (NSString *) productName : (NSString *) processed : (NSString *) local : (NSString *) lineNumber : (NSString *) invoiceNumber : (NSString *) quantity : (NSString *) pricePerUOM : (NSString *) total : (NSString *) batch : (NSString *) errStatus : (NSString *) PDFFile : (NSNumber *) page ;
-(void) addRecordFromArrays : (NSDate*) fdate : (NSArray *) fields : (NSArray*) values;
-(void) clearBatchCounter;
-(void) deleteObjectsByVendor : (NSString *)vendor;
-(void) getObjectsByIDs : (NSArray *)oids;
-(void) getObjectByID : (NSString *)oid;
-(void) fixPricesInObjectByID: (NSString *)oid  : (NSString *)productName : (NSString *)qt : (NSString *)pt : (NSString *)tt;
-(void) fixFieldInObjectByID : (NSString *)oid : (NSString *)key : (NSString *)value;
-(void) saveEXPOs;
-(void) saveToParse : (int) page : (BOOL) lastPage;
-(void) readFromParse : (NSString *) invoiceNumberstring;
-(void) readFromParseByObjIDs : (BOOL) dumptoCSV : (NSString *)vendor : (NSString *)soids;
-(void) readFromParseAsStrings : (BOOL) dumptoCSV : (NSString *)vendor : (NSString *)batch : invoiceNumberstring;
-(void) readFullTableToCSV : (int) skip : (BOOL) addErrStatus;
-(void) setTableName : (NSString *)newName;
-(NSString *) dumpToCSV;

//Gettors .... assume expos table allll loaded
-(int)  getAmount : (int) index;
-(BOOL) getLocal : (int) index;
-(BOOL) getProcessed : (int) index;
-(NSString *) getVendor : (int) index;
-(NSString *) getCategory : (int) index;
-(NSString *) getMonth : (int) index;



@end

@protocol EXPTableDelegate <NSObject>
@required
@optional
- (void)didGetObjectsByIds : (NSMutableDictionary *)d;
- (void)didReadEXPTable;
- (void)didReadFullTableToCSV : (NSString *)s;
- (void)didReadEXPTableAsStrings : (NSString *)s;
- (void)didReadEXPObjectByID :(EXPObject *)e : (PFObject*)pfo;
- (void)didSaveEXPTable : (NSArray *)a;
- (void)didFinishAllEXPRecords : (int) count : (NSArray *)a;
- (void)didFixPricesInObjectByID : (NSString *)oid;
- (void)errorFixingPricesInObjectByID : (NSString *)err;
- (void)errorInEXPRecord : (NSString *)err : (NSString *)oid : (NSString *)productName;
- (void)didSaveEXPOs ;
- (void)errorSavingEXPOs : (NSString *)err;
- (void)errorSavingEXPToParse : (NSString *)err;
@end

