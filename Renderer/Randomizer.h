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

// Object to return random value within a specified range

#import "RuntimeObject.h"

// C-api to getting a float value between 0 and 1
CGFloat RandomizerFloatValue();

@interface Randomizer : RuntimeObject {
  CGFloat min_;
  CGFloat max_;
}

+ (void)setSharedSeed:(NSUInteger)seed;

- (id)initWithArguments:(NSArray *)arguments;

- (CGFloat)floatValue;
- (CGFloat)integerValue;

@end
