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

#import "RectObject.h"

@implementation RectObject

+ (NSString *)className {
  return @"Rect";
}

+ (NSSet *)properties {
  return [NSSet setWithObjects:@"x", @"y", @"width", @"height", 
          @"midX", @"midY", @"isEmpty", nil];
}

+ (NSSet *)readOnlyProperties {
  return [NSSet setWithObjects:@"midX", @"midY", @"isEmpty", nil];
}

+ (NSSet *)methods {
  return [NSSet setWithObjects:@"inset", @"intersect", @"union",
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

- (BOOL)isEmpty {
  return NSIsEmptyRect(rect_);
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

- (NSString *)toString {
  return NSStringFromRect(rect_);
}

@end
