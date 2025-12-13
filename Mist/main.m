//
//  main.m
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import <Cocoa/Cocoa.h>
#import "App/MSTAppDelegate.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        MSTAppDelegate *delegate = [[MSTAppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
