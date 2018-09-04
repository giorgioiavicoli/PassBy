#ifndef PASSBYHELPER_H
#define PASSBYHELPER_H

NSString * stringFromDateAndFormat(NSDate * date, NSString * format)
{
    NSDateFormatter *formatter = [NSDateFormatter new];
    [formatter setLocale:[NSLocale currentLocale]];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    [formatter setDateFormat:format];
    
    NSString * string = [formatter stringFromDate:date];
    [formatter release];
    return string;
}

NSString * SHA1(NSString * str)
{
    NSMutableData * hashData = [[NSMutableData alloc] initWithLength:CC_SHA1_DIGEST_LENGTH];
    NSData * data = [str dataUsingEncoding:NSUTF8StringEncoding];

    unsigned char * hashBytes = (unsigned char *)[hashData mutableBytes];

    if (CC_SHA1([data bytes], [data length], hashBytes)) {
        NSUInteger len  = [hashData length];
        NSMutableString * hash  = [NSMutableString stringWithCapacity:(len * 2)];
        
        for (int i = 0; i < len; ++i)
            [hash appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)hashBytes[i]]];
        
        return [NSString stringWithString:hash];
    }
    return nil;
}

BOOL evalDateTimeHelper(NSString * format, char d0, char d1, BOOL reversed)
{
    if(reversed) {
        char tmp = d0;
        d0 = d1;
        d1 = tmp;
    }

    NSDate * date = [NSDate new];
    NSString * dateString = stringFromDateAndFormat(
        [date dateByAddingTimeInterval:timeShift * 60], format
    );
    [date release];

    BOOL success = 
        d0 == [dateString characterAtIndex:0] 
        && d1 == [dateString characterAtIndex:1];

    [dateString release];
    return success;
}


struct Digits {
    BOOL (* eval) (struct Digits *, char, char);
    char digit0, digit1;
    BOOL reversed, isGracePeriod;
};

static BOOL evalCustom(struct Digits * config, char d0, char d1)
{
    return config->reversed 
        ? d1 == config->digit0 && d0 == config->digit1
        : d0 == config->digit0 && d1 == config->digit1;
}

static BOOL evalTimeH(struct Digits * config, char d0, char d1)
{
    return evalDateTimeHelper(
        use24hFormat ? @"HH" : @"hh", 
        d0, d1, config->reversed
    );
}

static BOOL evalTimeM(struct Digits * config, char d0, char d1)
{
    return evalDateTimeHelper(@"mm", d0, d1, config->reversed);
}

static BOOL evalDateD(struct Digits * config, char d0, char d1)
{
    return evalDateTimeHelper(@"dd", d0, d1, config->reversed);
}

static BOOL evalDateM(struct Digits * config, char d0, char d1)
{
    return evalDateTimeHelper(@"MM", d0, d1, config->reversed);
}

static BOOL evalBattR(struct Digits * config, char d0, char d1)
{
    if (config->reversed) {
        char tmp = d0;
        d0 = d1;
        d1 = tmp;
    }
    int level = (int) ([[UIDevice currentDevice] batteryLevel] * 100.0f);
    return d0 == '0' + ((level / 10) % 10)
        && d1 == '0' + (level % 10);
}

static BOOL evalBattU(struct Digits * config, char d0, char d1)
{
    if (config->reversed) {
        char tmp = d0;
        d0 = d1;
        d1 = tmp;
    }
    int level = 100 - (int) ([[UIDevice currentDevice] batteryLevel] * 100.0f);
    return d0 == '0' + ((level / 10) % 10)
        && d1 == '0' + (level % 10);
}

static BOOL evalGraceP(struct Digits * config, char d0, char d1)
{
    if (config->reversed) {
        char tmp = d0;
        d0 = d1;
        d1 = tmp;
    }
    digitsGracePeriod = (d0 - '0') * 60 + (d1 - '0') * 10;
    return TRUE;
}

enum DigitConfig : int {
    CONFIG_TIMEH    = 0,
    CONFIG_TIMEM    = 1,
    CONFIG_DATED    = 2,
    CONFIG_DATEM    = 3,
    CONFIG_BATTR    = 4,
    CONFIG_BATTU    = 5,
    CONFIG_GRACEP   = 6,
    CONFIG_CUSTOM   = 7
};

void parseDigitsConfiguration(struct Digits * digits, 
    NSString * custom, int config, BOOL reversed)
{
    digits->reversed        = reversed;
    digits->isGracePeriod   = NO;

    switch(config) {
        case CONFIG_TIMEH:
            digits->eval = evalTimeH;
            return;
        case CONFIG_TIMEM:
            digits->eval = evalTimeM;
            return;
        case CONFIG_DATED:
            digits->eval = evalDateD;
            return;
        case CONFIG_DATEM:
            digits->eval = evalDateM;
            return;
        case CONFIG_BATTR:
            digits->eval = evalBattR;
            return;
        case CONFIG_BATTU:
            digits->eval = evalBattU;
            return;
        case CONFIG_GRACEP:
            digits->eval = evalGraceP;
            digits->isGracePeriod = YES;
            return;
        case CONFIG_CUSTOM:
        default:
            if ([custom length] == 2) {
                digits->digit0 = [custom characterAtIndex:0];
                digits->digit1 = [custom characterAtIndex:1];
            } else {
                digits->digit1 = digits->digit0 = '0';
            }
            digits->eval = evalCustom;
            return;
    }
}

#endif // PASSBYHELPER_H