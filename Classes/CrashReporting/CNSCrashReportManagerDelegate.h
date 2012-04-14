//
//  CNSCrashReportManagerDelegate.h
//  HockeySDK
//
//  Created by Andreas Linde on 29.03.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol CNSCrashReportManagerDelegate <NSObject>

@required

// Invoked once the modal sheets are gone
- (void) showMainApplicationWindow;

@optional

// Return additional log data the crashreport should contain, empty by default. The string will automatically be wrapped into <[DATA[ ]]>, so make sure you don't do that in your string.
-(NSString *) crashReportLog;

// Return the userid the crashreport should contain, empty by default
-(NSString *) crashReportUserID;

// Return the contact value (e.g. email) the crashreport should contain, empty by default
-(NSString *) crashReportContact;

@end