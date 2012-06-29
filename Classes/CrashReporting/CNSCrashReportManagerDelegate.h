//
//  CNSCrashReportManagerDelegate.h
//  HockeySDK
//
//  Created by Andreas Linde on 29.03.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CrashReporter/CrashReporter.h>

@protocol CNSCrashReportManagerDelegate <NSObject>

@required

// Invoked once the modal sheets are gone
- (void) showMainApplicationWindow;

@optional

// Invoked before a crash report will be sent
// 
// Return a userid or similar which the crashreport should contain
// Maximum length: 255 chars
// 
// Default: empty
- (NSString *)crashReportUserID;

// Invoked before a crash report will be sent
// 
// Return contact data, e.g. an email address, for the crash report
// Maximum length: 255 chars
// 
// Default: empty
-(NSString *)crashReportContact;

// Invoked before a crash report will be sent
// 
// Return cadditional application specific log data the crashreport should contain, empty by default.
// The string will automatically be wrapped into <[DATA[ ]]>, so make sure you don't do that in your string.
// 
// Default: empty
-(NSString *) crashReportApplicationLog;

@end