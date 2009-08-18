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

#import "Randomizer.h"
#import "RectObject.h"

@implementation RectObject

+ (NSString *)className {
  return @"Rect";
}

+ (NSSet *)properties {
  return [NSSet setWithObjects:@"x", @"y", @"width", @"height", 
          @"midX", @"midY", @"maxX", @"maxY", @"center", @"isEmpty", @"pointtypes", nil];
}

+ (NSSet *)readOnlyProperties {
  return [NSSet setWithObjects:@"midX", @"midY", @"maxX", @"maxY", @"center", @"isEmpty", 
          @"pointTypes", nil];
}

+ (NSSet *)methods {
  return [NSSet setWithObjects:@"normalize", @"inset", @"intersect", @"union", @"point",
          @"toString", nil];
}

- (id)initWithArguments:(NSArray *)arguments {
  if ((self = [super initWithArguments:arguments])) {
    int count = [arguments count];
    rect_ = NSZeroRect;
    
    if (count == 1) {
      RectObject *r = [RuntimeObject coerceArray:arguments objectAtIndex:0 toClass:[RectObject class]];
      rect_ = [r rect];
    } else if (count == 2) {
      rect_.origin = NSZeroPoint;
      rect_.size.width = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:0]];
      rect_.size.height = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:1]];
    } else if (count >= 4) {
      rect_.origin.x = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:0]];
      rect_.origin.y = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:1]];
      rect_.size.width = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:2]];
      rect_.size.height = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:3]];
    }
  }
  
  return self;
}

- (id)initWithRect:(NSRect)rect {
  if ((self = [super init])) {
    rect_ = rect;
  }
  
  return self;
}

- (NSRect)rect {
  return rect_;
}

- (void)setRect:(NSRect)rect {
  rect_ = rect;
}

- (void)setX:(CGFloat)x {
  rect_.origin.x = x;
}

- (CGFloat)x {
  return rect_.origin.x;
}

- (void)setY:(CGFloat)y {
  rect_.origin.y = y;
}

- (CGFloat)y {
  return rect_.origin.y;
}

- (void)setWidth:(CGFloat)width {
  rect_.size.width = width;
}

- (CGFloat)width {
  return rect_.size.width;
}

- (void)setHeight:(CGFloat)height {
  rect_.size.height = height;
}

- (CGFloat)height {
  return rect_.size.height;
}

- (CGFloat)midX {
  return NSMidX(rect_);
}

- (CGFloat)midY {
  return NSMidY(rect_);
}

- (CGFloat)maxX {
  return NSMaxX(rect_);
}

- (CGFloat)maxY {
  return NSMaxY(rect_);
}

- (PointObject *)center {
  return [[[PointObject alloc] initWithPoint:NSMakePoint(NSMidX(rect_), NSMidY(rect_))] autorelease];
}

- (BOOL)isEmpty {
  return NSIsEmptyRect(rect_);
}

- (NSArray *)pointTypes {
  return [NSArray arrayWithObjects:
    @"topleft", @"topcenter", @"topright",
    @"centerleft", @"center", @"centerright",
    @"bottomleft", @"bottomcenter", @"bottomright",
          nil];
}

- (void)normalize {
  if (rect_.size.width < 0) {
    rect_.size.width = -rect_.size.width;
    rect_.origin.x -= rect_.size.width;
  }

  if (rect_.size.height < 0) {
    rect_.size.height = -rect_.size.height;
    rect_.origin.y -= rect_.size.height;
  }
}

- (RectObject *)inset:(NSArray *)arguments {
  float dx = 0;
  float dy = 0;
  int count = [arguments count];
  
  // Uniform inset
  if (count >= 1) {
    dx = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:0]];
    dy = dx;
  }
  
  // Width and height
  if (count == 2)
    dy = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:1]];
  
  return [[[RectObject alloc] initWithRect:NSInsetRect(rect_, dx, dy)] autorelease];
}

- (RectObject *)intersect:(NSArray *)arguments {
  RectObject *otherRectObj = [[[RectObject alloc] initWithArguments:arguments] autorelease];
  NSRect otherRect = [otherRectObj rect];
  
  return [[[RectObject alloc] initWithRect:NSIntersectionRect(rect_, otherRect)] autorelease];
}

- (RectObject *)union:(NSArray *)arguments {
  RectObject *otherRectObj = [[[RectObject alloc] initWithArguments:arguments] autorelease];
  NSRect otherRect = [otherRectObj rect];
  
  return [[[RectObject alloc] initWithRect:NSUnionRect(rect_, otherRect)] autorelease];
}

- (RectObject *)point:(NSArray *)arguments {
  NSPoint pt = NSZeroPoint;

  if ([arguments count] == 1) {
    NSString *locStr = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[NSString class]];
    locStr = [locStr lowercaseString];
    
    if ([locStr isEqualToString:@"random"]) {
      NSArray *types = [self pointTypes];
      int idx = RandomizerFloatValue() * ([types count] - 1);
      locStr = [types objectAtIndex:idx];
    }
    
    if ([locStr isEqualToString:@"topleft"])
      pt = NSMakePoint(NSMinX(rect_), NSMaxY(rect_));
    else if ([locStr isEqualToString:@"topcenter"])
      pt = NSMakePoint(NSMidX(rect_), NSMaxY(rect_));
    else if ([locStr isEqualToString:@"topright"])
      pt = NSMakePoint(NSMaxX(rect_), NSMaxY(rect_));
    else if ([locStr isEqualToString:@"centerleft"])
      pt = NSMakePoint(NSMinX(rect_), NSMidY(rect_));
    else if ([locStr isEqualToString:@"center"])
      pt = NSMakePoint(NSMidX(rect_), NSMidY(rect_));
    else if ([locStr isEqualToString:@"centerright"])
      pt = NSMakePoint(NSMaxX(rect_), NSMidY(rect_));
    else if ([locStr isEqualToString:@"bottomleft"])
      pt = NSMakePoint(NSMinX(rect_), NSMinY(rect_));
    else if ([locStr isEqualToString:@"bottomcenter"])
      pt = NSMakePoint(NSMidX(rect_), NSMinY(rect_));
    else if ([locStr isEqualToString:@"bottomright"])
      pt = NSMakePoint(NSMaxX(rect_), NSMinY(rect_));
  }
  
  return [[[PointObject alloc] initWithPoint:pt] autorelease];
}

- (NSString *)toString {
  return NSStringFromRect(rect_);
}

@end
