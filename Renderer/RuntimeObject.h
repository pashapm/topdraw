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

// Base class for objects that are used in the Runtime

#import <Foundation/Foundation.h>

@class Runtime;

@protocol RuntimeObject
+ (NSString *)className;

// Return a set of NSStrings with the names of properties.  All properties are
// considered to be non-deletable and read-write unless specified otherwise.
// If there are no properties, return nil.  Default is nil.
+ (NSSet *)properties;

// Returns a NSSet of property names that are read-only
+ (NSSet *)readOnlyProperties;

// Return a set of NSStrings with the names of methods.  The methods can have
// an optional NSArray parameter which contains the array of arguments to the
// method.  Methods can return: NSNumber, NSNull, NSArray, RuntimeObject subclass, or 
// no value (e.g., void).  Default is nil.
+ (NSSet *)methods;

// Initialize a new instance of this object with |arguments|.
- (id)initWithArguments:(NSArray *)arguments;

- (id)valueForProperty:(NSString *)property;
- (void)setValue:(id)value forProperty:(NSString *)property;

- (void)setException:(NSString *)message;
- (NSString *)exception;
@end

@interface RuntimeObject : NSObject <RuntimeObject> {
  NSString *exception_;
}

+ (NSInteger)coerceObjectToInteger:(id)obj;
+ (double)coerceObjectToDouble:(id)obj;
+ (id)coerceObject:(id)object toClass:(Class)classType;
+ (id)coerceArray:(NSArray *)array objectAtIndex:(NSUInteger)index toClass:(Class)classType;

@end
