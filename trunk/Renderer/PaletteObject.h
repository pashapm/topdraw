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

// Holds a palette of colors that can created manually or read from a URL.
// Can return a random color or an array with all colors

#import "RuntimeObject.h"

@interface PaletteObject : RuntimeObject {
 @protected
  NSMutableArray *colors_;
  NSURLRequest *request_;
}

@end
