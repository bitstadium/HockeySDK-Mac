/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2014 HockeyApp, Bit Stadium GmbH.
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

#import "BITFeedbackMessageCellView.h"

#import "BITFeedbackMessage.h"


#define BACKGROUNDCOLOR_DEFAULT BIT_RGBCOLOR(245, 245, 245)
#define BACKGROUNDCOLOR_ALTERNATE BIT_RGBCOLOR(235, 235, 235)

#define TEXTCOLOR_TITLE BIT_RGBCOLOR(75, 75, 75)

#define TEXTCOLOR_DEFAULT BIT_RGBCOLOR(25, 25, 25)
#define TEXTCOLOR_PENDING BIT_RGBCOLOR(75, 75, 75)

#define TEXT_FONTSIZE 13
#define DATE_FONTSIZE 11

#define FRAME_SIDE_BORDER 10
#define FRAME_TOP_BORDER 23
#define FRAME_BOTTOM_BORDER 23
#define FRAME_LEFT_RESPONSE_BORDER 20

#define LABEL_TEXT_Y 17


@implementation BITFeedbackMessageCellView {
  NSDateFormatter *_dateFormatter;
  NSDateFormatter *_timeFormatter;
  
  NSInteger _row;
}


#pragma mark - Layout

- (void)drawRect:(NSRect)dirtyRect {
  NSColor *backgroundColor = [NSColor whiteColor];
  
  if (self.objectValue) {
    BITFeedbackMessage *message = (BITFeedbackMessage *)self.objectValue;
    
    if (message.userMessage) {
      backgroundColor = [NSColor colorWithCalibratedRed:0.93 green:0.94 blue:0.95 alpha:1];
      self.message.alignment = NSLeftTextAlignment;
      self.dateAndStatus.alignment = NSLeftTextAlignment;
    }
  }
  
  [backgroundColor setFill];
  NSRectFill(dirtyRect);
  
  [super drawRect:dirtyRect];
}


+ (NSRect)messageUsedRect:(BITFeedbackMessage *)message tableViewWidth:(CGFloat)width {
  CGRect maxMessageHeightFrame = CGRectMake(0, 0, width - FRAME_SIDE_BORDER * 2, CGFLOAT_MAX);
  
  NSTextStorage *textStorage = [[[NSTextStorage alloc] initWithString:message.text] autorelease];
  NSTextContainer *textContainer = [[[NSTextContainer alloc] initWithContainerSize:NSSizeFromCGSize(maxMessageHeightFrame.size)] autorelease];
  NSLayoutManager *layoutManager = [[[NSLayoutManager alloc] init] autorelease];
  
  [layoutManager addTextContainer:textContainer];
  [textStorage addLayoutManager:layoutManager];
  
  [textStorage setAttributes:@{NSFontAttributeName: [NSFont systemFontOfSize:TEXT_FONTSIZE]}
                       range:NSMakeRange(0, [textStorage length])];
  [textContainer setLineFragmentPadding:0.0];
  
  (void)[layoutManager glyphRangeForTextContainer:textContainer];
  NSRect aRect = [layoutManager usedRectForTextContainer:textContainer];
  
  aRect.size.height += FRAME_TOP_BORDER + LABEL_TEXT_Y + FRAME_BOTTOM_BORDER;
  
  return aRect;
}

#pragma mark - Public


/**
 * The identifier for the list cell.
 */
+ (NSString *)identifier {
  return NSStringFromClass([self class]);
}


+ (CGFloat) heightForRowWithMessage:(BITFeedbackMessage *)message tableViewWidth:(CGFloat)width {
  return [[self class] messageUsedRect:message tableViewWidth:width].size.height;
}

@end
