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

static NSString *kDynamicFilterName = @"TopDrawDynamicFilter";
static NSString *kKernelSourceKey = @"kernelSource";
static NSString *kOutputSizeKey = @"outputSize";

//------------------------------------------------------------------------------
// If no name is specified, we'll expose a dynamic filter.
@interface DynamicFilter : CIFilter {
  NSMutableDictionary *parameters_;
	CIKernel *kernel_;
}
@end

@implementation DynamicFilter
+ (void)initialize {
  NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
                        kDynamicFilterName, kCIAttributeFilterDisplayName,
                         NULL];
  [CIFilter registerFilterName:kDynamicFilterName constructor:self classAttributes:attrs];
}

+ (CIFilter *)filterWithName:(NSString *)name {
  return ([[[self alloc] init] autorelease]);
}

+ (NSString *)defaultSource {
  NSString *source = @"kernel vec4 defaultShader(vec2 outputSize) { "
  "vec2 t = destCoord() / outputSize;"
  "vec4 white = vec4(1.0, 1.0, 1.0, 1.0);"
  "vec4 black = vec4(0.0, 0.0, 0.0, 1.0);"
  "vec4 result = vec4(black * t.x + white * (1.0 - t.x));"
  "return premultiply(result);}";
  
  return source;
}

- (NSArray *)inputKeys {
  return [NSArray arrayWithObjects:kKernelSourceKey, kOutputSizeKey, nil];
}

- (NSArray *)outputKeys {
  return [NSArray arrayWithObject:kCIOutputImageKey];
}

- (void)setDefaults {
  [self setValue:[[self class] defaultSource] forUndefinedKey:kKernelSourceKey];
}

- (void)dealloc {
  // Since the superclass may try to cleanup some settings, we need to keep
  // our parameters around and call the super classes dealloc first.
  [super dealloc];
  [parameters_ release];
  [kernel_ release];
}

- (id)valueForKey:(NSString *)key {
  if ([key isEqualToString:kKernelSourceKey])
    return [self valueForUndefinedKey:key];
  
  return [super valueForKey:key];
}

- (id)valueForUndefinedKey:(NSString *)key {
  return [parameters_ objectForKey:key];
}

- (void)setValue:(id)value forKey:(NSString *)key {
  // Strings are not allowed types for CIFilters, so the default implementation
  // will erase the value
  if ([key isEqualToString:kKernelSourceKey]) {
    [kernel_ release];
    kernel_ = nil;
    [self setValue:value forUndefinedKey:key];
  } else {
    [super setValue:value forKey:key];
  }
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
  if (value) {
    if (!parameters_)
      parameters_ = [[NSMutableDictionary alloc] init];

    [parameters_ setObject:value forKey:key];
  } else {
    [parameters_ removeObjectForKey:key];
  }
}

- (CIKernel *)compiledKernel {
  if (!kernel_) {
    NSString *source = [self valueForUndefinedKey:kKernelSourceKey];
    if ([source length]) {
      NSArray *kernels = [CIKernel kernelsWithString:source];
      if ([kernels count]) {
        kernel_ = [[kernels objectAtIndex:0] retain];
      }
    }
  }
  
  return kernel_;
}

- (NSDictionary *)kernelArguments {
  NSString *source = [self valueForUndefinedKey:@"kernelSource"];
  NSScanner *scanner = [NSScanner scannerWithString:source];
  NSMutableDictionary *arguments = [NSMutableDictionary dictionary];
  
  // Find the start of the arguments
  if ([scanner scanUpToString:@"(" intoString:nil]) {
    [scanner setScanLocation:[scanner scanLocation] + 1];
    NSString *argStr;
    [scanner scanUpToString:@")" intoString:&argStr];
    
    // Arguments: type name[, type name...]
    if ([argStr length]) {
      NSScanner *argScanner = [NSScanner scannerWithString:argStr];
      NSString *arg, *type;
      NSCharacterSet *delimiterSet = [NSCharacterSet characterSetWithCharactersInString:@" ,"];
      
      while (![argScanner isAtEnd]) {
        [argScanner scanUpToCharactersFromSet:delimiterSet intoString:&type];
        [argScanner scanUpToCharactersFromSet:delimiterSet intoString:&arg];
        [argScanner scanCharactersFromSet:delimiterSet intoString:nil];
        [arguments setObject:type forKey:arg];
      }
    }
  }
  
  return arguments;
}

- (NSDictionary *)attributes {
  NSDictionary *arguments = [self kernelArguments];
  NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
  NSEnumerator *e = [arguments keyEnumerator];
  NSString *key, *type;
  while ((key = [e nextObject])) {
    type = [arguments objectForKey:key];
    if ([type isEqualToString:@"__color"])
      type = @"CIColor";
    else if ([type hasPrefix:@"vec"])
      type = @"CIVector";
    else if ([type isEqualToString:@"float"])
      type = @"NSNumber";
    
    NSDictionary *attrDict = [NSDictionary dictionaryWithObject:type forKey:@"CIAttributeClass"];
    [attributes setObject:attrDict forKey:key];
  }
  
  return attributes;
}

- (CIImage *)outputImage {
  CIKernel *kernel = [self compiledKernel];
  CIImage *result = nil;
  NSArray *argumentKeys = [[self kernelArguments] allKeys];
  CIVector *zero = [CIVector vectorWithX:0];
  NSArray *arguments = [parameters_ objectsForKeys:argumentKeys notFoundMarker:zero];
  
  @try {
    result = [self apply:kernel arguments:arguments options:nil];
  }
  
  @catch (NSException *e) {
    NSLog(@"Kernel problem: %@", e);
  }
  
  return result;
}

@end

@implementation Filter
//------------------------------------------------------------------------------
+ (NSString *)className {
  return @"Filter";
}

//------------------------------------------------------------------------------
+ (NSSet *)properties {
  return [NSSet setWithObjects:@"name", @"inputFilter", @"kernelSource", nil];
}

//------------------------------------------------------------------------------
+ (NSSet *)methods {
  return [NSSet setWithObjects:@"setKeyValue", @"toString", nil];
}

//------------------------------------------------------------------------------
- (id)initWithArguments:(NSArray *)arguments {
  if ((self = [super initWithArguments:arguments])) {
    int count = [arguments count];
    NSString *name = kDynamicFilterName;
    
    // Ensure that our filter is initialized
    [DynamicFilter defaultSource];
    
    if (count == 1)
      name = [RuntimeObject coerceObject:[arguments objectAtIndex:0] toClass:[NSString class]];
      
    filter_ = [[CIFilter filterWithName:name] retain];
    [filter_ setDefaults];
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
- (void)setKernelSource:(NSString *)source {
  @try {
    [filter_ setValue:source forKey:kKernelSourceKey];
  }
  
  @catch (NSException *e) {
    // Don't care
  }
}

//------------------------------------------------------------------------------
- (NSString *)kernelSource {
  return [filter_ valueForKey:kKernelSourceKey];
}

//------------------------------------------------------------------------------
- (void)setKeyValue:(NSArray *)arguments {
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
  
  // Support conversion to CIVector, CIColor, Image, and NSNumber
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
  } else if ([attributeClass isEqualToString:@"CIImage"]) {
    // Create a sampler?
  } 
}

//------------------------------------------------------------------------------
- (NSString *)toString {
  return [NSString stringWithFormat:@"%@", [filter_ attributes]];
}

@end
