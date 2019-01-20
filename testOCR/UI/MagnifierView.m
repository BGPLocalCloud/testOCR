//
//   __  __                   _  __ _         __     ___
//  |  \/  | __ _  __ _ _ __ (_)/ _(_) ___ _ _\ \   / (_) _____      __
//  | |\/| |/ _` |/ _` | '_ \| | |_| |/ _ \ '__\ \ / /| |/ _ \ \ /\ / /
//  | |  | | (_| | (_| | | | | |  _| |  __/ |   \ V / | |  __/\ V  V /
//  |_|  |_|\__,_|\__, |_| |_|_|_| |_|\___|_|    \_/  |_|\___| \_/\_/
//                |___/
//
//
//  MagnifierView.m
//
//  DHS 4/20 Cut and paste-coded from stackoverflow in the best DHS tradition
//

#import "MagnifierView.h"
#import <QuartzCore/QuartzCore.h>

@implementation MagnifierView
@synthesize viewToMagnify;
@dynamic touchPoint;

//=======<Magnifying Glass (from web)>==================================
- (id)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame radius:120];
} //end initWithFrame

//=======<Magnifying Glass (from web)>==================================
- (id)initWithFrame:(CGRect)frame radius:(int)r {
    int radius = r;
    //NSLog(@" init with radius %d",r);
    //THis is a double-wide frame!
    if ((self = [super initWithFrame:CGRectMake(0, 0, 2*radius, radius)])) {
        //Make the layer circular.
        //self.layer.cornerRadius = radius *0.5;
        self.layer.masksToBounds = YES;
        _xoff = _yoff = 0;
    }
    
    return self;
} //end initWithFrame

//=======<Magnifying Glass (from web)>==================================
- (void)setTouchPoint:(CGPoint)pt : (BOOL) belowFlag : (BOOL) leftFlag
{
    touchPoint = pt;
    int xoff = 40;
    if (leftFlag) xoff = -90;
    int yoff = -20;
    if (belowFlag) yoff = 180;
    self.center = CGPointMake(pt.x + xoff, pt.y + yoff);
    
} //end setTouchPoint

//=======<Magnifying Glass (from web)>==================================
- (CGPoint)getTouchPoint {
    return touchPoint;
} //end getTouchPoint

//=======<Magnifying Glass (from web)>==================================
- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect bounds = self.bounds;
//    CGImageRef mask = [UIImage imageNamed: @"loupe-mask@2x.png"].CGImage;
//    CGImageRef mask = [UIImage imageNamed: @"squareMask.png"].CGImage;
    UIImage *glass  = nil; //[UIImage imageNamed: @"magtarg.png"];
    
    CGContextSaveGState(context);
    //Only need this if using circular mask, otherwise zoomed area is rectangular
    // CGContextClipToMask(context, bounds, mask);
    CGContextFillRect(context, bounds);
    CGContextScaleCTM(context, 5, 5);
    
    //draw your subject view here
    float xxf = 1*(self.frame.size.width*0.45);
    float yyf = 1*(self.frame.size.height*0.45);
    
    CGContextTranslateCTM(context,xxf,yyf);
    float xf,yf;
    xf = -1.0*(touchPoint.x) - 25.0f + (float)_xoff;
    yf = -1.0*(touchPoint.y) - 25.0f + (float)_yoff;
    CGContextTranslateCTM(context,xf,yf);
    [self.viewToMagnify.layer renderInContext:context];
    
    CGContextRestoreGState(context);
    if (glass != nil) [glass drawInRect: bounds];
} //end drawRect

//=======<Magnifying Glass (from web)>==================================
- (void)dealloc {
   // [viewToMagnify release];
   // [super dealloc];
}

@end
