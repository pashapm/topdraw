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

// Show a CGImage in a scrollable, zoomable environment

#import <Cocoa/Cocoa.h>

@class CGImageView;

@interface Preview : NSObject {
 @protected
  IBOutlet NSWindow *window_;
  IBOutlet CGImageView *imageView_;
  IBOutlet NSScrollView *scrollView_;
  IBOutlet NSSlider *zoom_;
}

- (void)showPreview;
- (void)hidePreview;
- (void)showHideTogglePreview:(id)sender;
- (BOOL)isVisible;
- (void)setIsVisible:(BOOL)visible;

- (CGImageView *)imageView;

@end
