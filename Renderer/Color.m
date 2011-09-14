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

#import "Color.h"
#import "NSColor+Adjustment.h"
#import "NSColor+Random.h"
#import "NSColor+String.h"

static const CGFloat kInvalidHue = 99;
static const int kInvalidColorIndex = -1;

@interface Color (PrivateMethods)
- (Color *)adjustColorBrightness:(CGFloat)amount;
- (void)ensureHSB;
- (void)updateRGBFromHSB;
@end

@implementation Color
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Runtime ||
//------------------------------------------------------------------------------
+ (NSString *)className {
  return @"Color";
}

//------------------------------------------------------------------------------
+ (NSSet *)properties {
  return [NSSet setWithObjects:@"red", @"green", @"blue", @"alpha", @"r", @"g", 
          @"b", @"a", @"brightness", @"hue", @"saturation", nil]; 
}

//------------------------------------------------------------------------------
+ (NSSet *)methods {
  return [NSSet setWithObjects:@"blend", @"vary", @"darker", @"lighter", 
          @"contrasting", @"isEqual", @"toString", nil];
}

//------------------------------------------------------------------------------
- (id)initWithArguments:(NSArray *)arguments {
  if ((self = [super initWithArguments:arguments])) {
    int count = [arguments count];
    NSColor *temp;
    
    // Can pass in another Color or 3-4 components
    // default to white
    color_[0] = color_[1] = color_[2] = color_[3] = 1.0;
    
    // Other Color, gray, named color, or Color or named color with alpha
    if (count == 0) {
      temp = [NSColor randomColor];
      [temp getComponents:color_];
      color_[3] = 1.0;
    }else if (count == 1 || count == 2) {
      Color *c = [RuntimeObject coerceArray:arguments objectAtIndex:0 toClass:[Color class]];
      if (c) {
        [c getComponents:color_];        
      } else {
        NSString *name = [RuntimeObject coerceArray:arguments objectAtIndex:0 toClass:[NSString class]];
        temp = [NSColor colorWithString:name];
        
        // If we have a string, but can't find a color
        if (name && !temp)
          temp = [NSColor randomColor];
        
        if (temp) {
          NSColor *rgb = [temp colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
          [rgb getComponents:color_];
        } else {
          // Might just be gray
          color_[0] = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:0]];
          color_[1] = color_[2] = color_[0];
        }
      }
      
      // Add alpha
      if (count == 2)
        color_[3] = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:1]];
        
    } else if (count >= 3) {
      color_[0] = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:0]];
      color_[1] = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:1]];
      color_[2] = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:2]];
    
      if (count == 4)
        color_[3] = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:3]];
    }
  }
  
  hsb_[0] = kInvalidHue;
  
  return self;
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Public Methods ||
//------------------------------------------------------------------------------
+ (CGColorSpaceRef)createDefaultCGColorSpace {
  return CGColorSpaceCreateDeviceRGB();
}

//------------------------------------------------------------------------------
+ (NSColorSpace *)defaultColorSpace {
  return [NSColorSpace deviceRGBColorSpace];
}

//------------------------------------------------------------------------------
- (id)initWithColorName:(NSString *)name {
  NSColor *color = [NSColor colorWithString:name];
  if ((self = [super init])) {
    if (!color)
      color = [NSColor whiteColor];

    [self setColor:color];
  }
  
  return self;
}

//------------------------------------------------------------------------------
- (NSColor *)color {
  return [NSColor colorWithDeviceRed:color_[0] green:color_[1] blue:color_[2] alpha:color_[3]];
}

//------------------------------------------------------------------------------
- (void)setColor:(NSColor *)color {
  NSColor *rgba = [color colorUsingColorSpace:[Color defaultColorSpace]];
  [rgba getComponents:color_];
  hsb_[0] = kInvalidHue;
}
          
//------------------------------------------------------------------------------
- (CGColorRef)createCGColor {
  CGColorSpaceRef cs = [Color createDefaultCGColorSpace];
  CGColorRef color = CGColorCreate(cs, color_);
  CGColorSpaceRelease(cs);
  
  return color;
}

//------------------------------------------------------------------------------
- (void)getComponents:(CGFloat *)components {
  memcpy(components, color_, sizeof(color_));
}

//------------------------------------------------------------------------------
- (void)getHSBComponents:(CGFloat *)components {
  [self ensureHSB];
  memcpy(components, hsb_, sizeof(hsb_));
}

//------------------------------------------------------------------------------
- (void)setComponents:(CGFloat *)components rgb:(BOOL)isRGB {
  if (isRGB) {
    memcpy(color_, components, sizeof(color_));
    hsb_[0] = kInvalidHue;
  } else {
    memcpy(hsb_, components, sizeof(hsb_));
    [self updateRGBFromHSB];
  }
}

//------------------------------------------------------------------------------
- (void)getRGBAPixel:(unsigned long *)pixel {
  unsigned long temp;
  temp = (unsigned long)rint(color_[0] * 255.0);
  temp <<= 8;
  temp |= (unsigned long)rint(color_[1] * 255.0);
  temp <<= 8;
  temp |= (unsigned long)rint(color_[2] * 255.0);
  temp <<= 8;
  temp |= (unsigned long)rint(color_[3] * 255.0);
  
  if (pixel)
    *pixel = temp;
}

//------------------------------------------------------------------------------
static int RGBPropertyToIndex(NSString *property) {
  int index = kInvalidColorIndex;
  if ([property isEqualToString:@"red"] || [property isEqualToString:@"r"])
    index = 0;
  else if ([property isEqualToString:@"green"] || [property isEqualToString:@"g"])
    index = 1;
  else if ([property isEqualToString:@"blue"] || [property isEqualToString:@"b"])
    index = 2;
  else if ([property isEqualToString:@"alpha"] || [property isEqualToString:@"a"])
    index = 3;
  
  return index;
}

//------------------------------------------------------------------------------
static int HSBPropertyToIndex(NSString *property) {
  int index = kInvalidColorIndex;
  if ([property isEqualToString:@"hue"])
    index = 0;
  else if ([property isEqualToString:@"saturation"])
    index = 1;
  else if ([property isEqualToString:@"brightness"])
    index = 2;
  
  return index;
}

//------------------------------------------------------------------------------
- (void)ensureHSB {
  if (hsb_[0] == kInvalidHue) {
    NSColor *color = [self color];
    [color getHue:&hsb_[0] saturation:&hsb_[1] brightness:&hsb_[2] alpha:NULL];
  }  
}

//------------------------------------------------------------------------------
- (void)updateRGBFromHSB {
  NSColor *color = [NSColor colorWithCalibratedHue:hsb_[0] saturation:hsb_[1] brightness:hsb_[2] alpha:color_[3]];
  [color getRed:&color_[0] green:&color_[1] blue:&color_[2] alpha:&color_[3]];
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Properties ||
//------------------------------------------------------------------------------
- (id)valueForKey:(NSString *)key {
  int colorIdx = RGBPropertyToIndex(key);

  if (colorIdx != kInvalidColorIndex)
    return [NSNumber numberWithFloat:color_[colorIdx]];
  else 
    colorIdx = HSBPropertyToIndex(key);
  
  if (colorIdx != kInvalidColorIndex) {
    [self ensureHSB];
    
    if (colorIdx != kInvalidColorIndex)
      return [NSNumber numberWithFloat:hsb_[colorIdx]];
  }

  return nil;
}

//------------------------------------------------------------------------------
- (void)setValue:(id)value forKey:(NSString *)key {
  int colorIdx = RGBPropertyToIndex(key);
  CGFloat floatValue = MAX(0, MIN(1, [RuntimeObject coerceObjectToDouble:value]));
  
  if (colorIdx != kInvalidColorIndex) {
    color_[colorIdx] = floatValue;
    hsb_[0] = kInvalidHue;
  } else {
    [self ensureHSB];
    colorIdx = HSBPropertyToIndex(key);
    
    if (colorIdx != kInvalidColorIndex) {
      hsb_[colorIdx] = floatValue;
      [self updateRGBFromHSB];
    }
  }
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Methods ||
//------------------------------------------------------------------------------
- (Color *)blend:(NSArray *)arguments {
  Color *result = nil;
  
  if ([arguments count] >= 1) {
    Color *blendColor = [RuntimeObject coerceArray:arguments objectAtIndex:0 toClass:[Color class]];
    
    if (blendColor) {
      CGFloat fraction = 0.5;
      
      if ([arguments count] == 2)
        fraction = MAX(0, MIN(1, [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:1]]));
      
      NSColor *blend = [[self color] blendedColorWithFraction:fraction ofColor:[blendColor color]];
      result = [[[Color alloc] init] autorelease];
      [result setColor:blend];
    }
  }
  
  return result;
}

//------------------------------------------------------------------------------
- (Color *)vary:(NSArray *)arguments {
  Color *result = nil;
  CGFloat c[4];
  
  if ([arguments count] >= 3) {
    c[0] = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:0]];
    c[1] = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:1]];
    c[2] = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:2]];
    c[3] = 0;
    
    if ([arguments count] >= 4)
      c[3] = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:3]];
    
    NSColor *color = [self color];
    NSColor *varied = [color varyColorRed:c[0] green:c[1] blue:c[2] alpha:c[3]];
    result = [[[Color alloc] init] autorelease];
    [result setColor:varied];
  }
  
  return result;
}

//------------------------------------------------------------------------------
- (Color *)darker:(NSArray *)arguments {
  CGFloat amount = 0.2;
  
  if ([arguments count] == 1)
    amount = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:0]];
    
  return [self adjustColorBrightness:-amount];
}

//------------------------------------------------------------------------------
- (Color *)lighter:(NSArray *)arguments {
  CGFloat amount = 0.2;
  
  if ([arguments count] == 1)
    amount = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:0]];

  return [self adjustColorBrightness:amount];
}

//------------------------------------------------------------------------------
- (Color *)contrasting:(NSArray *)arguments {
  CGFloat amount = 0.2;
  NSColor *color = [self color];
  
  if ([arguments count] == 1)
    amount = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:0]];

  NSColor *adjusted = [color contrastingColor:amount];
  Color *result = [[[Color alloc] init] autorelease];
  [result setColor:adjusted];
  return result;
}

//------------------------------------------------------------------------------
- (BOOL)isEqualToColor:(Color *)color {
  if (color) {
    CGFloat c[4];
    [color getComponents:c];
    if ((color_[0] == c[0]) &&
        (color_[1] == c[1]) &&
        (color_[2] == c[2]) &&
        (color_[3] == c[3]))
      return YES;
  }
  
  return NO;
}

//------------------------------------------------------------------------------
- (BOOL)isEqual:(NSArray *)arguments {
  Color *c = nil;
  
  if ([arguments count] == 1)
    c = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[Color class]];
  
  return [self isEqualToColor:c];
}

//------------------------------------------------------------------------------
- (NSString *)toString {
  return [NSString stringWithFormat:@"(%g, %g, %g, %g)",
          color_[0], color_[1], color_[2], color_[3]];
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Private ||
//------------------------------------------------------------------------------
- (Color *)adjustColorBrightness:(CGFloat)amount {
  NSColor *color = [self color];
  NSColor *adjusted = [color colorByAdjustingBrightness:amount];
  Color *result = [[[Color alloc] init] autorelease];
  [result setColor:adjusted];
  return result;
}

@end
