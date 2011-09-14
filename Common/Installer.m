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
#import "Installer.h"

@implementation Installer

+ (NSScreen *)screenWithIDString:(NSString *)screenID {
  NSArray *screens = [NSScreen screens];
  for (NSScreen *screen in screens) {
    NSString *searchID = [Exporter idForScreen:screen];
    if ([searchID isEqualToString:screenID]) {
      return screen;
    }
  }
  
  return nil;
}

//------------------------------------------------------------------------------
+ (BOOL)installDesktopImagesFromScreenImageDict:(NSDictionary *)screenImageDict {
  // Key: screenID; Value: path
	for (NSString *screenID in screenImageDict) {
    NSURL *url = [NSURL fileURLWithPath:[screenImageDict objectForKey:screenID]];
    NSError *error = nil;
    NSScreen *screen = [self screenWithIDString:screenID];
    [[NSWorkspace sharedWorkspace] setDesktopImageURL:url forScreen:screen options:nil error:&error];
  }
  
  return YES;
}

@end
