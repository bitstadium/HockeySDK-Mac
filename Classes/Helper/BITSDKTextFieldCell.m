#import "BITSDKTextFieldCell.h"

@implementation BITSDKTextFieldCell

- (NSRect)drawingRectForBounds:(NSRect)theRect {
	// Get the parent's idea of where we should draw
	NSRect newRect = [super drawingRectForBounds:theRect];
  NSSize textSize = [self cellSizeForBounds:theRect];
  
  CGFloat heightDelta = newRect.size.height - textSize.height;
  if (heightDelta > 0) {
    newRect.size.height -= heightDelta;
    newRect.origin.y += heightDelta / 2;
    if (self.horizontalInset) {
#if CGFLOAT_IS_DOUBLE
      CGFloat horizontalInset = [self.horizontalInset doubleValue];
#else
      CGFloat horizontalInset = [self.horizontalInset floatValue];
#endif
      newRect.origin.x += horizontalInset;
      newRect.size.width -= (horizontalInset * 2);
    }
  }
	
	return newRect;
}

- (void)setBitPlaceHolderString:(NSString *)bitPlaceHolderString {
  self.placeholderString = bitPlaceHolderString;
}

@end
