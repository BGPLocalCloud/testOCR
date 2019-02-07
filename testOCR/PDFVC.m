//
//   ____  ____  _______     ______
//  |  _ \|  _ \|  ___\ \   / / ___|
//  | |_) | | | | |_   \ \ / / |
//  |  __/| |_| |  _|   \ V /| |___
//  |_|   |____/|_|      \_/  \____|
//
//  PDFVC.m
//  testOCR
//
//  Created by Dave Scruton on 2/6/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import "PDFVC.h"

@interface PDFVC ()

@end

@implementation PDFVC

//=============PDF VC=====================================================
-(id)initWithCoder:(NSCoder *)aDecoder {
    if ( !(self = [super initWithCoder:aDecoder]) ) return nil;
    photo = [ UIImage imageNamed:@"emptyDoc"];
    itools = [[imageTools alloc] init];

    pc    = [PDFCache sharedInstance];      //For looking at images of ivoices
    vv    = [Vendors sharedInstance];
    return self;
}

//=============PDF VC=====================================================
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _titleLabel.text = @"PDF Viewer";
    _pdfImage.image = photo;
    _scrollView.delegate=self;
    vindex = [vv getVendorIndex:_vendor];
    page = 1;
    pastEnd =  FALSE;
    [self loadPhoto];

}

//=============PDF VC=====================================================
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
    UIView *v = _pdfImage;
    int vw = v.bounds.size.width;
    int vh = v.bounds.size.height;
    int zoom = 4;
    CGAffineTransform t = v.transform;
    t = CGAffineTransformMakeScale(zoom,zoom);
    v.transform = t;
    v.center = CGPointMake(vw*zoom/2, vh*zoom/2);
    _scrollView.contentSize = CGSizeMake(vw*zoom, vh*zoom);
    [_scrollView setContentOffset:CGPointMake(0,0) animated:NO];
   
} //end loadView


//=============PDF VC=====================================================
-(void) dismiss
{
    //[_sfx makeTicSoundWithPitch : 8 : 52];
    [self dismissViewControllerAnimated : YES completion:nil];
    
}

//=============PDF VC=====================================================
- (IBAction)backSelect:(id)sender
{
    [self dismiss];
}

//=============PDF VC=====================================================
- (IBAction)nextPageSelect:(id)sender
{
    if (!pastEnd)
    {
        page++;
        [self loadPhoto];
    }
}

//=============PDF VC=====================================================
- (IBAction)prevPageSelect:(id)sender
{
    page--;
    if (page < 1) page = 1;
    [self loadPhoto];
}


//=============PDF VC=====================================================
//What about going past end page?
-(void) loadPhoto
{
    UIImage *testPhoto =  [pc getImageByID:_pdfFile : page];
    if (testPhoto == nil)
    {
        photo   = [ UIImage imageNamed:@"emptyDoc"];
        pastEnd = TRUE;
    }
    else{
        photo   = testPhoto;
        pastEnd = FALSE;
        NSString* vrstr = vv.vRotations[vindex];
        if ([vrstr isEqualToString:@"-90"])  //Rotate to make readable
            photo = [itools rotate90CCW:photo];
    }
    _pdfImage.image = photo;
    _titleLabel.text = [NSString stringWithFormat:@"Invoice%@ : Page %d",_invoiceNumber,page];
}
@end
