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

// Screen Saver view

#import <ScreenSaver/ScreenSaverView.h>

@class Renderer;

@interface TopDrawSaverView : ScreenSaverView {
  IBOutlet NSWindow *configureSheet_;
  
  Renderer *renderer_;
  NSDictionary *scripts_;
  NSString *imagePath_;
  CGImageRef frontImage_;
  CGImageRef backImage_;
  NSTimer *fadeTimer_;
  CGFloat fadeAmount_;
}

+ (NSUserDefaults *)userDefaults;

- (IBAction)endConfiguration:(id)sender;

- (NSURL *)scriptDirectory;
- (void)setScriptDirectory:(NSURL *)dir;

- (NSString *)selectedScript;
- (void)setSelectedScript:(NSString *)selected;

- (NSArray *)scriptNames;

- (BOOL)randomlyChosen;
- (void)setRandomlyChosen:(BOOL)chosen;

- (int)refreshTime;
- (void)setRefreshTime:(int)time;

- (int)refreshUnit;
- (void)setRefreshUnit:(int)tag;

- (BOOL)fadeBetweenImages;
- (void)setFadeBetweenImages:(BOOL)fade;

- (NSString *)version;


@end
