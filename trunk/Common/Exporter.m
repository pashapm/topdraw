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
+ (NSString *)baseStorageDirectory {
  NSString *result = nil;
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                       NSUserDomainMask, YES);
  
  if ([paths count]) {
    NSString *dir = [paths objectAtIndex:0];
    result = [dir stringByAppendingPathComponent:@"Google/TopDraw"];
    NSError *error = nil;
    
    if (![[NSFileManager defaultManager] createDirectoryAtPath:result withIntermediateDirectories:YES 
                                                    attributes:nil error:&error]) {
      MethodLog("Unable to create %@: %@", result, [error localizedDescription]);
      return nil;
    }
  }
  
  return result;
}

//------------------------------------------------------------------------------
+ (NSString *)imageStorageDirectory {
  NSString *base = [self baseStorageDirectory];

  // We'll store the images in the base
  return base;
}

//------------------------------------------------------------------------------
+ (NSString *)scriptStorageDirectory {
  NSString *base = [self baseStorageDirectory];
  NSString *path = [base stringByAppendingPathComponent:@"Scripts"];
  NSError *error = nil;
  
  if (![[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES 
                                                  attributes:nil error:&error]) {
    MethodLog("Unable to create %@: %@", path, [error localizedDescription]);
    path = nil;
  }
    
  return path;
}

//------------------------------------------------------------------------------
+ (NSString *)nextBaseName {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSInteger idxNumber = [ud integerForKey:@"NextIndex"];

  if (++idxNumber > kMaxCachedDrawings)
    idxNumber = 0;
  
  [ud setInteger:idxNumber forKey:@"NextIndex"];
  
  return [NSString stringWithFormat:@"Image-%d", idxNumber];
}

//------------------------------------------------------------------------------
+ (NSArray *)partitionAndWriteImage:(CGImageRef)image path:(NSString *)path type:(NSString *)type {
  NSArray *screens = [NSScreen screens];
  NSMutableArray *result = [NSMutableArray array];
  NSString *writtenPath;
  
  if ([screens count] == 1) {
    writtenPath = [self exportImage:image path:path type:type quality:1.0];
    
    if (writtenPath)
      [result addObject:writtenPath];
  } else {
    NSEnumerator *e = [screens objectEnumerator];
    NSScreen *screen;
    NSRect desktop = [NSScreen desktopFrame];
    NSRect imageRect = NSMakeRect(NSMinX(desktop), NSMinY(desktop), CGImageGetWidth(image), CGImageGetHeight(image));
    NSString *baseName = [[path lastPathComponent] stringByDeletingPathExtension];
    NSString *baseDir = [path stringByDeletingLastPathComponent];
    int idxNumber = 0;
   
    while ((screen = [e nextObject])) {
      NSRect frame = [screen frame];
      
      // If the frame of this screen intersects with the image, partition off
      // the image, and save the file
      if (NSIntersectsRect(frame, imageRect)) {
        // The subimage bounds are (0,0) - (width, height)
        NSRect subImageRect = frame;
        subImageRect.origin.x -= NSMinX(desktop);
        subImageRect.origin.y -= NSMinY(desktop);
        CGImageRef subImage = CGImageCreateWithImageInRect(image, NSRectToCGRect(subImageRect));
        NSString *filePath = [baseDir stringByAppendingPathComponent:baseName];
        filePath = [filePath stringByAppendingFormat:@"-%d", idxNumber];
        
        writtenPath = [self exportImage:subImage path:filePath type:type quality:1.0];
        
        if (writtenPath)
          [result addObject:writtenPath];
        else
          MethodLog("Failed to write to %@", filePath);
        
        CGImageRelease(subImage);
      }
      
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
