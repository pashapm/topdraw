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

#import <JavaScriptCore/JavaScriptCore.h>

#import "Color.h"
#import "Compositor.h"
#import "Filter.h"
#import "Gradient.h"
#import "GravityPoint.h"
#import "Image.h"
#import "Layer.h"
#import "Noise.h"
#import "Particles.h"
#import "PatternObject.h"
#import "Plasma.h"
#import "PointObject.h"
#import "Randomizer.h"
#import "RectObject.h"
#import "NSScreen+Convenience.h"
#import "Randomizer.h"
#import "Runtime.h"
#import "Simulator.h"
#import "Text.h"

static inline BOOL IsEmptySize(NSSize size) {
  return (size.width > 0 && size.height > 0) ? NO : YES;
}

static int kCurrentVersion = 1;

@implementation Compositor
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Runtime ||
//------------------------------------------------------------------------------
+ (NSString *)className {
  return @"Compositor";
}

//------------------------------------------------------------------------------
+ (NSSet *)properties {
  return [NSSet setWithObjects:@"randomSeed", @"screenCount", @"name",
          @"requiredVersion", @"currentVersion", nil];
}

//------------------------------------------------------------------------------
+ (NSSet *)readOnlyProperties {
  return [NSSet setWithObjects:@"screenCount", @"currentVersion", @"name", nil];
}

//------------------------------------------------------------------------------
+ (NSSet *)methods {
  return [NSSet setWithObjects:@"addLayer", @"boundsOfScreen", @"toString", nil];
}

//------------------------------------------------------------------------------
- (id)initWithSource:(NSString *)source name:(NSString *)name {
  if ((self = [super init])) {
    source_ = [source copy];
    name_ = [name copy];
    requiredVersion_ = kCurrentVersion;
  }
  
  return self;
}

//------------------------------------------------------------------------------
- (void)dealloc {
  [source_ release];
  [name_ release];
  [desktop_ release];
  [menubar_ release];
  [layers_ release];
  [blendModes_ release];
  [super dealloc];
}

//------------------------------------------------------------------------------
- (void)setMaximumSize:(NSSize)size {
  size_ = size;
  
  // Ensure that they're reset
  [desktop_ release];
  desktop_ = nil;
  [menubar_ release];
  menubar_ = nil;
}

//------------------------------------------------------------------------------
- (void)runtime:(Runtime *)runtime didReceiveLogMessage:(NSString *)msg {
  if (loggingCallback_)
    loggingCallback_([msg UTF8String], loggingCallbackContext_);
}

//------------------------------------------------------------------------------
- (NSString *)checkVersion:(NSString *)source {
  NSScanner *scanner = [NSScanner scannerWithString:source];
  
  // Check the required version.  If we can't run, substitute a helpful
  // script that prints the name, required, current version.
  if ([scanner scanUpToString:@".requiredVersion" intoString:nil]) {
    [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
    int version;
    [scanner scanInt:&version];
    
    if (version > kCurrentVersion) {
      source = [NSString stringWithFormat:
                @"var t = new Text(compositor.name + \" Requires Top Draw Version: %d "
      "(Current version: \" + compositor.currentVersion + \")\");"
      "t.fontSize = 72;"
      "var db = desktop.bounds;"
      "var textBounds = t.bounds;"
      "var pt = new Point(db.midX - textBounds.width / 2, db.midY - textBounds.height / 2);"
                "desktop.drawText(t, pt);", version];
      
    }
  }
  
  return source;
}

//------------------------------------------------------------------------------
- (NSString *)evaluateWithSeed:(NSUInteger)seed {
  Runtime *rt = [[Runtime alloc] initWithName:@"Drawing"];
  
  activeRuntime_ = rt;
  [rt setDelegate:self];
  [self setRandomSeed:seed];
  
  // Register classes
  [rt registerClass:[Color class]];
  [rt registerClass:[Filter class]];
  [rt registerClass:[Gradient class]];
  [rt registerClass:[GravityPoint class]];
  [rt registerClass:[Image class]];
  [rt registerClass:[Noise class]];
  [rt registerClass:[Particles class]];
  [rt registerClass:[PatternObject class]];
  [rt registerClass:[Plasma class]];
  [rt registerClass:[PointObject class]];
  [rt registerClass:[RectObject class]];
  [rt registerClass:[Randomizer class]];
  [rt registerClass:[Simulator class]];
  [rt registerClass:[Text class]];
  
  // Register objects
  [rt setObject:[self desktop] withName:@"desktop"];
  [rt setObject:[self menubar] withName:@"menubar"];
  [rt setObject:self withName:@"compositor"];
  
  NSException *e = NULL;
  NSString *errorStr = nil;
  
  // Check for the version.  If we can't render, put up a message
  NSString *source = [self checkVersion:source_];
  
  if ([source length]) {
    [rt evaluateScript:source exception:&e];
    
    if (e)
      errorStr = [NSString stringWithFormat:@"%@ - %@", 
                  [[e userInfo] objectForKey:@"line"], e];
  } else {
    errorStr = @"No source";
  }
  
  [rt release];
  
  return errorStr;
}

//------------------------------------------------------------------------------
- (CGRect)convertFrameToDesktop:(CGRect)frame {
  CGRect desktop = [desktop_ cgRectFrame];
  frame.origin.x -= desktop.origin.x;
  frame.origin.y -= desktop.origin.y;
  
  return frame;
}

//------------------------------------------------------------------------------
- (CGImageRef)image {
  int count = [layers_ count];
  CGContextRef dest = [desktop_ backingStore];
  
  // Restore the clip
  CGRect rect = [desktop_ cgRectFrame];
  rect.origin = CGPointZero;
  CGContextClipToRect(dest, rect);
  
  // Draw each layer into the desktop
  for (int i = 0; i < count; ++i) {
    Layer *layer = [layers_ objectAtIndex:i];
    CGContextSaveGState(dest);
    CGBlendMode blendMode = [Layer blendModeFromString:[blendModes_ objectAtIndex:i]];
    CGContextSetBlendMode(dest, blendMode);
    CGContextDrawImage(dest, [self convertFrameToDesktop:[layer cgRectFrame]], [layer cgImage]);
    CGContextRestoreGState(dest);
  }
  
  // Draw the menubar
  CGContextDrawImage(dest, [self convertFrameToDesktop:[menubar_ cgRectFrame]], [menubar_ cgImage]);
    
  return [desktop_ cgImage];
}

//------------------------------------------------------------------------------
- (Layer *)desktop {
  if (!desktop_) {
    NSRect frame = [NSScreen desktopFrame];
    
    // Override the size of the desktop
    if (!IsEmptySize(size_)) {
      frame.origin = NSZeroPoint;
      frame.size = size_;
    }
    
    desktop_ = [[Layer alloc] initWithFrame:frame];
  }
  
  return desktop_;
}

//------------------------------------------------------------------------------
- (Layer *)menubar {
  if (!menubar_) {
    NSRect frame = [NSScreen menubarFrame];

    // Resize/position to be at the top
    if (!IsEmptySize(size_)) {
      frame.origin.x = 0;
      frame.origin.y = size_.height - NSHeight(frame);
      frame.size.width = size_.width;
    }

    menubar_ = [[Layer alloc] initWithFrame:frame];
  }
  
  return menubar_;
}

//------------------------------------------------------------------------------
- (void)addLayer:(NSArray *)arguments {
  if (!layers_) {
    layers_ = [[NSMutableArray alloc] init];
    blendModes_ = [[NSMutableArray alloc] init];
  }
  
  int count = [arguments count];
  if (count < 1 || count > 2)
    return;
  
  Layer *layer = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[Layer class]];
  [layers_ addObject:layer];
  NSString *compositingMode = [Layer blendModeToString:kCGBlendModeNormal];
  
  if (count == 2) {
    // Normalize the string
    NSString *modeStr = [RuntimeObject coerceObject:[arguments objectAtIndex:1] toClass:[NSString class]];
    CGBlendMode mode = [Layer blendModeFromString:modeStr];
    compositingMode = [Layer blendModeToString:mode];
  }
  
  [blendModes_ addObject:compositingMode];
}

//------------------------------------------------------------------------------
- (NSArray *)layers {
  return layers_;
}

//------------------------------------------------------------------------------
- (void)setRandomSeed:(NSUInteger)seed {
  seed_ = seed;
  [Randomizer setSharedSeed:seed_];
}

//------------------------------------------------------------------------------
- (NSUInteger)randomSeed {
  return seed_;
}

//------------------------------------------------------------------------------
- (void)setRequiredVersion:(int)version {
  requiredVersion_ = version;
}

//------------------------------------------------------------------------------
- (int)requiredVersion {
  return requiredVersion_;
}

//------------------------------------------------------------------------------
- (int)currentVersion {
  return kCurrentVersion;
}

//------------------------------------------------------------------------------
- (NSUInteger)screenCount {
  if (!IsEmptySize(size_))
    return 1;
  
  return [[NSScreen screens] count];
}

//------------------------------------------------------------------------------
- (NSString *)name {
  return name_;
}

//------------------------------------------------------------------------------
- (RectObject *)boundsOfScreen:(NSArray *)arguments {
  NSRect frame;
  
  if (!IsEmptySize(size_)) {
    frame.origin = NSZeroPoint;
    frame.size = size_;
  } else {
    int index = [[RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[NSNumber class]] intValue];
    NSArray *screens = [NSScreen screens];
    index = MAX(0, MIN(index, [screens count] - 1));
    NSScreen *screen = [screens objectAtIndex:index];
    frame = [screen frame];
  }
  
  return [[[RectObject alloc] initWithRect:frame] autorelease];
}

//------------------------------------------------------------------------------
- (void)setLoggingCallback:(LoggingCB)cb context:(void *)context {
  loggingCallback_ = cb;
  loggingCallbackContext_ = context;
}

@end
