/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Kent Sutherland
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
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


#ifndef HockeySDK_HockeySDKPrivate_h
#define HockeySDK_HockeySDKPrivate_h

#define BITHOCKEY_NAME @"HockeySDK"
#define BITHOCKEY_IDENTIFIER @"net.hockeyapp.sdk.mac"
#define BITHOCKEY_CRASH_SETTINGS @"BITCrashManager.plist"
#define BITHOCKEY_CRASH_ANALYZER @"BITCrashManager.analyzer"

#define BITHOCKEY_FEEDBACK_SETTINGS @"BITFeedbackManager.plist"

#define BITHOCKEY_INTEGRATIONFLOW_TIMESTAMP @"BITIntegrationFlowStartTimestamp"

#define BITHockeyBundle [NSBundle bundleWithIdentifier:BITHOCKEY_IDENTIFIER]
//#define BITHOCKEYSDK_URL @"https://sdk.hockeyapp.net/"
extern NSString *const __attribute__((unused)) kBITHockeySDKURL;

extern NSString *const __attribute__((unused)) kBITFeedbackAttachmentLoadedNotification;
extern NSString *const __attribute__((unused)) kBITFeedbackAttachmentLoadedKey;

#define BITHockeyLocalizedString(key,comment) NSLocalizedStringFromTableInBundle(key, @"HockeySDK", BITHockeyBundle, comment)
#define BITHockeyLog(fmt, ...) do { if([BITHockeyManager sharedHockeyManager].isDebugLogEnabled) { NSLog((@"[HockeySDK] %s/%d " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__); }} while(0)


#define BIT_RGBCOLOR(r,g,b) [NSColor colorWithCalibratedRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1]

#define BIT_ATTACHMENT_THUMBNAIL_LENGTH 45

#endif


