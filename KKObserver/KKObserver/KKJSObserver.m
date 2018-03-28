//
//  KKJSObserver.m
//  KKObserver
//
//  Created by hailong11 on 2018/3/28.
//  Copyright © 2018年 kkmofang.cn. All rights reserved.
//

#import "KKJSObserver.h"
#import "KKObserver.h"

@implementation KKJSObserver

@synthesize observer = _observer;

-(instancetype) initWithObserver:(KKObserver *) observer {
    if((self = [super init])) {
        _observer = observer;
    }
    return self;
}

-(void) recycle {
    [_observer off:nil keys:@[] context:nil];
    _observer = nil;
}

-(void) changeKeys:(NSArray *) keys{
    [_observer changeKeys:keys];
}

-(id) get:(NSArray *) keys defaultValue:(id) defaultValue {
    return [_observer get:keys defaultValue:defaultValue];
}

-(void) set:(NSArray *) keys value:(id) value {
    [_observer set:keys value:value];
}

-(void) on:(NSArray *) keys fn:(JSValue *) func context:(JSValue *) context {
    [_observer on:keys fn:func context:context];
}

-(void) onEvaluateScript:(NSString *) evaluateScript fn:(JSValue *) func  context:(JSValue *) context {
    [_observer onEvaluateScript:evaluateScript fn:func context:context];
}

-(void) off:(NSArray *) keys fn:(JSValue *) func context:(JSValue *) context {
    [_observer off:keys fn:func context:context];
}

-(instancetype) newObserver {
    return [[KKJSObserver alloc] initWithObserver:[_observer newObserver]];
}
@end
