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

#import "Function.h"
#import "Runtime.h"

@interface Runtime(PrivateMethods)
- (id)convertJSValue:(JSValueRef)value exception:(JSValueRef *)exception context:(JSContextRef)context;
- (JSValueRef)convertObject:(id)object context:(JSContextRef)context;
- (NSArray *)convertJSArguments:(const JSValueRef *)arguments count:(size_t)count
                      exception:(JSValueRef *)exception context:(JSContextRef)context;
- (NSArray *)propertyNamesForObject:(JSObjectRef)object exception:(JSValueRef *)exception context:(JSContextRef)context;
- (NSDictionary *)propertiesForObject:(JSObjectRef)object exception:(JSValueRef *)exception context:(JSContextRef)context;

- (JSClassRef)registeredClassForConstructor:(JSObjectRef)constructor;
- (Class)registeredClassForJSClass:(JSClassRef)class;
- (JSClassRef)registeredJSClassForClass:(Class)class;
- (NSString *)methodNameForFunction:(JSObjectRef)function;
- (void)setMethodName:(NSString *)name forFunction:(JSObjectRef)function;
- (void)updateObjectPrototype:(JSObjectRef)protoObj forMethods:(NSSet *)methods;

- (JSStaticValue *)staticValuesForClass:(Class)class;
- (JSStaticFunction *)staticFunctionsForClass:(Class)class;

@end

static Runtime *RuntimeFromContext(JSContextRef ctx) {
  JSObjectRef global = JSContextGetGlobalObject(ctx);
  
  return JSObjectGetPrivate(global);
}

@implementation Runtime
#pragma mark -
#pragma mark || JS Binding Functions ||
static JSObjectRef Constructor(JSContextRef ctx, JSObjectRef constructor, 
                               size_t count, const JSValueRef arguments[], JSValueRef *exception) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  Runtime *runtime = RuntimeFromContext(ctx);
  JSClassRef jsClass = [runtime registeredClassForConstructor:constructor];
  Class class = [runtime registeredClassForJSClass:jsClass];
  NSArray *args = [runtime convertJSArguments:arguments count:count exception:exception context:ctx];
  id obj = [[class alloc] initWithArguments:args];
  JSObjectRef jsObj = JSObjectMake(ctx, jsClass, obj);
  
  // Insert any of the functions
  JSObjectRef protoObj = (JSObjectRef)JSObjectGetPrototype(ctx, jsObj);
  [runtime updateObjectPrototype:protoObj forMethods:[class methods]];
  
  [pool release];
  
  return jsObj;
}

static void Finalize(JSObjectRef object) {
  RuntimeObject *obj = JSObjectGetPrivate(object);
  [obj release];
}

JSValueRef GetProperty(JSContextRef ctx, JSObjectRef object, 
                       JSStringRef propertyName, JSValueRef *exception) {
  RuntimeObject *runtimeObj = JSObjectGetPrivate(object);
  Runtime *runtime = RuntimeFromContext(ctx);
  NSString *propertyStr = (NSString *)JSStringCopyCFString(NULL, propertyName);
  id propertyObj = [runtimeObj valueForProperty:propertyStr];
  JSValueRef result = [runtime convertObject:propertyObj context:ctx];
  [propertyStr release];
  
  return result;
}

bool SetProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, 
                 JSValueRef value, JSValueRef *exception) {
  RuntimeObject *runtimeObj = JSObjectGetPrivate(object);
  Runtime *runtime = RuntimeFromContext(ctx);
  NSString *propertyStr = (NSString *)JSStringCopyCFString(NULL, propertyName); 
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  id objCValue = [runtime convertJSValue:value exception:exception context:ctx];
  [runtimeObj setValue:objCValue forProperty:propertyStr];
  [pool release];
  [propertyStr release];
  
  return true;
}

static JSValueRef CallAsFunction(JSContextRef ctx, JSObjectRef function, JSObjectRef object, 
                                 size_t count, const JSValueRef arguments[], JSValueRef *exception) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  RuntimeObject *runtimeObj = JSObjectGetPrivate(object);
  Runtime *runtime = RuntimeFromContext(ctx);
  NSString *methodName = [runtime methodNameForFunction:function];
  SEL methodSel = NSSelectorFromString(methodName);
  id result = nil;
  
  // Check if this needs a ":" to indicate that it takes some more args
  if (![runtimeObj respondsToSelector:methodSel]) {
    methodName = [methodName stringByAppendingString:@":"];
    methodSel = NSSelectorFromString(methodName);
    
    // Change the name in the runtime if this one works
    if ([runtimeObj respondsToSelector:methodSel])
      [runtime setMethodName:methodName forFunction:function];
    else
      methodSel = NULL;
  }
  
  if (methodSel) {
    NSArray *args = [runtime convertJSArguments:arguments count:count exception:exception context:ctx];
    NSMethodSignature *methodSig = [runtimeObj methodSignatureForSelector:methodSel];
    int returnLength = [methodSig methodReturnLength];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSig];
    
    [invocation setTarget:runtimeObj];
    [invocation setSelector:methodSel];
    
    if (([methodSig numberOfArguments] > 2) && args)
      [invocation setArgument:&args atIndex:2];
    
    [invocation invoke];
    
    if (returnLength) {
      const char *returnType = [methodSig methodReturnType];
      if (strlen(returnType)) {
        char type = returnType[0];
        int returnInt = 0;
        unsigned int returnUnsignedInt = 0;
        float returnFloat = 0.0;
        double returnDouble = 0.0;
        switch (type) {
          case 'c':
          case 'i':
          case 's':
          case 'l':
            [invocation getReturnValue:&returnInt];
            result = [NSNumber numberWithInt:returnInt];
            break;
          case 'C':
          case 'I':
          case 'S':
          case 'L':
            [invocation getReturnValue:&returnUnsignedInt];
            result = [NSNumber numberWithUnsignedInt:returnInt];
            break;
          case 'd':
            [invocation getReturnValue:&returnDouble];
            result = [NSNumber numberWithDouble:returnDouble];
            break;
          case 'f':
            [invocation getReturnValue:&returnFloat];
            result = [NSNumber numberWithDouble:returnFloat];
            break;
          case '@':
            [invocation getReturnValue:&result];
            break;
          default:
            MethodLog("Unexpected return type (%s) from %@", returnType, methodName);
            result = nil;
        }
      }
    } else {
      result = nil;
    }
  } else {
    NSLog(@"%@ doesn't respond to %@ method", NSStringFromClass([runtimeObj class]), methodName);
  }
  
  JSValueRef returnRef = [runtime convertObject:result context:ctx];
  [pool release];
  
  return returnRef;
}

static JSValueRef ConvertToType(JSContextRef ctx, JSObjectRef object, JSType type, JSValueRef *exception) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  RuntimeObject *runtimeObj = JSObjectGetPrivate(object);
  Runtime *runtime = RuntimeFromContext(ctx);
  id result = nil;
  
  if (type == kJSTypeString)
    result = [runtimeObj description];
  
  JSValueRef value = [runtime convertObject:result context:ctx];
  [pool release];
  
  return value;
}

static JSValueRef LogFn(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                        size_t count, const JSValueRef arguments[], JSValueRef *exception) {
  Runtime *runtime = RuntimeFromContext(ctx);
  id delegate = [runtime delegate];
  
  if (![delegate respondsToSelector:@selector(runtime:didReceiveLogMessage:)])
    return JSValueMakeNull(ctx);
  
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSArray *args = [runtime convertJSArguments:arguments count:count exception:exception context:ctx];
  NSMutableString *str = [[NSMutableString alloc] init];
  
  for (int i = 0; i < count; ++i)
    [str appendFormat:@"%@", [args objectAtIndex:i]];

  [delegate runtime:runtime didReceiveLogMessage:str];
  [str release];
  [pool release];
  
  return JSValueMakeNull(ctx);
}

#pragma mark -
#pragma mark || Private Methods ||
- (id)convertJSValue:(JSValueRef)value exception:(JSValueRef *)exception context:(JSContextRef)context{
  JSType type = JSValueGetType(context, value);
  id obj = nil;
  switch (type) {
    case kJSTypeUndefined:
    case kJSTypeNull:
      obj = [NSNull null];
      break;
    case kJSTypeBoolean:
      obj = [NSNumber numberWithBool:JSValueToBoolean(context, value)];
      break;
    case kJSTypeNumber:
      obj = [NSNumber numberWithDouble:JSValueToNumber(context, value, exception)];
      break;
    case kJSTypeString: {
      JSStringRef jsStr = JSValueToStringCopy(context, value, exception);
      obj = [(NSString *)JSStringCopyCFString(NULL, jsStr) autorelease];
      JSStringRelease(jsStr);
    }
      break;
    case kJSTypeObject: {
      JSObjectRef objRef = JSValueToObject(context, value, exception);
      obj = JSObjectGetPrivate(objRef);
      
      if (!obj) {
        if (JSObjectIsFunction(context, objRef)) {
          // Try function
          obj = [[[Function alloc] initWithJSFunction:objRef runtime:self] autorelease];
        } else {
          // Try to convert array to NSArray
          JSStringRef array = JSStringCreateWithUTF8CString("Array");
          JSObjectRef arrayConstructor = JSValueToObject(context, JSObjectGetProperty(context, global_, array, NULL), NULL);
          JSStringRelease(array);
          
          if (JSValueIsInstanceOfConstructor(context, value, arrayConstructor, NULL)) {
            JSValueRef val;
            obj = [NSMutableArray array];
            
            for (int i = 0; i < INT_MAX; ++i) {
              val = JSObjectGetPropertyAtIndex(context, objRef, i, NULL);
              if (JSValueIsUndefined(context, val))
                break;
              id valObj = [self convertJSValue:val exception:exception context:context];
              if (valObj)
                [obj addObject:valObj];
            }
          }
        } 
        
        if (!obj)
          obj = [NSString stringWithFormat:@"[Object %x]", objRef];
      }
    }
      break;
      
    default:
      MethodLog("Unexpected JS type: %d", type);
      break;
  }
  
  return obj;
}

- (JSValueRef)convertObject:(id)object context:(JSContextRef)context {
  JSValueRef value = JSValueMakeUndefined(context);
  
  if ([object isKindOfClass:[NSNull class]]) {
    value = JSValueMakeNull(context);
  } else if ([object isKindOfClass:[NSNumber class]]) {
    value = JSValueMakeNumber(context, [object doubleValue]);
  } else if ([object isKindOfClass:[NSString class]]) {
    JSStringRef str = JSStringCreateWithCFString((CFStringRef)object);
    value = JSValueMakeString(context, str);
    JSStringRelease(str);
  } else if ([object isKindOfClass:[NSArray class]]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    JSStringRef arrayStr = JSStringCreateWithUTF8CString("Array");
    JSObjectRef arrayConstructor = JSValueToObject(context, JSObjectGetProperty(context, global_, arrayStr, NULL), NULL);
    JSStringRelease(arrayStr);

    JSValueRef exception;
    JSObjectRef array = JSObjectCallAsConstructor(context, arrayConstructor, 0, nil, &exception);
    if (array) {
      int count = [object count];
      for (int i = 0; i < count; ++i) {
        JSValueRef converted = [self convertObject:[object objectAtIndex:i] context:context];
        JSObjectSetPropertyAtIndex(context, array, i, converted, &exception);
      }
      
      value = array;
    }
    
    [pool release];
  } else {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    Class class = [object class];
    JSClassRef jsClass = [self registeredJSClassForClass:class];
    
    if (jsClass) {
      // TODO: This is similar to code in the Constructor function -- should 
      // probably be refactored.
      JSObjectRef jsObj = JSObjectMake(context, jsClass, object);
      JSObjectRef protoObj = (JSObjectRef)JSObjectGetPrototype(context, jsObj);
      [self updateObjectPrototype:protoObj forMethods:[class methods]];

      // The object should be on an autorelease pool or retained privately.
      // When the JS object is finalized, it will release this object, so we
      // make sure that we retain it here
      [object retain];
      [pool release];
      value = (JSValueRef)jsObj;
    }
  }
  
  return value;
}

- (NSArray *)convertJSArguments:(const JSValueRef *)arguments count:(size_t)count 
                      exception:(JSValueRef *)exception context:(JSContextRef)context {
  NSMutableArray *array = [NSMutableArray array];
  
  for (int i = 0; i < count; ++i) {
    id obj = [self convertJSValue:arguments[i] exception:exception context:context];
    
    if (obj)
      [array addObject:obj];
  }
  
  return array;
}

- (NSArray *)propertyNamesForObject:(JSObjectRef)object 
                          exception:(JSValueRef *)exception
                            context:(JSContextRef)context {
  JSPropertyNameArrayRef propertyArray = JSObjectCopyPropertyNames(context, object);
  int count = JSPropertyNameArrayGetCount(propertyArray);
  NSMutableArray *result = [NSMutableArray array];
  
  for (int i = 0; i < count; ++i) {
    JSStringRef keyRef = JSPropertyNameArrayGetNameAtIndex(propertyArray, i);
    CFStringRef key = JSStringCopyCFString(NULL, keyRef);
    [result addObject:(NSString *)key];
    CFRelease(key);
  }
  
  JSPropertyNameArrayRelease(propertyArray);
  
  return result;
}

- (NSDictionary *)propertiesForObject:(JSObjectRef)object 
                            exception:(JSValueRef *)exception 
                              context:(JSContextRef)context {
  JSPropertyNameArrayRef propertyArray = JSObjectCopyPropertyNames(context, object);
  int count = JSPropertyNameArrayGetCount(propertyArray);
  NSMutableDictionary *result = [NSMutableDictionary dictionary];
  
  for (int i = 0; i < count; ++i) {
    JSStringRef keyRef = JSPropertyNameArrayGetNameAtIndex(propertyArray, i);
    JSValueRef valueRef = JSObjectGetProperty(context, object, keyRef, NULL);
    CFStringRef key = JSStringCopyCFString(NULL, keyRef);
    id val = [self convertJSValue:valueRef exception:exception context:context];
    
    if (val)
      [result setObject:val forKey:(NSString *)key];
    
    CFRelease(key);
  }
  
  JSPropertyNameArrayRelease(propertyArray);
  
  return result;
}

- (JSClassRef)registeredClassForConstructor:(JSObjectRef)constructor {
  return NSMapGet(constructorMap_, constructor);
}

- (Class)registeredClassForJSClass:(JSClassRef)class {
  return NSMapGet(classMap_, class);
}

- (JSClassRef)registeredJSClassForClass:(Class)class {
  NSMapEnumerator e = NSEnumerateMapTable(classMap_);
  JSClassRef jsClass;
  Class foundClass;
  while (NSNextMapEnumeratorPair(&e, (void *)&jsClass, (void *)&foundClass)) {
    if (foundClass == class) {
      NSEndMapTableEnumeration(&e);
      return jsClass;
    }
  }
  
  NSEndMapTableEnumeration(&e);
  return NULL;
}

- (NSString *)methodNameForFunction:(JSObjectRef)function {
  return NSMapGet(methodMap_, function);
}

- (void)setMethodName:(NSString *)name forFunction:(JSObjectRef)function {
  NSMapInsert(methodMap_, function, name);
}

- (void)updateObjectPrototype:(JSObjectRef)protoObj forMethods:(NSSet *)methods {
  // If this isn't an object or we've already updated the prototype
  if (!JSValueIsObject(globalContext_, protoObj) || NSHashGet(prototypeUpdated_, protoObj))
    return;
  
  JSPropertyNameArrayRef propertyArray = JSObjectCopyPropertyNames(globalContext_, protoObj);
  int count = JSPropertyNameArrayGetCount(propertyArray);

  for (int i = 0; i < count; ++i) {
    JSStringRef methodRef = JSPropertyNameArrayGetNameAtIndex(propertyArray, i);
    NSString *methodStr = (NSString *)JSStringCopyCFString(NULL, methodRef);
    
    // If this is one of our known methods, add the object to our table
    if ([methods containsObject:methodStr]) {
      JSObjectRef methodObj = (JSObjectRef)JSObjectGetProperty(globalContext_, protoObj, methodRef, NULL);
      NSMapInsertKnownAbsent(methodMap_, methodObj, [methods member:methodStr]);
    }
      
    [methodStr release];
  }
  
  JSPropertyNameArrayRelease(propertyArray);
  NSHashInsertKnownAbsent(prototypeUpdated_, protoObj);
}

static void CopyStringToCString(NSString *str, char **cStr) {
  const char *utf8Str = [str UTF8String];
  int len = strlen(utf8Str) + 1;
  *cStr = malloc(len);
  strlcpy(*cStr, utf8Str, len);
}

- (JSStaticValue *)staticValuesForClass:(Class)class {
  NSSet *properties = [class properties];
  NSEnumerator *e = [properties objectEnumerator];
  NSString *name;
  JSStaticValue *values = (JSStaticValue *)calloc(sizeof(JSStaticValue), [properties count] + 1);
  JSStaticValue *valuePtr = values;
  while ((name = [e nextObject])) {
    CopyStringToCString(name, (char **)&valuePtr->name);
    valuePtr->getProperty = GetProperty;
    valuePtr->setProperty = SetProperty;
    valuePtr->attributes = kJSPropertyAttributeDontDelete;
    
    // Keep track of the name for later cleanup
    NSHashInsertKnownAbsent(staticClassElements_, valuePtr->name);
    ++valuePtr;
  }

  NSHashInsertKnownAbsent(staticClassElements_, values);
  
  return values;
}

- (JSStaticFunction *)staticFunctionsForClass:(Class)class {
  NSSet *methods = [class methods];
  NSEnumerator *e = [methods objectEnumerator];
  NSString *name;
  JSStaticFunction *functions = (JSStaticFunction *)calloc(sizeof(JSStaticFunction), [methods count] + 1);
  JSStaticFunction *functionPtr = functions;
  while ((name = [e nextObject])) {
    CopyStringToCString(name, (char **)&functionPtr->name);
    functionPtr->callAsFunction = CallAsFunction;
    functionPtr->attributes = kJSPropertyAttributeDontDelete | kJSPropertyAttributeReadOnly;
    
    // Keep track of the name for later cleanup
    NSHashInsertKnownAbsent(staticClassElements_, functionPtr->name);
    ++functionPtr;
  }

  NSHashInsertKnownAbsent(staticClassElements_, functions);
  
  return functions;  
}

#pragma mark -
#pragma mark || Public ||

- (id)initWithName:(NSString *)name {
  if ((self = [super init])) {
    // We'll have an "empty" global object
    JSClassDefinition def = kJSClassDefinitionEmpty;
    JSClassRef globalRef = JSClassCreate(&def);
    
    // Create the context with our global object
    globalContext_ = JSGlobalContextCreate(globalRef);
    global_ = JSContextGetGlobalObject(globalContext_);
    JSObjectSetPrivate(global_, self);
    
    // Map from JSClassRef to ObjC Class
    classMap_ = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks, NSNonRetainedObjectMapValueCallBacks, 0);
    
    // Map from constructor (JSObjectRef) to JSClassRef
    constructorMap_ = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks, NSNonOwnedPointerMapValueCallBacks, 0);
    
    // Map from function (JSObjectRef) to NSString method name
    methodMap_ = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks, NSObjectMapValueCallBacks, 0); 
    
    // Container for static values & functions for defined classes
    staticClassElements_ = NSCreateHashTable(NSOwnedPointerHashCallBacks, 0);
    
    // Container for JSObjectRef that are prototypes that we've updated the
    // functions to have the strings set as private data
    prototypeUpdated_ = NSCreateHashTable(NSNonOwnedPointerHashCallBacks, 0);
    
    // Create our logging function
    JSStringRef logFnStr = JSStringCreateWithUTF8CString("log");
    JSObjectRef logFnObj = JSObjectMakeFunctionWithCallback(globalContext_, logFnStr, LogFn);
    JSPropertyAttributes attrs = kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete;
    JSObjectSetProperty(globalContext_, global_, logFnStr, logFnObj, attrs, NULL);
    JSStringRelease(logFnStr);
    
    name_ = [name copy];
  }
  
  return self;
}

- (void)dealloc {
  // This seems a bit strange, as you'd expect the release to invalidate the
  // context.  However, the documentation (and when running), it seems to work.
  JSGlobalContextRelease(globalContext_);
  JSGarbageCollect(globalContext_);

  // Release the created JSClassRef objects that we allocated
  NSMapEnumerator e = NSEnumerateMapTable(classMap_);
  void *key, *value;
  while ((NSNextMapEnumeratorPair(&e, &key, &value))) {
    JSClassRelease((JSClassRef)key);
  }
  
  NSEndMapTableEnumeration(&e);
  
  // Cleanup the mapping/hash tables
  NSFreeMapTable(classMap_);
  NSFreeMapTable(constructorMap_);
  NSFreeMapTable(methodMap_);  
  NSFreeHashTable(staticClassElements_);
  NSFreeHashTable(prototypeUpdated_);
  
  [name_ release];
  [super dealloc];
}

- (void)setDelegate:(id)delegate {
  delegate_ = delegate;
}

- (id)delegate {
  return delegate_;
}

- (BOOL)registerClass:(Class)objCClass {
  BOOL result = NO;  
  JSClassRef jsClass;
  JSClassDefinition def = kJSClassDefinitionEmpty;
  NSString *classNameForJS = [objCClass className];
  const char *classNameChars = [classNameForJS UTF8String];
  int len = strlen(classNameChars) + 1;
  
  // Create the JS class
  def.className = malloc(len);
  strlcpy((char *)def.className, classNameChars, len);
  def.staticValues = [self staticValuesForClass:objCClass];
  def.staticFunctions = [self staticFunctionsForClass:objCClass];
  def.finalize = Finalize;
  def.callAsFunction = CallAsFunction;
  def.convertToType = ConvertToType;
  jsClass = JSClassCreate(&def);
  
  // Create a constructor for it and attach it to the global object
  JSObjectRef constructor = JSObjectMakeConstructor(globalContext_, jsClass, Constructor);
  JSStringRef nameRef = JSStringCreateWithCFString((CFStringRef)classNameForJS);
  int attrs = kJSPropertyAttributeDontDelete | kJSPropertyAttributeReadOnly;
  JSValueRef exception = NULL;
  JSObjectSetProperty(globalContext_, global_, nameRef, (JSValueRef)constructor, attrs, &exception);
  JSStringRelease(nameRef);
  
  if (exception)
    NSLog(@"Exception when registering %@", NSStringFromClass(objCClass));
  
  NSMapInsertKnownAbsent(classMap_, jsClass, objCClass);
  NSMapInsertKnownAbsent(constructorMap_, constructor, jsClass);
  NSHashInsertKnownAbsent(staticClassElements_, def.className);

  return result;
}

- (BOOL)setObject:(NSObject <RuntimeObject> *)obj withName:(NSString *)name {
  Class class = [obj class];
  BOOL result = YES;
  JSClassRef jsClass = [self registeredJSClassForClass:class];
  
  if (!jsClass) {
    [self registerClass:class];
    jsClass = [self registeredJSClassForClass:class];
    if (!jsClass) {
      MethodLog("Unable to register class: %@", NSStringFromClass(class));
      return NO;
    }
  }
  
  JSObjectRef jsObj = JSObjectMake(globalContext_, jsClass, obj);
  
  // Insert any of the functions
  JSObjectRef protoObj = (JSObjectRef)JSObjectGetPrototype(globalContext_, jsObj);
  [self updateObjectPrototype:protoObj forMethods:[class methods]];
  
  // Add the object to the global object
  JSStringRef jsName = JSStringCreateWithCFString((CFStringRef)name);
  JSObjectSetProperty(globalContext_, global_, jsName, jsObj, 
                      kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete, NULL);
  
  // Hold onto the object
  [obj retain];
  
  return result;
}

- (BOOL)evaluateScript:(NSString *)script exception:(NSException **)exception {
  BOOL result = NO;
  
  JSStringRef sourceJS = JSStringCreateWithCFString((CFStringRef)script);
  JSStringRef sourceURL = JSStringCreateWithCFString((CFStringRef)name_);
  JSValueRef jsException = NULL;
  JSEvaluateScript(globalContext_, sourceJS, NULL, sourceURL, 0, &jsException);
  JSStringRelease(sourceJS);
  JSStringRelease(sourceURL);
 
  if (jsException && exception) {
    JSObjectRef exceptionObj = JSValueToObject(globalContext_, jsException, NULL);
    NSDictionary *exceptionDict = [self propertiesForObject:exceptionObj exception:NULL context:globalContext_];
    // line, sourceId, sourceURL, name, message
    NSString *name = [exceptionDict objectForKey:@"name"];
    NSString *reason = [exceptionDict objectForKey:@"message"];
    *exception = [NSException exceptionWithName:name reason:reason userInfo:exceptionDict];
  }
  
  return result;
}

- (id)invokeFunction:(Function *)function arguments:(NSArray *)arguments {
  JSValueRef *argumentValues = NULL;
  int argCount = [arguments count];
  
  if (argCount) {
    argumentValues = malloc(sizeof(JSValueRef) * argCount);
    for (int i = 0; i < argCount; ++i) {
      argumentValues[i] = [self convertObject:[arguments objectAtIndex:i] context:globalContext_];
    }
  }
  
  JSValueRef exception = NULL;
  JSValueRef resultRef = JSObjectCallAsFunction(globalContext_, [function function], NULL, argCount, argumentValues, &exception);
  id result = nil;

  if (resultRef)
    result = [self convertJSValue:resultRef exception:NULL context:globalContext_];
  
  // Since the values are GC'd, we don't have to clean them up
  free(argumentValues);
  
  return result;
}

@end
