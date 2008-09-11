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

#import "ColorSet.h"

@implementation ColorSet
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Runtime ||
//------------------------------------------------------------------------------
+ (NSString *)className {
  return @"ColorSet";
}

//------------------------------------------------------------------------------
+ (NSSet *)properties {
  return [NSSet setWithObjects:@"count", @"color", @"colors", nil]; 
}

//------------------------------------------------------------------------------
+ (NSSet *)methods {
  return [NSSet setWithObjects:@"addColors", @"addKulerColors",
//          cs.addKulerColors(<name>, [...]);
//          cs.addKulerColors("recent", count);
          @"toString", nil];
}

//------------------------------------------------------------------------------
- (id)initWithArguments:(NSArray *)arguments {
  if ((self = [super initWithArguments:arguments])) {

  }
  
  return self;
}


    
@end
