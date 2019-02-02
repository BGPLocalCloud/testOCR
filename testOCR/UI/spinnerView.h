//
//             _                     __     ___
//   ___ _ __ (_)_ __  _ __   ___ _ _\ \   / (_) _____      __
//  / __| '_ \| | '_ \| '_ \ / _ \ '__\ \ / /| |/ _ \ \ /\ / /
//  \__ \ |_) | | | | | | | |  __/ |   \ V / | |  __/\ V  V /
//  |___/ .__/|_|_| |_|_| |_|\___|_|    \_/  |_|\___| \_/\_/
//        |_|
//
//  spinnerView.h
//  testOCR
//
//  Created by Dave Scruton on 1/19/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface spinnerView : UIView
{
    CGRect cframe;
    UIView *spView;
    UILabel *spLabel;
    int animTick;
    NSTimer *animTimer;
    int hvsize;
    int lsize;
    
}
@property (nonatomic, assign) int borderWidth;
@property (nonatomic, strong) UIColor *borderColor;
@property (nonatomic, strong) NSString *message;

-(void) start : (NSString *) ms;
-(void) stop;

@end

