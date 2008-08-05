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

#import <Accelerate/Accelerate.h>

#import "Image.h"
#import "Layer.h"
#import "Noise.h"
#import "RuntimeObject.h"

@interface Noise(PrivateMethods)
- (void)invalidate;
- (void)ensureBitmap;
- (BOOL)randomlyFillBytes:(unsigned char *)bytes size:(size_t)size;
- (void)render;
@end

@implementation Noise
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Private ||
//------------------------------------------------------------------------------
- (void)invalidate {
  free(buffer_);
  buffer_ = NULL;
  CGContextRelease(bitmap_);
  bitmap_ = NULL;
  CGImageRelease(image_);
  image_ = NULL;
}

//------------------------------------------------------------------------------
- (void)ensureBitmap {
  if (bitmap_)
    return;
  
  // Use width and height for a 32-bit/pixel ARGB.  16 byte align rowbytes
  int rowBytes = 0xFFF0 & ((4 * width_) + 0xF);
  buffer_ = malloc(height_ * rowBytes);
  CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
  CGBitmapInfo info = kCGImageAlphaPremultipliedFirst;
  bitmap_ = CGBitmapContextCreate(buffer_, width_, height_, 8, rowBytes, cs, info);
  CGColorSpaceRelease(cs);
  
  if (bitmap_) {
    [self render];
  } else {
    free(buffer_);
    buffer_ = NULL;
  }
}

//------------------------------------------------------------------------------
- (void)drawInLayer:(NSArray *)arguments {
  Layer *layer = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[Layer class]];

  if (!layer)
    return;
  
  CGRect destRect = [layer cgRectFrame];
  CGContextRef dest = [layer backingStore];
  
  CGContextDrawImage(dest, destRect, [self cgImage]);
}

//------------------------------------------------------------------------------
- (BOOL)randomlyFillBytes:(unsigned char *)bytes size:(size_t)size {
  int fd = open("/dev/random", O_RDONLY);
  
  if (fd == -1)
    return NO;
  
  read(fd, bytes, size);
  close(fd);

  return YES;
}

//------------------------------------------------------------------------------
- (void)render {
  // We'll be duplicating the data for all channels, so
  unsigned long rowBytes = CGBitmapContextGetBytesPerRow(bitmap_);
  unsigned long planeBytes = height_ * rowBytes;
  unsigned char *rData = malloc(planeBytes);
  unsigned char *gData = NULL;
  unsigned char *bData = NULL;
  unsigned char *aData = NULL;
  unsigned char *tempData = malloc(planeBytes * 4);
  
  if (alpha_ > 0.0) {
    aData = malloc(planeBytes);
    memset(aData, (unsigned long)floor(alpha_ * 255.0), planeBytes);
  }
  
  if (grayscale_) {
    gData = rData;
    bData = rData;
    
    if (!aData)
      aData = rData;
    
    [self randomlyFillBytes:rData size:planeBytes];
  } else {
    gData = malloc(planeBytes);
    bData = malloc(planeBytes);
    
    if (!aData) {
      aData = malloc(planeBytes);
      [self randomlyFillBytes:aData size:planeBytes];
    }
    
    [self randomlyFillBytes:rData size:planeBytes];
    [self randomlyFillBytes:gData size:planeBytes];
    [self randomlyFillBytes:bData size:planeBytes];    
  }
  
  vImage_Buffer srcA = { aData, height_, width_, rowBytes };
  vImage_Buffer srcR = { rData, height_, width_, rowBytes };
  vImage_Buffer srcG = { gData, height_, width_, rowBytes };
  vImage_Buffer srcB = { bData, height_, width_, rowBytes };
  vImage_Buffer tempDest = { tempData, height_, width_, rowBytes };
  vImage_Flags flags = kvImageDoNotTile;
  
  // Convert
  vImageConvert_Planar8toARGB8888(&srcA, &srcR, &srcG, &srcB, &tempDest, flags);

  // Push into our bitmap
  unsigned char *bitmapData = CGBitmapContextGetData(bitmap_);
  vImage_Buffer dest = { bitmapData, height_, width_, rowBytes };
  vImagePremultiplyData_ARGB8888(&tempDest, &dest, flags);
  
  // Cleanup
  free(rData);
  free(tempData);
  
  if (gData != rData) {
    free(gData);
    free(bData);
  }
  
  if (aData != rData)
    free(aData);
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || RuntimeObject ||
//------------------------------------------------------------------------------
+ (NSString *)className {
  return @"Noise";
}

//------------------------------------------------------------------------------
+ (NSSet *)properties {
  return [NSSet setWithObjects:@"grayscale", @"alpha", @"image", @"width", @"height", nil];
}

//------------------------------------------------------------------------------
+ (NSSet *)readOnlyProperties {
  return [NSSet setWithObjects:@"image", @"width", @"height", nil];
}

//------------------------------------------------------------------------------
+ (NSSet *)methods {
  return [NSSet setWithObjects:@"drawInLayer", @"toString", nil];
}

//------------------------------------------------------------------------------
- (id)initWithArguments:(NSArray *)arguments {
  if ((self = [super initWithArguments:arguments])) {
    // Default values
    [self setGrayscale:NO];
    [self setAlpha:0];
    
    // args: width, height, [alpha], [grayscale]
    int count = [arguments count];
    
    if (count >= 2) {
      width_ = floor([RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:0]]);
      height_ = floor([RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:1]]);
      
      if (count >= 3)
        alpha_ = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:2]];

      if (count == 4)
        grayscale_ = [[RuntimeObject coerceObject:[arguments objectAtIndex:3] toClass:[NSNumber class]] boolValue];

    } else {
      NSLog(@"Must specify width and height");
      [self release];
      self = nil;
    }
  }
  
  return self;
}

//------------------------------------------------------------------------------
- (void)dealloc {
  [self invalidate];
  [super dealloc];
}

//------------------------------------------------------------------------------
- (NSString *)toString {
  return [NSString stringWithFormat:@"Noise (%p): (%d x %d), alpha: %f, gray: %@",
          self, width_, height_, alpha_, grayscale_ ? @"YES" : @"NO"];
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Public ||
//------------------------------------------------------------------------------
- (id)initWithWidth:(unsigned int)width height:(unsigned int)height {
  NSArray *args = [NSArray arrayWithObjects:
                   [NSNumber numberWithUnsignedInt:width], 
                   [NSNumber numberWithUnsignedInt:height], 
                   nil];
  return [self initWithArguments:args];
}

//------------------------------------------------------------------------------
- (void)setGrayscale:(BOOL)grayscale {
  if (grayscale != grayscale_) {
    grayscale_ = grayscale;
    [self invalidate];
  }
}

//------------------------------------------------------------------------------
- (BOOL)grayscale {
  return grayscale_;
}

//------------------------------------------------------------------------------
- (void)setAlpha:(CGFloat)alpha {
  if (alpha != alpha_) {
    alpha_ = alpha;
    [self invalidate];
  }
}

//------------------------------------------------------------------------------
- (CGFloat)alpha {
  return alpha_;
}

//------------------------------------------------------------------------------
- (unsigned int)width {
  return width_;
}

//------------------------------------------------------------------------------
- (unsigned int)height {
  return height_;
}

//------------------------------------------------------------------------------
- (Image *)image {
  return [[[Image alloc] initWithCGImage:[self cgImage]] autorelease];
}

//------------------------------------------------------------------------------
- (CGImageRef)cgImage {
  if (image_)
    return image_;
  
  CGContextRef bitmap = [self bitmap];
  
  if (bitmap)
    image_ = CGBitmapContextCreateImage(bitmap);
  
  return image_;
}

//------------------------------------------------------------------------------
- (CIImage *)ciImage {
  return [CIImage imageWithCGImage:[self cgImage]];
}

//------------------------------------------------------------------------------
- (CGContextRef)bitmap {
  [self ensureBitmap];
  
  return bitmap_;
}

@end
