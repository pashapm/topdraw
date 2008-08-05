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

// An NSTextView subclass that provides syntax coloring, comment coloring, and
// automatic indention

#import <Cocoa/Cocoa.h>

@interface ColorizingTextView : NSTextView {
 @protected
  NSMutableSet *reserved_;            // Reserved words (STRONG)
  NSMutableSet *userDefined_;         // User defined words (STRONG)
  NSString *blockCommentStart_;       // Starting string for block comment (STRONG)
  NSString *blockCommentEnd_;         // Ending string for block comment (STRONG)
  NSString *lineComment_;             // Prefix for line comment (STRONG)
  NSColor *reservedColor_;            // Color for reserved (STRONG)
  NSColor *userDefinedColor_;         // Color for user defined (STRONG)
  NSColor *commentColor_;             // Color for comment (STRONG)
  BOOL isColoring_;                   // YES, if coloring
  NSRange lastRange_;                 // The last range colorized
  NSRange invalidRange_;              // Invalidated by the layout mgr
  NSMutableIndexSet *modifiedRange_;  // Range that's been modified
  BOOL insertedNewLine_;              // YES, if the last typing was a new line
  BOOL deletedCharacters_;            // YES, if the last typing was a deletion
  BOOL automaticallyIndent_;          // YES, if it automatically indents
  BOOL hasTemporaryLineHighlight_;    // YES, if we added a temporary highlight
}

//------------------------------------------------------------------------------
// Public
//------------------------------------------------------------------------------
- (void)addReservedWords:(NSArray *)words;
- (void)addUserDefinedWords:(NSArray *)words;
- (void)setBlockCommentStart:(NSString *)start end:(NSString *)end;
- (void)setLineComment:(NSString *)comment;

- (void)setReservedColor:(NSColor *)color;
- (void)setUserDefinedColor:(NSColor *)color;
- (void)setCommentColor:(NSColor *)color;

- (void)colorize;
- (void)colorizeRange:(NSRange)range;

- (void)setAutomaticallyIndents:(BOOL)autoIndent;

- (void)temporarilyHighlightLine:(int)line color:(NSColor *)color;

@end
