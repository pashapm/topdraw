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

#import "DocumentController.h"
#import "Exporter.h"

@implementation DocumentController

NSString *kLastDocumentStorageFolder = @"lastFolder";

+ (NSString *)recommendedStorageFolder {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSString *folder = [ud stringForKey:kLastDocumentStorageFolder];
  BOOL isDir = NO;
  
  if (!([[NSFileManager defaultManager] fileExistsAtPath:folder isDirectory:&isDir] && isDir))
    folder = [Exporter scriptDirectory];

  return folder;
}

- (NSInteger)runModalOpenPanel:(NSOpenPanel *)openPanel forTypes:(NSArray *)types {
  [openPanel setDirectory:[DocumentController recommendedStorageFolder]];
  
  return [super runModalOpenPanel:openPanel forTypes:types];
}

- (void)addDocument:(NSDocument *)document {
  // Store the folder where we just loaded this
  NSString *folder = [[[document fileURL] path] stringByDeletingLastPathComponent];
  BOOL isDir = NO;
  
  if ([[NSFileManager defaultManager] fileExistsAtPath:folder isDirectory:&isDir] && isDir)
    [[NSUserDefaults standardUserDefaults] setObject:folder forKey:kLastDocumentStorageFolder];
  
  [super addDocument:document];
}

@end
