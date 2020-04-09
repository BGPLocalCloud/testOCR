//
//
//     _                _             __     ______
//    / \   _ __   __ _| |_   _ ______\ \   / / ___|
//   / _ \ | '_ \ / _` | | | | |_  / _ \ \ / / |
//  / ___ \| | | | (_| | | |_| |/ /  __/\ V /| |___
// /_/   \_\_| |_|\__,_|_|\__, /___\___| \_/  \____|
//                        |___/
//
//  AnalyzeVC.m
//  testOCR
//
//  Created by Dave Scruton on 2/22/19.
//  Copyright © 2019 Beyond Green Partners. All rights reserved.
//   Scrolling tutorial 
//  https://www.raywenderlich.com/560-uiscrollview-tutorial-getting-started
//  3/20 new folder structure
//  4/5/20 change errorPerformingOCR, to errorPerformingOCRNotification

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

    obstep = 10; //Stepsize for select box size changes

    clugeX =  90;
    clugeY = 0;
    NSLog(@" init clugexy %d %d",clugeX,clugeY);
    return self;
}


//=============AnalyzeVC=====================================================
- (void)viewDidLoad {
    [super viewDidLoad];
    CGSize csz   = [UIScreen mainScreen].bounds.size;
    spv = [[spinnerView alloc] initWithFrame:CGRectMake(0, 0, csz.width, csz.height)];
    viewWid = csz.width;
    viewHit = csz.height;
    [self.view addSubview:spv];
    _scrollView.delegate=self;
    
    
    int xi,yi,xs,ys;
    xs = ys = viewWid;
    xi = 0;
    yi = viewHit/2 - viewWid/2;
    _scrollView.frame = CGRectMake(xi,yi,xs,ys);
    _pdfImage.image = [UIImage imageNamed:@"hfm90.jpg"];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didPerformOCR:)
                                                 name:@"didPerformOCR" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(errorPerformingOCRNotification:)
                                                 name:@"errorPerformingOCRNotification" object:nil];

    
}  //end viewDidLoad



//=============AnalyzeVC=====================================================
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    NSLog(@" didscroll");
    CGPoint p = scrollView.contentOffset;
//    float x = p.x;
//    float y = p.y;
    scrollX = (int)p.x;
    scrollY = (int)p.y;
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
    int topLeftX = zoomwid/4 - marginX;
    int topLeftY = zoomhit/4 - marginY;
    
    NSLog(@" scrollx %d topleftX %d",scrollX,topLeftX);
    NSLog(@" scrolly %d topleftY %d",scrollY,topLeftY);
    NSLog(@" marginXY %d,%d",marginX,marginY);
    
    int xoff = scrollX - topLeftX;
    int yoff = scrollY - topLeftY;
    NSLog(@" ....xyoff %d %d",xoff,yoff);

    int fudgeWid = imagewid + 2 * marginX;
    int fudgeHit = imagehit + 2 * marginY;
    
    double xPercent = (double)xoff / (double)fudgeWid;
    double yPercent = (double)yoff / (double)fudgeHit;

    //HFM! FLIPPED XY!!!
    int docWid =  od.height;
    int docHit =  od.width;
#ifdef NOTHFM
    int docWid =  od.width;
    int docHit =  od.height;
#endif
    NSLog(@" ...xyoff %d %d  xyPercent %f %f",xoff,yoff,xPercent,yPercent);
    NSLog(@"  maxWid? %d %d",fudgeWid,fudgeHit);
    NSLog(@"   doc WH %d %d",docWid,docHit);
    NSLog(@"  clugeXY %d %d",clugeX,clugeY);
    if (xoff > 0 && yoff > 0)
    {
        obx = (int)((double)docWid*xPercent);
        oby = (int)((double)docWid*xPercent);
        obx += clugeX;
        oby += clugeY;
        obw = bw;   //Overlay black box outline size??
        obh = bh;
        obRect = CGRectMake(obx, oby, obw, obh);
        NSLog(@" annnd docrect is %@",NSStringFromCGRect(obRect));
    }
    
} //end getOBRect

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
//asdf


//=============AnalyzeVC=====================================================
- (IBAction)loadSelect:(id)sender
{
    [self loadMenu];
}

//=============AnalyzeVC=====================================================
-(void) updateDatShit
{
    [self updateSelectBox];
    [self getOBRect];
    [self updateOCRText];
}

//=============AnalyzeVC=====================================================
- (IBAction)boxWMinusSelect:(id)sender {
    bw = MAX (40,bw-10);
    [self updateDatShit];
}

//=============AnalyzeVC=====================================================
- (IBAction)boxWPlusSelect:(id)sender {
    bw+=10;
    [self updateDatShit];
}

//=============AnalyzeVC=====================================================
- (IBAction)boxHMinusSelect:(id)sender {
    bh = MAX (40,bh-10);
    [self updateDatShit];
}

//=============AnalyzeVC=====================================================
- (IBAction)boxHPlusSelect:(id)sender {
    bh+=10;
    [self updateDatShit];
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
    for (int i=0;i<vv.vcount;i++)  //DHS 3/6
    {
        NSString *s = [vv getNameByIndex:i]; //DHS 3/6
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
    for (int i=0;i<vv.vcount;i++)  //DHS 3/6
    {
        NSString *s = [vv getNameByIndex:i]; //DHS 3/6
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
        //folderPath = [NSString stringWithFormat : @"/%@",bappDelegate.settings.batchFolder];
        folderPath = [bappDelegate getBatchFolderPath]; // 3/20
    }
    else{
        folderPath = [bappDelegate getOutputFolderPath]; // 3/20
    }
    [spv start : @"Get Folder List"];
    [dbt getBatchList : folderPath : vendorSelect];
    
} //end chooseVendor

//=============AnalyzeVC=====================================================
-(NSString *) getFilenameFromFullPath : (NSString*)fullpath
{
    NSArray  *fstrs = [fullpath componentsSeparatedByString:@"/"]; //Peel off last part of path -> filename
    NSString *fname = fstrs[fstrs.count-1];
    return fname;
}

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
        [alert addAction: [UIAlertAction actionWithTitle:[self getFilenameFromFullPath:s]
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
  //  NSLog(@" ocr rect %@",NSStringFromCGRect(obRect));
    NSMutableArray *a = [od findAllWordsInDocumentRect:obRect];
    NSString *daWoids = [od assembleWordFromArray : a : false : 10];
  //  NSLog(@"OCR: %d words",(int)a.count);
  //  NSLog(@"     %@",daWoids);
    _ocrText.text = daWoids;

}

//=============AnalyzeVC=====================================================
-(void) updateUI
{
    //asdf
    _titleLabel.text = [self getFilenameFromFullPath : fname];
    if (page == 0) _pageLabel.text  = @"...";
    else _pageLabel.text  = [NSString stringWithFormat:@"%d",page];
    _ocrText.text = ocrOutput;


} //end updateUI

//=============AnalyzeVC=====================================================
- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self updateMinZoomScaleForSize : zoomwid : zoomhit];
    NSLog(@" layout subviews...");
    [self initScrollForImage];
    [self placeBoxView];
}

//=============AnalyzeVC=====================================================
-(void) initScrollForImage
{
    imagewid = _pdfImage.image.size.width;
    imagehit = _pdfImage.image.size.height;
    izoom = 2;
    zoomwid  = imagewid*izoom;
    zoomhit  = imagehit*izoom;
    int xyd = 0;
    if (imagewid > imagehit)
        xyd = imagewid - imagehit;  //For landscape images, x bigger than y
    else
        xyd = imagehit - imagewid;  //For portrait images, y bigger than x
    int xoff = 0;
    int yoff = 0;
    
    UIView *v = _pdfImage;

    _scrollView.contentSize = CGSizeMake(4*izoom*xyd,4*izoom*xyd);
    [_scrollView setContentOffset:CGPointMake(xoff,yoff) animated:NO];
    //If I don't do this the scrollview can't scroll to the left edge! WHY?
    CGAffineTransform t = v.transform;
    t = CGAffineTransformMakeScale(izoom,izoom);
    v.transform = t;
    v.center = CGPointMake(izoom*imagewid/2, izoom*imagehit/2);
    //Fudge factors, WTF??? they match aspect ratio
    marginX = 27*izoom;
    marginY = 18*izoom;
}



//=============AnalyzeVC=====================================================
-(void) updateMinZoomScaleForSize : (int) xw : (int) yw
{
    UIImage *ii = _pdfImage.image;
    float xscale = (float)xw / (float)ii.size.width;
    float yscale = (float)yw / (float)ii.size.height;
    float minscale = MIN(xscale,yscale);
    _scrollView.minimumZoomScale = minscale;
    _scrollView.zoomScale = minscale;

    
}

//=============AnalyzeVC=====================================================
-(void) placeBoxView
{
    // Clear centered box with black border
    _boxView.backgroundColor = [UIColor clearColor];
    _boxView.layer.borderWidth = 2;
    _boxView.layer.borderColor = [UIColor blackColor].CGColor;
    //Now center it over scrollview
    bw = 200;
    bh = 60;
    [self updateSelectBox];
    //asdf
    
} //end placeBoxView

//=============AnalyzeVC=====================================================
// Box stays pinned TL, this is for size changes...
-(void) updateSelectBox
{
    CGRect rr      = _scrollView.frame;
    CGRect br      = _boxView.frame;
    br.origin.x    = rr.origin.x; // rr.origin.x + rr.size.width/2 - bw/2;
    br.origin.y    = rr.origin.y; // rr.origin.y + rr.size.height/2 - bw/2;
    br.size.width  = bw;
    br.size.height = bh;
    _boxView.frame = br;  // annd reset the box size

} //end updateSelectBox

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
- (void)errorPerformingOCRNotification:(NSNotification *)notification
{
    NSString *errmsg = (NSString*)notification.object;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self errorMessage:@"Error Performing OCR" : errmsg];
    });
}

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
