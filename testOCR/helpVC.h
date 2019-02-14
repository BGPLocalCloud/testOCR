//
//   _          _    __     ______
//  | |__   ___| |_ _\ \   / / ___|
//  | '_ \ / _ \ | '_ \ \ / / |
//  | | | |  __/ | |_) \ V /| |___
//  |_| |_|\___|_| .__/ \_/  \____|
//               |_|
//
//  helpVC.h
//  testOCR
//
//  Created by Dave Scruton on 2/13/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface helpVC : UIViewController <WKUIDelegate>
- (IBAction)backSelect:(id)sender;
@property (weak, nonatomic) IBOutlet WKWebView *webView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;

@end

NS_ASSUME_NONNULL_END
