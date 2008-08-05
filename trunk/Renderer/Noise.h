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

// A source for random pixels

#import <Cocoa/Cocoa.h>

@class Image;

@interface Noise : RuntimeObject {
  void *buffer_;
  CGContextRef bitmap_;
  CGImageRef image_;
  BOOL grayscale_;
  CGFloat alpha_;
  unsigned int width_;
  unsigned int height_;
}

//------------------------------------------------------------------------------
// Public
//------------------------------------------------------------------------------
- (id)initWithWidth:(unsigned int)width height:(unsigned int)height;

- (void)setGrayscale:(BOOL)grayscale;
- (BOOL)grayscale;

- (void)setAlpha:(CGFloat)alpha;
- (CGFloat)alpha;

- (unsigned int)width;
- (unsigned int)height;

- (Image *)image;
- (CGImageRef)cgImage;
- (CIImage *)ciImage;
- (CGContextRef)bitmap;

@end
