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

