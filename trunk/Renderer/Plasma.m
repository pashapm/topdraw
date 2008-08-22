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

#import <libkern/OSAtomic.h>
#import <pthread.h>

#import "Color.h"
#import "Layer.h"
#import "Plasma.h"
#import "Randomizer.h"

// The threading seems like a great idea, except it ends up being slower and leaves
// behind some graphics trails.  It's possible that it's due to the threads exiting
// prematurely.  Worth a revist someday
#define kMaxThreads 4

typedef struct {
  NSUInteger x;
  NSUInteger y;
} UIntPoint;

typedef struct {
  NSUInteger width;
  NSUInteger height;
} UIntSize;

typedef struct {
  UIntPoint origin;
  UIntSize size;
} UIntRect;

// Used for indexing ColoredRect.colors as well
#define TOP_LEFT      0
#define TOP_RIGHT     1
#define BOTTOM_LEFT   2
#define BOTTOM_RIGHT  3

// In addition to the above, used in UIntRectPoint() function
#define CENTER        4
#define CENTER_TOP    5
#define CENTER_BOTTOM 6
#define CENTER_LEFT   7
#define CENTER_RIGHT  8

typedef struct {
  UIntRect rect;
  RGBAPixel colors[4];
} ColoredRect;

typedef struct {
  CGContextRef context;
  unsigned char *bitmap;
  NSUInteger width;
  NSUInteger height;
  NSUInteger rowBytes;
  NSUInteger rowLongs;
  CGFloat variation;
  int threadCount;
  pthread_t threads[kMaxThreads];
  BOOL grayscale;
  RGBAPixel opaqueMask;
} PlasmaData;

typedef struct {
  PlasmaData *data;
  ColoredRect cr;
  float depth;
} PlasmaThreadData;

static void *PlasmaRectThread(void *context);

static inline RGBAPixel *GetPixelAddress(PlasmaData *data, UIntPoint pt) {
  return (RGBAPixel *)(data->bitmap + pt.x * sizeof(RGBAPixel) + (pt.y * data->rowBytes));
}

static inline void SetPixel(PlasmaData *data, UIntPoint pt, RGBAPixel p) {
  RGBAPixel *dest = GetPixelAddress(data, pt);
  *dest = p;
}

static inline void SetPixelIfUnset(PlasmaData *data, UIntPoint pt, RGBAPixel p) {
  RGBAPixel *dest = GetPixelAddress(data, pt);
  if (*dest == 0)
    *dest = p;
}

static inline RGBAPixel PixelComponent(RGBAPixel p, int index) {
  switch (index) {
    case 0: return p & 0xFF;
    case 1: return (p >> 8) & 0xFF;
    case 2: return (p >> 16) & 0xFF;
    case 3: return (p >> 24) & 0xFF;
  }
  
  return 0;
}

static inline RGBAPixel PixelReverse(RGBAPixel p) {
  return PixelComponent(p, 0) << 24 | PixelComponent(p, 1) << 16 |
    PixelComponent(p, 2) << 8 | PixelComponent(p, 3); 
}

static inline NSUInteger UIntRectMinX(UIntRect *r) {
  return r->origin.x;
}

static inline NSUInteger UIntRectMinY(UIntRect *r) {
  return r->origin.y;
}

static inline NSUInteger UIntRectMaxX(UIntRect *r) {
  return r->origin.x + r->size.width;
}

static inline NSUInteger UIntRectMaxY(UIntRect *r) {
  return r->origin.y + r->size.height;
}

static inline NSUInteger UIntRectMidX(UIntRect *r) {
  return r->origin.x + r->size.width / 2.0;
}

static inline NSUInteger UIntRectMidY(UIntRect *r) {
  return r->origin.y + r->size.height / 2.0;
}

static inline UIntPoint UIntPointMake(NSUInteger x, NSUInteger y) {
  UIntPoint p;
  p.x = x;
  p.y = y;
  return p;
}

static inline UIntPoint UIntRectPoint(UIntRect *r, int pointType) {
  UIntPoint p;
  switch (pointType) {
    case TOP_LEFT: p.x = UIntRectMinX(r); p.y = UIntRectMaxY(r); break;
    case TOP_RIGHT: p.x = UIntRectMaxX(r); p.y = UIntRectMaxY(r); break;
    case BOTTOM_LEFT: p.x = UIntRectMinX(r); p.y = UIntRectMinY(r); break;
    case BOTTOM_RIGHT: p.x = UIntRectMaxX(r); p.y = UIntRectMinY(r); break;
    case CENTER: p.x = UIntRectMidX(r); p.y = UIntRectMidY(r); break;
    case CENTER_TOP: p.x = UIntRectMidX(r); p.y = UIntRectMaxY(r); break;
    case CENTER_BOTTOM: p.x = UIntRectMidX(r); p.y = UIntRectMinY(r); break;
    case CENTER_LEFT: p.x = UIntRectMinX(r); p.y = UIntRectMidY(r); break;
    case CENTER_RIGHT: p.x = UIntRectMaxX(r); p.y = UIntRectMidY(r); break;
  }
  
  return p;
}

static inline RGBAPixel BlendComponents(RGBAPixel a, RGBAPixel b, int idx, float variation) {
  // Values should be 0 - 255
  if (variation > 0) {
    int aDelta = (255.0f * variation) * (1.0f - RandomizerFloatValue() * 2.0f);
    int bDelta = (255.0f * variation) * (1.0f - RandomizerFloatValue() * 2.0f);
    int aComponent = (int)PixelComponent(a, idx) + aDelta;
    int bComponent = (int)PixelComponent(b, idx) + bDelta;
    a = MIN(MAX(0, aComponent), 255);
    b = MIN(MAX(0, bComponent), 255);
  } else {
    a = PixelComponent(a, idx);
    b = PixelComponent(b, idx);
  }
  
  return (a + b) / 2;
}

static inline RGBAPixel BlendPixel(PlasmaData *data, RGBAPixel a, RGBAPixel b, float variation) {
  RGBAPixel result = 0;
  if (data->grayscale) {
    result = BlendComponents(a, b, 0, variation);
    result |= result << 8 | result << 16 | result << 24;
  } else {
    result = BlendComponents(a, b, 3, variation); result <<= 8;
    result |= BlendComponents(a, b, 2, variation); result <<= 8;
    result |= BlendComponents(a, b, 1, variation); result <<= 8;
    result |= BlendComponents(a, b, 0, variation);
  }
  
  if (data->opaqueMask)
    result |= data->opaqueMask;
  
  return result;
}

static void DrawRectCorners(PlasmaData *data, ColoredRect *cr, float variation) {
  // Corners
  SetPixel(data, UIntRectPoint(&cr->rect, TOP_LEFT), cr->colors[TOP_LEFT]);
  SetPixel(data, UIntRectPoint(&cr->rect, TOP_RIGHT), cr->colors[TOP_RIGHT]);
  SetPixel(data, UIntRectPoint(&cr->rect, BOTTOM_LEFT), cr->colors[BOTTOM_LEFT]);
  SetPixel(data, UIntRectPoint(&cr->rect, BOTTOM_RIGHT), cr->colors[BOTTOM_RIGHT]);
}

static void DrawRectEdgesAndMiddle(PlasmaData *data, ColoredRect *cr, float variation) {
  // Edge Mid points
  RGBAPixel ctp = BlendPixel(data, cr->colors[TOP_LEFT], cr->colors[TOP_RIGHT], variation);
  RGBAPixel cbp = BlendPixel(data, cr->colors[BOTTOM_LEFT], cr->colors[BOTTOM_RIGHT], variation);
  RGBAPixel clp = BlendPixel(data, cr->colors[TOP_LEFT], cr->colors[BOTTOM_LEFT], variation);
  RGBAPixel crp = BlendPixel(data, cr->colors[TOP_RIGHT], cr->colors[BOTTOM_RIGHT], variation);
  
  SetPixelIfUnset(data, UIntRectPoint(&cr->rect, CENTER_TOP), ctp);
  SetPixelIfUnset(data, UIntRectPoint(&cr->rect, CENTER_BOTTOM), cbp);
  SetPixelIfUnset(data, UIntRectPoint(&cr->rect, CENTER_LEFT), clp);
  SetPixelIfUnset(data, UIntRectPoint(&cr->rect, CENTER_RIGHT), crp);
  
  // Center
  RGBAPixel c1 = BlendPixel(data, ctp, cbp, 0);
  RGBAPixel c2 = BlendPixel(data, clp, crp, 0);
  SetPixelIfUnset(data, UIntRectPoint(&cr->rect, CENTER), BlendPixel(data, c1, c2, 0));
}

// Clockwise from lower left
// Because of rounding, make sure that there's 1 pixel overlap
//
// +---+---+
// | b | c |
// +---+---+
// | a | d |
// +---+---+
//

static void SubdivideGeometry(UIntRect *src, UIntRect *a, UIntRect *b, UIntRect *c, UIntRect *d) {
  a->origin = src->origin;
  a->size.width = src->size.width / 2;
  a->size.height = src->size.height / 2;
  
  // Calculate the rest of the rectangles releative to this
  b->origin.x = UIntRectMinX(a);
  b->origin.y = UIntRectMaxY(a);
  b->size.width = a->size.width;
  b->size.height = UIntRectMaxY(src) - UIntRectMaxY(a);
  
  c->origin.x = UIntRectMaxX(b);
  c->origin.y = UIntRectMinY(b);
  c->size.width = UIntRectMaxX(src) - UIntRectMaxX(b);
  c->size.height = b->size.height;
  
  d->origin.x = UIntRectMinX(c);
  d->origin.y = UIntRectMinY(a);
  d->size.width = c->size.width;
  d->size.height = a->size.height;
}

static void ReadColorsForRect(PlasmaData *data, ColoredRect *cr) {
  cr->colors[TOP_LEFT] = *(GetPixelAddress(data, UIntRectPoint(&cr->rect, TOP_LEFT)));
  cr->colors[TOP_RIGHT] = *(GetPixelAddress(data, UIntRectPoint(&cr->rect, TOP_RIGHT)));
  cr->colors[BOTTOM_LEFT] = *(GetPixelAddress(data, UIntRectPoint(&cr->rect, BOTTOM_LEFT)));
  cr->colors[BOTTOM_RIGHT] = *(GetPixelAddress(data, UIntRectPoint(&cr->rect, BOTTOM_RIGHT)));
}

static void Subdivide(PlasmaData *data, ColoredRect *cr, ColoredRect *a, 
                      ColoredRect *b, ColoredRect *c, ColoredRect *d) {
  SubdivideGeometry(&cr->rect, &a->rect, &b->rect, &c->rect, &d->rect);
  ReadColorsForRect(data, a);
  ReadColorsForRect(data, b);
  ReadColorsForRect(data, c);
  ReadColorsForRect(data, d);
}

static void PlasmaRect(PlasmaData *data, ColoredRect *cr, float depth) {
  // One pixel or smaller, exit
  unsigned int width = cr->rect.size.width;
  unsigned int height = cr->rect.size.height;
  
  if (width < 2 && height < 2)
    return;

  float variation = data->variation * data->variation / depth;	// Less as you go deeper

  // Draw stuff
  DrawRectEdgesAndMiddle(data, cr, variation);

  // Subdivide & load 
  ColoredRect subRect[4];
  Subdivide(data, cr, &subRect[0], &subRect[1], &subRect[2], &subRect[3]);

  // Recursive descent
  for (int i = 0; i < 4; ++i) {
    if (data->threadCount < kMaxThreads && depth <= 1) {
      OSAtomicIncrement32(&data->threadCount);
      PlasmaThreadData *threadData = (PlasmaThreadData *)malloc(sizeof(PlasmaThreadData));
      threadData->data = data;
      threadData->cr = subRect[i];
      threadData->depth = depth + 1;
      pthread_t threadID;
      pthread_create(&threadID, NULL, PlasmaRectThread, threadData);
      pthread_detach(threadID);
    } else {
      PlasmaRect(data, &subRect[i], depth + 1);
    }
  }
}

static void *PlasmaRectThread(void *context) {
  PlasmaThreadData *threadData = (PlasmaThreadData *)context;
#if 0
  NSLog(@"Created thread %x rect: (%d, %d) x (%d, %d) (Count: %d)", pthread_self(),
        threadData->cr.rect.origin.x,
        threadData->cr.rect.origin.y,
        threadData->cr.rect.size.width,
        threadData->cr.rect.size.height,
        threadData->data->threadCount);
#endif
  
  PlasmaRect(threadData->data, &threadData->cr, threadData->depth);
  
  // Decrement the thread count
  OSAtomicDecrement32(&threadData->data->threadCount);

#if 0
  NSLog(@"Exiting thread %x rect: (%d, %d) x (%d, %d)", pthread_self(),
        threadData->cr.rect.origin.x,
        threadData->cr.rect.origin.y,
        threadData->cr.rect.size.width,
        threadData->cr.rect.size.height);
#endif
  
  // Cleanup
  free(context);
  
  return nil;
}

@implementation Plasma
+ (NSString *)className {
  return @"Plasma";
}

+ (NSSet *)properties {
  return [NSSet setWithObjects:@"topLeft", @"topRight", @"bottomLeft", @"bottomRight", 
          @"variation", @"grayscale", @"opaque", nil];
}

+ (NSSet *)colorProperties {
  return [NSSet setWithObjects:@"topLeft", @"topRight", @"bottomLeft", @"bottomRight",
          nil];
}

+ (NSSet *)methods {
  return [NSSet setWithObjects:@"drawInLayer", @"toString", nil];
}

- (id)initWithArguments:(NSArray *)arguments {
  if ((self = [super initWithArguments:arguments])) {
    colors_ = [[NSMutableDictionary alloc] init];
    variation_ = 0.5;
    grayscale_ = NO;
    opaque_ = NO;
    
    // Add some random colors
    [colors_ setObject:[[[Color alloc] initWithArguments:nil] autorelease] forKey:@"topLeft"];
    [colors_ setObject:[[[Color alloc] initWithArguments:nil] autorelease] forKey:@"topRight"];
    [colors_ setObject:[[[Color alloc] initWithArguments:nil] autorelease] forKey:@"bottomLeft"];
    [colors_ setObject:[[[Color alloc] initWithArguments:nil] autorelease] forKey:@"bottomRight"];
  }
  
  return self;
}

- (void)dealloc {
  [colors_ release];
  [super dealloc];
}

- (id)valueForProperty:(NSString *)property {
  if ([[[self class] colorProperties] containsObject:property])
    return [colors_ objectForKey:property];
  
  return [super valueForProperty:property];
}

- (void)setValue:(id)value forProperty:(NSString *)property {
  if ([[[self class] colorProperties] containsObject:property])
    [colors_ setObject:value forKey:property];
  else
    [super setValue:value forProperty:property];
}

- (void)setVariation:(CGFloat)variation {
  variation_ = variation;
}

- (CGFloat)variation {
  return variation_;
}

- (void)setGrayscale:(BOOL)grayscale {
  grayscale_ = grayscale;
}

- (BOOL)grayscale {
  return grayscale_;
}

- (void)setOpaque:(BOOL)opaque {
  opaque_ = opaque;
}

- (BOOL)opaque {
  return opaque_;
}

- (void)drawInLayer:(NSArray *)arguments {
  if ([arguments count] != 1)
    return;
  
  Layer *layer = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[Layer class]];
  
  // Create a bitmap from some memory.
  CGRect rect = CGRectMake(0, 0, CGRectGetWidth([layer cgRectFrame]), CGRectGetHeight([layer cgRectFrame]));
  PlasmaData data;
  
  bzero(&data, sizeof(data));
  data.width = ceil(CGRectGetWidth(rect));
  data.height = ceil(CGRectGetHeight(rect));
  data.rowBytes = ((sizeof(long) * data.width) + 0xF) & ~0xF; // 16 byte alignment
  data.rowLongs = data.rowBytes / sizeof(long);
  data.bitmap = (unsigned char *)malloc(data.height * data.rowBytes);
  CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
  data.context = CGBitmapContextCreate(data.bitmap, data.width, data.height, 8, 
                                       data.rowBytes, cs, kCGImageAlphaPremultipliedLast); // RGBA or ABGR
  data.variation = variation_;
  data.grayscale = grayscale_;
  data.opaqueMask = opaque_ ? 0x000000ff : 0;
  
  // Clear the buffer to zero
  CGContextClearRect(data.context, rect);
  
  // Setup & render
  ColoredRect cr;
  cr.rect.origin.x = cr.rect.origin.y = 0;
  cr.rect.size.width = data.width - 1;
  cr.rect.size.height = data.height - 1;
  
  // The layer renders upside down, so "flip" the top and bottom
  [[colors_ objectForKey:@"topLeft"] getRGBAPixel:&cr.colors[BOTTOM_LEFT]];
  [[colors_ objectForKey:@"topRight"] getRGBAPixel:&cr.colors[BOTTOM_RIGHT]];
  [[colors_ objectForKey:@"bottomLeft"] getRGBAPixel:&cr.colors[TOP_LEFT]];
  [[colors_ objectForKey:@"bottomRight"] getRGBAPixel:&cr.colors[TOP_RIGHT]];
  
  // Determine if we need to flip pixels around by drawing a black background
  // and reading back the bits.
  CGContextSetRGBFillColor(data.context, 0, 0, 0, 1);
  CGContextFillRect(data.context, rect);
  RGBAPixel *pixPtr = GetPixelAddress(&data, UIntPointMake(0, 0));
  
  if (*pixPtr == 0xFF000000) {
    cr.colors[TOP_LEFT] = PixelReverse(cr.colors[TOP_LEFT]);
    cr.colors[TOP_RIGHT] = PixelReverse(cr.colors[TOP_RIGHT]);
    cr.colors[BOTTOM_LEFT] = PixelReverse(cr.colors[BOTTOM_LEFT]);
    cr.colors[BOTTOM_RIGHT] = PixelReverse(cr.colors[BOTTOM_RIGHT]);
    data.opaqueMask = PixelReverse(data.opaqueMask);
  }  // ABGR
  
  // Clear the context and draw.  We rely on the bits to be all zero as the
  // SetPixelIfUnset() method will read a location before writing to it so that
  // things are smoooooth.
  bzero(data.bitmap, data.height * data.rowBytes);
  DrawRectCorners(&data, &cr, 0);

  PlasmaRect(&data, &cr, 1);

  // Wait for any pending threads
  while (data.threadCount) {
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
  }
  
  // Create image to draw in layer
  CGImageRef plasmaImage = CGBitmapContextCreateImage(data.context);
  CGContextRef layerContext = [layer backingStore];
  CGContextDrawImage(layerContext, rect, plasmaImage);
  CGImageRelease(plasmaImage);
  
  // Cleanup
  CGColorSpaceRelease(cs);
  CGContextRelease(data.context);
  free(data.bitmap);
}
    
@end
