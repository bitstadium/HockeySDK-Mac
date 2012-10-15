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

#import "BITSystemProfile.h"
#import <sys/sysctl.h>

@implementation BITSystemProfile

+ (NSArray *)standardProfile {
	NSMutableArray *profileArray = [NSMutableArray array];
	NSArray *profileKeys = [NSArray arrayWithObjects:@"key", @"displayKey", @"value", @"displayValue", nil];
  
  NSString *uuid = [[self class] deviceIdentifier];
  [profileArray addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"udid", @"UDID", uuid, uuid, nil] forKeys:profileKeys]];
  
  NSString *app_version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
  [profileArray addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"app_version", @"App Version", app_version, app_version, nil] forKeys:profileKeys]];
  
  NSString *os_version = [[self class] systemVersionString];
  [profileArray addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"os_version", @"OS Version", os_version, os_version, nil] forKeys:profileKeys]];
  [profileArray addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"os", @"OS", @"Mac OS", @"Mac OS", nil] forKeys:profileKeys]];
  
  NSString *model = [[self class] deviceModel];
  [profileArray addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"model", @"Model", model, model, nil] forKeys:profileKeys]];
  
  return profileArray;
}

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

@end
