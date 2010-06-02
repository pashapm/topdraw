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
#import "Randomizer.h"

#define RandomComponent() RandomizerFloatValue()

static inline float Clamp(float a) {
  return (a > 1) ? a : (a < 0) ? 0 : a;
}

@implementation NSColor(TopDrawRandom)
//------------------------------------------------------------------------------
+ (NSColor *)randomOpaqueColor {
  float c[4];

  c[0] = RandomComponent();
  c[1] = RandomComponent();
  c[2] = RandomComponent();
  c[3] = 1.0;

  return [NSColor colorWithCalibratedRed:c[0] green:c[1] blue:c[2] alpha:c[3]];
}

//------------------------------------------------------------------------------
+ (NSColor *)randomColor {
  float c[4];

  c[0] = RandomComponent();
  c[1] = RandomComponent();
  c[2] = RandomComponent();
  c[3] = RandomComponent();

  return [NSColor colorWithCalibratedRed:c[0] green:c[1] blue:c[2] alpha:c[3]];
}

//------------------------------------------------------------------------------
- (NSColor *)varyColorRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha {
  CGFloat c[4] = { 0 };

  if ([self numberOfComponents] <= 4) {
    [self getComponents:c];
  } else {
    NSLog(@"varColorRed: Unexpected # of components");
  }
  
  c[0] += (1.0 - 2.0 * RandomComponent()) * red;
  c[1] += (1.0 - 2.0 * RandomComponent()) * green;
  c[2] += (1.0 - 2.0 * RandomComponent()) * blue;
  c[3] += (1.0 - 2.0 * RandomComponent()) * alpha;

  NSColor *color =  [NSColor colorWithCalibratedRed:Clamp(c[0]) green:Clamp(c[1])
                                    blue:Clamp(c[2]) alpha:Clamp(c[3])];
  return color;
}

@end
