//
//    ____ _               _    _____                    _       _     __     ______
//   / ___| |__   ___  ___| | _|_   _|__ _ __ ___  _ __ | | __ _| |_ __\ \   / / ___|
//  | |   | '_ \ / _ \/ __| |/ / | |/ _ \ '_ ` _ \| '_ \| |/ _` | __/ _ \ \ / / |
//  | |___| | | |  __/ (__|   <  | |  __/ | | | | | |_) | | (_| | ||  __/\ V /| |___
//   \____|_| |_|\___|\___|_|\_\ |_|\___|_| |_| |_| .__/|_|\__,_|\__\___| \_/  \____|
//                                                |_|
//  CheckTemplateVC.h
//  testOCR
//
//  Created by Dave Scruton on 12/26/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OCRTopObject.h"
#import "EditTemplateVC.h"
NS_ASSUME_NONNULL_BEGIN

@interface CheckTemplateVC : UIViewController <UIScrollViewDelegate,OCRTopObjectDelegate>
{
    int viewWid,viewHit,viewW2,viewH2;
    int photoPixWid,photoPixHit;
    OCRTopObject *oto;
    NSString *ocredText;

}
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
- (IBAction)backSelect:(id)sender;
- (IBAction)nextSelect:(id)sender;

@property (nonatomic , strong) NSString* fileName;
@property (nonatomic , strong) UIImage* photo;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UITextView *outputTextView;
@property (nonatomic , strong) NSString *vendor;


@end

NS_ASSUME_NONNULL_END
