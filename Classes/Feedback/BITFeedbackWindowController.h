//
//  BITFeedbackWindowController.h
//  HockeySDK
//
//  Created by Andreas Linde on 28.05.13.
//
//

#import <Cocoa/Cocoa.h>

@class BITFeedbackManager;

@interface BITFeedbackWindowController : NSWindowController

- (id)initWithManager:(BITFeedbackManager *)feedbackManager;

@end
