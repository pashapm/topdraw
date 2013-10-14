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

#import <ScreenSaver/ScreenSaver.h>

#import "Exporter.h"
#import "Renderer.h"
#import "TopDrawSaverView.h"

static const int kRefreshUnitSeconds = 1;
static const int kRefreshUnitMinutes = 2;

static NSString *kModuleName = @"Top Draw";

// Fading parameters
static NSTimeInterval kFadeTime = 1.0;
static CGFloat kFadeSteps = 30.0;

@implementation TopDrawSaverView
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Private ||
//------------------------------------------------------------------------------
+ (void)initialize {
  NSUserDefaults *defaults = [[self class] userDefaults];
  NSString *scriptPath = [Exporter scriptDirectory];
  NSDictionary *factoryValues = 
  [NSDictionary dictionaryWithObjectsAndKeys:
   scriptPath, @"scriptDirectory",
   kDefaultScriptName, @"selectedScript",
   [NSNumber numberWithBool:YES], @"randomlyChosen",
   [NSNumber numberWithInt:15], @"refreshTime",
   [NSNumber numberWithInt:kRefreshUnitMinutes], @"refreshUnit",
   [NSNumber numberWithBool:YES], @"fadeBetweenImages",
   nil];
  [defaults registerDefaults:factoryValues];
}

//------------------------------------------------------------------------------
- (void)updateScripts {
  NSString *path = [[self scriptDirectory] path];
  [scripts_ autorelease];
  scripts_ = [[Renderer scriptsInDirectory:path] retain];
}

//------------------------------------------------------------------------------
- (void)updateAnimationTimeInterval {
  NSUserDefaults *defaults = [[self class] userDefaults];
  int time = [defaults integerForKey:@"refreshTime"];
  int units = [defaults integerForKey:@"refreshUnit"];
  int multiplier = 1;
  
  if (units == kRefreshUnitMinutes)
    multiplier = 60;
  
  [self setAnimationTimeInterval:time * multiplier];
}

//------------------------------------------------------------------------------
- (void)stopFadeTimer {
  [fadeTimer_ invalidate];
  [fadeTimer_ release];
  fadeTimer_ = nil;
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Actions ||
//------------------------------------------------------------------------------
- (IBAction)endConfiguration:(id)sender {
  [NSApp endSheet:configureSheet_];
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Public ||
//------------------------------------------------------------------------------
+ (NSUserDefaults *)userDefaults {
  return [ScreenSaverDefaults defaultsForModuleWithName:kModuleName];
}

//------------------------------------------------------------------------------
- (id)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
  if ((self = [super initWithFrame:frame isPreview:isPreview])) {
    renderer_ = [[Renderer alloc] initWithReference:self];
    [self updateScripts];
    
    NSString *fileName = [NSString stringWithFormat:@"TopDrawSaver-%p.jpeg", self];
    imagePath_ = [[NSTemporaryDirectory() stringByAppendingPathComponent:fileName] retain];

    [self updateAnimationTimeInterval];
  }
  
  return self;
}

//------------------------------------------------------------------------------
- (void)dealloc {
  [renderer_ release];
  [scripts_ release];
  [imagePath_ release];
  CGImageRelease(frontImage_);
  CGImageRelease(backImage_);
  [self stopFadeTimer];
  [super dealloc];
}

//------------------------------------------------------------------------------
- (void)stopAnimation {
  [renderer_ cancelRender];
  [super stopAnimation];
}

//------------------------------------------------------------------------------
- (void)drawRect:(NSRect)rect {
  // Fill with black
  if (!frontImage_ || !backImage_) {
    [[NSColor blackColor] set];
    NSRectFill(rect);
  }
  
  // Draw the image(s)
  CGFloat opacity = 1.0;
  CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
  if (fadeAmount_ > 0) {
    CGContextDrawImage(context, NSRectToCGRect([self bounds]), backImage_);
    opacity = fadeAmount_;
  }

  CGContextSetAlpha(context, opacity);
  CGContextDrawImage(context, NSRectToCGRect([self bounds]), frontImage_);
}

//------------------------------------------------------------------------------
- (void)fadeImages {
  fadeAmount_ += (1.0 / kFadeSteps);
  if (fadeAmount_ >= 1.0) {
    fadeAmount_ = 0;
    [self stopFadeTimer];
    CGImageRelease(backImage_);
    backImage_ = NULL;
  }
  
  [self setNeedsDisplay:YES];
}

//------------------------------------------------------------------------------
- (void)animateOneFrame {
  // If we're currently rendering something, kill it
  if ([renderer_ isRendering])
    [renderer_ cancelRender];
  
  NSString *name = [self selectedScript];
  
  if ([self randomlyChosen])
    name = [[scripts_ allKeys] objectAtIndex:random() % [scripts_ count]];

  NSString *path = [scripts_ objectForKey:name];
  NSError *error;
  NSString *source = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];

  // Setup the renderer and make it go
  [renderer_ setSource:source name:name seed:[Renderer randomSeedFromDevice]];
  [renderer_ setDestination:imagePath_];
  [renderer_ setType:@"jpeg"];
  [renderer_ setMaximumSize:[self frame].size];
  [renderer_ setDisableMenubarRendering:YES];
  [renderer_ render];
  
  // Swap images around
  CGImageRelease(backImage_);
  backImage_ = frontImage_;
  
  NSURL *url = [NSURL fileURLWithPath:imagePath_];
  CGDataProviderRef src = CGDataProviderCreateWithURL((CFURLRef)url);
  frontImage_ = CGImageCreateWithJPEGDataProvider(src, nil, FALSE, kCGRenderingIntentDefault);
  CGDataProviderRelease(src);
  
  if (!frontImage_) {
    NSLog(@"Error loading from %@", imagePath_);
  }
  
  // Setup the fading, if needed
  fadeAmount_ = 0;
  [self stopFadeTimer];
  
  if ([self fadeBetweenImages]) {
    CGFloat interval = kFadeTime / kFadeSteps;
    fadeTimer_ = [[NSTimer scheduledTimerWithTimeInterval:interval target:self 
                                                 selector:@selector(fadeImages) 
                                                 userInfo:nil repeats:YES] retain];
  } else {
    [self setNeedsDisplay:YES];
  }
}

//------------------------------------------------------------------------------
- (BOOL)hasConfigureSheet {
  return YES;
}

//------------------------------------------------------------------------------
- (NSWindow *)configureSheet {
  if (!configureSheet_)
    [NSBundle loadNibNamed:@"TopDrawSaver" owner:self];
  
  return configureSheet_;
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Bindings
//------------------------------------------------------------------------------
- (NSURL *)scriptDirectory {
  NSString *dirStr = [[[self class] userDefaults] objectForKey:@"scriptDirectory"];
  return [NSURL fileURLWithPath:dirStr];
}

//------------------------------------------------------------------------------
- (void)setScriptDirectory:(NSURL *)dir {
  NSString *dirStr = [dir path];
  [[[self class] userDefaults] setObject:dirStr forKey:@"scriptDirectory"];
  
  [self willChangeValueForKey:@"scriptNames"];
  [self updateScripts];
  [self didChangeValueForKey:@"scriptNames"];
}

//------------------------------------------------------------------------------
- (NSString *)selectedScript {
  NSString *selected = [[[self class] userDefaults] objectForKey:@"selectedScript"];
  
  if (![selected length]) {
    NSArray *names = [self scriptNames];
    
    if ([names count]) {
      selected = [names objectAtIndex:0];
      [self setSelectedScript:selected];
    }
  }
  
  return selected;
}

//------------------------------------------------------------------------------
- (void)setSelectedScript:(NSString *)selected {
  [[[self class] userDefaults] setObject:selected forKey:@"selectedScript"];
}

//------------------------------------------------------------------------------
static NSComparisonResult CompareBaseNames(id a, id b, void *context) {
  NSString *aBase = [a lastPathComponent];
  NSString *bBase = [b lastPathComponent];
  
  return [aBase caseInsensitiveCompare:bBase];
}
//------------------------------------------------------------------------------
- (NSArray *)scriptNames {
  if (!scripts_) 
    [self updateScripts];
  
  return [[scripts_ allKeys] sortedArrayUsingFunction:CompareBaseNames context:nil];
}

//------------------------------------------------------------------------------
- (BOOL)randomlyChosen {
  return [[[self class] userDefaults] boolForKey:@"randomlyChosen"];
}

//------------------------------------------------------------------------------
- (void)setRandomlyChosen:(BOOL)chosen {
  [[[self class] userDefaults] setBool:chosen forKey:@"randomlyChosen"];
}

//------------------------------------------------------------------------------
- (int)refreshTime {
  return [[[self class] userDefaults] integerForKey:@"refreshTime"];
}

//------------------------------------------------------------------------------
- (void)setRefreshTime:(int)time {
  [[[self class] userDefaults] setInteger:time forKey:@"refreshTime"];
}

//------------------------------------------------------------------------------
- (int)refreshUnit {
  return [[[self class] userDefaults] integerForKey:@"refreshUnit"];
}

//------------------------------------------------------------------------------
- (void)setRefreshUnit:(int)tag {
  [[[self class] userDefaults] setInteger:tag forKey:@"refreshUnit"];
}

//------------------------------------------------------------------------------
- (BOOL)fadeBetweenImages {
  return [[[self class] userDefaults] boolForKey:@"fadeBetweenImages"];
}

//------------------------------------------------------------------------------
- (void)setFadeBetweenImages:(BOOL)chosen {
  [[[self class] userDefaults] setBool:chosen forKey:@"fadeBetweenImages"];
}

//------------------------------------------------------------------------------
- (NSString *)version {
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSDictionary *info = [bundle infoDictionary];
  NSString *version = [info objectForKey:@"CFBundleShortVersionString"];
  
  return [NSString stringWithFormat:@"Version: %@", version];
}

@end
