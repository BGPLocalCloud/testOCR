//
//    ____ _               _    _____                    _       _     __     ______
//   / ___| |__   ___  ___| | _|_   _|__ _ __ ___  _ __ | | __ _| |_ __\ \   / / ___|
//  | |   | '_ \ / _ \/ __| |/ / | |/ _ \ '_ ` _ \| '_ \| |/ _` | __/ _ \ \ / / |
//  | |___| | | |  __/ (__|   <  | |  __/ | | | | | |_) | | (_| | ||  __/\ V /| |___
//   \____|_| |_|\___|\___|_|\_\ |_|\___|_| |_| |_| .__/|_|\__,_|\__\___| \_/  \____|
//                                                |_|
//
//  CheckTemplateVC.m
//  testOCR
//
//  Created by Dave Scruton on 12/26/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
//  1/15 hook up filename property
//  1/18 change 2nd scroll area  to textfield, add segue to editVC
//  1/19 Added dropbox file save and PDF cache save
//  3/17 changed OCRTopObject delegate callbacks to notifications...
//
#import "CheckTemplateVC.h"

@interface CheckTemplateVC ()

@end

@implementation CheckTemplateVC

//=============CheckTemplate VC=====================================================
-(id)initWithCoder:(NSCoder *)aDecoder {
    if ( !(self = [super initWithCoder:aDecoder]) ) return nil;
    
    //   _versionNumber    = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
    oto = [OCRTopObject sharedInstance];
    oto.delegate = self;
    //Dropbox...
    dbt = [[DropboxTools alloc] init];
    dbt.delegate = self;
    [dbt setParent:self];

    //PDF Cache: for saving images
    pc = [PDFCache sharedInstance];

    return self;
}

//=============CheckTemplate VC=====================================================
- (void)viewDidLoad {
    [super viewDidLoad];
    // 1/19 Add spinner busy indicator...
    CGSize csz   = [UIScreen mainScreen].bounds.size;
    spv = [[spinnerView alloc] initWithFrame:CGRectMake(0, 0, csz.width, csz.height)];
    [self.view addSubview:spv];
    
    //3/17 notifications from OCRTopObject singleton...
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didPerformOCR:)
                                                 name:@"didPerformOCR" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(errorPerformingOCR:)
                                                 name:@"errorPerformingOCR" object:nil];

    
    
    // Do any additional setup after loading the view.
    _imageView.image = _photo;
    _scrollView.delegate=self;
    oto.imageFileName = _fileName; //1/15
    oto.ot = nil; //Hand template down to oto
    [spv start:@"Perform OCR..."];
    [oto performOCROnImage : oto.imageFileName : _photo ];
} //end viewDidLoad

//=============CheckTemplate VC=====================================================
-(void) loadView
{
    [super loadView];
    CGSize csz   = [UIScreen mainScreen].bounds.size;
    viewWid = (int)csz.width;
    viewHit = (int)csz.height;
    viewW2  = viewWid/2;
    viewH2  = viewHit/2;

    int xi,yi,xs,ys;
    xs = viewWid;
    ys = xs;
    xi = viewW2 - xs/2;
    yi = 70;
    _scrollView.frame = CGRectMake(xi, yi, xs, ys);
    //Zoom up by 8x
    UIView *v = _imageView;
    int vw = v.bounds.size.width;
    int vh = v.bounds.size.height;
    CGAffineTransform t = v.transform;
    t = CGAffineTransformMakeScale(8, 8);
    v.transform = t;
    v.center = CGPointMake(vw*4, vh*4);
    _scrollView.contentSize = CGSizeMake(vw*8, vh*8);
    [_scrollView setContentOffset:CGPointMake(0,0) animated:NO];
    
    //Move down: text view contains OCR'ed text
    yi += ys;
    ys = viewHit - yi - 80;
    _outputTextView.frame = CGRectMake(xi, yi, xs, ys);

} //end loadView


//=============CheckTemplate VC=====================================================
-(void) dismiss
{
    //[_sfx makeTicSoundWithPitch : 8 : 52];
    [self dismissViewControllerAnimated : YES completion:nil];
    
}


//=============CheckTemplate VC=====================================================
- (IBAction)backSelect:(id)sender
{
    [self dismiss];
}

//=============CheckTemplate VC=====================================================
- (IBAction)nextSelect:(id)sender
{
    AppDelegate *tappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSString *templateFolder  = tappDelegate.settings.templateFolder;
    NSString *outputPath      = [NSString stringWithFormat:@"/%@/template_%@.png",templateFolder,_vendor];
    [spv start : @"Save Image..."];
    //Add image to PDF cache...
    [pc addPDFImage : _photo : outputPath : 1];
    //OK save our template image...
    [dbt uploadPNGImage:outputPath : _photo];

}

//=============CheckTemplate VC=====================================================
// Handles last minute VC property setups prior to segues
-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    //NSLog(@" prepareForSegue: %@ sender %@",[segue identifier], sender);
    if([[segue identifier] isEqualToString:@"editTemplateSegue"])
    {
        EditTemplateVC *vc = (EditTemplateVC*)[segue destinationViewController];
        vc.incomingOCRText = ocredText;
        vc.incomingImage   = _photo;
        vc.incomingVendor  = _vendor;
    }
} //end prepareForSegue


//=============CheckTemplate VC=====================================================
-(UIView *) viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return self.imageView;
}

//=============CheckTemplate VC=====================================================
-(void) errMsg : (NSString *)title : (NSString*)message
{
    UIAlertController *alertController =
    [UIAlertController alertControllerWithTitle:title
                                        message:message
                                 preferredStyle:(UIAlertControllerStyle)UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"OK"
                                                        style:(UIAlertActionStyle)UIAlertActionStyleCancel
                                                      handler:nil]];
    [self presentViewController:alertController animated:YES completion:nil];
    
} //end errMsg





#pragma mark - OCRTopObjectDelegate

//=============<OCRTopObjectDelegate>=====================================================
// 3/17 OBSOLETE
//- (void)didPerformOCR : (NSString *) result
//{
//    NSLog(@" OCR OK");
//    dispatch_async(dispatch_get_main_queue(), ^{
//        self->ocredText = [self->oto getRawResult];
//        self->_outputTextView.text = self->ocredText;
//    });
//
//}

//=============<OCRTopObject notification>=====================================================
// 3/17
- (void)errorPerformingOCR:(NSNotification *)notification
{
    NSString *errmsg = (NSString*)notification.object;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@" error on OCR... %@",errmsg);
        //        [self errorMessage:@"Error Performing OCR" : errmsg];
    });
}

//=============<OCRTopObject notification>=====================================================
// 3/17
- (void)didPerformOCR:(NSNotification *)notification
{
    NSLog(@" didPerformOCR");
//    od = (OCRDocument*)notification.object; //Note this ISN'T a copy! don't modify it!
//    [od setupPage:page-1]; //NOTE must change on page +/-!!
//    NSLog(@" annnd doc is %@",od);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->spv stop];
        self->ocredText = [self->oto getRawResult];
        self->_outputTextView.text = self->ocredText;
    });
} //end didReadBatchByIDs


//=============<OCRTopObjectDelegate>=====================================================
- (void)batchUpdate : (NSString *) s
{
    NSLog(@" ...stubbed batchUpdate %@",s);
}


#pragma mark - DropboxToolsDelegate

//===========<DropboxToolDelegate>================================================
- (void)didUploadImageFile : (NSString *)fname
{
    NSLog(@" didUploadImageFile[%@]",fname);
    // OK came back from dropbox image save, now segue to image editor...
    [spv stop];
    [self performSegueWithIdentifier:@"editTemplateSegue" sender:@"addTemplateVC"];

}

//===========<DropboxToolDelegate>================================================
- (void)errorUploadingImage : (NSString *)s
{
    NSLog(@" errorUploadingImage[%@] ",s);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->spv stop];
        [self errMsg:@"Error saving Template Image" :s];
    });
}



@end
