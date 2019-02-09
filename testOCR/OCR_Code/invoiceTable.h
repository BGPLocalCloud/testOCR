//
//   _                 _         _____     _     _
//  (_)_ ____   _____ (_) ___ __|_   _|_ _| |__ | | ___
//  | | '_ \ \ / / _ \| |/ __/ _ \| |/ _` | '_ \| |/ _ \
//  | | | | \ V / (_) | | (_|  __/| | (_| | |_) | |  __/
//  |_|_| |_|\_/ \___/|_|\___\___||_|\__,_|_.__/|_|\___|
//
//  invoiceTable.h
//  testOCR
//
//  Created by Dave Scruton on 12/17/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Parse/Parse.h>
#import "AppDelegate.h"
#import "DBKeys.h"
#import "invoiceObject.h"


@protocol invoiceTableDelegate;

@interface invoiceTable : NSObject
{
    NSMutableArray *recordStrings;
    NSMutableArray *invoiceObjects;
    NSMutableArray *EXPIDs;
    int dog;
    NSString *tableName;
    NSString *packedOIDs;
    
    BOOL debugMode;   //2/7 For verbose logging...

}

@property (nonatomic , strong) invoiceObject* iobj;
@property (nonatomic , strong) NSString* versionNumber;

@property (nonatomic, unsafe_unretained) id <invoiceTableDelegate> delegate; // receiver of completion messages


-(void) addInvoiceItemByObjectID:(NSString *)oid;
-(void) setBasicFields : (NSDate *) ddd : (NSString*)num : (NSString*)total :
                (NSString*)vendor : (NSString*)customer : (NSString*)PDFFile : (NSString*)pageCount;
-(void) clearObjectIds;
-(int)  getItemCount;
-(void) readFromParse : (NSString *)vendor : (NSString *)invoiceNumberstring;
-(void) readFromParseAsStrings : (NSString *)vendor : batch : invoiceNumberstring;
-(void) saveToParse : (BOOL)lastPage;
-(void) setupVendorTableName : (NSString *)vname;
-(void) updateInvoice : (NSString *)vendor : (NSString *)invoiceNumberstring : (NSString *)batchID : (BOOL)lastPage;


@end

@protocol invoiceTableDelegate <NSObject>
@required
@optional
- (void)didReadInvoiceTable;
- (void)didReadInvoiceTableAsStrings : (NSMutableArray*) a;
- (void)didSaveInvoiceTable:(NSString *) s : (BOOL)lastPage;
- (void)didUpdateInvoiceTable:(NSString *) inum : (BOOL)lastPage;
- (void)errorSavingInvoiceTable:(NSString *) s : (BOOL)lastPage;

@end

