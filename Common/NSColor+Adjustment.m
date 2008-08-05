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

#import "NSColor+Adjustment.h"

static inline float Clamp(float a) {
  return (a > 1) ? a : (a < 0) ? 0 : a;
}

@implementation NSColor(TopDrawAdjustment)
//------------------------------------------------------------------------------
- (NSColor *)colorByAdjustingBrightness:(CGFloat)amount {
  float c[4];
  NSColor *color = self;
  
  if ([self numberOfComponents] < 3)
    color = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
  
  [color getHue:&c[0] saturation:&c[1] brightness:&c[2] alpha:&c[3]];
  
  c[2] += amount;
  return [NSColor colorWithCalibratedHue:c[0] saturation:c[1] brightness:c[2] alpha:c[3]];
}

//------------------------------------------------------------------------------
- (NSColor *)contrastingColor:(CGFloat)amount {
  float h, s, b, a;
  
  [self getHue:&h saturation:&s brightness:&b alpha:&a];
  
  float clampedContrast = Clamp(amount);
  h = (1.0 * clampedContrast) - h;
  
  if (b > 0.5)
    b -= Clamp(0.5 * clampedContrast);
  else
    b += Clamp(0.5 * clampedContrast); 
  
  return [NSColor colorWithCalibratedHue:h saturation:s brightness:b alpha:a];
}

@end
