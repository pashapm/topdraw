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
#import "Installer.h"
#import "PreferencesController.h"
#import "ViewerController.h"
#import "StatusItemView.h"
#import "Renderer.h"

@interface ViewerController (PrivateMethods)
- (void)statusClicked:(id)sender;
- (void)adjustStatusMenu;
- (void)update:(NSTimer *)timer;
- (void)scheduleUpdateTimer;
- (void)loadScripts;
- (void)buildRenderMenu;
- (void)selectScript:(id)sender;
- (void)render;
@end

static const int kRefreshModeEvery = 1;
static const int kRefreshModeOn = 2;

static const int kRefreshUnitSeconds = 1;
static const int kRefreshUnitMinutes = 2;
static const int kRefreshUnitHours = 3;

static const int kRefreshActionWake = 1;
static const int kRefreshActionStartup = 2;

@implementation ViewerController
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Private ||
//------------------------------------------------------------------------------
+ (void)initialize {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *scriptPath = [Exporter scriptDirectory];
  NSColor *activeColor = [NSColor colorWithCalibratedRed:0 green:0.8 blue:0 alpha:0.3];
  NSColor *idleColor = [NSColor colorWithCalibratedRed:0 green:0.5 blue:0.5 alpha:0.2];
  NSData *activeData = [NSArchiver archivedDataWithRootObject:activeColor];
  NSData *idleData = [NSArchiver archivedDataWithRootObject:idleColor];
  NSDictionary *factoryValues = 
  [NSDictionary dictionaryWithObjectsAndKeys:
   scriptPath, @"scriptDirectory",
   kDefaultScriptName, @"selectedScript",
   [NSNumber numberWithBool:YES], @"randomlyChosen",
   [NSNumber numberWithInt:kRefreshModeEvery], @"refreshMode",
   [NSNumber numberWithInt:15], @"refreshTime",
   [NSNumber numberWithInt:kRefreshUnitMinutes], @"refreshUnit",
   [NSNumber numberWithInt:kRefreshActionWake], @"refreshAction",
   activeData, @"activeColor",
   idleData, @"idleColor",
   [NSNumber numberWithInt:kIndicatorRectangle], @"indicatorStyle",
   nil];
  [defaults registerDefaults:factoryValues];
}

//------------------------------------------------------------------------------
- (NSString *)nextScriptName {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *name;
  
  if ([defaults boolForKey:@"randomlyChosen"])
    name = [[scripts_ allKeys] objectAtIndex:random() % [scripts_ count]];
  else
    name = [defaults stringForKey:@"selectedScript"];
  
  return name;
}

//------------------------------------------------------------------------------
- (void)updateSettingsForUserDefaults {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *path = [defaults stringForKey:@"scriptDirectory"];
  
  if (![path isEqualToString:currentScriptDirectory_]) {
    [currentScriptDirectory_ release];
    currentScriptDirectory_ = [path retain];
    
    [scripts_ autorelease];
    scripts_ = [[Renderer scriptsInDirectory:path] retain];
  }

  [selectedScript_ autorelease];
  selectedScript_ = [[self nextScriptName] retain];
  [self buildRenderMenu];
  
  int time = [defaults integerForKey:@"refreshTime"];
  int units = [defaults integerForKey:@"refreshUnit"];
  int multiplier = 1;
  
  if (units == 2)
    multiplier = 60;
  else if (units == 3)
    multiplier = 60 * 60;
  
  updateInterval_ = time * multiplier;
  [self scheduleUpdateTimer];
  
  // Redraw the status item as we may have changed its appearance
  [statusItemView_ setNeedsDisplay:YES];
}


//------------------------------------------------------------------------------
- (void)statusClicked:(id)sender {
  // Schedule a timer to update the status so that we have a countdown
  NSTimer *menuTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self
                                                      selector:@selector(adjustStatusMenu) userInfo:nil repeats:YES];
  [[NSRunLoop currentRunLoop] addTimer:menuTimer forMode:NSEventTrackingRunLoopMode];
  [[NSRunLoop currentRunLoop] addTimer:menuTimer forMode:NSModalPanelRunLoopMode];

  [self adjustStatusMenu];
  [statusItem_ popUpStatusItemMenu:menu_];
  
  [menuTimer invalidate];
}

//------------------------------------------------------------------------------
- (void)buildRenderMenu {
  NSArray *names = [preferences_ scriptNames];
  
  while ([renderMenu_ numberOfItems])
    [renderMenu_ removeItemAtIndex:0];
  
  for (int i = 0; i < [names count]; ++i) {
    NSString *name = [names objectAtIndex:i];
    NSMenuItem *item = [renderMenu_ addItemWithTitle:name action:@selector(renderImmediately:) keyEquivalent:@""];
    [item setTarget:self];
  }
}

//------------------------------------------------------------------------------
- (void)adjustStatusMenu {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *title;

  if ([defaults integerForKey:@"refreshMode"] == kRefreshModeEvery) {
    NSTimeInterval seconds = [[updateTimer_ fireDate] timeIntervalSinceNow];
    NSTimeInterval minutes = floor(seconds / 60);
    NSTimeInterval hours = floor(minutes / 60);
    NSMutableString *timeStr = [NSMutableString string];
    NSString *separatorStr = @"";
    
    if (hours > 0) {
      [timeStr appendFormat:@"%dh", (int)hours];
      separatorStr = @" ";
    }
    
    if (minutes > 0) {
      [timeStr appendFormat:@"%@%dm", separatorStr, (int)minutes];
      separatorStr = @" ";
    }
    
    seconds = fmod(seconds, 60);
    [timeStr appendFormat:@"%@%ds", separatorStr, (int)seconds];
    title = [NSString stringWithFormat:@"Render %@ in %@",
             selectedScript_, timeStr];
  } else {
    if ([defaults integerForKey:@"refreshAction"] == kRefreshActionWake)
      title = @"Render on wake";
    else
      title = @"Render on launch";
  }
  
  [statusMenuItem_ setTitle:title];
}

//------------------------------------------------------------------------------
- (void)rendererFinished:(NSNotification *)note {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSDictionary *userInfo = [note userInfo];
  NSArray *paths = [[userInfo objectForKey:RendererOutputKey] componentsSeparatedByString:@","];
  NSString *error = [userInfo objectForKey:RendererErrorKey];
  
  if ([error length])
    MethodLog(@"Error: %@", error);
  
  if ([paths count] && ![error length]) {
    // We've asked the renderer to output the file(s) on our behalf 
    [Installer installDesktopImagesFromPaths:paths];
  }
  
  [statusItemView_ setIsRendering:NO];
  
  [pool release];

  // Pick the next script
  [selectedScript_ autorelease];
  selectedScript_ = [[self nextScriptName] retain];
  
  // Increment the # of times we've drawn
  ++renderCount_;
}

//------------------------------------------------------------------------------
- (void)render {
  if (![renderer_ isRendering]) {
    unsigned long seed = [Renderer randomSeedFromDevice];
    
    [statusItemView_ setIsRendering:YES];
    
    if (!renderer_) {
      renderer_ = [[Renderer alloc] initWithReference:self];
      [[NSNotificationCenter defaultCenter] addObserver:self
                                               selector:@selector(rendererFinished:)
                                                   name:RendererDidFinish object:renderer_];
    }
    
    // Pick the script && path
    NSString *scriptName = selectedScript_;
    NSString *scriptPath = [scripts_ objectForKey:scriptName];
    
    // Render
    NSData *data = [NSData dataWithContentsOfFile:scriptPath];
    NSString *source = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString *dest = [[Exporter imageDirectory] stringByAppendingPathComponent:[Exporter nextBaseName]];
    [renderer_ setSource:source name:scriptName seed:seed];
    [source release];
    [renderer_ setShouldSplitImages:YES];
    [renderer_ setType:@"jpeg"];
    [renderer_ setDestination:dest];
    
    [renderer_ renderInBackgroundAndNotify];
  }
}

//------------------------------------------------------------------------------
- (void)update:(NSTimer *)timer {
  [self render];

  // Schedule the next thing
  [self scheduleUpdateTimer];
}

//------------------------------------------------------------------------------
- (void)didWake:(NSNotification *)note {
  [self update:nil];
}

//------------------------------------------------------------------------------
- (void)scheduleUpdateTimer {
  [updateTimer_ invalidate];
  [updateTimer_ release];
  updateTimer_ = nil;
  
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  if ([defaults integerForKey:@"refreshMode"] == 1) {
    // "On" timer
    updateTimer_ = [[NSTimer scheduledTimerWithTimeInterval:updateInterval_ target:self 
                                                   selector:@selector(update:) userInfo:nil repeats:NO] retain];
    [[NSRunLoop currentRunLoop] addTimer:updateTimer_ forMode:NSEventTrackingRunLoopMode];
    [[NSRunLoop currentRunLoop] addTimer:updateTimer_ forMode:NSModalPanelRunLoopMode];
  } else {
    // "Every" timer
    if (renderCount_ == 0) {
      // Render right now
      [self render];

      // Register a notification on wake
      if ([defaults integerForKey:@"refreshAction"] == 1) { // On wake
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(didWake:) 
                                                                   name:NSWorkspaceDidWakeNotification object:nil];
      }
    }
  }
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Actions ||
//------------------------------------------------------------------------------
- (IBAction)about:(id)sender {
  [NSApp activateIgnoringOtherApps:YES];

  NSString *htmlStr = @"<html><a href='http://code.google.com/p/topdraw'>http://code.google.com/p/topdraw</a></html>";
  NSData *htmlData = [htmlStr dataUsingEncoding:NSUTF8StringEncoding];
  NSAttributedString *str = [[NSAttributedString alloc] initWithHTML:htmlData documentAttributes:nil];
  NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                           str, @"Credits",
                           nil];
  [str release];
  [NSApp orderFrontStandardAboutPanelWithOptions:options];
}

//------------------------------------------------------------------------------
- (IBAction)renderImmediately:(id)sender {
  int tag = [sender tag];
  
  // The tag of the render menu is 1.  If that was not the sender, look at
  // the title of the script.
  if (!tag) {
    [selectedScript_ autorelease];
    selectedScript_ = [[sender title] retain];
  }
    
  [self update:nil];
}

//------------------------------------------------------------------------------
- (IBAction)preferences:(id)sender {
  [preferences_ show];
}

//------------------------------------------------------------------------------
- (IBAction)quit:(id)sender {
  [NSApp terminate:sender];
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || NSObject ||
//------------------------------------------------------------------------------
- (void)awakeFromNib {
  srandom(CFAbsoluteTimeGetCurrent() * 10);

  statusItem_ = [[[NSStatusBar systemStatusBar]
                  statusItemWithLength:NSSquareStatusItemLength] retain];
  
  statusItemView_ = [[[StatusItemView alloc] init] autorelease];
  [statusItemView_ setStatusItem:statusItem_];
  [statusItemView_ setTarget:self];
  [statusItemView_ setAction:@selector(statusClicked:)];
  [menu_ setDelegate:statusItemView_];

  [statusItem_ setView:statusItemView_];
  [statusItem_ setEnabled:YES];
  
  [statusItemView_ setNeedsDisplay:YES];
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSettingsForUserDefaults)
                                               name:PreferencesControllerDidUpdate 
                                             object:nil];
  [self updateSettingsForUserDefaults];
}

//------------------------------------------------------------------------------
- (void)dealloc {
  [renderer_ release];
  [statusItem_ release];
  [scripts_ release];
  [super dealloc];
}

@end
