//
//  OCRCache.m
//  testOCR
//
//  Created by Dave Scruton on 12/28/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
//  2/25/20 remove NSLogs

#import "OCRCache.h"

@implementation OCRCache

static OCRCache *sharedInstance = nil;

//=====(OCRCache)======================================================================
// Get the shared instance and create it if necessary.
+ (OCRCache *)sharedInstance {
    if (sharedInstance == nil) {
        sharedInstance = [[super allocWithZone:NULL] init];
    }
    
    return sharedInstance;
}

//=====(OCRCache)======================================================================
-(instancetype) init
{
    if (self = [super init])
    {
        //Ascii file with all cache image filenaes in it...
        cacheMasterFile = @"cacheList.txt";
        _OCRids     = [[NSMutableArray alloc] init];
        OCRDict     = [[NSMutableDictionary alloc] init];
        OCRRectDict = [[NSMutableDictionary alloc] init];
        //Check for cache folder DHS 5/24
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        cachesDirectory = [paths objectAtIndex:0];
        NSLog(@"CACHEPATH[%@]",cachesDirectory);
        [self createCacheFolder];
        [self loadMasterCacheFile];
        [self loadCache];
    }
    return self;
} //end init


//=====(OCRCache)======================================================================
-(void) clear
{
    [_OCRids     removeAllObjects];
    [OCRDict     removeAllObjects];
    [OCRRectDict removeAllObjects];
    _cacheSize = 0;
    
    
} //end clear


//=====(OCRCache)======================================================================
// Blows away disk cache...
-(void) clearHardCore
{
    //2/25 NSLog(@" CLEAR OCR CACHE HARDCORE....");
    NSString *path;
    [self clear];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // DHS 2/8/18 Remove each cache file...
    for (NSString* workID in cacheNames)
    {
        NSString *filepath  = [NSString stringWithFormat:@"%@/%@.txt",cacheFolderPath,workID];
        if ([fileManager fileExistsAtPath:filepath])
        {
            [fileManager removeItemAtPath: filepath error:NULL];
        }
        filepath  = [NSString stringWithFormat:@"%@/%@.rct",cacheFolderPath,workID];
        if ([fileManager fileExistsAtPath:filepath])
        {
            [fileManager removeItemAtPath: filepath error:NULL];
        }
    }
    
    path = [NSString stringWithFormat:@"%@/%@",cacheFolderPath,cacheMasterFile];
    if ([fileManager fileExistsAtPath:path])
    {
        [fileManager removeItemAtPath: path error:NULL];
    }
    
} //end clearHardCore

//=====(OCRCache)======================================================================
-(void) createCacheFolder
{
    cacheFolderPath  = [NSString stringWithFormat:@"%@/OCRCache",cachesDirectory];
    NSFileManager *NSFm= [NSFileManager defaultManager];
    [NSFm createDirectoryAtPath:cacheFolderPath
    withIntermediateDirectories:YES attributes:nil error:nil];
} //end createCacheFolder


//=====(OCRCache)======================================================================
// Garbage collection: called if memory gets tight;
//   this is brute force: just blows away entire cache; a more elegant
//    solution would be to time-tag the cache entries and delete the oldest
-(void) freeupMemory
{
    [self clear];
}


//=====(OCRCache)======================================================================
-(void) addOCRTxtWithRect : (NSString *) fname : (CGRect) r : (NSString *) txt
{
    //No Illegal stuff...
    if (fname == nil || txt == nil || txt.length<2 ) return;
    
    NSString *oid = [self cleanupID:fname];
    //2/25 NSLog(@"   addOCRTxt %@",fname);
    //No dupes...
    if ([_OCRids containsObject:oid])
    {
        //2/25 NSLog(@"  ...cache dupe [%@]...",oid);
        return;
    }
    [_OCRids addObject : oid];
    [self saveCacheFile: oid : txt];
    [self saveCacheRect: oid : r];
    [self updateMasterFile:oid];
    //[self dumpCacheToLog];
    _cacheSize++;
} //end addOCRTxtWithRect

//=====(OCRCache)======================================================================
-(NSString *) cleanupID : (NSString*) inoid
{
    //First, get rid of slashes...
    NSString *oid1 = [inoid stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    // Now look for dots, remove if needed...
    NSArray *dotWords = [oid1 componentsSeparatedByString:@"."];
    NSString *oid = oid1;
    if (dotWords.count > 1) oid = dotWords[0];
    return oid;
}


//=====(OCRCache)======================================================================
// Loads master file, has cache filenames
-(void) loadMasterCacheFile
{
    NSString *path;
    NSString *fileContentsAscii;
    NSError *error;
    
    //File is .../Library/Caches/cacheList.txt"
    path = [NSString stringWithFormat:@"%@/%@",cacheFolderPath,cacheMasterFile];
    //NSLog(@"cache loadMasterFile...%@",path);
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path])
    {
        // NSLog(@" ERROR: bad/missing cache master file");
        return ;
    }
    
    NSURL *url = [NSURL fileURLWithPath:path];
    if (url == nil)
    {
        NSLog(@" ERROR: bad cache master URL");
        return ;
    }
    fileContentsAscii = [NSString stringWithContentsOfURL:url encoding:NSASCIIStringEncoding error:&error];
    //Is this safe, loading the array straight off?
    cacheNames        = [fileContentsAscii componentsSeparatedByString:@"\n"];
    
} //end loadMasterCacheFile

//=====(OCRCache)======================================================================
// Tacks on new filename as ascii record at end of master file
-(void) updateMasterFile : (NSString *)latestFilename
{
    NSString *path = [NSString stringWithFormat:@"%@/%@",cacheFolderPath,cacheMasterFile];
    NSFileHandle *file;
    NSString *recordToWrite = [NSString stringWithFormat:@"%@\n",latestFilename];
    //Prepare filename for appending to master file...
    const char *utfString = [recordToWrite UTF8String];
    NSData *myData = [NSData dataWithBytes: utfString length: strlen(utfString)];
    //NSLog(@" OCRCache:update master file %@ with %@",path,latestFilename);
    //ok, get file handle for master...
    file = [NSFileHandle fileHandleForUpdatingAtPath:path];
    if (file == nil) //nuttin yet?
    {
        NSFileManager *filemgr =[NSFileManager defaultManager];
        [filemgr createFileAtPath:path contents:myData attributes:nil];
    }
    else //file already exists? append
    {
        [file seekToEndOfFile];
        [file writeData:myData];
        [file closeFile];
    }
    
}  //end updateMasterFile

//=====(OCRCache)======================================================================
//  returns NSNotFound if no match
-(NSUInteger) index : (NSString *) inoid
{
    NSString *oid = [self cleanupID:inoid];
    return [_OCRids indexOfObject : oid];
}

//=====(OCRCache)======================================================================
-(NSString *) getTxtByID : (NSString *) inoid
{
    NSString *oid = [self cleanupID:inoid];
    return [OCRDict objectForKey:oid];
}

//=====(OCRCache)======================================================================
-(CGRect) getRectByID : (NSString *) inoid
{
    NSString *oid = [self cleanupID:inoid];
    NSString *s = [OCRRectDict objectForKey:oid];
    if (s != nil) return  CGRectFromString(s);
    return CGRectMake(0, 0, 0, 0);
}

//=====(OCRCache)======================================================================
-(BOOL) txtExistsByID : (NSString *) oidIn
{
    NSString *oid = [self cleanupID:oidIn];
    NSString *s = [OCRDict objectForKey:oid];
    if (s == nil) return FALSE;
    return TRUE;
}


//=====(OCRCache)======================================================================
// Iterate through cachenames and load images...
-(void) loadCache
{
    int ccount = (int)[cacheNames count];
    if (ccount <= 0) return;
    NSString *ocrFile;
    NSError *error;
    NSString *path;
    [self clear]; //Clear cache arrays just in case...
    //NSLog(@" loadOCRCache... %d items",ccount);
    for (int i=0;i<ccount;i++) // it looks like ccount is one too big, not causing trouble yet...
    {
        ocrFile   = [cacheNames objectAtIndex:i];
        path      = [NSString stringWithFormat:@"%@/%@.txt",cacheFolderPath,ocrFile];
        NSString *fileContentsAscii;
        NSURL *url = [NSURL fileURLWithPath:path];
        fileContentsAscii = [NSString stringWithContentsOfURL:url encoding:NSASCIIStringEncoding error:&error];
        if (fileContentsAscii != nil)
        {
            [_OCRids addObject : ocrFile];
            [OCRDict setObject:fileContentsAscii forKey:ocrFile];
        }
        //Get Rect file...
        path = [NSString stringWithFormat:@"%@/%@.rct",cacheFolderPath,ocrFile];
        url  = [NSURL fileURLWithPath:path];
        fileContentsAscii = [NSString stringWithContentsOfURL:url encoding:NSASCIIStringEncoding error:&error];
        if (fileContentsAscii != nil) [OCRRectDict setObject:fileContentsAscii forKey:ocrFile];
    } //end for i
    //[self dump];
} //end loadCache


//=====(OCRCache)======================================================================
// Saves portrait in file named "id".txt
-(void) saveCacheFile : (NSString *) oid : (NSString *) txt
{
    NSString *path = [NSString stringWithFormat:@"%@/%@.txt",cacheFolderPath,oid];
    NSData *data =[txt dataUsingEncoding:NSUTF8StringEncoding];
    [data writeToFile:path atomically:YES];
    //2/25 NSLog(@" ...savecache txt %@",path);
    
} //end saveCacheFile

//=====(OCRCache)======================================================================
// Saves portrait in file named "id".txt
-(void) saveCacheRect : (NSString *) oid : (CGRect) r
{
    NSString *path = [NSString stringWithFormat:@"%@/%@.rct",cacheFolderPath,oid];
    NSData *data =[NSStringFromCGRect(r) dataUsingEncoding:NSUTF8StringEncoding];
    [data writeToFile:path atomically:YES];
    // 2/25 NSLog(@" ...savecache rect %@",path);
    
} //end saveCacheFile



//=====(OCRCache)======================================================================
// for debug only, this is messy!
-(void) dump
{
    NSLog(@"OCRCACHE Dump...");
    for(id key in OCRDict)
    {
        NSString *txt = [OCRDict objectForKey:key];
        NSLog(@" ------------OCRID %@ ---------txt %@",key,txt);
    }
} //end dump

@end
