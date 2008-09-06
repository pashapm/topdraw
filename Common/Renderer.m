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

#import "Renderer.h"

NSString *RendererDidFinish = @"RendererDidFinish";

NSString *RendererOutputKey = @"RendererOutputKey";
NSString *RendererErrorKey = @"RendererErrorKey";
NSString *RendererErrorLineKey = @"RendererErrorLineKey";
NSString *RendererLogKey = @"RendererLogKey";
NSString *RendererTimeKey = @"RendererTimeKey";
NSString *RendererSeedKey = @"RendererSeedKey";

static NSString *kRendererName = @"TopDrawRenderer";

@interface Renderer(PrivateMethods)
- (void)renderData:(NSNotification *)note;
- (void)renderFinished:(NSNotification *)note;
- (NSString *)rendererExecutablePath;
@end

@implementation Renderer
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Private ||
//------------------------------------------------------------------------------
- (void)renderFinished:(NSNotification *)note {
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center removeObserver:self];
  
  [task_ terminate];
  endTime_ = CFAbsoluteTimeGetCurrent();
  
  // If there was any pending data, add it here
  NSData *data;
  while ((data = [[[task_ standardOutput] fileHandleForReading] availableData]) && [data length]) {
    [taskResponse_ appendData:data];
  }

  // There may be multiple Log and a single Error message from the renderer.
  NSString *errorStr = @"";
  NSMutableString *logStr = [NSMutableString string];
  int errorLineNumber = 0;
  NSMutableString *outputPath = [NSMutableString string];
  NSString *outputSeparator = @"";
  
  if ([taskResponse_ length]) {
    NSString *renderOutput = [[NSString alloc] initWithData:taskResponse_ encoding:NSUTF8StringEncoding];    
    NSScanner *scanner = [NSScanner scannerWithString:renderOutput];
    NSCharacterSet *ws = [NSCharacterSet characterSetWithCharactersInString:@" \n\r\t"];
    NSCharacterSet *alphaNum = [NSCharacterSet alphanumericCharacterSet];
    NSString *temp = nil;

    [scanner setCharactersToBeSkipped:ws];
    
    NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
    [dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
    [dateFormatter setDateStyle:NSDateFormatterNoStyle];
    [dateFormatter setDateFormat:@"hh:mm:ss.SSS"];
    
    while (![scanner isAtEnd]) {
      BOOL foundValidInput = NO;
      double seconds;
      
      // All entries should be in the form: <time> <type>:msg
      [scanner scanDouble:&seconds];
      [scanner scanCharactersFromSet:ws intoString:nil];
      NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate:seconds];
      NSString *timeStr = [dateFormatter stringFromDate:date];

      if ([scanner scanString:@"Error:" intoString:nil]) {
        [scanner scanInt:&errorLineNumber];
        [scanner scanUpToCharactersFromSet:alphaNum intoString:nil];
        int currentScanLocation = [scanner scanLocation];
        
        if (![scanner scanUpToString:@"\n" intoString:&temp])
          temp = [renderOutput substringFromIndex:currentScanLocation];
        
        errorStr = [NSString stringWithFormat:@"%@: %@", 
                    timeStr, [temp stringByTrimmingCharactersInSet:ws]];
        foundValidInput = YES;
        taskResponseContainedErrors_ = YES;
      }
      
      if ([scanner scanString:@"Log:" intoString:nil]) {
        [scanner scanUpToString:@"\n" intoString:&temp];
        temp = [temp stringByTrimmingCharactersInSet:ws];
        [logStr appendFormat:@"%@: %@\n", timeStr, temp];
        foundValidInput = YES;
      }
      
      if ([scanner scanString:@"Seed:" intoString:nil]) {
        long long seed;
        [scanner scanLongLong:&seed];
        seed_ = (unsigned long)seed;
        [scanner scanUpToString:@"\n" intoString:nil];
        foundValidInput = YES;
      }
      
      if ([scanner scanString:@"Output:" intoString:nil]) {
        NSString *path;
        [scanner scanUpToString:@"\n" intoString:&path];
        [outputPath appendFormat:@"%@%@", outputSeparator, path];
        outputSeparator = @",";
        foundValidInput = YES;
      }
      
      if ([scanner scanString:@"Preamble:" intoString:nil]) {
        [scanner scanUpToString:@"\n" intoString:&temp];
        foundValidInput = YES;
      }
      
      if (!foundValidInput) {
        [logStr appendFormat:@"Unknown: %@\n", renderOutput];
        break;
      }
    }
    
    [renderOutput release];
  }
  
  // Create a notification with the data
  NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                            outputPath, RendererOutputKey,
                            errorStr, RendererErrorKey,
                            [NSNumber numberWithInt:errorLineNumber], RendererErrorLineKey,
                            logStr, RendererLogKey,
                            [NSNumber numberWithDouble:[self elapsedTime]], RendererTimeKey,
                            [NSNumber numberWithUnsignedInt:seed_], RendererSeedKey,
                            nil];
  
  if (!cancelNotifications_)
    [center postNotificationName:RendererDidFinish object:self userInfo:userInfo];
  
  // Cleanup
  [outputPath_ release];
  outputPath_ = nil;
  [taskResponse_ release];
  taskResponse_ = nil;
  [task_ release];
  task_ = nil;
}

//------------------------------------------------------------------------------
- (void)renderData:(NSNotification *)note {
  NSData *data = [[note userInfo] objectForKey:NSFileHandleNotificationDataItem];
  
  if ([data length])
    [taskResponse_ appendData:data];
  
  // Continue reading
  [[note object] readInBackgroundAndNotify];  
}

//------------------------------------------------------------------------------
- (NSString *)rendererExecutablePath {
  // Depending on the packaging, the renderer might be in the executable portion
  // of the bundle, or it might be at the top level
  NSString *path = [[NSBundle mainBundle] pathForAuxiliaryExecutable:kRendererName];
  if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
    path = [[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
      NSLog(@"Unable to locate: %@", kRendererName);
      path = nil;
    }
  }
  
  return path;
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Public ||
//------------------------------------------------------------------------------
+ (unsigned long)randomSeedFromDevice {
  int fd = open("/dev/random", O_RDONLY);
  unsigned int buffer = -1;
  
  if (fd != -1) {
    read(fd, &buffer, sizeof(buffer));
    close(fd);
  }
  
  return buffer;
}

//------------------------------------------------------------------------------
+ (NSArray *)allowedTypes {
  return [NSArray arrayWithObjects:@"jpeg", @"tiff", @"png", nil];
}

//------------------------------------------------------------------------------
- (id)initWithReference:(void *)reference {
  if ((self = [super init])) {
    reference_ = reference;
    type_ = @"tiff";
  }
  
  return self;
}

//------------------------------------------------------------------------------
- (void)dealloc {
  [type_ release];
  [self cancelRender];
  [source_ release];
  [destination_ release];
  [super dealloc];
}

//------------------------------------------------------------------------------
- (void)setSource:(NSString *)source name:(NSString *)name seed:(unsigned long)seed {
  if (source_ != source) {
    [source_ release];
    source_ = [source copy];
    [name_ release];
    name_ = [name copy];
  }
  
  seed_ = seed;
}

//------------------------------------------------------------------------------
- (void)setMaximumSize:(NSSize)size {
  size_ = size;
}

//------------------------------------------------------------------------------
- (void)setType:(NSString *)type {
  if (type != type_) {
    [type_ release];
    type_ = [type copy];
  }
}

//------------------------------------------------------------------------------
- (void)setShouldSplitImages:(BOOL)shouldSplit {
  shouldSplit_ = shouldSplit;
}

//------------------------------------------------------------------------------
- (void)setDestination:(NSString *)path {
  if (path != destination_) {
    [destination_ autorelease];
    destination_ = [path copy];
  }
}

//------------------------------------------------------------------------------
- (void)renderInBackgroundAndNotify {
  if ([self isRendering]) {
    MethodLog("Currently rendering...");
    return;
  }
  
  startTime_ = CFAbsoluteTimeGetCurrent();
  endTime_ = 0;
  [outputPath_ release];
  outputPath_ = nil;

  // Write the data to a temporary file using the document identifier
  NSString *sourcePath = [NSString stringWithFormat:@"/tmp/%x.tds", reference_];
  
  if (!destination_)
    outputPath_ = [[NSString stringWithFormat:@"/tmp/%x.%@", reference_, type_] retain];
  else
    outputPath_ = [destination_ retain];
  
  NSData *sourceData = [source_ dataUsingEncoding:NSUTF8StringEncoding];
  
  if (![sourceData writeToFile:sourcePath atomically:NO]) {
    NSLog(@"Unable to write to %@", sourcePath);
    return;
  }
  
  // Run the script and wait for a notification of its success
  CGFloat quality = 1.0;
  NSMutableArray *arguments = [NSMutableArray array];
  
  [arguments addObject:[NSString stringWithFormat:@"-r %d", seed_]];
  [arguments addObject:[NSString stringWithFormat:@"-o %@", outputPath_]];
  [arguments addObject:[NSString stringWithFormat:@"-t %@", type_]];
  [arguments addObject:[NSString stringWithFormat:@"-q %f", quality]];
  
  if ([name_ length])
    [arguments addObject:[NSString stringWithFormat:@"-n \"%@\"", name_]];
  
  if (size_.width > 0 && size_.height > 0) {
    NSUInteger width = floor(size_.width);
    NSUInteger height = floor(size_.height);
    [arguments addObject:[NSString stringWithFormat:@"-m %dx%d", width, height]];
  }
  
  if (shouldSplit_)
    [arguments addObject:@"-s"];

  [arguments addObject:sourcePath];
  
  NSString *executablePath = [self rendererExecutablePath];
  task_ = [[NSTask alloc] init];
  [task_ setLaunchPath:executablePath];
  [task_ setArguments:arguments];

  [task_ setStandardOutput:[NSPipe pipe]];
  [task_ setStandardError:[task_ standardOutput]];
  
  taskResponse_ = [[NSMutableData alloc] init];
  taskResponseContainedErrors_ = NO;
  
  // Observe the data availablity and task finishing
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center addObserver:self selector:@selector(renderData:) 
                 name:NSFileHandleReadCompletionNotification 
               object:[[task_ standardOutput] fileHandleForReading]];
  [center addObserver:self selector:@selector(renderFinished:)
                 name:NSTaskDidTerminateNotification
               object:task_];
  [[[task_ standardOutput] fileHandleForReading] readInBackgroundAndNotify];
  [task_ launch];
}

//------------------------------------------------------------------------------
- (BOOL)isRendering {
  return task_ ? YES : NO;
}

//------------------------------------------------------------------------------
- (void)cancelRender {
  [self renderFinished:nil];
}

//------------------------------------------------------------------------------
- (BOOL)render {
  NSRunLoop *loop = [NSRunLoop currentRunLoop];
  
  cancelNotifications_ = YES;
  [self renderInBackgroundAndNotify];
  
  while(task_) {
    [loop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
  }
  
  cancelNotifications_ = NO;
  
  return taskResponseContainedErrors_;
}

//------------------------------------------------------------------------------
- (NSTimeInterval)elapsedTime {
  if (endTime_)
    return endTime_ - startTime_;
  
  return CFAbsoluteTimeGetCurrent() - startTime_;
}

@end
