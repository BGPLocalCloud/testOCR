//
//    ___   ____ ____  ____       _   _   _
//   / _ \ / ___|  _ \/ ___|  ___| |_| |_(_)_ __   __ _ ___
//  | | | | |   | |_) \___ \ / _ \ __| __| | '_ \ / _` / __|
//  | |_| | |___|  _ < ___) |  __/ |_| |_| | | | | (_| \__ \
//   \___/ \____|_| \_\____/ \___|\__|\__|_|_| |_|\__, |___/
//                                                |___/
//
//  OCRSettings.m
//  testOCR
//
//  Created by Dave Scruton on 12/30/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
//  1/9  Add outputFolder
//  1/14 Add templateFolder
//  2/1  Add comparisonFolder
//  2/10 Add moveProcessedFiles

#import "OCRSettings.h"

@implementation OCRSettings

static OCRSettings *sharedInstance = nil;

#define BUFFERSIZE 256
NSString *const PS_PhotoJPEGQualityKey      = @"PhotoJPEGQuality";
NSString *const PS_BatchFolderKey           = @"BatchFolder";
NSString *const PS_OutputFolderKey          = @"OutputFolder";
NSString *const PS_ErrorFolderKey           = @"ErrorFolder";
NSString *const PS_RejectFolderKey          = @"RejectFolder";
NSString *const PS_TemplateFolderKey        = @"TemplateFolder";
NSString *const PS_ComparisonFolderKey      = @"ComparisonFolder";
NSString *const PS_MoveProcessedFilesKey    = @"MoveProcessedFiles";


//=====<OCRSettings>======================================================================
// Get the shared instance and create it if necessary.
+ (OCRSettings *)sharedInstance {
    if (sharedInstance == nil) {
        sharedInstance = [[super allocWithZone:NULL] init];
    }
    return sharedInstance;
}


//=====<OCRSettings>======================================================================
-(instancetype) init
{
    if (self = [super init])
    {
        loaded = FALSE;
        tableName = @"Settings";
        NSArray  *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        SettingsFileFullPath = [documentsDirectory stringByAppendingPathComponent:tableName];
        
        //Set up defaults in case of parse error or offline...
        _batchFolder           = batchFolderDefault            = @"latestBatch";
        _errorFolder           = errorFolderDefault            = @"errors";
        _rejectFolder          = rejectFolderDefault           = @"rejects";
        _PhotoJPEGQuality      = PhotoJPEGQualityDefault       = 0.8;
        _outputFolder          = outputFolderDefault           = @"processedBatch";
        _templateFolder        = templateFolderDefault         = @"templates";
        _comparisonFolder      = comparisonFolderDefault       = @"comparison";
        _moveProcessedFiles    = moveProcessedFilesDefault     = @"FALSE";
        [self readLocalSettings]; //Read local copy first before going to parse..
        [self loadFromParse];
    }
    
    return self;
} //end init


//=====<OCRSettings>======================================================================
-(BOOL) SettingsExists
{
    return ([[NSFileManager defaultManager] fileExistsAtPath:SettingsFileFullPath]);
}



//=====<OCRSettings>======================================================================
-(void) loadFromParse
{
    loaded = FALSE;
    PFQuery *query = [PFQuery queryWithClassName:tableName];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) { //Query came back...
            for (PFObject *objectx in objects) //We should only have one object...(see break below)
            {
               
                //DHS 6/7 photo jpeg quality param...
                self->_PhotoJPEGQuality        = [[objectx objectForKey:PS_PhotoJPEGQualityKey] doubleValue];
                self->_batchFolder             = [objectx objectForKey:PS_BatchFolderKey];
                self->_errorFolder             = [objectx objectForKey:PS_ErrorFolderKey];
                self->_rejectFolder            = [objectx objectForKey:PS_RejectFolderKey];
                self->_outputFolder            = [objectx objectForKey:PS_OutputFolderKey];
                self->_templateFolder          = [objectx objectForKey:PS_TemplateFolderKey];
                self->_comparisonFolder        = [objectx objectForKey:PS_ComparisonFolderKey];
                self->_moveProcessedFiles      = [objectx objectForKey:PS_MoveProcessedFilesKey];

                [self keepFieldsLegal];
                [self saveLocalSettings]; //Save a copy locally...
                self->loaded = TRUE;
                //NSLog(@"...settings loaded");
                break; //We only go thru once!
            }
            if (self->loaded)
            {
                [self.delegate didLoadOCRSettings];
                [self dump];
            }
            else //Failed to load? Probably called from feedVC before parse came up!
            {
                //NSLog(@" ...settings load failure...");
            }
        } //end !error
        else //Offline?
        {
            // NSLog(@" read settings: Parse ERROR");
        }
    }]; //end query
    
    
} //end loadFromParse

//=====<OCRSettings>======================================================================
-(BOOL) moveFiles
{
    BOOL moveit = FALSE;
    if ([_moveProcessedFiles.lowercaseString isEqualToString:@"true"]) moveit = TRUE;
    if ([_moveProcessedFiles.lowercaseString isEqualToString:@"yes"])  moveit = TRUE;
    return moveit;
}


//=====<OCRSettings>======================================================================
-(void) keepFieldsLegal
{
    _PhotoJPEGQuality      = [self checkFieldDoubleLimits: _PhotoJPEGQuality      : 0.05 : 1.0 : PhotoJPEGQualityDefault];
    
    //Folders? How do we make sure they are legal?
    
} // end keepFieldsLegal

//=====<OCRSettings>======================================================================
-(int) checkFieldIntLimits : (int) ival : (int) imin : (int) imax : (int) idefault
{
    if (ival < imin) ival = idefault;
    if (ival > imax) ival = idefault;
    return ival;
} //end checkFieldIntLimits


//=====<OCRSettings>======================================================================
-(double) checkFieldDoubleLimits : (double) dval : (double) dmin : (double) dmax : (double) ddefault
{
    if (dval < dmin) dval = ddefault;
    if (dval > dmax) dval = ddefault;
    return dval;
} //end checkFieldDoubleLimits

//=====<OCRSettings>======================================================================
// Reads NUMERIC settings from local storage: These are copies of what is on parse...
//  NOTE floats / doubles saved as integers 1000x
- (void) readLocalSettings
{
    //NSLog(@" readLocalSettings...");
    NSData *data;
    uint32_t buffer[BUFFERSIZE];
    if([self SettingsExists])
    {
        NSDictionary *fdict = [[NSFileManager defaultManager] attributesOfItemAtPath:SettingsFileFullPath error:nil];
        //NSLog(@" path %@",SettingsFileFullPath);
        int fsize = [[fdict valueForKey : @"NSFileSize"] intValue];
        //NSLog(@" filesize %d",fsize);
        data = [[NSFileManager defaultManager] contentsAtPath:SettingsFileFullPath];
        [data getBytes : buffer length:fsize];
        int n = 0;
        
        //DHS 6/7 Photo Jpg quality
        _PhotoJPEGQuality        = (double)buffer[n++] * 0.001;
    }
    else
    {
        // NSLog(@" ERROR! readLocalSettings: No Settings file!");
    }
    //NSLog(@" ...read OK");
    
} //end readLocalSettings



//=====<OCRSettings>======================================================================
// Saves existing NUMERIC settings to a file named SETTINGS
//  DOES NOT SAVE FOLDER NAMES
//  NOTE floats / doubles saved as integers 1000x
- (void) saveLocalSettings
{
    //NSLog(@" saveLocalSettings...");
    uint32_t buffer[BUFFERSIZE];
    //add some padding for future expansion
    for(int i = 0;i<BUFFERSIZE;i++) buffer[i] = 0;
    //Pack buffer with settings, for doubles, multiply by 1000 and save as int.
    int n = 0;
    buffer[n++]  = (int)(1000.0*_PhotoJPEGQuality);
    
    
    NSData *data = [[NSData alloc] initWithBytes:buffer length:4*BUFFERSIZE];
    [data writeToFile:SettingsFileFullPath atomically:YES];
    //NSLog(@" ....save OK");
} //end saveLocalSettings


//=====<OCRSettings>======================================================================
-(NSString *)getDumpString
{
    NSString *dumpit = @" dump OCR Default settings...\n";
    dumpit = [dumpit stringByAppendingString:[NSString stringWithFormat:@"   Photo Jpg Quality : %f\n" ,
                                              _PhotoJPEGQuality]];

    dumpit = [dumpit stringByAppendingString:[NSString stringWithFormat:@"   BatchFolder       : %@\n" ,
                                              _batchFolder]];
    dumpit = [dumpit stringByAppendingString:[NSString stringWithFormat:@"   ErrorFolder       : %@\n" ,
                                              _errorFolder]];
    dumpit = [dumpit stringByAppendingString:[NSString stringWithFormat:@"   RejectFolder      : %@\n" ,
                                              _rejectFolder]];
    dumpit = [dumpit stringByAppendingString:[NSString stringWithFormat:@"   OutputFolder      : %@\n" ,
                                              _outputFolder]];
    dumpit = [dumpit stringByAppendingString:[NSString stringWithFormat:@"   TemplateFolder    : %@\n" ,
                                              _templateFolder]];
    dumpit = [dumpit stringByAppendingString:[NSString stringWithFormat:@"   ComparisonFolder  : %@\n" ,
                                              _comparisonFolder]];
    dumpit = [dumpit stringByAppendingString:[NSString stringWithFormat:@"   MoveProcessedFiles: %@\n" ,
                                              _moveProcessedFiles]];

    return dumpit;
}
//=====<OCRSettings>======================================================================
-(void) dump
{
    NSLog(@"%@",[self getDumpString]);
    
} //end dump


//=====<OCRSettings>======================================================================


@end
