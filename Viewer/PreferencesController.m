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

#import "PreferencesController.h"
#import "Renderer.h"

NSString *PreferencesControllerDidUpdate = @"PreferencesControllerDidUpdate";

@interface PreferencesController(PrivateMethods)
- (void)updateScripts;
@end

@implementation PreferencesController
//------------------------------------------------------------------------------
- (NSURL *)scriptDirectory {
  NSString *dirStr = [[NSUserDefaults standardUserDefaults] objectForKey:@"scriptDirectory"];
  return [NSURL fileURLWithPath:dirStr];
}

//------------------------------------------------------------------------------
- (void)setScriptDirectory:(NSURL *)dir {
  NSString *dirStr = [dir path];
  [[NSUserDefaults standardUserDefaults] setObject:dirStr forKey:@"scriptDirectory"];

  [self willChangeValueForKey:@"scriptNames"];
  [self updateScripts];
  [self didChangeValueForKey:@"scriptNames"];
}

//------------------------------------------------------------------------------
- (NSString *)selectedScript {
  NSString *selected = [[NSUserDefaults standardUserDefaults] objectForKey:@"selectedScript"];
  
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
  [[NSUserDefaults standardUserDefaults] setObject:selected forKey:@"selectedScript"];
}

//------------------------------------------------------------------------------
- (void)updateScripts {
  NSString *path = [[self scriptDirectory] path];
  [scripts_ autorelease];
  scripts_ = [[Renderer scriptsInDirectory:path] retain];
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
  return [[NSUserDefaults standardUserDefaults] boolForKey:@"randomlyChosen"];
}

//------------------------------------------------------------------------------
- (void)setRandomlyChosen:(BOOL)chosen {
  [[NSUserDefaults standardUserDefaults] setBool:chosen forKey:@"randomlyChosen"];
}

//------------------------------------------------------------------------------
- (int)refreshMode {
  return [[NSUserDefaults standardUserDefaults] integerForKey:@"refreshMode"];
}

//------------------------------------------------------------------------------
- (void)setRefreshMode:(int)tag {
  [[NSUserDefaults standardUserDefaults] setInteger:tag forKey:@"refreshMode"];
}

//------------------------------------------------------------------------------
- (int)refreshTime {
  return [[NSUserDefaults standardUserDefaults] integerForKey:@"refreshTime"];
}

//------------------------------------------------------------------------------
- (void)setRefreshTime:(int)time {
  [[NSUserDefaults standardUserDefaults] setInteger:time forKey:@"refreshTime"];
}

//------------------------------------------------------------------------------
- (int)refreshUnit {
  return [[NSUserDefaults standardUserDefaults] integerForKey:@"refreshUnit"];
}

//------------------------------------------------------------------------------
- (void)setRefreshUnit:(int)tag {
  [[NSUserDefaults standardUserDefaults] setInteger:tag forKey:@"refreshUnit"];
}

//------------------------------------------------------------------------------
- (int)refreshAction {
  return [[NSUserDefaults standardUserDefaults] integerForKey:@"refreshAction"];
}

//------------------------------------------------------------------------------
- (void)setRefreshAction:(int)tag {
  [[NSUserDefaults standardUserDefaults] setInteger:tag forKey:@"refreshAction"];
}

//------------------------------------------------------------------------------
- (NSColor *)idleColor {
  NSData *colorData = [[NSUserDefaults standardUserDefaults] dataForKey:@"idleColor"];
  NSColor *color = [NSUnarchiver unarchiveObjectWithData:colorData];
  
  if (!color)
    color = [NSColor grayColor];
  
  return color;
}

//------------------------------------------------------------------------------
- (void)setIdleColor:(NSColor *)color {
  NSData *colorData = [NSArchiver archivedDataWithRootObject:color];
  [[NSUserDefaults standardUserDefaults] setObject:colorData forKey:@"idleColor"];
}

//------------------------------------------------------------------------------
- (NSColor *)activeColor {
  NSData *colorData = [[NSUserDefaults standardUserDefaults] dataForKey:@"activeColor"];
  NSColor *color = [NSUnarchiver unarchiveObjectWithData:colorData];
  
  if (!color)
    color = [NSColor greenColor];
  
  return color;
}

//------------------------------------------------------------------------------
- (void)setActiveColor:(NSColor *)color {
  NSData *colorData = [NSArchiver archivedDataWithRootObject:color];
  [[NSUserDefaults standardUserDefaults] setObject:colorData forKey:@"activeColor"];
}

//------------------------------------------------------------------------------
- (int)indicatorStyle {
  return [[NSUserDefaults standardUserDefaults] integerForKey:@"indicatorStyle"];
}

//------------------------------------------------------------------------------
- (void)setIndicatorStyle:(int)tag {
  [[NSUserDefaults standardUserDefaults] setInteger:tag forKey:@"indicatorStyle"];  
}

//------------------------------------------------------------------------------
- (void)show {
  [[NSColorPanel sharedColorPanel] setShowsAlpha:YES];
  
  [window_ center];
  [NSApp activateIgnoringOtherApps:YES];
  [window_ setDelegate:self];
  [window_ orderFront:nil];
  [window_ makeKeyWindow];
}

//------------------------------------------------------------------------------
- (void)windowWillClose:(NSNotification *)note {
  [[NSNotificationCenter defaultCenter] postNotificationName:PreferencesControllerDidUpdate object:nil];
  [window_ endEditingFor:nil];
}

//------------------------------------------------------------------------------
- (void)close:(id)sender {
  [window_ orderOut:sender];
}

@end
