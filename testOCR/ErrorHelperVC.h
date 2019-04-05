//
//   _____                     _   _      _               __     ______
//  | ____|_ __ _ __ ___  _ __| | | | ___| |_ __   ___ _ _\ \   / / ___|
//  |  _| | '__| '__/ _ \| '__| |_| |/ _ \ | '_ \ / _ \ '__\ \ / / |
//  | |___| |  | | | (_) | |  |  _  |  __/ | |_) |  __/ |   \ V /| |___
//  |_____|_|  |_|  \___/|_|  |_| |_|\___|_| .__/ \___|_|    \_/  \____|
//                                         |_|
//
//  ErrorHelperVC.h
//  testOCR
//
//  Created by Dave Scruton on 2/12/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BatchObject.h"
#import "DropboxTools.h"
#import "EXPObject.h"
#import "EXPTable.h"
#import "imageTools.h"
#import "PDFCache.h"
#import "spinnerView.h"
#import "Vendors.h"


@interface ErrorHelperVC : UIViewController <batchObjectDelegate,
                EXPTableDelegate, DropboxToolsDelegate,UIScrollViewDelegate>
{
    BatchObject *bbb;
    DropboxTools *dbt;
    spinnerView *spv;
    EXPTable *et;
    PFObject *pfoWork;
    PDFCache *pc;
    Vendors *vv;
    imageTools *it;


    NSMutableArray *errorList;
    NSMutableArray *expList;
    NSMutableArray *objectIDs;
    NSString *batchID;
    NSString *pdfName;
    NSString *oldName;

    NSMutableDictionary *expRecordsByID;

    
    int selectedError;
    int errorPage;
    int oldPage;
    NSString *vendorName;
    NSString *productName;
    NSString *errorStatus;
    
    int iwid,ihit;
    int rotatedCount;

}

@property (weak, nonatomic) IBOutlet UIImageView *pdfImage;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (nonatomic , strong) NSString* batchData;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UILabel *errorLabel;

- (IBAction)rotSelect:(id)sender;


- (IBAction)leftArrowSelect:(id)sender;
- (IBAction)rightArrowSelect:(id)sender;
- (IBAction)backSelect:(id)sender;

@end

 
