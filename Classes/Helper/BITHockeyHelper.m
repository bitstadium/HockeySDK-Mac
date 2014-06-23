/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
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


#import "BITHockeyHelper.h"
#import "HockeySDK.h"
#import "HockeySDKPrivate.h"
#import "BITKeychainItem.h"


#pragma mark NSString helpers

NSString *bit_URLEncodedString(NSString *inputString) {
  return CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                   (__bridge CFStringRef)inputString,
                                                                   NULL,
                                                                   CFSTR("!*'();:@&=+$,/?%#[]"),
                                                                   kCFStringEncodingUTF8)
                           );
}

NSString *bit_URLDecodedString(NSString *inputString) {
  return CFBridgingRelease(CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault,
                                                                                   (__bridge CFStringRef)inputString,
                                                                                   CFSTR(""),
                                                                                   kCFStringEncodingUTF8)
                           );
}

NSComparisonResult bit_versionCompare(NSString *stringA, NSString *stringB) {
  // Extract plain version number from self
  NSString *plainSelf = stringA;
  NSRange letterRange = [plainSelf rangeOfCharacterFromSet: [NSCharacterSet letterCharacterSet]];
  if (letterRange.length)
    plainSelf = [plainSelf substringToIndex: letterRange.location];
	
  // Extract plain version number from other
  NSString *plainOther = stringB;
  letterRange = [plainOther rangeOfCharacterFromSet: [NSCharacterSet letterCharacterSet]];
  if (letterRange.length)
    plainOther = [plainOther substringToIndex: letterRange.location];
	
  // Compare plain versions
  NSComparisonResult result = [plainSelf compare:plainOther options:NSNumericSearch];
	
  // If plain versions are equal, compare full versions
  if (result == NSOrderedSame)
    result = [stringA compare:stringB options:NSNumericSearch];
	
  // Done
  return result;
}

NSString *bit_appName(NSString *placeHolderString) {
  NSString *appName = [[NSBundle mainBundle] localizedInfoDictionary][@"CFBundleDisplayName"];
  if (!appName)
    appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?: placeHolderString;
  
  return appName;
}

NSString *bit_UUID(void) {
  CFUUIDRef theToken = CFUUIDCreate(NULL);
  CFStringRef uuidStringRef = CFUUIDCreateString(NULL, theToken);
  CFRelease(theToken);
  NSString *stringUUID = [NSString stringWithString:(__bridge NSString *) uuidStringRef];
  CFRelease(uuidStringRef);
  return stringUUID;
}

NSString *bit_settingsDir(void) {
  static NSString *settingsDir = nil;
  static dispatch_once_t predSettingsDir;
  
  dispatch_once(&predSettingsDir, ^{
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    
    // temporary directory for crashes grabbed from PLCrashReporter
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDir = paths[0];
    settingsDir = [[cacheDir stringByAppendingPathComponent:bundleIdentifier] stringByAppendingPathComponent:BITHOCKEY_IDENTIFIER];
    
    if (![fileManager fileExistsAtPath:settingsDir]) {
      NSDictionary *attributes = @{NSFilePosixPermissions: @0755UL};
      NSError *theError = NULL;
      
      [fileManager createDirectoryAtPath:settingsDir withIntermediateDirectories: YES attributes: attributes error: &theError];
    }
  });
  
  return settingsDir;
}

#pragma mark - Keychain

BOOL bit_addStringValueToKeychain(NSString *stringValue, NSString *key) {
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

NSString *bit_stringValueFromKeychainForKey(NSString *key) {
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

BOOL bit_removeKeyFromKeychain(NSString *key) {
  NSString *serviceName = [NSString stringWithFormat:@"%@.HockeySDK", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"]];
  
  BITGenericKeychainItem *item = [BITGenericKeychainItem genericKeychainItemForService:serviceName withUsername:key];
  if (item) {
    [item removeFromKeychain];
    return YES;
  }
  
  return NO;
}
