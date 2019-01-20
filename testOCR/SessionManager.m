//
//  SessionManager.m
//  testOCR
//
//  Created by Dave Scruton on 12/19/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//  From StackOverflow: boilerplate code for NSURLSession downloading...
//  https://stackoverflow.com/questions/32676352/urlsessiondidfinisheventsforbackgroundurlsession-not-calling-objective-c

#import <Foundation/Foundation.h>
#import "SessionManager.h"
@interface SessionManager () <NSURLSessionDownloadDelegate, NSURLSessionDelegate>
@property (nonatomic, strong) NSURLSession *session;
@end

@implementation SessionManager

+ (instancetype)sharedSession {
    static id sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgpCloud"];
        self.session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    }
    return self;
}

- (void)startDownload:(NSURL *)url {
    [self.session downloadTaskWithURL:url];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    NSLog(@"%s: %@", __FUNCTION__, downloadTask.originalRequest.URL.lastPathComponent);
    
    NSError *error;
    NSURL *documents = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:false error:&error];
    NSAssert(!error, @"Docs failed %@", error);
    
    NSURL *localPath = [documents URLByAppendingPathComponent:downloadTask.originalRequest.URL.lastPathComponent];
    if (![[NSFileManager defaultManager] moveItemAtURL:location toURL:localPath error:&error]) {
        NSLog(@"move failed: %@", error);
    }
    else
    {
        NSLog(@" file copied to %@",localPath.absoluteString);
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    NSLog(@"%s: %@ %@", __FUNCTION__, error, task.originalRequest.URL.lastPathComponent);
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
    NSLog(@"%s", __FUNCTION__);
    
    // UILocalNotification *notification = [[UILocalNotification alloc] init];
    // notification.fireDate = [NSDate date];
    // notification.alertBody = [NSString stringWithFormat:NSLocalizedString(@"Downloads done", nil. nil)];
    //
    // [[UIApplication sharedApplication] scheduleLocalNotification:notification];
    
    if (self.savedCompletionHandler) {
        self.savedCompletionHandler();
        self.savedCompletionHandler = nil;
    }
}

@end

