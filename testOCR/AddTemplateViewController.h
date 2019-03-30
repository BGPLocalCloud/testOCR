//
//      _       _     _ _____                    _       _     __     ______
//     / \   __| | __| |_   _|__ _ __ ___  _ __ | | __ _| |_ __\ \   / / ___|
//    / _ \ / _` |/ _` | | |/ _ \ '_ ` _ \| '_ \| |/ _` | __/ _ \ \ / / |
//   / ___ \ (_| | (_| | | |  __/ | | | | | |_) | | (_| | ||  __/\ V /| |___
//  /_/   \_\__,_|\__,_| |_|\___|_| |_| |_| .__/|_|\__,_|\__\___| \_/  \____|
//                                        |_|
//
//  AddTemplateViewController.h
//  testOCR
//
//  Created by Dave Scruton on 12/20/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#import "CheckTemplateVC.h"
#import "DropboxTools.h"
#import "ImageTools.h"
#import "OCRTemplate.h"
#import "PDFCache.h"
#import "spinnerView.h"
#import "Vendors.h"

NS_ASSUME_NONNULL_BEGIN

@interface AddTemplateViewController : UIViewController <UIImagePickerControllerDelegate,
                        UINavigationControllerDelegate,DropboxToolsDelegate,OCRTemplateDelegate>
{
    int viewWid,viewHit,viewW2,viewH2;
    int photoPixWid,photoPixHit;
    int photoScreenWid,photoScreenHit;
    float photoToUIX,photoToUIY;
    BOOL gotPhoto;
    double rotAngle;
    double rotAngleRadians;
    BOOL showRotatedImage;
    spinnerView *spv;
    imageTools *it;
    DropboxTools *dbt;
    OCRTemplate *ot;
    PDFCache *pc;
    NSMutableArray *fileEntries;
    
    NSString *templateFolder;
    
    NSString *customerSelect;
    
    CIImage *coreImage;
    float brightness;
    float contrast;
    float saturation;
    BOOL removeColor;
    BOOL enhancing;
    NSString* imagePath;
    Vendors *vv;
    NSString *vendorMode;
    
}
// UI stuff
@property (weak, nonatomic) IBOutlet UIImageView *gridOverlay;
@property (weak, nonatomic) IBOutlet UILabel *titeLabel;
@property (weak, nonatomic) IBOutlet UIButton *nextButton;
@property (weak, nonatomic) IBOutlet UIImageView *templateImage;
@property (weak, nonatomic) IBOutlet UIView *rotateView;
@property (weak, nonatomic) IBOutlet UILabel *skewLabel;
@property (weak, nonatomic) IBOutlet UIButton *removeColorButton;
@property (weak, nonatomic) IBOutlet UIButton *loadButton;
@property (weak, nonatomic) IBOutlet UIView *enhanceView;
@property (weak, nonatomic) IBOutlet UISlider *bSlider;
@property (weak, nonatomic) IBOutlet UISlider *cSlider;
@property (weak, nonatomic) IBOutlet UILabel *briLabel;
@property (weak, nonatomic) IBOutlet UILabel *conLabel;

// sharable properties...
@property (nonatomic , strong) UIImage *photo;
@property (nonatomic , assign) CGRect photoRect;
@property (nonatomic , strong) UIImage *rphoto;
@property (nonatomic , strong) UIImage *prphoto;
@property (nonatomic , assign) int step;
@property (nonatomic , assign) BOOL needPicker;
@property (nonatomic , strong) NSString *vendor;


- (IBAction)resetSelect:(id)sender;
- (IBAction)cancelSelect:(id)sender;
- (IBAction)loadSelect:(id)sender;
- (IBAction)deskewSelect:(id)sender;
- (IBAction)p90Select:(id)sender;
- (IBAction)p10Select:(id)sender;
- (IBAction)p1Select:(id)sender;
- (IBAction)m1Select:(id)sender;
- (IBAction)m10Select:(id)sender;
- (IBAction)m90Select:(id)sender;
- (IBAction)nextSelect:(id)sender;
- (IBAction)bSliderChanged:(id)sender;
- (IBAction)cSliderChanged:(id)sender;
- (IBAction)removeColorSelect:(id)sender;
- (IBAction)resetEnhanceSelect:(id)sender;


@end

NS_ASSUME_NONNULL_END
