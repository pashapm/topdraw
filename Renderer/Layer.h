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

// Destination for all drawing operations.  Objects may draw into a Layer or
// will be used by the Layer.

#import <Foundation/Foundation.h>

#import "RuntimeObject.h"

@class Color;
@class Gradient;
@class RectObject;

@interface Layer : RuntimeObject {
 @protected
  NSRect frame_;
  CGContextRef backingStore_; // CGBitmapContext
  CGImageRef image_;
  Gradient *fillGradient_;
  
  // Used in WavyLine drawing
  CGPoint *segments_;
  int segmentCount_;
}

+ (CGBlendMode)blendModeFromString:(NSString *)blendModeStr;
+ (NSString *)blendModeToString:(CGBlendMode)blendMode;

- (id)initWithFrame:(NSRect)frame;
- (RectObject *)frame;
- (RectObject *)bounds;
- (CGRect)cgRectFrame;

- (CGImageRef)cgImage;
- (CGContextRef)backingStore;

@end
