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

#import "Exporter.h"
#import "NSScreen+Convenience.h"

static const int kMaxCachedDrawings = 10;

@implementation Exporter
//------------------------------------------------------------------------------
+ (NSString *)supportDirectory:(NSString *)subdir {
  NSString *path = nil;
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                       NSUserDomainMask, YES);
  
  if ([paths count]) {
    NSString *dir = [paths objectAtIndex:0];
    path = [dir stringByAppendingPathComponent:@"Google/TopDraw"];
    NSError *error = nil;
    
    if (subdir)
      path = [path stringByAppendingPathComponent:subdir];
    
    if (![[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES 
                                                    attributes:nil error:&error]) {
      MethodLog("Unable to create %@: %@", path, [error localizedDescription]);
      return nil;
    }
  }
  
  return path;
}

//------------------------------------------------------------------------------
+ (NSString *)imageDirectory {
  // We'll store the images in the base
  return [self supportDirectory:nil];
}

//------------------------------------------------------------------------------
+ (NSString *)scriptDirectory {
  return [self supportDirectory:@"Scripts"];
}

//------------------------------------------------------------------------------
+ (NSString *)storageDirectory {
  return [self supportDirectory:@"Storage"];
}

//------------------------------------------------------------------------------
+ (NSString *)rendererDirectory {
  return [self supportDirectory:@"Renderer"];
}

//------------------------------------------------------------------------------
+ (NSString *)nextBaseName {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSInteger idxNumber = [ud integerForKey:@"NextIndex"];

  if (++idxNumber >= kMaxCachedDrawings)
    idxNumber = 0;
  
  [ud setInteger:idxNumber forKey:@"NextIndex"];
  
  return [NSString stringWithFormat:@"Image-%ld", (long)idxNumber];
}

//------------------------------------------------------------------------------
+ (NSString *)idForScreen:(NSScreen *)screen {
	return [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] stringValue];
}

//------------------------------------------------------------------------------
+ (NSDictionary *)partitionAndWriteImage:(CGImageRef)image path:(NSString *)path type:(NSString *)type {
  NSArray *screens = [NSScreen screens];
  NSMutableDictionary *result = [NSMutableDictionary dictionary];
  NSString *writtenPath;

  if ([screens count] == 1) {
    writtenPath = [self exportImage:image path:path type:type quality:1.0];
    
    if (writtenPath)
      [result setObject:writtenPath forKey:[self idForScreen:[NSScreen mainScreen]]];
  } else {
    NSString *baseName = [[path lastPathComponent] stringByDeletingPathExtension];
    NSString *baseDir = [path stringByDeletingLastPathComponent];
    int idxNumber = 0;
    CGFloat height = CGImageGetHeight(image);
    
    for (NSScreen *screen in screens) {
      NSRect frame = [screen globalFrame];
      
      // subimage is (0,0) in upper left so flip around
      frame.origin.y = (height - frame.size.height - frame.origin.y);
      
      CGImageRef subImage = CGImageCreateWithImageInRect(image, NSRectToCGRect(frame));
      NSString *filePath = [baseDir stringByAppendingPathComponent:baseName];
      filePath = [filePath stringByAppendingFormat:@"-%d", idxNumber];      
      writtenPath = [self exportImage:subImage path:filePath type:type quality:1.0];
      
      if (writtenPath)
        [result setObject:writtenPath forKey:[self idForScreen:screen]];
      else
        MethodLog("Failed to write to %@", filePath);
      
      CGImageRelease(subImage);
      ++idxNumber;
    }
  }
  
  return result;
}

//------------------------------------------------------------------------------
+ (NSString *)exportImage:(CGImageRef)image path:(NSString *)path type:(NSString *)type quality:(CGFloat)quality {
  NSMutableData *data = [[NSMutableData alloc] init];
  NSString *utiType = [NSString stringWithFormat:@"public.%@", type];
  CGImageDestinationRef dest = CGImageDestinationCreateWithData((CFMutableDataRef)data,
                                                                (CFStringRef)utiType, 1, nil);
  
  if (dest) {
    NSDictionary *properties = 
    [NSDictionary dictionaryWithObjectsAndKeys:
     [NSNumber numberWithFloat:quality], (NSString *)kCGImageDestinationLossyCompressionQuality,
     nil];
    CGImageDestinationAddImage(dest, image, (CFDictionaryRef)properties);
    CGImageDestinationFinalize(dest);
    
    NSString *ext = [path pathExtension];
    
    if (![ext length])
      path = [path stringByAppendingPathExtension:type];
    
    if (![data writeToFile:path atomically:NO])
      path = nil;

    CFRelease(dest);
  } else {
    path = nil;
  }

  [data release];
  
  return path;
}

@end
