//
//   _____                   __     ______
//  | ____|_ __ _ __ ___  _ _\ \   / / ___|
//  |  _| | '__| '__/ _ \| '__\ \ / / |
//  | |___| |  | | | (_) | |   \ V /| |___
//  |_____|_|  |_|  \___/|_|    \_/  \____|
//
//  ErrorViewController.h
//  testOCR
//
//  Created by Dave Scruton on 1/4/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BatchObject.h"
#import "DropboxTools.h"
#import "errorCell.h"
#import "EXPTable.h"
#import "imageTools.h"
#import "PDFCache.h"
#import "Vendors.h"
#import "smartProducts.h"
#import "spinnerView.h"
#import "soundFX.h"

@interface ErrorViewController : UIViewController <batchObjectDelegate,
                                UITableViewDelegate,UITableViewDataSource,EXPTableDelegate,
                                UITextFieldDelegate, DropboxToolsDelegate>
{
    BatchObject *bbb;
    DropboxTools *dbt;
    smartProducts *sp;
    NSString *berrs;
    NSMutableArray *errorList;
    NSMutableArray *fixedList;
    NSMutableArray *expList;
    NSMutableArray *objectIDs;
    NSMutableDictionary *expRecordsByID;
    int selectedRow;
    EXPTable *et;
    NSMutableArray *allErrorsInEXPRecord;
    PDFCache *pc;
    Vendors *vv;
    imageTools *it;
    spinnerView *spv;
    
    int errorPage;
    NSString *vendorName;
    
    UIImage *xIcon;
    UIImage *wIcon;
    UIImage *okIcon;

    int viewWid,viewHit,viewW2,viewH2;

    //Keys used to look thru pf object and find errors,
    //  and types of error correction each field will need
    NSArray *errKeysToCheck;
    NSArray *errKeysNumeric;
    NSArray *errKeysBinary;
    NSString *iText;  
    NSString *qText;
    NSString *pText;
    NSString *tText;
    BOOL kbUp;
    NSString *fixingObjectKey;
    NSString *fixingObjectField;
    NSString *fixingObjectID;
    NSString *batchID;
    PFObject *pfoWork;
    BOOL isNumeric;
    int rotatedCount;
}

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UIImageView *pdfView;
@property (weak, nonatomic) IBOutlet UITableView *table;
@property (weak, nonatomic) IBOutlet UIView *fixNumberView;
@property (weak, nonatomic) IBOutlet UILabel *fieldName;
@property (weak, nonatomic) IBOutlet UIView *numericPanelView;
@property (weak, nonatomic) IBOutlet UITextField *field0Value;
@property (weak, nonatomic) IBOutlet UITextField *field1Value;
@property (weak, nonatomic) IBOutlet UITextField *field2Value;
@property (weak, nonatomic) IBOutlet UITextField *field3Value;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UIButton *backButton;
@property (weak, nonatomic) IBOutlet UIButton *rotButton;
@property (nonatomic, strong) soundFX *sfx;

@property (nonatomic , assign) BOOL fixingErrors;
@property (nonatomic , strong) NSString* customer; //4/3/20

- (IBAction)fieldCancelSelect:(id)sender;
- (IBAction)fieldFixSelect:(id)sender;
- (IBAction)rotSelect:(id)sender;

- (IBAction)textChanged:(id)sender;





@property (nonatomic , strong) NSString* batchData;

- (IBAction)backSelect:(id)sender;

@end

 
