// One explicit root-operated action; no autoload hook, command listener or passcode bypass.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <sys/stat.h>
static void Reply(NSDictionary *request,NSDictionary *result){
    NSString *path=[request objectForKey:@"resultPath"];
    if(![path hasPrefix:@"/var/mobile/Library/Caches/codex-device-access-"] || ![[path pathExtension] isEqual:@"plist"])return;
    NSMutableDictionary *out=[NSMutableDictionary dictionaryWithDictionary:result];[out setObject:[request objectForKey:@"nonce"] forKey:@"nonce"];
    [out writeToFile:path atomically:YES];chmod([path fileSystemRepresentation],0600);
}
static BOOL BoolGetter(id object,SEL selector,BOOL *value){
    NSMethodSignature *signature=[object methodSignatureForSelector:selector];
    if(!signature || signature.numberOfArguments!=2 || signature.methodReturnLength!=sizeof(BOOL))return NO;
    *value=((BOOL (*)(id,SEL))objc_msgSend)(object,selector);return YES;
}
static id Singleton(NSString *name,NSString *method){
    Class type=NSClassFromString(name);SEL selector=NSSelectorFromString(method);
    NSMethodSignature *signature=[type methodSignatureForSelector:selector];
    if(!signature||signature.numberOfArguments!=2||strcmp(signature.methodReturnType,@encode(id)))return nil;
    return ((id (*)(id,SEL))objc_msgSend)(type,selector);
}
static void ModernAccess(NSDictionary *request){
    dlopen("/System/Library/PrivateFrameworks/ManagedConfiguration.framework/ManagedConfiguration",RTLD_LAZY|RTLD_LOCAL);
    id controller=Singleton(@"SBLockScreenManager",@"sharedInstance");
    id policy=Singleton(@"MCProfileConnection",@"sharedConnection");
    BOOL protected=YES,locked=YES;
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    if(!BoolGetter(policy,NSSelectorFromString(@"isPasscodeSet"),&protected)||!BoolGetter(controller,NSSelectorFromString(@"isUILocked"),&locked)){
        [result setObject:@"refused-unknown-runtime" forKey:@"result"];Reply(request,result);return;
    }
    [result setObject:@(protected) forKey:@"passcodeProtected"];[result setObject:@(locked) forKey:@"locked"];
    NSString *action=[request objectForKey:@"action"];
    if([action isEqual:@"status"]){[result setObject:@"status" forKey:@"result"];Reply(request,result);return;}
    if(protected||[[request objectForKey:@"simulatePasscode"]boolValue]){[result setObject:@"refused-passcode" forKey:@"result"];Reply(request,result);return;}
    BOOL unlocking=[action isEqual:@"unlock"];
    id target=unlocking?controller:Singleton(@"SBUserAgent",@"sharedUserAgent");
    SEL selector=NSSelectorFromString(unlocking?@"unlockUIFromSource:withOptions:":@"lockAndDimDevice");
    NSMethodSignature *signature=[target methodSignatureForSelector:selector];
    if(!signature||signature.numberOfArguments!=(unlocking?4:2)||strcmp(signature.methodReturnType,@encode(void))||(unlocking&&(strcmp([signature getArgumentTypeAtIndex:2],@encode(int))||strcmp([signature getArgumentTypeAtIndex:3],@encode(id))))){
        [result setObject:@"refused-unknown-method" forKey:@"result"];Reply(request,result);return;
    }
    if(unlocking&&locked){
        id app=Singleton(@"UIApplication",@"sharedApplication");SEL wake=NSSelectorFromString(@"resetIdleTimerAndUndim");NSMethodSignature *w=[app methodSignatureForSelector:wake];
        if(!w||w.numberOfArguments!=2||strcmp(w.methodReturnType,@encode(void))){[result setObject:@"refused-unknown-wake-method" forKey:@"result"];Reply(request,result);return;}
        ((void (*)(id,SEL))objc_msgSend)(app,wake);
    }
    if(unlocking&&locked)((void (*)(id,SEL,int,id))objc_msgSend)(target,selector,0,nil);
    else if(!unlocking&&!locked)((void (*)(id,SEL))objc_msgSend)(target,selector);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/2),dispatch_get_main_queue(),^{
        NSAutoreleasePool *pool=[NSAutoreleasePool new];BOOL now=YES;
        if(!BoolGetter(controller,NSSelectorFromString(@"isUILocked"),&now))[result setObject:@"refused-unknown-runtime" forKey:@"result"];
        else{[result setObject:@(now)forKey:@"locked"];[result setObject:(unlocking?!now:now)?(unlocking?@"unlocked":@"locked"):@"state-change-failed" forKey:@"result"];}
        Reply(request,result);[pool drain];
    });
}
__attribute__((constructor)) static void Access(void){
    Dl_info image;if(!dladdr((void *)&Access,&image))return;
    // Keep queued main-thread code mapped after the injector closes its handle.
    if(!dlopen(image.dli_fname,RTLD_LAZY|RTLD_LOCAL|RTLD_NODELETE))return;
    NSString *folder=[[NSString stringWithUTF8String:image.dli_fname] stringByDeletingLastPathComponent];
    if(![folder hasPrefix:@"/var/tmp/codex-device-access-"])return;
    NSDictionary *request=[NSDictionary dictionaryWithContentsOfFile:[folder stringByAppendingPathComponent:@"request.plist"]];if(!request)return;
    dispatch_async(dispatch_get_main_queue(),^{
        NSAutoreleasePool *pool=[NSAutoreleasePool new];
        @try{
            NSDictionary *system=[NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
            if([[system objectForKey:@"ProductVersion"]intValue]==7){ModernAccess(request);[pool drain];return;}
            Class type=NSClassFromString(@"SBAwayController");SEL shared=NSSelectorFromString(@"sharedAwayController");id controller=[type respondsToSelector:shared]?[type performSelector:shared]:nil;
            BOOL protected=YES,locked=YES;
            id passcodeController=controller;
            if(![passcodeController respondsToSelector:NSSelectorFromString(@"isPasswordProtected")]){
                Class lockType=NSClassFromString(@"SBDeviceLockController");SEL singleton=NSSelectorFromString(@"sharedController");
                passcodeController=[lockType respondsToSelector:singleton]?[lockType performSelector:singleton]:nil;
            }
            NSMutableDictionary *result=[NSMutableDictionary dictionary];
            if(!BoolGetter(passcodeController,NSSelectorFromString(@"isPasswordProtected"),&protected) || !BoolGetter(controller,NSSelectorFromString(@"isLocked"),&locked)){
                NSMutableArray *methods=[NSMutableArray array];unsigned count=0;Method *list=class_copyMethodList(type,&count);
                for(unsigned i=0;i<count;i++){NSString *name=NSStringFromSelector(method_getName(list[i]));if([name rangeOfString:@"lock" options:NSCaseInsensitiveSearch].location!=NSNotFound || [name rangeOfString:@"password" options:NSCaseInsensitiveSearch].location!=NSNotFound)[methods addObject:name];}free(list);
                [result setObject:@"refused-unknown-runtime" forKey:@"result"];[result setObject:methods forKey:@"methods"];Reply(request,result);[pool drain];return;
            }
            [result setObject:[NSNumber numberWithBool:protected] forKey:@"passcodeProtected"];[result setObject:[NSNumber numberWithBool:locked] forKey:@"wasLocked"];
            NSString *action=[request objectForKey:@"action"];
            if([action isEqual:@"status"]){[result setObject:@"status" forKey:@"result"];[result setObject:[NSNumber numberWithBool:locked] forKey:@"locked"];Reply(request,result);}
            else if(protected || [[request objectForKey:@"simulatePasscode"] boolValue]){[result setObject:@"refused-passcode" forKey:@"result"];[result setObject:[NSNumber numberWithBool:locked] forKey:@"locked"];Reply(request,result);}
            else{
                BOOL unlocking=[action isEqual:@"unlock"];
                BOOL legacy=[controller respondsToSelector:NSSelectorFromString(@"unlockWithSound:isAutoUnlock:")];
                BOOL uiLock=!unlocking&&!legacy;
                id target=controller;
                if(uiLock){Class ui=NSClassFromString(@"SBUIController");SEL singleton=NSSelectorFromString(@"sharedInstance");target=[ui respondsToSelector:singleton]?[ui performSelector:singleton]:nil;}
                SEL method=NSSelectorFromString(uiLock?@"lockFromSource:":unlocking?(legacy?@"unlockWithSound:isAutoUnlock:":@"unlockWithSound:"):@"lock");NSMethodSignature *signature=[target methodSignatureForSelector:method];
                BOOL valid=signature && !strcmp(signature.methodReturnType,"v") && signature.numberOfArguments==(uiLock?3:(unlocking?(legacy?4:3):2));
                if(valid)for(NSUInteger i=2;i<signature.numberOfArguments;i++)if(strcmp([signature getArgumentTypeAtIndex:i],uiLock?@encode(int):@encode(BOOL)))valid=NO;
                if(!valid){[result setObject:@"refused-unknown-method" forKey:@"result"];Reply(request,result);}
                else{
                    void (^change)(void)=^{
                        if(unlocking && locked){if(legacy)((void (*)(id,SEL,BOOL,BOOL))objc_msgSend)(controller,method,NO,NO);else ((void (*)(id,SEL,BOOL))objc_msgSend)(controller,method,NO);}
                        else if(uiLock)((void (*)(id,SEL,int))objc_msgSend)(target,method,0);
                        else if(!unlocking && !locked)((void (*)(id,SEL))objc_msgSend)(target,method);
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/2),dispatch_get_main_queue(),^{
                            NSAutoreleasePool *p=[NSAutoreleasePool new];BOOL now=YES;BoolGetter(controller,NSSelectorFromString(@"isLocked"),&now);
                            [result setObject:[NSNumber numberWithBool:now] forKey:@"locked"];
                            [result setObject:(unlocking?!now:now)?(unlocking?@"unlocked":@"locked"):@"state-change-failed" forKey:@"result"];Reply(request,result);[p drain];
                        });
                    };
                    if(unlocking && locked && !legacy){
                        Class appClass=NSClassFromString(@"UIApplication");SEL sharedApp=NSSelectorFromString(@"sharedApplication");id app=[appClass respondsToSelector:sharedApp]?[appClass performSelector:sharedApp]:nil;SEL wake=NSSelectorFromString(@"resetIdleTimerAndUndim");NSMethodSignature *wakeSignature=[app methodSignatureForSelector:wake];
                        if(!wakeSignature || strcmp(wakeSignature.methodReturnType,"v") || wakeSignature.numberOfArguments!=2){[result setObject:@"refused-unknown-wake-method" forKey:@"result"];Reply(request,result);}
                        else{
                            // SpringBoard's display state can be asleep while SBAwayController reports undimmed.
                            ((void (*)(id,SEL))objc_msgSend)(app,wake);
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/2),dispatch_get_main_queue(),change);
                        }
                    }else change();
                }
            }
        }@catch(NSException *error){Reply(request,[NSDictionary dictionaryWithObjectsAndKeys:@"error",@"result",error.description,@"error",nil]);}
        [pool drain];
    });
}
