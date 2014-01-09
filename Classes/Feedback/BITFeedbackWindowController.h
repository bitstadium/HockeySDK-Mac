//
//  BITFeedbackWindowController.h
//  HockeySDK
//
//  Created by Andreas Linde on 28.05.13.
//
//

#import <Cocoa/Cocoa.h>

@class BITFeedbackManager;

@interface BITFeedbackWindowController : NSWindowController {
@private
  BITFeedbackManager *_manager;
  NSDateFormatter *_lastUpdateDateFormatter;

  NSView *_userDataView;
  NSTextField *_userNameTextField;
  NSTextField *_userEmailTextField;
  NSButton *_userDataContinueButton;
  
  NSString *_userName;
  NSString *_userEmail;
  
  NSView *_feedbackView;
  NSView *_feedbackEmptyView;
  NSScrollView *_feedbackScrollView;
  NSTableView *_feedbackTableView;

  NSTextView *_messageTextField;
  NSAttributedString *_messageText;

  NSView *_statusBarComposeView;
  NSButton *_sendMessageButton;
  
  NSView *_statusBarDefaultView;
  NSProgressIndicator *_statusBarLoadingIndicator;
  NSTextField *_statusBarTextField;
  NSButton *_statusBarRefreshButton;
}

- (id)initWithManager:(BITFeedbackManager *)feedbackManager;

@end
