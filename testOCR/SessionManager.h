//
//  SessionManager.h
//  testOCR
//
//  Created by Dave Scruton on 12/19/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

@import UIKit;

@interface SessionManager : NSObject

@property (nonatomic, copy) void (^savedCompletionHandler)();

+ (instancetype)sharedSession;
- (void)startDownload:(NSURL *)url;

@end

