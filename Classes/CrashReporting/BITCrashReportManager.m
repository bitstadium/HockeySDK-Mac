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

#import "BITCrashReportManager.h"
#import "BITCrashReportUI.h"
#import <sys/sysctl.h>
#import <CrashReporter/CrashReporter.h>
#import <HockeySDK/HockeySDK.h>
#import "BITCrashReportTextFormatter.h"
#import <objc/runtime.h>

#define SDK_NAME @"HockeySDK-Mac"

NSString *const kHockeyErrorDomain = @"HockeyErrorDomain";

/**
 * @internal
 *
 * The overridden version of sendEvent: in NSApplication
 */
@class NSEvent;

@interface NSObject (HockeySDK_PrivateAdditions)
- (void)hockeysdk_catching_sendEvent: (NSEvent *) theEvent;
@end

@implementation NSObject (HockeySDK_PrivateAdditions)

- (void)hockeysdk_catching_sendEvent:(NSEvent *)theEvent {
  @try {
    /* In a swizzled method, calling the swizzled selector actually calls the
     original method. */
    [self hockeysdk_catching_sendEvent:theEvent];
  } @catch (NSException *exception) {
    (NSGetUncaughtExceptionHandler())(exception);
  }
}

@end


@interface BITCrashReportManager (private)
- (NSString *)applicationName;
- (NSString *)applicationVersion;

- (BOOL)trapRunLoopExceptions;

- (void)handleCrashReport;
- (BOOL)hasPendingCrashReport;
- (void)cleanCrashReports;
- (NSString *)extractAppUUIDs:(PLCrashReport *)report;

- (void)postXML:(NSString*)xml;
- (void)searchCrashLogFile:(NSString *)path;

- (void)returnToMainApplication;
@end


@implementation BITCrashReportManager

@synthesize exceptionInterceptionEnabled = _exceptionInterceptionEnabled;
@synthesize delegate = _delegate;
@synthesize appIdentifier = _appIdentifier;
@synthesize companyName = _companyName;
@synthesize userName = _userName;
@synthesize userEmail = _userEmail;
@synthesize autoSubmitCrashReport = _autoSubmitCrashReport;
@synthesize askUserDetails = _askUserDetails;
@synthesize maxTimeIntervalOfCrashForReturnMainApplicationDelay = _maxTimeIntervalOfCrashForReturnMainApplicationDelay;
@synthesize didCrashInLastSession = _didCrashInLastSession;

#pragma mark - Init

+ (BITCrashReportManager *)sharedCrashReportManager {
  static BITCrashReportManager *crashReportManager = nil;
  
  if (crashReportManager == nil) {
    crashReportManager = [[BITCrashReportManager alloc] init];
  }
  
  return crashReportManager;
}

- (id)init {
  if ((self = [super init])) {
    _exceptionInterceptionEnabled = NO;
    _serverResult = HockeyCrashReportStatusUnknown;
    _crashReportUI = nil;
    _fileManager = [[NSFileManager alloc] init];
    _askUserDetails = YES;
    
    _crashIdenticalCurrentVersion = YES;
    _submissionURL = @"https://sdk.hockeyapp.net/";
    
    _timeIntervalCrashInLastSessionOccured = -1;
    _maxTimeIntervalOfCrashForReturnMainApplicationDelay = 5;

    _approvedCrashReports = [[NSMutableDictionary alloc] init];
    _analyzerStarted = NO;
    _didCrashInLastSession = NO;
    
    self.userName = @"";
    self.userEmail = @"";
    
    _crashFiles = [[NSMutableArray alloc] init];
    _crashesDir = nil;
    
    _invokedReturnToMainApplication = NO;
    self.delegate = nil;
    self.companyName = @"";
    
    NSString *testValue = nil;
    testValue = [[NSUserDefaults standardUserDefaults] stringForKey:kHockeySDKCrashReportActivated];
    if (testValue) {
      _crashReportActivated = [[NSUserDefaults standardUserDefaults] boolForKey:kHockeySDKCrashReportActivated];
    } else {
      _crashReportActivated = YES;
      [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:YES] forKey:kHockeySDKCrashReportActivated];
    }

    testValue = [[NSUserDefaults standardUserDefaults] stringForKey:kHockeySDKAutomaticallySendCrashReports];
    if (testValue) {
      _autoSubmitCrashReport = [[NSUserDefaults standardUserDefaults] boolForKey:kHockeySDKAutomaticallySendCrashReports];
    } else {
      _autoSubmitCrashReport = NO;
      [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:NO] forKey:kHockeySDKAutomaticallySendCrashReports];
    }
    
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    
    // temporary directory for crashes grabbed from PLCrashReporter
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDir = [paths objectAtIndex: 0];
    _crashesDir = [[[cacheDir stringByAppendingPathComponent:bundleIdentifier] stringByAppendingPathComponent:HOCKEYSDK_IDENTIFIER] retain];
    
    if (![_fileManager fileExistsAtPath:_crashesDir]) {
      NSDictionary *attributes = [NSDictionary dictionaryWithObject: [NSNumber numberWithUnsignedLong: 0755] forKey: NSFilePosixPermissions];
      NSError *theError = NULL;
      
      [_fileManager createDirectoryAtPath:_crashesDir withIntermediateDirectories: YES attributes: attributes error: &theError];
    }
    
    _settingsFile = [[_crashesDir stringByAppendingPathComponent:HOCKEYSDK_SETTINGS] retain];
      
    // on the very first startup this will always be initialized, since the default value for _crashReportActivated is YES
    // but we do it anyway, to be able to initialize PLCrashReporter as early as possible
    if (_crashReportActivated) {      
      PLCrashReporter *crashReporter = [PLCrashReporter sharedReporter];
      NSError *error = NULL;
      
      // Check if we previously crashed
      if ([crashReporter hasPendingCrashReport]) {
        _didCrashInLastSession = YES;
        [self handleCrashReport];
      }
      
      // Enable the Crash Reporter
      if (![crashReporter enableCrashReporterAndReturnError:&error])
        NSLog(@"Warning: Could not enable crash reporter: %@", error);
    }
  }
  return self;
}

- (void)dealloc {
  _delegate = nil;

  [_responseData release]; _responseData = nil;
  
  [_appIdentifier release]; _appIdentifier = nil;
  [_companyName release]; _companyName = nil;

  [_fileManager release]; _fileManager = nil;
  
  self.userName = nil;
  self.userEmail = nil;

  [_crashFiles release]; _crashFiles = nil;
  [_crashesDir release]; _crashesDir = nil;
  [_settingsFile release]; _settingsFile = nil;
  
  [_crashReportUI release]; _crashReportUI= nil;
  
  [_approvedCrashReports release]; _approvedCrashReports = nil;
  
  [super dealloc];
}


#pragma mark - Private

- (void)saveSettings {
  NSString *error = nil;

  NSMutableDictionary *rootObj = [NSMutableDictionary dictionaryWithCapacity:4];
  [rootObj setObject:self.userName forKey:kHockeySDKUserName];
  [rootObj setObject:self.userEmail forKey:kHockeySDKUserEmail];
  if (_approvedCrashReports && [_approvedCrashReports count] > 0)
    [rootObj setObject:_approvedCrashReports forKey:kHockeySDKApprovedCrashReports];
  [rootObj setObject:[NSNumber numberWithBool:_analyzerStarted] forKey:kHockeySDKAnalyzerStarted];
  
  NSData *plist = [NSPropertyListSerialization dataFromPropertyList:(id)rootObj
                                                        format:NSPropertyListBinaryFormat_v1_0
                                              errorDescription:&error];
  if (plist) {
    [plist writeToFile:_settingsFile atomically:YES];
  } else {
    HockeySDKLog(@"ERROR: Writing settings. %@", error);
  }
}

- (void)loadSettings {
  NSString *error = nil;
  NSPropertyListFormat format;
  
  if (![_fileManager fileExistsAtPath:_settingsFile])
    return;
  
  NSData *plist = [NSData dataWithContentsOfFile:_settingsFile];
  if (plist) {
    NSDictionary *rootObj = (NSDictionary *)[NSPropertyListSerialization
                                          propertyListFromData:plist
                                          mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                          format:&format
                                          errorDescription:&error];

    if ([rootObj objectForKey:kHockeySDKApprovedCrashReports])
      [_approvedCrashReports setDictionary:[rootObj objectForKey:kHockeySDKApprovedCrashReports]];
    _analyzerStarted = [(NSNumber *)[rootObj objectForKey:kHockeySDKAnalyzerStarted] boolValue];
    self.userName = [rootObj objectForKey:kHockeySDKUserName] ?: @"";
    self.userEmail = [rootObj objectForKey:kHockeySDKUserEmail] ?: @"";
  } else {
    HockeySDKLog(@"ERROR: Reading settings. %@", error);
  }
}


/**
 * Swizzle -[NSApplication sendEvent:] to capture exceptions in the run loop.
 */
- (BOOL)trapRunLoopExceptions {
  Class cls = NSClassFromString(@"NSApplication");
  
  if (!cls)
    return NO;
  
  SEL origSel = @selector(sendEvent:), altSel = @selector(hockeysdk_catching_sendEvent:);
  Method origMethod = class_getInstanceMethod(cls, origSel),
  altMethod = class_getInstanceMethod(cls, altSel);
  
  if (!origMethod || !altMethod)
    return NO;
  
  class_addMethod(cls, origSel, class_getMethodImplementation(cls, origSel), method_getTypeEncoding(origMethod));
  class_addMethod(cls, altSel, class_getMethodImplementation(cls, altSel), method_getTypeEncoding(altMethod));
  method_exchangeImplementations(class_getInstanceMethod(cls, origSel), class_getInstanceMethod(cls, altSel));
  return YES;
}


- (void)cleanCrashReports {
  NSError *error = NULL;
  
  for (NSUInteger i=0; i < [_crashFiles count]; i++) {		
    [_fileManager removeItemAtPath:[_crashFiles objectAtIndex:i] error:&error];
    [_fileManager removeItemAtPath:[[_crashFiles objectAtIndex:i] stringByAppendingString:@".meta"] error:&error];
  }
  [_crashFiles removeAllObjects];
  [_approvedCrashReports removeAllObjects];
  
  [self saveSettings];
}

- (NSString *)modelVersion {
  NSString * modelString  = nil;
  int        modelInfo[2] = { CTL_HW, HW_MODEL };
  size_t     modelSize;
  
  if (sysctl(modelInfo,
             2,
             NULL,
             &modelSize,
             NULL, 0) == 0) {
    void * modelData = malloc(modelSize);
    
    if (modelData) {
      if (sysctl(modelInfo,
                 2,
                 modelData,
                 &modelSize,
                 NULL, 0) == 0) {
        modelString = [NSString stringWithUTF8String:modelData];
      }
      
      free(modelData);
    }
  }
  
  return modelString;
}

- (NSString *)extractAppUUIDs:(PLCrashReport *)report {  
  NSMutableString *uuidString = [NSMutableString string];
  NSArray *uuidArray = [BITCrashReportTextFormatter arrayOfAppUUIDsForCrashReport:report];
  
  for (NSDictionary *element in uuidArray) {
    if ([element objectForKey:kBITBinaryImageKeyUUID] && [element objectForKey:kBITBinaryImageKeyArch] && [element objectForKey:kBITBinaryImageKeyUUID]) {
      [uuidString appendFormat:@"<uuid type=\"%@\" arch=\"%@\">%@</uuid>",
       [element objectForKey:kBITBinaryImageKeyType],
       [element objectForKey:kBITBinaryImageKeyArch],
       [element objectForKey:kBITBinaryImageKeyUUID]
       ];
    }
  }
  
  return uuidString;
}

- (void)returnToMainApplication {
  if (_invokedReturnToMainApplication) {
    return;
  }
  
  _invokedReturnToMainApplication = YES;
  
  if (self.delegate != nil && [self.delegate respondsToSelector:@selector(showMainApplicationWindow)]) {
    [self.delegate showMainApplicationWindow];
  } else {
    NSLog(@"ERROR: Required BITCrashReportManagerDelegate is not set!");
  }
}


#pragma mark - PLCrashReporter

// Called to handle a pending crash report.
- (void)handleCrashReport {
  PLCrashReporter *crashReporter = [PLCrashReporter sharedReporter];
  NSError *error = NULL;
	
  [self loadSettings];
  
  // check if the next call ran successfully the last time
  if (!_analyzerStarted) {
    // mark the start of the routine
    _analyzerStarted = YES;
    [self saveSettings];
    
    // Try loading the crash report
    NSData *crashData = [[[NSData alloc] initWithData:[crashReporter loadPendingCrashReportDataAndReturnError: &error]] autorelease];
    
    NSString *cacheFilename = [NSString stringWithFormat: @"%.0f", [NSDate timeIntervalSinceReferenceDate]];
    
    if (crashData == nil) {
      HockeySDKLog(@"Warning: Could not load crash report: %@", error);
    } else {
      [crashData writeToFile:[_crashesDir stringByAppendingPathComponent: cacheFilename] atomically:YES];
      
      // get the startup timestamp from the crash report, and the file timestamp to calculate the timeinterval when the crash happened after startup
      PLCrashReport *report = [[[PLCrashReport alloc] initWithData:crashData error:&error] autorelease];
      
      if (report.systemInfo.timestamp && report.applicationInfo.applicationStartupTimestamp) {
        _timeIntervalCrashInLastSessionOccured = [report.systemInfo.timestamp timeIntervalSinceDate:report.applicationInfo.applicationStartupTimestamp];
      }
    }
  }
	
  // Purge the report
  // mark the end of the routine
  _analyzerStarted = NO;
  [self saveSettings];
  
  [crashReporter purgePendingCrashReport];
}

- (BOOL)hasNonApprovedCrashReports {
  if (!_approvedCrashReports || [_approvedCrashReports count] == 0) return YES;
  
  for (NSUInteger i=0; i < [_crashFiles count]; i++) {
    NSString *filename = [_crashFiles objectAtIndex:i];
    
    if (![_approvedCrashReports objectForKey:filename]) return YES;
  }
  
  return NO;
}

- (BOOL)hasPendingCrashReport {
  if (!_crashReportActivated) return NO;
    
  if ([_fileManager fileExistsAtPath: _crashesDir]) {
    NSString *file = nil;
    NSError *error = NULL;
    
    NSDirectoryEnumerator *dirEnum = [_fileManager enumeratorAtPath: _crashesDir];
    
    while ((file = [dirEnum nextObject])) {
      NSDictionary *fileAttributes = [_fileManager attributesOfItemAtPath:[_crashesDir stringByAppendingPathComponent:file] error:&error];
      if ([[fileAttributes objectForKey:NSFileSize] intValue] > 0 &&
          ![file isEqualToString:@".DS_Store"] &&
          ![file hasSuffix:@".meta"] &&
          ![file hasSuffix:@".plist"]) {
        [_crashFiles addObject:[_crashesDir stringByAppendingPathComponent: file]];
      }
    }
  }
  
  if ([_crashFiles count] > 0)
    return YES;
  else
    return NO;
}


#pragma mark - Crash Report Processing

- (void)startManager {
  HockeySDKLog(@"Info: Start CrashReportManager startManager");

  BOOL returnToApp = NO;
  
  if ([self hasPendingCrashReport]) {
    HockeySDKLog(@"Info: Pending crash reports found.");
    
    NSError* error = nil;
    NSString *crashReport = nil;
    
    NSString *crashFile = [_crashFiles lastObject];
    NSData *crashData = [NSData dataWithContentsOfFile: crashFile];
    PLCrashReport *report = [[[PLCrashReport alloc] initWithData:crashData error:&error] autorelease];
    crashReport = [BITCrashReportTextFormatter stringValueForCrashReport:report];
    
    if (crashReport && !error) {        
      NSString *log = @"";
      
      if (_delegate && [_delegate respondsToSelector:@selector(crashReportApplicationLog)]) {
        log = [_delegate crashReportApplicationLog];
      }
      
      if (!self.autoSubmitCrashReport && [self hasNonApprovedCrashReports]) {
        _crashReportUI = [[BITCrashReportUI alloc] initWithManager:self
                                                   crashReportFile:crashFile
                                                       crashReport:crashReport
                                                        logContent:log
                                                       companyName:_companyName
                                                   applicationName:[self applicationName]
                                                    askUserDetails:_askUserDetails];
        
        [_crashReportUI setUserName:self.userName];
        [_crashReportUI setUserEmail:self.userEmail];
        
        [_crashReportUI askCrashReportDetails];
      } else {
        [self sendReportWithCrash:crashFile crashDescription:nil];
      }
    } else {
      if (![self hasNonApprovedCrashReports]) {
        [self performSendingCrashReports];
      } else {
        returnToApp = YES;
      }
    }
  } else {
    returnToApp = YES;
  }
  
  if (returnToApp)
    [self returnToMainApplication];
}

- (void)cancelReport {
  [self cleanCrashReports];
  [self returnToMainApplication];
}

- (void)sendReportWithCrash:(NSString*)crashFile crashDescription:(NSString *)crashDescription {
  // add notes and delegate results to the latest crash report
  
  NSMutableDictionary *metaDict = [NSMutableDictionary dictionaryWithCapacity:4];
  NSString *log = @"";
  NSString *error = nil;
  
  if (!crashDescription) crashDescription = @"";
  [metaDict setObject:crashDescription forKey:@"description"];
  
  [metaDict setObject:self.userName forKey:@"username"];
  [metaDict setObject:self.userEmail forKey:@"useremail"];
  
  if (_delegate != nil && [_delegate respondsToSelector:@selector(crashReportApplicationLog)]) {
    log = [self.delegate crashReportApplicationLog] ?: @"";
  }
  [metaDict setObject:log forKey:@"log"];
  
  NSData *plist = [NSPropertyListSerialization dataFromPropertyList:(id)metaDict
                                                             format:NSPropertyListBinaryFormat_v1_0
                                                   errorDescription:&error];
  if (plist) {
    [plist writeToFile:[NSString stringWithFormat:@"%@.meta", crashFile] atomically:YES];
  } else {
    HockeySDKLog(@"ERROR: Writing crash meta data. %@", error);
  }
  
  [self performSendingCrashReports];
}

- (void)performSendingCrashReports {
  NSError *error = NULL;
		
  NSMutableString *crashes = nil;
  _crashIdenticalCurrentVersion = NO;
  
  for (NSUInteger i=0; i < [_crashFiles count]; i++) {
    NSString *filename = [_crashFiles objectAtIndex:i];
    NSData *crashData = [NSData dataWithContentsOfFile:filename];
		
    if ([crashData length] > 0) {
      PLCrashReport *report = [[[PLCrashReport alloc] initWithData:crashData error:&error] autorelease];
			
      if (report == nil) {
        HockeySDKLog(@"ERROR: Could not parse crash report");
        // we cannot do anything with this report, so delete it
        [_fileManager removeItemAtPath:filename error:&error];
        [_fileManager removeItemAtPath:[NSString stringWithFormat:@"%@.meta", filename] error:&error];
        continue;
      }
      
      NSString *crashUUID = report.reportInfo.reportGUID ?: @"";
      NSString *crashLogString = [BITCrashReportTextFormatter stringValueForCrashReport:report];
                     
      if ([report.applicationInfo.applicationVersion compare:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]] == NSOrderedSame) {
        _crashIdenticalCurrentVersion = YES;
      }
			
      if (crashes == nil) {
        crashes = [NSMutableString string];
      }

      NSString *userid = @"";
      NSString *contact = @"";
      NSString *log = @"";
      NSString *description = @"";

      NSString *error = nil;
      NSPropertyListFormat format;
      
      NSData *plist = [NSData dataWithContentsOfFile:[filename stringByAppendingString:@".meta"]];
      if (plist) {
        NSDictionary *metaDict = (NSDictionary *)[NSPropertyListSerialization
                                                  propertyListFromData:plist
                                                  mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                                  format:&format
                                                  errorDescription:&error];
        
        userid = [metaDict objectForKey:@"username"] ?: @"";
        contact = [metaDict objectForKey:@"useremail"] ?: @"";
        log = [metaDict objectForKey:@"log"] ?: @"";
        description = [metaDict objectForKey:@"description"] ?: @"";
      } else {
        HockeySDKLog(@"ERROR: Reading crash meta data. %@", error);
      }
      
      if ([log length] > 0) {
        if ([description length] > 0) {
          description = [NSString stringWithFormat:@"%@\n\nLog:\n%@", description, log];
        } else {
          description = [NSString stringWithFormat:@"Log:\n%@", log];
        }
      }
      
      [crashes appendFormat:@"<crash><applicationname>%s</applicationname><uuids>%@</uuids><bundleidentifier>%@</bundleidentifier><systemversion>%@</systemversion><senderversion>%@</senderversion><version>%@</version><uuid>%@</uuid><platform>%@</platform><userid>%@</userid><contact>%@</contact><description><![CDATA[%@]]></description><log><![CDATA[%@]]></log></crash>",
       [[self applicationName] UTF8String],
       [self extractAppUUIDs:report],
       report.applicationInfo.applicationIdentifier,
       report.systemInfo.operatingSystemVersion,
       [self applicationVersion],
       report.applicationInfo.applicationVersion,
       crashUUID,
       [self modelVersion],
       userid,
       contact,
       [description stringByReplacingOccurrencesOfString:@"]]>" withString:@"]]" @"]]><![CDATA[" @">" options:NSLiteralSearch range:NSMakeRange(0,description.length)],
       [crashLogString stringByReplacingOccurrencesOfString:@"]]>" withString:@"]]" @"]]><![CDATA[" @">" options:NSLiteralSearch range:NSMakeRange(0,crashLogString.length)]
                       ];

      // store this crash report as user approved, so if it fails it will retry automatically
      [_approvedCrashReports setObject:[NSNumber numberWithBool:YES] forKey:filename];
    } else {
      // we cannot do anything with this report, so delete it
      [_fileManager removeItemAtPath:filename error:&error];
      [_fileManager removeItemAtPath:[NSString stringWithFormat:@"%@.meta", filename] error:&error];
    }
  }
	
  [self saveSettings];
  
  if (crashes != nil) {
    [self postXML:[NSString stringWithFormat:@"<crashes>%@</crashes>", crashes]];
  } else {
    [self returnToMainApplication];
  }
}


#pragma mark - Networking

- (void)postXML:(NSString*)xml {
  NSMutableURLRequest *request = nil;
  NSString *boundary = @"----FOO";
  
  HockeySDKLog(@"Info: Crash XML:\n%@", xml);
  
  NSString *url = [NSString stringWithFormat:@"%@api/2/apps/%@/crashes?sdk=%@&sdk_version=%@&feedbackEnabled=no",
                   _submissionURL,
                   [self.appIdentifier stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                   SDK_NAME,
                   [HOCKEYSDK_BUNDLE objectForInfoDictionaryKey:@"CFBundleShortVersionString"]
                   ];
  
  HockeySDKLog(@"Info: Sending report to %@", url);

  request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
  
  [request setValue:SDK_NAME forHTTPHeaderField:@"User-Agent"];
  [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
  [request setTimeoutInterval: 15];
  [request setHTTPMethod:@"POST"];
  NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
  [request setValue:contentType forHTTPHeaderField:@"Content-type"];
  
  NSMutableData *postBody =  [NSMutableData data];  
  [postBody appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
  if (self.appIdentifier) {
    [postBody appendData:[@"Content-Disposition: form-data; name=\"xml\"; filename=\"crash.xml\"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [postBody appendData:[[NSString stringWithFormat:@"Content-Type: text/xml\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
  } else {
    [postBody appendData:[@"Content-Disposition: form-data; name=\"xmlstring\"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
  }
  [postBody appendData:[xml dataUsingEncoding:NSUTF8StringEncoding]];
  [postBody appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
  [request setHTTPBody:postBody];
  
  _serverResult = HockeyCrashReportStatusUnknown;
  _statusCode = 200;
  
  if (_timeIntervalCrashInLastSessionOccured > -1 && _timeIntervalCrashInLastSessionOccured <= _maxTimeIntervalOfCrashForReturnMainApplicationDelay) {
    // send synchronously, so any code in applicationDidFinishLaunching after initialization that might have caused the crash, won't be executed before the crash was successfully send.
    HockeySDKLog(@"Info: Sending crash reports synchronously.");
    NSHTTPURLResponse *response = nil;
    NSError *error = nil;
    
    NSData *synchronousResponseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    _responseData = [[NSMutableData alloc] initWithData:synchronousResponseData];
    _statusCode = [response statusCode];
    
    [self processServerResult];
  } else {
    
    _responseData = [[NSMutableData alloc] init];
    
    _urlConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];

    if (!_urlConnection) {
      HockeySDKLog(@"Info: Sending crash reports could not start!");
      [self returnToMainApplication];
    } else {
      HockeySDKLog(@"Info: Returning to main application while sending.");
      [self returnToMainApplication];
    }
  }
}


- (void)processServerResult {
  NSError *error = nil;
  
  if (_statusCode >= 200 && _statusCode < 400 && _responseData != nil && [_responseData length] > 0) {
    [self cleanCrashReports];
    
    // HockeyApp uses PList XML format
    NSMutableDictionary *response = [NSPropertyListSerialization propertyListFromData:_responseData
                                                                     mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                                                               format:nil
                                                                     errorDescription:NULL];
    HockeySDKLog(@"Received API response: %@", response);
    
    _serverResult = (HockeyCrashReportStatus)[[response objectForKey:@"status"] intValue];    
  } else if (_statusCode == 400) {
    [self cleanCrashReports];
    
    error = [NSError errorWithDomain:kHockeyErrorDomain
                                code:HockeyAPIAppVersionRejected
                            userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"The server rejected receiving crash reports for this app version!", NSLocalizedDescriptionKey, nil]];
    
    HockeySDKLog(@"ERROR: %@", [error localizedDescription]);
  } else {
    if (_responseData == nil || [_responseData length] == 0) {
      error = [NSError errorWithDomain:kHockeyErrorDomain
                                  code:HockeyAPIReceivedEmptyResponse
                              userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Sending failed with an empty response!", NSLocalizedDescriptionKey, nil]];
    } else {
      error = [NSError errorWithDomain:kHockeyErrorDomain
                                  code:HockeyAPIErrorWithStatusCode
                              userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"Sending failed with status code: %i", (int)_statusCode], NSLocalizedDescriptionKey, nil]];
    }
    
    HockeySDKLog(@"ERROR: %@", [error localizedDescription]);
  }
  
  [_responseData release];
  _responseData = nil;  

  [self returnToMainApplication];
}

#pragma mark - NSURLConnection Delegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
  if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
    _statusCode = [(NSHTTPURLResponse *)response statusCode];
  }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
  [_responseData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
  HockeySDKLog(@"ERROR: %@", [error localizedDescription]);
  
  [_responseData release];
  _responseData = nil;	
  [_urlConnection release];
  _urlConnection = nil;
  
  [self returnToMainApplication];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
  [_urlConnection release];
  _urlConnection = nil;
  
  [self processServerResult];
}


#pragma mark - GetterSetter

- (void)setExceptionInterceptionEnabled:(BOOL)exceptionInterceptionEnabled {
  _exceptionInterceptionEnabled = exceptionInterceptionEnabled;
  
  /* Enable run-loop exception trapping if requested */
  if (exceptionInterceptionEnabled) {
    if (![self trapRunLoopExceptions])
      NSLog(@"Warning: Could not enable run-loop exception trapping!");
  }
}


- (NSString *)applicationName {
  NSString *applicationName = [[[NSBundle mainBundle] localizedInfoDictionary] valueForKey: @"CFBundleExecutable"];
  
  if (!applicationName)
    applicationName = [[[NSBundle mainBundle] infoDictionary] valueForKey: @"CFBundleExecutable"];
  
  return applicationName;
}


- (NSString *)applicationVersion {
  NSString *string = [[[NSBundle mainBundle] localizedInfoDictionary] valueForKey: @"CFBundleVersion"];
  
  if (!string)
    string = [[[NSBundle mainBundle] infoDictionary] valueForKey: @"CFBundleVersion"];
  
  return string;
}

@end
