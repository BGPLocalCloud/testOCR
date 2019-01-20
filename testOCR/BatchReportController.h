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

NS_ASSUME_NONNULL_BEGIN

@interface BatchReportController : UIViewController < DropboxToolsDelegate>
{
    NSString *batchID;
    DropboxTools *dbt;
    NSString *reportText;

}
@property (weak, nonatomic) IBOutlet UILabel *errLabel;
@property (weak, nonatomic) IBOutlet UILabel *warnLabel;
@property (weak, nonatomic) IBOutlet UILabel *contents;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;

- (IBAction)backSelect:(id)sender;


@property (nonatomic , strong) PFObject* pfo;

@end

NS_ASSUME_NONNULL_END
