//
//  KKObserver.m
//  KKObserver
//
//  Created by 张海龙 on 2017/12/4.
//  Copyright © 2017年 kkmofang.cn. All rights reserved.
//

#import "KKObserver.h"

#include <objc/runtime.h>

@interface KKKeyObserverCallback : NSObject {
    
}

@property(nonatomic,strong) NSArray * keys;
@property(nonatomic,strong) JSValue * evaluateScript;
@property(nonatomic,strong) KKObserverFunction func;
@property(nonatomic,strong) JSValue * jsFunction;
@property(nonatomic,assign) void * context;
@property(nonatomic,assign) BOOL children;

-(void) changeKeys:(NSArray *) keys ofObject:(id) object;

@end

@interface KKKeyObserver : NSObject {
    NSMutableDictionary * _children;
    NSMutableArray * _callbacks;
}

-(void) add:(NSArray *) keys idx:(int) idx cb:(KKKeyObserverCallback *) cb;

-(void) remove:(NSArray *) keys idx:(int) idx func:(KKObserverFunction) func jsFunction:(JSValue *) jsFunction context:(void *) context;

-(void) changeKeys:(NSArray *) keys idx:(int) idx ofObject:(id) object;

@end

@interface KKObserver() {
    KKKeyObserver * _keyObserver;
}

@end

@implementation KKObserver

-(instancetype) initWithJSContext:(JSContext *) jsContext{
    return [self initWithJSContext:jsContext object:[NSMutableDictionary dictionaryWithCapacity:4]];
}

-(instancetype) initWithJSContext:(JSContext *) jsContext object:(id) object {
    if((self = [super init])) {
        _jsContext = jsContext;
        _object = object;
        _keyObserver = [[KKKeyObserver alloc] init];
    }
    return self;
}

-(instancetype) init {
    return [self initWithJSContext:[KKObserver mainJSContext] object:[NSMutableDictionary dictionaryWithCapacity:4]];
}

-(instancetype) initWithObject:(id) object {
    return [self initWithJSContext:[KKObserver mainJSContext] object:object];
}

-(void) on:(void (^)(NSArray * keys)) cb evaluateScript:(NSString *) evaluateScript {
    
    NSRegularExpression * pattern = [NSRegularExpression regularExpressionWithPattern:@"[0-9a-zA-Z\\._]*" options:NSRegularExpressionCaseInsensitive error:nil];
    
    NSString * v = [evaluateScript stringByReplacingOccurrencesOfString:@"\\'" withString:@""];
    
    v = [evaluateScript stringByReplacingOccurrencesOfString:@"\\\"" withString:@""];
    
    v = [v stringByReplacingOccurrencesOfString:@"'.*?'" withString:@"''" options:NSRegularExpressionSearch range:NSMakeRange(0, [v length])];
    
    v = [v stringByReplacingOccurrencesOfString:@"\".*?\"" withString:@"\"\"" options:NSRegularExpressionSearch range:NSMakeRange(0, [v length])];
     
    [pattern enumerateMatchesInString:v options:NSMatchingReportProgress range:NSMakeRange(0, [v length]) usingBlock:^(NSTextCheckingResult *  result, NSMatchingFlags flags, BOOL * stop) {
        
        if(result.range.length >0) {
            
            NSArray * keys = [[v substringWithRange:result.range] componentsSeparatedByString:@"."];
            
            cb(keys);
            
        }
        
        * stop = NO;
    }];
    
}

-(void) on:(KKObserverFunction) func evaluateScript:(NSString *) evaluateScript context:(void *) context {
    
    KKKeyObserverCallback * cb = [[KKKeyObserverCallback alloc] init];
    cb.evaluateScript = [_jsContext evaluateScript:[NSString stringWithFormat:@"(function(object){ var _G; try { with(object) { _G = (%@); } } catch(e) { _G = e + ''; } return _G; })",evaluateScript]];
    cb.context = context;
    cb.func = func;
    
    [self on:^(NSArray *keys) {
        
        [_keyObserver add:keys idx:0 cb:cb];
        
    } evaluateScript:evaluateScript];
    
}

-(void) on:(KKObserverFunction) func keys:(NSArray *) keys children:(BOOL) children context:(void *) context {
    KKKeyObserverCallback * cb = [[KKKeyObserverCallback alloc] init];
    cb.keys = keys;
    cb.context = context;
    cb.func = func;
    cb.children = children;
    [_keyObserver add:keys idx:0 cb:cb];
}

-(void) on:(KKObserverFunction) func keys:(NSArray *) keys context:(void *) context {
    [self on:func keys:keys children:NO context:context];
}

-(void) off:(KKObserverFunction) func keys:(NSArray *) keys context:(void *) context {
    [_keyObserver remove:keys idx:0 func:func jsFunction:nil context:context];
}

-(void) ofObject:(NSMutableDictionary *) object {
    [_parent ofObject:object];
    
    id v = self.object;
    
    for(NSString * key in [v keySet]) {
        NSArray * keys = @[key];
        [object set:keys value:[v get:keys defaultValue:nil]];
    }
}

-(id) ofObject{
    NSMutableDictionary * object = [NSMutableDictionary dictionaryWithCapacity:4];
    [self ofObject:object];
    return object;
}

-(void) changeKeys:(NSArray *) keys {
    [_keyObserver changeKeys:keys idx:0 ofObject:[self ofObject]];
}

-(id) get:(NSArray *) keys defaultValue:(id) defaultValue {
    
    id v = nil;
    
    if(_object != nil) {
        
        if([keys count] == 0) {
            v = _object;
        } else {
            v = [_object get:keys defaultValue:nil];
        }
    }
    
    if(v != nil) {
        return v;
    }
    
    if(_parent != nil) {
        return [_parent get:keys defaultValue:defaultValue];
    }
    
    return defaultValue;
}

-(void) set:(NSArray *) keys value:(id) value {
    if([keys count] == 0) {
        _object = value;
    } else {
        if(_object == nil) {
            _object = [[NSMutableDictionary alloc] initWithCapacity:4];
        }
        [_object set:keys value:value];
    }
    [self changeKeys:keys];
}

-(void) setValue:(id)value forKey:(NSString *)key {
    [self set:[NSArray arrayWithObjects:key, nil] value:value];
}

-(void) setValue:(id)value forKeyPath:(NSString *)keyPath {
    [self set:[keyPath componentsSeparatedByString:@"."] value:value];
}

-(id) valueForKey:(NSString *)key {
    return [self get:[NSArray arrayWithObjects:key, nil] defaultValue:nil];
}

-(id) valueForKeyPath:(NSString *)keyPath {
    return [self get:[keyPath componentsSeparatedByString:@"."] defaultValue:nil];
}

-(id) evaluateScript:(NSString*) evaluateScript {
    
    if(_object == nil) {
        return nil;
    }
    
    JSValue * v = [_jsContext evaluateScript:[NSString stringWithFormat:@"(function(object){ var _G; try { with(object){ _G = (%@); } } catch(e) { _G = e + ''; } return _G; })",evaluateScript]];
    
    if(v != nil) {
        v = [v callWithArguments:[NSArray arrayWithObject:_object]];
    }
    
    return [v toObject];
}

-(void) onJSFunction:(JSValue *) func keys:(NSArray *) keys context:(JSValue *) context {
    KKKeyObserverCallback * cb = [[KKKeyObserverCallback alloc] init];
    cb.keys = keys;
    cb.context = (__bridge void *) context;
    cb.jsFunction = func;
    [_keyObserver add:keys idx:0 cb:cb];
}

-(void) onJSFunction:(JSValue *) func evaluateScript:(NSString *) evaluateScript context:(JSValue *) context{
    
    KKKeyObserverCallback * cb = [[KKKeyObserverCallback alloc] init];
    cb.evaluateScript = [_jsContext evaluateScript:[NSString stringWithFormat:@"(function(object){ var _G; try { with(object) { _G = (%@); } } catch(e) { _G = e; } return _G; })",evaluateScript]];
    cb.context = (__bridge void *) context;
    cb.jsFunction = func;
    
    [self on:^(NSArray *keys) {
        
        [_keyObserver add:keys idx:0 cb:cb];
        
    } evaluateScript:evaluateScript];
}

-(void) offJSFunction:(JSValue *) func keys:(NSArray *) keys context:(JSValue *) context {
    [_keyObserver remove:keys idx:0 func:nil jsFunction:func context:(__bridge void *) context];
}

static JSContext * MainJSContext = nil;

+(JSContext *) mainJSContext {
    if(MainJSContext == nil) {
        MainJSContext = [[JSContext alloc] init];
        MainJSContext.exceptionHandler = ^(JSContext *context, JSValue *exception) {
            NSLog(@"[KK] %@",exception);
        };
    }
    return MainJSContext;
}

+(void) setMainJSContext:(JSContext *) mainJSContext {
    MainJSContext = mainJSContext;
}

@end

@implementation KKKeyObserverCallback

-(void) changeKeys:(NSArray *) keys ofObject:(id) object {
    
    id v = nil;
    
    if(_evaluateScript != nil) {
        v = [[_evaluateScript callWithArguments:[NSArray arrayWithObjects:object, nil]] toObject];
    } else if(_keys != nil) {
        v = [object get:_keys defaultValue:nil];
    }
    
    if(_func != nil) {
        _func(v,keys,_context);
    }
    
    if(_jsFunction != nil) {
        if(v == nil) {
            v = [JSValue valueWithNullInContext:_jsFunction.context];
        }
        [_jsFunction callWithArguments:@[v,keys]];
    }
}

@end

@implementation KKKeyObserver

-(void) add:(NSArray *) keys idx:(int) idx cb:(KKKeyObserverCallback *) cb {
    if(idx < [keys count]) {
        NSString * key = [keys objectAtIndex:idx];
        KKKeyObserver * v = [_children objectForKey:key];
        if(v == nil) {
            v = [[KKKeyObserver alloc] init];
            if(_children ==nil) {
                _children = [[NSMutableDictionary alloc] initWithCapacity:4];
            }
            [_children setObject:v forKey:key];
        }
        [v add:keys idx:idx + 1 cb:cb];
    } else {
        if(_callbacks == nil) {
            _callbacks = [[NSMutableArray alloc] initWithCapacity:4];
        }
        [_callbacks addObject:cb];
    }
}

-(void) remove:(NSArray *) keys idx:(int) idx func:(KKObserverFunction) func jsFunction:(JSValue *) jsFunction context:(void *) context {
    
    if(idx < [keys count]) {
        
        NSString * key = [keys objectAtIndex:idx];
        
        if(context == nil && func == nil && jsFunction == nil) {
            [_children removeObjectForKey:key];
        } else {
            KKKeyObserver * v = [_children objectForKey:key];
            [v remove:keys idx:idx + 1 func:func jsFunction:jsFunction context:context];
        }
        
    } else {
        
        NSInteger i = (NSInteger) [_callbacks count] - 1;
        
        while( i >= 0 ) {
            
            KKKeyObserverCallback * cb = [_callbacks objectAtIndex:i];
            
            if((context == nil || cb.context == context) && (func == nil || cb.func == func)
               && (jsFunction == nil || cb.jsFunction == jsFunction)) {
                [_callbacks removeObjectAtIndex:i];
            }
            
            i -- ;
        }
        
    }
}

-(void) changeKeys:(NSArray *) keys idx:(int) idx ofObject:(id) object {
    
    if(idx < [keys count]) {
        
        NSString * key = [keys objectAtIndex:idx];
        KKKeyObserver * v = [_children objectForKey:key];
        
        [v changeKeys:keys idx:idx + 1 ofObject:object];
        
        NSMutableArray * cbs = [NSMutableArray arrayWithCapacity:4];
        
        for(KKKeyObserverCallback * cb in _callbacks) {
            if(cb.children) {
                [cbs addObject:cb];
            }
        }
        
        for(KKKeyObserverCallback * cb in cbs) {
            [cb changeKeys:keys ofObject:object];
        }
        
    } else {
        
        if(_callbacks != nil) {
            
            for(KKKeyObserverCallback * cb in [NSArray arrayWithArray:_callbacks]) {
                [cb changeKeys:keys ofObject:object];
            }
            
        }
        
        if(_children != nil) {
            for(KKKeyObserver * v in [NSArray arrayWithArray:[_children allValues]]) {
                [v changeKeys:keys idx:idx ofObject:object];
            }
        }
    }
    
}

@end

@implementation NSObject(KKObserver)

-(id) get:(NSArray *) keys defaultValue:(id) defaultValue {
    
    id v = self;
    
    for(NSString * key in keys) {
        
        @try {
            v = [v valueForKey:key];
        }
        @catch(NSException *ex){
            v = nil;
            NSLog(@"[KK] %@",ex);
        }
        
        if(v == nil) {
            break;
        }
    }
    
    return v;
}

-(void) set:(NSArray *) keys value:(id) value {
    
    id v = self;
    
    NSInteger i =0;
    
    while(i < [keys count] - 1) {
        
        NSString * key = [keys objectAtIndex:i];
        
        @try {
            id vv = [v valueForKey:key];
            if(vv == nil) {
                vv = [NSMutableDictionary dictionaryWithCapacity:4];
                [v setValue:vv forKey:key];
            }
            v = vv;
        }
        @catch(NSException *ex){
            v = nil;
            NSLog(@"[KK] %@",ex);
        }
        
        if(v == nil) {
            break;
        }
        
        i ++;
    }
    
    if(v != nil && i < [keys count]) {
        
        NSString * key = [keys objectAtIndex:i];
        
        @try {
            [v setValue:value forKey:key];
        }
        @catch(NSException *ex){
            NSLog(@"[KK] %@",ex);
        }
    }
    
    
}

-(NSSet *) keySet {
    
    NSMutableSet * keys = [NSMutableSet setWithCapacity:4];
    
    Class isa = [self class];
    
    while(isa != nil) {
        
        unsigned int count = 0;
        objc_property_t * p = class_copyPropertyList(isa, &count);
        
        for(unsigned int i=0;i<count;i++) {
            NSString * key = [NSString stringWithCString:property_getName(p[0]) encoding:NSUTF8StringEncoding];
            [keys addObject:key];
        }
        
        if(p) {
            free(p);
        }
        
        isa = class_getSuperclass(isa);
    }
    
    return keys;
}

@end

@implementation NSArray(KKObserver)

-(id) valueForKey:(NSString *)key {
    
    if([@"length" isEqualToString:key]) {
        return @([self count]);
    }
    
    NSInteger i =[key integerValue];
    
    if(i >=0 && i < [self count]) {
        return [self objectAtIndex:i];
    }
    
    return nil;
}

-(NSSet *) keySet {
    NSMutableSet * keys = [NSMutableSet setWithCapacity:4];
    for(NSInteger i= 0;i<[self count];i++) {
        [keys addObject:[NSString stringWithFormat:@"%ld",i]];
    }
    return keys;
}

@end

@implementation NSDictionary(KKObserver)

-(NSSet *) keySet {
    NSMutableSet * keys = [NSMutableSet setWithCapacity:4];
    NSEnumerator * keyEnum = [self keyEnumerator];
    NSString * key;
    while((key = [keyEnum nextObject])) {
        [keys addObject:key];
    }
    return keys;
}

@end
