//
//   _____                     _   _      _               __     ______
//  | ____|_ __ _ __ ___  _ __| | | | ___| |_ __   ___ _ _\ \   / / ___|
//  |  _| | '__| '__/ _ \| '__| |_| |/ _ \ | '_ \ / _ \ '__\ \ / / |
//  | |___| |  | | | (_) | |  |  _  |  __/ | |_) |  __/ |   \ V /| |___
//  |_____|_|  |_|  \___/|_|  |_| |_|\___|_| .__/ \___|_|    \_/  \____|
//                                         |_|
//  ErrorHelperVC.m
//  testOCR
//
//  Created by Dave Scruton on 2/12/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
//  This looks up errors and displays them as text on top of a
//   fullscreen-scrollable view of the matching invoice.
//  Designed for use when correcting EXP data on another platform
//  gets batch ID, looks up batch, then has to go get EXP records
//   once that is done, has to fetch PDF ! may miss cache!

//  4/5 add rotatedcount to keep track of rotations across invoice pages
//      exp multi-customer support

#import "ErrorHelperVC.h"


@implementation ErrorHelperVC

//=============ErrorHelperVC=====================================================
-(id)initWithCoder:(NSCoder *)aDecoder {
    if ( !(self = [super initWithCoder:aDecoder]) ) return nil;
    
    bbb = [BatchObject sharedInstance];
    bbb.delegate = self;
    [bbb setParent:self];
    dbt = [[DropboxTools alloc] init];
    dbt.delegate = self;
    [dbt setParent:self];
    //For loading PDF images...
    pc = [PDFCache sharedInstance];
    //For getting document rotation...
    vv = [Vendors sharedInstance];
    
    et = [[EXPTable alloc] init];
    et.delegate = self;
    
    it = [[imageTools alloc] init];

    expRecordsByID = [[NSMutableDictionary alloc] init];

    
    errorList = [[NSMutableArray alloc] init];
    expList   = [[NSMutableArray alloc] init];
    objectIDs = [[NSMutableArray alloc] init];

    oldName = @"";
    oldPage = 0;
    iwid = ihit = 128;
    
    rotatedCount = 0;
    return self;
} //end initWithCoder

//=============Error VC=====================================================
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    NSLog(@"ErrorHelperVC: adata %@",_batchData);
    NSArray* bItems    = [_batchData componentsSeparatedByString:@":"];
    if (bItems.count > 0)
    {
        [spv start : @"Get Batch Errors"];
        batchID = bItems[0];
        //DHS 4/5 need to setup customer too!
        if (bItems.count > 2) [et setTableName:[NSString stringWithFormat:@"EXP_%@",bItems[2]]]; //Customer name: 3rd item
        [bbb readFromParseByID : batchID];
    }
    [expList removeAllObjects];
    [self zoomPDFView : 1.0];
    productName = @"...";
    errorStatus = @"...";
    [self setLabels];
} //end viewWillAppear


//=============ErrorHelperVC=====================================================
- (void)viewDidLoad {
    [super viewDidLoad];
    
   //NOT NEEDED? _scrollView.delegate=self;


    //Busy indicator
    CGSize csz   = [UIScreen mainScreen].bounds.size;
    spv = [[spinnerView alloc] initWithFrame:CGRectMake(0, 0, csz.width, csz.height)];
    [self.view addSubview:spv];
}


//==========FeedVC=========================================================================
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 90000
- (NSUInteger)supportedInterfaceOrientations
#else
- (UIInterfaceOrientationMask)supportedInterfaceOrientations
#endif
{
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown
     | UIInterfaceOrientationMaskLandscapeLeft| UIInterfaceOrientationMaskLandscapeRight;
}



//=============ErrorHelperVC=====================================================
-(void) dismiss
{
//    et.parentUp = FALSE; // 2/9 Tell expTable we are outta here
    [self dismissViewControllerAnimated : YES completion:nil];
}



//=============ErrorHelperVC=====================================================
// Does a 90 degree CCW rotation on exiting image
- (IBAction)rotSelect:(id)sender
{
    UIImage *ii = _pdfImage.image;
    ii = [it rotate90CCW : ii];
    _pdfImage.image = ii;
    rotatedCount++;

}

//=============ErrorHelperVC=====================================================
- (IBAction)leftArrowSelect:(id)sender {
    selectedError--;
    int ect = (int)objectIDs.count;
    if (selectedError<0) selectedError = ect-1; //Wraparound
    [self loadPDF];
}

//=============ErrorHelperVC=====================================================
- (IBAction)rightArrowSelect:(id)sender {
    selectedError++;
    int ect = (int)objectIDs.count;
    if (selectedError>=ect) selectedError = 0; //Wraparound
    [self loadPDF];
}

//=============ErrorHelperVC=====================================================
- (IBAction)backSelect:(id)sender {
    [self dismiss];
}


//=============ErrorHelperVC=====================================================
-(void) errorMessage : (NSString *) title :(NSString *) msg
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
                                NSLocalizedString(title,nil)  message:msg
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                              }]];
    [self presentViewController:alert animated:YES completion:nil];
    
} //end errorMessage


//=============Error VC=====================================================
-(void) finishSettingPDFImage : (UIImage *)ii
{
    //Does this vendor usually have XY flipped scans?
    NSString *rot = [vv getRotationByVendorName:vendorName]; //asdf
    if ([rot isEqualToString:@"-90"]) ii = [it rotate90CCW : ii];
    for (int i=0;i<rotatedCount;i++)  ii = [it rotate90CCW : ii]; //handle xtra rotations
    _pdfImage.image = ii;
    iwid = ii.size.width;
    ihit = ii.size.height;
    [spv stop]; //DHS 4/5 just in case...
    [self zoomPDFView : 1.8];
    [self setLabels];
} //end finishSettingPDFImage

//=============ErrorHelperVC=====================================================
-(void) setLabels
{
    _titleLabel.text = productName; //Set our product name for reference
    _errorLabel.text = errorStatus;
}

//=============ErrorHelperVC=====================================================
-(void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
}

//=============ErrorHelperVC=====================================================
-(void) zoomPDFView : (float) zoomBy
{
    //Zoom up...
    dispatch_async(dispatch_get_main_queue(), ^ {
        UIView *v = self->_pdfImage;
        CGAffineTransform t = v.transform;
        t = CGAffineTransformMakeScale(zoomBy, zoomBy);
        v.transform = t;
        float fwid = (float)self->iwid * zoomBy;
        float fhit = (float)self->ihit * zoomBy;
        v.center = CGPointMake(fwid/2,fhit/2);
        self->_pdfImage.frame = CGRectMake(-200,-200,fwid,fhit);
        NSLog(@" scrollview frame = %@",NSStringFromCGRect(self->_scrollView.frame));
        self->_scrollView.contentSize = CGSizeMake(fwid,fhit);
        //CGSizeMake(fwid,fhit);
       // _scrollView.zoomScale = 4.0;
        //[_scrollView setContentOffset:CGPointMake(200,200)];
    });

} //end zoomPDFView

//=============ErrorHelperVC=====================================================
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return _pdfImage;
}

//=============ErrorHelperVC=====================================================
// Errors are now E:ErrDesc:ObjID, so there are 3 sub-items! (were 2 before)
-(NSString *) getIDFromErrorString : (NSString *)errString
{
    NSArray *sItems = [errString componentsSeparatedByString:@":"];
    if (sItems.count > 2) //DHS 1/27 format is E : ErrMsg : objectID
    {
        NSString *s = sItems[2]; //If not n/a it is an objectID
        if (![s containsString:@"/"] ) return s;
    }
    return @"";
}

//=============Error VC=====================================================
-(void) loadAllExpObjects
{
    [spv start : @"Load EXP objects"];
    [objectIDs removeAllObjects];
    [expRecordsByID removeAllObjects];
    for (NSString *e in errorList)
    {
        NSLog(@" err %@",e);
        NSString *s = [self getIDFromErrorString : e];
        NSLog(@" .....s %@",s);
        if (s.length > 0) [objectIDs addObject: s];
    }
    [et getObjectsByIDs : objectIDs];
} //end loadAllExpObjects


//=============ErrorHelperVC=====================================================
// Gets matching PDF for error
-(void) loadPDF
{
    //Find proper exp object...
    EXPObject *foundEXP = nil;
    NSString *oid = objectIDs[selectedError];
    BOOL found = FALSE;
    int index = 0;
    for (EXPObject *exp in et.expos) //Look thru object IDS, find matching EXP Object
    {
        if ([exp.objectId isEqualToString:oid] )
        {
            foundEXP = exp;
            found    = TRUE;
            break;
        }
        index++;
    }
    if (found)
    {
        pdfName      = foundEXP.PDFFile;  //Get EXP object fields we need
        NSNumber *nn = foundEXP.page;
        errorPage    = nn.intValue;
        vendorName   = foundEXP.vendor;
        productName  = foundEXP.productName;
        errorStatus  = foundEXP.errStatus;
        NSLog(@" annnd pdf is %@, page %d",pdfName,errorPage);
        if (![pdfName isEqualToString:oldName] || (errorPage != oldPage)) //New Name? Get file!
        {
            if ([pc imageExistsByID : pdfName : errorPage+1])
            {
                NSLog(@" ...cache HIT %@",pdfName);
                [self finishSettingPDFImage:[pc getImageByID : pdfName : errorPage+1]];
            }
            else //Cache miss? get PDF directly from dropbox...
            {
                [spv start: @"Download PDF..."];
                NSLog(@" ...cache MISS: downloading %@",pdfName);
                rotatedCount = 0;
                [dbt downloadImages:pdfName];
            }
        }
        else
        {
            [self setLabels]; //Keep PDF image but update labels
        }
        oldName = pdfName; //Remember for next time
        oldPage = errorPage;
    }
    else{
        NSLog(@" no PDF available...");
    }
    
    
}


#pragma mark - batchObjectDelegate

//=============<batchObjectDelegate>=====================================================
- (void)didReadBatchByID : (NSString *)oid
{
    errorList = [NSMutableArray arrayWithArray:[bbb getErrors]];
    selectedError = 0;
    //NSLog(@" ok batch read %@:%@",oid,errorList);
    [spv stop];
    [self loadAllExpObjects];
}

//=============<batchObjectDelegate>=====================================================
- (void)errorReadingBatchByID : (NSString *)err
{
    NSLog(@" errorReadingBatchByID:%@",err);
    
}


#pragma mark - EXPTableDelegate

//=============<EXPTableDelegate>=====================================================
//Returning dictionary of EXP objects keyed by id's
- (void)didGetObjectsByIds : (NSMutableDictionary *)d
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@" getEXPObjects...[%d recs found]",(int)d.count);
       //DHS 4/5 comes in late! [self->spv stop];
    });
    
    NSLog(@" OK exp objectsBYid %@",d);
    expRecordsByID = d;
    [self loadPDF];

}

#pragma mark - DropboxToolsDelegate
//=============<DropboxToolsDelegate>=====================================================
// returning from a PDF fetch...
- (void)didDownloadImages
{
    [spv stop];
    if (errorPage < 0 || errorPage >= dbt.batchImages.count) return;
    UIImage *ii = dbt.batchImages[errorPage];
    [self finishSettingPDFImage:ii];
}

//=============<EXPTableDelegate>=====================================================
- (void)errorDownloadingImages : (NSString *)s
{
    [spv stop];
    NSLog(@" ERROR! %@",s); //2/8 MAKE THIS AN ERROR POPUP?
    dispatch_async(dispatch_get_main_queue(), ^{
        [self errorMessage : @"Dropbox Error" : s];
    });

}

//asdf
@end
