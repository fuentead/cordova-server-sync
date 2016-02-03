//
//  DataUtils.h
//  CFC_Tracker
//
//  Created by Kalyanaraman Shankari on 3/9/15.
//  Copyright (c) 2015 Kalyanaraman Shankari. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

typedef void (^CombinedArrayHandler)(NSArray* combinedArrayHandler);

@interface BEMActivitySync: NSObject
+ (void) getCombinedArray:(NSArray*)locationArray withHandler:(CombinedArrayHandler)completionArray;
@end
