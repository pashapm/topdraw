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

@implementation Image

+ (NSString *)className {
  return @"Image";
}

+ (NSSet *)properties {
  return [NSSet setWithObjects:@"alpha", @"blendMode", @"width", @"height", nil];
}

+ (NSSet *)readOnlyProperties {
  return [NSSet setWithObjects:@"width", @"height", nil];
}

+ (NSSet *)methods {
  return [NSSet setWithObjects:@"toString", nil];
}

+ (CGBlendMode)blendModeFromString:(NSString *)blendModeStr {
  static NSDictionary *sBlendMode = nil;
  
  @synchronized (sBlendMode) {
    if (!sBlendMode) {
      sBlendMode = [[NSDictionary dictionaryWithObjectsAndKeys:
                     [NSNumber numberWithInt:kCGBlendModeNormal], @"normal",
                     [NSNumber numberWithInt:kCGBlendModeMultiply], @"multiply",
                     [NSNumber numberWithInt:kCGBlendModeOverlay], @"overlay",
                     [NSNumber numberWithInt:kCGBlendModeDarken], @"darken",
                     [NSNumber numberWithInt:kCGBlendModeLighten], @"lighten",
                     [NSNumber numberWithInt:kCGBlendModeColorDodge], @"color-dodge",
                     [NSNumber numberWithInt:kCGBlendModeColorBurn], @"color-burn",
                     [NSNumber numberWithInt:kCGBlendModeSoftLight], @"soft-light",
                     [NSNumber numberWithInt:kCGBlendModeHardLight], @"hard-light",
                     [NSNumber numberWithInt:kCGBlendModeDifference], @"difference",
                     [NSNumber numberWithInt:kCGBlendModeExclusion], @"exclusion",
                     [NSNumber numberWithInt:kCGBlendModeHue], @"hue",
                     [NSNumber numberWithInt:kCGBlendModeSaturation], @"saturation",
                     [NSNumber numberWithInt:kCGBlendModeColor], @"color",
                     [NSNumber numberWithInt:kCGBlendModeLuminosity], @"luminosity",
                     nil] retain];                     
    }
  }

  return [[sBlendMode objectForKey:[blendModeStr lowercaseString]] intValue];
}

+ (NSString *)stringWithBlendMode:(CGBlendMode)blendMode {
  NSString *str = nil;
  
  switch (blendMode) {
    case kCGBlendModeNormal: str = @"normal";  break;
    case kCGBlendModeMultiply: str = @"multiply";  break;
    case kCGBlendModeScreen: str = @"screen";  break;
    case kCGBlendModeOverlay: str = @"overlay";  break;
    case kCGBlendModeDarken: str = @"darken";  break;
    case kCGBlendModeLighten: str = @"lighten";  break;
    case kCGBlendModeColorDodge: str = @"color-dodge";  break;
    case kCGBlendModeColorBurn: str = @"color-burn";  break;
    case kCGBlendModeSoftLight: str = @"soft-light";  break;
    case kCGBlendModeHardLight: str = @"hard-light";  break;
    case kCGBlendModeDifference: str = @"difference";  break;
    case kCGBlendModeExclusion: str = @"exclusion";  break;
    case kCGBlendModeHue: str = @"hue";  break;
    case kCGBlendModeSaturation: str = @"saturation";  break;
    case kCGBlendModeColor: str = @"color";  break;
    case kCGBlendModeLuminosity: str = @"luminosity";  break;
    default:
      str = @"unknown-blend-mode";
  }
  
  return str;
}

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

- (id)initWithCGImage:(CGImageRef)image {
  if ((self = [self initWithArguments:nil])) {
    image_ = CGImageRetain(image);
  }

  return self;
}

- (void)dealloc {
  CGImageRelease(image_);
  [super dealloc];
}

- (CGImageRef)image {
  return image_;
}

- (void)setAlpha:(CGFloat)alpha {
  alpha_ = alpha;
}

- (CGFloat)alpha {
  return alpha_;
}

- (void)setBlendMode:(NSString *)blendMode {
  blendMode_ = [[self class] blendModeFromString:blendMode];
}

- (NSString *)blendMode {
  return [[self class] stringWithBlendMode:blendMode_];
}

- (CGBlendMode)cgBlendMode {
  return blendMode_;
}

- (NSUInteger)width {
  return width_;
}

- (NSUInteger)height {
  return height_;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"%d x %d image, %g alpha, %@ blend mode",
          width_, height_, alpha_, [[self class] stringWithBlendMode:blendMode_]];
}

@end
