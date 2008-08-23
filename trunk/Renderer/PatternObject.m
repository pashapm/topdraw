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

#import "Image.h"
#import "Layer.h"
#import "PatternObject.h"
#import "PointObject.h"

@interface PatternObject(PrivateMethods)
- (void)setImage:(id)image;
- (void)setOffset:(id)offsetObj;
@end

static void DrawPattern(void *info, CGContextRef context) {
  CGImageRef image = (CGImageRef)info;
  CGRect bounds;
  bounds.origin = CGPointZero;
  bounds.size = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
  CGContextDrawImage(context, bounds, image);
}

@implementation PatternObject
//------------------------------------------------------------------------------
+ (NSString *)className {
  return @"Pattern";
}

//------------------------------------------------------------------------------
+ (NSSet *)properties {
  return [NSSet setWithObjects:@"image", @"offset", @"phase", nil];
}

//------------------------------------------------------------------------------
+ (NSSet *)methods {
  return [NSSet setWithObjects:@"toString", nil];
}

//------------------------------------------------------------------------------
- (id)initWithArguments:(NSArray *)arguments {
  if ((self = [super initWithArguments:arguments])) {
    //args: image/layer[, style]
    int count = [arguments count];
    
    if (count >= 1)
      [self setImage:[arguments objectAtIndex:0]];
    
    if (count >= 2)
      [self setOffset:[arguments objectAtIndex:1]];
  }
  
  return self;
}

//------------------------------------------------------------------------------
- (void)dealloc {
  CGImageRelease(image_);
  CGPatternRelease(pattern_);
  [super dealloc];
}

//------------------------------------------------------------------------------
- (CGPatternRef)cgPattern {
  if (!pattern_ && image_) {
    CGPatternCallbacks callbacks = { 0, DrawPattern, NULL };
    CGRect bounds;
    bounds.origin = CGPointZero;
    bounds.size = CGSizeMake(CGImageGetWidth(image_), CGImageGetHeight(image_));
    
    if (offset_.width == 0 && offset_.height == 0)
      offset_ = NSSizeFromCGSize(bounds.size);
    
    pattern_ = CGPatternCreate(image_, bounds, CGAffineTransformIdentity, 
                               offset_.width, offset_.height,
                               kCGPatternTilingConstantSpacingMinimalDistortion, 
                               TRUE, &callbacks);   
  }
  return pattern_;
}

//------------------------------------------------------------------------------
- (void)setImage:(id)imageObj {
  CGImageRelease(image_);
  image_ = NULL;
  CGPatternRelease(pattern_);
  pattern_ = NULL;
  offset_ = NSZeroSize;
  
  Image *image = [RuntimeObject coerceObject:imageObj toClass:[Image class]];
  if (image) {
    image_ = CGImageRetain([image cgImage]);
    return;
  }
  
  Layer *layer = [RuntimeObject coerceObject:imageObj toClass:[Layer class]];
  if (layer) {
    image_ = CGImageRetain([layer cgImage]);
  }
}

//------------------------------------------------------------------------------
- (void)setOffset:(id)offsetObj {
  PointObject *offset = [RuntimeObject coerceObject:offsetObj toClass:[PointObject class]];
  
  offset_ = NSMakeSize([offset x], [offset y]);
}

//------------------------------------------------------------------------------
- (NSSize)phase {
  return phase_;
}

//------------------------------------------------------------------------------
- (void)setPhase:(id)offsetObj {
  PointObject *offset = [RuntimeObject coerceObject:offsetObj toClass:[PointObject class]];
  
  phase_ = NSMakeSize([offset x], [offset y]);
}

@end
