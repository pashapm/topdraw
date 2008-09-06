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

// Exporting paths and names
// Exporting and partitioning images

#import <Foundation/Foundation.h>

@interface Exporter : NSObject

+ (NSString *)imageStorageDirectory;
+ (NSString *)scriptStorageDirectory;
+ (NSString *)nextBaseName;

// Breaks up |image| (if necessary, for the screens) and saves the resulting images to the 
// application support directory.  Returns an array of NSStrings that are the
// paths to the files written out.
+ (NSArray *)partitionAndWriteImage:(CGImageRef)image path:(NSString *)path type:(NSString *)type;

// Export |image| to |path| with UTI type and quality.  The |type| should be one of: jpeg, png, or tiff
// and quality is between 0 and 1.  If |path| is lacking an extension, the type will be used.
// Return the name of the file written, or nil if there was an error.
+ (NSString *)exportImage:(CGImageRef)image path:(NSString *)path type:(NSString *)type quality:(CGFloat)quality;

@end
