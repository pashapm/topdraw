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

#import "RuntimeObject.h"

@interface RuntimeObject(PrivateMethods)
@end

@implementation RuntimeObject
+ (NSInteger)coerceObjectToInteger:(id)obj {
  if ([obj isMemberOfClass:[NSNumber class]])
    return [obj integerValue];
  
  if ([obj respondsToSelector:@selector(intValue)])
    return [obj intValue];
  
  return 0;
}

+ (double)coerceObjectToDouble:(id)obj {
  if ([obj isMemberOfClass:[NSNumber class]])
    return [obj doubleValue];
  
  if ([obj respondsToSelector:@selector(doubleValue)])
    return [obj doubleValue];
  
  return 0;
}

+ (id)coerceObject:(id)object toClass:(Class)classType {
  if ([object isKindOfClass:classType])
    return object;
  
  return nil;
}

+ (id)coerceArray:(NSArray *)array objectAtIndex:(NSUInteger)index toClass:(Class)classType {
  id result = nil;
  
  if (index < [array count]) {
    result = [array objectAtIndex:index];
    
    if (![result isKindOfClass:classType])
      result = nil;
  }
  
  return result;
}

+ (NSString *)className {
  return @"RuntimeObject";
}

+ (NSSet *)properties {
  return nil;
}

+ (NSSet *)readOnlyProperties {
  return nil;
}

+ (NSSet *)methods {
  return nil;
}

- (id)initWithArguments:(NSArray *)arguments {
  if ((self = [super init])) {
  }
  
  return self;
}

- (void)dealloc {
  [exception_ release];
  [super dealloc];
}

- (id)valueForProperty:(NSString *)property {
  if ([[[self class] properties] containsObject:property])
    return [self valueForKey:property];
  
  [self setException:[NSString stringWithFormat:@"Unknown property: %@", property]];
  return nil;
}

- (void)setValue:(id)value forProperty:(NSString *)property {
  if ([[[self class] properties] containsObject:property]) {

    if (![[[self class] readOnlyProperties] containsObject:property])
      [self setValue:value forKey:property];
    else
      [self setException:[NSString stringWithFormat:@"Read-only property: %@", property]];
  }
  
  [self setException:[NSString stringWithFormat:@"Unknown property: %@", property]];
}

- (void)setException:(NSString *)message {
  if (message != exception_) {
    [exception_ release];
    exception_ = [message copy];
  }
}

- (NSString *)exception {
  return exception_;
}

@end
