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
//  2/7 add debugMode for logging

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
        batchFolder = bappDelegate.settings.batchFolder;        //@"latestBatch";
        
        oto = [OCRTopObject sharedInstance];
        oto.delegate = self;

        vv  = [Vendors sharedInstance];

        act = [[ActivityTable alloc] init];
        
        //Uses caches folder for batch reports...
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        cachesDirectory = [paths objectAtIndex:0];
        [self createBatchFolder];
        
        tableName   = @"Batch";
        _batchMonth = @"01-JUL";

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
    [self.delegate batchUpdate : @"Clear old tables..."];
    selectedVendor = vindex;
    NSString *vname = @"*";
    if (vindex != -1 && vindex < vv.vNames.count) vname = vv.vNames[vindex];
    [self clearTables:vname];
} //end clearAndRunBatches



//=============(BatchObject)=====================================================
-(void) clearTables : (NSString *) vendor
{
   // [gp deleteAllByTableAndKey:@"Batch"    :@"*" :@"*"];
    [gp deleteAllByTableAndKey:@"EXPFullTable"      :@"*" :@"*"];
    if ([vendor isEqualToString:@"*"]) //All vendors?
    {
        for (NSString *vn in vv.vNames)
        {
            NSString *tableName = [NSString stringWithFormat:@"I_%@",vn];
            [gp deleteAllByTableAndKey:tableName : @"*" : @"*"];
        }
    }
    else
    {
        NSString *tableName = [NSString stringWithFormat:@"I_%@",vendor];
        [gp deleteAllByTableAndKey:tableName : @"*" : @"*"];
    }
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
    for (NSString *vn in vv.vFolderNames)
    {
        [dbt countEntries : batchFolder : vn];
    }
}

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
// vendor vindex -1 means run ALL
-(void) runOneOrMoreBatches : (int) vindex
{
    if (vindex >= (int)vv.vFolderNames.count)
    {
        NSLog(@" ERROR: illegal vendor index");
        return;
    }
    if (!_authorized) return; //can't get at dropbox w/o login!
    [self getNewBatchID];
    NSString *actData = [NSString stringWithFormat:@"%@:%@",_batchID,vendorName];
    [act saveActivityToParse:@"Batch Started" : actData];
    
    AppDelegate *bappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    bappDelegate.batchID = _batchID; //This way everyone can see the batch
    debugMode = bappDelegate.debugMode; //2/7 For dwbug logging, check every batch
    
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
// Get next vendor with staged files and start batch
-(void) startNextVendorBatch : (BOOL) preIncrement
{
    if (!runAllBatches) //Single vendor ? Complete batch / bail
    {
        [self completeBatch : 0 : FALSE]; //Bail on single batch only...
        return;
    }
    if (preIncrement) vendorIndex++;
    int vfcsize = (int)vv.vFileCounts.count;
    int vfnsize = (int)vv.vNames.count;
    if (debugMode) NSLog(@" vfcsize %d vs vfnsize %d",vfcsize,vfnsize);
    //NOTE filecounts can be larger than vendor counts!
    if (vendorIndex >= vfnsize) [self completeBatch : 1 : FALSE];
    //Find next vendor with staged files...
    BOOL found = FALSE;
    while (vendorIndex < vfnsize && !found)
    {
        if (debugMode) NSLog(@" vendorIndex %d vs vfnsize %d",vendorIndex,vfnsize);
        if ([self getVendorFileCount : vv.vNames[vendorIndex]] > 0) found = TRUE;
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
    vendorName       = vv.vNames[vendorIndex];
    vendorFolderName = vv.vFolderNames[vendorIndex];
    vendorRotation   = vv.vRotations[vendorIndex];  //For templates: portrait / landscape orient
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
    
    NSString *actData     = [NSString stringWithFormat:@"%@:%@",_batchID,vendorName];
    NSString *lilStr      = [NSString stringWithFormat:@"Batch Completed E:%d W:%d",
                             (int)errorList.count,(int)warningList.count];
    if (haltFlag) lilStr  = @"Batch Halted";
    [act saveActivityToParse : lilStr : actData];
    [self.delegate didCompleteBatch];
    [self writeBatchReport];
}


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
    batchTotal = (int)pdfEntries.count;
    if (debugMode) NSLog(@" start processing for vendor %@ count %d",vendorName,batchTotal);
    [self updateBatchProgress : [NSString stringWithFormat:@"Process Files:%@",vendorName] : FALSE];
    batchCount = 0;
    [self processNextFile : 4];
} //end startProcessingFiles


//=============(BatchObject)=====================================================
// Major step in batch process, gets repeatedly called for each OCR job
-(void) processNextFile : (int) whereFrom
{
    // Rename last processed file...
#ifdef RENAME_FILES_AFTER_PROCESSING
    if (batchCount > 0)
    {
        NSMutableArray *chunks = (NSMutableArray*)[lastFileProcessed componentsSeparatedByString:@"/"];
        if (chunks.count > 2)
        {
            AppDelegate *bappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            chunks[1] = bappDelegate.settings.outputFolder;
            NSString *outputPath = [chunks componentsJoinedByString:@"/"];
            [dbt renameFile:lastFileProcessed : outputPath];
        }
    }
#endif
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
    if (i < 0 || i >= pdfEntries.count) return; //Out of bounds!
    DBFILESMetadata *entry = pdfEntries[i];
    lastFileProcessed = [NSString stringWithFormat:@"%@/%@",dbt.prefix,entry.name];
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
            [oto performOCROnData : lastFileProcessed : nil : CGRectZero ];
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
        [oto performOCROnData : lastFileProcessed : data : imageFrame];
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
    [oto performOCROnData : ipath : data : imageFrame ];
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
    NSString* arg2 = @"";
    if (lastFileProcessed != nil) arg2 = lastFileProcessed;
    if (saveActivity) [act saveActivityToParse : message : arg2];
}


//=============(BatchObject)=====================================================
-(void) readFromParseByID : (NSString *) bID
{
    PFQuery *query = [PFQuery queryWithClassName:tableName];
    [query whereKey:PInv_BatchID_key equalTo:bID];   //Look for our batch
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) { //Query came back...
            
            if (objects.count > 0) //Got something? Update...
            {
                PFObject *pfo = objects[0];
                //Load internal fields...
                self->vendorName       = pfo[PInv_Vendor_key];
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
    PFQuery *query = [PFQuery queryWithClassName:tableName];
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
    PFQuery *query = [PFQuery queryWithClassName:tableName];
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
                pfo = [PFObject objectWithClassName:self->tableName];
            pfo[PInv_BatchID_key]       = self->_batchID;
            pfo[PInv_BatchStatus_key]   = self->_batchStatus;
            pfo[PInv_Vendor_key]        = self->vendorName;
            pfo[PInv_BatchFiles_key]    = self->batchFiles;
            pfo[PInv_BatchProgress_key] = self->batchProgress;
            //Pack up errors / fixed...
            pfo[PInv_BatchErrors_key]   = [self->errorList componentsJoinedByString:@","];
            pfo[PInv_BatchWarnings_key] = [self->warningList componentsJoinedByString:@","];
            pfo[PInv_BatchFixed_key]    = [self->fixedList componentsJoinedByString:@","];
            pfo[PInv_BatchWFixed_key]   = [self->warningFixedList componentsJoinedByString:@","];
            pfo[PInv_VersionNumber]     = self->_versionNumber;
            [pfo saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                if (succeeded)
                {
                    if (debugMode) NSLog(@" ...batch updated[%@]->parse",self->_batchID);
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
    //if (batchCount > 1)
    s = [s stringByAppendingString:[NSString stringWithFormat:@"ID %@\n",_batchID]];
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
    NSMutableArray *chunks = (NSMutableArray*)[lastFileProcessed componentsSeparatedByString:@"/"];
    if (chunks.count >= 4)
    {
        ///outputFolder/reports/fname
        AppDelegate *bappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        NSString *folderPath = [NSString stringWithFormat : @"/%@/reports",bappDelegate.settings.outputFolder];
        [dbt createFolderIfNeeded:folderPath]; //Delegate callback handles reset
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
    if (returnCount == vv.vFolderNames.count)
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
    NSLog(@" what next????");
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
}


//===========<OCRTemplateDelegate>================================================
- (void)didCreateFolder : (NSString *)folderPath
{
    [self finishSavingReportToDropbox : folderPath];
}

//===========<OCRTemplateDelegate>================================================
- (void)errorCreatingFolder : (NSString *)folderPath
{
    [self finishSavingReportToDropbox : folderPath];
}

#pragma mark - GenParseDelegate

//===========<GenParseDelegate>================================================
- (void)didDeleteAllByTableAndKey : (NSString *)s1 : (NSString *)s2 : (NSString *)s3
{
    if (debugMode) NSLog(@" delete OK %@/%@/%@",s1,s2,s3);
    if ([s1 isEqualToString:@"EXPFullTable"]) //Usually the longest table..
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
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateBatchProgress : [NSString stringWithFormat:@"Fatal OCR Error:%@",errMsg] : TRUE];
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
- (void)errorSavingEXP  : (NSString *) errMsg : (NSString*) objectID : (NSString*) productName
{
    //Assume only 2 types for now...
    if ([[errMsg substringToIndex:2] containsString:@"E"]) //Error?
    {
        NSLog(@" exp error %@ : %@",errMsg,objectID);
        [self addError : errMsg : objectID : productName];
    }
    else //Warning?
        [self addWarning : errMsg : objectID : productName];
} //end errorSavingEXP



@end
