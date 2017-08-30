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

@property (nonatomic, strong) IBOutlet NSTextField *nameTextField;
@property (nonatomic, strong) IBOutlet NSTextField *emailTextField;
@property (nonatomic, strong) IBOutlet NSTextField *descriptionTextField;
@property (nonatomic, strong) IBOutlet NSTextView  *crashLogTextView;

@property (nonatomic, strong) IBOutlet NSTextField *nameTextFieldTitle;
@property (nonatomic, strong) IBOutlet NSTextField *emailTextFieldTitle;

@property (nonatomic, strong) IBOutlet NSTextField *introductionText;
@property (nonatomic, strong) IBOutlet NSTextField *commentsTextFieldTitle;
@property (nonatomic, strong) IBOutlet NSTextField *problemDescriptionTextFieldTitle;

@property (nonatomic, strong) IBOutlet NSTextField *noteText;

@property (nonatomic, strong) IBOutlet NSButton *disclosureButton;
@property (nonatomic, strong) IBOutlet NSButton *showButton;
@property (nonatomic, strong) IBOutlet NSButton *hideButton;
@property (nonatomic, strong) IBOutlet NSButton *cancelButton;
@property (nonatomic, strong) IBOutlet NSButton *submitButton;

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

@implementation BITCrashReportUI

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
      
      NSRect frame = _commentsTextFieldTitle.frame;
      frame.origin.y += kUserHeight;
      _commentsTextFieldTitle.frame = frame;

      frame = _disclosureButton.frame;
      frame.origin.y += kUserHeight;
      _disclosureButton.frame = frame;

      frame = _descriptionTextField.frame;
      frame.origin.y += kUserHeight;
      _descriptionTextField.frame = frame;
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
  [self.crashLogTextView setEditable:NO];
  if ([self.crashLogTextView respondsToSelector:@selector(setAutomaticSpellingCorrectionEnabled:)]) {
    [self.crashLogTextView setAutomaticSpellingCorrectionEnabled:NO];
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
  [self.showButton setEnabled:NO];
  [self.hideButton setEnabled:NO];
  [self.cancelButton setEnabled:NO];
  [self.submitButton setEnabled:NO];
  
  [[self window] makeFirstResponder: nil];
  
  BITCrashMetaData *crashMetaData = [[BITCrashMetaData alloc] init];
  if (self.showUserDetails) {
    crashMetaData.userName = [self.nameTextField stringValue];
    crashMetaData.userEmail = [self.emailTextField stringValue];
  }
  crashMetaData.userDescription = [self.descriptionTextField stringValue];
  
  [self.crashManager handleUserInput:BITCrashManagerUserInputSend withUserProvidedMetaData:crashMetaData];
  
  [self endCrashReporter];
}


- (void)askCrashReportDetails {
#define DISTANCE_BETWEEN_BUTTONS		3
  
  NSString *title = [NSString stringWithFormat:BITHockeyLocalizedString(@"WindowTitle", @""), self.applicationName];
  [[self window] setTitle:title];
  
  [[self.nameTextFieldTitle cell] setTitle:BITHockeyLocalizedString(@"NameTextTitle", @"")];
  [[self.nameTextField cell] setTitle:self.userName];
  if ([[self.nameTextField cell] respondsToSelector:@selector(setUsesSingleLineMode:)]) {
    [[self.nameTextField cell] setUsesSingleLineMode:YES];
  }
  
  [[self.emailTextFieldTitle cell] setTitle:BITHockeyLocalizedString(@"EmailTextTitle", @"")];
  [[self.emailTextField cell] setTitle:self.userEmail];
  if ([[self.emailTextField cell] respondsToSelector:@selector(setUsesSingleLineMode:)]) {
    [[self.emailTextField cell] setUsesSingleLineMode:YES];
  }

  title = BITHockeyLocalizedString(@"IntroductionText", @"");
  [[self.introductionText cell] setTitle:[NSString stringWithFormat:title, self.applicationName]];
  [[self.commentsTextFieldTitle cell] setTitle:BITHockeyLocalizedString(@"CommentsDisclosureTitle", @"")];
  [[self.problemDescriptionTextFieldTitle cell] setTitle:BITHockeyLocalizedString(@"ProblemDetailsTitle", @"")];

  [[self.descriptionTextField cell] setPlaceholderString:BITHockeyLocalizedString(@"UserDescriptionPlaceholder", @"")];
  [self.noteText setStringValue:BITHockeyLocalizedString(@"PrivacyNote", @"")];
  
  [self.showButton setTitle:BITHockeyLocalizedString(@"ShowDetailsButtonTitle", @"")];
  [self.hideButton setTitle:BITHockeyLocalizedString(@"HideDetailsButtonTitle", @"")];
  [self.cancelButton setTitle:BITHockeyLocalizedString(@"CancelButtonTitle", @"")];
  [self.submitButton setTitle:BITHockeyLocalizedString(@"SendButtonTitle", @"")];
  
  // adjust button sizes
  NSDictionary *attrs = @{NSFontAttributeName: [self.submitButton font]};
  NSSize titleSize = [[self.submitButton title] sizeWithAttributes: attrs];
	titleSize.width += (16 + 8) * 2;	// 16 px for the end caps plus 8 px padding at each end
	NSRect submitBtnBox = [self.submitButton frame];
	submitBtnBox.origin.x += submitBtnBox.size.width -titleSize.width;
	submitBtnBox.size.width = titleSize.width;
	[self.submitButton setFrame: submitBtnBox];
  
  titleSize = [[self.cancelButton title] sizeWithAttributes: attrs];
	titleSize.width += (16 + 8) * 2;	// 16 px for the end caps plus 8 px padding at each end
	NSRect cancelBtnBox = [self.cancelButton frame];
	cancelBtnBox.origin.x = submitBtnBox.origin.x -DISTANCE_BETWEEN_BUTTONS -titleSize.width;
	cancelBtnBox.size.width = titleSize.width;
	[self.cancelButton setFrame: cancelBtnBox];

  titleSize = [[self.showButton title] sizeWithAttributes: attrs];
	titleSize.width += (16 + 8) * 2;	// 16 px for the end caps plus 8 px padding at each end
	NSRect showBtnBox = [self.showButton frame];
	showBtnBox.size.width = titleSize.width;
	[self.showButton setFrame: showBtnBox];

  titleSize = [[self.hideButton title] sizeWithAttributes: attrs];
	titleSize.width += (16 + 8) * 2;	// 16 px for the end caps plus 8 px padding at each end
	NSRect hideBtnBox = [self.hideButton frame];
	hideBtnBox.size.width = titleSize.width;
	[self.hideButton setFrame: showBtnBox];
    
  NSString *logTextViewContent = [self.crashLogContent copy];
  
  if (self.logContent)
    logTextViewContent = [NSString stringWithFormat:@"%@\n\n%@", logTextViewContent, self.logContent];
  
  [self.crashLogTextView setString:logTextViewContent];
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

