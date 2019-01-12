#import "HockeySDK.h"
#import "HockeySDKPrivate.h"

#import "BITCrashReportUI.h"

#import "BITHockeyBaseManagerPrivate.h"
#import "BITCrashManagerPrivate.h"
#import "BITHockeyAttachment.h"
#import "BITCrashDetails.h"
#import "BITCrashDetailsPrivate.h"
#import "BITCrashMetaData.h"
#import "BITCrashCXXExceptionHandler.h"
#import "BITCrashReportTextFormatter.h"

#import "BITHockeyHelper.h"
#import "BITHockeyAppClient.h"

#import <sys/sysctl.h>
#import <objc/runtime.h>

// stores the set of crashreports that have been approved but aren't sent yet
#define kBITCrashApprovedReports @"HockeySDKCrashApprovedReports"

// keys for meta information associated to each crash
#define kBITCrashMetaUserName @"BITCrashMetaUserName"
#define kBITCrashMetaUserEmail @"BITCrashMetaUserEmail"
#define kBITCrashMetaUserID @"BITCrashMetaUserID"
#define kBITCrashMetaApplicationLog @"BITCrashMetaApplicationLog"
#define kBITCrashMetaDescription @"BITCrashMetaDescription"
#define kBITCrashMetaAttachment @"BITCrashMetaAttachment"

static NSString *const kHockeyErrorDomain = @"HockeyErrorDomain";


static BITCrashManagerCallbacks bitCrashCallbacks = {
  .context = NULL,
  .handleSignal = NULL
};

// proxy implementation for PLCrashReporter to keep our interface stable while this can change
static void plcr_post_crash_callback (siginfo_t * __unused info, ucontext_t * __unused uap, void *context) {
  if (bitCrashCallbacks.handleSignal != NULL)
    bitCrashCallbacks.handleSignal(context);
}

static PLCrashReporterCallbacks plCrashCallbacks = {
  .version = 0,
  .context = NULL,
  .handleSignal = plcr_post_crash_callback
};


// Temporary class until PLCR catches up
// We trick PLCR with an Objective-C exception.
//
// This code provides us access to the C++ exception message and stack trace.
//
@interface BITCrashCXXExceptionWrapperException : NSException

- (instancetype)initWithCXXExceptionInfo:(const BITCrashUncaughtCXXExceptionInfo *)info;

@property (nonatomic, readonly) const BITCrashUncaughtCXXExceptionInfo *info;

@end

@implementation BITCrashCXXExceptionWrapperException

- (instancetype)initWithCXXExceptionInfo:(const BITCrashUncaughtCXXExceptionInfo *)info {
  extern char* __cxa_demangle(const char* mangled_name, char* output_buffer, size_t* length, int* status);
  char *demangled_name = &__cxa_demangle ? __cxa_demangle(info->exception_type_name ?: "", NULL, NULL, NULL) : NULL;
  
  if ((self = [super
               initWithName:(NSString *)[NSString stringWithUTF8String:demangled_name ?: info->exception_type_name ?: ""]
               reason:[NSString stringWithUTF8String:info->exception_message ?: ""]
               userInfo:nil])) {
    _info = info;
  }
  return self;
}

- (NSArray *)callStackReturnAddresses {
  NSMutableArray *cxxFrames = [NSMutableArray arrayWithCapacity:self.info->exception_frames_count];
  
  for (uint32_t i = 0; i < self.info->exception_frames_count; ++i) {
    [cxxFrames addObject:[NSNumber numberWithUnsignedLongLong:self.info->exception_frames[i]]];
  }
  return cxxFrames;
}

@end


// C++ Exception Handler
__attribute__((noreturn)) static void uncaught_cxx_exception_handler(const BITCrashUncaughtCXXExceptionInfo *info) {
  // This relies on a LOT of sneaky internal knowledge of how PLCR works and should not be considered a long-term solution.
  NSGetUncaughtExceptionHandler()([[BITCrashCXXExceptionWrapperException alloc] initWithCXXExceptionInfo:info]);
  abort();
}


@interface BITCrashManager ()
@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic) BOOL sendingInProgress;
@property (nonatomic) BOOL crashIdenticalCurrentVersion;

@property (nonatomic, strong) NSMutableArray *crashFiles;
@property (nonatomic, copy) NSString       *settingsFile;
@property (nonatomic, copy) NSString       *analyzerInProgressFile;

@property (nonatomic, strong) BITPLCrashReporter *plCrashReporter;
@property (nonatomic, strong) BITCrashReportUI *crashReportUI;

@property (nonatomic, strong) NSMutableDictionary *approvedCrashReports;
@property (nonatomic, strong) NSMutableDictionary *dictOfLastSessionCrash;

// Redeclare BITCrashManager properties with readwrite attribute
@property (nonatomic, readwrite) NSTimeInterval timeintervalCrashInLastSessionOccured;
@property (nonatomic, readwrite) BITCrashDetails *lastSessionCrashDetails;
@property (nonatomic, readwrite) BOOL didCrashInLastSession;
@end

@implementation BITCrashManager

#pragma mark - Init

- (instancetype)initWithAppIdentifier:(NSString *)appIdentifier hockeyAppClient:(BITHockeyAppClient *)hockeyAppClient {
  if ((self = [super initWithAppIdentifier:appIdentifier])) {
    self.crashReportUI = nil;
    self.fileManager = [[NSFileManager alloc] init];
    _askUserDetails = YES;
    
    _plcrExceptionHandler = nil;
    _crashCallBacks = nil;
    _crashIdenticalCurrentVersion = YES;
    
    _timeintervalCrashInLastSessionOccured = -1;
    
    _approvedCrashReports = [[NSMutableDictionary alloc] init];
    _dictOfLastSessionCrash = [[NSMutableDictionary alloc] init];
    _didCrashInLastSession = NO;
    
    self.crashFiles = [[NSMutableArray alloc] init];
    self.crashesDir = nil;
    
    _delegate = nil;
    _hockeyAppClient = hockeyAppClient;
    
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
    
    self.crashesDir = bit_settingsDir();
    _settingsFile = [self.crashesDir stringByAppendingPathComponent:BITHOCKEY_CRASH_SETTINGS];
    _analyzerInProgressFile = [self.crashesDir stringByAppendingPathComponent:BITHOCKEY_CRASH_ANALYZER];
    
  }
  return self;
}

- (void)dealloc {
  _delegate = nil;
  
  self.fileManager = nil;
  
  self.crashFiles = nil;
  _settingsFile = nil;
  _analyzerInProgressFile = nil;
  
  self.crashReportUI= nil;
  
  _approvedCrashReports = nil;
  _dictOfLastSessionCrash = nil;
  
}

- (void)setServerURL:(NSString *)serverURL {
  if ([serverURL isEqualToString:super.serverURL]) { return; }
  
  super.serverURL = serverURL;
  self.hockeyAppClient = [[BITHockeyAppClient alloc] initWithBaseURL:[NSURL URLWithString:serverURL]];
}

#pragma mark - Private

- (void)saveSettings {  
  NSString *errorString = nil;
  
  NSMutableDictionary *rootObj = [NSMutableDictionary dictionaryWithCapacity:2];
  if (self.approvedCrashReports && [self.approvedCrashReports count] > 0)
    [rootObj setObject:self.approvedCrashReports forKey:kBITCrashApprovedReports];
  
  NSData *plist = [NSPropertyListSerialization dataFromPropertyList:(id)rootObj
                                                             format:NSPropertyListBinaryFormat_v1_0
                                                   errorDescription:&errorString];
  if (plist) {
    [plist writeToFile:self.settingsFile atomically:YES];
  } else {
    BITHockeyLogError(@"ERROR: Writing settings. %@", errorString);
  }
  
}

- (void)loadSettings {
  NSString *errorString = nil;
  NSPropertyListFormat format;
  
  self.userName = bit_stringValueFromKeychainForKey([NSString stringWithFormat:@"default.%@", kBITCrashMetaUserName]);
  self.userEmail = bit_stringValueFromKeychainForKey([NSString stringWithFormat:@"default.%@", kBITCrashMetaUserEmail]);
  
  if (![self.fileManager fileExistsAtPath:self.settingsFile])
    return;
  
  NSData *plist = [NSData dataWithContentsOfFile:self.settingsFile];
  if (plist) {
    NSDictionary *rootObj = (NSDictionary *)[NSPropertyListSerialization
                                             propertyListFromData:plist
                                             mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                             format:&format
                                             errorDescription:&errorString];
    if ([rootObj objectForKey:kBITCrashApprovedReports])
      [self.approvedCrashReports setDictionary:(NSDictionary *)[rootObj objectForKey:kBITCrashApprovedReports]];
  } else {
    BITHockeyLogError(@"ERROR: Reading crash manager settings.");
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
  
  [self.fileManager removeItemAtPath:filename error:&error];
  [self.fileManager removeItemAtPath:[filename stringByAppendingString:@".data"] error:&error];
  [self.fileManager removeItemAtPath:[filename stringByAppendingString:@".meta"] error:&error];
  [self.fileManager removeItemAtPath:[filename stringByAppendingString:@".desc"] error:&error];
  
  NSString *cacheFilename = [filename lastPathComponent];
  bit_removeKeyFromKeychain([NSString stringWithFormat:@"%@.%@", cacheFilename, kBITCrashMetaUserName]);
  bit_removeKeyFromKeychain([NSString stringWithFormat:@"%@.%@", cacheFilename, kBITCrashMetaUserEmail]);
  bit_removeKeyFromKeychain([NSString stringWithFormat:@"%@.%@", cacheFilename, kBITCrashMetaUserID]);
  
  [self.crashFiles removeObject:filename];
  [self.approvedCrashReports removeObjectForKey:filename];
  
  [self saveSettings];
}

/**
 *	 Remove all crash reports and stored meta data for each from the file system and keychain
 *
 * This is currently only used as a helper method for tests
 */
- (void)cleanCrashReports {
  for (NSUInteger i=0; i < [self.crashFiles count]; i++) {
    [self cleanCrashReportWithFilename:[self.crashFiles objectAtIndex:0]];
  }
}

- (BOOL)persistAttachment:(BITHockeyAttachment *)attachment withFilename:(NSString *)filename {
  NSString *attachmentFilename = [filename stringByAppendingString:@".data"];
  NSMutableData *data = [[NSMutableData alloc] init];
  NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
  
  [archiver encodeObject:attachment forKey:kBITCrashMetaAttachment];
  
  [archiver finishEncoding];
  
  return [data writeToFile:attachmentFilename atomically:YES];
}

- (void)persistUserProvidedMetaData:(BITCrashMetaData *)userProvidedMetaData {
  if (!userProvidedMetaData) return;
  
  if (userProvidedMetaData.userDescription && [userProvidedMetaData.userDescription length] > 0) {
    NSError *error;
    [userProvidedMetaData.userDescription writeToFile:[NSString stringWithFormat:@"%@.desc", [self.crashesDir stringByAppendingPathComponent: self.lastCrashFilename]] atomically:YES encoding:NSUTF8StringEncoding error:&error];
  }
  
  if (userProvidedMetaData.userName && [userProvidedMetaData.userName length] > 0) {
    bit_addStringValueToKeychain(userProvidedMetaData.userName, [NSString stringWithFormat:@"default.%@", kBITCrashMetaUserName]);
    bit_addStringValueToKeychain(userProvidedMetaData.userName, [NSString stringWithFormat:@"%@.%@", self.lastCrashFilename, kBITCrashMetaUserName]);
  }
  
  if (userProvidedMetaData.userEmail && [userProvidedMetaData.userEmail length] > 0) {
    bit_addStringValueToKeychain(userProvidedMetaData.userEmail, [NSString stringWithFormat:@"default.%@", kBITCrashMetaUserEmail]);
    bit_addStringValueToKeychain(userProvidedMetaData.userEmail, [NSString stringWithFormat:@"%@.%@", self.lastCrashFilename, kBITCrashMetaUserEmail]);
  }
  
  if (userProvidedMetaData.userID && [userProvidedMetaData.userID length] > 0) {
    bit_addStringValueToKeychain(userProvidedMetaData.userID, [NSString stringWithFormat:@"%@.%@", self.lastCrashFilename, kBITCrashMetaUserID]);
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
  
  if (![self.fileManager fileExistsAtPath:attachmentFilename])
    return nil;
  
  
  NSData *codedData = [[NSData alloc] initWithContentsOfFile:attachmentFilename];
  if (!codedData)
    return nil;
  
  NSKeyedUnarchiver *unarchiver = nil;
  
  @try {
    unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:codedData];
  }
  @catch (NSException * __unused exception) {
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
    if ([element objectForKey:kBITBinaryImageKeyType] &&
        [element objectForKey:kBITBinaryImageKeyArch] &&
        [element objectForKey:kBITBinaryImageKeyUUID]) {
      [uuidString appendFormat:@"<uuid type=\"%@\" arch=\"%@\">%@</uuid>",
       [element objectForKey:kBITBinaryImageKeyType],
       [element objectForKey:kBITBinaryImageKeyArch],
       [element objectForKey:kBITBinaryImageKeyUUID]
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
  
  id<BITHockeyManagerDelegate> delegate = [BITHockeyManager sharedHockeyManager].delegate;
  if (delegate && [delegate respondsToSelector:@selector(userIDForHockeyManager:componentManager:)]) {
    userID = [delegate userIDForHockeyManager:[BITHockeyManager sharedHockeyManager]
                             componentManager:self];
  }
  
  return userID ?: @"";
}

- (NSString *)userNameForCrashReport {
  NSString *userName = nil;
  
  if (self.userName)
    return self.userName;
  
  userName = bit_stringValueFromKeychainForKey(kBITDefaultUserName);
  
  id<BITHockeyManagerDelegate> delegate = [BITHockeyManager sharedHockeyManager].delegate;
  if (delegate && [delegate respondsToSelector:@selector(userNameForHockeyManager:componentManager:)]) {
    userName = [delegate userNameForHockeyManager:[BITHockeyManager sharedHockeyManager]
                                 componentManager:self];
  }
  
  return userName ?: @"";
}

- (NSString *)userEmailForCrashReport {
  NSString *userEmail = nil;
  
  if (self.userEmail)
    return self.userEmail;
  
  userEmail = bit_stringValueFromKeychainForKey(kBITDefaultUserEmail);
  
  id<BITHockeyManagerDelegate> delegate = [BITHockeyManager sharedHockeyManager].delegate;
  if (delegate && [delegate respondsToSelector:@selector(userEmailForHockeyManager:componentManager:)]) {
    userEmail = [delegate userEmailForHockeyManager:[BITHockeyManager sharedHockeyManager]
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
  
  self.crashCallBacks = &plCrashCallbacks;
}

- (void)setCrashReportUIHandler:(BITCustomCrashReportUIHandler)crashReportUIHandler {
  _crashReportUIHandler = crashReportUIHandler;
}


- (void)generateTestCrash __attribute__((noreturn)) {
  if (bit_isDebuggerAttached()) {
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
  BITHockeyLogVerbose(@"Storing meta data for crash report with filename %@", filename);
  
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
  [self.dictOfLastSessionCrash setObject:applicationLog forKey:kBITCrashMetaApplicationLog];
  [metaDict setObject:applicationLog forKey:kBITCrashMetaApplicationLog];
  
  if (self.delegate != nil && [self.delegate respondsToSelector:@selector(attachmentForCrashManager:)]) {
    BITHockeyLogVerbose(@"Processing attachment for crash report with filename %@", filename);
    
    BITHockeyAttachment *attachment = [self.delegate attachmentForCrashManager:self];
    
    if (attachment) {
      BOOL success = [self persistAttachment:attachment withFilename:[self.crashesDir stringByAppendingPathComponent: filename]];
      if (!success) {
        BITHockeyLogError(@"Persisting the crash attachment failed");
      } else {
        BITHockeyLogVerbose(@"Crash attachment successfully persisted.");
      }
    } else {
      BITHockeyLogVerbose(@"Crash attachment was nil");
    }
  }
  
  NSData *plist = [NSPropertyListSerialization dataFromPropertyList:(id)metaDict
                                                             format:NSPropertyListBinaryFormat_v1_0
                                                   errorDescription:&errorString];
  if (plist) {
    BOOL success = [plist writeToFile:[self.crashesDir stringByAppendingPathComponent: (NSString *)[filename stringByAppendingPathExtension:@"meta"]] atomically:YES];
    if (!success) {
      BITHockeyLogError(@"Writing crash meta data failed.");
    }
  } else {
    BITHockeyLogError(@"Serializing crash meta dict failed. %@", error);
  }
}

- (BOOL)handleUserInput:(BITCrashManagerUserInput)userInput withUserProvidedMetaData:(BITCrashMetaData *)userProvidedMetaData {
  switch (userInput) {
    case BITCrashManagerUserInputDontSend:
      if (self.delegate != nil && [self.delegate respondsToSelector:@selector(crashManagerWillCancelSendingCrashReport:)]) {
        [self.delegate crashManagerWillCancelSendingCrashReport:self];
      }
      
      if (self.lastCrashFilename)
        [self cleanCrashReportWithFilename:[self.crashesDir stringByAppendingPathComponent: self.lastCrashFilename]];
      
      return YES;
      
    case BITCrashManagerUserInputSend:
      if (userProvidedMetaData)
        [self persistUserProvidedMetaData:userProvidedMetaData];
      
      [self approveLatestCrashReport];
      [self sendNextCrashReport];
      return YES;
      
    case BITCrashManagerUserInputAlwaysSend:
      self.autoSubmitCrashReport = YES;
      
      if (userProvidedMetaData)
        [self persistUserProvidedMetaData:userProvidedMetaData];
      
      [self approveLatestCrashReport];
      [self sendNextCrashReport];
      return YES;
  }
  return NO;
}


#pragma mark - BITPLCrashReporter

// Called to handle a pending crash report.
- (void)handleCrashReport {
  BITHockeyLogVerbose(@"Handling crash report");
  
  NSError *error = NULL;
  
  // check if the next call ran successfully the last time
  if (![self.fileManager fileExistsAtPath:self.analyzerInProgressFile]) {
    // mark the start of the routine
    [self.fileManager createFileAtPath:self.analyzerInProgressFile contents:nil attributes:nil];
    BITHockeyLogVerbose(@"AnalyzerInProgress file created");
    
    [self saveSettings];
    
    // Try loading the crash report
    NSData *crashData = [[NSData alloc] initWithData:[self.plCrashReporter loadPendingCrashReportDataAndReturnError: &error]];
    
    NSString *cacheFilename = [NSString stringWithFormat: @"%.0f", [NSDate timeIntervalSinceReferenceDate]];
    self.lastCrashFilename = [cacheFilename copy];
    
    if (crashData == nil) {
      BITHockeyLogWarning(@"WARNING: Could not load crash report: %@", error);
    } else {
      // get the startup timestamp from the crash report, and the file timestamp to calculate the timeinterval when the crash happened after startup
      BITPLCrashReport *report = [[BITPLCrashReport alloc] initWithData:crashData error:&error];
      
      if (report == nil) {
        BITHockeyLogWarning(@"WARNING: Could not parse crash report");
      } else {
        NSDate *appStartTime = nil;
        NSDate *appCrashTime = nil;
        if ([report.processInfo respondsToSelector:@selector(processStartTime)]) {
          if (report.systemInfo.timestamp && report.processInfo.processStartTime) {
            appStartTime = report.processInfo.processStartTime;
            appCrashTime =report.systemInfo.timestamp;
            self.timeintervalCrashInLastSessionOccured = [report.systemInfo.timestamp timeIntervalSinceDate:report.processInfo.processStartTime];
          }
        }
        
        [crashData writeToFile:[self.crashesDir stringByAppendingPathComponent: cacheFilename] atomically:YES];
        
        NSString *incidentIdentifier = @"???";
        if (report.uuidRef != NULL) {
          incidentIdentifier = (NSString *) CFBridgingRelease(CFUUIDCreateString(NULL, report.uuidRef));
        }
        
        NSString *reporterKey = [BITSystemProfile deviceIdentifier] ?: @"";
        
        self.lastSessionCrashDetails = [[BITCrashDetails alloc] initWithIncidentIdentifier:incidentIdentifier
                                                                               reporterKey:reporterKey
                                                                                    signal:report.signalInfo.name
                                                                             exceptionName:report.exceptionInfo.exceptionName
                                                                           exceptionReason:report.exceptionInfo.exceptionReason
                                                                              appStartTime:appStartTime
                                                                                 crashTime:appCrashTime
                                                                                 osVersion:report.systemInfo.operatingSystemVersion
                                                                                   osBuild:report.systemInfo.operatingSystemBuild
                                                                                appVersion:report.applicationInfo.applicationMarketingVersion
                                                                                  appBuild:report.applicationInfo.applicationVersion
                                                                      appProcessIdentifier:report.processInfo.processID
                                        ];
        
        // fetch and store the meta data after setting _lastSessionCrashDetails, so the property can be used in the protocol methods
        [self storeMetaDataForCrashReportFilename:cacheFilename];
      }
    }
  }
  
  // Purge the report
  // mark the end of the routine
  if ([self.fileManager fileExistsAtPath:self.analyzerInProgressFile]) {
    [self.fileManager removeItemAtPath:self.analyzerInProgressFile error:&error];
  }
  
  [self saveSettings];
  
  [self.plCrashReporter purgePendingCrashReport];
}

/**
 Get the filename of the first not approved crash report
 
 @return NSString Filename of the first found not approved crash report
 */
- (NSString *)firstNotApprovedCrashReport {
  if ((!self.approvedCrashReports || [self.approvedCrashReports count] == 0) && [self.crashFiles count] > 0) {
    return [self.crashFiles objectAtIndex:0];
  }
  
  for (NSUInteger i=0; i < [self.crashFiles count]; i++) {
    NSString *filename = [self.crashFiles objectAtIndex:i];
    
    if (![self.approvedCrashReports objectForKey:filename]) return filename;
  }
  
  return nil;
}

/**
 Check if there are any new crash reports that are not yet processed
 
 @return	`YES` if there is at least one new crash report found, `NO` otherwise
 */
- (BOOL)hasPendingCrashReport {
  if (!self.crashManagerActivated) return NO;
  
  if ([self.fileManager fileExistsAtPath: self.crashesDir]) {
    NSString *file = nil;
    NSError *error = NULL;
    
    NSDirectoryEnumerator *dirEnum = [self.fileManager enumeratorAtPath: self.crashesDir];
    
    while ((file = [dirEnum nextObject])) {
      NSDictionary *fileAttributes = [self.fileManager attributesOfItemAtPath:[self.crashesDir stringByAppendingPathComponent:file] error:&error];
      if ([[fileAttributes objectForKey:NSFileSize] intValue] > 0 &&
          ![file hasSuffix:@".DS_Store"] &&
          ![file hasSuffix:@".analyzer"] &&
          ![file hasSuffix:@".plist"] &&
          ![file hasSuffix:@".data"] &&
          ![file hasSuffix:@".meta"] &&
          ![file hasSuffix:@".desc"]) {
        [self.crashFiles addObject:[self.crashesDir stringByAppendingPathComponent: file]];
      }
    }
  }
  
  if ([self.crashFiles count] > 0) {
    BITHockeyLogDebug(@"INFO: %li pending crash reports found.", (unsigned long)[self.crashFiles count]);
    return YES;
  } else {
    if (self.didCrashInLastSession) {
      if (self.delegate != nil && [self.delegate respondsToSelector:@selector(crashManagerWillCancelSendingCrashReport:)]) {
        [self.delegate crashManagerWillCancelSendingCrashReport:self];
      }
      
      self.didCrashInLastSession = NO;
    }
    
    return NO;
  }
}


#pragma mark - Crash Report Processing

// store the latest crash report as user approved, so if it fails it will retry automatically
- (void)approveLatestCrashReport {
  [self.approvedCrashReports setObject:[NSNumber numberWithBool:YES] forKey:[self.crashesDir stringByAppendingPathComponent: self.lastCrashFilename]];
  [self saveSettings];
}

- (void)invokeProcessing {
  BITHockeyLogDebug(@"INFO: Start CrashManager processing");
  
  if (!self.sendingInProgress && [self hasPendingCrashReport]) {
    self.sendingInProgress = YES;
    BITHockeyLogDebug(@"INFO: Pending crash reports found.");
    
    NSString *notApprovedReportFilename = [self firstNotApprovedCrashReport];
    if (!self.autoSubmitCrashReport && notApprovedReportFilename) {
      NSError* error = nil;
      NSString *crashReport = nil;
      
      // this can happen in case there is a non approved crash report but it didn't happen in the previous app session
      if (!self.lastCrashFilename) {
        self.lastCrashFilename = [[notApprovedReportFilename lastPathComponent] copy];
      }
      
      NSData *crashData = [NSData dataWithContentsOfFile: [self.crashesDir stringByAppendingPathComponent:self.lastCrashFilename]];
      BITPLCrashReport *report = [[BITPLCrashReport alloc] initWithData:crashData error:&error];
      NSString *installString = [BITSystemProfile deviceIdentifier] ?: @"";
      crashReport = [BITCrashReportTextFormatter stringValueForCrashReport:report crashReporterKey:installString];
      
      if (crashReport && !error) {
        NSString *log = [self.dictOfLastSessionCrash valueForKey:kBITCrashMetaApplicationLog] ?: @"";
        
        if (self.delegate != nil && [self.delegate respondsToSelector:@selector(crashManagerWillShowSubmitCrashReportAlert:)]) {
          [self.delegate crashManagerWillShowSubmitCrashReportAlert:self];
        }
        
        if (self.crashReportUIHandler) {
          self.crashReportUIHandler(crashReport, log);
        } else {
          self.crashReportUI = [[BITCrashReportUI alloc] initWithManager:self
                                                             crashReport:crashReport
                                                              logContent:log
                                                         applicationName:[self applicationName]
                                                          askUserDetails:self.askUserDetails];
          
          [self.crashReportUI setUserName:[self userNameForCrashReport]];
          [self.crashReportUI setUserEmail:[self userEmailForCrashReport]];
          
          if (self.crashReportUI.nibDidLoadSuccessfully) {
            [self.crashReportUI askCrashReportDetails];
            [self.crashReportUI showWindow:self];
            [self.crashReportUI.window setLevel:NSNormalWindowLevel+1];
            [self.crashReportUI.window makeKeyAndOrderFront:self];
          } else {
            [self approveLatestCrashReport];
            [self sendNextCrashReport];
          }
        }
      } else {
        [self cleanCrashReportWithFilename:self.lastCrashFilename];
      }
    } else {
      [self approveLatestCrashReport];
      [self sendNextCrashReport];
    }
  }
  
  [self performSelector:@selector(invokeDelayedProcessing) withObject:nil afterDelay:0.5];
}

- (void)startManager {
  if (!self.crashManagerActivated) {
    return;
  }
  
  BITHockeyLogDebug(@"INFO: Start CrashManager startManager");
  
  [self loadSettings];
  
  if (!self.plCrashReporter) {
    /* Configure our reporter */
    
    PLCrashReporterSignalHandlerType signalHandlerType = PLCrashReporterSignalHandlerTypeMach;
    if (self.isMachExceptionHandlerDisabled) {
      signalHandlerType = PLCrashReporterSignalHandlerTypeBSD;
    }
    BITPLCrashReporterConfig *config = [[BITPLCrashReporterConfig alloc] initWithSignalHandlerType: signalHandlerType
                                                                             symbolicationStrategy: PLCrashReporterSymbolicationStrategySymbolTable];
    self.plCrashReporter = [[BITPLCrashReporter alloc] initWithConfiguration: config];
    NSError *error = NULL;
    
    // Check if we previously crashed
    if ([self.plCrashReporter hasPendingCrashReport]) {
      self.didCrashInLastSession = YES;
      [self handleCrashReport];
    }
    
    // The actual signal and mach handlers are only registered when invoking `enableCrashReporterAndReturnError`
    // So it is safe enough to only disable the following part when a debugger is attached no matter which
    // signal handler type is set
    if (!bit_isDebuggerAttached()) {
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
      if (self.crashCallBacks) {
        [self.plCrashReporter setCrashCallbacks:self.crashCallBacks];
      }
      
      // Enable the Crash Reporter
      BOOL crashReporterEnabled = [self.plCrashReporter enableCrashReporterAndReturnError:&error];
      if (!crashReporterEnabled)
        NSLog(@"[HockeySDK] WARNING: Could not enable crash reporter: %@", error);
      
      // get the new current top level error handler, which should now be the one from PLCrashReporter
      NSUncaughtExceptionHandler *currentHandler = NSGetUncaughtExceptionHandler();
      
      // do we have a new top level error handler? then we were successful
      if (currentHandler && currentHandler != initialHandler) {
        self.plcrExceptionHandler = currentHandler;
        
        BITHockeyLogDebug(@"INFO: Exception handler successfully initialized.");
      } else {
        // this should never happen, theoretically only if NSSetUncaugtExceptionHandler() has some internal issues
        NSLog(@"[HockeySDK] ERROR: Exception handler could not be set. Make sure there is no other exception handler set up!");
      }
      [BITCrashUncaughtCXXExceptionHandlerManager addCXXExceptionHandler:uncaught_cxx_exception_handler];
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
  BITHockeyLogDebug(@"INFO: Start delayed CrashManager processing");
  
  // was our own exception handler successfully added?
  if (self.plcrExceptionHandler) {
    // get the current top level error handler
    NSUncaughtExceptionHandler *currentHandler = NSGetUncaughtExceptionHandler();
    
    // If the top level error handler differs from our own, then at least another one was added.
    // This could cause exception crashes not to be reported to HockeyApp. See log message for details.
    if (self.plcrExceptionHandler != currentHandler) {
      BITHockeyLogWarning(@"[HockeySDK] WARNING: Another exception handler was added. If this invokes any kind exit() after processing the exception, which causes any subsequent error handler not to be invoked, these crashes will NOT be reported to HockeyApp!");
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
  
  self.crashIdenticalCurrentVersion = NO;
  
  if ([self.crashFiles count] == 0)
    return;
  
  NSString *crashXML = nil;
  BITHockeyAttachment *attachment = nil;
  
  // we start sending always with the oldest pending one
  NSString *filename = [self.crashFiles objectAtIndex:0];
  NSData *crashData = [NSData dataWithContentsOfFile:filename];
  if ([crashData length] > 0) {
    BITPLCrashReport *report = nil;
    NSString *crashUUID = @"";
    NSString *installString = nil;
    NSString *crashLogString = nil;
    NSString *appBundleIdentifier = nil;
    NSString *appBundleMarketingVersion = nil;
    NSString *appBundleVersion = nil;
    NSString *osVersion = nil;
    NSString *deviceModel = nil;
    NSString *appBinaryUUIDs = nil;
    NSString *metaFilename = nil;
    
    NSString *errorString = nil;
    NSPropertyListFormat format;
    
    report = [[BITPLCrashReport alloc] initWithData:crashData error:&error];
    if (report == nil) {
      BITHockeyLogWarning(@"WARNING: Could not parse crash report");
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
    appBundleMarketingVersion = report.applicationInfo.applicationMarketingVersion ?: @"";
    appBundleVersion = report.applicationInfo.applicationVersion;
    osVersion = report.systemInfo.operatingSystemVersion;
    deviceModel = [BITSystemProfile deviceModel];
    appBinaryUUIDs = [self extractAppUUIDs:report];
    if ([report.applicationInfo.applicationVersion compare:(id)[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]] == NSOrderedSame) {
      self.crashIdenticalCurrentVersion = YES;
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
      applicationLog = [metaDict objectForKey:kBITCrashMetaApplicationLog] ?: @"";
      description = [metaDict objectForKey:kBITCrashMetaDescription] ?: @"";
      attachment = [self attachmentForCrashReport:filename];
    } else {
      BITHockeyLogError(@"ERROR: Reading crash meta data. %@", error);
    }
    
    NSString *descriptionMetaFilePath = [filename stringByAppendingPathExtension:@"desc"];
    if ([self.fileManager fileExistsAtPath:descriptionMetaFilePath]) {
      description = [NSString stringWithContentsOfFile:descriptionMetaFilePath encoding:NSUTF8StringEncoding error:&error] ?: @"";
    }
    
    if ([applicationLog length] > 0) {
      if ([description length] > 0) {
        description = [NSString stringWithFormat:@"%@\n\nLog:\n%@", description, applicationLog];
      } else {
        description = [NSString stringWithFormat:@"Log:\n%@", applicationLog];
      }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcstring-format-directive"
    crashXML = [NSString stringWithFormat:@"<crashes><crash><applicationname>%s</applicationname><uuids>%@</uuids><bundleidentifier>%@</bundleidentifier><systemversion>%@</systemversion><platform>%@</platform><senderversion>%@</senderversion><versionstring>%@</versionstring><version>%@</version><uuid>%@</uuid><log><![CDATA[%@]]></log><userid>%@</userid><username>%@</username><contact>%@</contact><installstring>%@</installstring><description><![CDATA[%@]]></description></crash></crashes>",
                [[self applicationName] UTF8String],
                appBinaryUUIDs,
                appBundleIdentifier,
                osVersion,
                deviceModel,
                [self applicationVersion],
                appBundleMarketingVersion,
                appBundleVersion,
                crashUUID,
                [crashLogString stringByReplacingOccurrencesOfString:@"]]>" withString:@"]]" @"]]><![CDATA[" @">" options:NSLiteralSearch range:NSMakeRange(0,crashLogString.length)],
                userid,
                username,
                useremail,
                installString,
                [description stringByReplacingOccurrencesOfString:@"]]>" withString:@"]]" @"]]><![CDATA[" @">" options:NSLiteralSearch range:NSMakeRange(0,description.length)]];
#pragma clang diagnostic pop
    BITHockeyLogDebug(@"INFO: Sending crash reports:\n%@", crashXML);
    [self sendCrashReportWithFilename:filename xml:crashXML attachment:attachment];
  } else {
    // we cannot do anything with this report, so delete it
    [self cleanCrashReportWithFilename:filename];
  }
}


#pragma mark - Networking

- (NSData *)postBodyWithXML:(NSString *)xml attachment:(BITHockeyAttachment *)attachment boundary:(NSString *)boundary {
  NSMutableData *postBody =  [NSMutableData data];
  
  //  [postBody appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
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
  
  [postBody appendData:(NSData *)[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
  
  return postBody;
}

- (NSMutableURLRequest *)requestWithBoundary:(NSString *)boundary {
  NSString *postCrashPath = [NSString stringWithFormat:@"api/2/apps/%@/crashes", self.encodedAppIdentifier];
  
  NSMutableURLRequest *request = [self.hockeyAppClient requestWithMethod:@"POST"
                                                                    path:postCrashPath
                                                              parameters:nil];
  
  [request setCachePolicy: NSURLRequestReloadIgnoringLocalCacheData];
  [request setValue:@"HockeySDK/iOS" forHTTPHeaderField:@"User-Agent"];
  [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
  
  NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
  [request setValue:contentType forHTTPHeaderField:@"Content-type"];
  
  return request;
}

// process upload response
- (void)processUploadResultWithFilename:(NSString *)filename responseData:(NSData *)responseData statusCode:(NSInteger)statusCode error:(NSError *)error {
  __block NSError *theError = error;
  
  dispatch_async(dispatch_get_main_queue(), ^{
    self.sendingInProgress = NO;
    
    if (nil == theError) {
      if (nil == responseData || [responseData length] == 0) {
        theError = [NSError errorWithDomain:kBITCrashErrorDomain
                                       code:BITCrashAPIReceivedEmptyResponse
                                   userInfo:@{
                                              NSLocalizedDescriptionKey: @"Sending failed with an empty response!"
                                              }
                    ];
      } else if (statusCode >= 200 && statusCode < 400) {
        [self cleanCrashReportWithFilename:filename];
        
        // HockeyApp uses PList XML format
        NSMutableDictionary *response = [NSPropertyListSerialization propertyListWithData:responseData
                                                                                  options:NSPropertyListMutableContainersAndLeaves
                                                                                   format:nil
                                                                                    error:&theError];
        BITHockeyLogDebug(@"INFO: Received API response: %@", response);
        
        if ([self.delegate respondsToSelector:@selector(crashManagerDidFinishSendingCrashReport:)]) {
          [self.delegate crashManagerDidFinishSendingCrashReport:self];
        }
        
        // only if sending the crash report went successfully, continue with the next one (if there are more)
        [self sendNextCrashReport];
      } else if (statusCode == 400) {
        [self cleanCrashReportWithFilename:filename];
        
        theError = [NSError errorWithDomain:kBITCrashErrorDomain
                                       code:BITCrashAPIAppVersionRejected
                                   userInfo:@{
                                              NSLocalizedDescriptionKey: @"The server rejected receiving crash reports for this app version!"
                                              }
                    ];
      } else {
        theError = [NSError errorWithDomain:kBITCrashErrorDomain
                                       code:BITCrashAPIErrorWithStatusCode
                                   userInfo:@{
                                              NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Sending failed with status code: %li", (long)statusCode]
                                              }
                    ];
      }
    }
    
    if (theError) {
      if ([self.delegate respondsToSelector:@selector(crashManager:didFailWithError:)]) {
        [self.delegate crashManager:self didFailWithError:theError];
      }
      
      BITHockeyLogError(@"ERROR: %@", [theError localizedDescription]);
    }
  });
}

/**
 *	 Send the XML data to the server
 *
 * Wraps the XML structure into a POST body and starts sending the data asynchronously
 *
 *	@param	xml	The XML data that needs to be send to the server
 */
- (void)sendCrashReportWithFilename:(NSString *)filename xml:(NSString*)xml attachment:(BITHockeyAttachment *)attachment {
  NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
  __block NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfiguration];
  
  NSURLRequest *request = [self requestWithBoundary:kBITHockeyAppClientBoundary];
  NSData *data = [self postBodyWithXML:xml attachment:attachment boundary:kBITHockeyAppClientBoundary];
  
  if (request && data) {
    __weak typeof (self) weakSelf = self;
    NSURLSessionUploadTask *uploadTask = [session uploadTaskWithRequest:request
                                                               fromData:data
                                                      completionHandler:^(NSData *responseData, NSURLResponse *response, NSError *error) {
                                                        typeof (self) strongSelf = weakSelf;
                                                        
                                                        [session finishTasksAndInvalidate];
                                                        
                                                        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*) response;
                                                        NSInteger statusCode = [httpResponse statusCode];
                                                        [strongSelf processUploadResultWithFilename:filename responseData:responseData statusCode:statusCode error:error];
                                                      }];
    
    [uploadTask resume];
  }
  
  if ([self.delegate respondsToSelector:@selector(crashManagerWillSendCrashReport:)]) {
    [self.delegate crashManagerWillSendCrashReport:self];
  }
  
  BITHockeyLogDebug(@"INFO: Sending crash reports started.");
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
