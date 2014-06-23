//
//  BITTextViewDelegate.h
//  HockeySDK
//
//  Created by Andreas Linde on 23.06.14.
//
//

#import <Foundation/Foundation.h>

@class BITTextView;

@protocol BITTextViewDelegate <NSObject>

- (void)textView:(BITTextView *)textView dragOperationWithFilename:(NSString *)filename;

@end
