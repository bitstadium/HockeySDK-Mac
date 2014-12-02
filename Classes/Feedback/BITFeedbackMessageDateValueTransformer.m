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

#import "BITFeedbackMessageDateValueTransformer.h"

#import "HockeySDKPrivate.h"
#import "BITFeedbackMessage.h"

@implementation BITFeedbackMessageDateValueTransformer

- (NSDateFormatter *)dateFormatter {
  static NSDateFormatter *dateFormatter = nil;
  
  static dispatch_once_t predDateFormatter;
  
  dispatch_once(&predDateFormatter, ^{
    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [dateFormatter setLocale:[NSLocale currentLocale]];
    [dateFormatter setDoesRelativeDateFormatting:YES];
  });
  
  return dateFormatter;
}

- (NSDateFormatter *)timeFormatter {
  static NSDateFormatter *timeFormatter = nil;
  
  static dispatch_once_t predTimeFormatter;
  
  dispatch_once(&predTimeFormatter, ^{
    timeFormatter = [[NSDateFormatter alloc] init];
    [timeFormatter setTimeStyle:NSDateFormatterShortStyle];
    [timeFormatter setDateStyle:NSDateFormatterNoStyle];
    [timeFormatter setLocale:[NSLocale currentLocale]];
    [timeFormatter setDoesRelativeDateFormatting:YES];
  });
  
  return timeFormatter;
}

- (BOOL)isSameDayWithDate1:(NSDate*)date1 date2:(NSDate*)date2 {
  NSCalendar* calendar = [NSCalendar currentCalendar];
  
  unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit;
  NSDateComponents *dateComponent1 = [calendar components:unitFlags fromDate:date1];
  NSDateComponents *dateComponent2 = [calendar components:unitFlags fromDate:date2];
  
  return ([dateComponent1 day] == [dateComponent2 day] &&
          [dateComponent1 month] == [dateComponent2 month] &&
          [dateComponent1 year]  == [dateComponent2 year]);
}

-(id)transformedValue:(BITFeedbackMessage *)message {
  NSString *result = @"";
  
  if (!message) return nil;
  
  if (![message isKindOfClass:[BITFeedbackMessage class]]) return nil;
  
  if (message.status == BITFeedbackMessageStatusSendPending || message.status == BITFeedbackMessageStatusSendInProgress) {
    result = @"Pending";
  } else if (message.date) {
    if ([self isSameDayWithDate1:[NSDate date] date2:message.date]) {
      result = [[self timeFormatter] stringFromDate:message.date];
    } else {
      result = [NSString stringWithFormat:@"%@ %@", [[self dateFormatter] stringFromDate:message.date], [[self timeFormatter] stringFromDate:message.date]];
    }
  }
  
  if (!message.userMessage && [message.name length] > 0) {
    result = [NSString stringWithFormat:@"%@ %@ %@", result, BITHockeyLocalizedString(@"FeedbackFrom", @""),  message.name];
  }
  
  return result;
}

@end
