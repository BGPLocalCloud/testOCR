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
#import "activityCell.h"
#import "DropboxTools.h"
#import "BatchObject.h"
#import "AppDelegate.h"
#import "AddTemplateViewController.h"
#import "BatchReportController.h"
#import "ErrorViewController.h"
#import "EXPViewController.h"
#import "NavButtons.h"
#import "SessionManager.h"
#import "OCRCache.h"
#import "OCRDocument.h"
#import "PDFCache.h"
#import "spinnerView.h"
#import "smartProducts.h"
#import "Vendors.h"
NS_ASSUME_NONNULL_BEGIN

@interface MainVC : UIViewController <NavButtonsDelegate,ActivityTableDelegate,
                    UITableViewDelegate,UITableViewDataSource, batchObjectDelegate,DropboxToolsDelegate>
{
    NavButtons *nav;
    int viewWid,viewHit,viewW2,viewH2;
    ActivityTable *act;
    NSString *versionNumber;
    UIImage *emptyIcon;
    UIImage *dbIcon;
    UIImage *batchIcon;
    int selectedRow;
    NSString* stype;
    NSString* sdata;
    UIRefreshControl *refreshControl;
    OCRCache *oc;
    PDFCache *pc;
    BatchObject *bbb;
    NSMutableArray *batchPFObjects;
    BOOL fixingErrors;
    spinnerView *spv;
    DropboxTools *dbt;


}
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *logoLabel;

@property (weak, nonatomic) IBOutlet UITableView *table;

@property (weak, nonatomic) IBOutlet UILabel *versionLabel;
@property (weak, nonatomic) IBOutlet UIImageView *logoView;

@end

NS_ASSUME_NONNULL_END
