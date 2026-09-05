#import <Foundation/Foundation.h>
#include <stdio.h>

@interface Log : NSObject
+ (void) log: (char *) s;
@end

@implementation Log

+ (void) log: (char *) s {
    printf("%s\n", s);
    fflush(stdout);
    NSLog(@"%s", s);
}

@end
