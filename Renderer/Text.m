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

#import "Color.h"
#import "RectObject.h"
#import "Text.h"

@implementation Text

+ (NSString *)className {
  return @"Text";
}

+ (NSSet *)properties {
  return [NSSet setWithObjects:@"string", @"fontName", @"fontSize", @"bounds",
          @"foregroundColor", @"backgroundColor", nil];
}

+ (NSSet *)readOnlyProperties {
  return [NSSet setWithObjects:@"bounds", nil];
}

+ (NSSet *)methods {
  return [NSSet setWithObjects:@"boundsForRect", @"toString", nil];
}

+ (NSDictionary *)defaultAttributes {
  return [NSDictionary dictionaryWithObjectsAndKeys:
          [NSFont fontWithName:@"LucidaGrande" size:18], NSFontAttributeName,
          [NSColor grayColor], NSForegroundColorAttributeName,
          nil];
}

- (id)initWithArguments:(NSArray *)arguments {
  if ((self = [super initWithArguments:arguments])) {
    int count = [arguments count];
    attributes_ = [[NSMutableDictionary alloc] initWithDictionary:[[self class] defaultAttributes]];
    string_ = @"";
    
    // Can initialize with a string
    if (count == 1) {
      NSString *str = [RuntimeObject coerceArray:arguments objectAtIndex:0 toClass:[NSString class]];
      
      [self setString:str];
    }
  }
  
  return self;
}
        
- (id)initWithString:(NSString *)string {
  return [self initWithArguments:[NSArray arrayWithObject:string]];
}

- (void)dealloc {
  [string_ release];
  [attributes_ release];
  [super dealloc];
}

- (void)setString:(NSString *)string {
  if (string != string_) {
    [string_ release];
    string_ = [string copy];
  }
}

- (NSString *)string {
  return string_;
}

- (NSDictionary *)attributes {
  return attributes_;
}

- (RectObject *)bounds {
  return [self boundsForRect:nil];
}

- (RectObject *)boundsForRect:(NSArray *)arguments {
  NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingDisableScreenFontSubstitution;
  int count = [arguments count];
  RectObject *rect = count ? [RuntimeObject coerceArray:arguments objectAtIndex:0 toClass:[RectObject class]] : nil;
  NSRect constraint = rect ? [rect rect] : NSMakeRect(0, 0, 65000, 65000);
  NSAttributedString *str = [[NSAttributedString alloc] initWithString:string_ attributes:attributes_];
  NSRect optimalRect = [str boundingRectWithSize:constraint.size options:options];
  [str release];
  
  return [[[RectObject alloc] initWithRect:optimalRect] autorelease];
}

- (void)setFontName:(NSString *)name {
  CGFloat size = [self fontSize];
  NSFont *font = [NSFont fontWithName:name size:size];
  
  if (font)
    [attributes_ setObject:font forKey:NSFontAttributeName];
}

- (NSString *)fontName {
  return [attributes_ objectForKey:NSFontAttributeName];
}

- (void)setFontSize:(CGFloat)size {
  NSFont *font = [attributes_ objectForKey:NSFontAttributeName];
  font = [NSFont fontWithName:[font familyName] size:size];
  
  if (font)
    [attributes_ setObject:font forKey:NSFontAttributeName];
}

- (CGFloat)fontSize {
  NSFont *font = [attributes_ objectForKey:NSFontAttributeName];
  
  return [font pointSize];
}

- (void)setForegroundColor:(Color *)color {
  [attributes_ setObject:[color color] forKey:NSForegroundColorAttributeName];
}

- (Color *)foregroundColor {
  NSColor *fg = [attributes_ objectForKey:NSForegroundColorAttributeName];
  Color *color = [[[Color alloc] init] autorelease];
  [color setColor:fg];
  
  return color;  
}

- (void)setBackgroundColor:(Color *)color {
  [attributes_ setObject:[color color] forKey:NSBackgroundColorAttributeName];
}

- (Color *)backgroundColor {
  NSColor *bg = [attributes_ objectForKey:NSBackgroundColorAttributeName];
  Color *color = [[[Color alloc] init] autorelease];
  [color setColor:bg];
  
  return color;  
}

- (void)replaceWithRandomWord {
  
}

@end
