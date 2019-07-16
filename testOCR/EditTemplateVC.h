//
//   _____    _ _ _  _____                    _       _     __     ______
//  | ____|__| (_) ||_   _|__ _ __ ___  _ __ | | __ _| |_ __\ \   / / ___|
//  |  _| / _` | | __|| |/ _ \ '_ ` _ \| '_ \| |/ _` | __/ _ \ \ / / |
//  | |__| (_| | | |_ | |  __/ | | | | | |_) | | (_| | ||  __/\ V /| |___
//  |_____\__,_|_|\__||_|\___|_| |_| |_| .__/|_|\__,_|\__\___| \_/  \____|
//                                     |_|
//
//  EditTemplateVC.h
//  testOCR
//
//  Created by Dave Scruton on 12/3/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//  March/April: Redo to link in w/ addTemplate/CheckTemplateVC

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <MessageUI/MessageUI.h>
#import "AppDelegate.h"
#import "ActivityTable.h"
#import "DBKeys.h"
#import "DropboxTools.h"
#import "OCRWord.h"
#import "OCRDocument.h"
#import "OCRTemplate.h"
#import "OCRTopObject.h"
#import "PDFCache.h"
#import "imageTools.h"
#import "MagnifierView.h"
#import "smartProducts.h"
#import "spinnerView.h"
#import "invoiceTable.h"
#import "EXPTable.h"

#define DEFAULT_FIELD_FORMAT @"DEFAULT"
#define VALUE_BELOW_TITLE_FIELD_FORMAT @"VALUE_BELOW_TITLE"
#define DATE_MMDDYYYY_FIELD_FORMAT @"DATE_MMDDYYYY"
#define DATE_DDMMYYYY_FIELD_FORMAT @"DATE_DDMMYYYY"


//Tags: used to get hints about field placement
#define TOP_TAG_TYPE        @"TOP_TAG"
#define BOTTOM_TAG_TYPE     @"BOTTOM_TAG"
#define LEFT_TAG_TYPE       @"LEFT_TAG"
#define RIGHT_TAG_TYPE      @"RIGHT_TAG"
#define TOPMOST_TAG_TYPE    @"TOPMOST_TAG"
#define BOTTOMMOST_TAG_TYPE @"BOTTOMMOST_TAG"
#define LEFTMOST_TAG_TYPE   @"LEFTMOST_TAG"
#define RIGHTMOST_TAG_TYPE  @"RIGHTMOST_TAG"
#define ABOVE_TAG_TYPE      @"ABOVE_TAG"
#define BELOW_TAG_TYPE      @"BELOW_TAG"
#define LEFTOF_TAG_TYPE     @"LEFTOF_TAG"
#define RIGHTOF_TAG_TYPE    @"RIGHTOF_TAG"
#define HCENTER_TAG_TYPE    @"HCENTER_TAG"
#define HALIGN_TAG_TYPE     @"HALIGN_TAG"
#define VCENTER_TAG_TYPE    @"VCENTER_TAG"
#define VALIGN_TAG_TYPE     @"VALIGN_TAG"


#define TOP_TAG_TYPE @"TOP_TAG"
#define TOP_TAG_TYPE @"TOP_TAG"



@interface EditTemplateVC : UIViewController <OCRTemplateDelegate,
                                            invoiceTableDelegate,EXPTableDelegate,OCRTopObjectDelegate,
                                            ActivityTableDelegate, DropboxToolsDelegate>
{
    
    UIActivityIndicatorView *spinner;

    NSString *selectFnameForTemplate;
    NSString *selectFname;
    CFDataRef pixelData;
    OCRDocument *od;
    OCRTemplate *ot;
    OCRTopObject *oto; //Performs OCR using template and document...
    PDFCache *pc;

    ActivityTable *act;
    DropboxTools *dbt;
    spinnerView *spv;

    UIView *selectBox;
    CGRect selectDocRect;
    CGRect pageRect;
    CGRect docRect;
    int arrowLHStepSize;
    int arrowRHStepSize;
    int viewWid,viewHit,viewW2,viewH2;
    BOOL editing;
    BOOL adjusting;
    BOOL lhArrowsFast;
    BOOL rhArrowsFast;
    double docXConv,docYConv;
    BOOL docFlipped90;
    NSString *rawOCRResult;

    //OCR'ed results...
    NSString *supplierName;
    NSString *vendor;
    NSString *fieldName;
    NSString *fieldNameShort;
    NSString *fieldFormat;
    NSString *stubbedDocName;

    UIImage *fastIcon;
    UIImage *slowIcon;
    
    NSArray *columnHeaders;
    
    //INvoice-specific fields (MOVE TO SEPARATE OBJECT)
    long invoiceNumber;
    NSString *invoiceNumberString;

    NSDate *invoiceDate;
    NSString *invoiceCustomer;
    NSString *invoiceSupplier;
    float invoiceTotal;
    NSMutableArray *rowItems;
    
    CGPoint touchLocation;
    int touchX,touchY;
    int touchDocX,touchDocY;
    BOOL dragging;
    int adjustSelect;
    
    CGRect tlRect,trRect;  //Absolute document boundary rects for text

    //Move to a processor object?
    smartProducts *smartp;
    int smartCount;
    NSMutableArray *EXPDump;
    NSString *EXPDumpCSVList;
    
    MagnifierView *magView;
    
    int clugex,clugey;

    int docnum;
    invoiceTable *it;
    EXPTable *et;
    
}

@property (weak, nonatomic) IBOutlet UIButton *arrowRightSelect;
@property (weak, nonatomic) IBOutlet UIImageView *inputImage;
@property (weak, nonatomic) IBOutlet UIView *LHArrowView;
@property (weak, nonatomic) IBOutlet UIView *RHArrowView;
@property (weak, nonatomic) IBOutlet UIView *selectOverlayView;
@property (weak, nonatomic) IBOutlet UIButton *addFieldButton;
@property (weak, nonatomic) IBOutlet UIButton *lhCenterButton;
@property (weak, nonatomic) IBOutlet UIButton *rhCenterButton;
@property (weak, nonatomic) IBOutlet UILabel *wordsLabel;

@property (nonatomic , strong) NSString* versionNumber;

@property (weak, nonatomic) IBOutlet UILabel *instructionsLabel;
@property (weak, nonatomic) IBOutlet UIView *overlayView;


@property (nonatomic , strong) NSString* incomingOCRText;
@property (nonatomic , strong) UIImage* incomingImage;
@property (nonatomic , strong) NSString* incomingVendor;
@property (nonatomic , strong) NSString* incomingImageFilename;


- (IBAction)arrowDownSelect:(id)sender;
- (IBAction)arrowUpSelect:(id)sender;
- (IBAction)arrowLeftSelect:(id)sender;
- (IBAction)testSelect:(id)sender;
- (IBAction)clearSelect:(id)sender;
- (IBAction)addFieldSelect:(id)sender;
- (IBAction)doneSelect:(id)sender;
- (IBAction)arrowRightSelect:(id)sender;
- (IBAction)arrowCenterSelect:(id)sender;

@end

