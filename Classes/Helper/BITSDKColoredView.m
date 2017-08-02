#import "BITSDKColoredView.h"

@implementation BITSDKColoredView

- (void)drawRect:(NSRect)dirtyRect {
  if (self.viewBackgroundColor) {
    [self.viewBackgroundColor setFill];
    NSRectFill(dirtyRect);
  }
  
  if (self.viewBorderWidth > 0 && self.viewBorderColor) {
    [self setWantsLayer:YES];
    self.layer.masksToBounds = YES;
    self.layer.borderWidth = self.viewBorderWidth;
    
    // Convert to CGColorRef
    const NSInteger numberOfComponents = [self.viewBorderColor numberOfComponents];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wvla"
    CGFloat components[numberOfComponents];
#pragma clang diagnostic pop
    [self.viewBorderColor getComponents:(CGFloat *)&components];
    CGColorSpaceRef colorSpace = [[self.viewBorderColor colorSpace] CGColorSpace];
    CGColorRef orangeCGColor = CGColorCreate(colorSpace, components);
    
    self.layer.borderColor = orangeCGColor;
    CGColorRelease(orangeCGColor);    
  }
  
  [super drawRect:dirtyRect];
}

@end
