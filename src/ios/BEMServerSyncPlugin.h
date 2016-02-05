#import <Cordova/CDV.h>

@interface BEMServerSyncPlugin: CDVPlugin <UINavigationControllerDelegate>

/* 
 * Currently unused. Depending on what we choose to do wrt remote
 * notifications, visit notification, etc, here's where we will sign up for
 * events if needed.
 */

- (void) init:(CDVInvokedUrlCommand*)command;
- (void) forceSync:(CDVInvokedUrlCommand*)command;

@end
