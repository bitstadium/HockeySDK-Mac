#import "HockeySDK.h"
#import "HockeySDKPrivate.h"

#import "BITHockeyBaseManagerPrivate.h"
#import "BITCrashManagerPrivate.h"
#import "BITFeedbackManagerPrivate.h"
#import "BITMetricsManagerPrivate.h"
#import "BITCategoryContainer.h"
#import "BITHockeyHelper.h"
#import "BITHockeyAppClient.h"

NSString *const kBITHockeySDKURL = @"https://sdk.hockeyapp.net/";

@interface BITHockeyManager ()

@property (nonatomic, copy) NSString *appIdentifier;
@property (nonatomic) BOOL validAppIdentifier;
@property (nonatomic) BOOL startManagerIsInvoked;
@property (nonatomic, strong) BITHockeyAppClient *hockeyAppClient;

// Redeclare BITHockeyManager properties with readwrite attribute.
@property (nonatomic, strong, readwrite) BITCrashManager *crashManager;
@property (nonatomic, strong, readwrite) BITFeedbackManager *feedbackManager;
@property (nonatomic, strong, readwrite) BITMetricsManager *metricsManager;

@end


@implementation BITHockeyManager

#pragma mark - Public Class Methods

+ (BITHockeyManager *)sharedHockeyManager {
  static BITHockeyManager *sharedInstance = nil;
  static dispatch_once_t pred;
  
  dispatch_once(&pred, ^{
    sharedInstance = [BITHockeyManager alloc];
    sharedInstance = [sharedInstance init];
  });
  
  return sharedInstance;
}

- (id) init {
  if ((self = [super init])) {
    _serverURL = nil;
    _delegate = nil;
    self.hockeyAppClient = nil;
    
    _disableCrashManager = NO;
    _disableFeedbackManager = NO;
    _disableMetricsManager = NO;
    
    self.startManagerIsInvoked = NO;
    
    [self performSelector:@selector(validateStartManagerIsInvoked) withObject:nil afterDelay:0.0];
  }
  return self;
}

- (void)dealloc {
  self.appIdentifier = nil;
  
}


#pragma mark - Private Class Methods

- (BOOL)isSetUpOnMainThread {
  if (!NSThread.isMainThread) {
    NSAssert(NSThread.isMainThread, @"ERROR: This SDK has to be setup on the main thread!");
    
    return NO;
  }
  
  return YES;
}

- (BOOL)checkValidityOfAppIdentifier:(NSString *)identifier {
  BOOL result = NO;
  
  if (identifier) {
    NSCharacterSet *hexSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"];
    NSCharacterSet *inStringSet = [NSCharacterSet characterSetWithCharactersInString:identifier];
    result = ([identifier length] == 32) && ([hexSet isSupersetOfSet:inStringSet]);
  }
  
  return result;
}

- (void)logInvalidIdentifier:(NSString *)environment {
  NSLog(@"[HockeySDK] ERROR: The %@ is invalid! Please use the HockeyApp app identifier you find on the apps website on HockeyApp! The SDK is disabled!", environment);
}

- (NSString *)integrationFlowTimeString {
  NSString *timeString = [[NSBundle mainBundle] objectForInfoDictionaryKey:BITHOCKEY_INTEGRATIONFLOW_TIMESTAMP];
  
  return timeString;
}

- (BOOL)integrationFlowStartedWithTimeString:(NSString *)timeString {
  if (timeString == nil) {
    return NO;
  }
  
  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
  NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
  [dateFormatter setLocale:enUSPOSIXLocale];
  [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
  NSDate *integrationFlowStartDate = [dateFormatter dateFromString:timeString];
  
  if (integrationFlowStartDate && [integrationFlowStartDate timeIntervalSince1970] > [[NSDate date] timeIntervalSince1970] - (60 * 10) ) {
    return YES;
  }
  
  return NO;
}

- (void)pingServerForIntegrationStartWorkflowWithTimeString:(NSString *)timeString {
  if (!self.appIdentifier) {
    return;
  }
  
  NSString *integrationPath = [NSString stringWithFormat:@"api/3/apps/%@/integration", [self.appIdentifier stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
  
  BITHockeyLogDebug(@"INFO: Sending integration workflow ping to %@", integrationPath);
  
  [[self hockeyAppClient] postPath:integrationPath
                        parameters:@{@"timestamp": timeString,
                                     @"sdk": BITHOCKEY_NAME,
                                     @"sdk_version": BITHOCKEY_VERSION,
                                     @"bundle_version": [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]
                                     }
                        completion:^(BITHTTPOperation *operation, NSData * __unused responseData, NSError * __unused error) {
                          switch (operation.response.statusCode) {
                            case 400:
                              BITHockeyLogError(@"ERROR: App ID not found");
                              break;
                            case 201:
                              BITHockeyLogDebug(@"INFO: Ping accepted.");
                              break;
                            case 200:
                              BITHockeyLogDebug(@"INFO: Ping accepted. Server already knows.");
                              break;
                            default:
                              BITHockeyLogError(@"ERROR: Unknown error");
                              break;
                          }
                        }];
}


#pragma mark - Public Instance Methods (Configuration)

- (void)configureWithIdentifier:(NSString *)appIdentifier {
  self.appIdentifier = [appIdentifier copy];
  
  [self initializeModules];
}

- (void)configureWithIdentifier:(NSString *)appIdentifier delegate:(id <BITHockeyManagerDelegate>)delegate {
  self.appIdentifier = [appIdentifier copy];
  
  self.delegate = delegate;
  
  [self initializeModules];
}


- (void)configureWithIdentifier:(NSString *)appIdentifier companyName:(NSString *) __unused companyName delegate:(id <BITHockeyManagerDelegate>)delegate {
  self.appIdentifier = [appIdentifier copy];
  
  self.delegate = delegate;
  
  [self initializeModules];
}

- (void)startManager {
  if (!self.validAppIdentifier || ![self isSetUpOnMainThread]) {
    return;
  }
  
  // Fix bug where Application Support directory was encluded from backup
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSURL *appSupportURL = [[fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject];
  bit_fixBackupAttributeForURL(appSupportURL);
  
  BITHockeyLogDebug(@"INFO: Starting HockeyManager");
  self.startManagerIsInvoked = YES;
  
  // start CrashManager
  if (![self isCrashManagerDisabled]) {
    BITHockeyLogDebug(@"INFO: Start CrashManager");
    [self.crashManager startManager];
  }
  
  // start FeedbackManager
  if (![self isFeedbackManagerDisabled]) {
    BITHockeyLogDebug(@"INFO: Start FeedbackManager");
    if (self.serverURL) {
      [self.feedbackManager setServerURL:self.serverURL];
    }
    [self.feedbackManager performSelector:@selector(startManager) withObject:nil afterDelay:1.0];
  }
  
  // start MetricsManager
  if (!self.disableMetricsManager) {
    BITHockeyLogDebug(@"INFO: Start MetricsManager");
    [self.metricsManager startManager];
    [BITCategoryContainer activateCategory];
  }
  
  NSString *integrationFlowTime = [self integrationFlowTimeString];
  if (integrationFlowTime && [self integrationFlowStartedWithTimeString:integrationFlowTime]) {
    [self pingServerForIntegrationStartWorkflowWithTimeString:integrationFlowTime];
  }
}

- (void)validateStartManagerIsInvoked {
  if (self.validAppIdentifier && !self.startManagerIsInvoked) {
    NSLog(@"[HockeySDK] ERROR: You did not call [[BITHockeyManager sharedHockeyManager] startManager] to startup the HockeySDK! Please do so after setting up all properties. The SDK is NOT running.");
  }
}

- (void)setDisableMetricsManager:(BOOL)disableMetricsManager {
  if (self.metricsManager) {
    self.metricsManager.disabled = disableMetricsManager;
  }
  _disableMetricsManager = disableMetricsManager;
}

- (void)setDisableFeedbackManager:(BOOL)disableFeedbackManager {
  if (self.feedbackManager) {
    [self.feedbackManager setDisableFeedbackManager:disableFeedbackManager];
  }
  _disableFeedbackManager = disableFeedbackManager;
}

- (void)setServerURL:(NSString *)aServerURL {
  // ensure url ends with a trailing slash
  if (![aServerURL hasSuffix:@"/"]) {
    aServerURL = [NSString stringWithFormat:@"%@/", aServerURL];
  }
  
  if (_serverURL != aServerURL) {
    _serverURL = [aServerURL copy];
    
    if (self.hockeyAppClient) {
      self.hockeyAppClient.baseURL = [NSURL URLWithString:_serverURL ?: kBITHockeySDKURL];
    }
  }
}

- (void)setDelegate:(id<BITHockeyManagerDelegate>)delegate {
  if (_delegate != delegate) {
    _delegate = delegate;
    
    if (self.crashManager) {
      self.crashManager.delegate = delegate;
    }
  }
}

- (void)setDebugLogEnabled:(BOOL)debugLogEnabled {
  _debugLogEnabled = debugLogEnabled;
  if (debugLogEnabled) {
    self.logLevel = BITLogLevelDebug;
  } else {
    self.logLevel = BITLogLevelWarning;
  }
}

- (BITLogLevel)logLevel {
  return BITHockeyLogger.currentLogLevel;
}

- (void)setLogLevel:(BITLogLevel)logLevel {
  BITHockeyLogger.currentLogLevel = logLevel;
}

- (void)setLogHandler:(BITLogHandler)logHandler {
  [BITHockeyLogger setLogHandler:logHandler];
}

- (void)setUserID:(NSString *)userID {
  if (!userID) {
    bit_removeKeyFromKeychain(kBITDefaultUserID);
  } else {
    bit_addStringValueToKeychain(userID, kBITDefaultUserID);
  }
}

- (void)setUserName:(NSString *)userName {
  if (!userName) {
    bit_removeKeyFromKeychain(kBITDefaultUserName);
  } else {
    bit_addStringValueToKeychain(userName, kBITDefaultUserName);
  }
}

- (void)setUserEmail:(NSString *)userEmail {
  if (!userEmail) {
    bit_removeKeyFromKeychain(kBITDefaultUserEmail);
  } else {
    bit_addStringValueToKeychain(userEmail, kBITDefaultUserEmail);
  }
}

- (void)testIdentifier {
  if (!self.appIdentifier) {
    return;
  }
  
  NSDate *now = [NSDate date];
  NSString *timeString = [NSString stringWithFormat:@"%.0f", [now timeIntervalSince1970]];
  [self pingServerForIntegrationStartWorkflowWithTimeString:timeString];
}


#pragma mark - Private Instance Methods

- (BITHockeyAppClient *)hockeyAppClient {
  if (!_hockeyAppClient) {
    _hockeyAppClient = [[BITHockeyAppClient alloc] initWithBaseURL:[NSURL URLWithString:self.serverURL ?: kBITHockeySDKURL]];
  }
  
  return _hockeyAppClient;
}

- (void)initializeModules {
  self.validAppIdentifier = [self checkValidityOfAppIdentifier:self.appIdentifier];
  
  if (![self isSetUpOnMainThread]) return;
  
  self.startManagerIsInvoked = NO;
  
  BITHockeyLogDebug(@"INFO: Setup CrashManager");
  self.crashManager = [[BITCrashManager alloc] initWithAppIdentifier:self.appIdentifier
                                                 hockeyAppClient:[self hockeyAppClient]];
  self.crashManager.delegate = self.delegate;
  
  // if we don't initialize the BITCrashManager instance, then the delegate will not be invoked
  // leaving the app to never show the window if the developer provided an invalid app identifier
  if (!self.validAppIdentifier) {
    [self logInvalidIdentifier:@"app identifier"];
    self.disableCrashManager = YES;
  } else {
    BITHockeyLogDebug(@"INFO: Setup FeedbackManager");
    self.feedbackManager = [[BITFeedbackManager alloc] initWithAppIdentifier:self.appIdentifier];
    
    BITHockeyLogDebug(@"INFO: Setup MetricsManager");
    NSString *iKey = bit_appIdentifierToGuid(self.appIdentifier);
    self.metricsManager = [[BITMetricsManager alloc] initWithAppIdentifier:iKey];
  }
  
  if ([self isCrashManagerDisabled])
    self.crashManager.crashManagerActivated = NO;
}

@end
