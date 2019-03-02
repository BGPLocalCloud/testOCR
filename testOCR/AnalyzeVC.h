//
//  AnalyzeVC.h
//  testOCR
//
//  Created by Dave Scruton on 2/22/19.
//  Copyright © 2019 Beyond Green Partners. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#import "DropboxTools.h"
#import "imageTools.h"
#import "OCRTopObject.h"
#import "OCRDocument.h"
#import "OCRTemplate.h"
#import "OCRCache.h"
#import "PDFCache.h"
#import "spinnerView.h"
#import "Vendors.h"


@interface AnalyzeVC : UIViewController <DropboxToolsDelegate,UIScrollViewDelegate>
{
    
    UIView *selectBox;
    CGRect selectBoxRect;

    DropboxTools *dbt;
    imageTools *it;
    OCRTopObject *oto;
    OCRDocument *od;
    OCRTemplate *ot;
    OCRCache *oc;
    PDFCache *pc;
    Vendors *vv;
    spinnerView *spv;
    int page;
    NSString* fname;
    int bx,by,bw,bh;
    int iwid,ihit;
    int izoom;
    BOOL stagedSelect;
    NSString *vendorSelect;
    NSString *folderPath;

    int obx,oby,obw,obh; //OCR box in document
    CGRect obRect;
    int scrollX,scrollY;
    int clugeX,clugeY;
    NSString* ocrOutput;

    NSArray *pdfFnames;  //Fetched list of PDF files from batch folder

}

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *pageLabel;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UIImageView *pdfImage;
@property (weak, nonatomic) IBOutlet UITextView *ocrText;
@property (weak, nonatomic) IBOutlet UIView *boxView;

- (IBAction)backSelect:(id)sender;
- (IBAction)prevPageSelect:(id)sender;
- (IBAction)nextPageSelect:(id)sender;
- (IBAction)loadSelect:(id)sender;



@end


