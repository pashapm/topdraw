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

#import "ColorizingTextView.h"

static NSString *ColorizerAttr = @"Colorizer";

static NSString *ColorizerBlockCommentAttr = @"ColorizerBlockCommentAttr";
static NSString *ColorizerLineCommentAttr = @"ColorizerLineCommentAttr";
static NSString *ColorizerTemporaryLineHighlightAttr = @"ColorizerTemporaryLineHighlightAttr";
static NSString *ColorizerTemporaryRangeHighlightAttr = @"ColorizerTemporaryRangeHighlightAttr";

@interface ColorizingTextView(PrivateMethods)
- (void)disableLineWrapping;

- (NSRange)extendRangeIfNecessary:(NSRange)range;
- (void)removeColorizerAttribute:(NSString *)attrName range:(NSRange)range;
- (BOOL)hasColorizerAttribute:(NSString *)attrName characterIndex:(unsigned int)idx; 

- (void)colorizeBlockComment:(NSRange)range;
- (void)colorizeLineComment:(NSRange)range;
- (void)colorizeReserved:(NSRange)range;
- (void)colorizeUserDefined:(NSRange)range;

- (void)adjustIndention:(NSRange)range;

- (void)storageChanged:(NSNotification *)note;
- (void)delayedColorize;

- (void)removeTemporaryLineHighlight;
- (void)flashBackgroundForRange:(id)rangeValue;
@end

@implementation ColorizingTextView
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Private ||
//------------------------------------------------------------------------------
- (void)disableLineWrapping {
  NSSize largeSize = NSMakeSize(1e7, 1e7);
	NSTextContainer *container = [self textContainer];
	NSScrollView *scrollView = [self enclosingScrollView];
	
	// Make sure we can see right edge of line:
  [scrollView setHasHorizontalScroller:YES];
  [scrollView setAutohidesScrollers:YES];
	
	// Make text container so wide it won't wrap:
	[container setContainerSize:largeSize];
	[container setWidthTracksTextView:NO];
  [container setHeightTracksTextView:NO];
  
	// Make sure text view is wide enough:
  [self setMaxSize:largeSize];
  [self setHorizontallyResizable:YES];
  [self setVerticallyResizable:YES];
  [self setAutoresizingMask:NSViewNotSizable];
}

//------------------------------------------------------------------------------
- (NSRange)extendRangeIfNecessary:(NSRange)range {
  NSTextStorage *ts = [self textStorage];
  unsigned int tsLen = [ts length];
  NSString *str = [ts string];
  NSRange newRange = range;

  // If the most recent change was a newline, we need to extend the range on 
  // either side of the current insertion point
  if (insertedNewLine_) {
    NSUInteger lineStart, lineEnd;

//    NSMethodLog("before: %@ (ts: %d)", NSStringFromRange(range), tsLen);
    [str getLineStart:&lineStart end:&lineEnd contentsEnd:nil forRange:NSMakeRange(newRange.location, 0)];
    
    if (lineStart > 0) {
      newRange.length += newRange.location - lineStart + 1;
      newRange.location = lineStart - 1;
    }
    
    // Find the next line start and add one character
    if (lineEnd < tsLen) {
      [str getLineStart:&lineStart end:nil contentsEnd:nil forRange:NSMakeRange(lineEnd + 1, 0)];
      newRange.length = lineStart - (newRange.location - 1) + 1;
    }
    
    // Ensure we're less than tsLen
    if (NSMaxRange(newRange) > tsLen)
      newRange.length -= NSMaxRange(newRange) - tsLen;
    
//    NSMethodLog("after: %@", NSStringFromRange(range));
    
    // Also, we shouldn't be smaller than the original range
    if ((range.location < newRange.location) ||
        (NSMaxRange(range) > NSMaxRange(newRange)))
      newRange = range;
  }
  
  return newRange;
}

//------------------------------------------------------------------------------
- (void)removeColorizerAttribute:(NSString *)attrName range:(NSRange)range {
  NSTextStorage *ts = [self textStorage];
  unsigned int tsLen = [ts length];
	NSLayoutManager *lm = [self layoutManager];
  unsigned loc = range.location;
  NSDictionary *currentAttr;
  NSString *currentAttrName;
  NSRange effective;
  
  while (loc < NSMaxRange(range)) {
    currentAttr = [lm temporaryAttributesAtCharacterIndex:loc effectiveRange:&effective];
    currentAttrName = [currentAttr objectForKey:ColorizerAttr];
    
    if ((NSMaxRange(effective) <= tsLen) && ([currentAttrName isEqualToString:attrName])) {
      [lm removeTemporaryAttribute:attrName forCharacterRange:effective];
      [lm removeTemporaryAttribute:NSForegroundColorAttributeName forCharacterRange:effective];
      [lm removeTemporaryAttribute:NSBackgroundColorAttributeName forCharacterRange:effective];
      loc += effective.length;
    } else
      ++loc;
  }
}

//------------------------------------------------------------------------------
- (BOOL)hasColorizerAttribute:(NSString *)attrName characterIndex:(unsigned int)idx {
	NSLayoutManager *lm = [self layoutManager];
  NSRange effective;
  NSDictionary *currentAttr = [lm temporaryAttributesAtCharacterIndex:idx effectiveRange:&effective];
  NSString *currentAttrName = [currentAttr objectForKey:ColorizerAttr];
  
  return [currentAttrName isEqualToString:attrName];
}

//------------------------------------------------------------------------------
- (void)colorizeBlockComment:(NSRange)range {
  NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
    commentColor_, NSForegroundColorAttributeName,
    ColorizerBlockCommentAttr, ColorizerAttr, nil];
  NSTextStorage *ts = [self textStorage];
  unsigned int tsLen = [ts length];
	NSLayoutManager *lm = [self layoutManager];
  NSString *str = [ts string];
  NSRange commentRange;
  NSRange startRange, endRange;
  unsigned int loc = range.location;
  
  commentRange = NSMakeRange(0, 0);
  
  // Check if there are any strings backwards from here
  // Might be faster to check if there's a block comment attribute nearby
  startRange = [str rangeOfString:blockCommentStart_ options:NSBackwardsSearch
                            range:NSMakeRange(0, loc)];

  // If there's a start previously, look for the end to the comment
  if (NSMaxRange(startRange) < tsLen) {
    loc = NSMaxRange(startRange);
    endRange = [str rangeOfString:blockCommentEnd_ options:0 
                            range:NSMakeRange(loc, tsLen - loc)];
    
    // If there's no end, make the end the end of the text
    if (NSMaxRange(endRange) > tsLen)
      endRange = NSMakeRange(tsLen - 1, 1);
    
    commentRange = NSUnionRange(startRange, endRange);
    [lm addTemporaryAttributes:attrs forCharacterRange:commentRange];
    NSLog(@"Adding comment: %@", NSStringFromRange(commentRange));
    [self flashBackgroundForRange:[NSValue valueWithRange:commentRange]];
  }

  // If the range of any found comments (or no comments) is before our
  // range start, scan ahead to the next start (if any) and remove the range
  if (NSMaxRange(commentRange) < range.location) {
    NSRange nextStart;
    
    nextStart = [str rangeOfString:blockCommentStart_ options:0
                              range:NSMakeRange(range.location, tsLen - range.location)];
    
    // If there isn't a following start, ensure that there's no attribute
    if (NSMaxRange(nextStart) > tsLen)
      nextStart = NSMakeRange(range.location, tsLen - range.location);
    
    // If we did have an end comment, use that as the start
    if (NSMaxRange(commentRange)) {
      commentRange.location = NSMaxRange(commentRange);
      commentRange.length = 0;
    }
    
    commentRange.length = NSMaxRange(nextStart) - NSMaxRange(commentRange);
    [self removeColorizerAttribute:ColorizerBlockCommentAttr range:commentRange];
    NSLog(@"Removing comment: %@", NSStringFromRange(commentRange));
    [self flashBackgroundForRange:[NSValue valueWithRange:commentRange]];
    
    // We need to be sure to colorize the range of what we removed, but outside
    // of this current run
    [self performSelector:@selector(colorize) withObject:nil afterDelay:0];
  }
}

//------------------------------------------------------------------------------
- (NSRange)quotedRangeForString:(NSString *)str range:(NSRange)lineRange {
  // This is semi-braindead because it will only return a single range whereas
  // there could be several ranges of quotes in the line. 
  NSString *searchStr = @"\"";
  NSRange start = [str rangeOfString:searchStr options:0 range:lineRange];
  
  if (NSMaxRange(start) > NSMaxRange(lineRange)) {
    searchStr = @"'";
    start = [str rangeOfString:searchStr options:0 range:lineRange];
  }
  
  if (NSMaxRange(start) > NSMaxRange(lineRange))
    return NSMakeRange(NSMaxRange(lineRange), NSNotFound);
  
  NSRange end = [str rangeOfString:searchStr options:NSBackwardsSearch range:lineRange];
  NSRange result = NSMakeRange(start.location, NSMaxRange(end) - NSMaxRange(start));
  
  return result;
}

//------------------------------------------------------------------------------
- (void)colorizeLineComment:(NSRange)range {
  NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
    commentColor_, NSForegroundColorAttributeName,
    ColorizerLineCommentAttr, ColorizerAttr, nil];
  NSTextStorage *ts = [self textStorage];
  unsigned int tsLen = [ts length];
	NSLayoutManager *lm = [self layoutManager];
  NSString *str = [ts string];
  NSRange lineRange, commentRange;
  unsigned int loc = range.location;
  NSUInteger lineStart, lineEnd;
  NSRange quoteRange;
   
  do {
    // Calculate the range for this line & look for comments
    [str getLineStart:&lineStart end:&lineEnd contentsEnd:nil forRange:NSMakeRange(loc, 0)];
    lineRange = NSMakeRange(lineStart, lineEnd - lineStart);
    commentRange = [str rangeOfString:lineComment_ options:0 range:lineRange];
    quoteRange = [self quotedRangeForString:str range:lineRange];

#if 0
    NSLog(@"R: %@ C: %@ L: %@", NSStringFromRange(range), NSStringFromRange(commentRange), NSStringFromRange(lineRange));
    NSLog(@"Loc: %d Sel: %@", loc, NSStringFromRange([self selectedRange]));
#endif
    
    // If there's a comment in this line, make sure that anything to the right
    // of the comment is colored
    BOOL colorize = NO;
    NSRange nextCommentRange = NSMakeRange(NSMaxRange(commentRange), 
                                           NSMaxRange(lineRange) - NSMaxRange(commentRange));
    
    // Check if there are multiple comments in this line
    while (NSMaxRange(commentRange) < NSMaxRange(lineRange)) {
      if ((commentRange.location < tsLen) && commentRange.length) {
        colorize = YES;
        
        if (quoteRange.location < commentRange.location  &&
            NSMaxRange(quoteRange) > commentRange.location) {
          commentRange = [str rangeOfString:lineComment_ options:0 range:nextCommentRange];
          colorize = NO;
        } else {
          break;
        }
      }
    }
    
    if (colorize) {
      commentRange.length = lineRange.length - (commentRange.location - lineRange.location);
      [modifiedRange_ addIndexesInRange:commentRange];
      [lm addTemporaryAttributes:attrs forCharacterRange:commentRange];
    } else {
      // There's no comment in this line.  Remove the attribute, if any
      [self removeColorizerAttribute:ColorizerLineCommentAttr range:lineRange];
    }
    
    loc += lineRange.length;
  } while (loc < NSMaxRange(range));
}

//------------------------------------------------------------------------------
- (void)colorizeWordsInSet:(NSSet *)words color:(NSColor *)color range:(NSRange)range {
  NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
                         color, NSForegroundColorAttributeName, nil];
  NSTextStorage *ts = [self textStorage];
  unsigned int tsLen = [ts length];
	NSLayoutManager *lm = [self layoutManager];
  NSString *str = [ts string];
  NSString *word;
  unsigned int loc;
  NSRange wordRange, testRange;
  
  if (!tsLen)
    return;
  
  // Gather the words
  for (loc = range.location; loc < NSMaxRange(range); ) {
    testRange = NSMakeRange(loc, 0);
    wordRange = [self selectionRangeForProposedRange:testRange granularity:NSSelectByWord];
    loc = NSMaxRange(wordRange) + 1;
    
    // Skip if this is in a range we've already modified
    if ([modifiedRange_ intersectsIndexesInRange:wordRange])
      continue;
    
    word = [str substringWithRange:wordRange];
    
    BOOL isKnownWord = NO;
    
    if ([reserved_ containsObject:word] || [userDefined_ containsObject:word])
      isKnownWord = YES;

    // If we have this word, make sure the character range hasn't already been
    // modified this time
    if ([words containsObject:word]) {
      [lm addTemporaryAttributes:attrs forCharacterRange:wordRange];
    } else if (!isKnownWord) {
      [lm removeTemporaryAttribute:NSForegroundColorAttributeName forCharacterRange:wordRange];
      [lm removeTemporaryAttribute:ColorizerAttr forCharacterRange:wordRange];
    }
  }
}

//------------------------------------------------------------------------------
- (void)colorizeReserved:(NSRange)range {
  [self colorizeWordsInSet:reserved_ color:reservedColor_ range:range];
}

//------------------------------------------------------------------------------
- (void)colorizeUserDefined:(NSRange)range {
  [self colorizeWordsInSet:userDefined_ color:userDefinedColor_ range:range];
}

//------------------------------------------------------------------------------
- (int)indentationForLineAtRange:(NSRange)range {
  NSTextStorage *ts = [self textStorage];
  NSString *str = [ts string];
  NSUInteger lineStart, lineEnd;
  NSCharacterSet *ws = [NSCharacterSet whitespaceCharacterSet];
  unsigned int count = 0;
  
  [str getLineStart:&lineStart end:&lineEnd contentsEnd:nil forRange:NSMakeRange(range.location, 0)];
  NSRange lineRange = NSMakeRange(lineStart, lineEnd - lineStart - 1);
  
  if (lineRange.location < range.location) {    
    NSRange indentRange = NSMakeRange(lineStart, 0);

    while (([ws characterIsMember:[str characterAtIndex:NSMaxRange(indentRange)]]) && (NSMaxRange(indentRange) < lineEnd))
      ++indentRange.length;
    
    count = indentRange.length;
  }
  
  return count;
}

//------------------------------------------------------------------------------
- (void)adjustIndention:(NSRange)range {
  NSTextStorage *ts = [self textStorage];
  NSString *str = [ts string];
  unsigned int loc = range.location;
  NSUInteger lineStart, lineEnd;
  NSRange lineRange;
  NSCharacterSet *ws = [NSCharacterSet whitespaceCharacterSet];
  
  [ts beginEditing];
  
  do {
    // Gather information about the previous line
    [str getLineStart:&lineStart end:&lineEnd contentsEnd:nil forRange:NSMakeRange(loc, 0)];
    lineRange = NSMakeRange(lineStart, lineEnd - lineStart - 1);
    int braceIndentation = 0;
    
    if (lineRange.location < loc) {
      NSRange indentRange = NSMakeRange(lineStart, 0);
      
      while (([ws characterIsMember:[str characterAtIndex:NSMaxRange(indentRange)]]) && (NSMaxRange(indentRange) < lineEnd))
        ++indentRange.length;
      
      // If the last character on the previous line is a "{" or the first 
      // character is a "}", adjust the indentation accordingly
      if (lineEnd > 2) {
        if ([str characterAtIndex:lineEnd - 2] == '{')
          braceIndentation = 1;
        if ([str characterAtIndex:NSMaxRange(indentRange)] == '}' && (NSMaxRange(indentRange) - (lineEnd - 2) > 2)) {
          // If we're not indented from the above line, remove a char
          int previousIndentation = [self indentationForLineAtRange:NSMakeRange(lineStart - 1, 0)];
          
          if (previousIndentation == indentRange.length) {
            // Remove the last whitespace character
            [ts replaceCharactersInRange:NSMakeRange(NSMaxRange(indentRange) - 1, 1) withString:@""];
            --indentRange.length;
            --lineEnd;
          }
        }
      }
      
      if (indentRange.length || braceIndentation) {
        NSDictionary *attrs = [ts attributesAtIndex:indentRange.location effectiveRange:nil];
        NSString *srcStr = [str substringWithRange:indentRange];

        if (braceIndentation == 1) {
          // Add one more of the last indention characters
          NSString *baseStr = srcStr;
          int len = [baseStr length];
          
          if (len)
            srcStr = [NSString stringWithFormat:@"%@%C",
                      baseStr, [baseStr characterAtIndex:[baseStr length] - 1]];
          else
            srcStr = @"\t";
        }
        
        NSAttributedString *indentStr = [[NSAttributedString alloc] initWithString:srcStr attributes:attrs];
        [ts insertAttributedString:indentStr atIndex:lineEnd];
        [indentStr release];
      }
    }
    
    loc += lineEnd;
      
  } while (loc < NSMaxRange(range));
  
  [ts endEditing];
}

//------------------------------------------------------------------------------
- (void)flashBackgroundForRange:(id)rangeValue {
#if 1
  if (ColorizerTemporaryRangeHighlightAttr)
    ;
#else    
  NSRange range = [rangeValue rangeValue];
  NSLayoutManager *lm = [self layoutManager];
  
  if ([self hasColorizerAttribute:ColorizerTemporaryRangeHighlightAttr characterIndex:range.location]) {
    [lm removeTemporaryAttribute:ColorizerAttr forCharacterRange:range];
    [lm removeTemporaryAttribute:NSBackgroundColorAttributeName forCharacterRange:range];
  } else {
    NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
                           ColorizerTemporaryRangeHighlightAttr, ColorizerAttr,
                           [NSColor yellowColor], NSBackgroundColorAttributeName,
                           nil];
    [lm addTemporaryAttributes:attrs forCharacterRange:range];
    [self performSelector:_cmd withObject:rangeValue afterDelay:1];
  }
#endif
}

//------------------------------------------------------------------------------
- (void)delayedColorize {
  [self colorizeRange:invalidRange_];
  
  // Temporarily recolor the background
  [self flashBackgroundForRange:[NSValue valueWithRange:invalidRange_]];
  
  invalidRange_.location = 0;
  invalidRange_.length = 0;
}

//------------------------------------------------------------------------------
- (void)storageChanged:(NSNotification *)note {
	NSTextStorage *ts = [note object];
  NSRange edited = [ts editedRange];

  // There seems to be a problem with this happening at the same time
  // as the notification, so we'll delay it until the next run loop
  if ((invalidRange_.location < [ts length]) && invalidRange_.length)
    invalidRange_ = NSUnionRange(invalidRange_, edited);
  else
    invalidRange_ = edited;
  
  [self performSelector:@selector(delayedColorize) withObject:nil afterDelay:0];
}

//------------------------------------------------------------------------------
- (void)removeTemporaryLineHighlight {
  NSRange range = NSMakeRange(0, [[self textStorage] length]);
  [self removeColorizerAttribute:ColorizerTemporaryLineHighlightAttr range:range];
  hasTemporaryLineHighlight_ = NO;
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || Public ||
//------------------------------------------------------------------------------
- (void)addReservedWords:(NSArray *)words {
  
  if (!reserved_)
    reserved_ = [[NSMutableSet alloc] init];
  
  [reserved_ addObjectsFromArray:words];
}

//------------------------------------------------------------------------------
- (void)addUserDefinedWords:(NSArray *)words {
  if (!userDefined_)
    userDefined_ = [[NSMutableSet alloc] init];
  
  [userDefined_ addObjectsFromArray:words];
}

//------------------------------------------------------------------------------
- (void)setBlockCommentStart:(NSString *)start end:(NSString *)end {
  [blockCommentStart_ autorelease];
  [blockCommentEnd_ autorelease];
  blockCommentStart_ = [start copy];
  blockCommentEnd_ = [end copy];
}

//------------------------------------------------------------------------------
- (void)setLineComment:(NSString *)comment {
  [lineComment_ autorelease];
  lineComment_ = [comment copy];
}

//------------------------------------------------------------------------------
- (void)setReservedColor:(NSColor *)color {
  [reservedColor_ autorelease];
  reservedColor_ = [color copy];
}

//------------------------------------------------------------------------------
- (void)setUserDefinedColor:(NSColor *)color {
  [userDefinedColor_ autorelease];
  userDefinedColor_ = [color copy];
}

//------------------------------------------------------------------------------
- (void)setCommentColor:(NSColor *)color {
  [commentColor_ autorelease];
  commentColor_ = [color copy];
}

//------------------------------------------------------------------------------
- (void)colorize {
  unsigned int len = [[self textStorage] length];
  
  [self colorizeRange:NSMakeRange(0, len)];
}

//------------------------------------------------------------------------------
- (void)colorizeRange:(NSRange)range {
  NSTextStorage *ts = [self textStorage];
  NSRange originalRange = range;

  // Always remove
  [self removeTemporaryLineHighlight];
  
  // Quick checks for exist
  if (isColoring_)
    return;
  
  if (!range.location && !range.length)
    return;
  
  if (![ts length])
    return;
  
  if (!modifiedRange_)
    modifiedRange_ = [[NSMutableIndexSet alloc] init];

  [modifiedRange_ removeAllIndexes];
  range = [self extendRangeIfNecessary:range];
  
  isColoring_ = YES;
  // TODO: Block comment colorizing is not working
//  [self colorizeBlockComment:range];
  [self colorizeLineComment:range];
  [self colorizeReserved:range];
  [self colorizeUserDefined:range];
  isColoring_ = NO;
  lastRange_ = range;

  if ((automaticallyIndent_) && (insertedNewLine_))
    [self adjustIndention:originalRange];
  
  // Reset our state variables
  insertedNewLine_ = NO;
  deletedCharacters_ = NO;
}

//------------------------------------------------------------------------------
- (void)setAutomaticallyIndents:(BOOL)autoIndent {
  automaticallyIndent_ = autoIndent;
}

//------------------------------------------------------------------------------
- (void)temporarilyHighlightLine:(int)line color:(NSColor *)color {
  NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
                         color, NSBackgroundColorAttributeName,
                         ColorizerTemporaryLineHighlightAttr, ColorizerAttr, nil];
  NSTextStorage *ts = [self textStorage];
  unsigned int tsLen = [ts length];
  NSString *str = [ts string];
  NSRange range = NSMakeRange(0, 0);
  
  while (1) {
    range = [str lineRangeForRange:range];
    --line;
    
    if (line <= 0) {
      NSLayoutManager *lm = [self layoutManager];
      [lm addTemporaryAttributes:attrs forCharacterRange:range];
      hasTemporaryLineHighlight_ = YES;
      break;
    }
    
    if (NSMaxRange(range) >= tsLen)
      break;
    
    range.location = NSMaxRange(range);
    range.length = 0;
  }
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || NSResponder ||
//------------------------------------------------------------------------------
- (void)insertNewline:(id)sender {
  insertedNewLine_ = YES;
  [super insertNewline:sender];
  
  // Just in case we're all hosed up, try to recolorize after a short delay
//  [self performSelector:@selector(colorize) withObject:nil afterDelay:1.0];
}

//------------------------------------------------------------------------------
- (BOOL)expandSelectionToFullLines {
  NSRange selection = [self selectedRange];
  
  // If there's no selection, just return NO
  if (selection.length == 0)
    return NO;
  
  NSLayoutManager *layoutMgr = [self layoutManager];
  NSRange lineGlyphRange, firstLineCharRange, lastLineCharRange;
  
  // Find the start of the first line containing the selection
  [layoutMgr lineFragmentRectForGlyphAtIndex:selection.location effectiveRange:&lineGlyphRange];        
  firstLineCharRange = [layoutMgr characterRangeForGlyphRange:lineGlyphRange actualGlyphRange:NULL];
  
  // Find the end of the last line containing the selection, omitting the \n
  [layoutMgr lineFragmentRectForGlyphAtIndex:NSMaxRange(selection) - 1 effectiveRange:&lineGlyphRange];        
  lastLineCharRange = [layoutMgr characterRangeForGlyphRange:lineGlyphRange actualGlyphRange:NULL];

  // Select this range
  selection.location = firstLineCharRange.location;
  selection.length = NSMaxRange(lastLineCharRange) - firstLineCharRange.location;  
  [self setSelectedRange:selection];

  return YES;
}

//------------------------------------------------------------------------------
- (void)indentSelection:(id)sender {
  NSTextStorage *storage = [self textStorage];
  NSRange selection = [self selectedRange];
  NSRange subRange = NSMakeRange(selection.location, 1);
  NSUInteger startIdx = 0, endIdx = 0;
  
  // Group this undo
  [[self undoManager] registerUndoWithTarget:self selector:@selector(unindentSelection:) object:nil];
  [storage beginEditing];
  NSMutableString *str = [storage mutableString];
  int added = 0;

  while (endIdx < NSMaxRange(selection)) {
    [str getLineStart:&startIdx end:&endIdx contentsEnd:nil forRange:subRange];
    [str insertString:@"\t" atIndex:startIdx];
    subRange.location = endIdx + 1;
    ++added;
  }
  
  selection.length += added;
  
  [storage endEditing];
  [self setSelectedRange:selection];
}

//------------------------------------------------------------------------------
- (void)unindentSelection:(id)sender {
  NSTextStorage *storage = [self textStorage];
  NSRange selection = [self selectedRange];
  NSRange subRange = NSMakeRange(selection.location, 1);
  NSUInteger startIdx = 0, endIdx = 0, lastStart = 0;
  
  [[self undoManager] registerUndoWithTarget:self selector:@selector(indentSelection:) object:nil];

  [storage beginEditing];
  NSMutableString *str = [storage mutableString];
  int removed = 0;
  
  while (endIdx < (NSMaxRange(selection) - removed)) {
    [str getLineStart:&startIdx end:&endIdx contentsEnd:nil forRange:subRange];
    
    if (lastStart && lastStart == startIdx)
      break;
    
    lastStart = startIdx;
    unichar ch = [str characterAtIndex:startIdx];
    
    if ([[NSCharacterSet whitespaceCharacterSet] characterIsMember:ch]) {
      [str replaceCharactersInRange:NSMakeRange(startIdx, 1) withString:@""];
      subRange.location = endIdx - 1;
      ++removed;
    }
  }
  
  selection.length -= removed;
  
  [storage endEditing];
  [self setSelectedRange:selection];
}

//------------------------------------------------------------------------------
- (void)insertTab:(id)sender {
  // If there's a selection, block select all lines and insert tab character at beginning
  if ([self expandSelectionToFullLines])
    [self indentSelection:self];
  else
    [super insertTab:sender];
}

//------------------------------------------------------------------------------
- (void)insertBacktab:(id)sender {
  // If there's a selection, block select all lines and remove space/tab character at beginning
  if ([self expandSelectionToFullLines])
    [self unindentSelection:self];
  else
    [super insertBacktab:sender];
}

//------------------------------------------------------------------------------
- (void)deleteForward:(id)sender {
  deletedCharacters_ = YES;
  [super deleteForward:sender];  
}

//------------------------------------------------------------------------------
- (void)deleteBackward:(id)sender {
  deletedCharacters_ = YES;
  [super deleteBackward:sender];  
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark || NSObject ||
//------------------------------------------------------------------------------
- (void)awakeFromNib {
  automaticallyIndent_ = NO;
  
  // Listen for text changes
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(storageChanged:)
     name:NSTextStorageDidProcessEditingNotification object:[self textStorage]];
  
    // Turn off wrapping
  [self disableLineWrapping];
}

//------------------------------------------------------------------------------
- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  
  [reserved_ release];
  [blockCommentStart_ release];
  [blockCommentEnd_ release];
  [lineComment_ release];
  [reservedColor_ release];
  [userDefinedColor_ release];
  [commentColor_ release];

  [super dealloc];
}

@end
