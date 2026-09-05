#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <stdio.h>

@interface Log : NSObject
+ (void) log: (char *) s;
@end

static void uncaught_exception_handler(NSException *exception) {
    NSLog(@"💥 UNCAUGHT OBJC EXCEPTION: %@ - %@", exception.name, exception.reason);
    fprintf(stderr, "\n========================================\n");
    fprintf(stderr, "💥 UNCAUGHT OBJC EXCEPTION: %s: %s\n",
            [[exception name] UTF8String],
            [[exception reason] UTF8String]);
    fprintf(stderr, "Call stack:\n");
    for (NSString *frame in [exception callStackSymbols]) {
        fprintf(stderr, "  %s\n", [frame UTF8String]);
    }
    fprintf(stderr, "========================================\n");
    fflush(stderr);

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (paths.count > 0) {
        NSString *crashFile = [paths[0] stringByAppendingPathComponent:@"crash_report.log"];
        NSString *report = [NSString stringWithFormat:@"\n💥 UNCAUGHT OBJC EXCEPTION: %@: %@\nCall stack:\n%@\n========================================\n",
                            exception.name, exception.reason, [exception.callStackSymbols componentsJoinedByString:@"\n"]];
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:crashFile];
        if (!handle) {
            [[NSFileManager defaultManager] createFileAtPath:crashFile contents:[report dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
        } else {
            [handle seekToEndOfFile];
            [handle writeData:[report dataUsingEncoding:NSUTF8StringEncoding]];
            [handle closeFile];
        }
    }
}

@implementation Log

+ (void)load {
    NSSetUncaughtExceptionHandler(&uncaught_exception_handler);
}

+ (void) log: (char *) s {
    printf("%s\n", s);
    fflush(stdout);
    NSLog(@"%s", s);
}

@end

// Ensure UIWindow operations from background SDL/Ren'Py threads are safely dispatched to the main thread
@interface UIWindow (MainThreadSafe)
@end

@implementation UIWindow (MainThreadSafe)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = [UIWindow class];

        SEL origMakeKey = @selector(makeKeyAndVisible);
        SEL safeMakeKey = @selector(safe_makeKeyAndVisible);
        Method origM = class_getInstanceMethod(cls, origMakeKey);
        Method safeM = class_getInstanceMethod(cls, safeMakeKey);
        if (origM && safeM) {
            method_exchangeImplementations(origM, safeM);
        }

        SEL origRoot = @selector(setRootViewController:);
        SEL safeRoot = @selector(safe_setRootViewController:);
        Method origRootM = class_getInstanceMethod(cls, origRoot);
        Method safeRootM = class_getInstanceMethod(cls, safeRoot);
        if (origRootM && safeRootM) {
            method_exchangeImplementations(origRootM, safeRootM);
        }
    });
}

- (void)safe_makeKeyAndVisible {
    if ([NSThread isMainThread]) {
        [self safe_makeKeyAndVisible];
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self safe_makeKeyAndVisible];
        });
    }
}

- (void)safe_setRootViewController:(UIViewController *)rootViewController {
    if ([NSThread isMainThread]) {
        [self safe_setRootViewController:rootViewController];
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self safe_setRootViewController:rootViewController];
        });
    }
}

@end
