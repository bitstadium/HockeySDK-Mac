// 
//  Author: Andreas Linde <mail@andreaslinde.de>
// 
//  Copyright (c) 2012-2013 HockeyApp, Bit Stadium GmbH. All rights reserved.
//  See LICENSE.txt for author information.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "BITHockeyManager.h"
#import <HockeySDK/HockeySDK.h>

#import "BITCrashReportManager.h"
#import "BITCrashReportManagerDelegate.h"


@implementation BITHockeyManager

@synthesize appIdentifier = _appIdentifier;
@synthesize loggingEnabled = _loggingEnabled;
@synthesize exceptionInterceptionEnabled = _exceptionInterceptionEnabled;
@synthesize askUserDetails = _askUserDetails;
@synthesize maxTimeIntervalOfCrashForReturnMainApplicationDelay = _maxTimeIntervalOfCrashForReturnMainApplicationDelay;

#pragma mark - Public Class Methods

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_10_6
+ (BITHockeyManager *)sharedHockeyManager {   
  static BITHockeyManager *sharedInstance = nil;
  static dispatch_once_t pred;
  
  dispatch_once(&pred, ^{
    sharedInstance = [BITHockeyManager alloc];
    sharedInstance = [sharedInstance init];
  });
  
  return sharedInstance;
}
#else
+ (BITHockeyManager *)sharedHockeyManager {
  static BITHockeyManager *hockeyManager = nil;
  
  if (hockeyManager == nil) {
    hockeyManager = [[BITHockeyManager alloc] init];
  }
  
  return hockeyManager;
}
#endif


- (void)dealloc {
  [_appIdentifier release], _appIdentifier = nil;
  
  [super dealloc];
}


#pragma mark - Private Class Methods


#pragma mark - Public Instance Methods (Configuration)

- (void)configureWithIdentifier:(NSString *)newAppIdentifier companyName:(NSString *)newCompanyName crashReportManagerDelegate:(id <BITCrashReportManagerDelegate>)crashReportManagerDelegate {

  [_appIdentifier release];
  _appIdentifier = [newAppIdentifier copy];

  [_companyName release];
  _companyName = [newCompanyName copy];

  [[BITCrashReportManager sharedCrashReportManager] setDelegate:crashReportManagerDelegate];
}


- (void)setExceptionInterceptionEnabled:(BOOL)exceptionInterceptionEnabled {
  [[BITCrashReportManager sharedCrashReportManager] setExceptionInterceptionEnabled:exceptionInterceptionEnabled];
}


- (void)setAskUserDetails:(BOOL)askUserDetails {
  [[BITCrashReportManager sharedCrashReportManager] setAskUserDetails:askUserDetails];
}


- (void)setMaxTimeIntervalOfCrashForReturnMainApplicationDelay:(NSTimeInterval)maxTimeIntervalOfCrashForReturnMainApplicationDelay {
  [[BITCrashReportManager sharedCrashReportManager] setMaxTimeIntervalOfCrashForReturnMainApplicationDelay:maxTimeIntervalOfCrashForReturnMainApplicationDelay];
}


- (void)startManager {
	NSCharacterSet *hexSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"];
	NSCharacterSet *inStringSet = [NSCharacterSet characterSetWithCharactersInString:_appIdentifier];
	BOOL validAppID = ([_appIdentifier length] == 32) && ([hexSet isSupersetOfSet:inStringSet]);
  
	if (validAppID) {
    [[BITCrashReportManager sharedCrashReportManager] setAppIdentifier:_appIdentifier];
    [[BITCrashReportManager sharedCrashReportManager] setCompanyName:_companyName];
    [[BITCrashReportManager sharedCrashReportManager] startManager];
  } else {
    NSLog(@"ERROR: The app identifier is invalid! Please use the HockeyApp app identifier you find on the apps website on HockeyApp! The SDK is disabled!");
    [[BITCrashReportManager sharedCrashReportManager] returnToMainApplication];
  }
}


@end
