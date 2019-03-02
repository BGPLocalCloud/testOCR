//
//  AnalyzeVC.m
//  testOCR
//
//  Created by Dave Scruton on 2/22/19.
//  Copyright © 2019 Beyond Green Partners. All rights reserved.
//   Scrolling tutorial 
//  https://www.raywenderlich.com/560-uiscrollview-tutorial-getting-started

#import "AnalyzeVC.h"

@interface AnalyzeVC ()

@end

@implementation AnalyzeVC

//=============AnalyzeVC=====================================================
-(id)initWithCoder:(NSCoder *)aDecoder {
    if ( !(self = [super initWithCoder:aDecoder]) ) return nil;
    
    dbt = [[DropboxTools alloc] init];
    dbt.delegate = self;
    [dbt setParent:self];
    it = [[imageTools alloc] init];
    oc = [OCRCache sharedInstance];
    pc = [PDFCache sharedInstance];
    vv  = [Vendors sharedInstance];
    oto = [OCRTopObject sharedInstance];
    od  = [[OCRDocument alloc] init];
    ot  = [[OCRTemplate alloc] init];
    
    pdfFnames = [[NSArray alloc] init];
    
    page      = 1; //Use PDF page count
    fname     = @"";
    ocrOutput = @"";
 
    clugeX = 160;
    clugeY = 160;
    NSLog(@" init clugexy %d %d",clugeX,clugeY);
    return self;
}


//=============AnalyzeVC=====================================================
- (void)viewDidLoad {
    [super viewDidLoad];
    CGSize csz   = [UIScreen mainScreen].bounds.size;
    spv = [[spinnerView alloc] initWithFrame:CGRectMake(0, 0, csz.width, csz.height)];
    [self.view addSubview:spv];
    _scrollView.delegate=self;
    
    // Clear centered box with black border
    _boxView.backgroundColor = [UIColor clearColor];
    _boxView.layer.borderWidth = 2;
    _boxView.layer.borderColor = [UIColor blackColor].CGColor;
    //Now center it over scrollview
    CGRect rr = _scrollView.frame;
    CGRect br = _boxView.frame;
    bw = bh = br.size.width;
    br.origin.x = rr.origin.x + rr.size.width/2 - bw/2;
    br.origin.y = rr.origin.y + rr.size.height/2 - bw/2;
    _boxView.frame = br;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didPerformOCR:)
                                                 name:@"didPerformOCR" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(errorPerformingOCR:)
                                                 name:@"errorPerformingOCR" object:nil];

    
}  //end viewDidLoad



//=============AnalyzeVC=====================================================
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    NSLog(@" didscroll");
    CGPoint p = scrollView.contentOffset;
    float x = p.x;
    float y = p.y;
    scrollX = (int)p.x;
    scrollY = (int)p.y;
    NSLog(@" x %f y %f",x,y);
    NSLog(@" zxy %f %f",(float)izoom*x,(float)izoom*y);
    [self getOBRect];
    [self updateOCRText];
    
}

//=============AnalyzeVC=====================================================
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self updateUI];
} //end viewDidAppear

//=============AnalyzeVC=====================================================
-(void) getOBRect
{
    obx = (scrollX * izoom) + clugeX;
    oby = (scrollY * izoom) + clugeY;
    obw = izoom * 2*bw;
    obh = izoom * 2*bh;
    obRect = CGRectMake(obx, oby, obw, obh);

}

//=============AnalyzeVC=====================================================
- (IBAction)prevPageSelect:(id)sender
{
    clugeX-=10;
    [self getOBRect];
    NSLog(@" clugeXY %d %d",clugeX,clugeY);
    [self updateOCRText];
}

//=============AnalyzeVC=====================================================
- (IBAction)nextPageSelect:(id)sender
{
    clugeX+=10;
    [self getOBRect];
    NSLog(@" clugeXY %d %d",clugeX,clugeY);
    [self updateOCRText];
}

//=============AnalyzeVC=====================================================
- (IBAction)loadSelect:(id)sender
{
    [self loadMenu];
}

//=============AnalyzeVC=====================================================
- (IBAction)backSelect:(id)sender
{
    [self dismiss];
}


//=============AnalyzeVC=====================================================
-(void) loadMenu
{
    NSMutableAttributedString *tatString = [[NSMutableAttributedString alloc]initWithString:@"Load From:"];
    [tatString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:30] range:NSMakeRange(0, tatString.length)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
                                NSLocalizedString(@"Load From:",nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert setValue:tatString forKey:@"attributedTitle"];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Staged Files",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                  [self loadStagedMenu];
                                              }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Processed Files",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                  [self loadProcessedMenu];
                                              }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                              }]];
    [self presentViewController:alert animated:YES completion:nil];
    
    
} //end loadMmenu

//=============AnalyzeVC=====================================================
-(void) loadStagedMenu
{
    stagedSelect = TRUE;
    NSMutableAttributedString *tatString = [[NSMutableAttributedString alloc]initWithString:@"Select Staged Vendor:"];
    [tatString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:30] range:NSMakeRange(0, tatString.length)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
                                NSLocalizedString(@"Select Staged Vendor:",nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert setValue:tatString forKey:@"attributedTitle"];
    for (NSString *s in vv.vNames)
    {
        [alert addAction: [UIAlertAction actionWithTitle:s
                                                   style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                       self->vendorSelect = s;
                                                       [self getVendorFiles];
                                                   }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                              }]];
    [self presentViewController:alert animated:YES completion:nil];
    
    
} //end loadStagedMenu

//=============AnalyzeVC=====================================================
-(void) loadProcessedMenu
{
    stagedSelect = FALSE;
    NSMutableAttributedString *tatString = [[NSMutableAttributedString alloc]initWithString:@"Select Processed Vendor:"];
    [tatString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:30] range:NSMakeRange(0, tatString.length)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
                                NSLocalizedString(@"Select Processed Vendor:",nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert setValue:tatString forKey:@"attributedTitle"];
    for (NSString *s in vv.vNames)
    {
        [alert addAction: [UIAlertAction actionWithTitle:s
                                                   style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                       self->vendorSelect = s;
                                                       [self getVendorFiles];
                                                   }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                              }]];
    [self presentViewController:alert animated:YES completion:nil];
    
    
} //end loadStagedMenu

//=============AnalyzeVC=====================================================
-(void) getVendorFiles
{
    NSLog(@" chooseit %d %@",stagedSelect,vendorSelect);
    AppDelegate *bappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    if (stagedSelect)
    {
        folderPath = [NSString stringWithFormat : @"/%@",bappDelegate.settings.batchFolder];
    }
    else{
        folderPath = [NSString stringWithFormat : @"/%@",bappDelegate.settings.outputFolder];
    }
    [spv start : @"Get Folder List"];
    [dbt getBatchList : folderPath : vendorSelect];
    
} //end chooseVendor

//=============AnalyzeVC=====================================================
-(void) chooseFile
{
    NSString *tstr = [NSString stringWithFormat:@"Vendor : %@",vendorSelect];
    NSMutableAttributedString *tatString = [[NSMutableAttributedString alloc]initWithString:tstr];
    [tatString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:30] range:NSMakeRange(0, tatString.length)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:tstr
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert setValue:tatString forKey:@"attributedTitle"];
    for (NSString *s in pdfFnames) //Look at our PDF list...
    {
        NSArray *sstrs  = [s componentsSeparatedByString:@"/"]; //Peel off last part of path -> filename
        NSString *fname = sstrs[sstrs.count-1];
        [alert addAction: [UIAlertAction actionWithTitle:fname
                                                   style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                       [self loadPDF : s];
                                                   }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                              }]];
    [self presentViewController:alert animated:YES completion:nil];
    
    
} //end loadStagedMenu

//=============AnalyzeVC=====================================================
-(void) loadPDF : (NSString *)sfname
{
    fname = sfname;
    NSLog(@" loadit %@/%@",folderPath,sfname);
    if ([oc txtExistsByID : sfname])
    {
        //Got OCR? load document?
        NSLog(@" got OCR");
        [oto performOCROnData : sfname : nil : CGRectZero : FALSE];
        //Still need to get image! (assume if OCR is in cache, PDF is in cache too)
        UIImage *ii = [pc getImageByID:sfname : page];
        //Does this vendor usually have XY flipped scans?
        NSString *rot = [vv getRotationByVendorName:vendorSelect];
        if ([rot isEqualToString:@"-90"]) ii = [it rotate90CCW : ii];
        _pdfImage.image = ii;
        iwid = ii.size.width;
        ihit = ii.size.height;
    }
    else
    {
        [spv start : @"Download PDF"];
        [dbt downloadImages:sfname];
    }
} //end loadPDF

//=============AnalyzeVC=====================================================
-(void) dismiss
{
   // et.parentUp = FALSE; //2/9 Tell expTable we are outta here
    [self dismissViewControllerAnimated : YES completion:nil];
}

//=============AnalyzeVC=====================================================
-(void) updateOCRText
{
    NSLog(@" ocr rect %@",NSStringFromCGRect(obRect));
    NSMutableArray *a = [od findAllWordsInRect:obRect];
    NSString *daWoids = [od assembleWordFromArray : a : false : 10];
    NSLog(@"OCR: %d words",(int)a.count);
    NSLog(@"     %@",daWoids);
    _ocrText.text = daWoids;

}

//=============AnalyzeVC=====================================================
-(void) updateUI
{
    _titleLabel.text = fname;
    if (page == 0) _pageLabel.text  = @"...";
    else _pageLabel.text  = [NSString stringWithFormat:@"%d",page];
    _ocrText.text = ocrOutput;
    //Zoom up by 8x
    UIView *v = _pdfImage;
    int vw = v.bounds.size.width;
    int vh = v.bounds.size.height;
    izoom = 1;
    CGAffineTransform t = v.transform;
    t = CGAffineTransformMakeScale(izoom,izoom);
    v.transform = t;
    v.center = CGPointMake(vw*izoom/2, vh*izoom/2);
    _scrollView.contentSize = CGSizeMake(vw,vh);
    [_scrollView setZoomScale:(float)izoom];
//    _scrollView.contentSize = CGSizeMake(vw*izoom, vh*izoom);
    [_scrollView setContentOffset:CGPointMake(0,0) animated:NO];


} //end updateUI

//=============AnalyzeVC=====================================================
-(void) finishSettingPDFImage : (UIImage *)ii
{
    //Now do OCR...
    [spv start : @"Perform OCR"];
    oto.imageFileName = fname;
    oto.ot = nil; //Hand template down to oto
    NSValue *rectObj = dbt.batchImageRects[0]; //PDF size (hopefully!)
    CGRect imageFrame = [rectObj CGRectValue];
    NSData *data = dbt.batchImageData[0];  //Only one data set per file: MULTIPAGE!

    //2/23: use DATA not image!
    [oto performOCROnData:fname : data : imageFrame : FALSE];

    //Does this vendor usually have XY flipped scans?
    NSString *rot = [vv getRotationByVendorName:vendorSelect];
    if ([rot isEqualToString:@"-90"]) ii = [it rotate90CCW : ii];
    _pdfImage.image = ii;
    iwid = ii.size.width;
    ihit = ii.size.height;
//    [self zoomPDFView : 1.8];
    [self updateUI];

} //end finishSettingPDFImage


//=============AnalyzeVC=====================================================
-(void) errorMessage : (NSString *) title :(NSString *) msg
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
                                NSLocalizedString(title,nil)  message:msg
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                              }]];
    [self presentViewController:alert animated:YES completion:nil];
    
} //end errorMessage


#pragma mark - DropboxToolsDelegate

//===========<DropboxToolDelegate>================================================
// Returns with a list of all PDF's in the vendor folder
- (void)didGetBatchList : (NSArray *)a
{
    [spv stop];
    pdfFnames = dbt.batchFileList;
    [self chooseFile];
}

//===========<DropboxToolDelegate>================================================
- (void)errorGettingBatchList : (NSString *) type : (NSString *)s
{
    [spv stop];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self errorMessage:@"Error Reading Folder" :s];
    });
}

//===========<DropboxToolDelegate>================================================
- (void)didDownloadImages
{
    [spv stop];
    if (page < 0 || page >= dbt.batchImages.count) return;
    UIImage *ii = dbt.batchImages[page];
    [self finishSettingPDFImage:ii];

}

//===========<DropboxToolDelegate>================================================
- (void)errorDownloadingImages : (NSString *)s
{
    [spv stop];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self errorMessage:@"Error Downloading PDF" :s];
        });

}


#pragma mark - Notifications from OCRTopObject

//=============OCR MainVC=====================================================
- (void)errorPerformingOCR:(NSNotification *)notification
{
    NSString *errmsg = (NSString*)notification.object;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self errorMessage:@"Error Performing OCR" : errmsg];
    });
}  //end viewDidLoad

//=============OCR MainVC=====================================================
- (void)didPerformOCR:(NSNotification *)notification
{
    NSLog(@" didPerformOCR");
    od = (OCRDocument*)notification.object; //Note this ISN'T a copy! don't modify it!
    [od setupPage:page-1]; //NOTE must change on page +/-!!
    NSLog(@" annnd doc is %@",od);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->spv stop];
        [self updateOCRText];
    });
} //end didReadBatchByIDs



@end
