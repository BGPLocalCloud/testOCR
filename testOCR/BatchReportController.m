//
//   ____        _       _     ____                       _ __     ______
//  | __ )  __ _| |_ ___| |__ |  _ \ ___ _ __   ___  _ __| |\ \   / / ___|
//  |  _ \ / _` | __/ __| '_ \| |_) / _ \ '_ \ / _ \| '__| __\ \ / / |
//  | |_) | (_| | || (__| | | |  _ <  __/ |_) | (_) | |  | |_ \ V /| |___
//  |____/ \__,_|\__\___|_| |_|_| \_\___| .__/ \___/|_|   \__| \_/  \____|
//                                      |_|
//  BatchReportController.m
//  testOCR
//
//  Created by Dave Scruton on 1/13/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
//  2/23 Fix array -> mutableArray conversion bug
//  3/20 new folder structure
//  4/5  add dbt textfile error handler
//  8/13 Add spinner busy indicator...
#import "BatchReportController.h"

@interface BatchReportController ()

@end

@implementation BatchReportController

//=============BatchReport VC=====================================================
-(id)initWithCoder:(NSCoder *)aDecoder {
    if ( !(self = [super initWithCoder:aDecoder]) ) return nil;
    dbt = [[DropboxTools alloc] init];
    dbt.delegate = self;
    [dbt setParent:self];
    return self;
}

//=============OCR MainVC=====================================================
-(void) loadView
{
    [super loadView];
    CGSize csz   = [UIScreen mainScreen].bounds.size;
    viewWid = (int)csz.width;
    viewHit = (int)csz.height;
    viewW2  = viewWid/2;
    viewH2  = viewHit/2;
    
}


//=============BatchReport VC=====================================================
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    //Set up rounded labels...
    _errLabel.layer.cornerRadius  = 10;
    _errLabel.clipsToBounds       = YES;

    _warnLabel.layer.cornerRadius = 10;
    _warnLabel.clipsToBounds      = YES;
    
    // 8/13 Add spinner busy indicator...
    spv = [[spinnerView alloc] initWithFrame:CGRectMake(0, 0, viewWid, viewHit)];
    [self.view addSubview:spv];

}

//=============BatchReport VC=====================================================
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    int bcount = [self countCommas:_pfo[PInv_BatchErrors_key]];
    int fcount = [self countCommas:_pfo[PInv_BatchFixed_key]];;
    int errCount = bcount - fcount;  //# errs = total errs - fixed errs
    _errLabel.text               = [NSString stringWithFormat:@"%d",errCount];
    bcount = [self countCommas:_pfo[PInv_BatchWarnings_key]];
    fcount = [self countCommas:_pfo[PInv_BatchWFixed_key]];;
    int wCount = bcount - fcount;  //# errs = total errs - fixed errs
    _warnLabel.text               = [NSString stringWithFormat:@"%d",wCount];
    _titleLabel.text = @"Loading from Dropbox...";
    //Get batch files processed (to find root folder)
    NSString *bf = _pfo[PInv_BatchFiles_key];
    //There may be commas: strip!
    bf = [bf stringByReplacingOccurrencesOfString:@"," withString:@""];

    NSArray *bItems    = [bf componentsSeparatedByString:@":"];
    if (bItems != nil && bItems.count > 0)
    {
        //Look at first file in batch, break it up by folders
        NSMutableArray *chunks = [[bItems[0] componentsSeparatedByString:@"/"] mutableCopy];//DHS 2/23
        if (chunks.count >= 4)
        {
            ///outputFolder/reports/fname
            AppDelegate *bappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            NSString *reportPath = [NSString stringWithFormat:@"%@/%@_report.txt",   //3/20
                                    [bappDelegate getReportsFolderPath],_pfo[PInv_BatchID_key]];
            [self->spv start:@"Get Report..."]; //DHS 8/13
            [dbt downloadTextFile:reportPath];
            
        }
    }
} //end viewWillAppear


//=============BatchReport VC=====================================================
-(void) dismiss
{
    //[_sfx makeTicSoundWithPitch : 8 : 52];
    [self dismissViewControllerAnimated : YES completion:nil];
    
}



//=============BatchReport VC=====================================================
- (IBAction)backSelect:(id)sender
{
    [self dismiss];
}



//=============BatchReport VC=====================================================
-(int)countCommas : (NSString *)s
{
    if (s == nil) return 0;
    NSScanner *mainScanner = [NSScanner scannerWithString:s];
    NSString *temp;
    int nc=0;
    while(![mainScanner isAtEnd])
    {
        [mainScanner scanUpToString:@"," intoString:&temp];
        nc++;
        [mainScanner scanString:@"," intoString:nil];
    }
    return nc;
} //end countCommas


#pragma mark - DropboxToolsDelegate

//===========<DropboxToolDelegate>================================================
- (void)didDownloadTextFile : (NSString *)result
{
    [self->spv stop];  //DHS 8/13
    reportText       = result;
    _contents.text   = reportText;
    _titleLabel.text = _pfo[PInv_BatchID_key];
}

//===========<DropboxToolDelegate>================================================
// 4/5
- (void)errorDownloadingTextFile : (NSString *)s
{
    NSLog(@" DBT error %@",s);
}



@end
