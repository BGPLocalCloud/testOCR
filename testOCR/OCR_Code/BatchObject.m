//
//   ____        _       _      ___  _     _           _
//  | __ )  __ _| |_ ___| |__  / _ \| |__ (_) ___  ___| |_
//  |  _ \ / _` | __/ __| '_ \| | | | '_ \| |/ _ \/ __| __|
//  | |_) | (_| | || (__| | | | |_| | |_) | |  __/ (__| |_
//  |____/ \__,_|\__\___|_| |_|\___/|_.__// |\___|\___|\__|
//                                      |__/
//
//  BatchObject.m
//  testOCR
//
//  Created by Dave Scruton on 12/22/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
// Pull OIDs stuff asap
//  1/9 Added file rename (stubbed out for now)\
//  1/12 add OCRCache check to avoid download
//  1/24 add all vendors support, updateBatchProgress
//  1/25 add reports folder for batch reports on dropbox
//  1/29 add table deletes for batch run
//  2/4  add batch month
//  2/7  add debugMode for logging
//  2/10 enabled file rename, add majorFileError check
//  2/14 add username column, int/float quantity support
//  2/15 add setDebugMode
//  2/17 use dbt.batchFileList (sorted list of files)
//  2/23 Fix array -> mutableArray conversion bug
//  2/27 add batchID to all batch progress data
//  2/28 add call to oto.readCSVThenSaveToDropbox, username to batchReport
//  3/20 new folder structure, report output
//  3/24 change PDF renamer for multi-customer 
#import "BatchObject.h"

@implementation BatchObject

static BatchObject *sharedInstance = nil;

//=============(BatchObject)=====================================================
// Get the shared instance and create it if necessary.
+ (BatchObject *)sharedInstance {
    if (sharedInstance == nil) {
        sharedInstance = [[super allocWithZone:NULL] init];
    }
    
    return sharedInstance;
}

//=============(BatchObject)=====================================================
-(instancetype) init
{
    if (self = [super init])
    {
        vendorFileCounts  = [[NSMutableArray alloc] init];
        vendorFolders     = [[NSMutableDictionary alloc] init];
        errorList         = [[NSMutableArray alloc] init];
        warningList       = [[NSMutableArray alloc] init];
        warningFixedList  = [[NSMutableArray alloc] init];
        errorReportList   = [[NSMutableArray alloc] init];
        warningReportList = [[NSMutableArray alloc] init];
        fixedList         = [[NSMutableArray alloc] init];
        warningFixedList  = [[NSMutableArray alloc] init];
        oc                = [OCRCache sharedInstance];
        pc                = [PDFCache sharedInstance];

        gp                = [[GenParse alloc] init];
        gp.delegate = self;

        dbt = [[DropboxTools alloc] init];
        dbt.delegate = self;
        [dbt setParent:parent];
        
        ot  = [[OCRTemplate alloc] init];
        ot.delegate = self;
        AppDelegate *bappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        // 3/20 multi-customer support
        customerName = bappDelegate.selectedCustomer;
        expTableName = [NSString stringWithFormat:@"EXP_%@",customerName];
        //batchFolder = bappDelegate.settings.batchFolder;        //@"latestBatch";
        batchFolder = [bappDelegate getBatchFolderPath]; // 3/20
        oto = [OCRTopObject sharedInstance];
        oto.delegate = self;

        vv  = [Vendors sharedInstance];

        act = [[ActivityTable alloc] init];
        
        //Uses caches folder for batch reports...
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        cachesDirectory = [paths objectAtIndex:0];
        [self createBatchFolder];
        
        batchTableName = @"Batch"; //3/20
        _batchMonth    = @"01-JUL";

        _authorized = FALSE;
        
        _versionNumber    = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];

        debugMode = FALSE; //DHS 2/7
    }
    return self;
}


//=============(BatchObject)=====================================================
-(void) addError : (NSString *) errDesc : (NSString *) objectID : (NSString*) productName
{
    //Format error and add it to array
    if (debugMode) NSLog(@" ..batch addError %@:%@",errDesc,productName);
    NSString *errStr = [NSString stringWithFormat:@"%@:%@",errDesc,objectID];
    [errorList addObject:errStr];
    NSString *errStr2 = [NSString stringWithFormat:@"%@:%@",errDesc,productName];
    [errorReportList addObject:errStr2];
} //end addError

//=============(BatchObject)=====================================================
-(void) addWarning : (NSString *) errDesc : (NSString *) objectID : (NSString*) productName
{
    //Format error and add it to array
    if (debugMode) NSLog(@" ..batch addWarning %@:%@",errDesc,productName);
    NSString *errStr = [NSString stringWithFormat:@"%@:%@",errDesc,objectID];
    [warningList addObject:errStr];
    NSString *errStr2 = [NSString stringWithFormat:@"%@:%@",errDesc,productName];
    [warningReportList addObject:errStr2];
} //end addWarning


//=============(BatchObject)=====================================================
// Does table clear, and the activity table clear callback continues batch.
//   Convoluted enuf?
-(void) clearAndRunBatches : (int) vindex
{
    [self.delegate batchUpdate : @"Clear old EXP records..."];
    selectedVendor = vindex;
    NSString *vname = @"*";
    if (vindex != -1 && vindex < vv.vcount) vname = [vv getNameByIndex:vindex];  //DHS 3/6
    [self clearTables:vname];
} //end clearAndRunBatches



//=============(BatchObject)=====================================================
-(void) clearTables : (NSString *) vendor
{
    // 3/20 multi-customers
    [gp deleteAllByTableAndKey : expTableName : @"*" : @"*"];
    //3/20 there may be invoices from other customers, leave them be??
#ifdef CLEAR_INVOICES_TOO
    if ([vendor isEqualToString:@"*"]) //All vendors?
    {
        for (int i=0;i<vv.vcount;i++)  //DHS 3/6
        {
            NSString *vn = [vv getNameByIndex:i]; //DHS 3/6
            NSString *itableName = [NSString stringWithFormat:@"I_%@",vn];
            [gp deleteAllByTableAndKey:itableName : @"*" : @"*"];
        }
    }
    else
    {
        NSString *itableName = [NSString stringWithFormat:@"I_%@",vendor];
        [gp deleteAllByTableAndKey:itableName : @"*" : @"*"];
    }
#endif
} //end clearTables

//=============(BatchObject)=====================================================
-(int)countCommas : (NSString *)s
{
    if (s == nil) return 0;
    NSScanner *mainScanner = [NSScanner scannerWithString:s];
    NSString *temp;
    int nc=0;
    while(![mainScanner isAtEnd])
    {
        [mainScanner scanUpToString:@"," intoString:&temp];
        nc++;
        [mainScanner scanString:@"," intoString:nil];
    }
    return nc;
} //end countCommas


//=============(BatchObject)=====================================================
-(void) createBatchFolder
{
    cacheFolderPath  = [NSString stringWithFormat:@"%@/Batches",cachesDirectory];
    NSFileManager *NSFm= [NSFileManager defaultManager];
    [NSFm createDirectoryAtPath:cacheFolderPath
    withIntermediateDirectories:YES attributes:nil error:nil];
} //end createCacheFolder



//=============(BatchObject)=====================================================
// Copy error from errorList -> fixedList, leaves errorList alone!
-(void) fixError : (int) index
{
    if (index < 0 || index >= errorList.count) return;
    NSString *errString = [errorList objectAtIndex:index];
    if ([fixedList indexOfObject:errString] == NSNotFound) //1/23 No Dupes allowed
        [fixedList addObject:errString];
}

//=============(BatchObject)=====================================================
// Copy error from errorList -> fixedList, leaves errorList alone!
-(void) fixWarning : (int) index
{
    if (index < 0 || index >= warningList.count) return;
    NSString *warnString = [warningList objectAtIndex:index];
    if ([warningFixedList indexOfObject:warnString] == NSNotFound) //1/23 No Dupes allowed
        [warningFixedList addObject:warnString];
}


//=============(BatchObject)=====================================================
// Loop over vendors, get counts...
-(void) getBatchCounts
{
    [vendorFileCounts removeAllObjects];
    [vendorFolders removeAllObjects];
    returnCount = 0;
    for (int i=0;i<vv.vcount;i++)  //DHS 3/6
    {
        NSString *vn = [vv getFoldernameByIndex:i]; //DHS 3/6
        [dbt countEntries : batchFolder : vn];
    }
} //end getBatchCounts

//=============(BatchObject)=====================================================
-(void) getNewBatchID
{
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"MMM_dd_HH_mm"];
    _batchID = [NSString stringWithFormat:@"B_%@", [df stringFromDate:[NSDate date]]];
}

//=============(BatchObject)=====================================================
-(BOOL) isErrorFixed :(NSString *)errStr
{
//2/8    return ([batchFixed containsString:errStr]);
    return ([fixedList containsObject:errStr]);
}

//=============(BatchObject)=====================================================
-(BOOL) isWarningFixed :(NSString *)errStr
{
    return ([warningList indexOfObject :errStr] != NSNotFound);
}




//=============(BatchObject)=====================================================
// vendor vindex -1 means run ALL; called by gp delegate return!
-(void) runOneOrMoreBatches : (int) vindex
{
    if (vindex >= (int)vv.vcount) //DHS 3/6
    {
        NSLog(@" ERROR: illegal vendor index");
        return;
    }
    if (!_authorized) return; //can't get at dropbox w/o login!
    [self getNewBatchID];
    NSString *actData = [NSString stringWithFormat:@"%@:%@:%@",_batchID,vendorName,customerName];
    [act saveActivityToParse:@"Batch Started" : actData];
    
    AppDelegate *bappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    bappDelegate.batchID = _batchID; //This way everyone can see the batch
    debugMode = bappDelegate.debugMode; //2/7 For dwbug logging, check every batch
    [oto setDebugMode : debugMode];
    _batchStatus   = BATCH_STATUS_RUNNING;
    batchErrors   = @"";
    batchFiles    = @"";
    batchProgress = @"";
    [errorList removeAllObjects];        //Clear error / warning / fixed accumulators
    [warningList removeAllObjects];
    [fixedList removeAllObjects];
    [warningFixedList removeAllObjects];
    [errorReportList removeAllObjects];   //one set for parse storage, one for report
    [warningReportList removeAllObjects];
    [self.delegate batchUpdate : @"Started Batch..."];
    oto.batchID      = _batchID; //Make sure OCR toplevel has batchID...
    oto.batchMonth   = _batchMonth;
    oto.oldInvoiceNumberString = @""; //Clear old invoice # (used to discover new invoices)
    [oto clearEXPBatchCounter]; //for sorting EXP records on final output
    //Run just one vendor...
    if (vindex >= 0)
    {
        vendorIndex   = vindex;
        runAllBatches = FALSE;
        [self startBatchForCurrentVendor];
    }
    else
    {
        vendorIndex   = 0;
        runAllBatches = TRUE;
        [self startNextVendorBatch : FALSE];
        NSLog(@" run ALL batches...");
    }
} //end runOneOrMoreBatches

//=============(BatchObject)=====================================================
// 2/13 send debug display info down to children..
-(void) setVisualDebug : (UIViewController*) p : (NSString*)dbs
{
    [oto setVisualDebug : p : dbs];
}

//=============(BatchObject)=====================================================
// Get next vendor with staged files and start batch
-(void) startNextVendorBatch : (BOOL) preIncrement
{
    if (!runAllBatches) //Single vendor ? Complete batch / bail
    {
        [self completeBatch : 0 : FALSE]; //Bail on single batch only...
        return;
    }
    if (preIncrement) vendorIndex++;
    int vfcsize = (int)vv.vcount; //DHS 3/6 all one structure now
    int vfnsize = (int)vv.vcount; //DHS 3/6
    //DHS 2/14 int/floating point quantities for this vendor?
    NSString *intstr = [vv getIntQuantityByIndex : vendorIndex]; //DHS 3/6
    oto.intQuantity  = [intstr.lowercaseString isEqualToString:@"true"];
    if (debugMode) NSLog(@" vfcsize %d vs vfnsize %d",vfcsize,vfnsize);
    //NOTE filecounts can be larger than vendor counts!
    if (vendorIndex >= vfnsize) [self completeBatch : 1 : FALSE];
    //Find next vendor with staged files...
    BOOL found = FALSE;
    while (vendorIndex < vfnsize && !found)
    {
        if (debugMode) NSLog(@" vendorIndex %d vs vfnsize %d",vendorIndex,vfnsize);
        if ([self getVendorFileCount : [vv getNameByIndex:vendorIndex]] > 0) found = TRUE; //DHS 3/6
        else vendorIndex++;
    } //End while...
    //Hmm vendorindex never gets to vfnsize? 1/27
    if (vendorIndex >= vfnsize) [self completeBatch : 2 : FALSE];               //End of vendors? Done!
    else //Next vendor? Only if running all batches!
    {
        if (runAllBatches) [self startBatchForCurrentVendor]; //More? Run next batch!
        else               [self completeBatch : 3 : FALSE];
    }
} //end StartNextVendorBatch

//=============(BatchObject)=====================================================
// For each vendor: sets up batch vendor items, updates status and gets template
-(void) startBatchForCurrentVendor
{
    vendorName       = [vv getNameByIndex:vendorIndex]; //DHS 3/6 3 lines
    vendorFolderName = [vv getFoldernameByIndex:vendorIndex];
    vendorRotation   = [vv getRotationByIndex:vendorIndex];
    NSString *intstr = [vv getIntQuantityByIndex : vendorIndex]; //DHS 3/24 wups need this here!
    oto.intQuantity  = [intstr.lowercaseString isEqualToString:@"true"];
    [self updateParse];
    [self updateBatchProgress : [NSString stringWithFormat:@"Get Template:%@",vendorName] : FALSE];
    gotTemplate = FALSE;
    //After template comes through THEN dropbox is queued up to start downloading!
    [ot readFromParse:vendorName]; //Get our template, delegate return continues processing
} //end startBatchForCurrentVendor


//=============(BatchObject)=====================================================
-(void) completeBatch : (int) wherefrom : (BOOL) haltFlag
{
    if (![_batchStatus isEqualToString: BATCH_STATUS_RUNNING]) return; //In case of multiple completes?
    if ([_batchStatus  isEqualToString: BATCH_STATUS_COMPLETED]) return; //No dupes
    _batchStatus = BATCH_STATUS_COMPLETED;
    [self updateParse];
    
    NSString *actData     = [NSString stringWithFormat:@"%@:%@:%@",_batchID,vendorName,customerName];
    NSString *lilStr      = [NSString stringWithFormat:@"Batch Completed E:%d W:%d",
                             (int)errorList.count,(int)warningList.count];
    if (haltFlag) lilStr  = @"Batch Halted";
    [act saveActivityToParse : lilStr : actData];
    [self.delegate didCompleteBatch];
    [self writeBatchReport];
    // DHS 2/28
    //Long wait, what if user dismisses batchVC early??,
    //   may need to break batch complete in two
    //   around this operation!
    [oto readCSVThenSaveToDropbox];
} //end completeBatch


//=============(BatchObject)=====================================================
-(void) setParent : (UIViewController*) p
{
    parent = p;
    [dbt setParent:p];
}


//=============(BatchObject)=====================================================
// Given a list of PDF's in one vendor folder, download pDF and
//  run OCR on all pages... assumes template loaded and dbt.getBatchList was called....
-(void) startProcessingFiles
{
    batchTotal = (int)dbt.batchFileList.count; //2/17 USE presorted list duh!
    if (debugMode) NSLog(@" start processing for vendor %@ count %d",vendorName,batchTotal);
    [self updateBatchProgress : [NSString stringWithFormat:@"Process Files:%@",vendorName] : FALSE];
    batchCount = 0;
    [self processNextFile : 4];
} //end startProcessingFiles


//=============(BatchObject)=====================================================
// Major step in batch process, gets repeatedly called for each OCR job
-(void) processNextFile : (int) whereFrom
{
    if (batchCount > 0) //Have we run thru a file yet? 2/10
    {
        // Rename last processed file...
        AppDelegate *bappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        if ([bappDelegate.settings moveFiles]) //Rename files to output area after processing?
        {
            if (!majorFileError) //2/10 OK?
            {
                NSMutableArray *chunks = [[lastFileProcessed componentsSeparatedByString:@"/"] mutableCopy]; //DHS 2/23
                int ccount = (int)chunks.count;
                if (ccount > 3)
                {
                    NSString *outputPath = [NSString stringWithFormat:@"/%@/%@/%@", //3/24 multi-customer support
                                            [bappDelegate getOutputFolderPath],chunks[ccount-2],chunks[ccount-1]];
                    NSLog(@" rename %@ -> %@",lastFileProcessed , outputPath);
                    [dbt renameFile:lastFileProcessed : outputPath];
                    [self updateBatchProgress : [NSString stringWithFormat:@"...processed OK, move to output"] : FALSE];
                }
            }
            else{ //2/10 one of: Bad EXP/Invoice write, OCR failure, CSV/PDF download failure...
                [self updateBatchProgress : [NSString stringWithFormat:@"...major Error! File Not Moved"] : FALSE];
            }
        }    //end bappDelegate...
    } //end batchCount
    majorFileError = FALSE; //Clear major file error flag 2/10
    batchCount++;
    //Last file? Time for next vendor!
    if (batchCount > batchTotal) //1/28 bail when done, don't go below here
    {
        //This should be AFTER we are done with invoices!
        [self startNextVendorBatch : TRUE];
        return;
    }

    [self updateBatchProgress : [NSString stringWithFormat:@"Fetch File %d of %d",batchCount,batchTotal] : FALSE];

    int i = batchCount-1; //Batch Count is 1...n
    if (i < 0 || i >= dbt.batchFileList.count) return; //2/17 use sorted list! Out of bounds!
    DBFILESMetadata *entry = pdfEntries[i];
    lastFileProcessed = dbt.batchFileList[i]; //2/17 Use sorted results
    if (debugMode) NSLog(@" processing %@ ... (%d)",lastFileProcessed,whereFrom);
    //Check for "skip" string, ignore file if so...
    if ([lastFileProcessed.lowercaseString containsString:@"skip"]) //Skip this file?
    {
        if (debugMode) NSLog(@" ...skip %@",lastFileProcessed);
        [self updateBatchProgress : [NSString stringWithFormat:@"   skip:%@",lastFileProcessed] : FALSE];
        [self processNextFile : 0];  //Re-entrant call...
        //DHS 1/31                      may result in batch being completed!
        if ([_batchStatus  isEqualToString: BATCH_STATUS_COMPLETED]) return;
    }
    else if ([lastFileProcessed.lowercaseString containsString:@".csv"]) // CSV File?
    {
        //remember the filename...comma on 2nd... file
        if (batchCount > 1) batchFiles = [batchFiles stringByAppendingString:@","];
        batchFiles = [batchFiles stringByAppendingString:lastFileProcessed];
        [self updateBatchProgress : @"Download CSV..." : TRUE];
        [dbt downloadCSV : lastFileProcessed : vendorName];
    }
    else
    {
        //remember the filename...comma on 2nd... file
        if (batchCount > 1) batchFiles = [batchFiles stringByAppendingString:@","];
        batchFiles = [batchFiles stringByAppendingString:lastFileProcessed];
        [self updateBatchProgress : [NSString stringWithFormat:@"Download %@",
                                     [self getStrippedFilename:lastFileProcessed]] : FALSE];
        //if ([pc imageExistsByID:lastFileProcessed : 1])  // 1/19 pdf cache more logical
        //If we use the PDF cache, it's possible that the file images came down but the OCR did NOT.
        //  in that case the OCR never goes through, it gets a nil file reference and fails
        if ([oc txtExistsByID : lastFileProcessed ])  // Use OCR Cache!
        {
            if (debugMode) NSLog(@" OCR Cache HIT! %@",lastFileProcessed);
            if (!gotTemplate) //Handle obvious errors
            {
                NSLog(@" ERROR: tried to process images w/o template");
                //In this case we need to wait until template comes thru??
                return;
            }

            oto.vendor = vendorName;
            oto.imageFileName = lastFileProcessed;
            oto.ot = ot; //Hand template down to oto
            [oto performOCROnData : lastFileProcessed : nil : CGRectZero : TRUE];
        }
        else
        {
            [dbt downloadImages:lastFileProcessed];    //Asyncbonous, need to finish before handling results
        }
    }
} //end processNextFile

//=============(BatchObject)=====================================================
-(NSMutableArray *) getErrors
{
    return errorList;
}

//=============(BatchObject)=====================================================
-(NSMutableArray *) getWarnings
{
    return warningList;
}

//=============(BatchObject)=====================================================
-(NSString *) getVendor;
{
    return vendorName;
}

//=============(BatchObject)=====================================================
-(int) getVendorFileCount : (NSString *)vfn
{
    //1/28 vendorname files have underbars, NOT spaces
    NSString *vcompare = [vfn stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    for (NSDictionary *d in vendorFileCounts)
    {
        if ([d[@"Vendor"] isEqualToString:vcompare])
        {
            NSNumber *n = d[@"Count"];
            return n.intValue;
        }
    }
    return 0;
} //end getVendorFileCount

//=============(OCRTopObject)=====================================================
-(NSString*) getStrippedFilename : (NSString*) fname
{
    NSString* sfname = fname;
    NSArray *fItems    = [fname componentsSeparatedByString:@"/"];
    if (fItems.count > 1) //divided name w/ folders? just get last bit...
        sfname = fItems[fItems.count-1];
    return sfname;
} //end getStrippedFilename



//=============(BatchObject)=====================================================
// Force-Halt Batch
-(void) haltBatch
{
    [self completeBatch : 5 : TRUE];
}


//=============(BatchObject)=====================================================
// We have to pre-process PDF pages, one by one, assuming a different
//  skew per page. OUCH
-(void) processPDFPages
{
    if (!gotTemplate) //Handle obvious errors
    {
        NSLog(@" ERROR: tried to process images w/o template");
        return;
    }
    //Notify UI of progress...
    imageTools *it = [[imageTools alloc] init];
    
    int MustUseImagesBecauseWeCantDeskewData = 0;
    if (MustUseImagesBecauseWeCantDeskewData!=0)
    {
        int numPages = 1; //(int)dbt.batchImages.count;
        for (int page=0;page<numPages;page++)
        {
            batchProgress = [NSString stringWithFormat:@"File %d/%d Page %d/%d",batchCount,batchTotal,page+1,numPages];
            [self.delegate batchUpdate : batchProgress];

            if (debugMode) NSLog(@" OCR Image(not pdf) page %d of %d",page,numPages);
            UIImage *ii =  dbt.batchImages[page];
            if ([vendorRotation isEqualToString:@"-90"]) //Stupid, make this better!
                ii = [it rotate90CCW:ii];
            //UIImage *deskewedImage = [it deskew:ii];
            //OUCH! THis has to be decoupled to handle the OCR returning on each image!
             //Hand template down to oto
            oto.ot = ot; //Hand template down to oto
            [oto performOCROnImage:@"test.png" : ii];
        }

    }
    else //OLD PDF DATA, potentially skewed!
    {
        NSData *data = dbt.batchImageData[0];  //Raw PDF data, need to process...
        //NSString *ipath = dbt.batchFileList[0]; //[paths objectAtIndex:batchPage];
        NSValue *rectObj = dbt.batchImageRects[0]; //PDF size (hopefully!)
        CGRect imageFrame = [rectObj CGRectValue];
        if (debugMode) NSLog(@"  ...PDF imageXYWH %d %d, %d %d",
              (int)imageFrame.origin.x,(int)imageFrame.origin.y,
              (int)imageFrame.size.width,(int)imageFrame.size.height);
        oto.vendor = vendorName;
        oto.imageFileName = lastFileProcessed; // DHS 1/22 was using wrong filename!
        oto.ot = ot; //Hand template down to oto
        [oto performOCROnData : lastFileProcessed : data : imageFrame : TRUE];
    } //end else

} //end processPDFPages

//=============(BatchObject)=====================================================
// Handles each page that came back, sends data to OCR scanner, called
//  asynchronously when dropboxTools calls delegate method didDownloadImages below
-(void) processPDFPagesOLD
{
    if (debugMode) NSLog(@" batch:processPDFPages");
    if (!gotTemplate)
    {
        NSLog(@" ERROR: tried to process images w/o template");
        return;
    }
    batchProgress = [NSString stringWithFormat:@"Process File %d of %d",batchCount,batchTotal];
    [self.delegate batchUpdate : batchProgress];

    //Template MUST be ready at this point!
    batchPage = 0;
    NSData *data = dbt.batchImageData[0];  //Only one data set per file: MULTIPAGE!
    NSString *ipath = dbt.batchFileList[0]; //[paths objectAtIndex:batchPage];
    NSValue *rectObj = dbt.batchImageRects[0]; //PDF size (hopefully!)
    CGRect imageFrame = [rectObj CGRectValue];
    if (debugMode) NSLog(@"  ...PDF imageXYWH %d %d, %d %d",
          (int)imageFrame.origin.x,(int)imageFrame.origin.y,
          (int)imageFrame.size.width,(int)imageFrame.size.height);
    oto.vendor = vendorName;
    oto.imageFileName = ipath; //@"hawaiiBeefInvoice.jpg"; //ipath;
    oto.ot = ot;
    [oto performOCROnData : ipath : data : imageFrame  : TRUE];
    //  [oto stubbedOCR : oto.imageFileName : [UIImage imageNamed:oto.imageFileName]  : ot];
} //end processPDFPages


//=============(BatchObject)=====================================================
// Stupid but necessary: using componentsSeparatedByString somehow creates a
//  ?singleton array? which crashese when addObject is called!
-(NSMutableArray *) unpackErrorString : (NSString*)packedString
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    NSArray *dog = [packedString componentsSeparatedByString : @","];
    for (NSString *lildog in dog) [result addObject:lildog];
    return result;
}

//=============(BatchObject)=====================================================
-(void) updateBatchProgress : (NSString *)message : (BOOL) saveActivity
{
    [self.delegate batchUpdate : message]; //Should update UI if possible
    NSString* arg2 = _batchID; //DHS 2/27 make sure batchID comes thru
    if (lastFileProcessed != nil) arg2 = [NSString stringWithFormat:@"%@:%@",
                                          _batchID,lastFileProcessed];
    if (saveActivity) [act saveActivityToParse : message : arg2];
}


//=============(BatchObject)=====================================================
-(void) readFromParseByID : (NSString *) bID
{
    PFQuery *query = [PFQuery queryWithClassName:batchTableName];
    [query whereKey:PInv_BatchID_key equalTo:bID];   //Look for our batch
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) { //Query came back...
            
            if (objects.count > 0) //Got something? Update...
            {
                PFObject *pfo = objects[0];
                //Load internal fields...
                self->vendorName       = pfo[PInv_Vendor_key];
                self->customerName     = pfo[PInv_CustomerName_key];
                self->batchFiles       = pfo[PInv_BatchFiles_key];
                self->_batchStatus     = pfo[PInv_BatchStatus_key];
                self->batchProgress    = pfo[PInv_BatchProgress_key];
                self->batchErrors      = pfo[PInv_BatchErrors_key];
                self->batchWarnings    = pfo[PInv_BatchWarnings_key];
                self->batchFixed       = pfo[PInv_BatchFixed_key];
                //If there is no string, don't attempt to split stuff into an array!
                self->errorList = [self unpackErrorString:self->batchErrors];
                self->fixedList = [self unpackErrorString:self->batchFixed];
                self->warningList = [self unpackErrorString:self->batchWarnings];
                self->warningFixedList = [self unpackErrorString:pfo[PInv_BatchWFixed_key]];
                [self.delegate didReadBatchByID : bID];
            }
            else
            {
                [self.delegate didReadBatchByID : @"not found"];
            }
        }
    }];
} //end readFromParseByID


//=============(BatchObject)=====================================================
// Sloppy: this is called by a non-batch related UI, so we have to use
//  NSNotifications to get the results back since this object is a singleton!
// Just dumps result to notifications...
-(void) readFromParseByIDs : (NSArray *) bIDs
{
    PFQuery *query = [PFQuery queryWithClassName:batchTableName];
    [query whereKey:PInv_BatchID_key containedIn:bIDs];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) { //Query came back...
            [[NSNotificationCenter defaultCenter] postNotificationName:@"didReadBatchByIDs" object:objects userInfo:nil];
            }
            else
            {
                NSLog(@" error batchObject:readFromParseByIDs");
            }
    }];
} //end readFromParseByIDs


//=============(BatchObject)=====================================================
-(void) updateParse
{
    PFQuery *query = [PFQuery queryWithClassName:batchTableName];
    if (_batchID == nil)
    {
        NSLog(@" ERROR: update batchObject with null ID");
        return;
    }
    [query whereKey:PInv_BatchID_key equalTo:_batchID];   //Look for current batch
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) { //Query came back...
            PFObject *pfo;
            if (objects.count > 0) //Got something? Update...
                pfo = objects[0];
            else
                pfo = [PFObject objectWithClassName:self->batchTableName];
            pfo[PInv_BatchID_key]       = self->_batchID;
            pfo[PInv_BatchStatus_key]   = self->_batchStatus;
            pfo[PInv_Vendor_key]        = self->vendorName;
            pfo[PInv_CustomerName_key]  = self->customerName; //3/20
            pfo[PInv_BatchFiles_key]    = self->batchFiles;
            pfo[PInv_BatchProgress_key] = self->batchProgress;
            //Pack up errors / fixed...
            pfo[PInv_BatchErrors_key]   = [self->errorList componentsJoinedByString:@","];
            pfo[PInv_BatchWarnings_key] = [self->warningList componentsJoinedByString:@","];
            pfo[PInv_BatchFixed_key]    = [self->fixedList componentsJoinedByString:@","];
            pfo[PInv_BatchWFixed_key]   = [self->warningFixedList componentsJoinedByString:@","];
            pfo[PInv_VersionNumber]     = self->_versionNumber;
            NSString *uname = @"empty";  //DHS 2/14 add username column
            if ([PFUser currentUser] != nil) uname = [PFUser currentUser].username;
            pfo[PInv_UserName_key]         = uname;

            [pfo saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                if (succeeded)
                {
                    if (self->debugMode) NSLog(@" ...batch updated[%@]->parse",self->_batchID);
                    [self.delegate didUpdateBatchToParse];
                }
                else
                {
                    NSLog(@" ERROR: updating batch: %@",error.localizedDescription);
                }
            }]; //End save
        } //End !error
    }]; //End findobjects
} //end updateParse


//=============(BatchObject)=====================================================
// Saves batch report in file named B_WHATEVERDATE.txt,
//   and in dropbox processedFiles area...
-(void) writeBatchReport
{
    NSString *path = [NSString stringWithFormat:@"%@/%@.txt",cacheFolderPath,_batchID];
    //Assemble output string:
    NSString *s = @"Batch Report\n";
    //DHS 3/20 multi-customers
    AppDelegate *bappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate]; 
    s = [s stringByAppendingString:[NSString stringWithFormat:@"Customer:%@\n",bappDelegate.selectedCustomerFullName]];
    s = [s stringByAppendingString:[NSString stringWithFormat:@"ID:%@\n",_batchID]];
    // 2/28 add username to batch report!
    if ([PFUser currentUser] != nil)
        s = [s stringByAppendingString:[NSString stringWithFormat:@"Username:%@\n",[PFUser currentUser].username]];
    else
        s = [s stringByAppendingString: @"NO USERNAME...\n"];

    s = [s stringByAppendingString:[NSString stringWithFormat:@"Files %@\n",batchFiles]];
//    s = [s stringByAppendingString:[NSString stringWithFormat:@"Errors %@\n",batchErrors]];
    s = [s stringByAppendingString:[NSString stringWithFormat:@"Errors (%d found)\n",
                                    (int)errorReportList.count]];
    for (NSString *ns in errorReportList)
    {
        s = [s stringByAppendingString:[NSString stringWithFormat:@"->%@\n",ns]];
    }
    s = [s stringByAppendingString:[NSString stringWithFormat:@"Warnings (%d found)\n",
                                    (int)warningReportList.count]];
    for (NSString *ns in warningReportList)
    {
        s = [s stringByAppendingString:[NSString stringWithFormat:@"->%@\n",ns]];
    }
    batchReportString = s;
    //Save locally...
    NSData *data =[s dataUsingEncoding:NSUTF8StringEncoding];
    [data writeToFile:path atomically:YES];
    if (debugMode) NSLog(@" ...writeBatchReport local %@",path);
    if (debugMode) NSLog(@" ...   string %@",s);

    //Save to Dropbox...
    //break up lastFileProcessed, looks like: /inputfolder/vendor/filename.pdf
    NSArray *chunks = [lastFileProcessed componentsSeparatedByString:@"/"];
    if (chunks.count >= 4)
    {
        ///outputFolder/reports/fname
        AppDelegate *bappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        NSString *reportPath = [bappDelegate getReportsFolderPath]; // DHS 3/20
        [dbt createFolderIfNeeded:reportPath]; //Delegate callback handles reset
    }
    return;
} //end writeBatchReport

//===========<OCRTemplateDelegate>================================================
// Called by delegate callbacks after output folder is created or exists
-(void) finishSavingReportToDropbox : (NSString *)filePath
{
    NSString *outputPath = [NSString stringWithFormat : @"%@/%@_report.txt",filePath,_batchID];
    if (debugMode) NSLog(@" ...save report %@",outputPath);
    [dbt saveTextFile : outputPath : batchReportString];
} //end finishSavingReportToDropbox



#pragma mark - DropboxToolsDelegate

//===========<DropboxToolDelegate>================================================
// Returns with a list of all PDF's in the vendor folder
- (void)didGetBatchList : (NSArray *)a
{
    pdfEntries = a;
    [self startProcessingFiles];
}

//===========<DropboxToolDelegate>================================================
- (void)errorGettingBatchList : (NSString *) type : (NSString *)s 
{
    [self addError : s : @"n/a": @"n/a"];
}

//===========<DropboxToolDelegate>================================================
// coming back from dropbox : # files in a folder
-(void) didCountEntries:(NSString *)vname :(int)count
{
    //NSLog(@" didcountp[%@]  %d",vname,count);
    [vendorFileCounts addObject:@{@"Vendor": vname,@"Count":[NSNumber numberWithInt:count]}];
    if (count != 0)
    {
        [vendorFolders setObject:dbt.entries forKey:vname];
    }
    returnCount++; //Count returns, did we hit all the vendors? let delegate know
    if (returnCount == vv.vcount) //DHS 3/6
    {
        [self->_delegate didGetBatchCounts];
    }
} //end didCountEntries


//===========<DropboxToolDelegate>================================================
- (void)didDownloadCSVFile : (NSString *)vendor : (NSString *)result
{
    if (debugMode) NSLog(@" didDownloadCSVFile: %@ %@",vendor,result);
    [oto loadCSVValuesFromString : vendor : result]; //This does EXP writes...
}

//===========<DropboxToolDelegate>================================================
- (void)errorDownloadingCSV : (NSString *)s
{
    NSLog(@" Error Downloading CSV %@",s);
    majorFileError = TRUE; //2/10
}

//===========<DropboxToolDelegate>================================================
- (void)didDownloadImages
{
    if (debugMode) NSLog(@" ...downloaded all images? got %d",(int)dbt.batchImages.count);
    [self processPDFPages];
}  //end didDownloadImages


//===========<DropboxToolDelegate>================================================
- (void)errorDownloadingImages : (NSString *)s
{
    [self addError : s : @"n/a": @"n/a"];
    majorFileError = TRUE; //2/10
}


//===========<DropboxToolDelegate>================================================
- (void)didCreateFolder : (NSString *)folderPath
{
    [self finishSavingReportToDropbox : folderPath];
}

//===========<DropboxToolDelegate>================================================
- (void)errorCreatingFolder : (NSString *)folderPath
{
    [self finishSavingReportToDropbox : folderPath];
}

//===========<DropboxToolDelegate>================================================
// 2/10 files renamed after successful OCR... error handler
- (void)errorRenamingFile : (NSString *)s
{
    [self updateBatchProgress : [NSString stringWithFormat:@"Error Renaming PDF File:%@",s] : FALSE];
}


#pragma mark - GenParseDelegate

//===========<GenParseDelegate>================================================
// IMPORTANT: this is called at start of batch, ALL batches run thru here!
- (void)didDeleteAllByTableAndKey : (NSString *)s1 : (NSString *)s2 : (NSString *)s3
{
    if (debugMode) NSLog(@" delete OK %@/%@/%@",s1,s2,s3);
    if ([s1 isEqualToString:expTableName]) //Usually the longest table..
    {
        //OK continue running batch...
        [self runOneOrMoreBatches : selectedVendor];
    }
}

//===========<GenParseDelegate>================================================
- (void)errorDeletingAllByTableAndKey : (NSString *)s1 : (NSString *)s2 : (NSString *)s3
{
    NSLog(@" delete ERROR %@/%@/%@",s1,s2,s3);
    //PUT UP ERROR MESSAGE? or continue?
}




#pragma mark - OCRTemplateDelegate

//===========<OCRTemplateDelegate>================================================
- (void)didReadTemplate
{
    if (debugMode) NSLog(@" got template...");
    gotTemplate = TRUE;
    // This performs handoff to the actual running ...
    [self updateBatchProgress : [NSString stringWithFormat:@"Get Files:%@",vendorName] : FALSE];
    [dbt getBatchList : batchFolder : vendorFolderName];

}



//===========<OCRTemplateDelegate>================================================
- (void)errorReadingTemplate : (NSString *)errmsg
{
    NSString *s = [NSString stringWithFormat:@"%@ Template Error [%@]",vendorName,errmsg];
    gotTemplate = FALSE;
    [self addError : s : @"n/a": @"n/a"];
    [self startNextVendorBatch : TRUE];
}


#pragma mark - OCRTopObjectDelegate

//===========<OCRTopObjectDelegate>================================================
- (void)batchUpdate : (NSString *) s
{
    [self.delegate batchUpdate : s]; // pass the buck to parent
}


//===========<OCRTopObjectDelegate>================================================
- (void)didPerformOCR : (NSString *) result
{
    if (debugMode) NSLog(@" OCR OK page %d tp %d  count %d total %d",batchPage,batchTotalPages,batchCount,batchTotal);
    batchPage++;
}

//===========<OCRTopObjectDelegate>================================================
- (void)errorPerformingOCR : (NSString *) errMsg
{
    [self addError : errMsg : @"n/a": @"n/a"];
}

//===========<OCRTopObjectDelegate>================================================
- (void)fatalErrorPerformingOCR : (NSString *) errMsg
{
    [self addError : errMsg : @"n/a": @"n/a"];
    majorFileError = TRUE; //2/10
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateBatchProgress : [NSString stringWithFormat:
                                     @"Fatal OCR Error:%@",errMsg] : TRUE];
        [self processNextFile : 2];
    });
}


//===========<OCRTopObjectDelegate>================================================
- (void)didSaveOCRDataToParse : (NSString *) s
{
    if (debugMode) NSLog(@" OK: vendor OCR -> DB done, invoice %@",s);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self processNextFile : 3];
    });
}

//===========<OCRTopObjectDelegate>================================================
- (void)errorSavingOCRDataToParse : (NSString *) s
{
    NSLog(@" ERROR Saving Invoice:%@",s);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self processNextFile : 3];
    });
}



//===========<OCRTopObjectDelegate>================================================
// Called w/ bad product ID, or from errorInEXPRecord in EXP write
- (void)errorInEXPRecord  : (NSString *) errMsg : (NSString*) objectID : (NSString*) productName
{
    //Assume only 2 types for now...
    if ([[errMsg substringToIndex:2] containsString:@"E"]) //Error?
    {
        NSLog(@" exp error %@ : %@: %@",errMsg,objectID,productName);
        [self addError : errMsg : objectID : productName];
    }
    else //Warning?
        [self addWarning : errMsg : objectID : productName];
} //end errorSavingEXP

//===========<OCRTopObjectDelegate>================================================
// Parse save error only! Not related to OCR errors 2/10
- (void)errorSavingEXPToParse : (NSString *)err
{
    NSLog(@" majorFileError: saving EXP: %@",err);
    majorFileError = TRUE;
}

//===========<OCRTopObjectDelegate>================================================
- (void)errorSavingInvoiceToParse : (NSString *)err
{
    NSLog(@" majorFileError: saving Invoice: %@",err);
    majorFileError = TRUE;
}

//===========<OCRTopObjectDelegate>================================================
// 2/28 this is from this object calling oto -> parse and back...
//   too deep, should I just handle dropbox writes in oto????
- (void)didReadFullTableToCSV : (NSString *) s
{
    //OK write to dropbox.
    AppDelegate *bappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSString *folderPath = [NSString stringWithFormat : @"/%@/reports",bappDelegate.settings.outputFolder];
    [dbt saveTextFile : [NSString stringWithFormat:@"%@/%@.csv",folderPath,_batchID] :s];
}
//===========<OCRTopObjectDelegate>================================================
- (void)errorReadingFullTableToCSV : (NSString *) s
{
    NSString *errMsg = [NSString stringWithFormat:@"Error reading EXP results for CSV : %@",s];
    //Should this be a fatal error?
    [self addWarning : errMsg : @"n/a" : @"n/a"];
}


@end
