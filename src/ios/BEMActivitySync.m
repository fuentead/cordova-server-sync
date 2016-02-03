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
#import "BEMActivitySync.h"
#import "LocalNotificationManager.h"
#import "BEMBuiltinUserCache.h"
#import "SimpleLocation.h"
#import "TimeQuery.h"
#import "MotionActivity.h"
#import "BEMServerSyncCommunicationHelper.h"
#import "LocationTrackingConfig.h"
#import <CoreMotion/CoreMotion.h>

@implementation BEMActivitySync

+ (void) getCombinedArray:(NSArray*) locationArray withHandler:(CombinedArrayHandler)completionHandler {
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
    if (locationArray.count == 0) {
        completionHandler(locationArray);
    }
    TimeQuery* tq = [BuiltinUserCache getTimeQuery:locationArray];
    
    if ([CMMotionActivityManager isActivityAvailable] == YES) {
        CMMotionActivityManager* activityMgr = [[CMMotionActivityManager alloc] init];
        NSOperationQueue* mq = [NSOperationQueue mainQueue];
        [activityMgr queryActivityStartingFromDate:tq.startDate toDate:tq.endDate toQueue:mq withHandler:^(NSArray *activities, NSError *error) {
            if (error == nil) {
                /*
                 * This conversion allows us to unit test this code, since we cannot create valid CMMotionActivity
                 * segments. We can create a CMMotionActivity, but we cannot set any of its properties.
                 */
                NSArray* motionEntries = [self convertToEntries:activities locationEntries:locationArray];
                NSArray* combinedArray = [locationArray arrayByAddingObjectsFromArray:motionEntries];
                completionHandler(combinedArray);
            } else {
                [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                           @"Got error %@ while querying activity from %@ to %@",
                                                           error, tq.startDate, tq.endDate]];
                NSLog(@"Got error %@ while querying activity from %@ to %@", error, tq.startDate, tq.endDate);
                completionHandler(locationArray);
            }
        }];
    } else {
        NSLog(@"Activity recognition unavailable, skipping segmentation");
        completionHandler(locationArray);
    }
}

/*
 * THIS IS BROKEN wrt timezones. If we changed timezones during the course of a trip, this would make all activities
 * be in the last timezone. Need to find the timezones from the location entries and pass it in here instead.
 */

+ (NSArray*) convertToEntries:(NSArray*)activities locationEntries:(NSArray*)locEntries {
    /*
     * Iterate over the location entries and make a map of time range -> timezone that we can use to set the
     * time zones on the activity objects.
     */
    NSMutableArray* timezoneChanges = [NSMutableArray new];
    NSString* prevTimezone = NULL;
    
    for (int i=0; i < locEntries.count; i++) {
        NSDictionary* currEntry = locEntries[i];
        NSString* currTimezone = [BuiltinUserCache getTimezone:currEntry];
        if (![currTimezone isEqual:prevTimezone]) {
            [timezoneChanges addObject:currEntry];
        }
    }
    
    assert(timezoneChanges.count > 0);
    
    NSEnumerator* timezoneChangesEnum = timezoneChanges.objectEnumerator;
    NSDictionary* currTimezoneChange = [timezoneChangesEnum nextObject];
    NSDictionary* nextTimezoneChange = [timezoneChangesEnum nextObject];
    assert(currTimezoneChange != nil);
    
    NSMutableArray* entryArray = [NSMutableArray new];
    for (int i=0; i < activities.count; i++) {
        CMMotionActivity* activity = activities[i];
        MotionActivity* activityWrapper = [[MotionActivity alloc] initWithCMMotionActivity:activity];
        
        // if startDate > next timezone change.date, then we want to move to the next entry
        if (nextTimezoneChange != nil &&
            [activity.startDate compare:[BuiltinUserCache getWriteTs:nextTimezoneChange]] == NSOrderedDescending) {
            currTimezoneChange = nextTimezoneChange;
            nextTimezoneChange = [timezoneChangesEnum nextObject];
        }
        [entryArray addObject:[[BuiltinUserCache database] createSensorData:@"key.usercache.activity" write_ts:activity.startDate timezone:[BuiltinUserCache getTimezone:currTimezoneChange] data:activityWrapper]];
    }
    return entryArray;
}

+ (void) deleteAllEntries {
    [[BuiltinUserCache database] clear];
}

@end
