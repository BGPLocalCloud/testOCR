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


//=============BatchReport VC=====================================================
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    //Set up rounded labels...
    _errLabel.layer.cornerRadius  = 10;
    _errLabel.clipsToBounds       = YES;

    _warnLabel.layer.cornerRadius = 10;
    _warnLabel.clipsToBounds      = YES;
}

//=============BatchReport VC=====================================================
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    NSLog(@" pfo %@",_pfo);
    
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
            NSString *folderPath = [NSString stringWithFormat : @"/%@/reports",bappDelegate.settings.outputFolder];
            NSString *reportPath = [NSString stringWithFormat:@"%@/%@_report.txt",folderPath,_pfo[PInv_BatchID_key]];
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
    reportText       = result;
    _contents.text   = reportText;
    _titleLabel.text = _pfo[PInv_BatchID_key];
}


@end
