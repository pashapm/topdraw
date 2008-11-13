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

// A view to display a CGImageRef.  Also has zooming capabilities and
// panning with the mouse.

#import <Cocoa/Cocoa.h>

@interface CGImageView : NSView {
 @protected
  CGImageRef image_;        // Image to display (STRONG)
  CGFloat zoom_;            // Zooming (100 is full size)
  NSPoint initialPt_;       // For mouse drag
  NSPoint initialOrigin_;   // For mouse drag
  BOOL isDown_;             // For mouse drag
}

//------------------------------------------------------------------------------
// Public
//------------------------------------------------------------------------------
- (void)setImage:(CGImageRef)image;
- (CGImageRef)image;

- (void)setZoom:(CGFloat)zoom;
- (CGFloat)zoom;

- (NSRect)optimalFrame;
- (NSRect)optimalFrameForZoom:(CGFloat)zoom;

//------------------------------------------------------------------------------
// NSView
//------------------------------------------------------------------------------
- (id)initWithFrame:(NSRect)frame;

- (void)drawRect:(NSRect)rect;
- (void)resetCursorRects;

//------------------------------------------------------------------------------
// NSResponder
//------------------------------------------------------------------------------
- (void)mouseDown:(NSEvent *)event;
- (void)mouseDragged:(NSEvent *)event;
- (void)mouseUp:(NSEvent *)event;

@end
