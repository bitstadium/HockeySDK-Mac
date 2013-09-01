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


@class BITCrashReportUI;
@class BITPLCrashReporter;

/**
 * The crash reporting module.
 *
 * This is the HockeySDK module for handling crash reports, including when distributed via the App Store.
 * As a foundation it is using the open source, reliable and async-safe crash reporting framework
 * [PLCrashReporter](https://www.plcrashreporter.org).
 *
 * This module works as a wrapper around the underlying crash reporting framework and provides functionality to
 * detect new crashes, queues them if networking is not available, present a user interface to approve sending
 * the reports to the HockeyApp servers and more.
 *
 * It also provides options to add additional meta information to each crash report, like `userName`, `userEmail`,
 * additional textual log information via `BITCrashReportManagerDelegate` protocol and a way to detect startup
 * crashes so you can adjust your startup process to get these crash reports too and delay your app initialization.
 *
 * Crashes are send the next time the app starts. If `autoSubmitCrashReport` is enabled, crashes will be send
 * without any user interaction, otherwise an alert will appear allowing the users to decide whether they want
 * to send the report or not. This module is not sending the reports right when the crash happens
 * deliberately, because if is not safe to implement such a mechanism while being async-safe (any Objective-C code
 * is _NOT_ async-safe!) and not causing more danger like a deadlock of the device, than helping. We found that users
 * do start the app again because most don't know what happened, and you will get by far most of the reports.
 *
 * Sending the reports on startup is done asynchronously (non-blocking) if the crash happened outside of the
 * time defined in `maxTimeIntervalOfCrashForReturnMainApplicationDelay`.
 *
 * More background information on this topic can be found in the following blog post by Landon Fuller, the
 * developer of [PLCrashReporter](https://www.plcrashreporter.org), about writing reliable and
 * safe crash reporting: [Reliable Crash Reporting](http://goo.gl/WvTBR)
 *
 * @warning If you start the app with the Xcode debugger attached, detecting crashes will _NOT_ be enabled!
 */
@interface BITCrashReportManager : NSObject {
@private
  NSFileManager *_fileManager;

  BOOL _crashIdenticalCurrentVersion;
  BOOL _crashReportActivated;
  
  NSTimeInterval _timeIntervalCrashInLastSessionOccured;
  NSTimeInterval _maxTimeIntervalOfCrashForReturnMainApplicationDelay;
  
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
  
  BOOL                       _enableMachExceptionHandler;
  NSUncaughtExceptionHandler *_plcrExceptionHandler;
  BITPLCrashReporter         *_plCrashReporter;
  
  BITCrashReportUI *_crashReportUI;

  BOOL                _didCrashInLastSession;
  BOOL                _analyzerStarted;
  NSMutableDictionary *_approvedCrashReports;

  BOOL       _invokedReturnToMainApplication;
}

/**
 *  Returns the shared manager object
 *
 *  @return A singleton BITCrashReportManager instance ready use
 */
+ (BITCrashReportManager *)sharedCrashReportManager;


///-----------------------------------------------------------------------------
/// @name Delegate
///-----------------------------------------------------------------------------

// delegate is required
@property (nonatomic, assign) id <BITCrashReportManagerDelegate> delegate;


///-----------------------------------------------------------------------------
/// @name Configuration
///-----------------------------------------------------------------------------

// The HockeyApp app identifier (required)
@property (nonatomic, retain) NSString *appIdentifier;

/**
 *  Defines if the user interface should ask for name and email
 *
 *  Default: _YES_
 */
@property (nonatomic, assign) BOOL askUserDetails;

/**
 *  Defines the company name to be shown in the crash reporting dialog
 */
@property (nonatomic, retain) NSString *companyName;

/**
 *  Defines the users name or user id
 */
@property (nonatomic, copy) NSString *userName;

/**
 *  Defines the users email address
 */
@property (nonatomic, copy) NSString *userEmail;

/**
 *  Trap fatal signals via a Mach exception server.
 *
 *  By default the SDK is using the safe and proven in-process BSD Signals for catching crashes.
 *  This option provides an option to enable catching fatal signals via a Mach exception server
 *  instead.
 *
 *  We strongly advice _NOT_ to enable Mach exception handler in release versions of your apps!
 *
 *  Default: _NO_
 *
 * @warning The Mach exception handler executes in-process, and will interfere with debuggers when
 *  they attempt to suspend all active threads (which will include the Mach exception handler).
 *  Mach-based handling should _NOT_ be used when a debugger is attached. The SDK will not
 *  enabled catching exceptions if the app is started with the debugger running. If you attach
 *  the debugger during runtime, this may cause issues the Mach exception handler is enabled!
 */
@property (nonatomic, assign, getter=isMachExceptionHandlerEnabled) BOOL enableMachExceptionHandler;

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


///-----------------------------------------------------------------------------
/// @name Helper
///-----------------------------------------------------------------------------

/**
 *  Detect if a debugger is attached to the app process
 *
 *  This is only invoked once on app startup and can not detect if the debugger is being
 *  attached during runtime!
 *
 *  @return BOOL if the debugger is attached on app startup
 */
- (BOOL)isDebuggerAttached;


@end
