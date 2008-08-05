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

// Controller for Preferences

#import <Cocoa/Cocoa.h>

extern NSString *PreferencesControllerDidUpdate;

typedef enum {
  kIndicatorRectangle = 0,
  kIndicatorSquare,
  kIndicatorCircle,
  kIndicatorTriangle
} IndicatorStyle;

@interface PreferencesController : NSObject {
  IBOutlet NSWindow *window_;
  NSDictionary *scripts_;   // key: name of script, object: full path
}

- (NSURL *)scriptDirectory;
- (void)setScriptDirectory:(NSURL *)dir;

- (NSString *)selectedScript;
- (void)setSelectedScript:(NSString *)selected;

- (NSArray *)scriptNames;

- (BOOL)randomlyChosen;
- (void)setRandomlyChosen:(BOOL)chosen;

- (int)refreshMode;
- (void)setRefreshMode:(int)tag;

- (int)refreshTime;
- (void)setRefreshTime:(int)time;

- (int)refreshUnit;
- (void)setRefreshUnit:(int)tag;

- (int)refreshAction;
- (void)setRefreshAction:(int)tag;

- (NSColor *)idleColor;
- (void)setIdleColor:(NSColor *)color;

- (NSColor *)activeColor;
- (void)setActiveColor:(NSColor *)color;

- (int)indicatorStyle;
- (void)setIndicatorStyle:(int)tag;

- (void)show;

@end
