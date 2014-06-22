/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2013-2014 HockeyApp, Bit Stadium GmbH.
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

#import "BITFeedbackWindowController.h"

#import "HockeySDK.h"
#import "HockeySDKPrivate.h"

#import "BITHockeyBaseManagerPrivate.h"
#import "BITFeedbackManagerPrivate.h"
#import "BITFeedbackMessageCellView.h"

#import "BITTextView.h"
#import "BITColoredView.h"
#import "BITTextFieldCell.h"


@interface BITFeedbackWindowController () <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, unsafe_unretained) BITFeedbackManager *manager;
@property (nonatomic, strong) NSDateFormatter *lastUpdateDateFormatter;

@property (unsafe_unretained) IBOutlet NSView *userDataView;

@property (unsafe_unretained) IBOutlet BITColoredView *mainBackgroundView;

@property (unsafe_unretained) IBOutlet BITColoredView *userDataBoxView;
@property (unsafe_unretained) IBOutlet NSTextField *contactInfoTextField;
@property (unsafe_unretained) IBOutlet NSTextField *userNameTextField;
@property (unsafe_unretained) IBOutlet NSTextField *userEmailTextField;
@property (unsafe_unretained) IBOutlet NSButton *userDataContinueButton;

@property (nonatomic, copy) NSString *userName;
@property (nonatomic, copy) NSString *userEmail;

@property (unsafe_unretained) IBOutlet BITColoredView *feedbackListBackgroundView;
@property (unsafe_unretained) IBOutlet NSView *feedbackView;
@property (unsafe_unretained) IBOutlet NSView *feedbackEmptyView;
@property (unsafe_unretained) IBOutlet NSImageView *feedbackEmptyAppImageView;

@property (unsafe_unretained) IBOutlet BITColoredView *feedbackComposeBackgroundView;
@property (unsafe_unretained) IBOutlet BITTextView *feedbackComposeTextView;

@property (unsafe_unretained) IBOutlet NSScrollView *feedbackScrollView;
@property (unsafe_unretained) IBOutlet NSTableView *feedbackTableView;

@property (unsafe_unretained) IBOutlet NSTextView *messageTextField;
@property (nonatomic, strong) NSAttributedString *messageText;

@property (unsafe_unretained) IBOutlet BITColoredView *horizontalLine;
@property (unsafe_unretained) IBOutlet BITColoredView *statusBar;
@property (unsafe_unretained) IBOutlet NSView *statusBarComposeView;
@property (unsafe_unretained) IBOutlet NSButton *sendMessageButton;

@property (unsafe_unretained) IBOutlet NSView *statusBarDefaultView;
@property (unsafe_unretained) IBOutlet NSProgressIndicator *statusBarLoadingIndicator;
@property (unsafe_unretained) IBOutlet NSTextField *statusBarTextField;
@property (unsafe_unretained) IBOutlet NSButton *statusBarRefreshButton;

- (BOOL)canContinueUserDataView;
- (BOOL)canSendMessage;

- (IBAction)validateUserData:(id)sender;
- (IBAction)sendMessage:(id)sender;
- (IBAction)reloadList:(id)sender;

@end

@implementation BITFeedbackWindowController


- (id)initWithManager:(BITFeedbackManager *)feedbackManager {
  self = [super initWithWindowNibName: @"BITFeedbackWindowController"];
  if (self) {
    _manager = feedbackManager;
    
    self.lastUpdateDateFormatter = [[[NSDateFormatter alloc] init] autorelease];
		[self.lastUpdateDateFormatter setDateStyle:NSDateFormatterShortStyle];
		[self.lastUpdateDateFormatter setTimeStyle:NSDateFormatterShortStyle];
		self.lastUpdateDateFormatter.locale = [NSLocale currentLocale];
  }
  
  return self;
}

- (void)awakeFromNib {
  NSImage *appIcon = [NSImage imageNamed:@"NSApplicationIcon"];
  appIcon = [self imageToGreyImage:appIcon];
  appIcon = [self imageWithReducedAlpha:0.5 fromImage:appIcon];
  [self.feedbackEmptyAppImageView setImage:appIcon];
  
  [self.feedbackComposeTextView setPlaceHolderString:@"Your Feedback"];
  
  [self.feedbackListBackgroundView setViewBackgroundColor:[NSColor colorWithCalibratedRed:0.91 green:0.92 blue:0.93 alpha:1.0]];
  [self.feedbackComposeBackgroundView setViewBackgroundColor:[NSColor whiteColor]];
  [self.horizontalLine setViewBackgroundColor:[NSColor colorWithCalibratedRed:0.79 green:0.82 blue:0.83 alpha:1.0]];
  [self.statusBar setViewBackgroundColor:[NSColor whiteColor]];
  [self.mainBackgroundView setViewBackgroundColor:[NSColor colorWithCalibratedRed:0.91 green:0.92 blue:0.93 alpha:1.0]];
  [self.userDataBoxView setViewBackgroundColor:[NSColor colorWithCalibratedRed:0.88 green:0.89 blue:0.90 alpha:1.0]];
  [self.userDataBoxView setViewBorderWidth:1.0];
  [self.userDataBoxView setViewBorderColor:[NSColor colorWithCalibratedRed:0.82 green:0.85 blue:0.86 alpha:1.0]];
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(tableViewFrameChanged:)
                                               name:NSViewFrameDidChangeNotification
                                             object:self.feedbackTableView];
}

- (void)windowDidLoad {
  [super windowDidLoad];
  
  // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(startLoadingIndicator)
                                               name:BITHockeyFeedbackMessagesLoadingStarted
                                             object:nil];
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(updateList)
                                               name:BITHockeyFeedbackMessagesLoadingFinished
                                             object:nil];
  
  [self.statusBarRefreshButton setHidden:YES];
  [self.messageTextField setTypingAttributes:@{NSFontAttributeName: [NSFont userFixedPitchFontOfSize:13.0]}];
  
  [self.contactInfoTextField setStringValue:BITHockeyLocalizedString(@"FeedbackContactInfo", @"")];
  [(BITTextFieldCell *)[self.userNameTextField cell] setBitPlaceHolderString: BITHockeyLocalizedString(@"FeedbackName", @"")];
  [(BITTextFieldCell *)[self.userEmailTextField cell] setBitPlaceHolderString: BITHockeyLocalizedString(@"FeedbackEmail", @"")];
//  [[self.userEmailTextField cell] setPlaceHolderString:BITHockeyLocalizedString(@"FeedbackEmail", @"")];
  [self.userDataContinueButton setTitle:BITHockeyLocalizedString(@"FeedbackContinueButton", @"")];
  
  [self.sendMessageButton setTitle:BITHockeyLocalizedString(@"FeedbackSendButton", @"")];
  
  // startup
  self.userName = [self.manager userName] ?: @"";
  self.userEmail = [self.manager userEmail] ?: @"";
  
  [self.manager updateMessagesListIfRequired];
  
  if ([self.manager numberOfMessages] == 0 &&
      [self.manager askManualUserDataAvailable] &&
      [self.manager requireManualUserDataMissing] &&
      ![self.manager didAskUserData]
      ) {
    [self showUserDataView];
  } else {
    [self showMessagesView];
    [self updateList];
  }
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self name:BITHockeyFeedbackMessagesLoadingStarted object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:BITHockeyFeedbackMessagesLoadingFinished object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewFrameDidChangeNotification object:self.feedbackTableView];

  [super dealloc];
}


#pragma mark - Private Image methods

- (NSImage *)imageWithReducedAlpha:(CGFloat)alpha fromImage:(NSImage *)image {
  NSSize imageSize = [image size];
  NSRect imageRect = {NSZeroPoint, imageSize};
  
  [image lockFocus];
  [[[NSColor whiteColor] colorWithAlphaComponent: alpha] set];
  NSRectFillUsingOperation(imageRect, NSCompositeSourceAtop);
  [image unlockFocus];
  
  return image;
}

- (NSImage *)imageToGreyImage:(NSImage *)image {
  // Create image rectangle with current image width/height
  CGFloat actualWidth = image.size.width;
  CGFloat actualHeight = image.size.height;
  
  CGRect imageRect = CGRectMake(0, 0, actualWidth, actualHeight);
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
  
  CGContextRef context = CGBitmapContextCreate(nil, actualWidth, actualHeight, 8, 0, colorSpace, (CGBitmapInfo)kCGImageAlphaNone);
  CGContextDrawImage(context, imageRect, [self nsImageToCGImageRef:image]);
  
  CGImageRef grayImage = CGBitmapContextCreateImage(context);
  CGColorSpaceRelease(colorSpace);
  CGContextRelease(context);
  
  context = CGBitmapContextCreate(nil, actualWidth, actualHeight, 8, 0, nil, (CGBitmapInfo)kCGImageAlphaOnly);
  CGContextDrawImage(context, imageRect, [self nsImageToCGImageRef:image]);
  CGImageRef mask = CGBitmapContextCreateImage(context);
  CGContextRelease(context);
  
  NSImage *grayScaleImage =  [self imageFromCGImageRef:CGImageCreateWithMask(grayImage, mask)];
  CGImageRelease(grayImage);
  CGImageRelease(mask);
  
  // Return the new grayscale image
  return grayScaleImage;
}

- (NSImage*)imageFromCGImageRef:(CGImageRef)image {
  NSRect imageRect = NSMakeRect(0.0, 0.0, 0.0, 0.0);
  CGContextRef imageContext = nil;
  NSImage* newImage = nil; // Get the image dimensions.
  imageRect.size.height = CGImageGetHeight(image);
  imageRect.size.width = CGImageGetWidth(image);
  
  // Create a new image to receive the Quartz image data.
  newImage = [[NSImage alloc] initWithSize:imageRect.size];
  [newImage lockFocus];
  
  // Get the Quartz context and draw.
  imageContext = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
  CGContextDrawImage(imageContext, *(CGRect*)&imageRect, image); [newImage unlockFocus];
  return newImage;
}

- (CGImageRef)nsImageToCGImageRef:(NSImage*)image; {
  NSData * imageData = [image TIFFRepresentation];
  CGImageRef imageRef;
  if(!imageData) return nil;
  CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
  imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
  return imageRef;
}


#pragma mark - Private User Data methods

- (void)showUserDataView {
  [self.userDataView setHidden:NO];
  [self.feedbackView setHidden:YES];
  [self.userNameTextField becomeFirstResponder];
}

+ (NSSet *)keyPathsForValuesAffectingCanContinueUserDataView {
  return [NSSet setWithObjects:@"userName",@"userEmail", nil];
}

- (BOOL)canContinueUserDataView {
  BOOL result = YES;
  
  if ([self.manager requireUserName] == BITFeedbackUserDataElementRequired) {
    if (self.userName.length == 0)
      result = NO;
  }
  if (result && [self.manager requireUserEmail] == BITFeedbackUserDataElementRequired) {
    if (self.userEmail.length == 0)
      result = NO;
  }
  
  return result;
}

- (IBAction)validateUserData:(id)sender {
  [self.manager setUserName:self.userName];
  [self.manager setUserEmail:self.userEmail];
  
  [self.manager saveMessages];
  
  [self showMessagesView];
  [self.feedbackTableView becomeFirstResponder];
}


#pragma mark - Private Messages methods

- (void)showMessagesView {
  [self.userDataView setHidden:YES];
  [self.feedbackView setHidden:NO];
  [self.feedbackTableView becomeFirstResponder];
}

+ (NSSet *)keyPathsForValuesAffectingCanSendMessage {
  return [NSSet setWithObjects:@"messageText", nil];
}

- (BOOL)canSendMessage {
  return self.messageText.length > 0;
}

- (IBAction)sendMessage:(id)sender {
  [self.manager submitMessageWithText:[self.messageText string]];
  self.messageText = nil;
  [self.feedbackTableView reloadData];
}

- (void)deleteAllMessages {
  [_manager deleteAllMessages];
  [self.feedbackTableView reloadData];
}

- (IBAction)reloadList:(id)sender {
  [self startLoadingIndicator];
  [self.manager updateMessagesList];
}

- (void)updateList {
  [self stopLoadingIndicator];
  
  if ([self.manager numberOfMessages] > 0) {
    [self.statusBarRefreshButton setHidden:NO];
    [self.statusBarTextField setHidden:NO];
    [self.feedbackScrollView setHidden:NO];
    [self.feedbackEmptyView setHidden:YES];
  } else {
    [self.statusBarRefreshButton setHidden:YES];
    [self.statusBarTextField setHidden:YES];
    [self.feedbackScrollView setHidden:YES];
    [self.feedbackEmptyView setHidden:NO];
  }
  
  if ([self.manager numberOfMessages] > 0) {
    [self.feedbackTableView reloadData];
  }
}


#pragma mark - Private Status Bar

- (void)startLoadingIndicator {
  [self.statusBarLoadingIndicator setHidden:NO];
  [self.statusBarLoadingIndicator startAnimation:self];
  [self.statusBarRefreshButton setHidden:YES];
}

- (void)stopLoadingIndicator {
  [self.statusBarLoadingIndicator stopAnimation:self];
  [self.statusBarLoadingIndicator setHidden:YES];
  [self updateLastUpdate];
}

- (void)updateLastUpdate {  
  NSString *text = [NSString stringWithFormat:@"%@: %@",
                    BITHockeyLocalizedString(@"FeedbackLastUpdate", @""),
                    [self.manager lastCheck] ? [self.lastUpdateDateFormatter stringFromDate:[self.manager lastCheck]] : BITHockeyLocalizedString(@"FeedbackLastUpdateNever", @"")];
  
  NSFont *boldFont = [NSFont boldSystemFontOfSize:11];

  NSMutableDictionary *style = [NSMutableDictionary dictionary];
  style[NSFontAttributeName] = boldFont;
  
  NSMutableAttributedString *attributedText = [[[NSMutableAttributedString alloc] initWithString:text] autorelease];
  [attributedText beginEditing];
  [attributedText addAttribute:NSFontAttributeName
                 value:boldFont
                 range:NSMakeRange(0, 12)];
  [attributedText endEditing];
  
  NSMutableParagraphStyle *paraStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
  [paraStyle setAlignment:NSCenterTextAlignment];
  [attributedText addAttributes:@{NSParagraphStyleAttributeName: paraStyle} range:NSMakeRange(0, [attributedText length])];

  self.statusBarTextField.attributedStringValue = attributedText;
}


#pragma mark - Private

- (void)tableViewFrameChanged:(id)sender {
  // this may not be the fastest approach, but don't know of any better at the moment
  [NSAnimationContext beginGrouping];
  [[NSAnimationContext currentContext] setDuration:0];
  [self.feedbackTableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self.feedbackTableView numberOfRows])]];
  [NSAnimationContext endGrouping];
}


#pragma mark - Table view data source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
  return [self.manager numberOfMessages];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
  BITFeedbackMessage *message = [self.manager messageAtIndex:rowIndex];
  
  return message;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
  BITFeedbackMessage *message = [self.manager messageAtIndex:row];
  
  CGFloat height = [BITFeedbackMessageCellView heightForRowWithMessage:message tableViewWidth:tableView.frame.size.width];
  return height;
}


#pragma mark - NSSplitView Delegate

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)dividerIndex {
  CGFloat maximumSize = splitView.frame.size.height - 50;
  
  return maximumSize;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)dividerIndex {
  CGFloat minimumSize = splitView.frame.size.height - 300;
  
  return minimumSize;
}

- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize {
  CGFloat dividerThickness = [sender dividerThickness];
  NSRect topRect  = [[[sender subviews] objectAtIndex:0] frame];
  NSRect bottomRect = [[[sender subviews] objectAtIndex:1] frame];
  NSRect newFrame  = [sender frame];
  
  topRect.size.height = newFrame.size.height - bottomRect.size.height - dividerThickness;
  topRect.size.width = newFrame.size.width;
  topRect.origin = NSMakePoint(0, 0);
  bottomRect.size.width = newFrame.size.width;
  bottomRect.origin.y = topRect.size.height + dividerThickness;
  
  [[[sender subviews] objectAtIndex:0] setFrame:topRect];
  [[[sender subviews] objectAtIndex:1] setFrame:bottomRect];
}


@end
