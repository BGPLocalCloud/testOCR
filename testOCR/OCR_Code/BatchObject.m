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

        tableName = @"Batch";
        
        _authorized = FALSE;
        
        _versionNumber    = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];

    }
    return self;
}


//=============(BatchObject)=====================================================
-(void) addError : (NSString *) errDesc : (NSString *) objectID : (NSString*) productName
{
    //Format error and add it to array
    NSLog(@" ..batch addError %@:%@",errDesc,productName);
    NSString *errStr = [NSString stringWithFormat:@"%@:%@",errDesc,objectID];
    [errorList addObject:errStr];
    NSString *errStr2 = [NSString stringWithFormat:@"%@:%@",errDesc,productName];
    [errorReportList addObject:errStr2];
} //end addError

//=============(BatchObject)=====================================================
-(void) addWarning : (NSString *) errDesc : (NSString *) objectID : (NSString*) productName
{
    //Format error and add it to array
    NSLog(@" ..batch addWarning %@:%@",errDesc,productName);
    NSString *errStr = [NSString stringWithFormat:@"%@:%@",errDesc,objectID];
    [warningList addObject:errStr];
    NSString *errStr2 = [NSString stringWithFormat:@"%@:%@",errDesc,productName];
    [warningReportList addObject:errStr2];
} //end addWarning


//=============(BatchObject)=====================================================
// Copy error from errorList -> fixedList, leaves errorList alone!
-(void) fixError : (int) index
{
    if (index < 0 || index >= errorList.count) return;
    [fixedList addObject:[errorList objectAtIndex:index]];
}

//=============(BatchObject)=====================================================
// Copy error from errorList -> fixedList, leaves errorList alone!
-(void) fixWarning : (int) index
{
    if (index < 0 || index >= warningList.count) return;
    [warningFixedList addObject:[warningList objectAtIndex:index]];
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
    return ([batchFixed containsString:errStr]);
//    return ([fixedList containsObject:errStr]);
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
    if (vindex < 0)
    {
        NSLog(@" all vendors not implemented yet!");
        return;
    }
    if (vindex >= vv.vFolderNames.count)
    {
        NSLog(@" ERROR: illegal vendor index");
        return;
    }
    if (!_authorized) return; //can't get at dropbox w/o login!
    [self getNewBatchID];
    AppDelegate *bappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    bappDelegate.batchID = _batchID; //This way everyone can see the batch
    batchStatus   = BATCH_STATUS_RUNNING;
    batchErrors   = @"";
    batchFiles    = @"";
    batchProgress = @"";
    [errorList removeAllObjects];        //Clear error / warning accumulators
    [warningList removeAllObjects];
    [fixedList removeAllObjects];       // clear "fixed" accumulators too!
    [warningFixedList removeAllObjects];
    [errorReportList removeAllObjects];   //one set for parse storage, one for report
    [warningReportList removeAllObjects];
    [self.delegate batchUpdate : @"Started Batch..."];
    oto.batchID      = _batchID; //Make sure OCR toplevel has batchID...
    vendorName       = vv.vNames[vindex];
    vendorFolderName = vv.vFolderNames[vindex];
    vendorRotation   = vv.vRotations[vindex];
    [self updateParse];
    NSString *actData = [NSString stringWithFormat:@"%@:%@",_batchID,vendorName];
    [act saveActivityToParse:@"Batch Started" : actData];
    if (index >= 0)
    {
        gotTemplate = FALSE;
        //After template comes through THEN dropbox is queued up to start downloading!
        [ot readFromParse:vendorName]; //Get our template
    }
    else
    {
        NSLog(@" run ALL batches...");
    }
} //end runOneOrMoreBatches


//=============(BatchObject)=====================================================
-(void) completeBatch
{
    batchStatus = BATCH_STATUS_COMPLETED;
    [self updateParse];
    NSString *actData = [NSString stringWithFormat:@"%@:%@",_batchID,vendorName];
    [act saveActivityToParse:@"Batch Completed" : actData];
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
//  run OCR on all pages...
-(void) startProcessingFiles
{
    batchTotal = (int)pdfEntries.count;
    batchCount = 0;
    [self processNextFile];
} //end startProcessingFiles


//=============(BatchObject)=====================================================
// Major step in batch process, gets repeatedly called for each OCR job
-(void) processNextFile
{
    // Rename last processed file...
#ifdef RENAME_FILES_AFTER_PROCESSING
    if (batchCount > 0)
    {
        NSMutableArray *chunks = (NSMutableArray*)[lastPDFProcessed componentsSeparatedByString:@"/"];
        if (chunks.count > 2)
        {
            AppDelegate *bappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            chunks[1] = bappDelegate.settings.outputFolder;
            NSString *outputPath = [chunks componentsJoinedByString:@"/"];
            [dbt renameFile:lastPDFProcessed : outputPath];
        }
    }
#endif
    batchCount++;
    //Last file? Bail... we are now waiting on asynchronous operations to complete...
    if (batchCount > batchTotal)  return;

    int i = batchCount-1; //Batch Count is 1...n
    if (i < 0 || i >= pdfEntries.count) return; //Out of bounds!
    DBFILESMetadata *entry = pdfEntries[i];
    lastPDFProcessed = [NSString stringWithFormat:@"%@/%@",dbt.prefix,entry.name];
    //Check for "skip" string, ignore file if so...
    if ([lastPDFProcessed.lowercaseString containsString:@"skip"]) //Skip this file?
    {
        [self processNextFile];  //Re-entrant call, should be OK
    }
    else
    {
        //remember the filename...comma on 2nd... file
        if (batchCount > 1) batchFiles = [batchFiles stringByAppendingString:@","];
        batchFiles = [batchFiles stringByAppendingString:lastPDFProcessed];
        batchProgress = [NSString stringWithFormat:@"Download PDF..."];
        [self.delegate batchUpdate : batchProgress];
        //DHS 1/16 keep batch activity abreast of stuff...
        [act saveActivityToParse : batchProgress : lastPDFProcessed];
        if ([pc imageExistsByID:lastPDFProcessed : 1])  // 1/19 pdf cache more logical
        {
            NSLog(@" Cache HIT! %@",lastPDFProcessed);
            if (!gotTemplate) //Handle obvious errors
            {
                NSLog(@" ERROR: tried to process images w/o template");
                //In this case we need to wait until template comes thru??
                return;
            }

            oto.vendor = vendorName;
            oto.imageFileName = lastPDFProcessed;
            [oto performOCROnData : lastPDFProcessed : nil : CGRectZero : ot];
        }
        else
        {
            [dbt downloadImages:lastPDFProcessed];    //Asyncbonous, need to finish before handling results
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
    for (NSDictionary *d in vendorFileCounts)
    {
        if ([d[@"Vendor"] isEqualToString:vfn])
        {
            NSNumber *n = d[@"Count"];
            return n.intValue;
        }
    }
    return 0;
} //end getVendorFileCount

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

            NSLog(@" OCR Image(not pdf) page %d of %d",page,numPages);
            UIImage *ii =  dbt.batchImages[page];
            if ([vendorRotation isEqualToString:@"-90"]) //Stupid, make this better!
                ii = [it rotate90CCW:ii];
            //UIImage *deskewedImage = [it deskew:ii];
            //OUCH! THis has to be decoupled to handle the OCR returning on each image!
            [oto performOCROnImage:@"test.png" :ii :ot];
        }

    }
    else //OLD PDF DATA, potentially skewed! asdf
    {
        NSData *data = dbt.batchImageData[0];  //Raw PDF data, need to process...
        NSString *ipath = dbt.batchFileList[0]; //[paths objectAtIndex:batchPage];
        NSValue *rectObj = dbt.batchImageRects[0]; //PDF size (hopefully!)
        CGRect imageFrame = [rectObj CGRectValue];
        NSLog(@"  ...PDF imageXYWH %d %d, %d %d",
              (int)imageFrame.origin.x,(int)imageFrame.origin.y,
              (int)imageFrame.size.width,(int)imageFrame.size.height);
        oto.vendor = vendorName;
        oto.imageFileName = ipath; //@"hawaiiBeefInvoice.jpg"; //ipath;
        [oto performOCROnData : ipath : data : imageFrame : ot];

    }
    


} //end processPDFPages

//=============(BatchObject)=====================================================
// Handles each page that came back, sends data to OCR scanner, called
//  asynchronously when dropboxTools calls delegate method didDownloadImages below
-(void) processPDFPagesOLD
{
    NSLog(@" batch:processPDFPages");
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
    NSLog(@"  ...PDF imageXYWH %d %d, %d %d",
          (int)imageFrame.origin.x,(int)imageFrame.origin.y,
          (int)imageFrame.size.width,(int)imageFrame.size.height);
    oto.vendor = vendorName;
    oto.imageFileName = ipath; //@"hawaiiBeefInvoice.jpg"; //ipath;
    [oto performOCROnData : ipath : data : imageFrame : ot];
    //  [oto stubbedOCR : oto.imageFileName : [UIImage imageNamed:oto.imageFileName]  : ot];
} //end processPDFPages


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
                self->batchStatus      = pfo[PInv_BatchStatus_key];
                self->batchProgress    = pfo[PInv_BatchProgress_key];
                self->batchErrors      = pfo[PInv_BatchErrors_key];
                self->batchWarnings    = pfo[PInv_BatchWarnings_key];
                self->batchFixed       = pfo[PInv_BatchFixed_key];
                self->errorList        = (NSMutableArray*)[self->batchErrors componentsSeparatedByString:@","];
                self->fixedList        = (NSMutableArray*)[self->batchFixed  componentsSeparatedByString:@","];
                self->warningList      = (NSMutableArray*)[self->batchWarnings componentsSeparatedByString:@","];
                self->warningFixedList = (NSMutableArray*)[pfo[PInv_BatchWFixed_key]
                                                           componentsSeparatedByString:@","];
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
            pfo[PInv_BatchStatus_key]   = self->batchStatus;
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
                    NSLog(@" ...batch updated[%@]->parse",self->_batchID);
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
// Saves batch report in file named B_WHATEVERDATE.txt, saves in caches folder for now
-(void) writeBatchReport
{
    NSString *path = [NSString stringWithFormat:@"%@/%@.txt",cachesDirectory,_batchID];
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

    //Save locally...
    NSData *data =[s dataUsingEncoding:NSUTF8StringEncoding];
    [data writeToFile:path atomically:YES];
    NSLog(@" ...writeBatchReport %@",path);
    NSLog(@" ...   string %@",s);

    //Save to Dropbox...
    //last filename looks like: /inputfolder/vendor/filename.pdf
    NSMutableArray *chunks = (NSMutableArray*)[lastPDFProcessed componentsSeparatedByString:@"/"];
    if (chunks.count >= 4)
    {
        AppDelegate *bappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        chunks[1] = bappDelegate.settings.outputFolder;
        chunks[3] = [NSString stringWithFormat:@"%@_report.txt",_batchID];
//        chunks[3] = @"report.txt";
        NSString *outputPath = [chunks componentsJoinedByString:@"/"];
        DropboxTools *dbt = [DropboxTools sharedInstance];
        [dbt saveTextFile : outputPath : s];
        NSLog(@" ...report saved to dropbox: %@",outputPath);
    }
    return;
} //end writeBatchReport



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
    if (count != 0)
    {
        [vendorFileCounts addObject:@{@"Vendor": vname,@"Count":[NSNumber numberWithInt:count]}];
        [vendorFolders setObject:dbt.entries forKey:vname];
    }
    returnCount++; //Count returns, did we hit all the vendors? let delegate know
    if (returnCount == vv.vFolderNames.count)
    {
        [self->_delegate didGetBatchCounts];
    }
} //end didCountEntries


//===========<DropboxToolDelegate>================================================
- (void)didDownloadImages
{
    NSLog(@" ...downloaded all images? got %d",(int)dbt.batchImages.count);
    batchProgress = [NSString stringWithFormat:@"Fetch File %d of %d",batchCount,batchTotal];
    //At this point we have all the images for a file, ready to process!
    [self.delegate batchUpdate : batchProgress];
    [self updateParse];
    [self processPDFPages];
}  //end didDownloadImages


//===========<DropboxToolDelegate>================================================
- (void)errorDownloadingImages : (NSString *)s
{
    [self addError : s : @"n/a": @"n/a"];
}

#pragma mark - OCRTemplateDelegate

//===========<OCRTemplateDelegate>================================================
- (void)didReadTemplate
{
    NSLog(@" got template...");
    gotTemplate = TRUE;
    // This performs handoff to the actual running ...
    [dbt getBatchList : batchFolder : vendorFolderName];

}

//===========<OCRTemplateDelegate>================================================
- (void)errorReadingTemplate : (NSString *)errmsg
{
    NSString *s = [NSString stringWithFormat:@"%@ Template Error [%@]",vendorName,errmsg];
    gotTemplate = FALSE;
    [self addError : s : @"n/a": @"n/a"];
    [self completeBatch];
    //MUST END BATCH!
    //asdf
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
    NSLog(@" OCR OK page %d tp %d  count %d total %d",batchPage,batchTotalPages,batchCount,batchTotal);
    batchPage++;
    if (batchPage >= batchTotalPages)
    {
        [self processNextFile];
    }
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
        [self completeBatch];
    });
}


//===========<OCRTopObjectDelegate>================================================
- (void)didSaveOCRDataToParse : (NSString *) s
{
    NSLog(@" OK: full OCR -> DB done, invoice %@",s);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self completeBatch];
    });
}


//===========<OCRTopObjectDelegate>================================================
- (void)errorSavingEXP  : (NSString *) errMsg : (NSString*) objectID : (NSString*) productName
{
    //Record this error , gets saved with batch record
    NSString *secondArg = objectID;
    if (objectID== nil) secondArg = _batchID; //Got no DB oid? use batchID for lookup
    //Assume only 2 types for now...
    NSLog(@" exp error %@ : %@",errMsg,objectID);
    if ([[errMsg substringToIndex:2] containsString:@"E"])
        [self addError : errMsg : objectID : productName];
    else
        [self addWarning : errMsg : objectID : productName];
}



@end
