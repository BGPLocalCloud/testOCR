//
//
//   _______  ______   ____     _ _
//  | ____\ \/ /  _ \ / ___|___| | |
//  |  _|  \  /| |_) | |   / _ \ | |
//  | |___ /  \|  __/| |__|  __/ | |
//  |_____/_/\_\_|    \____\___|_|_|
//
//  EXPCell.h
//  testOCR
//
//  Created by Dave Scruton on 1/1/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface EXPCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIImageView *priceIcon;
@property (weak, nonatomic) IBOutlet UIImageView *processedIcon;
@property (weak, nonatomic) IBOutlet UIImageView *localIcon;
@property (weak, nonatomic) IBOutlet UILabel *label1;
@property (weak, nonatomic) IBOutlet UILabel *label2;
@property (weak, nonatomic) IBOutlet UILabel *label3;

@property (weak, nonatomic) IBOutlet UILabel *doblabel;

@end

NS_ASSUME_NONNULL_END
