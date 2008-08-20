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

// Manage particles with color and other physical attributes.  For use in the
// simulator.

#import "SimulatorObject.h"

@class Layer;
@class Randomizer;

typedef struct Particle {
  CGPoint location;
  CGPoint velocity;
  CGPoint acceleration;
  CGFloat color[4];
  unsigned long age;
} Particle;

@interface Particles : SimulatorObject {
 @protected
  CGPoint gravity_;
  CGPoint location_;
  CGFloat trailWidth_;
  CGFloat alphaDelta_;
  unsigned long alphaDelay_;
  unsigned long maxAge_;
  Randomizer *velocityXRandomizer_;
  Randomizer *velocityYRandomizer_;
  Randomizer *accelerationXRandomizer_;
  Randomizer *accelerationYRandomizer_;
  NSUInteger maxParticleCount_;

  Particle *particles_;
  NSUInteger currentCount_;
  
  NSMutableArray *colors_;
  NSMutableArray *gravityPoints_;
}

@end
