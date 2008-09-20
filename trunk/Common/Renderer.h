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

// Interface to the rendering command-line program

#import <Cocoa/Cocoa.h>

// Notifications                        // userInfo
extern NSString *RendererDidFinish;     // NSDictionary of below keys

extern NSString *RendererOutputKey;     // NSString of the image file created
extern NSString *RendererErrorKey;      // NSString of any errors (empty if none)
extern NSString *RendererErrorLineKey;  // NSNumber of line with error
extern NSString *RendererLogKey;        // NSString of any logging message (empty if none) - separated by \n
extern NSString *RendererTimeKey;       // NSNumber of elapsed time of render
extern NSString *RendererSeedKey;       // NSNumber of the seed used for randomization

extern NSString *kDefaultScriptName;
extern NSString *kScriptExtension;

@interface Renderer : NSObject {
  void *reference_;  // Weak reference -- only using pointer value
  NSString *source_;
  NSString *name_;
  NSString *destination_;
  NSString *type_;
  unsigned long seed_;
  BOOL shouldSplit_;
  NSTask *task_;
  NSMutableData *taskResponse_;
  BOOL taskResponseContainedErrors_;
  NSString *outputPath_;
  NSTimeInterval startTime_;
  NSTimeInterval endTime_;
  NSSize size_;
  BOOL cancelNotifications_;
  BOOL disableMenubarRendering_;
}

//------------------------------------------------------------------------------
// Public
//------------------------------------------------------------------------------
+ (unsigned long)randomSeedFromDevice;
+ (NSArray *)allowedTypes;

+ (NSDictionary *)scriptsInDirectory:(NSString *)dirPath;

- (id)initWithReference:(void *)reference;

- (void)setSource:(NSString *)source name:(NSString *)name seed:(unsigned long)seed;
- (void)setMaximumSize:(NSSize)size;
- (void)setDisableMenubarRendering:(BOOL)yn;

// Output type: jpeg, png, or tiff
- (void)setType:(NSString *)type;
- (void)setShouldSplitImages:(BOOL)shouldSplit;
- (void)setDestination:(NSString *)path;

- (void)renderInBackgroundAndNotify;
- (BOOL)isRendering;
- (void)cancelRender;

// Synchronous rendering
- (BOOL)render;

- (NSTimeInterval)elapsedTime;

@end
