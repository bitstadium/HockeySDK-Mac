/*
 * Author: Andreas Linde <mail@andreaslinde.de>
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

#import "HockeySDK.h"
#import "HockeySDKPrivate.h"

#import "BITCrashReportUI.h"

#import "BITHockeyBaseManagerPrivate.h"
#import "BITCrashManagerPrivate.h"
#import "BITHockeyAttachment.h"
#import "BITCrashDetails.h"
#import "BITCrashDetailsPrivate.h"
#import "BITCrashMetaData.h"

#import "BITHockeyHelper.h"
#import "BITHockeyAppClient.h"

#import "BITCrashReportTextFormatter.h"
#import <CrashReporter/CrashReporter.h>

#import <sys/sysctl.h>
#import <objc/runtime.h>

// flags if the crashlog analyzer is started. since this may theoretically crash we need to track it
#define kHockeySDKAnalyzerStarted @"HockeySDKCrashReportAnalyzerStarted"

// stores the set of crashreports that have been approved but aren't sent yet
#define kBITCrashApprovedReports @"HockeySDKCrashApprovedReports"

// keys for meta information associated to each crash
#define kBITCrashMetaUserName @"BITCrashMetaUserName"
#define kBITCrashMetaUserEmail @"BITCrashMetaUserEmail"
#define kBITCrashMetaUserID @"BITCrashMetaUserID"
#define kBITCrashMetaApplicationLog @"BITCrashMetaApplicationLog"
#define kBITCrashMetaDescription @"BITCrashMetaDescription"
#define kBITCrashMetaAttachment @"BITCrashMetaAttachment"

NSString *const kHockeyErrorDomain = @"HockeyErrorDomain";


static BITCrashManagerCallbacks bitCrashCallbacks = {
  .context = NULL,
  .handleSignal = NULL
};

// proxy implementation for PLCrashReporter to keep our interface stable while this can change
static void plcr_post_crash_callback (siginfo_t *info, ucontext_t *uap, void *context) {
  if (bitCrashCallbacks.handleSignal != NULL)
    bitCrashCallbacks.handleSignal(context);
}

static PLCrashReporterCallbacks plCrashCallbacks = {
  .version = 0,
  .context = NULL,
  .handleSignal = plcr_post_crash_callback
};


@implementation BITCrashManager {
  BOOL _sendingInProgress;
  
  NSFileManager *_fileManager;
  
  BOOL _crashIdenticalCurrentVersion;
  
  NSInteger       _statusCode;
  NSURLConnection *_urlConnection;
  NSMutableData   *_responseData;
  
  NSMutableArray *_crashFiles;
  NSString       *_settingsFile;
  NSString       *_analyzerInProgressFile;
  
  BITPLCrashReporter *_plCrashReporter;
  
  BITCrashReportUI *_crashReportUI;
  
  NSMutableDictionary *_approvedCrashReports;
  
  NSMutableDictionary *_dictOfLastSessionCrash;
}


#pragma mark - Init

- (instancetype)init {
  if ((self = [super init])) {
    _crashReportUI = nil;
    _fileManager = [[NSFileManager alloc] init];
    _askUserDetails = YES;
    
    _plcrExceptionHandler = nil;
    _crashCallBacks = nil;
    _crashIdenticalCurrentVersion = YES;
    
    _timeintervalCrashInLastSessionOccured = -1;

    _approvedCrashReports = [[NSMutableDictionary alloc] init];
    _dictOfLastSessionCrash = [[NSMutableDictionary alloc] init];
    _didCrashInLastSession = NO;
    
    _crashFiles = [[NSMutableArray alloc] init];
    _crashesDir = nil;

    _submitModally = NO;
    self.delegate = nil;
    
    NSString *testValue = nil;
    testValue = [[NSUserDefaults standardUserDefaults] stringForKey:kHockeySDKCrashReportActivated];
    if (testValue) {
      _crashManagerActivated = [[NSUserDefaults standardUserDefaults] boolForKey:kHockeySDKCrashReportActivated];
    } else {
      _crashManagerActivated = YES;
      [[NSUserDefaults standardUserDefaults] setValue:@YES forKey:kHockeySDKCrashReportActivated];
    }

    testValue = [[NSUserDefaults standardUserDefaults] stringForKey:kHockeySDKAutomaticallySendCrashReports];
    if (testValue) {
      _autoSubmitCrashReport = [[NSUserDefaults standardUserDefaults] boolForKey:kHockeySDKAutomaticallySendCrashReports];
    } else {
      _autoSubmitCrashReport = NO;
      [[NSUserDefaults standardUserDefaults] setValue:@NO forKey:kHockeySDKAutomaticallySendCrashReports];
    }
    
    _crashesDir = bit_settingsDir();
    _settingsFile = [_crashesDir stringByAppendingPathComponent:BITHOCKEY_CRASH_SETTINGS];
    _analyzerInProgressFile = [_crashesDir stringByAppendingPathComponent:BITHOCKEY_CRASH_ANALYZER];
    
    if ([_fileManager fileExistsAtPath:_analyzerInProgressFile]) {
      NSError *theError = nil;
      [_fileManager removeItemAtPath:_analyzerInProgressFile error:&theError];
    }
  }
  return self;
}

- (void)dealloc {
  _delegate = nil;

   _responseData = nil;

   _fileManager = nil;
  
   _crashFiles = nil;
   _settingsFile = nil;
   _analyzerInProgressFile = nil;
  
   _crashReportUI= nil;
  
   _approvedCrashReports = nil;
   _dictOfLastSessionCrash = nil;
  
}


#pragma mark - Private

- (void)saveSettings {  
  NSString *errorString = nil;
  
  NSMutableDictionary *rootObj = [NSMutableDictionary dictionaryWithCapacity:2];
  if (_approvedCrashReports && [_approvedCrashReports count] > 0)
    rootObj[kBITCrashApprovedReports] = _approvedCrashReports;
  
  NSData *plist = [NSPropertyListSerialization dataFromPropertyList:(id)rootObj
                                                             format:NSPropertyListBinaryFormat_v1_0
                                                   errorDescription:&errorString];
  if (plist) {
    [plist writeToFile:_settingsFile atomically:YES];
  } else {
    BITHockeyLog(@"ERROR: Writing settings. %@", errorString);
  }

}

- (void)loadSettings {
  NSString *errorString = nil;
  NSPropertyListFormat format;
  
  self.userName = bit_stringValueFromKeychainForKey([NSString stringWithFormat:@"default.%@", kBITCrashMetaUserName]);
  self.userEmail = bit_stringValueFromKeychainForKey([NSString stringWithFormat:@"default.%@", kBITCrashMetaUserEmail]);
  
  if (![_fileManager fileExistsAtPath:_settingsFile])
    return;
  
  NSData *plist = [NSData dataWithContentsOfFile:_settingsFile];
  if (plist) {
    NSDictionary *rootObj = (NSDictionary *)[NSPropertyListSerialization
                                             propertyListFromData:plist
                                             mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                             format:&format
                                             errorDescription:&errorString];
    
    if (rootObj[kBITCrashApprovedReports])
      [_approvedCrashReports setDictionary:rootObj[kBITCrashApprovedReports]];
  } else {
    BITHockeyLog(@"ERROR: Reading crash manager settings.");
  }
}

/**
 * Remove a cached crash report
 *
 *  @param filename The base filename of the crash report
 */
- (void)cleanCrashReportWithFilename:(NSString *)filename {
  if (!filename) return;
  
  NSError *error = NULL;
  
  [_fileManager removeItemAtPath:filename error:&error];
  [_fileManager removeItemAtPath:[filename stringByAppendingString:@".data"] error:&error];
  [_fileManager removeItemAtPath:[filename stringByAppendingString:@".meta"] error:&error];
  [_fileManager removeItemAtPath:[filename stringByAppendingString:@".desc"] error:&error];
  
  NSString *cacheFilename = [filename lastPathComponent];
  bit_removeKeyFromKeychain([NSString stringWithFormat:@"%@.%@", cacheFilename, kBITCrashMetaUserName]);
  bit_removeKeyFromKeychain([NSString stringWithFormat:@"%@.%@", cacheFilename, kBITCrashMetaUserEmail]);
  bit_removeKeyFromKeychain([NSString stringWithFormat:@"%@.%@", cacheFilename, kBITCrashMetaUserID]);
  
  [_crashFiles removeObject:filename];
  [_approvedCrashReports removeObjectForKey:filename];
  
  [self saveSettings];
}

/**
 *	 Remove all crash reports and stored meta data for each from the file system and keychain
 *
 * This is currently only used as a helper method for tests
 */
- (void)cleanCrashReports {
  for (NSUInteger i=0; i < [_crashFiles count]; i++) {
    [self cleanCrashReportWithFilename:_crashFiles[i]];
  }
}

- (void)persistAttachment:(BITHockeyAttachment *)attachment withFilename:(NSString *)filename {
  NSString *attachmentFilename = [filename stringByAppendingString:@".data"];
  NSMutableData *data = [[NSMutableData alloc] init];
  NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
  
  [archiver encodeObject:attachment forKey:kBITCrashMetaAttachment];
  
  [archiver finishEncoding];
  
  [data writeToFile:attachmentFilename atomically:YES];
}

- (void)persistUserProvidedMetaData:(BITCrashMetaData *)userProvidedMetaData {
  if (!userProvidedMetaData) return;
  
  if (userProvidedMetaData.userDescription && [userProvidedMetaData.userDescription length] > 0) {
    NSError *error;
    [userProvidedMetaData.userDescription writeToFile:[NSString stringWithFormat:@"%@.desc", [_crashesDir stringByAppendingPathComponent: _lastCrashFilename]] atomically:YES encoding:NSUTF8StringEncoding error:&error];
  }
  
  if (userProvidedMetaData.userName && [userProvidedMetaData.userName length] > 0) {
    bit_addStringValueToKeychain(userProvidedMetaData.userName, [NSString stringWithFormat:@"default.%@", kBITCrashMetaUserName]);
    bit_addStringValueToKeychain(userProvidedMetaData.userName, [NSString stringWithFormat:@"%@.%@", _lastCrashFilename, kBITCrashMetaUserName]);
  }
  
  if (userProvidedMetaData.userEmail && [userProvidedMetaData.userEmail length] > 0) {
    bit_addStringValueToKeychain(userProvidedMetaData.userEmail, [NSString stringWithFormat:@"default.%@", kBITCrashMetaUserEmail]);
    bit_addStringValueToKeychain(userProvidedMetaData.userEmail, [NSString stringWithFormat:@"%@.%@", _lastCrashFilename, kBITCrashMetaUserEmail]);
  }
  
  if (userProvidedMetaData.userID && [userProvidedMetaData.userID length] > 0) {
    bit_addStringValueToKeychain(userProvidedMetaData.userID, [NSString stringWithFormat:@"%@.%@", _lastCrashFilename, kBITCrashMetaUserID]);
  }
}

/**
 *  Read the attachment data from the stored file
 *
 *  @param filename The crash report file path
 *
 *  @return an BITCrashAttachment instance or nil
 */
- (BITHockeyAttachment *)attachmentForCrashReport:(NSString *)filename {
  NSString *attachmentFilename = [filename stringByAppendingString:@".data"];
  
  if (![_fileManager fileExistsAtPath:attachmentFilename])
    return nil;
  
  
  NSData *codedData = [[NSData alloc] initWithContentsOfFile:attachmentFilename];
  if (!codedData)
    return nil;
  
  NSKeyedUnarchiver *unarchiver = nil;
  
  @try {
    unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:codedData];
  }
  @catch (NSException *exception) {
    return nil;
  }
  
  if ([unarchiver containsValueForKey:kBITCrashMetaAttachment]) {
    BITHockeyAttachment *attachment = [unarchiver decodeObjectForKey:kBITCrashMetaAttachment];
    return attachment;
  }
  
  return nil;
}

- (NSString *)extractAppUUIDs:(BITPLCrashReport *)report {
  NSMutableString *uuidString = [NSMutableString string];
  NSArray *uuidArray = [BITCrashReportTextFormatter arrayOfAppUUIDsForCrashReport:report];
  
  for (NSDictionary *element in uuidArray) {
    if (element[kBITBinaryImageKeyUUID] && element[kBITBinaryImageKeyArch] && element[kBITBinaryImageKeyUUID]) {
      [uuidString appendFormat:@"<uuid type=\"%@\" arch=\"%@\">%@</uuid>",
       element[kBITBinaryImageKeyType],
       element[kBITBinaryImageKeyArch],
       element[kBITBinaryImageKeyUUID]
       ];
    }
  }
  
  return uuidString;
}

- (NSString *)userIDForCrashReport {
  NSString *userID = nil;
  
  if (self.userID)
    return self.userID;

  userID = bit_stringValueFromKeychainForKey(kBITDefaultUserID);

  if ([BITHockeyManager sharedHockeyManager].delegate &&
      [[BITHockeyManager sharedHockeyManager].delegate respondsToSelector:@selector(userIDForHockeyManager:componentManager:)]) {
    userID = [[BITHockeyManager sharedHockeyManager].delegate
              userIDForHockeyManager:[BITHockeyManager sharedHockeyManager]
              componentManager:self];
  }
  
  return userID ?: @"";
}

- (NSString *)userNameForCrashReport {
  NSString *userName = nil;
  
  if (self.userName)
    return self.userName;
  
  userName = bit_stringValueFromKeychainForKey(kBITDefaultUserName);

  if ([BITHockeyManager sharedHockeyManager].delegate &&
      [[BITHockeyManager sharedHockeyManager].delegate respondsToSelector:@selector(userNameForHockeyManager:componentManager:)]) {
    userName = [[BITHockeyManager sharedHockeyManager].delegate
                userNameForHockeyManager:[BITHockeyManager sharedHockeyManager]
                componentManager:self];
  }
  
  return userName ?: @"";
}

- (NSString *)userEmailForCrashReport {
  NSString *userEmail = nil;
  
  if (self.userEmail)
    return self.userEmail;
  
  userEmail = bit_stringValueFromKeychainForKey(kBITDefaultUserEmail);

  if ([BITHockeyManager sharedHockeyManager].delegate &&
      [[BITHockeyManager sharedHockeyManager].delegate respondsToSelector:@selector(userEmailForHockeyManager:componentManager:)]) {
    userEmail = [[BITHockeyManager sharedHockeyManager].delegate
                 userEmailForHockeyManager:[BITHockeyManager sharedHockeyManager]
                 componentManager:self];
  }
  
  return userEmail ?: @"";
}


#pragma mark - Public

/**
 *  Set the callback for PLCrashReporter
 *
 *  @param callbacks BITCrashManagerCallbacks instance
 */
- (void)setCrashCallbacks: (BITCrashManagerCallbacks *) callbacks {
  if (!callbacks) return;
  
  // set our proxy callback struct
  bitCrashCallbacks.context = callbacks->context;
  bitCrashCallbacks.handleSignal = callbacks->handleSignal;
  
  // set the PLCrashReporterCallbacks struct
  plCrashCallbacks.context = callbacks->context;
  
  _crashCallBacks = &plCrashCallbacks;
}

- (void)setCrashReportUIHandler:(BITCustomCrashReportUIHandler)crashReportUIHandler {
  _crashReportUIHandler = crashReportUIHandler;
}

/**
 * Check if the debugger is attached
 *
 * Taken from https://github.com/plausiblelabs/plcrashreporter/blob/2dd862ce049e6f43feb355308dfc710f3af54c4d/Source/Crash%20Demo/main.m#L96
 *
 * @return `YES` if the debugger is attached to the current process, `NO` otherwise
 */
- (BOOL)isDebuggerAttached {
  static BOOL debuggerIsAttached = NO;
  static BOOL debuggerIsChecked = NO;
  if (debuggerIsChecked) return debuggerIsAttached;

  struct kinfo_proc info;
  size_t info_size = sizeof(info);
  int name[4];
  
  name[0] = CTL_KERN;
  name[1] = KERN_PROC;
  name[2] = KERN_PROC_PID;
  name[3] = getpid();
  
  if (sysctl(name, 4, &info, &info_size, NULL, 0) == -1) {
    NSLog(@"[HockeySDK] ERROR: Checking for a running debugger via sysctl() failed: %s", strerror(errno));
    debuggerIsAttached = false;
  }
  
  if (!debuggerIsAttached && (info.kp_proc.p_flag & P_TRACED) != 0)
    debuggerIsAttached = true;

  debuggerIsChecked = YES;
  
  return debuggerIsAttached;
}


- (void)generateTestCrash {
  if ([self isDebuggerAttached]) {
    NSLog(@"[HockeySDK] WARNING: The debugger is attached. The following crash cannot be detected by the SDK!");
  }
  
  __builtin_trap();
}

/**
 *  Write a meta file for a new crash report
 *
 *  @param filename the crash reports temp filename
 */
- (void)storeMetaDataForCrashReportFilename:(NSString *)filename {
  NSError *error = NULL;
  NSMutableDictionary *metaDict = [NSMutableDictionary dictionaryWithCapacity:4];
  NSString *applicationLog = @"";
  NSString *errorString = nil;
  
  bit_addStringValueToKeychain([self userNameForCrashReport], [NSString stringWithFormat:@"%@.%@", filename, kBITCrashMetaUserName]);
  bit_addStringValueToKeychain([self userEmailForCrashReport], [NSString stringWithFormat:@"%@.%@", filename, kBITCrashMetaUserEmail]);
  bit_addStringValueToKeychain([self userIDForCrashReport], [NSString stringWithFormat:@"%@.%@", filename, kBITCrashMetaUserID]);
  
  if (self.delegate != nil && [self.delegate respondsToSelector:@selector(applicationLogForCrashManager:)]) {
    applicationLog = [self.delegate applicationLogForCrashManager:self] ?: @"";
  }
  _dictOfLastSessionCrash[kBITCrashMetaApplicationLog] = applicationLog;
  metaDict[kBITCrashMetaApplicationLog] = applicationLog;
  
  if (self.delegate != nil && [self.delegate respondsToSelector:@selector(attachmentForCrashManager:)]) {
    BITHockeyAttachment *attachment = [self.delegate attachmentForCrashManager:self];
    
    if (attachment) {
      [self persistAttachment:attachment withFilename:[_crashesDir stringByAppendingPathComponent: filename]];
    }
  }
  
  NSData *plist = [NSPropertyListSerialization dataFromPropertyList:(id)metaDict
                                                             format:NSPropertyListBinaryFormat_v1_0
                                                   errorDescription:&errorString];
  if (plist) {
    [plist writeToFile:[_crashesDir stringByAppendingPathComponent: [filename stringByAppendingPathExtension:@"meta"]] atomically:YES];
  } else {
    BITHockeyLog(@"ERROR: Writing crash meta data failed. %@", error);
  }
}

- (BOOL)handleUserInput:(BITCrashManagerUserInput)userInput withUserProvidedMetaData:(BITCrashMetaData *)userProvidedMetaData {
  switch (userInput) {
    case BITCrashManagerUserInputDontSend:
      if (self.delegate != nil && [self.delegate respondsToSelector:@selector(crashManagerWillCancelSendingCrashReport:)]) {
        [self.delegate crashManagerWillCancelSendingCrashReport:self];
      }
      
      if (_lastCrashFilename)
        [self cleanCrashReportWithFilename:[_crashesDir stringByAppendingPathComponent: _lastCrashFilename]];
      
      return YES;
      
    case BITCrashManagerUserInputSend:
      if (userProvidedMetaData)
        [self persistUserProvidedMetaData:userProvidedMetaData];
      
      [self sendNextCrashReport];
      return YES;
      
    case BITCrashManagerUserInputAlwaysSend:
      self.autoSubmitCrashReport = YES;
      
      if (userProvidedMetaData)
        [self persistUserProvidedMetaData:userProvidedMetaData];
      
      [self sendNextCrashReport];
      return YES;
      
    default:
      return NO;
  }
  
}


#pragma mark - BITPLCrashReporter

// Called to handle a pending crash report.
- (void)handleCrashReport {
  NSError *error = NULL;
	
  // check if the next call ran successfully the last time
  if (![_fileManager fileExistsAtPath:_analyzerInProgressFile]) {
    // mark the start of the routine
    [_fileManager createFileAtPath:_analyzerInProgressFile contents:nil attributes:nil];

    [self saveSettings];
    
    // Try loading the crash report
    NSData *crashData = [[NSData alloc] initWithData:[_plCrashReporter loadPendingCrashReportDataAndReturnError: &error]];
    
    NSString *cacheFilename = [NSString stringWithFormat: @"%.0f", [NSDate timeIntervalSinceReferenceDate]];
    _lastCrashFilename = [cacheFilename copy];

    if (crashData == nil) {
      BITHockeyLog(@"Warning: Could not load crash report: %@", error);
    } else {
      // get the startup timestamp from the crash report, and the file timestamp to calculate the timeinterval when the crash happened after startup
      BITPLCrashReport *report = [[BITPLCrashReport alloc] initWithData:crashData error:&error];

      if (report == nil) {
        BITHockeyLog(@"WARNING: Could not parse crash report");
      } else {
        NSDate *appStartTime = nil;
        NSDate *appCrashTime = nil;
        if ([report.processInfo respondsToSelector:@selector(processStartTime)]) {
          if (report.systemInfo.timestamp && report.processInfo.processStartTime) {
            appStartTime = report.processInfo.processStartTime;
            appCrashTime =report.systemInfo.timestamp;
            _timeintervalCrashInLastSessionOccured = [report.systemInfo.timestamp timeIntervalSinceDate:report.processInfo.processStartTime];
          }
        }

        [crashData writeToFile:[_crashesDir stringByAppendingPathComponent: cacheFilename] atomically:YES];
        
        [self storeMetaDataForCrashReportFilename:cacheFilename];
        
        NSString *incidentIdentifier = @"???";
        if (report.uuidRef != NULL) {
          incidentIdentifier = (NSString *) CFBridgingRelease(CFUUIDCreateString(NULL, report.uuidRef));
        }
        
        NSString *reporterKey = [BITSystemProfile deviceIdentifier] ?: @"";
        
        _lastSessionCrashDetails = [[BITCrashDetails alloc] initWithIncidentIdentifier:incidentIdentifier
                                                                           reporterKey:reporterKey
                                                                                signal:report.signalInfo.name
                                                                         exceptionName:report.exceptionInfo.exceptionName
                                                                       exceptionReason:report.exceptionInfo.exceptionReason
                                                                          appStartTime:appStartTime
                                                                             crashTime:appCrashTime
                                                                             osVersion:report.systemInfo.operatingSystemVersion
                                                                               osBuild:report.systemInfo.operatingSystemBuild
                                                                              appBuild:report.applicationInfo.applicationVersion
                                    ];
      }
    }
  }
	
  // Purge the report
  // mark the end of the routine
  if ([_fileManager fileExistsAtPath:_analyzerInProgressFile]) {
    [_fileManager removeItemAtPath:_analyzerInProgressFile error:&error];
  }
  
  [self saveSettings];
  
  [_plCrashReporter purgePendingCrashReport];
}

/**
 Get the filename of the first not approved crash report
 
 @return NSString Filename of the first found not approved crash report
 */
- (NSString *)firstNotApprovedCrashReport {
  if ((!_approvedCrashReports || [_approvedCrashReports count] == 0) && [_crashFiles count] > 0) {
    return _crashFiles[0];
  }
  
  for (NSUInteger i=0; i < [_crashFiles count]; i++) {
    NSString *filename = _crashFiles[i];
    
    if (!_approvedCrashReports[filename]) return filename;
  }
  
  return nil;
}

/**
 Check if there are any new crash reports that are not yet processed
 
 @return	`YES` if there is at least one new crash report found, `NO` otherwise
 */
- (BOOL)hasPendingCrashReport {
  if (!_crashManagerActivated) return NO;
    
  if ([_fileManager fileExistsAtPath: _crashesDir]) {
    NSString *file = nil;
    NSError *error = NULL;
    
    NSDirectoryEnumerator *dirEnum = [_fileManager enumeratorAtPath: _crashesDir];
    
    while ((file = [dirEnum nextObject])) {
      NSDictionary *fileAttributes = [_fileManager attributesOfItemAtPath:[_crashesDir stringByAppendingPathComponent:file] error:&error];
      if ([fileAttributes[NSFileSize] intValue] > 0 &&
          ![file hasSuffix:@".DS_Store"] &&
          ![file hasSuffix:@".analyzer"] &&
          ![file hasSuffix:@".plist"] &&
          ![file hasSuffix:@".data"] &&
          ![file hasSuffix:@".meta"] &&
          ![file hasSuffix:@".desc"]) {
        [_crashFiles addObject:[_crashesDir stringByAppendingPathComponent: file]];
      }
    }
  }
  
  if ([_crashFiles count] > 0) {
    BITHockeyLog(@"INFO: %li pending crash reports found.", (unsigned long)[_crashFiles count]);
    return YES;
  } else {
    if (_didCrashInLastSession) {
      if (self.delegate != nil && [self.delegate respondsToSelector:@selector(crashManagerWillCancelSendingCrashReport:)]) {
        [self.delegate crashManagerWillCancelSendingCrashReport:self];
      }
      
      _didCrashInLastSession = NO;
    }
    
    return NO;
  }
}


#pragma mark - Crash Report Processing

- (void)invokeProcessing {
  BITHockeyLog(@"INFO: Start CrashManager processing");
  
  if (!_sendingInProgress && [self hasPendingCrashReport]) {
    _sendingInProgress = YES;
    BITHockeyLog(@"INFO: Pending crash reports found.");

    NSString *notApprovedReportFilename = [self firstNotApprovedCrashReport];
    if (!self.autoSubmitCrashReport && notApprovedReportFilename) {
      NSError* error = nil;
      NSString *crashReport = nil;
      
      // this can happen in case there is a non approved crash report but it didn't happen in the previous app session
      if (!_lastCrashFilename) {
        _lastCrashFilename = [[notApprovedReportFilename lastPathComponent] copy];
      }
      
      NSData *crashData = [NSData dataWithContentsOfFile: [_crashesDir stringByAppendingPathComponent:_lastCrashFilename]];
      BITPLCrashReport *report = [[BITPLCrashReport alloc] initWithData:crashData error:&error];
      NSString *installString = [BITSystemProfile deviceIdentifier] ?: @"";
      crashReport = [BITCrashReportTextFormatter stringValueForCrashReport:report crashReporterKey:installString];
      
      if (crashReport && !error) {
        NSString *log = [_dictOfLastSessionCrash valueForKey:kBITCrashMetaApplicationLog] ?: @"";
        
        if (self.delegate != nil && [self.delegate respondsToSelector:@selector(crashManagerWillShowSubmitCrashReportAlert:)]) {
          [self.delegate crashManagerWillShowSubmitCrashReportAlert:self];
        }
        
        if (_crashReportUIHandler) {
          _crashReportUIHandler(crashReport, log);
        } else {
          _crashReportUI = [[BITCrashReportUI alloc] initWithManager:self
                                                         crashReport:crashReport
                                                          logContent:log
                                                     applicationName:[self applicationName]
                                                      askUserDetails:_askUserDetails];
          
          [_crashReportUI setUserName:[self userNameForCrashReport]];
          [_crashReportUI setUserEmail:[self userEmailForCrashReport]];
          
          if (_crashReportUI.nibDidLoadSuccessfully) {
            [_crashReportUI askCrashReportDetails];
            [_crashReportUI showWindow:self];
            [_crashReportUI.window makeKeyAndOrderFront:self];
            if (self.submitModally) {
              [_crashReportUI runModally];
            }
          } else {
            [self sendNextCrashReport];
          }
        }
      } else {
        [self cleanCrashReportWithFilename:_lastCrashFilename];
      }
    } else {
      [self sendNextCrashReport];
    }
  }
  
  [self performSelector:@selector(invokeDelayedProcessing) withObject:nil afterDelay:0.5];
}

- (void)startManager {
  if (!_crashManagerActivated) {
    return;
  }
  
  BITHockeyLog(@"INFO: Start CrashManager startManager");
  
  [self loadSettings];
  
  if (!_plCrashReporter) {
    /* Configure our reporter */
    
    PLCrashReporterSignalHandlerType signalHandlerType = PLCrashReporterSignalHandlerTypeMach;
    if (self.isMachExceptionHandlerDisabled) {
      signalHandlerType = PLCrashReporterSignalHandlerTypeBSD;
    }
    BITPLCrashReporterConfig *config = [[BITPLCrashReporterConfig alloc] initWithSignalHandlerType: signalHandlerType
                                                                             symbolicationStrategy: PLCrashReporterSymbolicationStrategySymbolTable];
    _plCrashReporter = [[BITPLCrashReporter alloc] initWithConfiguration: config];
    NSError *error = NULL;
    
    // Check if we previously crashed
    if ([_plCrashReporter hasPendingCrashReport]) {
      _didCrashInLastSession = YES;
      [self handleCrashReport];
    }
    
    // The actual signal and mach handlers are only registered when invoking `enableCrashReporterAndReturnError`
    // So it is safe enough to only disable the following part when a debugger is attached no matter which
    // signal handler type is set
    if (![self isDebuggerAttached]) {
      // Multiple exception handlers can be set, but we can only query the top level error handler (uncaught exception handler).
      //
      // To check if PLCrashReporter's error handler is successfully added, we compare the top
      // level one that is set before and the one after PLCrashReporter sets up its own.
      //
      // With delayed processing we can then check if another error handler was set up afterwards
      // and can show a debug warning log message, that the dev has to make sure the "newer" error handler
      // doesn't exit the process itself, because then all subsequent handlers would never be invoked.
      //
      // Note: ANY error handler setup BEFORE HockeySDK initialization will not be processed!
      
      // get the current top level error handler
      NSUncaughtExceptionHandler *initialHandler = NSGetUncaughtExceptionHandler();
      
      // set any user defined callbacks, hopefully the users knows what they do
      if (_crashCallBacks) {
        [_plCrashReporter setCrashCallbacks:_crashCallBacks];
      }
      
      // Enable the Crash Reporter
      BOOL crashReporterEnabled = [_plCrashReporter enableCrashReporterAndReturnError:&error];
      if (!crashReporterEnabled)
        NSLog(@"[HockeySDK] WARNING: Could not enable crash reporter: %@", error);
      
      // get the new current top level error handler, which should now be the one from PLCrashReporter
      NSUncaughtExceptionHandler *currentHandler = NSGetUncaughtExceptionHandler();
      
      // do we have a new top level error handler? then we were successful
      if (currentHandler && currentHandler != initialHandler) {
        self.plcrExceptionHandler = currentHandler;
        
        BITHockeyLog(@"INFO: Exception handler successfully initialized.");
      } else {
        // this should never happen, theoretically only if NSSetUncaugtExceptionHandler() has some internal issues
        NSLog(@"[HockeySDK] ERROR: Exception handler could not be set. Make sure there is no other exception handler set up!");
      }
    } else {
      NSLog(@"[HockeySDK] WARNING: Detecting crashes is NOT enabled due to running the app with a debugger attached.");
    }
  }
  
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  if (self.delegate != nil && [self.delegate respondsToSelector:@selector(showMainApplicationWindowForCrashManager:)]) {
    [self.delegate showMainApplicationWindowForCrashManager:self];
  }
#pragma clang diagnostic pop

  [self invokeProcessing];
}

// slightly delayed startup processing, so we don't keep the first runloop on startup busy for too long
- (void)invokeDelayedProcessing {
  BITHockeyLog(@"INFO: Start delayed CrashManager processing");
  
  // was our own exception handler successfully added?
  if (self.plcrExceptionHandler) {
    // get the current top level error handler
    NSUncaughtExceptionHandler *currentHandler = NSGetUncaughtExceptionHandler();
    
    // If the top level error handler differs from our own, then at least another one was added.
    // This could cause exception crashes not to be reported to HockeyApp. See log message for details.
    if (self.plcrExceptionHandler != currentHandler) {
      BITHockeyLog(@"[HockeySDK] WARNING: Another exception handler was added. If this invokes any kind exit() after processing the exception, which causes any subsequent error handler not to be invoked, these crashes will NOT be reported to HockeyApp!");
    }
  }
}


/**
 *	 Send all approved crash reports
 *
 * Gathers all collected data and constructs the XML structure and starts the sending process
 */
- (void)sendNextCrashReport {
  NSError *error = NULL;
  
  _crashIdenticalCurrentVersion = NO;
  
  if ([_crashFiles count] == 0)
    return;

  NSString *crashXML = nil;
  BITHockeyAttachment *attachment = nil;
  
  NSString *filename = _crashFiles[0];
  NSData *crashData = [NSData dataWithContentsOfFile:filename];
  if ([crashData length] > 0) {
    BITPLCrashReport *report = nil;
    NSString *crashUUID = @"";
    NSString *installString = nil;
    NSString *crashLogString = nil;
    NSString *appBundleIdentifier = nil;
    NSString *appBundleVersion = nil;
    NSString *osVersion = nil;
    NSString *deviceModel = nil;
    NSString *appBinaryUUIDs = nil;
    NSString *metaFilename = nil;
    
    NSString *errorString = nil;
    NSPropertyListFormat format;

    report = [[BITPLCrashReport alloc] initWithData:crashData error:&error];
    if (report == nil) {
      BITHockeyLog(@"WARNING: Could not parse crash report");
      // we cannot do anything with this report, so delete it
      [self cleanCrashReportWithFilename:filename];
      // we don't continue with the next report here, even if there are to prevent calling sendCrashReports from itself again
      // the next crash will be automatically send on the next app start/becoming active event
      return;
    }
    
    installString = [BITSystemProfile deviceIdentifier] ?: @"";
    
    if (report.uuidRef != NULL) {
      crashUUID = (NSString *) CFBridgingRelease(CFUUIDCreateString(NULL, report.uuidRef));
    }
    metaFilename = [filename stringByAppendingPathExtension:@"meta"];
    crashLogString = [BITCrashReportTextFormatter stringValueForCrashReport:report crashReporterKey:installString];
    appBundleIdentifier = report.applicationInfo.applicationIdentifier;
    appBundleVersion = report.applicationInfo.applicationVersion;
    osVersion = report.systemInfo.operatingSystemVersion;
    deviceModel = [BITSystemProfile deviceModel];
    appBinaryUUIDs = [self extractAppUUIDs:report];
    if ([report.applicationInfo.applicationVersion compare:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]] == NSOrderedSame) {
      _crashIdenticalCurrentVersion = YES;
    }

    NSString *username = @"";
    NSString *useremail = @"";
    NSString *userid = @"";
    NSString *applicationLog = @"";
    NSString *description = @"";
    
    NSData *plist = [NSData dataWithContentsOfFile:metaFilename];
    if (plist) {
      NSDictionary *metaDict = (NSDictionary *)[NSPropertyListSerialization
                                                propertyListFromData:plist
                                                mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                                format:&format
                                                errorDescription:&errorString];
      
      username = bit_stringValueFromKeychainForKey([NSString stringWithFormat:@"%@.%@", [filename lastPathComponent], kBITCrashMetaUserName]) ?: @"";
      useremail = bit_stringValueFromKeychainForKey([NSString stringWithFormat:@"%@.%@", [filename lastPathComponent], kBITCrashMetaUserEmail]) ?: @"";
      userid = bit_stringValueFromKeychainForKey([NSString stringWithFormat:@"%@.%@", [filename lastPathComponent], kBITCrashMetaUserID]) ?: @"";
      applicationLog = metaDict[kBITCrashMetaApplicationLog] ?: @"";
      description = metaDict[kBITCrashMetaDescription] ?: @"";
      attachment = [self attachmentForCrashReport:filename];
    } else {
      BITHockeyLog(@"ERROR: Reading crash meta data. %@", error);
    }

    NSString *descriptionMetaFilePath = [filename stringByAppendingPathExtension:@"desc"];
    if ([_fileManager fileExistsAtPath:descriptionMetaFilePath]) {
      description = [NSString stringWithContentsOfFile:descriptionMetaFilePath encoding:NSUTF8StringEncoding error:&error] ?: @"";
    }
    
    if ([applicationLog length] > 0) {
      if ([description length] > 0) {
        description = [NSString stringWithFormat:@"%@\n\nLog:\n%@", description, applicationLog];
      } else {
        description = [NSString stringWithFormat:@"Log:\n%@", applicationLog];
      }
    }
    
    crashXML = [NSString stringWithFormat:@"<crashes><crash><applicationname>%s</applicationname><uuids>%@</uuids><bundleidentifier>%@</bundleidentifier><systemversion>%@</systemversion><platform>%@</platform><senderversion>%@</senderversion><version>%@</version><uuid>%@</uuid><log><![CDATA[%@]]></log><userid>%@</userid><username>%@</username><contact>%@</contact><installstring>%@</installstring><description><![CDATA[%@]]></description></crash></crashes>",
                [[self applicationName] UTF8String],
                appBinaryUUIDs,
                appBundleIdentifier,
                osVersion,
                deviceModel,
                [self applicationVersion],
                appBundleVersion,
                crashUUID,
                [crashLogString stringByReplacingOccurrencesOfString:@"]]>" withString:@"]]" @"]]><![CDATA[" @">" options:NSLiteralSearch range:NSMakeRange(0,crashLogString.length)],
                userid,
                username,
                useremail,
                installString,
                [description stringByReplacingOccurrencesOfString:@"]]>" withString:@"]]" @"]]><![CDATA[" @">" options:NSLiteralSearch range:NSMakeRange(0,description.length)]];
    
    // store this crash report as user approved, so if it fails it will retry automatically
    _approvedCrashReports[filename] = @YES;
    
    [self saveSettings];
    
    BITHockeyLog(@"INFO: Sending crash reports:\n%@", crashXML);
    [self sendCrashReportWithFilename:filename xml:crashXML attachment:attachment];
  } else {
    // we cannot do anything with this report, so delete it
    [self cleanCrashReportWithFilename:filename];
  }
}


#pragma mark - Networking

- (NSURLRequest *)requestWithXML:(NSString*)xml attachment:(BITHockeyAttachment *)attachment {
  NSString *postCrashPath = [NSString stringWithFormat:@"api/2/apps/%@/crashes", self.encodedAppIdentifier];
  
  NSMutableURLRequest *request = [self.hockeyAppClient requestWithMethod:@"POST"
                                                                    path:postCrashPath
                                                              parameters:nil];
  
  [request setCachePolicy: NSURLRequestReloadIgnoringLocalCacheData];
  [request setValue:@"HockeySDK/iOS" forHTTPHeaderField:@"User-Agent"];
  [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
  
  NSString *boundary = @"----FOO";
  NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
  [request setValue:contentType forHTTPHeaderField:@"Content-type"];
	
  NSMutableData *postBody =  [NSMutableData data];
  
  [postBody appendData:[BITHockeyAppClient dataWithPostValue:BITHOCKEY_NAME
                                                      forKey:@"sdk"
                                                    boundary:boundary]];
  
  [postBody appendData:[BITHockeyAppClient dataWithPostValue:BITHOCKEY_VERSION
                                                      forKey:@"sdk_version"
                                                    boundary:boundary]];
  
  [postBody appendData:[BITHockeyAppClient dataWithPostValue:@"no"
                                                      forKey:@"feedbackEnabled"
                                                    boundary:boundary]];
  
  [postBody appendData:[BITHockeyAppClient dataWithPostValue:[xml dataUsingEncoding:NSUTF8StringEncoding]
                                                      forKey:@"xml"
                                                 contentType:@"text/xml"
                                                    boundary:boundary
                                                    filename:@"crash.xml"]];
  
  if (attachment && attachment.hockeyAttachmentData) {
    NSString *attachmentFilename = attachment.filename;
    if (!attachmentFilename) {
      attachmentFilename = @"Attachment_0";
    }
    [postBody appendData:[BITHockeyAppClient dataWithPostValue:attachment.hockeyAttachmentData
                                                        forKey:@"attachment0"
                                                   contentType:attachment.contentType
                                                      boundary:boundary
                                                      filename:attachmentFilename]];
  }
  
  [postBody appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
  
  [request setHTTPBody:postBody];
  
  return request;
}

/**
 *	 Send the XML data to the server
 *
 * Wraps the XML structure into a POST body and starts sending the data asynchronously
 *
 *	@param	xml	The XML data that needs to be send to the server
 */
- (void)sendCrashReportWithFilename:(NSString *)filename xml:(NSString*)xml attachment:(BITHockeyAttachment *)attachment {
  NSURLRequest* request = [self requestWithXML:xml attachment:attachment];
  
  __unsafe_unretained typeof(self) weakSelf = self;
  BITHTTPOperation *operation = [self.hockeyAppClient
                                 operationWithURLRequest:request
                                 completion:^(BITHTTPOperation *operation, NSData* responseData, NSError *error) {
                                   typeof (self) strongSelf = weakSelf;
                                   
                                   _sendingInProgress = NO;
                                   
                                   NSInteger statusCode = [operation.response statusCode];
                                   
                                   if (nil == error) {
                                     if (nil == responseData || [responseData length] == 0) {
                                       error = [NSError errorWithDomain:kBITCrashErrorDomain
                                                                   code:BITCrashAPIReceivedEmptyResponse
                                                               userInfo:@{
                                                                          NSLocalizedDescriptionKey: @"Sending failed with an empty response!"
                                                                          }
                                                ];
                                     } else if (statusCode >= 200 && statusCode < 400) {
                                       [strongSelf cleanCrashReportWithFilename:filename];
                                       
                                       // HockeyApp uses PList XML format
                                       NSMutableDictionary *response = [NSPropertyListSerialization propertyListFromData:responseData
                                                                                                        mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                                                                                                  format:nil
                                                                                                        errorDescription:NULL];
                                       BITHockeyLog(@"INFO: Received API response: %@", response);
                                       
                                       if (strongSelf.delegate != nil &&
                                           [strongSelf.delegate respondsToSelector:@selector(crashManagerDidFinishSendingCrashReport:)]) {
                                         [strongSelf.delegate crashManagerDidFinishSendingCrashReport:self];
                                       }
                                       
                                       // only if sending the crash report went successfully, continue with the next one (if there are more)
                                       [strongSelf performSelector:@selector(sendNextCrashReport) withObject:nil afterDelay:2];
                                     } else if (statusCode == 400) {
                                       [strongSelf cleanCrashReportWithFilename:filename];
                                       
                                       error = [NSError errorWithDomain:kBITCrashErrorDomain
                                                                   code:BITCrashAPIAppVersionRejected
                                                               userInfo:@{
                                                                          NSLocalizedDescriptionKey: @"The server rejected receiving crash reports for this app version!"
                                                                          }
                                                ];
                                     } else {
                                       error = [NSError errorWithDomain:kBITCrashErrorDomain
                                                                   code:BITCrashAPIErrorWithStatusCode
                                                               userInfo:@{
                                                                          NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Sending failed with status code: %li", (long)statusCode]
                                                                          }
                                                ];
                                     }
                                   }
                                   
                                   if (error) {
                                     if (strongSelf.delegate != nil &&
                                         [strongSelf.delegate respondsToSelector:@selector(crashManager:didFailWithError:)]) {
                                       [strongSelf.delegate crashManager:self didFailWithError:error];
                                     }
                                     
                                     BITHockeyLog(@"ERROR: %@", [error localizedDescription]);
                                   }
                                   
                                 }];
  
  if (self.delegate != nil && [self.delegate respondsToSelector:@selector(crashManagerWillSendCrashReport:)]) {
    [self.delegate crashManagerWillSendCrashReport:self];
  }
  
  BITHockeyLog(@"INFO: Sending crash reports started.");
  
  [self.hockeyAppClient enqeueHTTPOperation:operation];
}


#pragma mark - GetterSetter

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
