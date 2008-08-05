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

#import "DrawingDocument.h"
#import "Logging.h"

@implementation Logging
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Private ||
//------------------------------------------------------------------------------
- (void)addLogMsg:(NSString *)msg attributes:(NSDictionary *)attrs {
  NSTextStorage *storage = [logText_ textStorage];
  NSString *wrapped = [NSString stringWithFormat:@"%@\n", msg];
  NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:wrapped attributes:attrs];
  
  [logText_ setEditable:YES];
  [storage beginEditing];
  [storage appendAttributedString:attrStr];
  [storage endEditing];
  [attrStr release];
  [logText_ setEditable:NO];
  
  unsigned int len = [storage length];
  
  if (len > 0)
    [logText_ scrollRangeToVisible:NSMakeRange(len - 1, 1)];
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Actions ||
//------------------------------------------------------------------------------
- (IBAction)clearLog:(id)sender {
  [logText_ setEditable:YES];
  [logText_ setString:@""];
  [logText_ setEditable:NO];
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Public ||
//------------------------------------------------------------------------------
- (void)showLogging {
  [window_ orderFront:nil];
}

//------------------------------------------------------------------------------
- (void)hideLogging {
  [window_ orderOut:nil];
}

//------------------------------------------------------------------------------
- (void)showHideToggleLogging:(id)sender {
  if ([self isVisible])
    [self hideLogging];
  else
    [self showLogging];
}

//------------------------------------------------------------------------------
- (BOOL)isVisible {
  return [window_ isVisible];
}

//------------------------------------------------------------------------------
- (void)setIsVisible:(BOOL)visible {
  if (! visible)
    [self hideLogging];
  else
    [self showLogging];
}

//------------------------------------------------------------------------------
- (void)addLogMsg:(NSString *)msg {
  [self addLogMsg:msg attributes:nil];
}

//------------------------------------------------------------------------------
- (void)addErrorMsg:(NSString *)msg {
  NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
                         [DrawingDocument errorHighlightColor], NSBackgroundColorAttributeName,
                         nil];
  [self addLogMsg:msg attributes:attrs];
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || NSWindowDelegate ||
//------------------------------------------------------------------------------
- (NSRect)windowWillUseStandardFrame:(NSWindow *)window defaultFrame:(NSRect)frame {

  // TODO: sensible resizing
  return frame;
}

@end
