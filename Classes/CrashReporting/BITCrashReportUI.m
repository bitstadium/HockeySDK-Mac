#import "BITCrashReportUI.h"

#import <HockeySDK/HockeySDK.h>
#import "HockeySDKPrivate.h"

#import "BITHockeyBaseManagerPrivate.h"
#import "BITCrashManagerPrivate.h"
#import "BITCrashMetaData.h"

#import <sys/sysctl.h>


@interface BITCrashReportUI ()

- (void) askCrashReportDetails;
- (void) endCrashReporter;

@property (nonatomic, strong) BITCrashManager *crashManager;
@property (nonatomic, strong) NSString        *applicationName;
@property (nonatomic, strong) NSMutableString *logContent;
@property (nonatomic, strong) NSString        *crashLogContent;

// Redeclare BITCrashReportUI properties with readwrite attribute.
@property (nonatomic, readwrite) BOOL nibDidLoadSuccessfully;

@end

static const CGFloat kUserHeight = 50;
static const CGFloat kCommentsHeight = 105;
static const CGFloat kDetailsHeight = 285;

@implementation BITCrashReportUI {
  IBOutlet NSTextField *nameTextField;
  IBOutlet NSTextField *emailTextField;
  IBOutlet NSTextField *descriptionTextField;
  IBOutlet NSTextView  *crashLogTextView;
  
  IBOutlet NSTextField *nameTextFieldTitle;
  IBOutlet NSTextField *emailTextFieldTitle;
  
  IBOutlet NSTextField *introductionText;
  IBOutlet NSTextField *commentsTextFieldTitle;
  IBOutlet NSTextField *problemDescriptionTextFieldTitle;
  
  IBOutlet NSTextField *noteText;
  
  IBOutlet NSButton *disclosureButton;
  IBOutlet NSButton *showButton;
  IBOutlet NSButton *hideButton;
  IBOutlet NSButton *cancelButton;
  IBOutlet NSButton *submitButton;
}


- (instancetype)initWithManager:(BITCrashManager *)crashManager crashReport:(NSString *)crashReport logContent:(NSString *)logContent applicationName:(NSString *)applicationName askUserDetails:(BOOL)askUserDetails {
  
  self = [super initWithWindowNibName: @"BITCrashReportUI"];
  if (self != nil) {
    _crashManager = crashManager;
    _crashLogContent = [crashReport copy];
    _logContent = [logContent copy];
    _applicationName = [applicationName copy];
    _userName = @"";
    _userEmail = @"";
    _showComments = YES;
    _showDetails = NO;
    _showUserDetails = askUserDetails;
    _nibDidLoadSuccessfully = NO;

    NSRect windowFrame = [[self window] frame];
    windowFrame.size = NSMakeSize(windowFrame.size.width, windowFrame.size.height - kDetailsHeight);
    windowFrame.origin.y -= kDetailsHeight;
    
    if (!askUserDetails) {
      windowFrame.size = NSMakeSize(windowFrame.size.width, windowFrame.size.height - kUserHeight);
      windowFrame.origin.y -= kUserHeight;
      
      NSRect frame = commentsTextFieldTitle.frame;
      frame.origin.y += kUserHeight;
      commentsTextFieldTitle.frame = frame;

      frame = disclosureButton.frame;
      frame.origin.y += kUserHeight;
      disclosureButton.frame = frame;

      frame = descriptionTextField.frame;
      frame.origin.y += kUserHeight;
      descriptionTextField.frame = frame;
    }
    
    [[self window] setFrame: windowFrame
                    display: YES
                    animate: NO];
    [[self window] center];
    
  }
  return self;
}


- (void)awakeFromNib {
  self.nibDidLoadSuccessfully = YES;
  [crashLogTextView setEditable:NO];
  if ([crashLogTextView respondsToSelector:@selector(setAutomaticSpellingCorrectionEnabled:)]) {
    [crashLogTextView setAutomaticSpellingCorrectionEnabled:NO];
  }
}


- (void)endCrashReporter {
  [self close];
}


- (IBAction)showComments: (id) sender {
  NSRect windowFrame = [[self window] frame];
  
  if ([sender intValue]) {
    [self setShowComments: NO];
    
    windowFrame.size = NSMakeSize(windowFrame.size.width, windowFrame.size.height + kCommentsHeight);
    windowFrame.origin.y -= kCommentsHeight;
    [[self window] setFrame: windowFrame
                    display: YES
                    animate: YES];
    
    [self setShowComments: YES];
  } else {
    [self setShowComments: NO];
    
    windowFrame.size = NSMakeSize(windowFrame.size.width, windowFrame.size.height - kCommentsHeight);
    windowFrame.origin.y += kCommentsHeight;
    [[self window] setFrame: windowFrame
                    display: YES
                    animate: YES];
  }
}


- (IBAction)showDetails:(id) __unused sender {
  NSRect windowFrame = [[self window] frame];
  
  windowFrame.size = NSMakeSize(windowFrame.size.width, windowFrame.size.height + kDetailsHeight);
  windowFrame.origin.y -= kDetailsHeight;
  [[self window] setFrame: windowFrame
                  display: YES
                  animate: YES];
  
  [self setShowDetails:YES];
  
}


- (IBAction)hideDetails:(id) __unused sender {
  NSRect windowFrame = [[self window] frame];
  
  [self setShowDetails:NO];
  
  windowFrame.size = NSMakeSize(windowFrame.size.width, windowFrame.size.height - kDetailsHeight);
  windowFrame.origin.y += kDetailsHeight;
  [[self window] setFrame: windowFrame
                  display: YES
                  animate: YES];
}


- (IBAction)cancelReport:(id) __unused sender {
  [self.crashManager handleUserInput:BITCrashManagerUserInputDontSend withUserProvidedMetaData:nil];
  
  [self endCrashReporter];
}

- (IBAction)submitReport:(id) __unused sender {
  [showButton setEnabled:NO];
  [hideButton setEnabled:NO];
  [cancelButton setEnabled:NO];
  [submitButton setEnabled:NO];
  
  [[self window] makeFirstResponder: nil];
  
  BITCrashMetaData *crashMetaData = [[BITCrashMetaData alloc] init];
  if (_showUserDetails) {
    crashMetaData.userName = [nameTextField stringValue];
    crashMetaData.userEmail = [emailTextField stringValue];
  }
  crashMetaData.userDescription = [descriptionTextField stringValue];
  
  [self.crashManager handleUserInput:BITCrashManagerUserInputSend withUserProvidedMetaData:crashMetaData];
  
  [self endCrashReporter];
}


- (void)askCrashReportDetails {
#define DISTANCE_BETWEEN_BUTTONS		3
  
  NSString *title = BITHockeyLocalizedString(@"WindowTitle", @"");
  [[self window] setTitle:[NSString stringWithFormat:title, self.applicationName]];
  
  [[nameTextFieldTitle cell] setTitle:BITHockeyLocalizedString(@"NameTextTitle", @"")];
  [[nameTextField cell] setTitle:self.userName];
  if ([[nameTextField cell] respondsToSelector:@selector(setUsesSingleLineMode:)]) {
    [[nameTextField cell] setUsesSingleLineMode:YES];
  }
  
  [[emailTextFieldTitle cell] setTitle:BITHockeyLocalizedString(@"EmailTextTitle", @"")];
  [[emailTextField cell] setTitle:self.userEmail];
  if ([[emailTextField cell] respondsToSelector:@selector(setUsesSingleLineMode:)]) {
    [[emailTextField cell] setUsesSingleLineMode:YES];
  }

  title = BITHockeyLocalizedString(@"IntroductionText", @"");
  [[introductionText cell] setTitle:[NSString stringWithFormat:title, self.applicationName]];
  [[commentsTextFieldTitle cell] setTitle:BITHockeyLocalizedString(@"CommentsDisclosureTitle", @"")];
  [[problemDescriptionTextFieldTitle cell] setTitle:BITHockeyLocalizedString(@"ProblemDetailsTitle", @"")];

  [[descriptionTextField cell] setPlaceholderString:BITHockeyLocalizedString(@"UserDescriptionPlaceholder", @"")];
  [noteText setStringValue:BITHockeyLocalizedString(@"PrivacyNote", @"")];
  
  [showButton setTitle:BITHockeyLocalizedString(@"ShowDetailsButtonTitle", @"")];
  [hideButton setTitle:BITHockeyLocalizedString(@"HideDetailsButtonTitle", @"")];
  [cancelButton setTitle:BITHockeyLocalizedString(@"CancelButtonTitle", @"")];
  [submitButton setTitle:BITHockeyLocalizedString(@"SendButtonTitle", @"")];
  
  // adjust button sizes
  NSDictionary *attrs = @{NSFontAttributeName: [submitButton font]};
  NSSize titleSize = [[submitButton title] sizeWithAttributes: attrs];
	titleSize.width += (16 + 8) * 2;	// 16 px for the end caps plus 8 px padding at each end
	NSRect submitBtnBox = [submitButton frame];
	submitBtnBox.origin.x += submitBtnBox.size.width -titleSize.width;
	submitBtnBox.size.width = titleSize.width;
	[submitButton setFrame: submitBtnBox];
  
  titleSize = [[cancelButton title] sizeWithAttributes: attrs];
	titleSize.width += (16 + 8) * 2;	// 16 px for the end caps plus 8 px padding at each end
	NSRect cancelBtnBox = [cancelButton frame];
	cancelBtnBox.origin.x = submitBtnBox.origin.x -DISTANCE_BETWEEN_BUTTONS -titleSize.width;
	cancelBtnBox.size.width = titleSize.width;
	[cancelButton setFrame: cancelBtnBox];

  titleSize = [[showButton title] sizeWithAttributes: attrs];
	titleSize.width += (16 + 8) * 2;	// 16 px for the end caps plus 8 px padding at each end
	NSRect showBtnBox = [showButton frame];
	showBtnBox.size.width = titleSize.width;
	[showButton setFrame: showBtnBox];

  titleSize = [[hideButton title] sizeWithAttributes: attrs];
	titleSize.width += (16 + 8) * 2;	// 16 px for the end caps plus 8 px padding at each end
	NSRect hideBtnBox = [hideButton frame];
	hideBtnBox.size.width = titleSize.width;
	[hideButton setFrame: showBtnBox];
    
  NSString *logTextViewContent = [self.crashLogContent copy];
  
  if (self.logContent)
    logTextViewContent = [NSString stringWithFormat:@"%@\n\n%@", logTextViewContent, self.logContent];
  
  [crashLogTextView setString:logTextViewContent];
}


- (void)dealloc {
   _crashLogContent = nil;
   _logContent = nil;
   _applicationName = nil;
}


#pragma mark NSTextField Delegate

- (BOOL)control:(NSControl *) __unused control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
  BOOL commandHandled = NO;
  
  if (commandSelector == @selector(insertNewline:)) {
    [textView insertNewlineIgnoringFieldEditor:self];
    commandHandled = YES;
  }
  
  return commandHandled;
}

@end

