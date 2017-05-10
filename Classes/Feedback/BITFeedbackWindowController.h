#import <Cocoa/Cocoa.h>

@class BITFeedbackManager;

@interface BITFeedbackWindowController : NSWindowController

- (id)initWithManager:(BITFeedbackManager *)feedbackManager;

- (void)prepareWithItems:(NSArray *)items;

@end
