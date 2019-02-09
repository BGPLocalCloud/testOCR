//
//  AppDelegate.h
//  testOCR
//
//  Created by Dave Scruton on 12/3/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
//  12/21 add dropbox SDK
//  1/16  crashlytics ok now
//WARNING: DO NOT put batchObject.h in here! Causes horrible compiler problems!

#import <UIKit/UIKit.h>
#import <ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h>
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>
#import <Parse/Parse.h>
#import "OCRSettings.h"
#import "Reachability/Reachability.h"
#import "SessionManager.h"
#import "Vendors.h"

#define VERBOSITY_DELIVERY 101
#define VERBOSITY_DEBUG    102
#define VERBOSITY_HEAVY    103
#define VERBOSITY_INSANE   104

@interface AppDelegate : UIResponder <UIApplicationDelegate>
{
}

@property(nonatomic) BOOL authSuccessful;
@property (strong, nonatomic) NSString *batchID;
@property (strong, nonatomic) UIWindow *window;
@property (nonatomic , strong) NSString* versionNumber;
@property (strong, nonatomic) OCRSettings* settings;
@property (nonatomic , assign) BOOL networkStatus;
@property(nonatomic) BOOL debugMode;


@end

