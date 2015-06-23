/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
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

#import <Foundation/Foundation.h>

#import "CrashReporter.h"

// stores the set of crashreports that have been approved but aren't sent yet
#define kHockeySDKApprovedCrashReports @"HockeySDKApprovedCrashReports"

// stores the user name entered in the UI
#define kHockeySDKUserName @"HockeySDKUserName"

// stores the user email address entered in the UI
#define kHockeySDKUserEmail @"HockeySDKUserEmail"


@class BITHockeyAppClient;
@class BITHockeyAttachment;


@interface BITCrashManager ()

///-----------------------------------------------------------------------------
/// @name Delegate
///-----------------------------------------------------------------------------

// delegate is required
@property (nonatomic, unsafe_unretained) id <BITCrashManagerDelegate> delegate;

@property (nonatomic, strong) BITHockeyAppClient *hockeyAppClient;

@property (nonatomic, getter = isCrashManagerActivated) BOOL crashManagerActivated;

@property (nonatomic) NSUncaughtExceptionHandler *plcrExceptionHandler;

@property (nonatomic) PLCrashReporterCallbacks *crashCallBacks;

@property (nonatomic) NSString *lastCrashFilename;

@property (nonatomic, copy, setter = setCrashReportUIHandler:) BITCustomCrashReportUIHandler crashReportUIHandler;

@property (nonatomic, strong) NSString *crashesDir;

- (NSString *)applicationName;
- (NSString *)applicationVersion;

- (void)handleCrashReport;
- (BOOL)hasPendingCrashReport;
- (void)cleanCrashReports;
- (NSString *)extractAppUUIDs:(BITPLCrashReport *)report;

- (void)persistAttachment:(BITHockeyAttachment *)attachment withFilename:(NSString *)filename;

- (BITHockeyAttachment *)attachmentForCrashReport:(NSString *)filename;

- (void)setLastCrashFilename:(NSString *)lastCrashFilename;

/**
 *  Initialize the crash reporter and check if there are any pending crash reports
 *
 *  This method initializes the PLCrashReporter instance if it is not disabled.
 *  It also checks if there are any pending crash reports available that should be send or
 *  presented to the user.
 */
- (void)startManager;

@end
