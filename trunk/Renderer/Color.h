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

// RGB/HSB + A color object

#import <Foundation/Foundation.h>

#import "RuntimeObject.h"

typedef unsigned long RGBAPixel;

@interface Color : RuntimeObject {
 @protected
  CGFloat color_[4];  // RGBA
  CGFloat hsb_[3];    // HSB
}

+ (CGColorSpaceRef)createDefaultCGColorSpace;
+ (NSColorSpace *)defaultColorSpace;

- (id)initWithColorName:(NSString *)name;
- (id)initWithArguments:(NSArray *)arguments;

- (NSColor *)color;
- (void)setColor:(NSColor *)color;

- (CGColorRef)createCGColor;

- (void)getComponents:(CGFloat *)components;
- (void)getRGBAPixel:(unsigned long *)pixel;

@end
