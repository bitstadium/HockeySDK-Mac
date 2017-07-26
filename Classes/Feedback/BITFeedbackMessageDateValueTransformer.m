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

-(id)transformedValue:(id)message {
  NSString *result = @"";
  if (!message || ![message isKindOfClass:[BITFeedbackMessage class]]) {
    return nil;
  }
  BITFeedbackMessage *feedbackMessage = (BITFeedbackMessage *)message;
  
  if (feedbackMessage.status == BITFeedbackMessageStatusSendPending ||
      feedbackMessage.status == BITFeedbackMessageStatusSendInProgress) {
    result = @"Pending";
  } else if (feedbackMessage.date) {
    if ([self isSameDayWithDate1:[NSDate date] date2:feedbackMessage.date]) {
      result = [[self timeFormatter] stringFromDate:feedbackMessage.date];
    } else {
      result = [NSString stringWithFormat:@"%@ %@",
                [[self dateFormatter] stringFromDate:feedbackMessage.date],
                [[self timeFormatter] stringFromDate:feedbackMessage.date]];
    }
  }
  
  if (!feedbackMessage.userMessage && [feedbackMessage.name length] > 0) {
    result = [NSString stringWithFormat:@"%@ %@ %@", result, BITHockeyLocalizedString(@"FeedbackFrom", @""),  feedbackMessage.name];
  }
  
  return result;
}

@end
