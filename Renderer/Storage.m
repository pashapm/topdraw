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

#import "Compositor.h"
#import "Exporter.h"
#import "Storage.h"

@implementation Storage
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Private ||
//------------------------------------------------------------------------------
- (void)readFromStoragePath {
  NSString *path = [[Exporter storageDirectory] stringByAppendingPathComponent:name_];
  NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
  
  if ([dict count])
    [dictionary_ addEntriesFromDictionary:dict];
}

//------------------------------------------------------------------------------
- (void)writeToStoragePath {
  NSString *path = [[Exporter storageDirectory] stringByAppendingPathComponent:name_];
  
  [dictionary_ writeToFile:path atomically:NO];
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Runtime ||
//------------------------------------------------------------------------------
+ (NSString *)className {
  return @"Storage";
}

//------------------------------------------------------------------------------
+ (NSSet *)properties {
  return [NSSet setWithObjects:@"allKeys", @"allValues", nil]; 
}

//------------------------------------------------------------------------------
+ (NSSet *)methods {
  return [NSSet setWithObjects:@"setValueForKey", @"valueForKey",
          @"toString", nil];
}

//------------------------------------------------------------------------------
- (id)initWithArguments:(NSArray *)arguments {
  if ((self = [super initWithArguments:arguments])) {
    dictionary_ = [[NSMutableDictionary alloc] init];
    
    if ([arguments count]) {
      name_ = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[NSString class]];
      name_ = [[name_ lastPathComponent] copy];
    } else {
      name_ = [[[Compositor sharedCompositor] name] copy];
    }
    
    if (![name_ length]) {
      NSLog(@"Invalid name");
      [self release];
      self = nil;
    } else {
      [self readFromStoragePath];
    }
  }
  
  return self;
}

//------------------------------------------------------------------------------
- (void)dealloc {
  [self writeToStoragePath];
  [name_ release];
  [dictionary_ release];
  [super dealloc];
}

//------------------------------------------------------------------------------
- (void)setValueForKey:(NSArray *)arguments {
  if ([arguments count] == 2) {
    id value = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[NSString class]];
    NSString *key = [RuntimeObject coerceObject:[arguments objectAtIndex:1] toClass:[NSString class]];
    
    if (!value)
      value = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[NSNumber class]];
    
    if (value)
      [dictionary_ setObject:value forKey:key];
  }
}

//------------------------------------------------------------------------------
- (id)valueForKey:(NSArray *)arguments {
  if ([arguments count] == 1) {
    NSString *key = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[NSString class]];
    
    return [dictionary_ objectForKey:key];
  }
  
  return nil;
}
    
@end
