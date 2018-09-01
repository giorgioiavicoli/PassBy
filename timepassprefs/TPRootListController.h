#import <Preferences/PSListController.h>
//#import <Preferences/PSSpecifier.h>

@interface TPRootListController : PSListController
-(BOOL)validateTimeShift:(id)value;
-(BOOL)validateDigits:(id)value forKey:(NSString *)key;
@end

/*
@interface TPWiFiListController : PSListController
@end

typedef struct __WiFiNetwork* WiFiNetworkRef;
typedef struct __WiFiManager* WiFiManagerRef;

extern "C" WiFiManagerRef WiFiManagerClientCreate(CFAllocatorRef allocator, int flags);
extern "C" CFArrayRef WiFiManagerClientCopyNetworks(WiFiManagerRef manager);
extern "C" CFStringRef WiFiNetworkGetSSID(WiFiNetworkRef network);
*/