//
//    ___   ____ ____  ____       _   _   _
//   / _ \ / ___|  _ \/ ___|  ___| |_| |_(_)_ __   __ _ ___
//  | | | | |   | |_) \___ \ / _ \ __| __| | '_ \ / _` / __|
//  | |_| | |___|  _ < ___) |  __/ |_| |_| | | | | (_| \__ \
//   \___/ \____|_| \_\____/ \___|\__|\__|_|_| |_|\__, |___/
//                                                |___/
//
//  OCRSettings.h
//  testOCR
//
//  Created by Dave Scruton on 12/30/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Parse/Parse.h>

@protocol OCRSettingsDelegate;

@interface OCRSettings : NSObject
{
    NSString *tableName;
    NSString *batchFolderDefault;
    NSString *errorFolderDefault;
    NSString *rejectFolderDefault;
    NSString *outputFolderDefault;
    NSString *templateFolderDefault;
    NSString *comparisonFolderDefault;
    NSString *moveProcessedFilesDefault;
    double PhotoJPEGQualityDefault;
    BOOL loaded;
    
    NSString *SettingsFileFullPath;
}

@property (nonatomic , strong) NSString *batchFolder;
@property (nonatomic , strong) NSString *errorFolder;
@property (nonatomic , strong) NSString *rejectFolder;
@property (nonatomic , strong) NSString *outputFolder;
@property (nonatomic , strong) NSString *templateFolder;
@property (nonatomic , strong) NSString *comparisonFolder;
@property (nonatomic , strong) NSString *moveProcessedFiles;
@property (nonatomic , assign) double   PhotoJPEGQuality;

@property (nonatomic, unsafe_unretained) id <OCRSettingsDelegate> delegate;

+ (id)sharedInstance;

-(BOOL) moveFiles;
-(BOOL) isLoaded;
-(NSString *)getDumpString;
-(void) dump;


@end

@protocol OCRSettingsDelegate <NSObject>
@required
@optional
- (void)didLoadOCRSettings;
@end


