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

#import "NSColor+Adjustment.h"
#import "PreferencesController.h"
#import "StatusItemView.h"

const CGFloat kPadding = 4.0;

@implementation StatusItemView
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Private ||
//------------------------------------------------------------------------------
- (void)menuClick {
  isHighlighted_ = YES;
  [self setNeedsDisplay:YES];
  
  [target_ performSelector:action_];
  
  isHighlighted_ = NO;
  [self setNeedsDisplay:YES];
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Public ||
//------------------------------------------------------------------------------
- (void)setStatusItem:(NSStatusItem *)item {
  statusItem_ = item;
}

//------------------------------------------------------------------------------
- (void)setTarget:(id)target {
  target_ = target;
}

//------------------------------------------------------------------------------
- (void)setAction:(SEL)action {
  action_ = action;
}

//------------------------------------------------------------------------------
- (void)setIsRendering:(BOOL)rendering {
  isRendering_ = rendering;
  [self setNeedsDisplay:YES];
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || NSView ||
//------------------------------------------------------------------------------
- (void)drawRect:(NSRect)rect {
  if (!statusItem_)
    return;
  
  // Fill with background
  [statusItem_ drawStatusBarBackgroundInRect:rect withHighlight:isHighlighted_];
  
  // Draw our image
  NSRect bounds = [self bounds];
  NSRect content = NSMakeRect(0, 0, 16, 16);
  IndicatorStyle style = [[NSUserDefaults standardUserDefaults] integerForKey:@"indicatorStyle"];
  
  // Use a square shape for all but rect
  if (style == kIndicatorRectangle)
    content.size.width = 20;

  // Align it to our bounds
  content.origin.x = (NSWidth(bounds) - NSWidth(content)) / 2.0;
  content.origin.y = (NSHeight(bounds) - NSHeight(content)) / 2.0;
  content = NSIntegralRect(content);
  
  // Create the path
  NSBezierPath *shape = [NSBezierPath bezierPath];
  switch (style) {
    case kIndicatorSquare:
      [shape appendBezierPathWithRect:content];
      break;
      
    case kIndicatorCircle:
      [shape appendBezierPathWithOvalInRect:content];
      break;
      
    case kIndicatorTriangle:
      [shape moveToPoint:NSMakePoint(NSMinX(content), NSMinY(content))];
      [shape lineToPoint:NSMakePoint(NSMaxX(content), NSMinY(content))];
      [shape lineToPoint:NSMakePoint(NSMidX(content), NSMaxY(content))];
      [shape closePath];
      break;
      
    case kIndicatorRectangle:
    default:
      [shape appendBezierPathWithRect:content];
      break;
  }

  // Fill
  NSString *colorKey = isRendering_ ? @"activeColor" : @"idleColor";
  NSData *colorData = [[NSUserDefaults standardUserDefaults] dataForKey:colorKey];
  NSColor *color = [NSUnarchiver unarchiveObjectWithData:colorData];
  [color set];
  [shape fill];
  
  // Take the color and make it darker
  NSColor *darker = [color colorByAdjustingBrightness:-0.5];
  [darker set];
  [shape stroke];
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || NSResponder ||
//------------------------------------------------------------------------------
- (void)mouseDown:(NSEvent *)event {
  [self menuClick];
}

//------------------------------------------------------------------------------
- (void)rightMouseDown:(NSEvent *)event {
  [self menuClick];
}

@end
