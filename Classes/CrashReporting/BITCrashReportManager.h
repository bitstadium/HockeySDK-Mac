/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Kent Sutherland
 *
 * Copyright (c) 2012 HockeyApp, Bit Stadium GmbH.
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

// flags if the crashreporter is activated at all
#define kHockeySDKCrashReportActivated @"HockeySDKCrashReportActivated"

// flags if the crashreporter should automatically send crashes without asking the user again
#define kHockeySDKAutomaticallySendCrashReports @"HockeySDKAutomaticallySendCrashReports"

// stores the set of crashreports that have been approved but aren't sent yet
#define kHockeySDKApprovedCrashReports @"HockeySDKApprovedCrashReports"


typedef enum CrashAlertType {
  CrashAlertTypeSend = 0,
  CrashAlertTypeFeedback = 1,
} CrashAlertType;

typedef enum CrashReportStatus {  
  CrashReportStatusUnknown = 0,
  CrashReportStatusAssigned = 1,
  CrashReportStatusSubmitted = 2,
  CrashReportStatusAvailable = 3,
} CrashReportStatus;

@class BITCrashReportUI;

@interface BITCrashReportManager : NSObject {
  NSFileManager *_fileManager;

  BOOL _crashIdenticalCurrentVersion;
  BOOL _crashReportActivated;
  BOOL _exceptionInterceptionEnabled;
  
  CrashReportStatus _serverResult;
  NSInteger         _statusCode;
    
  NSMutableString   *_contentOfProperty;

  id<BITCrashReportManagerDelegate> _delegate;

  NSString   *_appIdentifier;
  NSString   *_submissionURL;
  NSString   *_companyName;
  BOOL       _autoSubmitCrashReport;
  
  NSString   *_crashFile;
  
  NSMutableArray *_crashFiles;
  NSString       *_crashesDir;
  
  BITCrashReportUI *_crashReportUI;

  int _analyzerStarted;

}

- (NSString *)modelVersion;

+ (BITCrashReportManager *)sharedCrashReportManager;

// The HockeyApp app identifier (required)
@property (nonatomic, retain) NSString *appIdentifier;

// defines if PLCrashReporter Exception Interception should be used, default to NO
@property (nonatomic) BOOL exceptionInterceptionEnabled;

// defines the company name to be shown in the crash reporting dialog
@property (nonatomic, retain) NSString *companyName;

// delegate is required
@property (nonatomic, assign) id <BITCrashReportManagerDelegate> delegate;

// if YES, the crash report will be submitted without asking the user
// if NO, the user will be asked if the crash report can be submitted (default)
@property (nonatomic, assign, getter=isAutoSubmitCrashReport) BOOL autoSubmitCrashReport;

- (void)startManager;

- (void)cancelReport;
- (void)sendReportCrash:(NSString*)crashFile crashDescription:(NSString *)crashDescription;

@end
