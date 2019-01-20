//
//   __  __                   _  __ _         __     ___
//  |  \/  | __ _  __ _ _ __ (_)/ _(_) ___ _ _\ \   / (_) _____      __
//  | |\/| |/ _` |/ _` | '_ \| | |_| |/ _ \ '__\ \ / /| |/ _ \ \ /\ / /
//  | |  | | (_| | (_| | | | | |  _| |  __/ |   \ V / | |  __/\ V  V /
//  |_|  |_|\__,_|\__, |_| |_|_|_| |_|\___|_|    \_/  |_|\___| \_/\_/
//                |___/
//
//
//  MagnifierView.h
//
//  DHS 4/20 Cut and paste-coded from stackoverflow in the best DHS tradition
//

#import <UIKit/UIKit.h>

@interface MagnifierView : UIView {
    UIImageView *viewToMagnify;
    CGPoint touchPoint;
}

@property (nonatomic , assign) int xoff;
@property (nonatomic , assign) int yoff;
@property (nonatomic , assign) BOOL gotiPad;


@property (nonatomic, retain) UIImageView *viewToMagnify;
//@property (nonatomic, retain) UIView *viewToMagnify;
@property (assign) CGPoint touchPoint;

- (void)setTouchPoint:(CGPoint)pt : (BOOL) belowFlag : (BOOL) leftFlag;


@end
