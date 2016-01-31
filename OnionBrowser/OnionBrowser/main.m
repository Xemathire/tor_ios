//
//  main.m
//  OnionBrowser
//
//  Copyright (c) 2012 Mike Tigas. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "AppDelegate.h"

#import "ProxyURLProtocol.h"

int main(int argc, char *argv[]) {
    @autoreleasepool {
        [NSURLProtocol registerClass:[ProxyURLProtocol class]];
        // signal(SIGPIPE, SIG_IGN);
        
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
