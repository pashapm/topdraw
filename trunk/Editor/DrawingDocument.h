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

// The JavaScript source for drawings

#import <Foundation/Foundation.h>

@class ColorizingTextView;
@class Layer;
@class Logging;
@class Renderer;

extern NSString *DrawingDocumentNewImageNotification;

@interface DrawingDocument : NSDocument {
 @protected
  IBOutlet ColorizingTextView *text_;
  IBOutlet NSProgressIndicator *progress_;
  IBOutlet NSTextField *status_;
  NSString *source_;
  CGImageRef image_;
  NSString *imagePath_;
  Renderer *renderer_;
  BOOL isExporting_;
  NSTimer *progressTimer_;
}

//------------------------------------------------------------------------------
// Actions
//------------------------------------------------------------------------------
- (IBAction)render:(id)sender;
- (IBAction)cancelRender:(id)sender;
- (IBAction)install:(id)sender;
- (IBAction)exportSample:(id)sender;

//------------------------------------------------------------------------------
// Public
//------------------------------------------------------------------------------
+ (NSColor *)errorHighlightColor;

- (CGImageRef)image;
- (NSString *)name;

@end
