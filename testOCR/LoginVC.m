//
//  LoginVC.m
//  testOCR
//
//  Created by Dave Scruton on 2/14/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import "LoginVC.h"

 

@implementation LoginVC

//=============Login VC=====================================================
-(id)initWithCoder:(NSCoder *)aDecoder {
    if ( !(self = [super initWithCoder:aDecoder]) ) return nil;
    
    
    return self;
}


//=============Login VC=====================================================
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    
    // 1/19 Add spinner busy indicator...
    CGSize csz   = [UIScreen mainScreen].bounds.size;
    spv = [[spinnerView alloc] initWithFrame:CGRectMake(0, 0, csz.width, csz.height)];
    [self.view addSubview:spv];

    NSLog(@" mode is %@",_mode);
    adminMode = [_mode isEqualToString:@"admin" ];
    
    _field1.delegate = self;
    _field2.delegate = self;
    _field3.delegate = self;
    _field3.hidden = (!adminMode);
}

//=============Login VC=====================================================
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self becomeFirstResponder]; //DHS 11/15 For Shake response
    
} //end viewDidAppear


//==========HDKPIX=========================================================================
- (BOOL)canBecomeFirstResponder
{
    return YES;
}

//=============Login VC=====================================================
-(void) dismiss
{
//    et.parentUp = FALSE; //2/9 Tell expTable we are outta here
    [self dismissViewControllerAnimated : YES completion:nil];
}



//=============Login VC=====================================================
- (IBAction)backSelect:(id)sender
{
    [self dismiss];
}

//=============Login VC=====================================================
- (IBAction)okSelect:(id)sender
{
    [self getFieldsAndLogin];
}

//=============Login VC=====================================================
-(void) getFieldsAndLogin
{
    username = _field1.text;
    password = _field2.text;
    if (adminMode) //Create account
    {
        pw2 = _field3.text;
       // if ([pw2 isEqualToString : @"Doogity123!"])
            [self signupUser];
    }
    else
    {
        [self loginUser];
    }
    
    
    NSLog(@" ok...");
}


//=============Login VC=====================================================
- (void)loginUser
{
    PFUser *user  = [[PFUser alloc] init];
    user.username = username;
    user.password = password;
    user.email    = username; //Username for email!
    [spv start : @"Logging in..."];
    [UIApplication.sharedApplication beginIgnoringInteractionEvents];
    [PFUser logInWithUsernameInBackground:username password:password block:^(PFUser * _Nullable user, NSError * _Nullable error) {
        [UIApplication.sharedApplication endIgnoringInteractionEvents];
        if (user != nil)
        {
            //[self alert : @"Login OK" : self->username];
            [self dismiss];
        }
        else
        {
            [self alert : @"Login Error" : error.localizedDescription];
       }
        [self->spv stop];
    }];
}  //end loginUser

//==========loginTestVC=========================================================================
- (void)signupUser
{
    PFUser *user  = [[PFUser alloc] init];
    user.username = username;
    user.password = password;
    user.email    = username; //Username for email!
    [spv start : @"Create User..."];
    [UIApplication.sharedApplication beginIgnoringInteractionEvents];
    [user signUpInBackgroundWithBlock:^(BOOL success, NSError * _Nullable error) {
        if (error != nil)
        {
            self->signupError = TRUE;
            [self alert : @"Error Creating User" : error.localizedDescription];
        }
        else
        {
            [self alert : @"User Created OK" : self->username];
        }
        [self->spv stop];
        [UIApplication.sharedApplication endIgnoringInteractionEvents];
    }];
}  // end signupUser



//==========loginTestVC=========================================================================
-(void) alert : (NSString*)titleLabel : (NSString*)message
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
                                NSLocalizedString(titleLabel,nil)
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK",nil)
                                                        style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                        }]];
    [self presentViewController:alert animated:YES completion:nil];
    
} //end alert

//==========loginTestVC=========================================================================
- (IBAction)logoutSelect:(id)sender
{
    [PFUser logOut];
}


#pragma mark - UITextFieldDelegate

//==========PuzzleVC=========================================================================
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    //NSLog(@" textFieldShouldBeginEditing ");
    return YES;
}

//==========PuzzleVC=========================================================================
- (BOOL)textFieldShouldClear:(UITextField *)textField {
    //NSLog(@" textFieldShouldClear");

    return YES;
}
//==========PuzzleVC=========================================================================
// It is important for you to hide the keyboard
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    //NSLog(@" textFieldShouldReturn");
    if (textField == _field2)
    {
        [textField resignFirstResponder];
        [self getFieldsAndLogin];
    }
    return YES;
}


//==========PuzzleVC=========================================================================
- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    //NSLog(@" textFieldDidBeginEditing");
} //end textFieldDidBeginEditing


//==========PuzzleVC=========================================================================
- (void)textFieldDidEndEditing:(UITextField *)textField
{
} //end textFieldDidEndEditing



@end
