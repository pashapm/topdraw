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

#import "GravityPoint.h"
#import "PointObject.h"

@implementation GravityPoint
//------------------------------------------------------------------------------
+ (NSString *)className {
  return @"GravityPoint";
}

//------------------------------------------------------------------------------
+ (NSSet *)properties {
  return [NSSet setWithObjects:@"location", @"gravity", nil];
}

//------------------------------------------------------------------------------
+ (NSSet *)methods {
  return [NSSet setWithObjects:@"toString", nil];
}

//------------------------------------------------------------------------------
- (void)setLocation:(id)obj {
  PointObject *pt = [RuntimeObject coerceObject:obj toClass:[PointObject class]];
  location_ = NSPointToCGPoint([pt point]);
}

//------------------------------------------------------------------------------
- (void)setGravity:(CGFloat)g {
  gravity_ = g;
}

//------------------------------------------------------------------------------
- (NSString *)toString {
  return [NSString stringWithFormat:@"GravityWell: %@, g=%g", 
          NSStringFromPoint(NSPointFromCGPoint(location_)), gravity_];
}

//------------------------------------------------------------------------------
- (CGPoint)accelerationForPoint:(CGPoint)point {
  CGPoint d;
  CGFloat mag;
  CGPoint a = CGPointMake(gravity_, gravity_);
  
  d.x = point.x - location_.x;
  d.y = point.y - location_.y;
  mag = sqrt(d.x * d.x + d.y * d.y);
  
  if (mag > 0) {
    a.x /= mag * (d.x > 0 ? -1 : 1);
    a.y /= mag * (d.y > 0 ? -1 : 1);
  }
  
  return a;
}

@end
