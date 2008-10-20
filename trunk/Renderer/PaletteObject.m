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
#import "PaletteObject.h"
#import "Randomizer.h"

@interface PaletteObject (PrivateMethods)
- (void)addColors:(NSArray *)colors;
- (Color *)internalColorAtIndex:(int)index;
- (void)addKulerFeed:(NSData *)data;
@end

@implementation PaletteObject
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Runtime ||
//------------------------------------------------------------------------------
+ (NSString *)className {
  return @"Palette";
}

//------------------------------------------------------------------------------
+ (NSSet *)properties {
  return [NSSet setWithObjects:@"count", @"colors", @"randomColor", nil]; 
}

//------------------------------------------------------------------------------
+ (NSSet *)readOnlyProperties {
  return [NSSet setWithObjects:@"count", @"colors", @"randomColor", nil]; 
}

//------------------------------------------------------------------------------
+ (NSSet *)methods {
  return [NSSet setWithObjects:@"addColors", @"addKulerColors",
          @"colorAtIndex",
          @"toString", nil];
}

//------------------------------------------------------------------------------
- (id)initWithArguments:(NSArray *)arguments {
  if ((self = [super initWithArguments:arguments])) {
    colors_ = [[NSMutableArray alloc] init];
    [self addColors:arguments];
  }
  
  return self;
}

//------------------------------------------------------------------------------
- (void)dealloc {
  [colors_ release];
  [super dealloc];
}

//------------------------------------------------------------------------------
- (int)count {
  return [colors_ count];
}

//------------------------------------------------------------------------------
- (NSArray *)colors {
  return [NSArray arrayWithArray:colors_];
}

//------------------------------------------------------------------------------
- (Color *)randomColor {
  int idx = floor(RandomizerFloatValue() * [colors_ count]);
  return [self internalColorAtIndex:idx];
}

//------------------------------------------------------------------------------
- (void)addColors:(NSArray *)arguments {
  int count = [arguments count];
  for (int i = 0; i < count; ++i) {
    Color *c = [RuntimeObject coerceObject:[arguments objectAtIndex:i] toClass:[Color class]];
    
    if (!c) {
      NSString *name = [RuntimeObject coerceObject:[arguments objectAtIndex:i] toClass:[NSString class]];
      c = [[[Color alloc] initWithColorName:name] autorelease];
    }
    
    if (c)
      [colors_ addObject:c];
  }
}

//------------------------------------------------------------------------------
- (Color *)colorAtIndex:(NSArray *)arguments {
  if ([arguments count]) {
    NSInteger index = [RuntimeObject coerceObjectToInteger:[arguments objectAtIndex:0]];
    return [self internalColorAtIndex:index];
  }
  
  return nil;
}

//------------------------------------------------------------------------------
- (Color *)internalColorAtIndex:(int)index {
  if (index < 0 || index >= [colors_ count])
    return nil;
  
  return [colors_ objectAtIndex:index];
}

//------------------------------------------------------------------------------
- (void)addKulerFeed:(NSData *)data {
  NSString *dataStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  NSScanner *scanner = [NSScanner scannerWithString:dataStr];
  NSString *hexMarkerStr = @"kuler:swatchHexColor>";
  
  while (1) {
    [scanner scanUpToString:hexMarkerStr intoString:nil];
    if ([scanner isAtEnd])
      break;
    
    [scanner scanString:hexMarkerStr intoString:nil];
    NSString *hexStr;
    [scanner scanUpToString:@"</" intoString:&hexStr];
    
    Color *c = [[Color alloc] initWithColorName:hexStr];

    if (c) {
      [colors_ addObject:c];
      [c release];
    }
    
    [scanner setScanLocation:[scanner scanLocation] + [hexMarkerStr length]];
  }
  
  [dataStr release];
}

//------------------------------------------------------------------------------
- (void)addKulerColors:(NSArray *)arguments {
  // Load Adobe Kuler colors
  // http://learn.adobe.com/wiki/display/kulerdev/A.+Kuler+API+Documentation
  NSInteger argCount = [arguments count];
  NSInteger nextArgIndex = 0;
  NSString *baseURLStr = @"http://kuler-api.adobe.com/rss/";
  NSString *getFmt = @"get.cfm?listtype=%@";
  NSString *searchFmt = @"search.cfm?searchQuery=%@";

  if (argCount) {
    NSString *type = [[RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[NSString class]] lowercaseString];
    NSInteger count = 5;
    NSString *search = nil;
    NSString *urlStr = [baseURLStr stringByAppendingFormat:getFmt, type];
    nextArgIndex = 1;
    
    if (argCount > 1) {
      if ([type isEqualToString:@"search"]) {
        search = [RuntimeObject coerceObject:[arguments objectAtIndex:1] toClass:[NSString class]];
        nextArgIndex = 2;
        urlStr = [baseURLStr stringByAppendingFormat:searchFmt, search];
      }
      
      if (argCount > nextArgIndex)
        count = [RuntimeObject coerceObjectToInteger:[arguments objectAtIndex:nextArgIndex]];
    }

    // Add the key and a limit
    urlStr = [urlStr stringByAppendingFormat:@"&itemsPerPage=%d&key=9B9B1A989185ED36A88A2E7817FF7389",
              count];
    NSString *escaped = [urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSURL *url = [NSURL URLWithString:escaped];
    NSData *data = [NSData dataWithContentsOfURL:url];
    [self addKulerFeed:data];
  }
}

@end
