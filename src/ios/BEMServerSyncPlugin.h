#import <Cordova/CDV.h>

@interface BEMServerSyncPlugin: CDVPlugin <UINavigationControllerDelegate>

- (void) forceSync:(CDVInvokedUrlCommand*)command;

@end
