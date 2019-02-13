//
//  ErrorHelperVC.h
//  testOCR
//
//  Created by Dave Scruton on 2/12/19.
//  Copyright © 2019 huedoku. All rights reserved.
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

}

@property (weak, nonatomic) IBOutlet UIImageView *pdfImage;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (nonatomic , strong) NSString* batchData;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UILabel *errorLabel;



- (IBAction)leftArrowSelect:(id)sender;
- (IBAction)rightArrowSelect:(id)sender;
- (IBAction)backSelect:(id)sender;

@end

 
