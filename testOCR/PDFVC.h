//
//   ____  ____  _______     ______
//  |  _ \|  _ \|  ___\ \   / / ___|
//  | |_) | | | | |_   \ \ / / |
//  |  __/| |_| |  _|   \ V /| |___
//  |_|   |____/|_|      \_/  \____|
//
//  PDFVC.h
//  testOCR
//
//  Created by Dave Scruton on 2/6/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#import "DropboxTools.h"
#import "imageTools.h"
#import "invoiceObject.h"
#import "PDFCache.h"
#import "spinnerView.h"
#import "Vendors.h"
#import "soundFX.h"

@interface PDFVC : UIViewController <UIScrollViewDelegate,DropboxToolsDelegate>
{
    UIImage *photo;
    PDFCache *pc;
    Vendors *vv;
    imageTools *itools;
    DropboxTools *dbt;
    spinnerView *spv;

    int viewWid,viewHit,viewW2,viewH2;
    int pageInt;
    int vindex;
    BOOL pastEnd;
    BOOL triedOutputFolder;
    int rotatedCount;

}
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;

@property (strong, nonatomic) IBOutlet NSString *pdfFile;
@property (strong, nonatomic) IBOutlet NSString *vendor;
@property (strong, nonatomic) IBOutlet NSString *invoiceNumber;
@property (weak, nonatomic) IBOutlet UIImageView *pdfImage;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (strong, nonatomic) IBOutlet NSString *page;
@property (nonatomic, strong) soundFX *sfx;


- (IBAction)backSelect:(id)sender;
- (IBAction)nextPageSelect:(id)sender;
- (IBAction)prevPageSelect:(id)sender;
- (IBAction)rotSelect:(id)sender;


@end


