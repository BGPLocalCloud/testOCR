//
//   _   _             ____        _   _
//  | \ | | __ ___   _| __ ) _   _| |_| |_ ___  _ __  ___
//  |  \| |/ _` \ \ / /  _ \| | | | __| __/ _ \| '_ \/ __|
//  | |\  | (_| |\ V /| |_) | |_| | |_| || (_) | | | \__ \
//  |_| \_|\__,_| \_/ |____/ \__,_|\__|\__\___/|_| |_|___/
//
//
//  NavButtons.h
//
//  Created by Dave Scruton on 12/5/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <UIKit/UIKit.h>


@protocol NavButtonsDelegate;

#define MAXNAVBUTTONS 8
@interface NavButtons : UIView

{
    UIView *blurBkgdView;
    BOOL          occupied[MAXNAVBUTTONS];
    UIView    *buttonViews[MAXNAVBUTTONS];     //Crude and rude...
    UIButton  *buttonArray[MAXNAVBUTTONS];
    UILabel    *labelArray[MAXNAVBUTTONS];
    UIColor    *bkgdColors[MAXNAVBUTTONS];
    UIView     *badgeViews[MAXNAVBUTTONS];
    UILabel   *badgeLabels[MAXNAVBUTTONS];
    BOOL     circleCropped[MAXNAVBUTTONS];
    int buttonCount;
    int viewWid,viewHit,viewW2,viewH2;
    int buttonWid;
    int fieldWid;
    NSString *defaultFont;
    int badgeCounts[MAXNAVBUTTONS];
    BOOL iphoneX;
    //For login animation...
    UIColor *cornerColors[4];
    UIView *aViews[4];
    BOOL loggedIn;
}

@property (nonatomic, assign) int inset;
@property (nonatomic, unsafe_unretained) id <NavButtonsDelegate> delegate; // receiver of completion messages
@property (nonatomic, assign) BOOL zebra;

- (id)initWithFrameAndCount:(CGRect)frame : (int) bcount;
-(void) animateLogin       : (BOOL) loggedIn : (UIImage *) portrait;
-(void) hideBadge          : (int) which : (BOOL) hidden;
-(void) setHidden          : (int) which : (BOOL) hidden;
-(void) setHotNot          : (int) which : (UIImage *) bhot : (UIImage * ) bnot;
-(void) setBackground      : (int) which : (UIColor *) color;
-(void) setBadgeCount      : (int) which : (int) count;
-(void) setBadgeTextColor  : (int) which : (UIColor *) color;
-(void) setBadgeBkgdColor  : (int) which : (UIColor *) color;
-(void) setButtonBkgdColor : (int) which : (UIColor *) color;
-(void) setCropped         : (int) which : (float) percent;
-(void) setLabelTextColor  : (int) which : (UIColor *) color;
-(void) setLabelText       : (int) which : (NSString *) text;
-(void) setOccupied        : (int) which : (BOOL) state;
-(void) setSolidBkgdColor  : (UIColor*) color : (float) alpha;

@end

@protocol NavButtonsDelegate <NSObject>
@required
- (void)didSelectNavButton : (int) which;
@optional
@end

