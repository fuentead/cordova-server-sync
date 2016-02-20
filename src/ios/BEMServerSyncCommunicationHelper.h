//
//  DataUtils.h
//  CFC_Tracker
//
//  Created by Kalyanaraman Shankari on 3/9/15.
//  Copyright (c) 2015 Kalyanaraman Shankari. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "Bolts/BFTask.h"

typedef void (^SilentPushCompletionHandler)(UIBackgroundFetchResult);

@interface BEMServerSyncCommunicationHelper: NSObject
// Top level method
+ (BFTask*) backgroundSync;

// Wrappers around the communication methods
+ (BFTask*) pushAndClearUserCache;
+ (BFTask*) pullIntoUserCache;
+ (BFTask*) pushAndClearStats;

// Communication methods (copied from communication handler to make it generic)
+(void)phone_to_server:(NSArray*) entriesToPush
     completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;
+(void)server_to_phone:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;
+(void)setClientStats:(NSDictionary*)statsToSend completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;

+ (NSInteger)fetchedData:(NSData *)responseData;
@end
