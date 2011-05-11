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

#import "Installer.h"

@implementation Installer

+ (NSDictionary *)dictionaryForImageAtPath:(NSString *)path forScreenID:(NSString *)screenID 
																baseDictionary:(NSDictionary *)baseDict {
	NSMutableDictionary *screenDict = [[baseDict mutableCopy] autorelease];
	
	if (path)
		[screenDict setObject:path forKey:@"ImageFilePath"];
	else
		NSLog(@"Installer: path for screen %@ is NULL", screenID);
	
	[screenDict setObject:@"Never" forKey:@"Change"];
	
	// Remove these as they seem to confuse slamming the image file path
	[screenDict removeObjectForKey:@"NewChangePath"];
	[screenDict removeObjectForKey:@"NewChooseFolderPath"];
	[screenDict removeObjectForKey:@"NewImageFilePath"];
	[screenDict removeObjectForKey:@"ImageFileAlias"];
	[screenDict removeObjectForKey:@"LastName"];
	[screenDict removeObjectForKey:@"ChooseFolderPath"];
	[screenDict removeObjectForKey:@"ChangePath"];
	[screenDict removeObjectForKey:@"CollectionString"];
	
	return screenDict;
}

//------------------------------------------------------------------------------
+ (BOOL)installDesktopImagesFromScreenImageDict:(NSDictionary *)screenImageDict {
  // com.apple.desktop.plist: Background = {key for dict is screen number
  // Change = Never;  Turn off random images
  // ImageFilePath = <path>;
  // ImageFileAlias = <???>; probably NSData of an Alias handle, but we'll kill it
  // post notification name "com.apple.desktop" with object "BackgroundChanged"
  // to make desktop notice
  // The name of the path in |paths| corresponds to the screen number
  CFStringRef appID = CFSTR("com.apple.desktop");
  NSDictionary *origBackgroundDict = (NSDictionary *)CFPreferencesCopyAppValue(CFSTR("Background"), appID);
  NSMutableDictionary *backgroundDict = [origBackgroundDict mutableCopy];
	NSArray *screenImageKeys = [screenImageDict allKeys];
	NSMutableSet *appliedScreenIDs = [NSMutableSet set];

	// Install the known images on the known screens.
	for (NSString *screenID in screenImageKeys) {
    NSDictionary *origScreenDict = [backgroundDict objectForKey:screenID];
    
    // For some, the key of the screen is not a number but the word "default"
    if (!origScreenDict)
      origScreenDict = [backgroundDict objectForKey:@"default"];
		
		NSString *path = [screenImageDict objectForKey:screenID];
		NSDictionary *screenDict = [self dictionaryForImageAtPath:path forScreenID:screenID
																							 baseDictionary:origScreenDict];
    if (screenDict) {
      [backgroundDict setObject:screenDict forKey:screenID];
			[appliedScreenIDs addObject:screenID];
		}
  }
	
	// If there are other screen definitions in the background dict, slam them with the first image.
	NSArray *backgroundScreenKeys = [backgroundDict allKeys];
	NSString *path = [screenImageDict objectForKey:[screenImageKeys objectAtIndex:0]];
	for (NSString *screenID in backgroundScreenKeys) {
		// Skip anything we've already applied.
		if ([appliedScreenIDs containsObject:screenID]) {
			continue;
		}

		NSDictionary *origScreenDict = [backgroundDict objectForKey:screenID];
		NSDictionary *screenDict = [self dictionaryForImageAtPath:path forScreenID:screenID
																							 baseDictionary:origScreenDict];
    if (screenDict) {
      [backgroundDict setObject:screenDict forKey:screenID];
		}			
	}

  // Store, sync, and cleanup
  CFPreferencesSetAppValue(CFSTR("Background"), (CFPropertyListRef)backgroundDict, appID);
  CFPreferencesAppSynchronize(appID);
  [backgroundDict release];
  [origBackgroundDict release];
  
  // Notify the dock of the change
  [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.apple.desktop" object:@"BackgroundChanged"];

  return YES;
}

@end
