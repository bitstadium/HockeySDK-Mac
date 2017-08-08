//
//  BITPersistenceTests.m
//  HockeySDK
//
//  Created by Patrick Dinger on 24/05/16.
//
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "BITPersistence.h"
#import "BITPersistencePrivate.h"

@interface BITPersistenceTests : XCTestCase

@property (strong) BITPersistence *sut;

@end

@implementation BITPersistenceTests

- (void)setUp {
    [super setUp];
    self.sut = [BITPersistence alloc];
    id mock = OCMPartialMock(self.sut);
    
    OCMStub([mock bundleIdentifier]).andReturn(@"com.testapp");    
}

- (void)tearDown {
    [super tearDown];
}

- (void)testAppHockeySDKDirectoryPath {
    NSString *path = [self.sut appHockeySDKDirectoryPath];
    
    NSString *appSupportPath = [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject] stringByStandardizingPath];
    NSString *validPath = [NSString stringWithFormat:@"%@/%@", appSupportPath, @"com.testapp/com.microsoft.HockeyApp"];
    
    XCTAssertEqualObjects(path, validPath);
}

@end
