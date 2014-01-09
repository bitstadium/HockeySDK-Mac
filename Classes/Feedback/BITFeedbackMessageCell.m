/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2013 HockeyApp, Bit Stadium GmbH.
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

#import "BITFeedbackMessageCell.h"

#import "BITFeedbackMessage.h"

#import "HockeySDKPrivate.h"


#define BACKGROUNDCOLOR_DEFAULT BIT_RGBCOLOR(245, 245, 245)
#define BACKGROUNDCOLOR_ALTERNATE BIT_RGBCOLOR(235, 235, 235)

#define TEXTCOLOR_TITLE BIT_RGBCOLOR(75, 75, 75)

#define TEXTCOLOR_DEFAULT BIT_RGBCOLOR(25, 25, 25)
#define TEXTCOLOR_PENDING BIT_RGBCOLOR(75, 75, 75)

#define TITLE_FONTSIZE 11
#define TEXT_FONTSIZE 13

#define FRAME_SIDE_BORDER 10
#define FRAME_TOP_BORDER 8
#define FRAME_BOTTOM_BORDER 5
#define FRAME_LEFT_RESPONSE_BORDER 20

#define LABEL_TITLE_Y 3
#define LABEL_TITLE_HEIGHT 15

#define LABEL_TEXT_Y 25


@interface BITFeedbackMessageCell ()

@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSDateFormatter *timeFormatter;

@end


@implementation BITFeedbackMessageCell

- (id)init {
  self = [super init];
  
  if (nil != self) {
    self.dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
    [self.dateFormatter setTimeStyle:NSDateFormatterNoStyle];
    [self.dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [self.dateFormatter setLocale:[NSLocale currentLocale]];
    [self.dateFormatter setDoesRelativeDateFormatting:YES];
    
    self.timeFormatter = [[[NSDateFormatter alloc] init] autorelease];
    [self.timeFormatter setTimeStyle:NSDateFormatterShortStyle];
    [self.timeFormatter setDateStyle:NSDateFormatterNoStyle];
    [self.timeFormatter setLocale:[NSLocale currentLocale]];
    [self.timeFormatter setDoesRelativeDateFormatting:YES];
  }
  
  return self;
}

- copyWithZone:(NSZone *)zone {
	BITFeedbackMessageCell *cell = (BITFeedbackMessageCell *)[super copyWithZone:zone];
  return cell;
}


#pragma mark - Private

- (BOOL)isSameDayWithDate1:(NSDate*)date1 date2:(NSDate*)date2 {
  NSCalendar* calendar = [NSCalendar currentCalendar];
  
  unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit;
  NSDateComponents *dateComponent1 = [calendar components:unitFlags fromDate:date1];
  NSDateComponents *dateComponent2 = [calendar components:unitFlags fromDate:date2];
  
  return ([dateComponent1 day] == [dateComponent2 day] &&
          [dateComponent1 month] == [dateComponent2 month] &&
          [dateComponent1 year]  == [dateComponent2 year]);
}


#pragma mark - Layout

+ (CGRect)messageUsedRect:(BITFeedbackMessage *)message tableViewWidth:(CGFloat)width {
  CGRect maxMessageHeightFrame = CGRectMake(0, 0, width - FRAME_SIDE_BORDER * 2, CGFLOAT_MAX);
  
  NSTextStorage *textStorage = [[[NSTextStorage alloc] initWithString:message.text] autorelease];
  NSTextContainer *textContainer = [[[NSTextContainer alloc] initWithContainerSize:maxMessageHeightFrame.size] autorelease];
  NSLayoutManager *layoutManager = [[[NSLayoutManager alloc] init] autorelease];
  
  [layoutManager addTextContainer:textContainer];
  [textStorage addLayoutManager:layoutManager];
  
  [textStorage setAttributes:@{NSFontAttributeName: [NSFont systemFontOfSize:TEXT_FONTSIZE]}
                       range:NSMakeRange(0, [textStorage length])];
  [textContainer setLineFragmentPadding:0.0];
  
  (void)[layoutManager glyphRangeForTextContainer:textContainer];
  CGRect aRect = [layoutManager usedRectForTextContainer:textContainer];
  
  aRect.size.height += FRAME_TOP_BORDER + LABEL_TEXT_Y + FRAME_BOTTOM_BORDER;
  
  return aRect;
}

+ (CGFloat) heightForRowWithMessage:(BITFeedbackMessage *)message tableViewWidth:(CGFloat)width {
  return [[self class] messageUsedRect:message tableViewWidth:width].size.height;
}


#pragma mark - Drawing

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
  NSColor *color = (self.row % 2) ? BACKGROUNDCOLOR_ALTERNATE : BACKGROUNDCOLOR_DEFAULT;
  
  [color set];
  NSRectFill(cellFrame);
  
  [self setTextColor:[NSColor blackColor]];
	
	BITFeedbackMessage *message = (BITFeedbackMessage *)[self objectValue];
  
  NSMutableParagraphStyle *pStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
  if (message.userMessage) {
    [pStyle setAlignment:NSRightTextAlignment];
  } else {
    [pStyle setAlignment:NSLeftTextAlignment];
  }
  
  NSColor *textColor = nil;
  if (message.status == BITFeedbackMessageStatusSendPending || message.status == BITFeedbackMessageStatusSendInProgress) {
    textColor = TEXTCOLOR_PENDING;
  } else {
    textColor = TEXTCOLOR_DEFAULT;
  }
  
  NSDictionary* titleAttributes = @{NSForegroundColorAttributeName: TEXTCOLOR_TITLE,
                                   NSFontAttributeName: [NSFont systemFontOfSize:TITLE_FONTSIZE],
                                   NSParagraphStyleAttributeName:pStyle
                                   };

	NSDictionary* textAttributes = @{NSForegroundColorAttributeName: textColor,
                                  NSFontAttributeName: [NSFont systemFontOfSize:TEXT_FONTSIZE],
                                  NSParagraphStyleAttributeName:pStyle
                                  };
  
  // message header
  NSString *dateString = @"";
  if (message.status == BITFeedbackMessageStatusSendPending || message.status == BITFeedbackMessageStatusSendInProgress) {
    dateString = @"Pending";
  } else if (message.date) {
    if ([self isSameDayWithDate1:[NSDate date] date2:message.date]) {
      dateString = [self.timeFormatter stringFromDate:message.date];
    } else {
      dateString = [self.dateFormatter stringFromDate:message.date];
    }
  }
  
  if (!message.userMessage && [message.name length] > 0) {
    dateString = [NSString stringWithFormat:@"%@ from %@", dateString, message.name];
  }
  
  CGSize headerSize = CGSizeMake(cellFrame.size.width - (2 * FRAME_SIDE_BORDER), LABEL_TITLE_HEIGHT);
  
  NSRect headerFrame = CGRectMake(cellFrame.origin.x + FRAME_SIDE_BORDER, cellFrame.origin.y + FRAME_TOP_BORDER + LABEL_TITLE_Y, headerSize.width, headerSize.height);

  [dateString drawInRect:headerFrame withAttributes:titleAttributes];
  
  // message text
  CGSize textSize = CGSizeMake(cellFrame.size.width - (2 * FRAME_SIDE_BORDER),
                           [[self class] heightForRowWithMessage:message tableViewWidth:cellFrame.size.width] - LABEL_TEXT_Y - FRAME_BOTTOM_BORDER);
  
  NSRect textFrame = CGRectMake(cellFrame.origin.x + FRAME_SIDE_BORDER, cellFrame.origin.y + LABEL_TEXT_Y, textSize.width, textSize.height);
  
  [message.text drawInRect:textFrame withAttributes:textAttributes];
}

@end
