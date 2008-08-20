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

#import "Controller.h"
#import "DrawingDocument.h"
#import "Preview.h"

static Controller *sController = nil;

static NSString *kOpenedDocumentsKey = @"opened";

@implementation Controller
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Public ||
//------------------------------------------------------------------------------
+ (Controller *)sharedController {
  MethodLog();
  return sController;
}

//------------------------------------------------------------------------------
- (Preview *)preview {
  return preview_;
}

//------------------------------------------------------------------------------
- (Logging *)logging {
  return logging_;
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || NSObject ||
//------------------------------------------------------------------------------
- (void)awakeFromNib {
  sController = self;
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || NSApplicationDelegate ||
//------------------------------------------------------------------------------
- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)app {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSArray *openedDocuments = [ud objectForKey:kOpenedDocumentsKey];
  
  // Validate the documents
  BOOL hasDocument = NO;
  int i, count = [openedDocuments count];

  for (i = 0; (i < count) && (!hasDocument); ++i) {
    NSString *path = [openedDocuments objectAtIndex:i];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path])
      hasDocument = YES;
  }
  
  return !hasDocument;
}

//------------------------------------------------------------------------------
- (void)applicationDidFinishLaunching:(NSNotification *)note {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSArray *openedDocuments = [ud objectForKey:kOpenedDocumentsKey];
  int i, count = [openedDocuments count];
  NSDocumentController *dc = [NSDocumentController sharedDocumentController];
  NSURL *url;
  NSError *error;
  
  for (i = 0; i < count; ++i) {
    // Ensure that it exists
    NSString *path = [openedDocuments objectAtIndex:i];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
      continue;
    
    url = [NSURL fileURLWithPath:path];
    error = nil;
    [dc openDocumentWithContentsOfURL:url display:YES error:&error];
    if (error)
      NSLog(@"Error: %@", error);
  }
  
  // Always show the preview
  [preview_ showPreview];
}

//------------------------------------------------------------------------------
- (void)applicationWillTerminate:(NSNotification *)note {
  NSArray *documents = [[NSDocumentController sharedDocumentController] documents];
  int i, count = [documents count];
  NSMutableArray *paths = [NSMutableArray array];
  
  for (i = 0; i < count; ++i) {
    NSURL *url = [[documents objectAtIndex:i] fileURL];
    if (url) {
      NSString *path = [url path];
      [paths addObject:path];
    }
  }
  
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  [ud setObject:paths forKey:kOpenedDocumentsKey];
}

@end
