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

// View for StatusItem

#import <Cocoa/Cocoa.h>

@interface StatusItemView : NSView {
  NSStatusItem *statusItem_;
  id target_;
  SEL action_;
  BOOL isHighlighted_;
  BOOL isRendering_;
}

- (void)setStatusItem:(NSStatusItem *)item;
- (void)setTarget:(id)target;
- (void)setAction:(SEL)action;

- (void)setIsRendering:(BOOL)rendering;

@end
