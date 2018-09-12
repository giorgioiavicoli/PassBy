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
    [gracePeriodWiFiEnds release];
    gracePeriodWiFiEnds = 
        useGracePeriodOnWiFi && isUsingWiFi()
            ? (gracePeriodOnWiFi 
                ? [[NSDate dateWithTimeIntervalSinceNow:gracePeriodOnWiFi] retain]
                : [[NSDate distantFuture] copy]
            ) : nil;
}

static void updateBTGracePeriod()
{
    [gracePeriodBTEnds release];
    
    gracePeriodBTEnds = 
        useGracePeriodOnBT && isUsingBT()
            ? (gracePeriodOnBT
                ? [[NSDate dateWithTimeIntervalSinceNow:gracePeriodOnBT] retain]
                : [[NSDate distantFuture] copy]
            ) : nil;
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

    [gracePeriodWiFiEnds release];
    gracePeriodWiFiEnds = nil;

    [gracePeriodBTEnds release];
    gracePeriodBTEnds = nil;

    wasUsingHeadphones = NO;
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
    if (isTemporaryDisabled())
        return NO;

    if (gracePeriodEnds 
    && [gracePeriodEnds compare:[NSDate date]] == NSOrderedDescending)
        return YES;

    if (gracePeriodWiFiEnds 
    && [gracePeriodWiFiEnds compare:[NSDate date]] == NSOrderedDescending
    && isUsingWiFi()
    ) {
        return YES;
    } else {
        [gracePeriodWiFiEnds release];
        gracePeriodWiFiEnds = nil;
    }

    if (gracePeriodBTEnds 
    && [gracePeriodBTEnds compare:[NSDate date]] == NSOrderedDescending 
    && isUsingBT()
    ) {
        return YES;
    } else {
        [gracePeriodBTEnds release];
        gracePeriodBTEnds = nil;
    }

    if (headphonesAutoUnlock)
        return (wasUsingHeadphones = wasUsingHeadphones && isUsingHeadphones());

    return NO;
}


#else
#error "File already included"
#endif // PASSBYGRACEPERIODHELPER_H