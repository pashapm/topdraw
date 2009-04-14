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

#import "Compositor.h"
#import "Function.h"
#import "Layer.h"
#import "LSystem.h"
#import "PointObject.h"
#import "Runtime.h"

static inline CGFloat DegToRad(CGFloat deg) {
  return M_PI * deg / 180.0;
}

static inline CGFloat RadToDeg(CGFloat rad) {
  return rad * 180.0 / M_PI;
}

@interface LSystem(PrivateMethods)
- (void)drawRule:(NSString *)rule depth:(int)depth length:(CGFloat)length;
@end

@implementation LSystem
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || RuntimeObject ||
//------------------------------------------------------------------------------
+ (NSString *)className {
  return @"LSystem";
}

//------------------------------------------------------------------------------
+ (NSSet *)properties {
  return [NSSet setWithObjects:@"angle", 
          @"length", @"lengthScale",
          @"root", @"depth", @"lastRule", @"lastTurn",
          @"drawFunction", nil];
}

//------------------------------------------------------------------------------
+ (NSSet *)readOnlyProperties {
  return [NSSet setWithObjects:@"depth", @"lastRule", @"lastTurn", nil];
}

//------------------------------------------------------------------------------
+ (NSSet *)methods {
  return [NSSet setWithObjects:@"addRule", @"drawInLayer", @"toString", nil];
}

//------------------------------------------------------------------------------
- (id)initWithArguments:(NSArray *)arguments {
  if ((self = [super initWithArguments:arguments])) {
    angle_ = DegToRad(20);
    length_ = 40;
    lengthScale_ = 1.0;
    root_ = @"1";
    rules_ = [[NSMutableDictionary alloc] init];
    
    [rules_ setObject:@"DD+1" forKey:@"1"];
  }
  return self;
}

//------------------------------------------------------------------------------
- (void)dealloc {
  [drawFunction_ release];
  [super dealloc];
}

//------------------------------------------------------------------------------
- (CGFloat)angle {
  return RadToDeg(angle_);
}

//------------------------------------------------------------------------------
- (void)setAngle:(CGFloat)angle {
  angle_ = DegToRad(angle);
}

//------------------------------------------------------------------------------
- (CGFloat)length {
  return length_;
}

//------------------------------------------------------------------------------
- (void)setLength:(CGFloat)length {
  length_ = length;
}

//------------------------------------------------------------------------------
- (CGFloat)lengthScale {
  return lengthScale_;
}

//------------------------------------------------------------------------------
- (void)setLengthScale:(CGFloat)scale {
  lengthScale_ = scale;
}

//------------------------------------------------------------------------------
- (void)setDrawFunction:(Function *)drawFunction {
  [drawFunction_ autorelease];
  
  if ([drawFunction isKindOfClass:[Function class]])
    drawFunction_ = [drawFunction retain];
  else
    drawFunction_ = nil;
}

//------------------------------------------------------------------------------
- (void)setRoot:(NSString *)root {
  [root_ release];
  root_ = [root copy];
}

//------------------------------------------------------------------------------
- (NSString *)root {
  return root_;
}

//------------------------------------------------------------------------------
- (int)depth {
  return depth_;
}

//------------------------------------------------------------------------------
- (NSString *)lastRule {
  return [NSString stringWithCharacters:&lastRule_ length:1];
}

//------------------------------------------------------------------------------
- (NSString *)lastTurn {
  return [NSString stringWithCharacters:&lastTurn_ length:1];
}

//------------------------------------------------------------------------------
// args: rule, string
- (void)addRule:(NSArray *)arguments {
  if ([arguments count] < 2)
    return;
  
  NSString *rule = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[NSString class]];
  NSString *replacement = [RuntimeObject coerceObject:[arguments objectAtIndex:1] toClass:[NSString class]];
  
  if (rule && replacement)
    [rules_ setObject:replacement forKey:rule];
}

//------------------------------------------------------------------------------
- (void)drawAtCurrentLocation:(int)depth length:(CGFloat)length{

  if (drawFunction_) {
    depth_ = depth;
    [[drawFunction_ runtime] invokeFunction:drawFunction_ arguments:[NSArray arrayWithObject:self]];
  } else {
    CGContextBeginPath(layerRef_);
    CGContextMoveToPoint(layerRef_, 0, 0);
    CGContextAddLineToPoint(layerRef_, 0, length);
    CGContextStrokePath(layerRef_);
  }
  
  CGContextTranslateCTM(layerRef_, 0, length);
}

//------------------------------------------------------------------------------
- (void)drawCommand:(unichar)cmd depth:(int)depth length:(CGFloat)length {
  lastRule_ = cmd;

  switch (cmd) {
    case '+':
      CGContextRotateCTM(layerRef_, -angle_);
      lastTurn_ = cmd;
      break;
      
    case '-':
      CGContextRotateCTM(layerRef_, angle_);
      lastTurn_ = cmd;
      break;
      
    case '[':
      CGContextSaveGState(layerRef_);
      break;
      
    case ']':
      CGContextRestoreGState(layerRef_);
      break;
      
    default: {
      if (depth > 0) {
        NSString *cmdStr = [NSString stringWithCharacters:&cmd length:1];
        NSString *rule = [rules_ objectForKey:cmdStr];
        [self drawRule:rule depth:depth length:length];
      } else {
        [self drawAtCurrentLocation:depth length:length];
      }
    }
  }
}

//------------------------------------------------------------------------------
- (void)drawRule:(NSString *)rule depth:(int)depth length:(CGFloat)length {
  int len = [rule length];
  
  length *= lengthScale_;
  
  if (len)
    for (int i = 0; i < len; ++i)
      [self drawCommand:[rule characterAtIndex:i] depth:depth - 1 length:length];  
  else
    [self drawAtCurrentLocation:depth length:length];
}

//------------------------------------------------------------------------------
// Args: layer, depth
- (void)drawInLayer:(NSArray *)arguments {
  if ([arguments count] < 1 || [arguments count] > 2)
    return;
  
  int depth = 10;
  
  if ([arguments count] > 1)
    depth = [RuntimeObject coerceObjectToInteger:[arguments objectAtIndex:1]];
  
  runtime_ = [drawFunction_ runtime];
  Layer *layer = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[Layer class]];
  layerRef_ = [layer backingStore];

  // Draw
  CGContextSaveGState(layerRef_);
  [self drawRule:root_ depth:depth + 1 length:length_];
  CGContextRestoreGState(layerRef_);
}

@end
