// 
//  Author: Andreas Linde <mail@andreaslinde.de>
// 
//  Copyright 2012 Codenauts UG (haftungsbeschränkt). All rights reserved.
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

#import "CNSHockeyManager.h"

#import "CNSCrashReportManager.h"
#import "CNSCrashReportManagerDelegate.h"

@interface CNSHockeyManager ()

- (void)configureCrashReportManager:(BOOL)enableExceptionInterception;

@end

@implementation CNSHockeyManager

@synthesize appIdentifier = _appIdentifier;
@synthesize loggingEnabled = _loggingEnabled;
@synthesize crashReportdelegate = _crashReportdelegate;


#pragma mark - Public Class Methods

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_10_6
+ (CNSHockeyManager *)sharedHockeyManager {   
  static CNSHockeyManager *sharedInstance = nil;
  static dispatch_once_t pred;
  
  dispatch_once(&pred, ^{
    sharedInstance = [CNSHockeyManager alloc];
    sharedInstance = [sharedInstance init];
  });
  
  return sharedInstance;
}
#else
+ (CNSHockeyManager *)sharedHockeyManager {
  static CNSHockeyManager *hockeyManager = nil;
  
  if (hockeyManager == nil) {
    hockeyManager = [[CNSHockeyManager alloc] init];
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

- (void)configureWithIdentifier:(NSString *)newAppIdentifier companyName:(NSString *)newCompanyName exceptionInterceptionEnabled:(BOOL)exceptionInterceptionEnabled {

  [_appIdentifier release];
  _appIdentifier = [newAppIdentifier copy];

  [_companyName release];
  _companyName = [newCompanyName copy];

  [self configureCrashReportManager:exceptionInterceptionEnabled];
}


- (void)configureWithIdentifier:(NSString *)newAppIdentifier companyName:(NSString *)newCompanyName {
  [self configureWithIdentifier:newAppIdentifier companyName:newCompanyName exceptionInterceptionEnabled:NO];
}


- (void)configureWithIdentifier:(NSString *)newAppIdentifier exceptionInterceptionEnabled:(BOOL)exceptionInterceptionEnabled {
  [self configureWithIdentifier:newAppIdentifier companyName:@"" exceptionInterceptionEnabled:exceptionInterceptionEnabled];
}


- (void)configureWithIdentifier:(NSString *)newAppIdentifier{
  [self configureWithIdentifier:newAppIdentifier companyName:@"" exceptionInterceptionEnabled:NO];
}


- (void)setCrashReportdelegate:(id<CNSCrashReportManagerDelegate>)crashReportdelegate {
  [[CNSCrashReportManager sharedCrashReportManager] setDelegate:crashReportdelegate];
}


#pragma mark - Private Instance Methods

- (void)configureCrashReportManager:(BOOL)exceptionInterceptionEnabled {
  [[CNSCrashReportManager sharedCrashReportManager] setAppIdentifier:_appIdentifier];
  [[CNSCrashReportManager sharedCrashReportManager] setCompanyName:_companyName];
  [[CNSCrashReportManager sharedCrashReportManager] setExceptionInterceptionEnabled:exceptionInterceptionEnabled];
  [[CNSCrashReportManager sharedCrashReportManager] startManager];
}

@end
