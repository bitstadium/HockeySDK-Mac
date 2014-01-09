//
//  CNSHockeyBaseManager.m
//  HockeySDK
//
//  Created by Andreas Linde on 04.06.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "HockeySDK.h"
#import "HockeySDKPrivate.h"

#import "BITHockeyHelper.h"

#import "BITHockeyBaseManager.h"
#import "BITHockeyBaseManagerPrivate.h"

#import "BITKeychainItem.h"

#import <sys/sysctl.h>
#import <mach-o/ldsyms.h>

@implementation BITHockeyBaseManager {
  NSDateFormatter *_rfc3339Formatter;
}


- (id)init {
  if ((self = [super init])) {
    _appIdentifier = nil;
    _serverURL = BITHOCKEYSDK_URL;
    _userID = nil;
    _userName = nil;
    _userEmail = nil;
    
    NSLocale *enUSPOSIXLocale = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease];
    _rfc3339Formatter = [[NSDateFormatter alloc] init];
    [_rfc3339Formatter setLocale:enUSPOSIXLocale];
    [_rfc3339Formatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
    [_rfc3339Formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
  }
  return self;
}

- (id)initWithAppIdentifier:(NSString *)appIdentifier {
  if ((self = [self init])) {
    _appIdentifier = appIdentifier;
  }
  return self;
}

- (void)dealloc {
  [_serverURL release]; _serverURL = nil;
  
  [super dealloc];
}


#pragma mark - Private

- (void)reportError:(NSError *)error {
  BITHockeyLog(@"ERROR: %@", [error localizedDescription]);
}

- (NSString *)encodedAppIdentifier {
  return (_appIdentifier ? bit_URLEncodedString(_appIdentifier) : bit_URLEncodedString([[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"]));
}

- (NSString *)getDevicePlatform {
  size_t size;
  sysctlbyname("hw.machine", NULL, &size, NULL, 0);
  char *answer = (char*)malloc(size);
  sysctlbyname("hw.machine", answer, &size, NULL, 0);
  NSString *platform = [NSString stringWithCString:answer encoding: NSUTF8StringEncoding];
  free(answer);
  return platform;
}

#pragma mark - Keychain

- (BOOL)addStringValueToKeychain:(NSString *)stringValue forKey:(NSString *)key {
	if (!key || !stringValue)
		return NO;
  
  NSString *serviceName = [NSString stringWithFormat:@"%@.HockeySDK", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"]];
  
  BITGenericKeychainItem *item = [BITGenericKeychainItem genericKeychainItemForService:serviceName withUsername:key];
  
  if (item) {
    // update
    [item setPassword:stringValue];
    return YES;
  } else {
    if ([BITGenericKeychainItem addGenericKeychainItemForService:serviceName withUsername:key password:stringValue])
      return YES;
  }
  
  return NO;
}

- (NSString *)stringValueFromKeychainForKey:(NSString *)key {
	if (!key)
		return nil;
  
  NSString *serviceName = [NSString stringWithFormat:@"%@.HockeySDK", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"]];
  
  BITGenericKeychainItem *item = [BITGenericKeychainItem genericKeychainItemForService:serviceName withUsername:key];
  if (item) {
    NSString *pwd = [item password];
    return pwd;
  }
  
  return nil;
}

- (BOOL)removeKeyFromKeychain:(NSString *)key {
  NSString *serviceName = [NSString stringWithFormat:@"%@.HockeySDK", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"]];
  
  BITGenericKeychainItem *item = [BITGenericKeychainItem genericKeychainItemForService:serviceName withUsername:key];
  if (item) {
    [item removeFromKeychain];
    return YES;
  }
  
  return NO;
}


#pragma mark - Manager Control

- (void)startManager {
}


#pragma mark - Networking

- (NSData *)appendPostValue:(NSString *)value forKey:(NSString *)key {
  NSString *boundary = @"----FOO";
  
  NSMutableData *postBody = [NSMutableData data];
  
  [postBody appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
  [postBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\";\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
  [postBody appendData:[[NSString stringWithFormat:@"Content-Type: text\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
  [postBody appendData:[value dataUsingEncoding:NSUTF8StringEncoding]];    
  [postBody appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
  
  return postBody;
}


#pragma mark - Helpers

- (NSDate *)parseRFC3339Date:(NSString *)dateString {
  NSDate *date = nil;
  NSError *error = nil; 
  if (![_rfc3339Formatter getObjectValue:&date forString:dateString range:nil error:&error]) {
    BITHockeyLog(@"INFO: Invalid date '%@' string: %@", dateString, error);
  }
  
  return date;
}


@end
