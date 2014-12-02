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

#import "BITSDKTextView.h"

@implementation BITSDKTextView

- (void)drawRect:(NSRect)rect {
  [super drawRect:rect];
  if ([[self string] isEqualToString:@""] && self != [[self window] firstResponder]) {
    if (self.placeHolderString) {
      NSColor *txtColor = [NSColor colorWithCalibratedRed:0.69 green:0.71 blue:0.73 alpha:1.0];
      NSDictionary *dict = @{NSForegroundColorAttributeName: txtColor};
      NSAttributedString *placeholder = [[NSAttributedString alloc] initWithString:self.placeHolderString attributes:dict];
      [placeholder drawAtPoint:NSMakePoint(0,0)];
    }
  }
}

- (BOOL)becomeFirstResponder {
  [self setNeedsDisplay:YES];
  return [super becomeFirstResponder];
}

- (BOOL)resignFirstResponder {
  [self setNeedsDisplay:YES];
  return [super resignFirstResponder];
}


#pragma mark - Drag & Drop for Attachments

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
  NSPasteboard *pb = [sender draggingPasteboard];
  NSDragOperation dragOperation = [sender draggingSourceOperationMask];
  
  if ([[pb types] containsObject:NSFilenamesPboardType]) {
    if (dragOperation & NSDragOperationCopy) {
      return NSDragOperationCopy;
    }
  }
  
  return NSDragOperationNone;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
  NSPasteboard *pb = [sender draggingPasteboard];
  
  if ( [[pb types] containsObject:NSFilenamesPboardType] ) {
    NSFileManager *fm = [[NSFileManager alloc] init];
    
    NSArray *filenames = [pb propertyListForType:NSFilenamesPboardType];
    
    BOOL fileFound = NO;
    
    for (NSString *filename in filenames) {
      BOOL isDir = NO;
      if (![fm fileExistsAtPath:filename isDirectory:&isDir] || isDir) continue;
      
      fileFound = YES;
      
      if (self.bitDelegate && [self.bitDelegate respondsToSelector:@selector(textView:dragOperationWithFilename:)]) {
        [self.bitDelegate textView:self dragOperationWithFilename:filename];
      }
    }
    return fileFound;
  }
  
  return NO;
}

@end
