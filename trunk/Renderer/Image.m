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

#import "Exporter.h"
#import "Image.h"
#import "Layer.h"

@implementation Image
//------------------------------------------------------------------------------
+ (NSString *)className {
  return @"Image";
}

//------------------------------------------------------------------------------
+ (NSSet *)properties {
  return [NSSet setWithObjects:@"alpha", @"blendMode", @"width", @"height", nil];
}

//------------------------------------------------------------------------------
+ (NSSet *)readOnlyProperties {
  return [NSSet setWithObjects:@"width", @"height", nil];
}

//------------------------------------------------------------------------------
+ (NSSet *)methods {
  return [NSSet setWithObjects:@"exportImage", @"toString", nil];
}

//------------------------------------------------------------------------------
- (id)initWithArguments:(NSArray *)arguments {
  if ((self = [super initWithArguments:arguments])) {
    int count = [arguments count];
    alpha_ = 1.0;
    
    // Can initialize with a Layer or a URL
    if (count == 1) {
      Layer *layer = [RuntimeObject coerceArray:arguments objectAtIndex:0 toClass:[Layer class]];
      if (layer) {
        // Make a copy of the current layer's image
        image_ = CGBitmapContextCreateImage([layer backingStore]);
      } else {
        NSString *urlStr = [RuntimeObject coerceArray:arguments objectAtIndex:0 toClass:[NSString class]];
        
        if ([urlStr length]) {
          NSURL *url = [NSURL URLWithString:urlStr];
          NSData *data = [NSData dataWithContentsOfURL:url];
          CGImageSourceRef src = CGImageSourceCreateWithData((CFDataRef)data, NULL);
          
          if (CGImageSourceGetCount(src))
            image_ = CGImageSourceCreateImageAtIndex(src, 0, NULL);
        }
      }
      
      width_ = (NSUInteger)CGImageGetWidth(image_);
      height_ = (NSUInteger)CGImageGetHeight(image_);
    }
  }
  
  return self;
}

//------------------------------------------------------------------------------
- (id)initWithCGImage:(CGImageRef)image {
  if ((self = [self initWithArguments:nil])) {
    image_ = CGImageRetain(image);
  }

  return self;
}

//------------------------------------------------------------------------------
- (void)dealloc {
  CGImageRelease(image_);
  [super dealloc];
}

//------------------------------------------------------------------------------
- (CGImageRef)cgImage {
  return image_;
}

//------------------------------------------------------------------------------
- (void)setAlpha:(CGFloat)alpha {
  alpha_ = alpha;
}

//------------------------------------------------------------------------------
- (CGFloat)alpha {
  return alpha_;
}

//------------------------------------------------------------------------------
- (void)setBlendMode:(NSString *)blendMode {
  blendMode_ = [[self class] blendModeFromString:blendMode];
}

//------------------------------------------------------------------------------
- (NSString *)blendMode {
  return [[self class] blendModeToString:blendMode_];
}

//------------------------------------------------------------------------------
- (CGBlendMode)cgBlendMode {
  return blendMode_;
}

//------------------------------------------------------------------------------
- (NSUInteger)width {
  return width_;
}

//------------------------------------------------------------------------------
- (NSUInteger)height {
  return height_;
}

//------------------------------------------------------------------------------
// Export the image to ~/Application Support/Google/TopDrawDrawings
- (void)exportImage:(NSArray *)arguments {
  NSString *name = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[NSString class]];
  NSString *type = [name pathExtension];
  
  // Ensure just the name
  name = [name lastPathComponent];
  
  if ([arguments count] > 1)
    type = [RuntimeObject coerceObject:[arguments objectAtIndex:1] toClass:[NSString class]];
  
  if (![type length])
    type = @"jpeg";
  
  if ([name length]) {
    NSString *safeName = [name lastPathComponent];
    NSString *path = [[Exporter imageStorageDirectory] stringByAppendingPathComponent:safeName];
    [Exporter exportImage:image_ path:path type:type quality:1.0];
  }
}

//------------------------------------------------------------------------------
- (NSString *)description {
  return [NSString stringWithFormat:@"%d x %d image, %g alpha, %@ blend mode",
          width_, height_, alpha_, [Layer blendModeToString:blendMode_]];
}

@end
