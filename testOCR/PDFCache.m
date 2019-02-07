//
//   ____  ____  _____ ____           _
//  |  _ \|  _ \|  ___/ ___|__ _  ___| |__   ___
//  | |_) | | | | |_ | |   / _` |/ __| '_ \ / _ \
//  |  __/| |_| |  _|| |__| (_| | (__| | | |  __/
//  |_|   |____/|_|   \____\__,_|\___|_| |_|\___|
//
//  PDFCache.m
//  testOCR
//
//  Created by Dave Scruton on 1/4/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
//  1/28 move cache to PDFCache sub-folder

#import "PDFCache.h"

@implementation PDFCache

static PDFCache *sharedInstance = nil;

//=====(PDFCache)======================================================================
// Get the shared instance and create it if necessary.
+ (PDFCache *)sharedInstance {
    if (sharedInstance == nil) {
        sharedInstance = [[super allocWithZone:NULL] init];
    }
    
    return sharedInstance;
}

//=====(PDFCache)======================================================================
-(instancetype) init
{
    if (self = [super init])
    {
        //Ascii file with all cache image filenaes in it...
        cacheMasterFile = @"pdfCacheList.txt";
        PDFDict     = [[NSMutableDictionary alloc] init];
        _PDFids     = [[NSMutableArray alloc] init];
        //Check for cache folder DHS 5/24
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        cachesDirectory = [paths objectAtIndex:0];
        NSLog(@"PDF CACHEPATH[%@]",cachesDirectory);
        [self createCacheFolder];
        [self loadMasterCacheFile];
        [self loadCache];
    }
    return self;
} //end init


//=====(PDFCache)======================================================================
-(void) clear
{
    [_PDFids     removeAllObjects];
    [PDFDict     removeAllObjects];
    _cacheSize = 0;
} //end clear


//=====(PDFCache)======================================================================
// Blows away disk cache...
-(void) clearHardCore
{
    NSLog(@" CLEAR PDF CACHE HARDCORE....");
    NSString *path;
    [self clear];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // DHS 2/8/18 Remove each cache jpg imagefile...
    if (cacheNames != nil) for (NSString* workID in cacheNames)
    {
        NSString *filepath  = [NSString stringWithFormat:@"%@/%@.jpg",cacheFolderPath,workID];
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

//=====(PDFCache)======================================================================
-(void) createCacheFolder
{
    cacheFolderPath  = [NSString stringWithFormat:@"%@/PDFCache",cachesDirectory];
    NSFileManager *NSFm= [NSFileManager defaultManager];
    [NSFm createDirectoryAtPath:cacheFolderPath
        withIntermediateDirectories:YES attributes:nil error:nil];
} //end createCacheFolder

//=====(PDFCache)======================================================================
// Garbage collection: called if memory gets tight;
//   this is brute force: just blows away entire cache; a more elegant
//    solution would be to time-tag the cache entries and delete the oldest
-(void) freeupMemory
{
    [self clear];
}

//=====(PDFCache)======================================================================
-(NSString *) cleanupID : (NSString*) inoid : (int) page
{
    //First, get rid of slashes...
    NSString *oid1 = [inoid stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    // Now look for dots, remove if needed...
    NSArray *dotWords = [oid1 componentsSeparatedByString:@"."];
    NSString *oid = oid1;
    if (dotWords.count > 1) oid = dotWords[0];
    oid = [NSString stringWithFormat:@"%@_%3.3d",oid,page];
    return oid;
}


//=====(PDFCache)======================================================================
-(void) addPDFImage : (UIImage*) pdfImage : (NSString *) fname : (int) page
{
    //No Illegal stuff...
    if (pdfImage == nil || fname == nil || fname.length<2 ) return;
    NSString *oid = [self cleanupID:fname : page];
    NSLog(@"   addOCRTxt %@",fname);
    //No dupes...
    if ([_PDFids containsObject:oid])
    {
        NSLog(@"  ...PDFcache dupe [%@]...",oid);
        return;
    }
    [_PDFids addObject : oid];
    [self saveCacheImage: oid : pdfImage];
    [self updateMasterFile:oid];
    _cacheSize++;
} //end addPDFImage


//=====(PDFCache)======================================================================
// Loads master file, has cache filenames
-(void) loadMasterCacheFile
{
    NSString *path;
    NSString *fileContentsAscii;
    NSError *error;
    
    //File is .../Library/Caches/pdfCacheList.txt
    path = [NSString stringWithFormat:@"%@/%@",cacheFolderPath,cacheMasterFile];
    NSLog(@"pdfcache loadMasterFile...%@",path);
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path])
    {
        // NSLog(@" ERROR: bad/missing pdfcache master file");
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


//=====(PDFCache)======================================================================
// Tacks on new filename as ascii record at end of master file
-(void) updateMasterFile : (NSString *)latestFilename
{
    NSString *path = [NSString stringWithFormat:@"%@/%@",cacheFolderPath,cacheMasterFile];
    NSFileHandle *file;
    NSString *recordToWrite = [NSString stringWithFormat:@"%@\n",latestFilename];
    //Prepare filename for appending to master file...
    const char *utfString = [recordToWrite UTF8String];
    NSData *myData = [NSData dataWithBytes: utfString length: strlen(utfString)];
    NSLog(@" PDFCache:update master file %@ with %@",path,latestFilename);
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


//=====(PDFCache)======================================================================
//  returns NSNotFound if no match
-(NSUInteger) index : (NSString *) inoid
{
    NSString *oid = [self cleanupID:inoid : 1];
    return [_PDFids indexOfObject : oid];
}

//=====(PDFCache)======================================================================
-(UIImage *) getImageByID : (NSString *) inoid : (int) page
{
    NSString *oid   = [self cleanupID : inoid : page];
    if ([_PDFids indexOfObject : oid] == NSNotFound) return nil;
    NSString *path  = [NSString stringWithFormat:@"%@/%@.jpg",cacheFolderPath,oid];
    NSData *data    = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:path]];
    return [UIImage imageWithData: data];
}

//=====(PDFCache)======================================================================
-(BOOL) imageExistsByID : (NSString *) oidIn : (int) page
{
    if (cacheNames == nil) return FALSE; //DHS 1/22
    NSString *oid = [self cleanupID : oidIn : page];
    //NSLog(@" oid %@",oid);
    //NSLog(@" index %d",(int)[cacheNames indexOfObject:oid]);
    return ([cacheNames indexOfObject:oid] != NSNotFound); //DHS 1/10
}

//=====(PDFCache)======================================================================
// Just loads cache filenames, images are too big to load all at once...
-(void) loadCache
{
    if (cacheNames == nil) return;
    int ccount = (int)[cacheNames count];
    if (ccount <= 0) return;
    NSString *pdfFile;
    [self clear]; //Clear cache arrays just in case...
    //NSLog(@" loadPDFCache... %d items",ccount);
    for (int i=0;i<ccount;i++) // it looks like ccount is one too big, not causing trouble yet...
    {
        pdfFile   = [cacheNames objectAtIndex:i];
        [_PDFids addObject : pdfFile];
    } //end for i
    [self dump];
} //end loadCache


//=====(PDFCache)======================================================================
// Saves portrait in file named "id".txt
-(void) saveCacheImage : (NSString *) oid : (UIImage *) pdfImage
{
    NSString *path = [NSString stringWithFormat:@"%@/%@.jpg",cacheFolderPath,oid];
    [UIImageJPEGRepresentation(pdfImage, 0.75) writeToFile:path atomically:YES];
    NSLog(@" ...savecache pdf %@",path);
} //end saveCacheImage


//=====(PDFCache)======================================================================
// for debug only, this is messy!
-(void) dump
{
    NSLog(@"PDFCACHE Dump...");
    for(id key in PDFDict)
    {
        NSString *txt = [PDFDict objectForKey:key];
        if (txt == nil) txt = @"...";
        NSLog(@" --PDFID %@ txt %@",key,txt);
    }
} //end dump

@end
