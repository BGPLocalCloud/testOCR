//
//   ____                  _               _____           _
//  |  _ \ _ __ ___  _ __ | |__   _____  _|_   _|__   ___ | |___
//  | | | | '__/ _ \| '_ \| '_ \ / _ \ \/ / | |/ _ \ / _ \| / __|
//  | |_| | | | (_) | |_) | |_) | (_) >  <  | | (_) | (_) | \__ \
//  |____/|_|  \___/| .__/|_.__/ \___/_/\_\ |_|\___/ \___/|_|___/
//                  |_|
//
//  DropboxTools.h
//  testOCR
//
//  Created by Dave Scruton on 12/21/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
//  1/25 Got rid of singleton, too many different uses across app needing delegate callbacks..

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h>
#import "PDFCache.h"
@protocol DropboxToolsDelegate;

@interface DropboxTools : NSObject
{
    UIViewController *parent;
    DBUserClient *client;
    PDFCache *pc;
}

@property (nonatomic, unsafe_unretained) id <DropboxToolsDelegate> delegate; // receiver of completion messages

@property (nonatomic , strong) NSMutableArray* batchFileList;
@property (nonatomic , strong) NSMutableArray* batchImages;
@property (nonatomic , strong) NSMutableArray* batchImagePaths;
@property (nonatomic , strong) NSMutableArray* batchImageData;
@property (nonatomic , strong) NSMutableArray* batchImageRects;

@property (nonatomic , strong) NSString* prefix;
@property (nonatomic , strong) NSArray* entries;



-(void) countEntries : (NSString *)batchFolder : (NSString *)vendorFolder;
-(void) createFolderIfNeeded : (NSString *)folderPath;

- (void)downloadImages:(NSString *)imagePath;
- (void)downloadCSV : (NSString *)path : (NSString *)vendor;
- (void)downloadTextFile:(NSString *)imagePath;
-(void) errMsg : (NSString *)title : (NSString*)message;
-(void) setParent : (UIViewController*) p;
-(void) getBatchList : (NSString *) batchFolder : (NSString *) vendorFolder;
-(void) getFolderList : (NSString *) folderPath;
-(void) renameFile : (NSString*) fromPath : (NSString*) toPath;
-(void) saveTextFile : (NSString *)fpath : (NSString *)stringToSave;
-(void) uploadPNGImage : (NSString *)imagePath : (UIImage *)pngImage;


@end


@protocol DropboxToolsDelegate <NSObject>
@required
@optional
- (void)didGetBatchList : (NSArray *)a;
- (void)didCountEntries : (NSString *)vname : (int) count;
- (void)errorGettingBatchList : (NSString *)type : (NSString *)s;
- (void)didCreateFolder : (NSString *)folderPath;
- (void)errorCreatingFolder : (NSString *)folderPath;
- (void)didDownloadImages;
- (void)didDownloadTextFile : (NSString *)result;
- (void)didDownloadCSVFile : (NSString *)vendor : (NSString *)result;
- (void)didGetFolderList : (NSArray *)entries;
- (void)errorDownloadingImages : (NSString *)s;
- (void)didUploadImageFile : (NSString *)fname;
- (void)errorUploadingImage : (NSString *)s;
@end
