#ifndef PASSBYGRACEPERIODHELPER_H
#define PASSBYGRACEPERIODHELPER_H

static void updateGracePeriod()
{
    [gracePeriodEnds release];

    gracePeriodEnds = 
        useGracePeriod 
            ? (gracePeriod
                ? [[NSDate dateWithTimeIntervalSinceNow:gracePeriod] retain]
                : [[NSDate distantFuture] copy]
            ) : nil;
}

static void updateWiFiGracePeriod()
{
    @synchronized(WiFiGracePeriodSyncObj) {
        [gracePeriodWiFiEnds release];
        gracePeriodWiFiEnds = 
            useGracePeriodOnWiFi && isUsingWiFi()
                ? (gracePeriodOnWiFi 
                    ? [[NSDate dateWithTimeIntervalSinceNow:gracePeriodOnWiFi] retain]
                    : [[NSDate distantFuture] copy]
                ) : nil;
    }
}

static void updateBTGracePeriod()
{
    @synchronized(BTGracePeriodSyncObj) {
        [gracePeriodBTEnds release];
        gracePeriodBTEnds = 
            useGracePeriodOnBT && isUsingBT()
                ? (gracePeriodOnBT
                    ? [[NSDate dateWithTimeIntervalSinceNow:gracePeriodOnBT] retain]
                    : [[NSDate distantFuture] copy]
                ) : nil;
    }
}

static void updateAllGracePeriods()
{
    updateGracePeriod();
    updateWiFiGracePeriod();
    updateBTGracePeriod();
    wasUsingHeadphones = isUsingHeadphones();
}

static void invalidateAllGracePeriods()
{
    [gracePeriodEnds release];
    gracePeriodEnds = nil;

    @synchronized(WiFiGracePeriodSyncObj) {
        [gracePeriodWiFiEnds release];
        gracePeriodWiFiEnds = nil;
    }

    @synchronized(BTGracePeriodSyncObj) {
        [gracePeriodBTEnds release];
        gracePeriodBTEnds = nil;
    }

    wasUsingHeadphones = NO;
}

static void saveAllGracePeriods()
{
    NSMutableDictionary * gracePeriods =    
        [   [NSMutableDictionary alloc] 
            initWithContentsOfFile:@GP_PLIST_PATH
        ] ?:[NSMutableDictionary new];

    if (useGracePeriod && gracePeriodEnds) {
        NSData * GPData =
            AES128Encrypt(
                [stringFromDateAndFormat(gracePeriodEnds, @"ddMMyyyyHHmmss")
                    dataUsingEncoding:NSUTF8StringEncoding
                ], UUID
            );
        [gracePeriods 
            setObject:GPData
            forKey:@"gp"
        ];
    }

    @synchronized(WiFiGracePeriodSyncObj) {
        if (useGracePeriodOnWiFi && gracePeriodWiFiEnds) {
            NSData * WiFiGPData =
                AES128Encrypt(
                    [stringFromDateAndFormat(gracePeriodWiFiEnds, @"ddMMyyyyHHmmss")
                        dataUsingEncoding:NSUTF8StringEncoding
                    ], UUID
                );
            [gracePeriods 
                setObject:WiFiGPData
                forKey:@"gpwifi"
            ];
        }
    }

    @synchronized(BTGracePeriodSyncObj) {
        if (useGracePeriodOnBT && gracePeriodBTEnds) {
            NSData * BTGPData =
                AES128Encrypt(
                    [stringFromDateAndFormat(gracePeriodBTEnds, @"ddMMyyyyHHmmss")
                        dataUsingEncoding:NSUTF8StringEncoding
                    ], UUID
                );
            [gracePeriods 
                setObject:BTGPData
                forKey:@"gpbt"
            ];
        }
    }

    [gracePeriods writeToFile:@(GP_PLIST_PATH) atomically:YES];
    [gracePeriods release];
}

static void loadAllGracePeriods()
{
    NSDictionary * gracePeriods =    
        [   [NSDictionary alloc] 
            initWithContentsOfFile:@GP_PLIST_PATH
        ];
    
    if (gracePeriods) {
        NSData * GPData = [gracePeriods valueForKey:@"gp"];
        if (useGracePeriod && GPData) {
            NSString * GPString =
                [   [NSString alloc] 
                    initWithData:AES128Decrypt(GPData, UUID)
                    encoding:NSUTF8StringEncoding
                ];

            gracePeriodEnds = 
                [   dateFromStringAndFormat(GPString, @"ddMMyyyyHHmmss")
                    copy
                ];

            [GPString release];
        }

        NSData * WiFiGPData = [gracePeriods valueForKey:@"gpwifi"];
        if (useGracePeriod && WiFiGPData) {
            NSString * WiFiGPString =
                [   [NSString alloc] 
                    initWithData:AES128Decrypt(WiFiGPData, UUID)
                    encoding:NSUTF8StringEncoding
                ];

            @synchronized(WiFiGracePeriodSyncObj) {
                gracePeriodEnds = 
                    [   dateFromStringAndFormat(WiFiGPString, @"ddMMyyyyHHmmss")
                        copy
                    ];
            }

            [WiFiGPString release];
        }

        NSData * BTGPData = [gracePeriods valueForKey:@"gp"];
        if (useGracePeriod && BTGPData) {
            NSString * BTPString =
                [   [NSString alloc] 
                    initWithData:AES128Decrypt(BTGPData, UUID)
                    encoding:NSUTF8StringEncoding
                ];
            @synchronized(BTGracePeriodSyncObj) {
                gracePeriodEnds = 
                    [   dateFromStringAndFormat(BTPString, @"ddMMyyyyHHmmss")
                        copy
                    ];
            }
            [BTPString release];
        }
    }
    
    [gracePeriods release];

}

static void refreshDisabledInterval()
{
    [currentDay         release];
    [disableFromDate    release];
    [disableToDate      release];

    currentDay = [NSDate new];

    disableFromDate = 
        [   [NSCalendar currentCalendar] 
            dateBySettingHour:  disableFromTime.hours
            minute:             disableFromTime.minutes
            second:0
            ofDate:currentDay
            options:NSCalendarMatchFirst
        ];
    disableToDate = 
        [   [NSCalendar currentCalendar] 
            dateBySettingHour:  disableToTime.hours
            minute:             disableToTime.minutes
            second:0
            ofDate:currentDay
            options:NSCalendarMatchFirst
        ];
}

static BOOL isTemporaryDisabled()
{
    if (!disableDuringTime)
        return NO;
    
    NSDate * currentDate = [NSDate date];

    if (
    ![  [NSCalendar currentCalendar] 
        isDate:currentDate
        inSameDayAsDate:currentDay
    ]) {
        refreshDisabledInterval();
    }

    if (keepDisabledAfterTime && isKeptDisabled)
        return YES;
        
    if ([disableFromDate compare:disableToDate] == NSOrderedAscending
            ? [disableFromDate compare:currentDate] == NSOrderedAscending
                && [currentDate compare:disableToDate] == NSOrderedAscending
            : [disableFromDate compare:currentDate] == NSOrderedAscending
                || [currentDate compare:disableToDate] == NSOrderedAscending
    ) {
        isKeptDisabled = keepDisabledAfterTime;
        return YES;
    }

    return NO;
}

static BOOL isInGrace()
{
    if (isManuallyDisabled || isTemporaryDisabled())
        return NO;

    if (watchAutoUnlock && isUsingWatch())
        return YES;

    if (gracePeriodEnds 
    && [gracePeriodEnds compare:[NSDate date]] == NSOrderedDescending)
        return YES;

    @synchronized(WiFiGracePeriodSyncObj) {
        if (gracePeriodWiFiEnds 
        && [gracePeriodWiFiEnds compare:[NSDate date]] == NSOrderedDescending
        && isUsingWiFi()
        ) {
            return YES;
        } else {
            [gracePeriodWiFiEnds release];
            gracePeriodWiFiEnds = nil;
        }
    }

    @synchronized(BTGracePeriodSyncObj) {
        if (gracePeriodBTEnds 
        && [gracePeriodBTEnds compare:[NSDate date]] == NSOrderedDescending 
        && isUsingBT()
        ) {
            return YES;
        } else {
            [gracePeriodBTEnds release];
            gracePeriodBTEnds = nil;
        }
    }

    if (headphonesAutoUnlock)
        return (wasUsingHeadphones = wasUsingHeadphones && isUsingHeadphones());

    return NO;
}


#else
#error "File already included"
#endif // PASSBYGRACEPERIODHELPER_H