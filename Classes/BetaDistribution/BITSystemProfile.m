//
//  Author: Thomas Dohmke <thomas@dohmke.de>
//
//  Copyright (c) 2012 HockeyApp, Bit Stadium GmbH. All rights reserved.
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

#import <sys/sysctl.h>
#import "BITSystemProfile.h"
#import "BITSystemProfilePrivate.h"

@implementation BITSystemProfile

@synthesize usageStartTimestamp = _usageStartTimestamp;

+ (NSString *)deviceIdentifier {
  char buffer[128];
  
  io_registry_entry_t registry = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/");
  CFStringRef uuid = (CFStringRef)IORegistryEntryCreateCFProperty(registry, CFSTR(kIOPlatformUUIDKey), kCFAllocatorDefault, 0);
  IOObjectRelease(registry);
  CFStringGetCString(uuid, buffer, 128, kCFStringEncodingMacRoman);
  CFRelease(uuid);
  
  return [NSString stringWithCString:buffer encoding:NSUTF8StringEncoding];
}

+ (NSString *)deviceModel {
  NSString *model = nil;
  
  int error = 0;
  int value = 0;
	size_t length = sizeof(value);
  
  error = sysctlbyname("hw.model", NULL, &length, NULL, 0);
  if (error == 0) {
    char *cpuModel = (char *)malloc(sizeof(char) * length);
    if (cpuModel != NULL) {
      error = sysctlbyname("hw.model", cpuModel, &length, NULL, 0);
      if (error == 0) {
        model = [NSString stringWithUTF8String:cpuModel];
      }
      free(cpuModel);
    }
  }
  
  return model;
}

+ (NSString *)systemVersionString {
	NSString* version = nil;
  
	SInt32 major, minor, bugfix;
	OSErr err1 = Gestalt(gestaltSystemVersionMajor, &major);
	OSErr err2 = Gestalt(gestaltSystemVersionMinor, &minor);
	OSErr err3 = Gestalt(gestaltSystemVersionBugFix, &bugfix);
	if ((!err1) && (!err2) && (!err3)) {
		version = [NSString stringWithFormat:@"%ld.%ld.%ld", (long)major, (long)minor, (long)bugfix];
	}
  
	return version;
}

+ (BITSystemProfile *)sharedSystemProfile {
  static BITSystemProfile *sharedInstance = nil;
  static dispatch_once_t pred;
  
  dispatch_once(&pred, ^{
    sharedInstance = [BITSystemProfile alloc];
    sharedInstance = [sharedInstance init];
  });
  
  return sharedInstance;
}

- (id)init {
  if ((self = [super init])) {
    _usageStartTimestamp = nil;
  }
  return self;
}

- (void)dealloc {
  [_usageStartTimestamp release], _usageStartTimestamp = nil;
  
  [super dealloc];
}

- (void)startUsageForBundle:(NSBundle *)bundle {
  self.usageStartTimestamp = [NSDate date];
  
  BOOL newVersion = NO;
  
  if (![[NSUserDefaults standardUserDefaults] valueForKey:kBITUpdateUsageTimeForVersionString]) {
    newVersion = YES;
  } else {
    if ([(NSString *)[[NSUserDefaults standardUserDefaults] valueForKey:kBITUpdateUsageTimeForVersionString] compare:[bundle objectForInfoDictionaryKey:@"CFBundleVersion"]] != NSOrderedSame) {
      newVersion = YES;
    }
  }
  
  if (newVersion) {
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSinceReferenceDate]] forKey:kBITUpdateDateOfVersionInstallation];
    [[NSUserDefaults standardUserDefaults] setObject:[bundle objectForInfoDictionaryKey:@"CFBundleVersion"] forKey:kBITUpdateUsageTimeForVersionString];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithDouble:0] forKey:kBITUpdateUsageTimeOfCurrentVersion];
    [[NSUserDefaults standardUserDefaults] synchronize];
  }
}

- (void)startUsage {
  [self startUsageForBundle:[NSBundle mainBundle]];
}

- (void)stopUsage {
  double timeDifference = [[NSDate date] timeIntervalSinceReferenceDate] - [_usageStartTimestamp timeIntervalSinceReferenceDate];
  double previousTimeDifference = [(NSNumber *)[[NSUserDefaults standardUserDefaults] valueForKey:kBITUpdateUsageTimeOfCurrentVersion] doubleValue];
  
  [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithDouble:previousTimeDifference + timeDifference] forKey:kBITUpdateUsageTimeOfCurrentVersion];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)currentUsageString {
  double currentUsageTime = [[NSUserDefaults standardUserDefaults] doubleForKey:kBITUpdateUsageTimeOfCurrentVersion];
  
  if (currentUsageTime > 0) {
    // round (up) to 1 minute
    return [NSString stringWithFormat:@"%.0f", ceil(currentUsageTime / 60.0)*60];
  }
  else {
    return @"0";
  }
}

- (NSMutableArray *)systemDataForBundle:(NSBundle *)bundle {
	NSMutableArray *profileArray = [NSMutableArray array];
	NSArray *keys = [self profileKeys];
  
  NSString *uuid = [[self class] deviceIdentifier];
  [profileArray addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"udid", @"UDID", uuid, uuid, nil] forKeys:keys]];
  
  NSString *app_version = [bundle objectForInfoDictionaryKey:@"CFBundleVersion"];
  [profileArray addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"app_version", @"App Version", app_version, app_version, nil] forKeys:keys]];
  
  NSString *os_version = [[self class] systemVersionString];
  [profileArray addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"os_version", @"OS Version", os_version, os_version, nil] forKeys:keys]];
  [profileArray addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"os", @"OS", @"Mac OS", @"Mac OS", nil] forKeys:keys]];
  
  NSString *model = [[self class] deviceModel];
  [profileArray addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"model", @"Model", model, model, nil] forKeys:keys]];
  
  return profileArray;
}

- (NSMutableArray *)systemData {
  return [self systemDataForBundle:[NSBundle mainBundle]];
}

- (NSMutableArray *)systemUsageDataForBundle:(NSBundle *)bundle {
  NSMutableArray *profileArray = [self systemDataForBundle:bundle];
	NSArray *keys = [self profileKeys];

  NSString *usageTime = [self currentUsageString];
  [profileArray addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"usage_time", @"Usage Time", usageTime, usageTime, nil] forKeys:keys]];

  return profileArray;
}

- (NSMutableArray *)systemUsageData {
  return [self systemUsageDataForBundle:[NSBundle mainBundle]];
}

- (NSArray *)profileKeys {
  return [NSArray arrayWithObjects:@"key", @"displayKey", @"value", @"displayValue", nil];
}

@end
