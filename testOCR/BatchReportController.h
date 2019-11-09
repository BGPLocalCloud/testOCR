//
//   ____        _       _     ____                       _ __     ______
//  | __ )  __ _| |_ ___| |__ |  _ \ ___ _ __   ___  _ __| |\ \   / / ___|
//  |  _ \ / _` | __/ __| '_ \| |_) / _ \ '_ \ / _ \| '__| __\ \ / / |
//  | |_) | (_| | || (__| | | |  _ <  __/ |_) | (_) | |  | |_ \ V /| |___
//  |____/ \__,_|\__\___|_| |_|_| \_\___| .__/ \___/|_|   \__| \_/  \____|
//                                      |_|
//  BatchReportController.h
//  testOCR
//
//  Created by Dave Scruton on 1/13/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Parse/Parse.h>
#import "AppDelegate.h"
#import "DBKeys.h"
#import "DropboxTools.h"
#import "spinnerView.h"


NS_ASSUME_NONNULL_BEGIN

@interface BatchReportController : UIViewController < DropboxToolsDelegate>
{
    int viewWid,viewHit,viewW2,viewH2;
    NSString *batchID;
    DropboxTools *dbt;
    NSString *reportText;
    spinnerView *spv;

}
@property (weak, nonatomic) IBOutlet UILabel *errLabel;
@property (weak, nonatomic) IBOutlet UILabel *warnLabel;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UITextView *contents;

- (IBAction)backSelect:(id)sender;


@property (nonatomic , strong) PFObject* pfo;

@end

NS_ASSUME_NONNULL_END
