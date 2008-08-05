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

#import <QuartzCore/QuartzCore.h>

#import "Color.h"
#import "Filter.h"

@implementation Filter
//------------------------------------------------------------------------------
+ (NSString *)className {
  return @"Filter";
}

//------------------------------------------------------------------------------
+ (NSSet *)properties {
  return [NSSet setWithObjects:@"name", @"inputFilter", nil];
}

//------------------------------------------------------------------------------
+ (NSSet *)methods {
  return [NSSet setWithObjects:@"setValueForKey", @"toString", nil];
}

//------------------------------------------------------------------------------
- (id)initWithArguments:(NSArray *)arguments {
  if ((self = [super initWithArguments:arguments])) {
    int count = [arguments count];
    if (count == 1) {
      NSString *name = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[NSString class]];
      filter_ = [[CIFilter filterWithName:name] retain];
      [filter_ setDefaults];
    }
  }
  
  return self;
}

//------------------------------------------------------------------------------
- (void)dealloc {
  [filter_ release];
  [super dealloc];
}

//------------------------------------------------------------------------------
- (CIFilter *)ciFilter {
  return filter_;
}

//------------------------------------------------------------------------------
- (void)setInputFilter:(Filter *)filter {
  [inputFilter_ release];
  inputFilter_ = [filter retain];
  
  // Hook the output of the input to our input
  @try {
    [filter_ setValue:[[filter ciFilter] valueForKey:@"outputImage"] forKey:@"inputImage"];
  }
  
  @catch (NSException *e) {
    NSLog(@"Filter Excption: %@", e);
  }
}

//------------------------------------------------------------------------------
- (Filter *)inputFilter {
  return inputFilter_;
}

//------------------------------------------------------------------------------
- (NSString *)name {
  NSDictionary *attrs = [filter_ attributes];
  return [attrs objectForKey:kCIAttributeFilterName];
}

//------------------------------------------------------------------------------
- (void)setValueForKey:(NSArray *)arguments {
  int count = [arguments count];
  
  if (count < 2)
    return;

  // First thing should be the key to set
  NSString *key = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[NSString class]];
  NSDictionary *allAttributes = [filter_ attributes];
  
  NSDictionary *attributeDetails = [allAttributes objectForKey:key];
  NSString *attributeClass = [attributeDetails objectForKey:@"CIAttributeClass"];
  NSArray *parameters = [arguments subarrayWithRange:NSMakeRange(1, count - 1)];

  count = [parameters count];
  
  // Support conversion to CIVector, CIColor, and NSNumber
  if ([attributeClass isEqualToString:@"CIVector"]) {
    CGFloat *values = (CGFloat *)malloc(sizeof(CGFloat) * count);
    for (int i = 0; i < count; ++i)
      values[i] = [[parameters objectAtIndex:i] floatValue];

    CIVector *v = [CIVector vectorWithValues:values count:count];
    [filter_ setValue:v forKey:key];
    free(values);
  } else if ([attributeClass isEqualToString:@"CIColor"]) {
    CGFloat c[4] = { 1 };
    
    if (count == 1) {
      Color *color = [RuntimeObject coerceObject:[parameters objectAtIndex:0] toClass:[Color class]];
      [color getComponents:c];
    } else if (count == 3 || count == 4) {
      for (int i = 0; i < count; ++i)
        c[i] = [RuntimeObject coerceObjectToDouble:[parameters objectAtIndex:i]];
    }
    CIColor *ciColor = [CIColor colorWithRed:c[0] green:c[1] blue:c[2] alpha:c[3]];
    [filter_ setValue:ciColor forKey:key];    
  } else if ([attributeClass isEqualToString:@"NSNumber"]) {
    CGFloat v = [RuntimeObject coerceObjectToDouble:[parameters objectAtIndex:0]];
    [filter_ setValue:[NSNumber numberWithFloat:v] forKey:key];
  } else
    NSLog(@"Key: %@ not known or supported", key);
}

//------------------------------------------------------------------------------
- (NSString *)toString {
  return [NSString stringWithFormat:@"%@", [filter_ attributes]];
}

@end
