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

#import "PointObject.h"

@implementation PointObject 
+ (NSString *)className {
  return @"Point";
}

+ (NSSet *)properties {
  return [NSSet setWithObjects:@"x", @"y", nil];
}

+ (NSSet *)methods {
  return [NSSet setWithObjects:@"add", @"distance", @"toString", nil];
}

- (id)initWithArguments:(NSArray *)arguments {
  if ((self = [super initWithArguments:arguments])) {
    int count = [arguments count];
    
    PointObject *obj = [RuntimeObject coerceArray:arguments objectAtIndex:0 toClass:[PointObject class]];
    if (obj) {
      pt_.x += [obj x];
      pt_.y += [obj y];
    } else if (count >= 2) {
      pt_.x = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:0]];
      pt_.y = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:1]];
    }
  }
  
  return self;
}

- (id)initWithPoint:(NSPoint)pt {
  if ((self = [super init])) {
    pt_ = pt;
  }
  
  return self;
}

- (NSPoint)point {
  return pt_;
}

- (void)setPoint:(NSPoint)point {
  pt_ = point;
}

- (void)setX:(CGFloat)x {
  pt_.x = x;
}

- (CGFloat)x {
  return pt_.x;
}

- (void)setY:(CGFloat)y {
  pt_.y = y;
}

- (CGFloat)y {
  return pt_.y;
}

- (PointObject *)add:(NSArray *)arguments {
  PointObject *pt = [[[PointObject alloc] initWithArguments:arguments] autorelease];
  
  [pt setX:[pt x] + pt_.x];
  [pt setY:[pt y] + pt_.y];
  
  return pt;
}

- (CGFloat)distance:(NSArray *)arguments {
  PointObject *pt = [[[PointObject alloc] initWithArguments:arguments] autorelease];
  
  CGFloat x = [pt x] - pt_.x;
  CGFloat y = [pt y] - pt_.y;
  
  return sqrt(x * x + y * y);
}

- (NSString *)toString {
  return [self description];
}

- (NSString *)description {
  return NSStringFromPoint(pt_);
}

@end