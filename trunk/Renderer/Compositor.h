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

// Evaluate the Top Draw Scripts and Composite layers together 

#import "RuntimeObject.h"

@class Layer;
@class Runtime;

typedef void (*LoggingCB)(const char *msg, void *context);

@interface Compositor : RuntimeObject {
 @protected
  NSString *source_;
  NSString *name_;
  Layer *desktop_;
  Layer *menubar_;
  NSMutableArray *layers_;
  NSMutableArray *blendModes_;
  NSUInteger seed_;
  LoggingCB loggingCallback_;
  void *loggingCallbackContext_;
  NSSize size_;
  int requiredVersion_;
  Runtime *activeRuntime_;  // Weak
}

- (id)initWithSource:(NSString *)source name:(NSString *)name;

// Specify the maximum size for the drawing
- (void)setMaximumSize:(NSSize)size;

// Return an error string (or nil if no error)
- (NSString *)evaluateWithSeed:(NSUInteger)seed;

// Get the image that is the result of the evaluation
- (CGImageRef)image;

- (Layer *)desktop;
- (Layer *)menubar;

- (void)setRandomSeed:(NSUInteger)seed;
- (NSUInteger)randomSeed;

- (void)setLoggingCallback:(LoggingCB)cb context:(void *)context;

@end
