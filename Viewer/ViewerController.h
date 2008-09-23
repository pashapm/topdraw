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

// Handle interaction with Status Item

#import <Cocoa/Cocoa.h>

@class PreferencesController;
@class Renderer;
@class StatusItemView;

@interface ViewerController : NSObject {
  IBOutlet NSMenu *menu_;
  IBOutlet NSMenu *renderMenu_;
  IBOutlet NSMenuItem *statusMenuItem_;
  IBOutlet PreferencesController *preferences_;

  NSStatusItem *statusItem_;
  StatusItemView *statusItemView_;
  Renderer *renderer_;
  
  NSString *currentScriptDirectory_;
  NSDictionary *scripts_;
  NSString *selectedScript_;
  
  NSTimer *updateTimer_;
  NSTimeInterval updateInterval_;
  NSTimer *menuTimer_;
  int renderCount_;
}

- (IBAction)about:(id)sender;
- (IBAction)renderImmediately:(id)sender;
- (IBAction)preferences:(id)sender;
- (IBAction)launchTopDraw:(id)sender;
- (IBAction)showDocumentation:(id)sender;
- (IBAction)quit:(id)sender;

@end
