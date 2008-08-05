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

// Base class for any objects that are to be used in the Simulator

#import "RuntimeObject.h"

@class Layer;

@interface SimulatorObject : RuntimeObject {
  Layer *layer_;
  CGFloat timeStep_;
}

- (void)setLayer:(Layer *)layer;
- (void)setTimeStep:(NSNumber *)step;
- (void)step;

@end
