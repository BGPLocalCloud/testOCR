//
//                            ____     _ _
//   ___ _ __ _ __ ___  _ __ / ___|___| | |
//  / _ \ '__| '__/ _ \| '__| |   / _ \ | |
//  |  __/ |  | | | (_) | |  | |__|  __/ | |
//  \___|_|  |_|  \___/|_|   \____\___|_|_|
//
//  errorCell.h
//  testOCR
//
//  Created by Dave Scruton on 1/4/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface errorCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *errorLabel;
@property (weak, nonatomic) IBOutlet UILabel *label2;
@property (weak, nonatomic) IBOutlet UIImageView *errIcon;

@end

