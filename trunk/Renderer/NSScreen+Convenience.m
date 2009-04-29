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

#import "NSScreen+Convenience.h"

@implementation NSScreen(TopDrawConvenience)
//------------------------------------------------------------------------------
+ (NSRect)desktopFrame {
  NSArray *screens = [NSScreen screens];
  
  if (!screens)
    return NSZeroRect;
  
  NSRect frame = [[NSScreen mainScreen] frame];
  
  if ([screens count] > 1) {
    // Union the entirety of the frame (not just the visible area)
    for (NSScreen *screen in screens)
      frame = NSUnionRect(frame, [screen frame]);
  }

  return frame;
}

//------------------------------------------------------------------------------
+ (NSRect)menubarFrame {
  NSScreen *mainScreen = [NSScreen mainScreen];
  NSRect frame = [mainScreen frame];
  NSRect visibleFrame = [mainScreen visibleFrame];
  CGFloat height = NSMaxY(frame) - NSMaxY(visibleFrame);
  
  // Assume menubar goes all the way across the main screen
  frame = [mainScreen globalFrame];
  frame.origin.y = NSMaxY(frame) - height;
  frame.size.height = height;

  return frame;
}

//------------------------------------------------------------------------------
+ (void)descriptions {
  NSArray *screens = [NSScreen screens];
  NSScreen *screen;
  NSRect frame;
  
  for (int i = 0; i < [screens count]; ++i) {
    screen = [screens objectAtIndex:i];
    frame = [screen frame];
    NSLog(@"Screen[%d]: (%@) %@", i,
          NSStringFromRect(frame), [screen deviceDescription]);
  }
}

//------------------------------------------------------------------------------
- (NSRect)globalFrame {
  NSRect global = [[NSScreen mainScreen] frame];
  NSRect screenFrame = NSZeroRect;
  
  NSArray *screens = [NSScreen screens];
  for (NSScreen *screen in screens) {
    global = NSUnionRect(global, [screen frame]);
    
    if (screen == self)
      screenFrame = [screen frame];
  }
  
  // Based on the size and origin of the global screen, offset accordingly
  screenFrame.origin.x -= NSMinX(global);
  screenFrame.origin.y -= NSMinY(global);
  
  return screenFrame;
}

@end
