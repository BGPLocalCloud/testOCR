//
//  LoginVC.h
//  testOCR
//
//  Created by Dave Scruton on 2/14/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Parse/Parse.h>
#import "spinnerView.h"

NS_ASSUME_NONNULL_BEGIN

@interface LoginVC : UIViewController < UITextFieldDelegate>
{
    spinnerView *spv;

    NSString* username;
    NSString* password;
    NSString* pw2;
    BOOL adminMode;
    BOOL signupError;
}
- (IBAction)backSelect:(id)sender;
- (IBAction)okSelect:(id)sender;
@property (weak, nonatomic) IBOutlet UITextField *field1;
@property (weak, nonatomic) IBOutlet UITextField *field2;
@property (weak, nonatomic) IBOutlet UITextField *field3;
- (IBAction)logoutSelect:(id)sender;


@property (nonatomic , strong) NSString* mode;

@end

NS_ASSUME_NONNULL_END
