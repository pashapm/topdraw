// Copyright 2008 Google Inc.
// 
// Licensed under the Apache License, Version 2.0 (the "License"); you may not
// use this file except in compliance with the License.  You may obtain a copy
// of the License at
// 
// http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
// License for the specific language governing permissions and limitations under
// the License.

#import "CenteringScrollView.h"
#import "CGImageView.h"

@implementation CenteringScrollView

- (void)tile {
  // Let the superclass handle the scrollbars and stuff
  [super tile];

  NSClipView *clipView = [self contentView];
  NSRect clipRect = [clipView frame];
  NSView *documentView = [self documentView];
  NSRect documentRect = [documentView frame];
  NSPoint scrollPt = NSZeroPoint;
  
  // We're scrolling the clip so that the document is centered, so the
  // point is really an offset 
  if (NSWidth(clipRect) > NSWidth(documentRect))
    scrollPt.x = round(NSWidth(documentRect) / 2 - NSMidX(clipRect));

  if (NSHeight(clipRect) > NSHeight(documentRect))
    scrollPt.y = round(NSHeight(documentRect) / 2 - NSHeight(clipRect) / 2);
  
  // Scroll so that the clip is centered and ensure that the document is at the
  // clip's origin
  [documentView setFrameOrigin:NSZeroPoint];
  [clipView scrollToPoint:scrollPt];
}

- (void)scrollWheel:(NSEvent *)event {
  int modifiers = [event modifierFlags];
  
  if (modifiers & NSAlternateKeyMask) {
    CGImageView *imageView = [self documentView];
    
    if ([imageView isKindOfClass:[CGImageView class]]) {
      CGFloat zoom = [imageView zoom];
      CGFloat delta = [event deltaY];
      zoom += delta;
      [imageView setZoom:zoom];

      // We've handled the event, so just return w/o calling the superclass
      return;
    }
  }
  
  // If the document view is completely visible, don't do anything
  NSClipView *clip = [self contentView];
  NSRect documentRect = [clip documentRect];
  NSRect documentVisibleRect = [clip documentVisibleRect];
  
  // If they're the same size, no scrolling
  if (NSEqualSizes(documentRect.size, documentVisibleRect.size))
    return;
  
  [super scrollWheel:event];
}

@end
