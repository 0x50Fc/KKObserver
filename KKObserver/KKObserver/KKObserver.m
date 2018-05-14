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

@property(nonatomic,assign) NSInteger priority;
@property(nonatomic,strong) NSArray * keys;
@property(nonatomic,strong) JSValue * evaluateScript;
@property(nonatomic,strong) KKObserverFunction func;
@property(nonatomic,strong) JSValue * jsFunction;
@property(nonatomic,assign) void * context;
@property(nonatomic,assign) BOOL children;

-(void) changeKeys:(NSArray *) keys observer:(KKObserver *) observer;

@end

@interface KKKeyObserver : NSObject {
    NSMutableDictionary * _children;
    NSMutableArray * _callbacks;
}

-(void) add:(NSArray *) keys idx:(int) idx cb:(KKKeyObserverCallback *) cb;

-(void) remove:(NSArray *) keys idx:(int) idx func:(KKObserverFunction) func jsFunction:(JSValue *) jsFunction context:(void *) context;

-(void) changeKeys:(NSArray *) keys idx:(int) idx callbacks:(NSMutableArray *) callbacks;

@end

@interface KKObserver() {
    KKKeyObserver * _keyObserver;
    NSInteger _priorityDesc;
    NSInteger _priorityAsc;
}

@end

@implementation KKObserver

-(void) dealloc {
    NSLog(@"[KK] KKObserver dealloc");
    [_parent off:nil keys:@[] context:(__bridge void *) self];
}

-(NSUInteger) count {
    return 0;
}

-(void) setParent:(KKObserver *)parent {
    
    if(_parent != parent) {
        
        [_parent off:nil keys:@[] context:(__bridge void *)self];
        
        _parent = parent;
        
        __weak KKObserver * v = self;
        
        [_parent on:^(id value, NSArray *changedKeys, void *context) {
            if(v) {
                [v set:changedKeys value:[value kk_get:changedKeys defaultValue:nil]];
            }
        } keys:@[] children:YES context:(__bridge void *)self];
        
        [_object setDictionary:[_parent object]];
        
        [self changeKeys:@[]];
        
    }
}

-(instancetype) newObserver {
    return [[[self class] alloc] initWithJSContext:self.jsContext];
}

-(instancetype) initWithJSContext:(JSContext *) jsContext{
    return [self initWithJSContext:jsContext object:[NSMutableDictionary dictionaryWithCapacity:4]];
}

-(instancetype) initWithJSContext:(JSContext *) jsContext object:(NSMutableDictionary *) object {
    if((self = [super init])) {
        _priorityDesc = INT32_MAX;
        _priorityAsc = INT32_MIN;
        _jsContext = jsContext;
        _object = object;
        _keyObserver = [[KKKeyObserver alloc] init];
        
        if(jsContext.exceptionHandler == nil) {
            jsContext.exceptionHandler = ^(JSContext *context, JSValue *v) {
                if([v hasProperty:@"column"] && [v hasProperty:@"line"]) {
                    NSLog(@"[KK] (%@,%@) %@"
                          ,[[v valueForProperty:@"line"] toObject]
                          ,[[v valueForProperty:@"column"] toObject]
                          ,[v description]);
                } else {
                    NSLog(@"[KK] %@",[v description]);
                }
            };
        }
        
        if([_jsContext[@"print"] isUndefined]) {
            
            _jsContext[@"print"] = ^(void){
                
                for(JSValue * v in [JSContext currentArguments]) {
                    if([v hasProperty:@"column"] && [v hasProperty:@"line"]) {
                        NSLog(@"[KK] (%@,%@) %@"
                              ,[[v valueForProperty:@"line"] toObject]
                              ,[[v valueForProperty:@"column"] toObject]
                              ,[v description]);
                    } else {
                        NSLog(@"[KK] %@",[v toObject]);
                    }
                }
                
            };
            
        }
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
    
    NSRegularExpression * pattern = [NSRegularExpression regularExpressionWithPattern:@"[a-zA-Z][0-9a-zA-Z\\._]*" options:NSRegularExpressionCaseInsensitive error:nil];
    
    NSString * v = [evaluateScript stringByReplacingOccurrencesOfString:@"\\'" withString:@""];
    
    v = [evaluateScript stringByReplacingOccurrencesOfString:@"\\\"" withString:@""];
    
    v = [v stringByReplacingOccurrencesOfString:@"'.*?'" withString:@"''" options:NSRegularExpressionSearch range:NSMakeRange(0, [v length])];
    
    v = [v stringByReplacingOccurrencesOfString:@"\".*?\"" withString:@"\"\"" options:NSRegularExpressionSearch range:NSMakeRange(0, [v length])];
    
    [pattern enumerateMatchesInString:v options:NSMatchingReportProgress range:NSMakeRange(0, [v length]) usingBlock:^(NSTextCheckingResult *  result, NSMatchingFlags flags, BOOL * stop) {
        
        if(result.range.length >0) {
            
            NSArray * keys = [[v substringWithRange:result.range] componentsSeparatedByString:@"."];
            
            if([keys count] ==0 || [keys[0] hasPrefix:@"_"]) {
                return;
            }
            
            cb(keys);
            
        }
        
        * stop = NO;
    }];
    
}

-(void) on:(KKObserverFunction) func evaluateScript:(NSString *) evaluateScript context:(void *) context {
    [self on:func evaluateScript:evaluateScript priority:KKOBSERVER_PRIORITY_NORMAL context:context];
}

-(void) on:(KKObserverFunction) func evaluateScript:(NSString *) evaluateScript priority:(NSInteger) priority context:(void *) context {
    
    KKKeyObserverCallback * cb = [[KKKeyObserverCallback alloc] init];
    cb.evaluateScript = [_jsContext evaluateScript:[NSString stringWithFormat:@"(function(object){ var _G; try { with(object) { _G = (%@); } } catch(e) { _G = undefined; } return _G; })",evaluateScript]];
    cb.context = context;
    cb.func = func;
    if(priority == KKOBSERVER_PRIORITY_ASC) {
        cb.priority = (++ _priorityAsc);
    } else if(priority == KKOBSERVER_PRIORITY_DESC) {
        cb.priority = (-- _priorityDesc);
    } else {
        cb.priority = priority;
    }
    
    [self on:^(NSArray *keys) {
        
        [_keyObserver add:keys idx:0 cb:cb];
        
    } evaluateScript:evaluateScript];
    
}

-(void) on:(KKObserverFunction) func keys:(NSArray *) keys children:(BOOL) children context:(void *) context {
    [self on:func keys:keys children:children priority: 0 context:context];
}

-(void) on:(KKObserverFunction) func keys:(NSArray *) keys children:(BOOL) children priority:(NSInteger) priority context:(void *) context {
    KKKeyObserverCallback * cb = [[KKKeyObserverCallback alloc] init];
    if(priority == KKOBSERVER_PRIORITY_ASC) {
        cb.priority = (++ _priorityAsc);
    } else if(priority == KKOBSERVER_PRIORITY_DESC) {
        cb.priority = (-- _priorityDesc);
    } else {
        cb.priority = priority;
    }
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

-(void) changeKeys:(NSArray *) keys {
    NSMutableArray * callbacks = [NSMutableArray arrayWithCapacity:4];
    [_keyObserver changeKeys:keys idx:0 callbacks:callbacks];
    [callbacks sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSInteger a = [(KKKeyObserverCallback *) obj1 priority];
        NSInteger b = [(KKKeyObserverCallback *) obj2 priority];
        if(a == b) {
            return NSOrderedSame;
        } else if(a < b) {
            return NSOrderedDescending;
        }
        return NSOrderedAscending;
    }];
    for(KKKeyObserverCallback * cb in callbacks) {
        [cb changeKeys:keys observer:self];
    }
}

-(id) get:(NSArray *) keys defaultValue:(id) defaultValue {
    
    id v = nil;
    
    if(_object != nil) {
        
        if([keys count] == 0) {
            v = _object;
        } else {
            v = [_object kk_get:keys defaultValue:nil];
        }
    }
    
    if(v != nil) {
        return v;
    }
    
    if(_parent != nil) {
        return [_parent kk_get:keys defaultValue:defaultValue];
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
        [_object kk_set:keys value:value];
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
    
    JSValue * v = [_jsContext evaluateScript:[NSString stringWithFormat:@"(function(object){ var _G; try { with(object){ _G = (%@); } } catch(e) { _G = undefined; } return _G; })",evaluateScript]];
    
    if(v != nil) {
        v = [v callWithArguments:[NSArray arrayWithObject:_object]];
    }
    
    if([v isUndefined] || [v isNull]) {
        return nil;
    }
    
    return [v toObject];
}

-(void) on:(NSArray *) keys fn:(JSValue *) func context:(void *) context {
    KKKeyObserverCallback * cb = [[KKKeyObserverCallback alloc] init];
    cb.keys = keys;
    cb.context = context;
    cb.jsFunction = func;
    [_keyObserver add:keys idx:0 cb:cb];
}

-(void) onEvaluateScript:(NSString *) evaluateScript fn:(JSValue *) func  context:(void *) context{
    
    KKKeyObserverCallback * cb = [[KKKeyObserverCallback alloc] init];
    cb.evaluateScript = [_jsContext evaluateScript:[NSString stringWithFormat:@"(function(object){ var _G; try { with(object) { _G = (%@); } } catch(e) { _G = undefined; } return _G; })",evaluateScript]];
    cb.context = context;
    cb.jsFunction = func;
    
    [self on:^(NSArray *keys) {
        
        [_keyObserver add:keys idx:0 cb:cb];
        
    } evaluateScript:evaluateScript];
}

-(void) off:(NSArray *) keys fn:(JSValue *) func context:(void *) context {
    [_keyObserver remove:keys idx:0 func:nil jsFunction:func context:context];
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

-(void) changeKeys:(NSArray *) keys observer:(KKObserver *) observer {
    
    id v = nil;
    
    if(_evaluateScript != nil) {
        v = [_evaluateScript callWithArguments:[NSArray arrayWithObjects:[observer object], nil]];
        if([v isNull] || [v isUndefined]) {
            v = nil;
        } else {
            v = [v toObject];
        }
    } else if(_keys != nil) {
        v = [observer get:_keys defaultValue:nil];
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
        
    } else if(func == nil && jsFunction == nil && context == nil){
        
        _callbacks = [[NSMutableArray alloc] initWithCapacity:4];
        _children = [[NSMutableDictionary alloc] initWithCapacity:4];
        
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
        
        {
            NSEnumerator * keyEnum = [_children keyEnumerator];
            NSString * key;
            while((key = [keyEnum nextObject])) {
                KKKeyObserver * v = [_children objectForKey:key];
                [v remove:keys idx:idx func:func jsFunction:jsFunction context:context];
            }
        }
        
        
        
        
    }
}

-(void) changeKeys:(NSArray *) keys idx:(int) idx callbacks:(NSMutableArray *)callbacks {
    
    if(idx < [keys count]) {
        
        NSString * key = [keys objectAtIndex:idx];
        KKKeyObserver * v = [_children objectForKey:key];
        
        [v changeKeys:keys idx:idx + 1 callbacks:callbacks];
        
        for(KKKeyObserverCallback * cb in _callbacks) {
            if(cb.children) {
                [callbacks addObject:cb];
            }
        }
        
    } else {
        
        if(_callbacks != nil) {
            
            [callbacks addObjectsFromArray:_callbacks];
            
        }
        
        if(_children != nil) {
            for(KKKeyObserver * v in [NSArray arrayWithArray:[_children allValues]]) {
                [v changeKeys:keys idx:idx callbacks:callbacks];
            }
        }
    }
    
}

@end

@implementation NSObject(KKObserver)

-(NSString *) kk_stringValue {
    if([self isKindOfClass:[NSString class]]) {
        return (NSString *) self;
    }
    if([self respondsToSelector:@selector(stringValue)]){
        return [(NSNumber *) self stringValue];
    }
    return nil;
}

-(NSString *) kk_getString:(NSString *) key {
    return [[self kk_getValue:key] kk_stringValue];
}

-(id) kk_getValue:(NSString *) key {
    @try {
        return [self valueForKey:key];
    }
    @catch(NSException * ex) {
        NSLog(@"[KK] %@",ex);
    }
    return nil;
}

-(void) kk_setValue:(NSString *) key value:(id) value {
    @try {
        return [self setValue:value forKey:key];
    }
    @catch(NSException * ex) {
        NSLog(@"[KK] %@",ex);
    }
}

-(id) kk_get:(NSArray *) keys defaultValue:(id) defaultValue {
    
    id v = self;
    
    for(NSString * key in keys) {
        
        v = [v kk_getValue:key];
        
        if(v == nil) {
            break;
        }
    }
    
    return v;
}

-(void) kk_set:(NSArray *) keys value:(id) value {
    
    id v = self;
    
    NSInteger i =0;
    
    while(i < [keys count] - 1) {
        
        NSString * key = [keys objectAtIndex:i];
        
        id vv = [v kk_getValue:key];
        
        if(vv == nil) {
            vv = [NSMutableDictionary dictionaryWithCapacity:4];
            [v kk_setValue:key value:vv];
        }
        
        v = vv;
        
        if(v == nil) {
            break;
        }
        
        i ++;
    }
    
    if(v != nil && i < [keys count]) {
        
        NSString * key = [keys objectAtIndex:i];
        
        [v kk_setValue:key value:value];
        
    }
    
    
}

-(NSSet *) kk_keySet {
    
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

-(id) kk_getValue:(NSString *)key{
    
    if([@"length" isEqualToString:key]) {
        return @([self count]);
    }
    
    NSInteger i =[key integerValue];
    
    if(i >=0 && i < [self count]) {
        return [self objectAtIndex:i];
    }
    
    return nil;
}

-(NSSet *) kk_keySet {
    NSMutableSet * keys = [NSMutableSet setWithCapacity:4];
    for(int i= 0;i<[self count];i++) {
        [keys addObject:[NSString stringWithFormat:@"%d",i]];
    }
    return keys;
}

@end

@implementation NSDictionary(KKObserver)

-(NSSet *) kk_keySet {
    NSMutableSet * keys = [NSMutableSet setWithCapacity:4];
    NSEnumerator * keyEnum = [self keyEnumerator];
    NSString * key;
    while((key = [keyEnum nextObject])) {
        [keys addObject:key];
    }
    return keys;
}

@end
