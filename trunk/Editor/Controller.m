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
#import "Exporter.h"
#import "Preview.h"

static Controller *sController = nil;

static NSString *kOpenedDocumentsKey = @"opened";
static NSString *kInstalledScriptsKey = @"installed";

@interface Controller (PrivateMethods)
- (void)installScripts;
- (NSString *)viewerPath;
- (LSSharedFileListItemRef)viewerStartupItemRef;
@end

@implementation Controller
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Private ||
//------------------------------------------------------------------------------
- (void)installScripts {
  NSString *scriptsArchivePath = [[NSBundle mainBundle] pathForResource:@"Scripts" ofType:@"zip"];
  
  // If we don't have any scripts, just bail
  if (![[NSFileManager defaultManager] fileExistsAtPath:scriptsArchivePath])
    return;
  
  // Launch a task to unzip
  NSString *destinationPath = [Exporter scriptStorageDirectory];
  NSTask *unzipTask = [[NSTask alloc] init];
  [unzipTask setLaunchPath:@"/usr/bin/unzip"];
  NSArray *args = [NSArray arrayWithObjects:
                   @"-uq",
                   scriptsArchivePath,
                   nil];
  [unzipTask setArguments:args];
  [unzipTask setCurrentDirectoryPath:destinationPath];
  [unzipTask launch];
  [unzipTask waitUntilExit];
  
  [unzipTask release];
}

//------------------------------------------------------------------------------
- (NSString *)viewerPath {
  return [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"TopDrawViewer.app"];
}

//------------------------------------------------------------------------------
- (LSSharedFileListItemRef)viewerStartupItemRef {
  LSSharedFileListRef startupList = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
  NSURL *url = [NSURL fileURLWithPath:[self viewerPath]];
  
  // Make a snapshot
  NSArray *startupItems = (NSArray *)LSSharedFileListCopySnapshot(startupList, NULL);
  NSEnumerator *e = [startupItems objectEnumerator];
  id item;
  NSURL *searchURL;
  LSSharedFileListItemRef foundItem = NULL;
  while ((item = [e nextObject]) && !foundItem) {
    LSSharedFileListItemResolve((LSSharedFileListItemRef)item,
                                0, (CFURLRef *)&searchURL, NULL);
    
    if ([searchURL isEqual:url])
      foundItem = (LSSharedFileListItemRef)item;

    [searchURL release];
  }

  [startupItems release];
  
  if (startupList)
    CFRelease(startupList);
  
  return foundItem;
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Public ||
//------------------------------------------------------------------------------
+ (Controller *)sharedController {
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
#pragma mark || Actions ||
//------------------------------------------------------------------------------
- (IBAction)showDocumentation:(id)sender {
  NSString *helpFileName = @"TopDraw.html";
  
  if ([sender tag])
    helpFileName = @"TopDrawViewer.html";
  
  NSString *documentFolder = @"Documentation";
  NSString *resources = [[NSBundle mainBundle] resourcePath];
  NSString *documentFolderPath = [resources stringByAppendingPathComponent:documentFolder];
  NSString *documentPath = [documentFolderPath stringByAppendingPathComponent:helpFileName];

  [[NSWorkspace sharedWorkspace] openFile:documentPath];
}

//------------------------------------------------------------------------------
- (IBAction)launchViewer:(id)sender {
  [[NSWorkspace sharedWorkspace] launchApplication:[self viewerPath]];
}

//------------------------------------------------------------------------------
- (IBAction)launchViewerOnStartup:(id)sender {
  int state = [sender state];
  LSSharedFileListRef startupList = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
  NSURL *url = [NSURL fileURLWithPath:[self viewerPath]];
  
  // Add or remove
  if (state == NSOffState) {
    LSSharedFileListInsertItemURL(startupList, kLSSharedFileListItemLast, NULL, NULL, 
                                  (CFURLRef)url, NULL, NULL);
  } else {
    LSSharedFileListItemRef found = [self viewerStartupItemRef];
    LSSharedFileListItemRemove(startupList, found);
  }
  
  if (startupList)
    CFRelease(startupList);
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || NSObject ||
//------------------------------------------------------------------------------
- (void)awakeFromNib {
  sController = self;
  
  // Install our scripts if we're launching the first time
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  if (![ud boolForKey:kInstalledScriptsKey]) {
    [self installScripts];
    [ud setBool:YES forKey:kInstalledScriptsKey];
  }
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

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || NSUserInterfaceValidations ||
//------------------------------------------------------------------------------
- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)item {
  SEL action = [item action];
  BOOL result = YES;
  
  if (action == @selector(launchViewerOnStartup:)) {
    BOOL found = ([self viewerStartupItemRef] ? YES : NO);
    
    [(NSMenuItem *)item setState:found ? NSOnState : NSOffState];
  }
  
  return result;
}

@end
