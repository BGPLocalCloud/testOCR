//
//   __  __       _    __     ______
//  |  \/  | __ _(_)_ _\ \   / / ___|
//  | |\/| |/ _` | | '_ \ \ / / |
//  | |  | | (_| | | | | \ V /| |___
//  |_|  |_|\__,_|_|_| |_|\_/  \____|
//
//  MainVC.h
//  testOCR
//
//  Created by Dave Scruton on 12/5/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Crashlytics/Crashlytics.h>
#import "ActivityTable.h"
#import "GenParse.h"
#import "activityCell.h"
#import "DropboxTools.h"
#import "BatchObject.h"
#import "AppDelegate.h"
#import "AnalyzeVC.h"
#import "AddTemplateViewController.h"
#import "BatchReportController.h"
#import "ErrorViewController.h"
#import "ErrorHelperVC.h"
#import "EXPViewController.h"
#import "InvoiceViewController.h"
#import "EXPTable.h"
#import "GenParse.h"
#import "LoginVC.h"
#import "NavButtons.h"
#import "SessionManager.h"
#import "OCRCache.h"
#import "OCRDocument.h"
#import "PDFCache.h"
#import "spinnerView.h"
#import "smartProducts.h"
#import "Vendors.h"
#import "soundFX.h"
NS_ASSUME_NONNULL_BEGIN

@interface MainVC : UIViewController <NavButtonsDelegate,ActivityTableDelegate,
                    UITableViewDelegate,UITableViewDataSource, batchObjectDelegate,DropboxToolsDelegate,
                    GenParseDelegate,EXPTableDelegate, MFMailComposeViewControllerDelegate>
{
    NavButtons *nav;
    int viewWid,viewHit,viewW2,viewH2;
    ActivityTable *act;
    AppDelegate *mappDelegate; //4/5 used often enough...
    NSString *versionNumber;
    UIImage *emptyIcon;
    UIImage *dbIcon;
    UIImage *batchIcon;
    UIImage *errIcon;
    int selectedRow;
    NSString* stype;
    NSString* sInvoiceNumber;
    NSString* sdata;
    NSString* scustomer;
    UIRefreshControl *refreshControl;
    OCRCache *oc;
    PDFCache *pc;
    BatchObject *bbb;
    NSMutableArray *batchPFObjects;
    BOOL fixingErrors;
    spinnerView *spv;
    DropboxTools *dbt;
    GenParse *gp;
    EXPTable *et;
    NSString *selVendor;
    BOOL fatalErrorSelect; //2/11 Better way to do this? Maybe type select?
    int ecount;
    NSString *loginMode;
    
}
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *logoLabel;
@property (weak, nonatomic) IBOutlet UILabel *customerLabel;

@property (weak, nonatomic) IBOutlet UITableView *table;

@property (weak, nonatomic) IBOutlet UILabel *versionLabel;
@property (weak, nonatomic) IBOutlet UIImageView *logoView;
@property (nonatomic, strong) soundFX *sfx;


- (IBAction)eSelect:(id)sender;
- (IBAction)customerSelect:(id)sender;


@end

NS_ASSUME_NONNULL_END
