//
//   _______  ______  ____       _        _ ___     ______
//  | ____\ \/ /  _ \|  _ \  ___| |_ __ _(_) \ \   / / ___|
//  |  _|  \  /| |_) | | | |/ _ \ __/ _` | | |\ \ / / |
//  | |___ /  \|  __/| |_| |  __/ || (_| | | | \ V /| |___
//  |_____/_/\_\_|   |____/ \___|\__\__,_|_|_|  \_/  \____|
//
//  EXPDetailVC.h
//  testOCR
//
//  Created by Dave Scruton on 1/4/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "EXPObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface EXPDetailVC : UIViewController
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *dateLabel;
@property (weak, nonatomic) IBOutlet UILabel *categoryLabel;
@property (weak, nonatomic) IBOutlet UILabel *monthLabel;
@property (weak, nonatomic) IBOutlet UILabel *itemLabel;
@property (weak, nonatomic) IBOutlet UILabel *uomLabel;
@property (weak, nonatomic) IBOutlet UILabel *bulkLabel;
@property (weak, nonatomic) IBOutlet UILabel *vendorLabel;
@property (weak, nonatomic) IBOutlet UILabel *productNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *processedLabel;
@property (weak, nonatomic) IBOutlet UILabel *localLabel;
@property (weak, nonatomic) IBOutlet UILabel *lineNumberLabel;
@property (weak, nonatomic) IBOutlet UILabel *quantityLabel;
@property (weak, nonatomic) IBOutlet UILabel *pricePerUOMLabel;
@property (weak, nonatomic) IBOutlet UILabel *totalLabel;
@property (weak, nonatomic) IBOutlet UILabel *batchLabel;
@property (weak, nonatomic) IBOutlet UILabel *pdfFileLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;

@property (nonatomic , strong) NSString* myTitle;
@property (nonatomic , strong) EXPObject* eobj;
@property (nonatomic , strong) NSArray* allObjects;
@property (nonatomic , assign) int detailIndex;

- (IBAction)backSelect:(id)sender;

@end

NS_ASSUME_NONNULL_END
