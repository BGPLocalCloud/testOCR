//
//  AppDelegate.m
//  testOCR
//
//  Created by Dave Scruton on 12/3/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
//  Dec 18: add PDF support in info.plist (CFBundleDocumentTypes setup)
//          change bundle id to com.bgpcloud.testOCR,
//          for setup with google cloud API
//  3/13    Add customers object
// 3/20    new folder structure

#import "AppDelegate.h"

@interface AppDelegate () 

@end

@implementation AppDelegate

#define NUM_SFX_SAMPLES 8
NSString *hdkSoundFiles[NUM_SFX_SAMPLES] =
{
    @"clave",          //00:click sound
    @"clave",                //01:Opening sound
    @"blip",                //02:tile sound
    @"bub1",            //03:win sound
    @"lilglock",         //04:glockinspiel trimmed
    @"congamid44k",         //05
    @"congamid44k",         //06 secret sound
    @"congamid44k",         //07 Squirrel Sound
};


//====(TestOCR AppDelegate)==========================================
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    [Parse initializeWithConfiguration:[ParseClientConfiguration configurationWithBlock:^(id<ParseMutableClientConfiguration> configuration) {
        //This is the AWS -> Mongo configuration...
        configuration.applicationId = @"jT8oJdg7ySCQrHazHQml6JHEnCoKAiYh5ON5leQk";
        configuration.clientKey     = @"hxSXfyhuz3xik85xRZlmC2XrhQ5URkOlLNAioGeY";
        configuration.server        = @"https://pg-app-jhg70nkxzqetipfyic66ks9q3kq41y.scalabl.cloud/1/";
        NSLog(@" parse DB at sashido.io connected");
        //Load Vendors from parse db,
        // ...force a load also, since object may already have been created before DB is ready!
    }]];
    
    //Dropbox?
//2/8 Old key, points to dave's dropbox    NSString *appKey = @"ltqz6bwzqfskfwj";
//    NSString *appKey = @"di1y8828rc9ax05"; //New key: points to BGP Cloud dropbox
    NSString *appKey = @"di1y8828rc9ax05"; //New key: points to BGP Cloud dropbox

    NSString *registeredUrlToHandle = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleURLTypes"][0][@"CFBundleURLSchemes"][0];
    if (!appKey || [registeredUrlToHandle containsString:@"<"]) {
        NSString *message = @"You need to set `appKey` variable in `AppDelegate.m`, as well as add to `Info.plist`, before you can use BGPCloud.";
        NSLog(@"%@", message);
        NSLog(@"Terminating...");
        exit(1);
    }
    [DBClientsManager setupWithAppKey:appKey];
    //NSLog(@" ...logged into dropbox...");

    //Crashlytics / Fabric
    [Fabric with:@[[Crashlytics class]]];
    
    //Settings...
    _settings = [OCRSettings sharedInstance];
    _vv = [Vendors sharedInstance]; //DHS 3/6 made property
    [_vv readFromParse];
    _cust = [Customers sharedInstance]; //DHS 3/13 new table
    [self getUserDefaults];
    //_selectedCustomer         = @"KCH"; //Default to something!
    //_selectedCustomerFullName = @"Kona Hospital";
    //Reachability...
    [self monitorReachability];
#define USE_SFX
#ifdef USE_SFX
    //Load Audio Sample files...
    _sfx = [soundFX sharedInstance];
    for (int i=0;i<NUM_SFX_SAMPLES;i++)
    {
        [_sfx setSoundFileName:i :hdkSoundFiles[i]];
    }
    //For now, load ALL audio in background: mixed foreground/background audio loading was
    //  causing data corruption in the sound buffers. We will have to accept no "bong" sound
    //STill getting audio weirdness: Load in bkgd 99 seems to load up every sample but 1,
    //  while loadAudio (foreground) produces all null audio or static!
    [_sfx loadAudioBKGD:0]; ///6]; //Load all samples except 6 in bkgd, 6 loads immediately...
#endif

    
    _debugMode = FALSE;
    
    _versionNumber    = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];

    // Override point for customization after application launch.
    return YES;
}


//====(TestOCR AppDelegate)==========================================
- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


//====(TestOCR AppDelegate)==========================================
- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler {
    [SessionManager sharedSession].savedCompletionHandler = completionHandler;
}

//====(TestOCR AppDelegate)==========================================
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    DBOAuthResult *authResult = [DBClientsManager handleRedirectURL:url];
    if (authResult != nil) {
        if ([authResult isSuccess]) {
            NSLog(@"Success! User is logged into Dropbox.");
            //UINavigationController *navigationController = (UINavigationController *)self.window.rootViewController;
            _authSuccessful = YES;
            return YES;
        } else if ([authResult isCancel]) {
            NSLog(@"Authorization flow was manually canceled by user!");
        } else if ([authResult isError]) {
            NSLog(@"Error: %@", authResult);
        }
    }
    
    return NO;
}


//====(TestOCR AppDelegate)==========================================
// Can we see the internet??
- (void)monitorReachability {
    //    Reachability *hostReach = [Reachability reachabilityWithHostname:@"www.google.com"];
    //DHS 9/11 Got rid of elasticbeanstalk -> Sashido's cloud
    Reachability *hostReach = [Reachability reachabilityWithHostname:@"scalabl.cloud"];
    hostReach.reachableBlock = ^(Reachability*reach) {
        self->_networkStatus = [reach currentReachabilityStatus];
        //NSLog(@" monitorReachability: status %d",_networkStatus);
    };
    [hostReach startNotifier];
} //end monitorReachability

//====(TestOCR AppDelegate)==========================================
-(void) updateCustomerDefaults : (NSString *)customerString : (NSString *)customerFullString
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    _selectedCustomer            = customerString;
    _selectedCustomerFullName    = customerFullString;
    [userDefaults setObject:_selectedCustomer         forKey:@"customer"];
    [userDefaults setObject:_selectedCustomerFullName forKey:@"customerFull"];

} //end updateCustomerDefault

//====(TestOCR AppDelegate)==========================================
-(void) getUserDefaults
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if ([userDefaults objectForKey:@"customer"] == nil  ) //No defaults yet?
    {
        NSLog(@" no defaults: reset");
        [userDefaults setObject:@"KCH" forKey:@"customer"];
        [userDefaults setObject:@"Kona Hospital" forKey:@"customerFull"];
    }
    else NSLog(@" found defaults...");
    _selectedCustomer         = [userDefaults objectForKey:@"customer"];
    _selectedCustomerFullName = [userDefaults objectForKey:@"customerFull"];

}

//====(TestOCR AppDelegate)==========================================
// 3/20 new folder structure
-(NSString *)getBatchFolderPath
{
    NSString *s = [NSString stringWithFormat:@"%@/%@",_selectedCustomer,_settings.batchFolder];
    return s;
}

//====(TestOCR AppDelegate)==========================================
// 3/20 new folder structure
-(NSString *)getOutputFolderPath
{
    NSString *s = [NSString stringWithFormat:@"%@/%@",_selectedCustomer,_settings.outputFolder];
    return s;
}

//====(TestOCR AppDelegate)==========================================
// 3/20 new folder structure
-(NSString *)getReportsFolderPath
{
    NSString *s = [NSString stringWithFormat:@"/%@/%@/reports",_selectedCustomer,_settings.outputFolder];
    return s;
}


@end
