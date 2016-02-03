//
//  DataUtils.m
//  CFC_Tracker
//
//  Created by Kalyanaraman Shankari on 3/9/15.
//  Copyright (c) 2015 Kalyanaraman Shankari. All rights reserved.
//

#import <Foundation/NSObjCRuntime.h>
#import <objc/objc.h>
#import <objc/runtime.h>
#import "DataUtils.h"
#import "LocalNotificationManager.h"
#import "BuiltinUserCache.h"
#import "SimpleLocation.h"
#import "TimeQuery.h"
#import "MotionActivity.h"
#import "CommunicationHelper.h"
#import "LocationTrackingConfig.h"

@implementation BEMCommunicationHelper

+ (void) backgroundSync:(void (^)(UIBackgroundFetchResult))completionHandler {
    [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                               @"backgroundSync called"] showUI:TRUE];
    BOOL overallStatus = TRUE;
    [self pushAndClearUserCache:^(BOOL status) {
        if (status == TRUE) {
            [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                       @"pushAndClearUserCache successful"] showUI:FALSE];
        } else {
            [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                       @"pushAndClearUserCache failed"] showUI:FALSE];
        }
        overallStatus = overallStatus && status;
    }];
    [self pullIntoUserCache:^(BOOL status) {
        if (status == TRUE) {
            [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                       @"pullIntoUserCache successful"] showUI:FALSE];
        } else {
            [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                       @"pullIntoUserCache failed"] showUI:FALSE];
        }
        overallStatus = overallStatus && status;
    }];
    [self pushAndClearStats:^(BOOL status) {
        if (status == TRUE) {
            [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                       @"pushAndClearStats successful"] showUI:FALSE];
        } else {
            [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                       @"pushAndClearStats failed"] showUI:FALSE];
        }
        overallStatus = overallStatus && status;
    }];
    completionHandler(UIBackgroundFetchResultNewData);
}

+ (void) pushAndClearUserCache:(void (^)(BOOL))completionHandler {
    /*
     * In iOS, we can only sign up for activity updates when the app is in the foreground
     * (from https://developer.apple.com/library/ios/documentation/CoreMotion/Reference/CMMotionActivityManager_class/index.html#//apple_ref/occ/instm/CMMotionActivityManager/startActivityUpdatesToQueue:withHandler:)
     * "The handler block is executed on a best effort basis and updates are not delivered while your app is suspended. If updates arrived while your app was suspended, the last update is delivered to your app when it resumes execution."
     * However, apple automatically stores the activities, and they can be retrieved in a batch.
     * https://developer.apple.com/library/ios/documentation/CoreMotion/Reference/CMMotionActivityManager_class/index.html#//apple_ref/occ/instm/CMMotionActivityManager/queryActivityStartingFromDate:toDate:toQueue:withHandler:
     * "A delay of up to several minutes in reported activities is expected."
     *
     * Since we now detect trip end only after the user has been stationary for a while, this should be fine.
     * We need to test this more carefully when we switch to the visit-based tracking.
     */
    [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                               @"pushAndClearUserCache called"] showUI:TRUE];
    NSArray* locEntriesToPush = [[BuiltinUserCache database] syncPhoneToServer];
    NSArray* combinedArray = [BEMActivitySync getCombinedArray:locEntriesToPush];
    TimeQuery* tq = [BuiltinUserCache getTimeQuery:locationArray];
    [self pushAndClearCombinedData:combinedArray timeQuery:tq completionHandler:completionHandler];
}

+ (void) pushAndClearCombinedData:(NSArray*)entriesToPush timeQuery:(TimeQuery*)tq completionHandler:(void (^)(BOOL))completionHandler {
    if (entriesToPush.count == 0) {
        NSLog(@"No data to send, returning early");
    } else {
        [self phone_to_server:entriesToPush
                             completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                 [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                                            @"successfully pushed %ld entries to the server",
                                                                            (unsigned long)entriesToPush.count]
                                                                    showUI:TRUE];
                                 // Only delete trips after they have been successfully pushed
                                 if (error == nil) {
                                     [[BuiltinUserCache database] clearEntries:tq];
                                 }
                                 NSLog(@"Returning from silent push");
                                 completionHandler(TRUE);
                             }];
    }
}

+(void)phone_to_server:(NSArray *)entriesToPush completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSMutableDictionary *toPush = [[NSMutableDictionary alloc] init];
    [toPush setObject:entriesToPush forKey:@"phone_to_server"];
    
    NSURL* kBaseURL = [[ConnectionSettings sharedInstance] getConnectUrl];
    NSURL* kUsercachePutURL = [NSURL URLWithString:kUsercachePutPath
                                 relativeToURL:kBaseURL];
    
    CommunicationHelper *executor = [[CommunicationHelper alloc] initPost:kUsercachePutURL data:toPush completionHandler:completionHandler];
    [executor execute];
}

+(void) pullIntoUserCache:(void (^)(BOOL))completionHandler {
    /*
     * Every time the app is launched, check the battery level. We are not signing up for battery level notifications because we don't want
     * to contribute to the battery drain ourselves. Instead, we are going to check the battery level when the app is launched anyway for other reasons,
     * by the user, or as part of background sync.
     */
    ClientStatsDatabase* statsDb = [ClientStatsDatabase database];
    NSString* currTS = [ClientStatsDatabase getCurrentTimeMillisString];
    NSString* batteryLevel = [@([UIDevice currentDevice].batteryLevel) stringValue];
    [statsDb storeMeasurement:@"battery_level" value:batteryLevel ts:currTS];
    
    long msTimeStart = [ClientStatsDatabase getCurrentTimeMillis];
    
    // Called in order to download data in the background
    [self server_to_phone:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error != NULL) {
            NSLog(@"Got error %@ while retrieving data", error);
            if ([error.domain isEqualToString:errorDomain] && (error.code == authFailedNeedUserInput)) {
                [self generateErrorNotificationImmediately:1 application:application];
            }
            completionHandler(NO);
        } else {
            if (data == NULL) {
                NSLog(@"Got data == NULL while retrieving data");
                [_statsDb storeMeasurement:@"sync_pull_list_size" value:CLIENT_STATS_DB_NIL_VALUE ts:currTS];
                completionHandler(YES);
            } else {
                NSLog(@"Got non NULL data while retrieving data");
                NSInteger newSectionCount = [self fetchedData:data];
                NSLog(@"Section count = %ld", (long)newSectionCount);
                [_statsDb storeMeasurement:@"sync_pull_list_size" value:[@(newSectionCount) stringValue] ts:currTS];
                if (newSectionCount > 0) {
                    [self generateLocalNotificationImmediately:newSectionCount application:application];
                    // Note that we need to update the UI before calling the completion handler, otherwise
                    // when the view appears, users won't see the newly fetched data!
                    [[NSNotificationCenter defaultCenter] postNotificationName:BackgroundRefreshNewData
                                                                        object:self];
                    completionHandler(YES);
                } else {
                    [_statsDb storeMeasurement:@"sync_pull_list_size" value:@"0" ts:currTS];
                    completionHandler(YES);
                }
            }
            long msTimeEnd = [[NSDate date] timeIntervalSince1970]*1000;
            long msDuration = msTimeEnd - msTimeStart;
            [_statsDb storeMeasurement:@"sync_duration" value:[@(msDuration) stringValue] ts:currTS];
        }
    }];
}

// This is the callback that is invoked when the async data collection ends.
// We are going to parse the JSON in here for simplicity
- (NSInteger)fetchedData:(NSData *)responseData {
    NSError *error;
    NSDictionary *documentDict = [NSJSONSerialization JSONObjectWithData:responseData
                                                                options:kNilOptions
                                                                  error: &error];
    
    NSArray *newDocs = [documentDict objectForKey:@"server_to_phone"];
    [[BuiltinUserCache database] syncServerToPhone:newDocs];
    NSLog(@"documents: %@", newDocs);
    
    return [newDocs count];
}

+(void)server_to_phone:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSLog(@"CommunicationHelper.server_to_phone called!");
    NSMutableDictionary *blankDict = [[NSMutableDictionary alloc] init];
    NSURL* kBaseURL = [[ConnectionSettings sharedInstance] getConnectUrl];
    NSURL* kUsercacheGetURL = [NSURL URLWithString:kUsercacheGetPath
                                            relativeToURL:kBaseURL];
    CommunicationHelper *executor = [[CommunicationHelper alloc] initPost:kUsercacheGetURL data:blankDict completionHandler:completionHandler];
    [executor execute];
}

- (void)pushAndClearStats:(void (^)(BOOL))completionHandler
{
    ClientStatsDatabase* statsDb = [ClientStatsDatabase database];
    NSString* currTs = [ClientStatsDatabase getCurrentTimeMillisString];
    NSDictionary *statsToSend = [statsDb getMeasurements];
    if ([statsToSend count] != 0) {
        // Also push the client level stats
        [self setClientStats:statsToSend
                      completionHandler:^(NSData *data, NSURLResponse* response, NSError* error){
                          NSLog(@"Pushing stats to the server is complete with response = %@i and error = %@", response, error);
                          // If the error was null, the push was successful, and we can clear the database
                          // Should we check for the code in the response, or for the error?
                          if(error == NULL) {
                              [statsDb clear];
                              completionHandler(TRUE);
                          } else {
                              completionHandler(FALSE);
                          }
                      }];
    } else {
        completionHandler(TRUE);
    }
}

+(void)setClientStats:(NSMutableDictionary*)statsToSend completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSMutableDictionary *toPush = [[NSMutableDictionary alloc] init];
    [toPush setObject:statsToSend forKey:@"stats"];
    
    NSURL* kBaseURL = [[ConnectionSettings sharedInstance] getConnectUrl];
    NSURL* kSetStatsURL = [NSURL URLWithString:kSetStatsPath
                                      relativeToURL:kBaseURL];
    
    CommunicationHelper *executor = [[CommunicationHelper alloc] initPost:kSetStatsURL data:toPush completionHandler:completionHandler];
    [executor execute];
}

@end
