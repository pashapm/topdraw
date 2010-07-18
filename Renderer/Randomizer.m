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

#import "Randomizer.h"

// Use a CGFloat lookup table to speed things up
static NSUInteger kSeed = 0;
static const NSUInteger kRandomTableSize = 65536;
static CGFloat *kRandomTable = NULL;
static NSUInteger kRandomTableIndex = 0;

static void InitializeRandomizerWithSeed(NSUInteger seed) {
  @synchronized ([Randomizer class]) {
    if (!kRandomTable)
      kRandomTable = (CGFloat *)malloc(sizeof(CGFloat) * kRandomTableSize);

    // Choose a random starting point as well.  It seems like making it 0 will
    // cause the first value to be 0.
    kRandomTableIndex = arc4random() % kRandomTableSize;

    kSeed = seed;
    NSUInteger lo = kSeed, hi = ~kSeed;
    for (NSUInteger i = 0; i < kRandomTableSize; ++i) {
      hi = (hi << 16) + (hi >> 16);
      hi += lo;
      lo += hi;
      kRandomTable[i] = (CGFloat)hi / (CGFloat)NSUIntegerMax;
    }
  }
}

CGFloat RandomizerFloatValue() {
  if (!kRandomTable)
    InitializeRandomizerWithSeed(CFAbsoluteTimeGetCurrent() * 10);

  if (kRandomTableIndex >= kRandomTableSize)
    kRandomTableIndex = 0;

  // In case there's a threaded access to bump this, we'll get a local
  // copy of the index and also check it
  NSUInteger idx = kRandomTableIndex++;

  if (idx >= kRandomTableSize)
    idx = 0;

  return kRandomTable[idx];
}

@implementation Randomizer

+ (NSString *)className {
  return @"Randomizer";
}

+ (NSSet *)properties {
  return [NSSet setWithObjects:@"floatValue", @"boolValue", @"booleanValue",
          @"intValue", @"integerValue", nil];
}

+ (NSSet *)readOnlyProperties {
  // All are read only
  return [self properties];
}

+ (void)setSharedSeed:(NSUInteger)seed {
  InitializeRandomizerWithSeed(seed);
}

- (id)initWithArguments:(NSArray *)arguments {
  if ((self = [super initWithArguments:arguments])) {
    min_ = 0;
    max_ = 1.0;

    if ([arguments count] == 2) {
      min_ = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:0]];
      max_ = [RuntimeObject coerceObjectToDouble:[arguments objectAtIndex:1]];

      if (max_ < min_) {
        CGFloat temp = min_;
        min_ = max_;
        max_ = temp;
      }
    }
  }

  return self;
}

- (CGFloat)floatValue {
  return min_ + RandomizerFloatValue() * (max_ - min_);
}

- (BOOL)boolValue {
  return RandomizerFloatValue() > 0.5 ? YES : NO;
}

- (BOOL)booleanValue {
  return [self boolValue];
}

- (CGFloat)intValue {
  return [self integerValue];
}

- (CGFloat)integerValue {
  return rint([self floatValue]);
}

@end
