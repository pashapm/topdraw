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

// Strings and drawing attributes

#import "RuntimeObject.h"

@class Color;
@class RectObject;

@interface Text : RuntimeObject {
  NSString *string_;
  NSMutableDictionary *attributes_;
}

- (id)initWithString:(NSString *)string;

- (void)setString:(NSString *)string;
- (NSString *)string;

- (NSDictionary *)attributes;

- (RectObject *)bounds;
- (RectObject *)boundsForRect:(NSArray *)arguments;

- (void)setFontName:(NSString *)name;
- (NSString *)fontName;

- (void)setFontSize:(CGFloat)size;
- (CGFloat)fontSize;

- (void)setForegroundColor:(Color *)color;
- (Color *)foregroundColor;

- (void)setBackgroundColor:(Color *)color;
- (Color *)backgroundColor;

@end
