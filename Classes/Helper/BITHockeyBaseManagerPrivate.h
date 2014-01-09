//
//  CNSHockeyBaseManager+Private.h
//  HockeySDK
//
//  Created by Andreas Linde on 04.06.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "BITHockeyBaseManager.h"


@interface BITHockeyBaseManager ()

@property (nonatomic, strong) NSString *appIdentifier;
@property (nonatomic, copy) NSString *userID;
@property (nonatomic, copy) NSString *userName;
@property (nonatomic, copy) NSString *userEmail;

- (id)initWithAppIdentifier:(NSString *)appIdentifier;

- (void)startManager;

- (void)reportError:(NSError *)error;
- (NSString *)encodedAppIdentifier;

- (NSString *)getDevicePlatform;
//- (NSString *)executableUUID;

- (NSData *)appendPostValue:(NSString *)value forKey:(NSString *)key;

- (NSDate *)parseRFC3339Date:(NSString *)dateString;

- (BOOL)addStringValueToKeychain:(NSString *)stringValue forKey:(NSString *)key;
- (NSString *)stringValueFromKeychainForKey:(NSString *)key;
- (BOOL)removeKeyFromKeychain:(NSString *)key;

@end
