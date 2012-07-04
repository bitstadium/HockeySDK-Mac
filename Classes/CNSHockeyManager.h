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

@protocol CNSCrashReportManagerDelegate;

@interface CNSHockeyManager : NSObject {
@private
  NSString *_appIdentifier;
  NSString *_companyName;
  
  BOOL _loggingEnabled;
}

#pragma mark - Public Properties

@property (nonatomic, readonly) NSString *appIdentifier;

// Enable debug logging; ONLY ENABLE THIS FOR DEBUGGING!
//
// Default: NO
@property (nonatomic, assign, getter=isLoggingEnabled) BOOL loggingEnabled;

#pragma mark - Public Methods

// Returns the shared manager object
+ (CNSHockeyManager *)sharedHockeyManager;

// Configure HockeyApp with a single app identifier and delegate; use this
// only for debug or beta versions of your app!
- (void)configureWithIdentifier:(NSString *)newAppIdentifier companyName:(NSString *)newCompanyName exceptionInterceptionEnabled:(BOOL)exceptionInterceptionEnabled crashReportManagerDelegate:(id <CNSCrashReportManagerDelegate>) crashReportManagerDelegate;

- (void)configureWithIdentifier:(NSString *)newAppIdentifier companyName:(NSString *)newCompanyName crashReportManagerDelegate:(id <CNSCrashReportManagerDelegate>) crashReportManagerDelegate;

- (void)configureWithIdentifier:(NSString *)newAppIdentifier exceptionInterceptionEnabled:(BOOL)exceptionInterceptionEnabled crashReportManagerDelegate:(id <CNSCrashReportManagerDelegate>)crashReportManagerDelegate;

- (void)configureWithIdentifier:(NSString *)newAppIdentifier crashReportManagerDelegate:(id <CNSCrashReportManagerDelegate>)crashReportManagerDelegate;

@end
