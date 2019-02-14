//
//   _          _    __     ______
//  | |__   ___| |_ _\ \   / / ___|
//  | '_ \ / _ \ | '_ \ \ / / |
//  | | | |  __/ | |_) \ V /| |___
//  |_| |_|\___|_| .__/ \_/  \____|
//               |_|
//
//  helpVC.m
//  testOCR
//
//  Created by Dave Scruton on 2/13/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
//  DUMBASS HTML5
//   https://www.html-5-tutorial.com/div-tag.htm
//  COLORS
//   https://www.w3schools.com/colors/colors_hex.asp

#import "helpVC.h"

@interface helpVC ()

@end

@implementation helpVC

//=============Help VC=====================================================
- (void)viewDidLoad {
    [super viewDidLoad];

    _webView.UIDelegate = self;
    [self loadHelpHTML];
}

//=============Help VC=====================================================
-(void) loadHelpHTML
{
    NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"index" ofType:@"html" inDirectory:@"www"]];
    NSURLRequest *requestObj = [NSURLRequest requestWithURL:url];
    [_webView loadRequest:requestObj];
}

//=============Help VC=====================================================
-(void) dismiss
{
    //[_sfx makeTicSoundWithPitch : 8 : 52];
    [self dismissViewControllerAnimated : YES completion:nil];
}


//=============Help VC=====================================================
- (IBAction)backSelect:(id)sender
{
    [self dismiss];
}
@end
