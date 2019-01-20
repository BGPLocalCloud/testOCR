//
//   _   _             ____        _   _
//  | \ | | __ ___   _| __ ) _   _| |_| |_ ___  _ __  ___
//  |  \| |/ _` \ \ / /  _ \| | | | __| __/ _ \| '_ \/ __|
//  | |\  | (_| |\ V /| |_) | |_| | |_| || (_) | | | \__ \
//  |_| \_|\__,_| \_/ |____/ \__,_|\__|\__\___/|_| |_|___/
//
//
//  NavButtons.m
//
//  Created by Dave Scruton on 12/5/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
#import "NavButtons.h"

@implementation NavButtons
#define INV255 0.00392156

#define NBBASE 222

//==========<Navbuttons>=========================================================================
- (void)baseInit
{
    for (int i=0;i<MAXNAVBUTTONS;i++)
    {
        occupied[i]    = FALSE;
        //We don't set up child views yet...
        buttonViews[i] = nil;
        buttonArray[i] = nil;
        labelArray[i]  = nil;
        bkgdColors[i]  = nil;
        badgeViews[i]  = nil;
        badgeLabels[i] = nil;
        badgeCounts[i] = 0;
        circleCropped[i] = FALSE;
    }
    loggedIn = FALSE; //DHS 9/13 Assume we start up logged OUT
    _inset = 10; //L/R inset, buttons are spaced between these two limits 8/9 back to 10
    self.backgroundColor = [UIColor clearColor];

    blurBkgdView = [[UIView alloc] initWithFrame : CGRectMake(0, 0, viewWid, viewHit)];
    blurBkgdView.backgroundColor = [UIColor grayColor];
    blurBkgdView.opaque = NO;
    blurBkgdView.alpha = .3f;
    [self addSubview:blurBkgdView];

    defaultFont =  @"AvenirNext-Bold";
//    defaultFont =  @"AvenirNext-Regular";
    [self addButtons];
    //Login animation support...
    for (int i=0;i<4;i++)
    {
        aViews[i] = [[UIView alloc] initWithFrame : CGRectMake(0, 0, 0, 0)];
        aViews[i].backgroundColor = [UIColor blackColor];
        aViews[i].hidden = TRUE;
        [self addSubview:aViews[i]];
    }
    
} //end baseInit


//==========<Navbuttons>=========================================================================
- (id)initWithFrameAndCount:(CGRect)frame : (int) bcount
//- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    //DHS 2/9/18 use height to determine if we have an iPhone X, with a very different screen!
    //    iPhone X             = 812
    //    iPhone 8/7/6s/6      = 667
    //    iPhone 8/7/6s/6 Plus = 736
    //    iPhone 5s / SE       = 568
    int height = [UIScreen mainScreen].fixedCoordinateSpace.bounds.size.height;
    iphoneX = (height == 812);  //iPhone X

    //Set up geometry...
    viewWid   = frame.size.width;
    viewHit   = frame.size.height;
    viewW2    = viewWid/2;
    viewH2    = viewHit/2;
    fieldWid  = viewHit;
    if (iphoneX)
        buttonWid = viewHit * 0.58; //DHS 2/9/18 for iphone X
    else
        buttonWid = viewHit * 0.50; //smaller buttons

    buttonCount = bcount;
    if (self) {
        [self baseInit];
    }
    return self;
}

//==========<Navbuttons>=========================================================================
- (id)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super initWithCoder:aDecoder])) {
        [self baseInit];
    }
    return self;
}

//==========<Navbuttons>=========================================================================
//        float rf,gf,bf;
//        rf =INV255 * (float)(40*i);
//        gf = INV255 * (float)(255-48*i);
//        bf = INV255 * (float)(255-28*i);
//        UIColor *cc = [UIColor colorWithRed:rf green:gf blue:bf alpha:1];
-(void) addButtons
{
    
    int xi,yi,xs,ys;
    //int xi0,yi0;
    xi = _inset;
    yi = 0;
    xs = ys = fieldWid;
    //Avoid kaos...
    if (buttonCount == 0) buttonCount = 1;
    //float invBCount = 1.0 / (float)buttonCount;
    int seperation = viewWid - 2*_inset;
    seperation-=buttonCount*fieldWid;
    if (buttonCount > 1) seperation/=(buttonCount-1);
    seperation+=fieldWid;
    for (int i=0;i<buttonCount;i++)
    {
        int lilxy = 0.5 * (fieldWid - buttonWid);
        CGRect f2 = CGRectMake(xi,yi,xs,ys);
        buttonViews[i] = [[UIView alloc] initWithFrame:f2]; //view w/ width of the screen
        buttonViews[i].backgroundColor = [UIColor clearColor];
        [self addSubview:buttonViews[i]];
        buttonViews[i].alpha = 0;
        //NSLog(@" add buttonViews %d  tl %d %d wh %d %d",i,xi,yi,xs,ys);

        buttonArray[i] = [UIButton buttonWithType:UIButtonTypeCustom];
        buttonArray[i].frame = CGRectMake(lilxy,lilxy/2,buttonWid,buttonWid);
        buttonArray[i].tag = NBBASE + i;
        [buttonArray[i] setImage:[UIImage imageNamed:@"empty64"] forState:UIControlStateNormal];
        [buttonArray[i] setImage:[UIImage imageNamed:@"empty64"] forState:UIControlStateHighlighted];
        [buttonArray[i] addTarget:self action:@selector(bSelect:) forControlEvents:UIControlEventTouchUpInside];
        [buttonViews[i] addSubview:buttonArray[i]];
        buttonArray[i].alpha = 0;
        //Add a custom label for each button, well below button area
        int lilys = 9;
        int lilyi;
        //DHS 2/9/18 handle iphoneX
        if (iphoneX) lilyi = fieldWid - 2.2*lilys;
        else         lilyi = buttonWid * 1.25;
        labelArray[i] = [[UILabel alloc] initWithFrame:  CGRectMake(0,lilyi,fieldWid,lilys)];
        [labelArray[i] setFont:[UIFont fontWithName:defaultFont size:1*lilys]];
        labelArray[i].text            = @"";
        labelArray[i].textColor       = [UIColor whiteColor];
        labelArray[i].backgroundColor = [UIColor clearColor];
        labelArray[i].textAlignment   = NSTextAlignmentCenter; //Assume most labels will be centered?
        [buttonViews[i] addSubview:labelArray[i]];
        
        int bsize = ys * 0.30; //Badge size
        int bxi = xs - bsize;
        int byi = 0;
        CGRect fb = CGRectMake(bxi,byi,bsize,bsize);
        badgeViews[i] = [[UIView alloc] initWithFrame:fb];
        badgeViews[i].clipsToBounds = TRUE;
        badgeViews[i].backgroundColor = [UIColor yellowColor];
        [buttonViews[i] addSubview:badgeViews[i]];
        badgeViews[i].hidden = TRUE;
        badgeViews[i].layer.cornerRadius = bsize/2;
        
        badgeLabels[i] = [[UILabel alloc] initWithFrame:  fb];
        [badgeLabels[i] setFont:[UIFont fontWithName:defaultFont size:0.6*bsize]];
        badgeLabels[i].text            = @"99";
        badgeLabels[i].textColor       = [UIColor blackColor];
        badgeLabels[i].backgroundColor = [UIColor clearColor];
        badgeLabels[i].textAlignment   = NSTextAlignmentCenter; //Assume most labels will be centered?
        [buttonViews[i] addSubview:badgeLabels[i]];
        badgeLabels[i].hidden = TRUE;
        
        xi+=seperation;
        occupied[i] = TRUE;
        
    }
    
    
//    double insetval = viewWid * 0.045; //NOTE: this has to scale with the cornerRadius used in updateProfileButton!

} //end addButtons


//==========<Navbuttons>=========================================================================
// Used by animateLogin below
-(CGRect) getCornerRect: (int) phase : (int) which : (int) xi : (int) yi : (int) xs : (int) ys
{
    if (phase == 0)
    {
        switch(which)
        {
            case 0: return CGRectMake(xi   , yi   , 0, 0); break;
            case 1: return CGRectMake(xi+xs, yi   , 0, 0); break;
            case 2: return CGRectMake(xi   , yi+ys, 0, 0); break;
            case 3: return CGRectMake(xi+xs, yi+ys, 0, 0); break;
        }
    }
    else
    {
        switch(which)
        {
            case 0: return CGRectMake(xi   , yi   , xs, ys); break;
            case 1: return CGRectMake(xi+xs, yi   , xs, ys); break;
            case 2: return CGRectMake(xi   , yi+ys, xs, ys); break;
            case 3: return CGRectMake(xi+xs, yi+ys, xs, ys); break;
        }
    }
    return CGRectMake(0, 0, 0, 0);
} //end getCornerRect

//==========<Navbuttons>=========================================================================
// Assumes login button is #2, animates 3-5 in / out based on loggedIn flag
-(void) animateLogin : (BOOL) newLoginState : (UIImage *) portrait
{
    if (loggedIn == newLoginState) //No State change? No Animation!
    {
        [self setHotNot:1 :portrait :portrait]; // 12/10/18 However we may have to update portrait!
        return;
    }
    loggedIn = newLoginState;
    //NSLog(@" animatelogin %d",loggedIn);
    float dur = 0.2;
    float chainDelay = 2*dur;
    //Kihei Yellow looks nice?  0x1b0064  , 0xb0b0d3  , 0x4985CE  , 0xFCEE21<br>
    //Maybe later we can customize these colors???
    cornerColors[0] = [UIColor colorWithRed:0.11 green:.00 blue:0.39 alpha:1.0];
    cornerColors[1] = [UIColor colorWithRed:0.68 green:.68 blue:0.81 alpha:1.0];
    cornerColors[2] = [UIColor colorWithRed:0.28 green:.51 blue:0.80 alpha:1.0];
    cornerColors[3] = [UIColor colorWithRed:0.99 green:.93 blue:0.12 alpha:1.0];
    CGRect rv = buttonViews[1].frame; //This is the login view's frame
    CGRect rr = buttonArray[1].frame; //This is the login button's frame
    int xoff = rv.origin.x;
    int xi,yi,xs,ys;
    xi = rr.origin.x + xoff;
    yi = rr.origin.y;
    xs = rr.size.width;
    ys = rr.size.height;
    for (int i=0;i<4;i++)
    {
        aViews[i].hidden          = FALSE;
        aViews[i].backgroundColor = cornerColors[i];
        aViews[i].frame           = [self getCornerRect:0 :i :xi :yi :xs :ys];
    }
    //Time to animate!
    [UIView animateWithDuration: dur
                          delay: 0
                        options: UIViewAnimationOptionCurveEaseInOut
                     animations:^{  //Iris the four corner squares IN to center
                         for (int i=0;i<4;i++)
                             self->aViews[i].frame = [self getCornerRect:1 :i :xi :yi :xs/2 :ys/2];
                     }
                     completion:^(BOOL completed) { //Iris the four corner squares OUT again
                         [UIView animateWithDuration: dur
                                               delay: 0
                                             options: UIViewAnimationOptionCurveEaseInOut
                                          animations:^{
                                              [self setHotNot:1 :portrait :portrait];
                                              for (int i=0;i<4;i++)
                                                  self->aViews[i].frame = [self getCornerRect:0 :i :xi :yi :xs :ys];
                                          }
                                          completion:^(BOOL completed) {
                                              for (int i=0;i<4;i++) self->aViews[i].hidden = TRUE;
                                          }];
                     }];
    //Get RH 2 buttons ready...DHS 10/16 was RH 3 buttons
    int alpha1 = 0.0;
    int alpha2 = 1.0;
    float delays[2];
    for (int i=0;i<2;i++) delays[i] = chainDelay + (float)i * 0.5*dur;
    if (!newLoginState)
    {
        alpha1 = 1.0;
        alpha2 = 0.0;
        for (int i=0;i<2;i++) delays[1-i] = chainDelay + (float)i * 0.5*dur;
    }
    for (int i=0;i<2;i++) //Loop over RH 2 buttons...fade in / out based on login state DHS 10/16
    {
        buttonViews[i+3].alpha = alpha1;
        buttonArray[i+3].alpha = alpha1;
        //Apparently there's no animation that has duration AND delay w/o completion block!
        [UIView animateWithDuration: dur
                              delay: delays[i]
                            options: UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             self->buttonViews[i+3].alpha = alpha2;
                             self->buttonArray[i+3].alpha = alpha2;
                         }
                         completion:^(BOOL completed) {
                         }];
    }
} //end animateLogin


//==========<Navbuttons>=========================================================================
-(BOOL) isIndexLegal : (int) which
{
    if (which < 0 || which >= buttonCount) return FALSE; //Illegal button select...
    return TRUE;
}



//==========<Navbuttons>=========================================================================
-(void) setBadgeCount : (int) which : (int) count
{
    if (![self isIndexLegal : which]) return; //Illegal button select...
    badgeCounts[which] = count;
} //end setBadgeCount

//==========<Navbuttons>=========================================================================
//WHY do i have to use alpha instead of setting the parent's hidden attribute?
//   setting hidden to true doesn't work!
-(void) setHidden          : (int) which : (BOOL) hidden;
{
    //NSLog(@" nav set hidden %d = %d",which,hidden);
    if (![self isIndexLegal : which]) return; //Illegal button select...
    float a = 1;
    if (hidden) a = 0;
    buttonViews[which].alpha = a;
    buttonArray[which].alpha = a;

}

//==========<Navbuttons>=========================================================================
-(void) setHotNot : (int) which : (UIImage *) bhot : (UIImage * ) bnot
{
    if (![self isIndexLegal : which]) return; //Illegal button select...
    [buttonArray[which] setImage:bnot forState:UIControlStateNormal];
    [buttonArray[which] setImage:bhot forState:UIControlStateHighlighted];
    [buttonArray[which] setNeedsDisplay];
} //end setHotNot


//==========<Navbuttons>=========================================================================
-(void) setBackground : (int) which : (UIColor *) color
{
    if (![self isIndexLegal : which]) return; //Illegal button select...
    buttonViews[which].backgroundColor = color;
} //end setBackground

//==========<Navbuttons>=========================================================================
-(void) hideBadge : (int) which : (BOOL) hidden
{
    if (![self isIndexLegal : which]) return; //Illegal button select...
    badgeViews[which].hidden  = hidden;
    badgeLabels[which].hidden = hidden;
} //end hideBadge

//==========<Navbuttons>=========================================================================
-(void) setBadgeTextColor : (int) which : (UIColor *) color
{
    if (![self isIndexLegal : which]) return; //Illegal button select...
    badgeLabels[which].textColor = color;
}

//==========<Navbuttons>=========================================================================
-(void) setBadgeBkgdColor : (int) which : (UIColor *) color
{
    if (![self isIndexLegal : which]) return; //Illegal button select...
    badgeViews[which].backgroundColor = color;
}


//==========<Navbuttons>=========================================================================
-(void) setButtonBkgdColor : (int) which : (UIColor *) color
{
    if (![self isIndexLegal : which]) return; //Illegal button select...
    badgeViews[which].backgroundColor = color;
}

//==========<Navbuttons>=========================================================================
-(void) setCropped : (int) which : (float) percent
{
    if (![self isIndexLegal : which]) return; //Illegal button select...
    buttonArray[which].clipsToBounds = TRUE;
    buttonArray[which].layer.cornerRadius = buttonArray[which].frame.size.width * percent;
}


//==========<Navbuttons>=========================================================================
-(void) setLabelTextColor : (int) which : (UIColor *) color
{
    if (![self isIndexLegal : which]) return; //Illegal button select...
    labelArray[which].textColor = color;
}

//==========<Navbuttons>=========================================================================
-(void) setLabelText : (int) which : (NSString *) text
{
    if (![self isIndexLegal : which]) return; //Illegal button select...
    labelArray[which].text = text;
    [labelArray[which] setNeedsDisplay];
}

//==========<Navbuttons>=========================================================================
-(void) setOccupied : (int) which : (BOOL) state
{
    if (![self isIndexLegal : which]) return; //Illegal button select...
    occupied[which] = state;
}

//==========<Navbuttons>=========================================================================
-(void) setSolidBkgdColor : (UIColor*) color : (float) alpha
{
    blurBkgdView.backgroundColor = color;
    blurBkgdView.opaque = YES;
    blurBkgdView.alpha = alpha;
    
} //end setSolidBkgdColor



//==========<Navbuttons>=========================================================================
- (IBAction)bSelect:(UIButton *)button
{
    int which = (int)button.tag - NBBASE;
    //NSLog(@" duh button tag %d : %d",(int)button.tag,which);
    [_delegate didSelectNavButton:which];
} //end bSelect


//==========<Navbuttons>=========================================================================
- (void)drawRect:(CGRect)rect
{
    //NSLog(@" NAVButtons drawRect...");
    // Update all buttons as needed
    for (int i=0;i<buttonCount;i++)
    {
        buttonViews[i].hidden = !occupied[i];
    //    buttonArray[i].hidden = !occupied[i];
        int bc = badgeCounts[i];
        if (bc > 0)
        {
            badgeLabels[i].hidden = FALSE;
            badgeViews[i].hidden  = FALSE;
            badgeLabels[i].text   = [NSString stringWithFormat:@"%d",bc];
        }
    }
    


} //end drawRect


@end
