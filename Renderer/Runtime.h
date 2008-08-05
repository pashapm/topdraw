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

// The JavaScript runtime.  A wrapper around JavaScriptCore framework so that
// it's relatively easy to use ObjC objects.

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

#import "RuntimeObject.h"

@interface Runtime : NSObject {
  NSString *name_;
  JSGlobalContextRef globalContext_;
  JSObjectRef global_;
  NSMapTable *classMap_;  // Map from JSClassRef to ObjC Class
  NSMapTable *constructorMap_;  // Map from Constructor JSObjectRef to JSClassRef
  NSMapTable *methodMap_; // Map from function JSObjectRef to NSString method name
  NSMutableSet *methodNames_;
  NSHashTable *staticClassElements_;
  NSHashTable *prototypeUpdated_; // If we've updated the prototype for a class, it will be in here
  id delegate_;
}

- (id)initWithName:(NSString *)name;

- (void)setDelegate:(id)delegate;
- (id)delegate;

// |objcClass| needs to be a class that conforms to JSWrapper.  This will allow
// the class to be created in the Runtime.
- (BOOL)registerClass:(Class)objcClass;

// Set |obj| into the Runtime with |name|
- (BOOL)setObject:(NSObject <RuntimeObject> *)obj withName:(NSString *)name;

- (BOOL)evaluateScript:(NSString *)script exception:(NSException **)exception;

@end

@interface NSObject(RuntimeDelegate)
- (void)runtime:(Runtime *)runtime didReceiveLogMessage:(NSString *)msg;
@end
