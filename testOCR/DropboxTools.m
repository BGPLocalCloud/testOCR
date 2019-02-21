//
//   ____                  _               _____           _
//  |  _ \ _ __ ___  _ __ | |__   _____  _|_   _|__   ___ | |___
//  | | | | '__/ _ \| '_ \| '_ \ / _ \ \/ / | |/ _ \ / _ \| / __|
//  | |_| | | | (_) | |_) | |_) | (_) >  <  | | (_) | (_) | \__ \
//  |____/|_|  \___/| .__/|_.__/ \___/_/\_\ |_|\___/ \___/|_|___/
//                  |_|
//
//  DropboxTools.m
//  testOCR
//
//  Created by Dave Scruton on 12/21/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
//  Looks like BIG PDF's may have to be chopped into smaller chunks:
//  https://stackoverflow.com/questions/25992238/how-to-split-pdf-into-separate-single-page-pdf-in-ios-programmatically
//
//  1/10 Add PDF cache hit to bypass downloading...
//  1/14 Add uploadPNGImage
#import "DropboxTools.h"

@implementation DropboxTools


//=============(DropboxTools)=====================================================
-(instancetype) init
{
    if (self = [super init])
    {
        _batchFileList   = [[NSMutableArray alloc] init]; //CSV data as read in from csv.txt
        _batchImages     = [[NSMutableArray alloc] init]; // Images coming in from one PDF file
        _batchImagePaths = [[NSMutableArray alloc] init]; // Filepaths for each PDF
        _batchImageRects = [[NSMutableArray alloc] init]; // Size info for each PDF
        _batchImageData  = [[NSMutableArray alloc] init]; // PDF raw data, goes into OCR
        client           = [DBClientsManager authorizedClient];
        pc               = [PDFCache sharedInstance];
    }
    return self;
}


//=============(DropboxTools)=====================================================
-(void) countEntries:(NSString *)batchFolder :(NSString *)vendorFolder
{
    //NSLog(@" ce %@",vendorFolder);
    NSString *searchPath = [NSString stringWithFormat:@"/%@/%@",batchFolder,vendorFolder];
    [[client.filesRoutes listFolder:searchPath]
     setResponseBlock:^(DBFILESListFolderResult *result, DBFILESListFolderError *routeError, DBRequestError *error) {
         if (result) { //Only handle good folders
             self->_entries = result.entries;
             int count = (int)result.entries.count;
             [self->_delegate didCountEntries:vendorFolder :count];
         }
         else
         {
             [self->_delegate didCountEntries:vendorFolder :0];
         }
     }];

} //end countEntries

//=============(DropboxTools)=====================================================
// This is in case we need to produce an error popup
-(void) setParent : (UIViewController*) p
{
    parent = p;
}


//=============(DropboxTools)=====================================================
// Must be able to handle multiple pages : adds to internal array...
-(void)addImagesFromPDFData : (NSData *)fileData : (NSString *) imagePath
{
    [_batchImageData addObject:fileData];
    CFDataRef pdfData = (__bridge CFDataRef) fileData;
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(pdfData);
    CGPDFDocumentRef pdf = CGPDFDocumentCreateWithProvider(provider);
    if (pdf)
    {
        int pageCount = (int)CGPDFDocumentGetNumberOfPages(pdf);
        //NSLog(@" PDF has %d pages",pageCount);
        for (int i = 1;i<=pageCount;i++) // loop over pages...
        {
            CGPDFPageRef PDFPage = CGPDFDocumentGetPage(pdf, i);
            if (PDFPage)
            {
                UIImage *nextImage = nil;
                // Determine the size of the PDF page.
                CGRect pageRect = CGPDFPageGetBoxRect(PDFPage, kCGPDFMediaBox);
                CGFloat PDFScale = 1.0; //view.frame.size.width/pageRect.size.width;
                pageRect.size = CGSizeMake(pageRect.size.width*PDFScale, pageRect.size.height*PDFScale);
                UIGraphicsBeginImageContext(pageRect.size);
                
                CGContextRef context = UIGraphicsGetCurrentContext();
                
                // First fill the background with white.
                CGContextSetRGBFillColor(context, 1.0,1.0,1.0,1.0);
                CGContextFillRect(context,pageRect);
                
                CGContextSaveGState(context);
                // Flip the context so that the PDF page is rendered right side up.
                CGContextTranslateCTM(context, 0.0, pageRect.size.height);
                CGContextScaleCTM(context, 1.0, -1.0);
                
                // Scale the context so that the PDF page is rendered at the correct size for the zoom level.
                CGContextScaleCTM(context, PDFScale,PDFScale);
                CGContextDrawPDFPage(context, PDFPage);
                CGContextRestoreGState(context);
                
                nextImage = UIGraphicsGetImageFromCurrentImageContext();
                if (nextImage != nil)
                {
                    NSValue *rectObj = [NSValue valueWithCGRect:pageRect];
                    [_batchImages     addObject:nextImage];
                    [_batchImagePaths addObject:imagePath];
                    [_batchImageRects addObject:rectObj];
                    //Somehow, this sent a garbage value for i!?!?
                    [pc addPDFImage:nextImage : imagePath : i];
                }
                if (i == pageCount) [_delegate didDownloadImages];
            } //end pdfpage
        } //end for i
    }  //end if pdf
} //end addImagesFromPDFData


//=============(DropboxTools)=====================================================
-(NSString*) getErrorMessage : (DBRequestError*)error
{
    NSString *message = @"";
    if ([error isInternalServerError]) {
        DBRequestInternalServerError *internalServerError = [error asInternalServerError];
        message = [NSString stringWithFormat:@"%@", internalServerError];
    } else if ([error isBadInputError]) {
        DBRequestBadInputError *badInputError = [error asBadInputError];
        message = [NSString stringWithFormat:@"%@", badInputError];
    } else if ([error isAuthError]) {
        DBRequestAuthError *authError = [error asAuthError];
        message = [NSString stringWithFormat:@"%@", authError];
    } else if ([error isRateLimitError]) {
        DBRequestRateLimitError *rateLimitError = [error asRateLimitError];
        message = [NSString stringWithFormat:@"%@", rateLimitError];
    } else if ([error isHttpError]) {
        DBRequestHttpError *genericHttpError = [error asHttpError];
        message = [NSString stringWithFormat:@"%@", genericHttpError];
    } else if ([error isClientError]) {
        DBRequestClientError *genericLocalError = [error asClientError];
        message = [NSString stringWithFormat:@"%@", genericLocalError];
    }
    return message;
} //end getErrorMessage

//=============(DropboxTools)=====================================================
// Generic folder read; passes back array of NSStrings to delegate...
-(void) getFolderList : (NSString *) folderPath 
{
    NSString *searchPath = [NSString stringWithFormat:@"/%@",folderPath]; //Prepend / to get subfolder
    [[client.filesRoutes listFolder:searchPath]
     setResponseBlock:^(DBFILESListFolderResult *result, DBFILESListFolderError *routeError, DBRequestError *error) {
         if (result) {
             if (result.entries.count > 0)
             {
                [self->_delegate didGetFolderList : result.entries];
             }
         }
     }];

} //end getFolderList

//=============(DropboxTools)=====================================================
-(void) createFolderIfNeeded : (NSString *)folderPath
{
    [[client.filesRoutes createFolderV2:folderPath]
     setResponseBlock:^(DBFILESListFolderResult *result, DBFILESListFolderError *routeError, DBRequestError *error) {
         if (result) {
             [self->_delegate didCreateFolder : folderPath];
         }
         else
         {
             [self->_delegate errorCreatingFolder : folderPath];
         }
     }];
}

//=============(DropboxTools)=====================================================
// Looks in default location for this app, we have ONLY one folder for now...
-(void) getBatchList : (NSString *) batchFolder : (NSString *) vendorFolder
{
    NSString *searchPath = [NSString stringWithFormat:@"/%@/%@",batchFolder,vendorFolder]; //Prepend / to get subfolder
    //NSLog(@"  get batchList from DB [%@]",searchPath);
    _prefix = searchPath;
    // list folder metadata contents (folder will be root "/" Dropbox folder if app has permission
    // "Full Dropbox" or "/Apps/<APP_NAME>/" if app has permission "App Folder").
    [[client.filesRoutes listFolder:searchPath]
     setResponseBlock:^(DBFILESListFolderResult *result, DBFILESListFolderError *routeError, DBRequestError *error) {
         if (result) {
             if (result.entries.count == 0) //Empty folder? No batch!
             {
                 [self->_delegate errorGettingBatchList : @"Error" : @"Empty Batch Folder"];
                 return;
             }
             self->_entries = result.entries;
             [self loadBatchEntries :result.entries];
             [self->_delegate didGetBatchList : result.entries];
         } else {
             NSString *title = @"";
             NSString *message = @"";
             if (routeError) {
                 // Route-specific request error
                 title = @"Route-specific error";
                 if ([routeError isPath]) {
                     message = [NSString stringWithFormat:@"Invalid path: %@", routeError.path];
                 }
             } else {
                 // Generic request error
                 title = @"Generic request error";
                 message = [self getErrorMessage:error];
             }
             [self errMsg:@"Dropbox read error" :message];
             [self->_delegate errorGettingBatchList : @"Error" : message];

             //  [self setFinished];
         }
     }];
}

//=============(DropboxTools)=====================================================
//DHS try adding PDF?
- (BOOL)isImageType:(NSString *)itemName {
    NSRange range = [itemName rangeOfString:@"\\.jpeg|\\.jpg|\\.JPEG|\\.JPG|\\.png|\\.pdf" options:NSRegularExpressionSearch];
    return range.location != NSNotFound;
}


//=============(DropboxTools)=====================================================
-(void) loadBatchEntries : (NSArray *)folderEntries
{
    //NSLog(@" entries %@",folderEntries);
    NSMutableArray<NSString *> *imagePaths = [NSMutableArray new];
    [_batchFileList removeAllObjects];
    for (DBFILESMetadata *entry in folderEntries) {
        NSString *itemName = entry.name;
        if ([self isImageType:itemName]) {
            [imagePaths addObject:entry.pathDisplay];
            [_batchFileList addObject:entry.pathDisplay];
        }
    }
    //2/17 list comes from dropbox in arbitrary order! Sortit...
    _batchFileList = (NSMutableArray*)[_batchFileList sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    //Make this an error message!
    if ([imagePaths count] == 0)
    {
        [self errMsg:@"Error loading batch list" :@" no entries found!"];
        NSLog(@" no entries found!");
    }
    //NSLog(@" loaded %d entries",(int)_batchFileList.count);
} //end loadBatchEntries


//=============(DropboxTools)=====================================================
// Eat CSV file spat out from another OCR provider, delegate gets didDownloadTextFile callback
- (void)downloadCSV : (NSString *)path : (NSString *)vendor
{
    DBUserClient *client = [DBClientsManager authorizedClient];
    NSLog(@" dropbox dload txt [%@[",path);
    
    [[client.filesRoutes downloadData:path]
     setResponseBlock:^(DBFILESFileMetadata *result, DBFILESDownloadError *routeError, DBRequestError *error, NSData *fileData) {
         if (result) {
             NSString *str = [[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding];
             [self->_delegate didDownloadCSVFile : vendor : str];
         }
     }];

}  //end downloadCSV

//=============(DropboxTools)=====================================================
// Eat XLS Excel SS...
//  https://stackoverflow.com/questions/21169942/use-xls-csv-or-other-type-of-file-to-make-a-float-array-in-objective-c
//  https://stackoverflow.com/questions/21169942/use-xls-csv-or-other-type-of-file-to-make-a-float-array-in-objective-c
//
- (void) downloadXLS:(NSString *)path
{
    //NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:@"https://mycoolserver.com/file.xlsx"]];
    //[_webView loadData:data MIMEType:@"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" textEncodingName:@"utf-8" baseURL:nil]
    //For now just download text?
    //[self downloadTextFile : path];
    
}  //end downloadCSV




//=============(DropboxTools)=====================================================
- (void)downloadTextFile:(NSString *)imagePath
{
    DBUserClient *client = [DBClientsManager authorizedClient];
    NSLog(@" dropbox dload txt [%@[",imagePath);
    
    [[client.filesRoutes downloadData:imagePath]
     setResponseBlock:^(DBFILESFileMetadata *result, DBFILESDownloadError *routeError, DBRequestError *error, NSData *fileData) {
         if (result) {
             NSString *str = [[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding];
             [self->_delegate didDownloadTextFile : str];
         }
     }];
    
} //end downloadTextFile


//=============(DropboxTools)=====================================================
- (void)downloadImages:(NSString *)imagePath
{
    DBUserClient *client = [DBClientsManager authorizedClient];
    NSLog(@" dropbox dload image %@",imagePath);
    
    [_batchImages     removeAllObjects];
    [_batchImagePaths removeAllObjects];
    [_batchImageData  removeAllObjects];
    [_batchImageRects removeAllObjects];
    [[client.filesRoutes downloadData:imagePath]
     setResponseBlock:^(DBFILESFileMetadata *result, DBFILESDownloadError *routeError, DBRequestError *error, NSData *fileData) {
         if (result) {
             UIImage *nextImage;
             //Got a PDF?
             if ([imagePath.lowercaseString containsString:@"pdf"])
             {
                 NSLog(@" ...found PDF file data");
                 [self addImagesFromPDFData:fileData:imagePath]; //May add more than one image!
                 return; //Delegate gets called later...
             } //end .pdf string
             else //Jpg / PNG file?
             {
                 NSLog(@" ...found jpg/png file data");
                 nextImage = [UIImage imageWithData:fileData];
                 if (nextImage != nil)
                 {
                     [self->_batchImages     addObject:nextImage];
                     [self->_batchImagePaths addObject:imagePath];
                     [self->_batchImageData  addObject:fileData];
                     [self->pc addPDFImage:nextImage : imagePath : 1];
                 }
             }
             [self->_delegate didDownloadImages];
         } else {
             NSString *title = @"";
             NSString *message = @"";
             if (routeError) {
                 // Route-specific request error
                 title = @"Route-specific error";
                 if ([routeError isPath]) {
                     message = [NSString stringWithFormat:@"Invalid path: %@", routeError.path];
                 } else if ([routeError isOther]) {
                     message = [NSString stringWithFormat:@"Unknown error: %@", routeError];
                 }
             } else {
                 // Generic request error
                 title = @"Generic request error";
                 if ([error isInternalServerError]) {
                     DBRequestInternalServerError *internalServerError = [error asInternalServerError];
                     message = [NSString stringWithFormat:@"%@", internalServerError];
                 } else if ([error isBadInputError]) {
                     DBRequestBadInputError *badInputError = [error asBadInputError];
                     message = [NSString stringWithFormat:@"%@", badInputError];
                 } else if ([error isAuthError]) {
                     DBRequestAuthError *authError = [error asAuthError];
                     message = [NSString stringWithFormat:@"%@", authError];
                 } else if ([error isRateLimitError]) {
                     DBRequestRateLimitError *rateLimitError = [error asRateLimitError];
                     message = [NSString stringWithFormat:@"%@", rateLimitError];
                 } else if ([error isHttpError]) {
                     DBRequestHttpError *genericHttpError = [error asHttpError];
                     message = [NSString stringWithFormat:@"%@", genericHttpError];
                 } else if ([error isClientError]) {
                     DBRequestClientError *genericLocalError = [error asClientError];
                     message = [NSString stringWithFormat:@"%@", genericLocalError];
                 }
             }
             [self->_delegate errorDownloadingImages:message];
             //             [self setFinished];
         }
     }];
}

//=============(DropboxTools)=====================================================
-(void) errMsg : (NSString *)title : (NSString*)message
{
    UIAlertController *alertController =
    [UIAlertController alertControllerWithTitle:title
                                        message:message
                                 preferredStyle:(UIAlertControllerStyle)UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"OK"
                                                        style:(UIAlertActionStyle)UIAlertActionStyleCancel
                                                      handler:nil]];
    [parent presentViewController:alertController animated:YES completion:nil];

} //end errMsg


//=============(DropboxTools)=====================================================
-(void) renameFile : (NSString*) fromPath : (NSString*) toPath
{
    
    DBUserClient *client = [DBClientsManager authorizedClient];
    [[[client filesRoutes] moveV2:fromPath toPath:toPath] //2/10 add error handler
     setResponseBlock:^(DBFILESFileMetadata *result, DBFILESUploadError *routeError, DBRequestError *error) {
         if (error != nil)
         {
             [self->_delegate errorRenamingFile:[self getErrorMessage:error]];
         }
     }];
} //end renameFile


//=============(DropboxTools)=====================================================
// Boilerplate code from dropbox...
-(void) saveTextFile : (NSString *)fpath : (NSString *)stringToSave
{
    NSData *fileData = [stringToSave dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    DBUserClient *client = [DBClientsManager authorizedClient];
    [[client.filesRoutes uploadData:fpath inputData:fileData]
     setResponseBlock:^(DBFILESFileMetadata *result, DBFILESUploadError *routeError, DBRequestError *error) {
         if (error != nil)
         {
             NSLog(@" error : %@",error);
         }
     }];
} //end saveBatchReport

//=============(DropboxTools)=====================================================
- (void)uploadPNGImage:(NSString *)imagePath : (UIImage *)pngImage
{
    NSData *imageData = UIImagePNGRepresentation(pngImage);
    DBUserClient *client = [DBClientsManager authorizedClient];
    [[client.filesRoutes uploadData:imagePath inputData:imageData]
     setResponseBlock:^(DBFILESFileMetadata *result, DBFILESUploadError *routeError, DBRequestError *error) {
         if (error != nil)
         {
             NSString *message = [self getErrorMessage:error];
             NSLog(@" dropbox upload error : %@",message);
             [self->_delegate errorUploadingImage:message];
         }
         else
         {
             NSLog(@" uploaded PNG->dropbox %@",imagePath);
             [self->_delegate didUploadImageFile:imagePath];
         }
     }];

} //end uploadPNGImage


@end
