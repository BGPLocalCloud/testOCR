//
//   ____        _       _  __     ______
//  | __ )  __ _| |_ ___| |_\ \   / / ___|
//  |  _ \ / _` | __/ __| '_ \ \ / / |
//  | |_) | (_| | || (__| | | \ V /| |___
//  |____/ \__,_|\__\___|_| |_|\_/  \____|
//
//  BatchViewController.m
//  testOCR
//
//  Created by Dave Scruton on 12/21/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import "BatchViewController.h"



@implementation BatchViewController

#define NOCAN_RUN_ALL_BATCHES

//=============DB VC=====================================================
-(id)initWithCoder:(NSCoder *)aDecoder {
    if ( !(self = [super initWithCoder:aDecoder]) ) return nil;

    bbb = [BatchObject sharedInstance];
    bbb.delegate = self;
    [bbb setParent:self];
    vv  = [Vendors sharedInstance];
    authorized = FALSE;
    return self;
}



//=============Batch VC=====================================================
- (void)viewDidLoad {
    [super viewDidLoad];
    // 1/19 Add spinner busy indicator...
    CGSize csz   = [UIScreen mainScreen].bounds.size;
    spv = [[spinnerView alloc] initWithFrame:CGRectMake(0, 0, csz.width, csz.height)];
    [self.view addSubview:spv];

    [spv start : @"Get batch counts"];
    _outputText.text = @"...";
    _runButton.hidden = TRUE;

    [bbb getBatchCounts];
}

//=============Batch VC=====================================================
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    //Check for authorization...
    if ([DBClientsManager authorizedClient] || [DBClientsManager authorizedTeamClient])
    {
        //NSLog(@" dropbox authorized...");
        authorized = TRUE;
        bbb.authorized = TRUE;
    } //end auth OK
    else
    {
        //NSLog(@" need to be authorized...");
        //FUnny: this produces a deprecated warning. it's dropbox boilerplate code!
        [DBClientsManager authorizeFromController:[UIApplication sharedApplication]
                                       controller:self
                                          openURL:^(NSURL *url) {
                                              [[UIApplication sharedApplication] openURL:url];
                                          }];
    } //End need auth
    haltingBatchToExitVC = FALSE;

} //end viewDidAppear

//=============Batch VC=====================================================
-(void) dismiss
{
    //[_sfx makeTicSoundWithPitch : 8 : 52];
    [spv stop];
    [self dismissViewControllerAnimated : YES completion:nil];
    
}

//=============AddTemplate VC=====================================================
-(void) updateUI
{
   // NSLog(@" updateui step %d showr %d",step,showRotatedImage);
    NSString *s = @"Staged Files by Vendor:\n\n";
    for (NSString *vn in vv.vFolderNames)
    {
        int vc = [bbb getVendorFileCount:vn];
        //NSLog(@" v[%@]: %d",vn,vc);
        s = [s stringByAppendingString:[NSString stringWithFormat:@"%@ :%d\n",vn,vc]];
        
    }
    _outputText.text = s;
    
} //end updateUI

//=============Batch VC=====================================================
- (IBAction)cancelSelect:(id)sender
{
    if ([bbb.batchStatus isEqualToString:BATCH_STATUS_RUNNING])
    {
        [self exitBatchMenu];
    }
    else
        [self dismiss];
}

//=============Batch VC=====================================================
- (IBAction)runSelect:(id)sender {
    if (!authorized) return ; //can't get at dropbox w/o login! 

    NSMutableAttributedString *tatString = [[NSMutableAttributedString alloc]initWithString:@"Run Batches..."];
    [tatString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:25] range:NSMakeRange(0, tatString.length)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
                                NSLocalizedString(@"Run Batches...",nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert setValue:tatString forKey:@"attributedTitle"];
    int vindex = 0;
    for (NSString *s in vv.vNames)
    {
        int vc = [bbb getVendorFileCount:vv.vFolderNames[vindex]];
        [vv.vFileCounts addObject: [NSNumber numberWithInt: vc]]; //Save filecounts for later
        if (vc > 0) //Don't add a batch run option for empty batch folders!
        {
            [alert addAction: [UIAlertAction actionWithTitle:s
                                                  style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                      self->vendorName = s;
                                                      self->_outputText.text = @"";
                                                      [self->spv start : @"Run Batch..."];
                                                      [self->bbb clearAndRunBatches : vindex];
                                                  }]];
        }
        vindex++; //Update vendor index (for checking vendor filecounts)
    }
    UIAlertAction *allAction    = [UIAlertAction actionWithTitle:NSLocalizedString(@"Run All",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                               self->_outputText.text = @"";
                                                               [self->spv start : @"Run Batch..."];
                                                               [self->bbb clearAndRunBatches : -1];
                                                           }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                           }];
    [alert addAction:allAction];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];
} //end runSelect

//=============Batch VC=====================================================
// Yes/No to exit UI on batch running...
-(void) exitBatchMenu
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
                                NSLocalizedString(@"Batch Running. Stop Batch?",nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *yesAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"YES",nil)
                                                        style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                            haltingBatchToExitVC = TRUE;
                                                            [self->bbb haltBatch];
                                                        }];
    UIAlertAction *noAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"NO",nil)
                                                       style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                       }];
    //DHS 3/13: Add owner's ability to delete puzzle
    [alert addAction:yesAction];
    [alert addAction:noAction];
    [self presentViewController:alert animated:YES completion:nil];
    
} //end menu


#pragma mark - batchObjectDelegate

//=============<batchObjectDelegate>=====================================================
-(void) didGetBatchCounts
{
    _titleLabel.text = @"Checking Dropbox...";

    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateUI];
        self->_runButton.hidden = FALSE; //OK we can run batches now
        self->_titleLabel.text = @"Batch Processor Ready";;
        [self->spv stop];
    });
}

//=============<batchObjectDelegate>=====================================================
- (void)didCompleteBatch
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_titleLabel.text = @"Batch Complete!";
        [self addToOutputText:@"Batch Complete!"];
        [self->spv stop];
        if (haltingBatchToExitVC) [self dismiss];

    });

}

//=============<batchObjectDelegate>=====================================================
- (void)didFailBatch
{
    NSLog(@" batch FAILURE!");
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->spv stop];
    });
}

//=============<batchObjectDelegate>=====================================================
- (void)didUpdateBatchToParse
{
    //NSLog(@" ok batch didUpdateBatchToParse");
}

//=============Batch VC=====================================================
//DHS 1/28 adds text, scrolls text area too!
-(void) addToOutputText : (NSString*)s
{
    NSString *os = self->_outputText.text;
    _outputText.text = [NSString stringWithFormat:@"%@\n%@",os,s];
    // ...and autoscroll UP
    if(self->_outputText.text.length > 0 ) {
        NSRange bottom = NSMakeRange(_outputText.text.length -1, 1);
        [_outputText scrollRangeToVisible:bottom];
    }

}

//=============<batchObjectDelegate>=====================================================
- (void)batchUpdate : (NSString *) s
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_titleLabel.text = s;
        [self addToOutputText:s];
    });
}


@end
