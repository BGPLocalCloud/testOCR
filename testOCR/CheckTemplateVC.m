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

    return self;
}

//=============CheckTemplate VC=====================================================
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _imageView.image = _photo;
    _scrollView.delegate=self;
    oto.imageFileName = _fileName; //1/15
    [oto performOCROnImage : oto.imageFileName : _photo : nil];
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
    [self performSegueWithIdentifier:@"editTemplateSegue" sender:@"addTemplateVC"];

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



//=============CheckTemplate VC=====================================================


#pragma mark - OCRTopObjectDelegate

//=============(BatchObject)=====================================================
- (void)didPerformOCR : (NSString *) result
{
    NSLog(@" OCR OK");
    dispatch_async(dispatch_get_main_queue(), ^{
        self->ocredText = [self->oto getRawResult];
        self->_outputTextView.text = self->ocredText;
    });

}


//=============(BatchObject)=====================================================
- (void)errorPerformingOCR : (NSString *) errMsg
{
    [self errMsg:@"Error Performing OCR" :errMsg];
}

@end
