#import <Cocoa/Cocoa.h>

#import "BITSDKTextViewDelegate.h"

@interface BITSDKTextView : NSTextView

@property (nonatomic, copy) NSString *placeHolderString;

@property (nonatomic, unsafe_unretained) id<BITSDKTextViewDelegate> bitDelegate;

@end
