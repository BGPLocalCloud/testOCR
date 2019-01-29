//
//   ____  ____  _____ ____           _
//  |  _ \|  _ \|  ___/ ___|__ _  ___| |__   ___
//  | |_) | | | | |_ | |   / _` |/ __| '_ \ / _ \
//  |  __/| |_| |  _|| |__| (_| | (__| | | |  __/
//  |_|   |____/|_|   \____\__,_|\___|_| |_|\___|
//
//  PDFCache.h
//  testOCR
//
//  Created by Dave Scruton on 1/4/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol PDFCacheDelegate;

@interface PDFCache : NSObject
{
    NSString *cachesDirectory;         //Where all caches live
    NSString *cacheFolderPath;        //Where our cache lives
    NSString *cacheMasterFile;       //Where cache entry names are stored
    NSArray *cacheNames;            //Array of cache filenames
    NSMutableDictionary *PDFDict;  //Lookup table for filenames -> Images
}

@property (nonatomic, unsafe_unretained) id <PDFCacheDelegate> delegate; // receiver of completion messages
@property (nonatomic, strong) NSMutableArray *PDFids;
@property (nonatomic , assign) int cacheSize;

-(void) clear;
-(void) clearHardCore;
-(void) addPDFImage : (UIImage*) pdfImage : (NSString *) fname : (int) page;
-(void) dump;
-(UIImage *) getImageByID : (NSString *) inoid : (int) page;
-(BOOL) imageExistsByID : (NSString *) oidIn : (int) page;

+ (id)sharedInstance;


@end

@protocol PDFCacheDelegate <NSObject>
@required
@optional
- (void)didLoadPDFCache;
@end
