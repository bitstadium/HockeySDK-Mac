// 
//  Author: Andreas Linde <mail@andreaslinde.de>
// 
//  Copyright (c) 2012-2013 HockeyApp, Bit Stadium GmbH. All rights reserved.
//  See LICENSE.txt for author information.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "HockeySDK.h"
#import "HockeySDKPrivate.h"

#import "BITCrashManagerPrivate.h"


@implementation BITHockeyManager

@synthesize delegate = _delegate;
@synthesize serverURL = _serverURL;
@synthesize crashManager = _crashManager;
@synthesize disableCrashManager = _disableCrashManager;
@synthesize debugLogEnabled = _debugLogEnabled;

#pragma mark - Public Class Methods

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_10_6
+ (BITHockeyManager *)sharedHockeyManager {
  static BITHockeyManager *sharedInstance = nil;
  static dispatch_once_t pred;
  
  dispatch_once(&pred, ^{
    sharedInstance = [BITHockeyManager alloc];
    sharedInstance = [sharedInstance init];
  });
  
  return sharedInstance;
}
#else
+ (BITHockeyManager *)sharedHockeyManager {
  static BITHockeyManager *hockeyManager = nil;
  
  if (hockeyManager == nil) {
    hockeyManager = [[BITHockeyManager alloc] init];
  }
  
  return hockeyManager;
}
#endif

- (id) init {
  if ((self = [super init])) {
    _serverURL = nil;
    _delegate = nil;
    
    _disableCrashManager = NO;
    
    _startManagerIsInvoked = NO;
    
    [self performSelector:@selector(validateStartManagerIsInvoked) withObject:nil afterDelay:0.0f];
  }
  return self;
}

- (void)dealloc {
  [_appIdentifier release], _appIdentifier = nil;
  
  [super dealloc];
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
  if (!_appIdentifier) {
    return;
  }
  
  NSString *serverString = [BITHOCKEYSDK_URL copy];
  if (_serverURL)
    serverString = [_serverURL copy];
  
  NSMutableURLRequest *request = nil;
  NSString *boundary = @"----FOO";
  
  NSString *url = [NSString stringWithFormat:@"%@api/3/apps/%@/integration",
                   serverString,
                   [_appIdentifier stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
                   ];
  
  BITHockeyLog(@"INFO: Sending integration workflow ping to %@", url);
  
  request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
  
  [request setValue:BITHOCKEY_NAME forHTTPHeaderField:@"User-Agent"];
  [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
  [request setTimeoutInterval: 15];
  [request setHTTPMethod:@"POST"];
  NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
  [request setValue:contentType forHTTPHeaderField:@"Content-type"];
  
  NSMutableData *postBody =  [NSMutableData data];
  [postBody appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
  [postBody appendData:[@"Content-Disposition: form-data; name=\"timestamp\"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
  [postBody appendData:[timeString dataUsingEncoding:NSUTF8StringEncoding]];
  [postBody appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
  [request setHTTPBody:postBody];
  
  _statusCode = 200;
  
  _urlConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
  if (!_urlConnection) {
    BITHockeyLog(@"INFO: Pinging server could not start!");
  }
}


#pragma mark - Public Instance Methods (Configuration)

- (void)configureWithIdentifier:(NSString *)appIdentifier {
  [_appIdentifier release];
  _appIdentifier = [appIdentifier copy];
  
  [self initializeModules];
}

- (void)configureWithIdentifier:(NSString *)appIdentifier delegate:(id <BITHockeyManagerDelegate>)delegate {
  [_appIdentifier release];
  _appIdentifier = [appIdentifier copy];
  
  self.delegate = delegate;
  
  [self initializeModules];
}

- (void)startManager {
  if (!_validAppIdentifier || ![self isSetUpOnMainThread]) {
    [_crashManager returnToMainApplication];
    return;
  }
  
  BITHockeyLog(@"INFO: Starting HockeyManager");
  _startManagerIsInvoked = YES;
  
  // start CrashManager
  if (![self isCrashManagerDisabled]) {
    BITHockeyLog(@"INFO: Start CrashManager");
    if (_serverURL) {
      [_crashManager setServerURL:_serverURL];
    }
    [_crashManager startManager];
  } else {
    [_crashManager returnToMainApplication];
  }
  
  NSString *integrationFlowTime = [self integrationFlowTimeString];
  if (integrationFlowTime && [self integrationFlowStartedWithTimeString:integrationFlowTime]) {
    [self pingServerForIntegrationStartWorkflowWithTimeString:integrationFlowTime];
  }
}

- (void)validateStartManagerIsInvoked {
  if (_validAppIdentifier && !_startManagerIsInvoked) {
    NSLog(@"[HockeySDK] ERROR: You did not call [[BITHockeyManager sharedHockeyManager] startManager] to startup the HockeySDK! Please do so after setting up all properties. The SDK is NOT running.");
  }
}

- (void)setServerURL:(NSString *)aServerURL {
  // ensure url ends with a trailing slash
  if (![aServerURL hasSuffix:@"/"]) {
    aServerURL = [NSString stringWithFormat:@"%@/", aServerURL];
  }
  
  if (_serverURL != aServerURL) {
    _serverURL = [aServerURL copy];
  }
}

- (void)setDelegate:(id<BITHockeyManagerDelegate>)delegate {
  if (_delegate != delegate) {
    _delegate = delegate;
    
    if (_crashManager) {
      _crashManager.delegate = delegate;
    }
  }
}


- (void)testIdentifier {
  if (!_appIdentifier) {
    return;
  }
  
  NSDate *now = [NSDate date];
  NSString *timeString = [NSString stringWithFormat:@"%.0f", [now timeIntervalSince1970]];
  [self pingServerForIntegrationStartWorkflowWithTimeString:timeString];
}


#pragma mark - Private Instance Methods

- (void)initializeModules {
  _validAppIdentifier = [self checkValidityOfAppIdentifier:_appIdentifier];
  
  if (![self isSetUpOnMainThread]) return;
  
  _startManagerIsInvoked = NO;
  
  BITHockeyLog(@"INFO: Setup CrashManager");
  _crashManager = [[BITCrashManager alloc] initWithAppIdentifier:_appIdentifier];
  _crashManager.delegate = self.delegate;
  
  // if we don't initialize the BITCrashManager instance, then the delegate will not be invoked
  // leaving the app to never show the window if the developer provided an invalid app identifier
  if (!_validAppIdentifier) {
    [self logInvalidIdentifier:@"app identifier"];
    self.disableCrashManager = YES;
  }
  
  if ([self isCrashManagerDisabled])
    _crashManager.crashManagerActivated = NO;
}

#pragma mark - NSURLConnection Delegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
  if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
    _statusCode = [(NSHTTPURLResponse *)response statusCode];
  }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
  BITHockeyLog(@"ERROR: %@", [error localizedDescription]);
  
  [_urlConnection release];
  _urlConnection = nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
  [_urlConnection release];
  _urlConnection = nil;
  
  [self processServerResult];
}

- (void)processServerResult {
  if (_statusCode == 201) {
    BITHockeyLog(@"INFO: Ping accepted.");
  } else if (_statusCode == 200) {
    BITHockeyLog(@"INFO: Ping accepted. Server already knows.");
  } else if (_statusCode == 400) {
    BITHockeyLog(@"ERROR: App ID not found");
  } else {
    BITHockeyLog(@"ERROR: Unknown error");
  }
}

@end
