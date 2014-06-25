/*
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
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

#import "BITActivityIndicatorButton.h"


@interface BITActivityIndicatorButton()

@property (nonatomic, strong) NSProgressIndicator *indicator;
@property (nonatomic) BOOL indicatorVisible;

@end


@implementation BITActivityIndicatorButton

- (instancetype)initWithFrame:(NSRect)frameRect {
  if (self = [super initWithFrame:frameRect]) {
    _indicator = [[NSProgressIndicator alloc] initWithFrame:self.bounds];
    
    [_indicator setStyle: NSProgressIndicatorSpinningStyle];
    [_indicator setControlSize: NSSmallControlSize];
    [_indicator sizeToFit];
    
    _indicator.hidden = YES;
    
    [self addSubview:_indicator];
  }
  return self;
}

- (void)setShowsActivityIndicator:(BOOL)showsIndicator {
  if (self.indicatorVisible == showsIndicator){
    return;
  }
  
  self.indicatorVisible = showsIndicator;
  [[self cell] setBackgroundColor:self.bitBackgroundColor];
  
  if (showsIndicator){
    [self.indicator startAnimation:self];
    [self.indicator setHidden:NO];
    self.image = nil;
  } else {
    [self.indicator stopAnimation:self];
    [self.indicator setHidden:YES];
  }
}


@end
