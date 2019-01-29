//
//  OCRCache.h
//  testOCR
//
//  Created by Dave Scruton on 12/28/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol OCRCacheDelegate;

@interface OCRCache : NSObject
{
    NSString *cachesDirectory;         //Where all caches live
    NSString *cacheFolderPath;        //Where our cache lives
    NSString *cacheMasterFile;       //Where cache entry names are stored
    NSArray *cacheNames;            //Array of cache filenames
    NSMutableDictionary *OCRDict;  //Lookup table for filenames -> Txt
    NSMutableDictionary *OCRRectDict;  //Lookup table for filenames -> Rects
}

@property (nonatomic, unsafe_unretained) id <OCRCacheDelegate> delegate; // receiver of completion messages
@property (nonatomic, strong) NSMutableArray *OCRids;

@property (nonatomic , assign) int cacheSize;

-(void) clear;
-(void) clearHardCore;
-(void) addOCRTxtWithRect : (NSString *) fname : (CGRect) r : (NSString *) txt;
-(void) dump;
-(CGRect) getRectByID : (NSString *) inoid;
-(NSString *) getTxtByID : (NSString *) inoid;
-(BOOL) txtExistsByID : (NSString *) oidIn;

+ (id)sharedInstance;


@end

@protocol OCRCacheDelegate <NSObject>
@required
@optional
- (void)didLoadOCRCache;
@end
