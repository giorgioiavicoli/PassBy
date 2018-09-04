#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface PassByRootListController : PSListController
@end

@interface PassByWiFiListController : PSListController
@end

@interface PassByHelpListController : PSListController
@end

typedef struct __WiFiNetwork* WiFiNetworkRef;
typedef struct __WiFiManager* WiFiManagerRef;

extern WiFiManagerRef WiFiManagerClientCreate(CFAllocatorRef allocator, int flags);
extern CFArrayRef WiFiManagerClientCopyNetworks(WiFiManagerRef manager);
extern CFStringRef WiFiNetworkGetSSID(WiFiNetworkRef network);

NSString * SHA1(NSString * str);