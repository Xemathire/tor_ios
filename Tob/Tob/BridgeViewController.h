//
//  BridgeViewController.h
//  OnionBrowser
//
//  Created by Mike Tigas on 3/10/15.
//
//

#import <UIKit/UIKit.h>
#import "QRCodeReaderViewController.h"

@interface BridgeViewController : UIViewController <QRCodeReaderDelegate>

- (void)qrscan;
- (void)saveAndExit;
- (void)saveAndExit:(Boolean)shouldSaveAndExit;
- (void)cancel;

- (void)exitModal;

@end
