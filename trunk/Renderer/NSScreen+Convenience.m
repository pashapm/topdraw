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
  NSRect frame;
  NSScreen *screen;
  
  if (!screens)
    return NSZeroRect;
  
  // Menubar is the 0th screen (according to the NSScreen docs)
  NSEnumerator *e = [screens objectEnumerator];
  frame = [[screens objectAtIndex:0] frame];
  while (screen = [e nextObject]) {
    // Union the entirety of the frame (not just the visible area)
    frame = NSUnionRect(frame, [screen frame]);
  }
  
  return frame;
}

//------------------------------------------------------------------------------
+ (NSRect)menubarFrame {
  NSArray *screens = [NSScreen screens];
  
  if (!screens)
    return NSZeroRect;

  // Menubar is the 0th screen (according to the NSScreen docs)
  NSScreen *mainScreen = [screens objectAtIndex:0];
  NSRect frame = [mainScreen frame];
  
  // Since the dock can only be on the bottom or the sides, calculate the difference
  // between the frame and the visibleFrame at the top
  NSRect visibleFrame = [mainScreen visibleFrame];
  NSRect menubarFrame;
  
  menubarFrame.origin.x = NSMinX(frame);
  menubarFrame.origin.y = NSMaxY(visibleFrame);
  menubarFrame.size.width = NSWidth(frame);
  menubarFrame.size.height = NSMaxY(frame) - NSMaxY(visibleFrame);
  
  return menubarFrame;
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


@end
