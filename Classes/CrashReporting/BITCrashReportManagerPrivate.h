//
//  BITCrashReportManagerPrivate.h
//  HockeySDK
//
//  Created by Andreas Linde on 08.08.13.
//
//

#import <Foundation/Foundation.h>

#import <CrashReporter/CrashReporter.h>


@interface BITCrashReportManager ()


@property (nonatomic) NSUncaughtExceptionHandler *plcrExceptionHandler;

- (NSString *)applicationName;
- (NSString *)applicationVersion;

- (void)returnToMainApplication;

- (void)cancelReport;
- (void)sendReportWithCrash:(NSString*)crashFile crashDescription:(NSString *)crashDescription;

- (void)handleCrashReport;
- (BOOL)hasPendingCrashReport;
- (void)cleanCrashReports;
- (NSString *)extractAppUUIDs:(BITPLCrashReport *)report;

- (void)postXML:(NSString*)xml;

@end
