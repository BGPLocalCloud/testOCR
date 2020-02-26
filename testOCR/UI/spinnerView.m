//
//             _                     __     ___
//   ___ _ __ (_)_ __  _ __   ___ _ _\ \   / (_) _____      __
//  / __| '_ \| | '_ \| '_ \ / _ \ '__\ \ / /| |/ _ \ \ /\ / /
//  \__ \ |_) | | | | | | | |  __/ |   \ V / | |  __/\ V  V /
//  |___/ .__/|_|_| |_|_| |_|\___|_|    \_/  |_|\___| \_/\_/
//        |_|
//
//  spinnerView.m
//  testOCR
//
//  Created by Dave Scruton on 1/19/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import "spinnerView.h"

@implementation spinnerView

//==========spinnerView=========================================================================
- (void)baseInit
{
    _message = @"";
    animTick = 0;
    self.backgroundColor = [UIColor clearColor];
    self.frame = cframe;
    _borderColor  = [UIColor colorWithRed:1 green:1 blue:1 alpha:1];
    _borderWidth  = 3;
    int xi,yi,xs,ys;
    xs = ys = lsize;
    xi = (hvsize - lsize)/2;
    yi = (hvsize - lsize)/2;
    spView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"bgpspin"]];
    [spView setFrame:CGRectMake(xi,yi, xs, ys)];
    [self addSubview : spView];
    xs = hvsize;
    ys = 40;
    yi = (xs - ys)/2;
    spLabel =  [[UILabel alloc] initWithFrame:  CGRectMake(0,yi, xs,ys)];
    spLabel.text = _message;
    [spLabel setFont: [UIFont systemFontOfSize:ys*0.7 weight:UIFontWeightBold]];
    spLabel.textAlignment   = NSTextAlignmentCenter ;
    spLabel.textColor       = [UIColor whiteColor];
    spLabel.backgroundColor = [UIColor blackColor];
    spLabel.alpha = 0.8;
    spLabel.clipsToBounds   = TRUE;
    spLabel.layer.cornerRadius = 10;

    [self  addSubview:spLabel];
    self.hidden = TRUE;
}

//==========spinnerView=========================================================================
// Frame is assumed to be FULL SCREEN
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
        int w = frame.size.width;
        int h = frame.size.height;
        //Always assume portrait!
        if (w > h)
        {
            w = frame.size.height;
            h = frame.size.width;
        }
        
        //CGSize csz   = [UIScreen mainScreen].bounds.size;
        //NSLog(@" spinnerview window size %@",NSStringFromCGSize(csz));
        
        hvsize = 256;
        lsize  = 128;
        cframe = CGRectMake((w-hvsize)/2,(h-hvsize)/2,hvsize,hvsize);
        [self baseInit];
    }
    return self;
}

//==========spinnerView=========================================================================
- (id)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super initWithCoder:aDecoder])) {
        [self baseInit];
    }
    return self;
}



//==========spinnerView=========================================================================
- (void)drawRect:(CGRect)rect
{
    CGContextRef contextRef = UIGraphicsGetCurrentContext();
    
    // Set the border width
    CGContextSetLineWidth(contextRef,_borderWidth);
    
    // Set the border color...
    CGFloat red, green, blue, alpha;
    [_borderColor getRed:&red green:&green blue:&blue alpha:&alpha];
    CGContextSetRGBStrokeColor(contextRef, red,green,blue,alpha);
    
    // Draw the border along the view edge
    CGContextStrokeRect(contextRef, rect);
     
    
}


//==========spinnerView=========================================================================
-(void) start : (NSString *) ms;
{
    _message     = ms;
    spLabel.text = _message;
    spView.transform  = CGAffineTransformMakeRotation(0); //Reset rotations
    //Trigger indicator animation..
    animTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(animtimerTick:) userInfo:nil repeats:YES];
    animTick = 0;
    self.hidden  = FALSE;
} //end startPlaceholder

//==========spinnerView=========================================================================
-(void) stop
{
    [animTimer invalidate]; //DHS 2/19/18 Stop load animation
    self.hidden  = TRUE; //DHS 2/19/18
}

//==========spinnerView=========================================================================
// Cutsie spinning animation...
- (void)animtimerTick:(NSTimer *)ltimer
{
    animTick++;
    
    [UIView animateWithDuration:0.3
                     animations:^{
                         self->spView.transform =
                         CGAffineTransformMakeRotation(0.2 * (float)self->animTick);
                     }
     ];
    
} //end animtimerTick



@end
