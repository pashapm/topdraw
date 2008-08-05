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
#import "Gradient.h"
#import "PointObject.h"

@implementation Gradient

+ (NSString *)className {
  return @"Gradient";
}

+ (NSSet *)methods {
  return [NSSet setWithObjects:@"setColorAndLocation", @"toString", nil];
}

- (void)setColor:(Color *)color location:(CGFloat)location {
  // Reset the gradient
  CGGradientRelease(gradient_);
  gradient_ = NULL;
  
  if (location < 0)
    location = 0;
  else if (location > 1)
    location = 1;
  
  if (color)
    [colors_ setObject:color forKey:[NSNumber numberWithFloat:location]];  
}

- (void)setColorAndLocation:(NSArray *)arguments {
  if ([arguments count] == 2) {
    Color *color = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[Color class]];
    CGFloat loc = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:1]];
    [self setColor:color location:loc];
  }
}

- (id)initWithArguments:(NSArray *)arguments {
  if ((self = [super initWithArguments:arguments])) {
    colors_ = [[NSMutableDictionary alloc] init];

    // Specify colors and assume evenly spaced from 0 to 1 for locations
    int count = [arguments count];
    
    if (count) {
      CGFloat delta = 1.0 / (CGFloat)count;
      CGFloat location = 0;
      for (int i = 0; i < count; ++i) {
        Color *color = [RuntimeObject coerceObject:[arguments objectAtIndex:i] toClass:[Color class]];
        
        if (color) {
          // Adjust for rounding errors
          if (i == (count - 1))
            location = 1.0;
          
          [self setColor:color location:location];
          location += delta;
        }
      }
    }
  }
  
  return self;
}

- (void)dealloc {
  CGGradientRelease(gradient_);
  [colors_ release];
  [super dealloc];
}

- (CGGradientRef)cgGradient {
  if (!gradient_) {
    NSArray *colorLocations = [colors_ allKeys];
    int count = [colorLocations count];
    CGFloat *locations = (CGFloat *)malloc(count * sizeof(CGFloat));
    CGFloat *components = (CGFloat *)malloc(4 * count * sizeof(CGFloat));
    CGFloat c[4];
    
    for (int i = 0; i < count; ++i) {
      NSNumber *num = [colorLocations objectAtIndex:i];
      Color *color = [colors_ objectForKey:num];
      locations[i] = [num floatValue];
      [color getComponents:c];
      components[i * 4] = c[0];
      components[i * 4 + 1] = c[1];
      components[i * 4 + 2] = c[2];
      components[i * 4 + 3] = c[3];
    }
    
    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    gradient_ = CGGradientCreateWithColorComponents(cs, components, locations, count);
    CGColorSpaceRelease(cs);
    free(locations);
    free(components);
  }
  
  return gradient_;
}

- (NSString *)toString {
  return [NSString stringWithFormat:@"Gradient: %d locations and colors",
          [colors_ count]];
}

@end
