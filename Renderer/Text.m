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
  return [NSSet setWithObjects:@"string", @"bounds",
          @"fontName", @"fontSize", @"fontStyle", 
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
    descriptor_ = [[NSFontDescriptor fontDescriptorWithName:@"Lucida Grande" size:64] retain];
    
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
  [descriptor_ release];
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
  if (![attributes_ objectForKey:NSFontAttributeName]) {
    NSSet *keys = [NSSet setWithObjects:NSFontFamilyAttribute, NSFontSizeAttribute, nil];
    NSArray *match = [descriptor_ matchingFontDescriptorsWithMandatoryKeys:keys];
    NSFontSymbolicTraits searchTraits = [descriptor_ symbolicTraits];
    CGFloat pointSize = [descriptor_ pointSize];
    int count = [match count];
    NSFontDescriptor *matchDescriptor = nil;
    
    for (int i = 0; (i < count) && (!matchDescriptor); ++i) {
      if (([[match objectAtIndex:i] symbolicTraits] & searchTraits) == searchTraits) {
        matchDescriptor = [match objectAtIndex:i];
      }
    }
    
    if (!matchDescriptor && count)
      matchDescriptor = [match objectAtIndex:0];
    
    if (matchDescriptor) {
      NSFont *font = [NSFont fontWithDescriptor:matchDescriptor size:pointSize];

      if (font)
        [attributes_ setObject:font forKey:NSFontAttributeName];
    }
  }
  
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
  NSDictionary *attributes = [self attributes];
  NSAttributedString *str = [[NSAttributedString alloc] initWithString:string_ attributes:attributes];
  NSRect optimalRect = [str boundingRectWithSize:constraint.size options:options];
  [str release];
  
  return [[[RectObject alloc] initWithRect:optimalRect] autorelease];
}

- (void)setFontDescriptor:(NSFontDescriptor *)descriptor {
  if (descriptor != descriptor_) {
    [descriptor_ release];
    descriptor_ = [descriptor retain];
    
    // Invalidate font
    [attributes_ removeObjectForKey:NSFontAttributeName];
  }
}

- (void)setFontName:(NSString *)name {
  [self setFontDescriptor:[descriptor_ fontDescriptorWithFamily:name]];
}

- (NSString *)fontName {
  return [descriptor_ objectForKey:NSFontFamilyAttribute];
}

- (void)setFontSize:(CGFloat)size {
  [self setFontDescriptor:[descriptor_ fontDescriptorWithSize:size]];
}

- (CGFloat)fontSize {
  return [descriptor_ pointSize];
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

- (void)setFontStyle:(NSString *)stylesStr {
  NSArray *styles = [[stylesStr lowercaseString] componentsSeparatedByString:@","];
  NSEnumerator *e = [styles objectEnumerator];
  NSString *style;
  NSFontSymbolicTraits traits = 0;
  
  while ((style = [e nextObject])) {
    NSString *trimmed = [style stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([trimmed isEqualToString:@"bold"])
      traits |= NSFontBoldTrait;
    else if ([trimmed isEqualToString:@"italic"])
      traits |= NSFontItalicTrait;
    else if ([trimmed isEqualToString:@"expanded"])
      traits |= NSFontExpandedTrait;
    else if ([trimmed isEqualToString:@"condensed"])
      traits |= NSFontCondensedTrait;
  }
  
  [self setFontDescriptor:[descriptor_ fontDescriptorWithSymbolicTraits:traits]];
}

@end
