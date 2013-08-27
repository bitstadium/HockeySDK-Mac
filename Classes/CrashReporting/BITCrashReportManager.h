/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Kent Sutherland
 *
 * Copyright (c) 2012-2013 HockeyApp, Bit Stadium GmbH.
 * Copyright (c) 2011 Andreas Linde & Kent Sutherland.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import <Cocoa/Cocoa.h>
#import <HockeySDK/BITCrashReportManagerDelegate.h>

// flags if the crashlog analyzer is started. since this may theoretically crash we need to track it
#define kHockeySDKAnalyzerStarted @"HockeySDKCrashReportAnalyzerStarted"

// stores the set of crashreports that have been approved but aren't sent yet
#define kHockeySDKApprovedCrashReports @"HockeySDKApprovedCrashReports"

// stores the user name entered in the UI
#define kHockeySDKUserName @"HockeySDKUserName"

// stores the user email address entered in the UI
#define kHockeySDKUserEmail @"HockeySDKUserEmail"


// flags if the crashreporter is activated at all
// set this as bool in user defaults e.g. in the settings, if you want to let the user be able to deactivate it
#define kHockeySDKCrashReportActivated @"HockeySDKCrashReportActivated"

// flags if the crashreporter should automatically send crashes without asking the user again
// set this as bool in user defaults e.g. in the settings, if you want to let the user be able to set this on or off
// or set it on runtime using the `autoSubmitCrashReport property` via
// `[[BITCrashReportManager sharedCrashReportManager] setAutoSubmitCrashReport: YES];`
#define kHockeySDKAutomaticallySendCrashReports @"HockeySDKAutomaticallySendCrashReports"


// hockey api error domain
typedef enum {
  HockeyErrorUnknown,
  HockeyAPIAppVersionRejected,
  HockeyAPIReceivedEmptyResponse,
  HockeyAPIErrorWithStatusCode
} HockeyErrorReason;
extern NSString *const __attribute__((unused)) kHockeyErrorDomain;


typedef enum HockeyCrashAlertType {
  HockeyCrashAlertTypeSend = 0,
  HockeyCrashAlertTypeFeedback = 1,
} HockeyCrashAlertType;

typedef enum HockeyCrashReportStatus {  
  HockeyCrashReportStatusUnknown = 0,
  HockeyCrashReportStatusAssigned = 1,
  HockeyCrashReportStatusSubmitted = 2,
  HockeyCrashReportStatusAvailable = 3,
} HockeyCrashReportStatus;

@class BITCrashReportUI;

@interface BITCrashReportManager : NSObject {
  NSFileManager *_fileManager;

  BOOL _crashIdenticalCurrentVersion;
  BOOL _crashReportActivated;
  
  NSTimeInterval _timeIntervalCrashInLastSessionOccured;
  NSTimeInterval _maxTimeIntervalOfCrashForReturnMainApplicationDelay;
  
  HockeyCrashReportStatus _serverResult;
  NSInteger         _statusCode;
  NSURLConnection   *_urlConnection;
  NSMutableData     *_responseData;

  id<BITCrashReportManagerDelegate> _delegate;

  NSString   *_appIdentifier;
  NSString   *_submissionURL;
  NSString   *_companyName;
  BOOL       _autoSubmitCrashReport;
  BOOL       _askUserDetails;
  
  NSString   *_userName;
  NSString   *_userEmail;
    
  NSMutableArray *_crashFiles;
  NSString       *_crashesDir;
  NSString       *_settingsFile;

  NSUncaughtExceptionHandler *_plcrExceptionHandler;
  
  BITCrashReportUI *_crashReportUI;

  BOOL                _didCrashInLastSession;
  BOOL                _analyzerStarted;
  NSMutableDictionary *_approvedCrashReports;

  BOOL       _invokedReturnToMainApplication;
}

- (NSString *)modelVersion;

+ (BITCrashReportManager *)sharedCrashReportManager;

// The HockeyApp app identifier (required)
@property (nonatomic, retain) NSString *appIdentifier;

// defines if the user interface should ask for name and email, default to NO
@property (nonatomic, assign) BOOL askUserDetails;

// defines the company name to be shown in the crash reporting dialog
@property (nonatomic, retain) NSString *companyName;

// defines the users name or user id
@property (nonatomic, copy) NSString *userName;

// defines the users email address
@property (nonatomic, copy) NSString *userEmail;

// delegate is required
@property (nonatomic, assign) id <BITCrashReportManagerDelegate> delegate;

// Indicates if the app crash in the previous session
/**
 *  Indicates if the app crash in the previous session
 */
@property (nonatomic, readonly) BOOL didCrashInLastSession;

/**
 *  Submit crash reports without asking the user
 *
 *  _YES_: The crash report will be submitted without asking the user
 *  _NO_: The user will be asked if the crash report can be submitted (default)
 *
 *  Default: _NO_
 */
@property (nonatomic, assign, getter=isAutoSubmitCrashReport) BOOL autoSubmitCrashReport;

/**
 *  Time between startup and a crash within which sending a crash will be send synchronously
 *
 *  By default crash reports are being send asynchronously, since otherwise it may block the
 *  app from startup, e.g. while the network is down and the crash report can not be send until
 *  the timeout occurs.
 *
 *  But especially crashes during app startup could be frequent to the affected user and if the app
 *  would continue to startup normally it might crash right away again, resulting in the crash reports
 *  never to arrive.
 *
 *  This property allows to specify the time between app start and crash within which the crash report
 *  should be send synchronously instead to improve the probability of the crash report being send successfully.
 *
 *  Default: _5_
 */
@property (nonatomic, readwrite) NSTimeInterval maxTimeIntervalOfCrashForReturnMainApplicationDelay;

- (void)returnToMainApplication;

- (void)cancelReport;
- (void)sendReportWithCrash:(NSString*)crashFile crashDescription:(NSString *)crashDescription;
/**
 *  Initialize the crash reporter and check if there are any pending crash reports
 *
 *  This method initializes the PLCrashReporter instance if it is not disabled.
 *  It also checks if there are any pending crash reports available that should be send or
 *  presented to the user.
 */
- (void)startManager;

@end
