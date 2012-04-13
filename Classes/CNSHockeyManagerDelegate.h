//
//  CNSHockeyManagerDelegate.h
//  HockeySDK
//
//  Created by Andreas Linde on 29.03.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol CNSHockeyManagerDelegate <NSObject>

@optional

// Invoked when the internet connection is started
// 
// Implement to let the delegate enable the activity indicator
- (void)connectionOpened;

// Invoked when the internet connection is closed
// 
// Implement to let the delegate disable the activity indicator
- (void)connectionClosed;

// Invoked before a crash report will be sent
// 
// Return a userid or similar which the crashreport should contain
// 
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
// Return a the description for the crashreport should contain; the string
// will automatically be wrapped into <[DATA[ ]]>, so make sure you don't do 
// that in your string.
// 
// Default: empty 
-(NSString *)crashReportDescription;

// Invoked before the user is asked to send a crash report
// 
// Implement to do additional actions, e.g. to make sure to not to ask the 
// user for an app rating :) 
- (void)willShowSubmitCrashReportAlert;

@end