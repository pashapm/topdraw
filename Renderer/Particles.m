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
#import "GravityPoint.h"
#import "Particles.h"
#import "PointObject.h"
#import "Randomizer.h"
#import "Layer.h"

@interface Particles(PrivateMethods)
- (void)addColor:(NSArray *)arguments;
- (Color *)randomColor;
- (void)reset:(Particle *)p;
- (void)generate:(NSUInteger)count;

- (void)setMaxParticles:(NSUInteger)max;

@end

@implementation Particles
+ (NSString *)className {
  return @"Particles";
}

+ (NSSet *)properties {
  return [NSSet setWithObjects:@"maxParticles", @"gravity", @"location", 
          @"velocityXRandomizer", @"velocityYRandomizer",
          @"accelerationXRandomizer", @"accelerationYRandomizer",
          @"alphaDelay", @"alphaDelta", @"trailWidth", @"maxAge",
          nil];
}

+ (NSSet *)methods {
  return [NSSet setWithObjects:@"addColor", @"addGravityPoint", @"toString", nil];
}

- (id)initWithArguments:(NSArray *)arguments {
  if ((self == [super initWithArguments:arguments])) {
    gravity_ = CGPointMake(0, -9.8);
    alphaDelta_ = -0.01;
    alphaDelay_ = 0;
    maxAge_ = 0;
    [self setMaxParticles:100];
    
    colors_ = [[NSMutableArray alloc] init];
  }
  
  return self;  
}

- (void)dealloc {
  [velocityXRandomizer_ release];
  [velocityYRandomizer_ release];
  [accelerationXRandomizer_ release];
  [accelerationYRandomizer_ release];
  free(particles_);
  [colors_ release];
  [gravityPoints_ release];
  [super dealloc];
}

- (void)setMaxParticles:(NSUInteger)max {
  if (max > maxParticleCount_) {
    NSUInteger currentMax = maxParticleCount_;
    Particle *p = realloc(particles_, sizeof(Particle) * max);
    
    if (p)
      particles_ = p;
    else
      max = currentMax;
  }
  
  maxParticleCount_ = max;
}

- (NSUInteger)maxParticles {
  return maxParticleCount_;
}

- (void)setGravity:(id)obj {
  PointObject *pt = [RuntimeObject coerceObject:obj toClass:[PointObject class]];
  
  gravity_ = NSPointToCGPoint([pt point]);
}

- (id)gravity {
  return [[[PointObject alloc] initWithPoint:NSPointFromCGPoint(gravity_)] autorelease];
}

- (void)setLocation:(id)obj {
  PointObject *pt = [RuntimeObject coerceObject:obj toClass:[PointObject class]];
  
  location_ = NSPointToCGPoint([pt point]);
}

- (id)location {
  return [[[PointObject alloc] initWithPoint:NSPointFromCGPoint(location_)] autorelease];
}

- (void)setVelocityXRandomizer:(id)obj {
  Randomizer *r = [RuntimeObject coerceObject:obj toClass:[Randomizer class]];
  
  if (r != velocityXRandomizer_) {
    [velocityXRandomizer_ release];
    velocityXRandomizer_ = [r retain];
  }
}

- (void)setVelocityYRandomizer:(id)obj {
  Randomizer *r = [RuntimeObject coerceObject:obj toClass:[Randomizer class]];
  
  if (r != velocityYRandomizer_) {
    [velocityYRandomizer_ release];
    velocityYRandomizer_ = [r retain];
  }
}

- (void)setAccelerationXRandomizer:(id)obj {
  Randomizer *r = [RuntimeObject coerceObject:obj toClass:[Randomizer class]];
  
  if (r != accelerationXRandomizer_) {
    [accelerationXRandomizer_ release];
    accelerationXRandomizer_ = [r retain];
  }
}

- (void)setAccelerationYRandomizer:(id)obj {
  Randomizer *r = [RuntimeObject coerceObject:obj toClass:[Randomizer class]];
  
  if (r != accelerationYRandomizer_) {
    [accelerationYRandomizer_ release];
    accelerationYRandomizer_ = [r retain];
  }
}

- (void)setAlphaDelta:(CGFloat)delta {
  alphaDelta_ = delta;
}

- (CGFloat)alphaDelta {
  return alphaDelta_;
}

- (void)setTrailWidth:(CGFloat)width {
  trailWidth_ = width;
}

- (CGFloat)trailWidth {
  return trailWidth_;
}

- (void)setMaxAge:(unsigned long)age {
  maxAge_ = age;
}

- (unsigned long)maxAge {
  return maxAge_;
}

- (void)setAlphaDelay:(unsigned long)delay {
  alphaDelay_ = delay;
}

- (unsigned long)alphaDelay {
  return alphaDelay_;
}

- (void)addColor:(NSArray *)arguments {
  if ([arguments count] == 1) {
    Color *c = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[Color class]];
    
    if (c)
      [colors_ addObject:c];
  }
}

- (void)addGravityPoint:(NSArray *)arguments {
  if ([arguments count] == 1) {
    GravityPoint *gp = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[GravityPoint class]];

    if (gp) {
      if (!gravityPoints_)
        gravityPoints_ = [[NSMutableArray alloc] init];

      [gravityPoints_ addObject:gp];
    }
  }
}

- (Color *)randomColor {
  NSUInteger count = [colors_ count];
  
  if (!count)
    return nil;
  
  NSUInteger idx = floor(RandomizerFloatValue() * (float)count);

  return [colors_ objectAtIndex:idx];
}

- (void)reset:(Particle *)p {
  p->location = location_;
  p->acceleration.x = [accelerationXRandomizer_ floatValue];
  p->acceleration.y = [accelerationYRandomizer_ floatValue];
  p->velocity.x = [velocityXRandomizer_ floatValue];
  p->velocity.y = [velocityYRandomizer_ floatValue];
  p->age = 0;
  
  Color *c = [self randomColor];
  if (c)
    [c getComponents:p->color];
  else
    p->color[0] = p->color[1] = p->color[2] = p->color[3] = 1.0;
}

- (void)generate:(NSUInteger)count {
  if (count + currentCount_ > maxParticleCount_)
    count = maxParticleCount_ - currentCount_;
  
  while (count--) {
    [self reset:&particles_[currentCount_]];
    ++currentCount_;
  }
}

- (void)step {
  CGContextRef context = [layer_ backingStore];
  CGRect bounds = [layer_ cgRectFrame];

  CGContextSetLineWidth(context, trailWidth_);

  // Generate one per step
  if (currentCount_ < maxParticleCount_) 
    [self generate:1];

  for (NSUInteger i = 0; i < currentCount_; ++i) {
    Particle *p = &particles_[i];
    CGPoint last = p->location;
    
    // Add any contribution from the gravity wells
    if (gravityPoints_) {
      NSUInteger gravityCount = [gravityPoints_ count];
      for (NSUInteger gravityIdx = 0; gravityIdx < gravityCount; ++gravityIdx) {
        GravityPoint *gp = [gravityPoints_ objectAtIndex:gravityIdx];
        CGPoint gravityPointAccel = [gp accelerationForPoint:p->location];
        p->acceleration.x += gravityPointAccel.x;
        p->acceleration.y += gravityPointAccel.y;
      }
    }
    
    // Apply acceleration to velocity
    p->velocity.x += (p->acceleration.x + gravity_.x) * timeStep_;
    p->velocity.y += (p->acceleration.y + gravity_.y) * timeStep_;
    
    // Apply velocity to location
    p->location.x += p->velocity.x * timeStep_;
    p->location.y += p->velocity.y * timeStep_;
    
    // Alpha delta 
    p->age += 1;

    if (!alphaDelay_ || alphaDelay_ < p->age)
      p->color[3] += alphaDelta_;
    
    // Check if this needs regeneration
    BOOL regenerate = NO;
    
    if (p->color[3] <= 0.0) {
      if (alphaDelta_ < 0)
        regenerate = YES;
    } else if (p->color[3] >= 1.0) {
      if (alphaDelta_ > 0)
        regenerate = YES;
    }
    
    if (maxAge_ && p->age > maxAge_)
      regenerate = YES;
    
    if (regenerate) {
      [self reset:p];
      continue;
    }
    
    // Draw a line
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, last.x, last.y);
    CGContextAddLineToPoint(context, p->location.x, p->location.y);
    CGContextSetRGBStrokeColor(context, p->color[0], p->color[1], p->color[2], p->color[3]);
    CGContextStrokePath(context);

    // If we've now drawn our line outside of the bounds, we're done
    if (!CGRectContainsPoint(bounds, p->location))
      [self reset:p];
  }
}

- (NSString *)toString {
  return [NSString stringWithFormat:@"Particles: %d (max: %d)", currentCount_, maxParticleCount_];
}

@end
