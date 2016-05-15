//
//  main.m
//  Tob
//
//  Created by Jean-Romain on 26/04/2016.
//  Copyright © 2016 JustKodding. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#import "ProxyURLProtocol.h"

int main(int argc, char * argv[]) {
    @autoreleasepool {
        [NSURLProtocol registerClass:[ProxyURLProtocol class]];
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
