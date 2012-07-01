/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Kent Sutherland
 *
 * Copyright (c) 2011 Andreas Linde & Kent Sutherland.
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

#import "CNSCrashReportUI.h"
#import "CNSCrashReportManager.h"
#import <sys/sysctl.h>
#import <CrashReporter/CrashReporter.h>


@interface CNSCrashReportUI(private)
- (void) askCrashReportDetails;
- (void) endCrashReporter;
@end

const CGFloat kCommentsHeight = 105;
const CGFloat kDetailsHeight = 285;

@implementation CNSCrashReportUI

- (id)initWithManager:(CNSCrashReportManager *)crashReportManager crashReportFile:(NSString *)crashReportFile crashReport:(NSString *)crashReport logContent:(NSString *)logContent companyName:(NSString *)companyName applicationName:(NSString *)applicationName {
  
  self = [super initWithWindowNibName: @"CNSCrashReportUI"];
  
  if ( self != nil) {
    _xml = nil;
    _crashReportManager = crashReportManager;
    _crashFile = [crashReportFile copy];
    _crashLogContent = [crashReport copy];
    _logContent = [logContent copy];
    _companyName = [companyName copy];
    _applicationName = applicationName;
    [self setShowComments: YES];
    [self setShowDetails: NO];
    
    NSRect windowFrame = [[self window] frame];
    windowFrame.size = NSMakeSize(windowFrame.size.width, windowFrame.size.height - kDetailsHeight);
    windowFrame.origin.y -= kDetailsHeight;
    [[self window] setFrame: windowFrame
                    display: YES
                    animate: NO];
    
  }
  return self;  
}


- (void)awakeFromNib {
	crashLogTextView.editable = NO;
	crashLogTextView.selectable = NO;
	crashLogTextView.automaticSpellingCorrectionEnabled = NO;
}


- (void) endCrashReporter {
  [self close];
}


- (IBAction) showComments: (id) sender {
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


- (IBAction) showDetails:(id)sender {
  NSRect windowFrame = [[self window] frame];
  
  windowFrame.size = NSMakeSize(windowFrame.size.width, windowFrame.size.height + kDetailsHeight);
  windowFrame.origin.y -= kDetailsHeight;
  [[self window] setFrame: windowFrame
                  display: YES
                  animate: YES];
  
  [self setShowDetails:YES];
  
}


- (IBAction) hideDetails:(id)sender {
  NSRect windowFrame = [[self window] frame];
  
  [self setShowDetails:NO];
  
  windowFrame.size = NSMakeSize(windowFrame.size.width, windowFrame.size.height - kDetailsHeight);
  windowFrame.origin.y += kDetailsHeight;
  [[self window] setFrame: windowFrame
                  display: YES
                  animate: YES];
}


- (IBAction) cancelReport:(id)sender {
  [self endCrashReporter];
  [NSApp stopModal];
  
  [_crashReportManager cancelReport];
}

- (IBAction) submitReport:(id)sender {
  [submitButton setEnabled:NO];
  
  [[self window] makeFirstResponder: nil];
  
  [_crashReportManager sendReportCrash:_crashFile crashDescription:[descriptionTextField stringValue]];
  [_crashLogContent release];
  _crashLogContent = nil;
  
  [self endCrashReporter];
  [NSApp stopModal];
}


- (void) askCrashReportDetails {
  [[self window] setTitle:[NSString stringWithFormat:CNSLocalizedString(@"WindowTitle", @""), _applicationName]];
  
  [introductionTextFieldCell setTitle:[NSString stringWithFormat:CNSLocalizedString(@"IntroductionText", @""), _applicationName, _companyName]];
  [commentsTextFieldCell setTitle:CNSLocalizedString(@"CommentsDisclosureTitle", @"")];
  [problemDescriptionTextFieldCell setTitle:CNSLocalizedString(@"ProblemDetailsTitle", @"")];

  [[descriptionTextField cell] setPlaceholderString:CNSLocalizedString(@"UserDescriptionPlaceholder", @"")];
  [noteText setStringValue:CNSLocalizedString(@"PrivacyNote", @"")];
  
  [showButton setTitle:CNSLocalizedString(@"ShowDetailsButtonTitle", @"")];
  [hideButton setTitle:CNSLocalizedString(@"HideDetailsButtonTitle", @"")];
  [cancelButton setTitle:CNSLocalizedString(@"CancelButtonTitle", @"")];
  [submitButton setTitle:CNSLocalizedString(@"SendButtonTitle", @"")];
  
  NSString *logTextViewContent = [_crashLogContent copy];
  
  if (_logContent)
    logTextViewContent = [NSString stringWithFormat:@"%@\n\n%@", logTextViewContent, _logContent];
  
  [crashLogTextView setString:logTextViewContent];
  
  NSBeep();
  [NSApp runModalForWindow:[self window]];
}


- (void)dealloc {
  [_crashFile release]; _crashFile = nil;
  [_crashLogContent release]; _crashLogContent = nil;
  [_logContent release]; _logContent = nil;
  [_companyName release]; _companyName = nil;
  _crashReportManager = nil;
  
  [super dealloc];
}


- (BOOL)showComments {
  return showComments;
}


- (void)setShowComments:(BOOL)value {
  showComments = value;
}


- (BOOL)showDetails {
  return showDetails;
}


- (void)setShowDetails:(BOOL)value {
  showDetails = value;
}

#pragma mark NSTextField Delegate

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
  BOOL commandHandled = NO;
  
  if (commandSelector == @selector(insertNewline:)) {
    [textView insertNewlineIgnoringFieldEditor:self];
    commandHandled = YES;
  }
  
  return commandHandled;
}

@end

