//
//   ____        _       _  __     ______
//  | __ )  __ _| |_ ___| |_\ \   / / ___|
//  |  _ \ / _` | __/ __| '_ \ \ / / |
//  | |_) | (_| | || (__| | | \ V /| |___
//  |____/ \__,_|\__\___|_| |_|\_/  \____|
//
//  BatchViewController.h
//  testOCR
//
//  Created by Dave Scruton on 12/21/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "BatchObject.h"
#import "spinnerView.h"
#import "Vendors.h"

@interface BatchViewController : UIViewController <batchObjectDelegate,OCRTemplateDelegate>
{
    Vendors *vv;
    BOOL authorized;
    NSString *vendorName;
    BatchObject *bbb;
    UIViewController *parent;
    spinnerView *spv;
    BOOL haltingBatchToExitVC;
    NSArray *fiscalMonths;
    NSString* batchMonth;
}
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UIButton *runButton;
@property (weak, nonatomic) IBOutlet UITextView *outputText;
@property (weak, nonatomic) IBOutlet UIButton *monthButton;

- (IBAction)cancelSelect:(id)sender;
- (IBAction)runSelect:(id)sender;
- (IBAction)monthSelect:(id)sender;
- (IBAction)debugSelect:(id)sender;

@end

