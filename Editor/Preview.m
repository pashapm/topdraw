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

#import "CenteringClipView.h"
#import "CGImageView.h"
#import "DrawingDocument.h"
#import "Preview.h"

@interface Preview(PrivateMethods)
- (void)keyWindowChanged:(NSNotification *)note;
- (void)imageChanged:(NSNotification *)note;
@end

@implementation Preview
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Private ||
//------------------------------------------------------------------------------
- (void)keyWindowChanged:(NSNotification *)note {
  NSWindow *window = (NSWindow *)[note object];
  NSDocument *doc = [[NSDocumentController sharedDocumentController] documentForWindow:window];
  
  if ([doc isMemberOfClass:[DrawingDocument class]]) {
    CGImageRef image = [(DrawingDocument *)doc image];
    [imageView_ setImage:image];
  }
}

//------------------------------------------------------------------------------
- (void)imageChanged:(NSNotification *)note {
  DrawingDocument *doc = (DrawingDocument *)[note object];
  CGImageRef image = [doc image];
  [imageView_ setImage:image];
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Public ||
//------------------------------------------------------------------------------
- (void)showPreview {
  [window_ orderFront:nil];
}

//------------------------------------------------------------------------------
- (void)hidePreview {
  [window_ orderOut:nil];
}

//------------------------------------------------------------------------------
- (void)showHideTogglePreview:(id)sender {
  if ([self isVisible])
    [self hidePreview];
  else
    [self showPreview];
}
       
//------------------------------------------------------------------------------
- (BOOL)isVisible {
  return [window_ isVisible];
}

//------------------------------------------------------------------------------
- (void)setIsVisible:(BOOL)visible {
  if (! visible)
    [self hidePreview];
  else
    [self showPreview];
}

//------------------------------------------------------------------------------
- (CGImageView *)imageView {
  return imageView_;
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || NSObject ||
//------------------------------------------------------------------------------
- (void)awakeFromNib {
  NSNotificationCenter *ctr = [NSNotificationCenter defaultCenter];
  
  [ctr addObserver:self selector:@selector(keyWindowChanged:) name:NSWindowDidBecomeKeyNotification object:nil];
  [ctr addObserver:self selector:@selector(imageChanged:) name:DrawingDocumentNewImageNotification object:nil];
  
  // Setup the centering clip view on the preview
  id contentView = [[scrollView_ documentView] retain];
  id clipView = [[CenteringClipView alloc] initWithFrame:[[scrollView_ contentView] frame]];
  [clipView setBackgroundColor:[NSColor windowBackgroundColor]];
  [scrollView_ setContentView:(NSClipView *)clipView];
  [clipView release];
  [scrollView_ setDocumentView:contentView];
  [contentView release];
}

//------------------------------------------------------------------------------
- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || NSWindowDelegate ||
//------------------------------------------------------------------------------
- (NSRect)windowWillUseStandardFrame:(NSWindow *)window defaultFrame:(NSRect)frame {
  NSRect optimal = [imageView_ optimalFrame];
  NSRect scrollFrame = [scrollView_ frame];
  NSRect current = [window frame];
  float scrollBarPad = 2; // Add some padding to ensure that the scroll bars don't show up
  
  current.size.width += NSWidth(optimal) - NSWidth(scrollFrame) + scrollBarPad; 
  current.size.height += NSHeight(optimal) - NSHeight(scrollFrame) + scrollBarPad;
  current.origin.y -= NSHeight(optimal) - NSHeight(scrollFrame) + scrollBarPad;
  
  return current;
}

@end
