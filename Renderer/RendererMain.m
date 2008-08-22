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

// The command line renderer

#import <unistd.h>

#import "Compositor.h"
#import "Exporter.h"

typedef struct {
  NSString *sourcePath;
  NSString *destPath;
  NSString *type;
  float quality;
  BOOL isValid;
  BOOL canTerminate;
  BOOL shouldSplit;
  unsigned long seed;
  NSSize size;
} Options;

//------------------------------------------------------------------------------
static void Log(NSString *fmt, ...) {
  va_list args;
  va_start(args, fmt);
  NSString *logStr = [[NSString alloc] initWithFormat:fmt arguments:args];
  va_end(args);
  fprintf(stdout, "%.3f %s\n", CFAbsoluteTimeGetCurrent(), [logStr UTF8String]);
  [logStr release];
}

//------------------------------------------------------------------------------
static void Logging(const char *msg, void *context) {
  Log(@"Log:%s", msg);
}

//------------------------------------------------------------------------------
static NSString *Preprocess(Options *options, NSString *path) {
  NSString *result = nil;

  if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:nil];
    if ([data length]) {
      result = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
      options->isValid = YES;
    }
  }
  
  return result;
}

//------------------------------------------------------------------------------
static void Process(Options *options) {
  NSString *source = Preprocess(options, options->sourcePath);
  Compositor *c = [[Compositor alloc] initWithSource:source];
  NSString *errorStr = nil;
  [c setLoggingCallback:Logging context:options];
  [c setMaximumSize:options->size];

  @try {
    errorStr = [c evaluateWithSeed:options->seed];
  }
  
  @catch (NSException *e) {
    errorStr = [NSString stringWithFormat:@"Exception: %@", e];
  }
  
  if (!errorStr) {
    CGImageRef image = [c image];
    
    if (options->shouldSplit) {
      NSArray *imagePaths = [Exporter partitionAndWriteImage:image path:options->destPath type:options->type];
      for (int i = 0; i < [imagePaths count]; ++i)
        Log(@"Output: %@", [imagePaths objectAtIndex:i]);
      
    } else {
      NSString *outputPath = [Exporter exportImage:image path:options->destPath type:options->type quality:options->quality];
      
      if ([outputPath length])
        Log(@"Output: %@", outputPath);
      else
        Log(@"Error: Unable to write: %@", options->destPath);
    }
    
    Log(@"Seed: %d", [c randomSeed]);
  } else {
    Log(@"Error: %s", [errorStr UTF8String]);
    
    // Strangely, if we return too quickly from the task, not all of the output
    // seems to go out.  If we have an error, sleep for a small amount of time.
    usleep(1000 * 100);  // 0.1 sec
  }
  
  // Cleanup
  [c release];
  
  options->canTerminate = YES;
}

//------------------------------------------------------------------------------
static void Usage(int argc, const char *argv[], int errorCode) {
  NSString *path = [NSString stringWithUTF8String:argv[0]];
  const char *exe = [[path lastPathComponent] fileSystemRepresentation];
  fprintf(stderr, "Render a Top Draw Document into an output image\n"); 
  fprintf(stderr, "Usage: %s [-r randomSeed][-t type][-q quality][-s][-o output-image][-m WxH] source-file\n", exe);
  fprintf(stderr, "\tsource-file: a Top Draw Document\n");
  fprintf(stderr, "\t-r: Specify the random seed to use\n");
  fprintf(stderr, "\t-f: Specify the type (default: jpeg; allowed: jpeg, png, tiff)\n");
  fprintf(stderr, "\t-q: Specify the quality (default: 1.0; allowed: (0, 1))\n");
  fprintf(stderr, "\t-s: Split the image based on the number of screens.  Output filename will be sequentially numbered starting with 0.\n");
  fprintf(stderr, "\t-o: Output filename (default: source-file base + type)\n");
  fprintf(stderr, "\t-m: Specify maximum width and height (default: actual desktop)\n");
  fprintf(stderr, "\t-h: Usage\n");
  fprintf(stderr, "\t-?: Usage\n");
  exit(errorCode);
}

//------------------------------------------------------------------------------
static void SetupOptions(int argc, const char *argv[], Options *options) {
  extern char *optarg;
  extern int optind;
  int ch;
  NSSet *allowedTypes = [NSSet setWithObjects:@"png", @"tiff", @"jpeg", nil];
  NSString *type;
  
  // Initialize
  bzero(options, sizeof(Options));
  options->seed = 42;
  options->quality = 1.0;
  options->type = @"jpeg";
  options->shouldSplit = NO;

  while ((ch = getopt(argc, (char * const *)argv, "m:sq:t:r:o:h?")) != -1) {
    switch (ch) {
      case 's':
        options->shouldSplit = YES;
        break;
        
      case 'q':
        options->quality = strtof(optarg, nil);
        if (options->quality < 0)
          options->quality = 0;
        else if (options->quality > 1)
          options->quality = 1;
        break;
        
      case 't':
        type = [[[NSString stringWithUTF8String:optarg] lowercaseString] 
                stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (![allowedTypes containsObject:type]) {
          NSLog(@"Unallowed type: '%@' -- using tiff", type);
          type = @"tiff";
        }
        
        options->type = [type copy];
        break;
        
      case 'r':
        options->seed = strtoul(optarg, NULL, 10);
        break;
        
      case 'o': {
        NSString *dest = [NSString stringWithUTF8String:optarg];
        NSCharacterSet *ws = [NSCharacterSet whitespaceCharacterSet];
        options->destPath = [[dest stringByTrimmingCharactersInSet:ws] retain];
        break;
      }
        
      case 'm': {
        char *ptr = NULL;
        NSUInteger width = 0, height = 0;
        width = strtoul(optarg, &ptr, 10);
        
        if (ptr) {
          while (!isdigit(*ptr) && *ptr)
            ++ptr;
          
          height = strtoul(ptr, NULL, 10);
        }
        
        if (width > 0 && height > 0)
          options->size = NSMakeSize(width, height);
        
        break;
      }
        
      case 'h':
      case '?':
      default:
        Usage(argc, argv, 0);
        break;
    }
  }
  
  if ((argc - optind) == 1) {
    options->sourcePath = [[NSString stringWithUTF8String:argv[optind]] retain];
    options->isValid = [[NSFileManager defaultManager] fileExistsAtPath:options->sourcePath];
    
    if (!options->destPath) {
      NSString *base = [options->sourcePath stringByDeletingPathExtension];
      options->destPath = [[base stringByAppendingPathExtension:options->type] retain];
    }
  }
  
  if (!options->isValid) {
    fprintf(stderr, "No valid file specified\n");
    Usage(argc, argv, 1);
  }
}
  
//------------------------------------------------------------------------------
int main(int argc, const char *argv[]) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  Options options;
  SetupOptions(argc, argv, &options);

  NSRunLoop *rl = [NSRunLoop currentRunLoop];
  BOOL isProcessing = NO;
  
  while (!options.canTerminate) {
    [rl runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    
    if (!isProcessing) {
      Process(&options);
      isProcessing = YES;
    }
  }
  
  [pool release];
  
  return 0;
}

