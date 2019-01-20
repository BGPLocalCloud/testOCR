//
//   _                 _           ____     _ _
//  (_)_ ____   _____ (_) ___ ___ / ___|___| | |
//  | | '_ \ \ / / _ \| |/ __/ _ \ |   / _ \ | |
//  | | | | \ V / (_) | | (_|  __/ |__|  __/ | |
//  |_|_| |_|\_/ \___/|_|\___\___|\____\___|_|_|
//
//  invoiceCell.h
//  testOCR
//
//  Created by Dave Scruton on 1/14/19.
//  Copyright © 2019 huedoku. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface invoiceCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *label1;
@property (weak, nonatomic) IBOutlet UILabel *label2;

@end

NS_ASSUME_NONNULL_END
