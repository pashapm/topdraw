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

// This code borrows heavily from code and links posted on CocoaDev.com

#import "CenteringClipView.h"

@implementation CenteringClipView
- (void)centerDocumentView {
  NSRect documentRect = [[self documentView] frame];
  NSRect clipRect = [self bounds];
  
  if (NSWidth(documentRect) < NSWidth(clipRect))
    clipRect.origin.x = floor((NSWidth(documentRect) - NSWidth(clipRect)) / 2);
  
  if (NSHeight(documentRect) < NSHeight(clipRect))
    clipRect.origin.y = floor((NSHeight(clipRect) - NSHeight(documentRect)) / 2);
  
  [self scrollToPoint:clipRect.origin];
}

- (NSPoint)constrainScrollPoint:(NSPoint)proposedNewOrigin {
  NSRect documentRect = [[self documentView] frame];
  NSRect clipRect = [self bounds];
  NSPoint delta = NSMakePoint(NSWidth(documentRect) - NSWidth(clipRect),
                              NSHeight(documentRect) - NSHeight(clipRect));
  
  if (NSWidth(documentRect) < NSWidth(clipRect))
    proposedNewOrigin.x = floor(delta.x / 2);
  else
    proposedNewOrigin.x = floor(MAX(0, MIN(proposedNewOrigin.x, delta.x)));
  
  if (NSHeight(documentRect) < NSHeight(clipRect))
    proposedNewOrigin.y = floor(delta.y / 2);
  else
    proposedNewOrigin.y = floor(MAX(0, MIN(proposedNewOrigin.y, delta.y)));

  return proposedNewOrigin;
}

- (void)viewBoundsChanged:(NSNotification *)note {
  [super viewBoundsChanged:note];
  [self centerDocumentView];
}

- (void)viewFrameChanged:(NSNotification *)note {
  [super viewFrameChanged:note];
  [self centerDocumentView];
}

- (void)setFrame:(NSRect)rect {
  [super setFrame:rect];
  [self centerDocumentView];
}

- (void)setFrameOrigin:(NSPoint)origin {
  [super setFrameOrigin:origin];
  [self centerDocumentView];
}

- (void)setFrameSize:(NSSize)size {
  [super setFrameSize:size];
  [self centerDocumentView];
}

- (void)setFrameRotation:(float)angle {
  [super setFrameRotation:angle];
  [self centerDocumentView];
}

- (BOOL)copiesOnScroll {
	NSRect documentRect = [[self documentView] frame];
	NSRect clipRect = [self bounds];
  
	return floor(NSWidth(documentRect) >= NSWidth(clipRect)) &&
    floor(NSHeight(documentRect) >= NSHeight(clipRect));
}

- (void)drawRect:(NSRect)rect {
  [super drawRect:rect];
  
	NSRect documentRect = [[self documentView] frame];
  [[NSColor redColor] set];
  NSFrameRect(documentRect);
}

@end
