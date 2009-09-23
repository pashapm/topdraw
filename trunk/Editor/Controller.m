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
#import "Renderer.h"

static Controller *sController = nil;

static NSString *kInstalledScriptsKey = @"installed";
static NSString *kCopiedRendererVersionKey = @"copiedRenderVersion";
static NSString *kShowAtLaunchKey = @"showAtLaunch";

static NSString *kScreenSaverName = @"Top Draw.saver";

@interface Controller (PrivateMethods)
- (void)installScripts;
- (void)installRenderer;
- (NSString *)viewerPath;
- (LSSharedFileListItemRef)viewerStartupItemRef;
@end

@implementation Controller
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Private ||
//------------------------------------------------------------------------------
+ (void)initialize {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSDictionary *factoryValues = 
  [NSDictionary dictionaryWithObjectsAndKeys:
   [NSNumber numberWithBool:YES], kShowAtLaunchKey,
   nil];
  [defaults registerDefaults:factoryValues];
}

//------------------------------------------------------------------------------
- (void)installScripts {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

  if ([ud boolForKey:kInstalledScriptsKey])
    return;
  
  NSString *scriptsArchivePath = [[NSBundle mainBundle] pathForResource:@"Scripts" ofType:@"zip"];
  
  // If we don't have any scripts, just bail
  if (![[NSFileManager defaultManager] fileExistsAtPath:scriptsArchivePath]) {
    NSLog(@"Missing scripts");
    return;
  }
  
  // Launch a task to unzip
  NSString *destinationPath = [Exporter scriptDirectory];
  NSTask *unzipTask = [[NSTask alloc] init];
  [unzipTask setLaunchPath:@"/usr/bin/unzip"];
  NSArray *args = [NSArray arrayWithObjects:
                   @"-oq",
                   scriptsArchivePath,
                   nil];
  [unzipTask setArguments:args];
  [unzipTask setCurrentDirectoryPath:destinationPath];
  [unzipTask launch];
  [unzipTask waitUntilExit];
  [unzipTask release];

  [ud setBool:YES forKey:kInstalledScriptsKey];
}

//------------------------------------------------------------------------------
- (void)installRenderer {
  NSString *rendererArchivePath = [[NSBundle mainBundle] pathForResource:@"TopDrawRenderer" ofType:@"zip"];
  
  if (![[NSFileManager defaultManager] fileExistsAtPath:rendererArchivePath]) {
    NSLog(@"Missing renderer archive");
    return;
  }

  // Check and see if we've got a version that matches ours
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSDictionary *rendererInfo = [[NSBundle bundleForClass:[self class]] infoDictionary];
  NSString *rendererVersion = [rendererInfo objectForKey:@"CFBundleShortVersionString"];
  NSString *rendererDir = [Exporter rendererDirectory];

  BOOL copyToAppSupport = YES;

  // For debug builds, always install
#ifndef DEBUG
  NSString *rendererPath = [rendererDir stringByAppendingPathComponent:[Renderer rendererName]];
  if ([[NSFileManager defaultManager] isExecutableFileAtPath:rendererPath]) {
    NSString *copiedVersion = [ud objectForKey:kCopiedRendererVersionKey];
  
    if ([rendererVersion isEqualToString:copiedVersion])
      copyToAppSupport = NO;
  }
#endif
  
  if (!copyToAppSupport)
    return;
  
  // Launch a task to unzip
  NSTask *unzipTask = [[NSTask alloc] init];
  [unzipTask setLaunchPath:@"/usr/bin/unzip"];
  NSArray *args = [NSArray arrayWithObjects:
                   @"-oq",
                   rendererArchivePath,
                   nil];
  [unzipTask setArguments:args];
  [unzipTask setCurrentDirectoryPath:rendererDir];
  [unzipTask launch];
  [unzipTask waitUntilExit];
  [unzipTask release];
  
  [ud setObject:rendererVersion forKey:kCopiedRendererVersionKey];
}

//------------------------------------------------------------------------------
- (NSString *)viewerPath {
  return [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"Top Draw Viewer.app"];
}

//------------------------------------------------------------------------------
- (LSSharedFileListItemRef)viewerStartupItemRef {
  LSSharedFileListRef startupList = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
  NSURL *url = [NSURL fileURLWithPath:[self viewerPath]];
  
  // Make a snapshot
  NSArray *startupItems = (NSArray *)LSSharedFileListCopySnapshot(startupList, NULL);
  NSEnumerator *e = [startupItems objectEnumerator];
  id item;
  NSURL *searchURL = NULL;
  LSSharedFileListItemRef foundItem = NULL;
  while ((item = [e nextObject]) && !foundItem) {
    OSStatus status = LSSharedFileListItemResolve((LSSharedFileListItemRef)item,
                                                  0, (CFURLRef *)&searchURL, NULL);
    
    if (status == noErr) {
      if ([searchURL isEqual:url])
        foundItem = (LSSharedFileListItemRef)item;
      
      [searchURL release];
    }
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
- (IBAction)installScreenSaver:(id)sender {
  NSString *destDir = [@"~/Library/Screen Savers" stringByStandardizingPath];
  NSString *destPath = [destDir stringByAppendingPathComponent:kScreenSaverName];
  NSString *srcPath = [[NSBundle mainBundle] pathForAuxiliaryExecutable:kScreenSaverName];
  
  // Setup a symbolic link.  Aliases do not seem to work.
  [[NSFileManager defaultManager] createSymbolicLinkAtPath:destPath pathContent:srcPath];
  
  // Now open up the screen savers panel
  NSString *path = @"/System/Library/PreferencePanes/ScreenSaver.prefPane";
  
  // Name changed in Snowy -- perhaps there's a more generic way to reference this?
  if (![[NSFileManager defaultManager] fileExistsAtPath:path])
    path = @"/System/Library/PreferencePanes/DesktopScreenEffectsPref.prefPane";
    
  [[NSWorkspace sharedWorkspace] openFile:path];
}

//------------------------------------------------------------------------------
- (IBAction)about:(id)sender {
  [NSApp activateIgnoringOtherApps:YES];
  
  NSString *htmlStr = @"<html><a href='http://code.google.com/p/topdraw'>http://code.google.com/p/topdraw</a></html>";
  NSData *htmlData = [htmlStr dataUsingEncoding:NSUTF8StringEncoding];
  NSAttributedString *str = [[NSAttributedString alloc] initWithHTML:htmlData documentAttributes:nil];
  NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                           str, @"Credits",
                           nil];
  [str release];
  [NSApp orderFrontStandardAboutPanelWithOptions:options];
}

//------------------------------------------------------------------------------
- (IBAction)getStartedWithViewer:(id)sender {
  [self launchViewer:sender];
  [NSApp terminate:sender];
}

//------------------------------------------------------------------------------
- (IBAction)getStartedWithEditor:(id)sender {
  [preview_ showPreview];
  [[NSDocumentController sharedDocumentController] newDocument:sender];
  [welcomeWindow_ close];
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || NSObject ||
//------------------------------------------------------------------------------
- (void)awakeFromNib {
  sController = self;

  // Install our scripts
  [self installScripts];
  
  // Always check to see if we've got the latest renderer
  [self installRenderer];
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || NSApplicationDelegate ||
//------------------------------------------------------------------------------
- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)app {
  return ![[NSUserDefaults standardUserDefaults] boolForKey:kShowAtLaunchKey];
}

//------------------------------------------------------------------------------
- (void)applicationDidFinishLaunching:(NSNotification *)note {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  if ([ud boolForKey:kShowAtLaunchKey]) {
    [welcomeWindow_ center];
    [welcomeWindow_ orderFront:self];
    return;
  }

  [preview_ showPreview];
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
