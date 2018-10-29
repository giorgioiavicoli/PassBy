#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface PassByRootListController : PSListController<MFMailComposeViewControllerDelegate>
@end

@interface PassByWiFiListController : PSListController
@end

@interface PassByBTListController : PSListController
@end

@interface PassByHelpListController : PSListController
@end

@interface PassByMagicPasscodeListController : PSListController
@end

@interface BluetoothDevice : NSObject
-(NSString *)name;
-(NSString*)address;
@end


@interface BluetoothManager : NSObject
+(id)sharedInstance;
-(id)pairedDevices;
@end

typedef struct __WiFiNetwork* WiFiNetworkRef;
typedef struct __WiFiManager* WiFiManagerRef;

extern WiFiManagerRef   WiFiManagerClientCreate(CFAllocatorRef allocator, int flags);
extern CFArrayRef       WiFiManagerClientCopyNetworks(WiFiManagerRef manager);
extern CFStringRef      WiFiNetworkGetSSID(WiFiNetworkRef network);
extern Boolean          WiFiNetworkIsWEP(WiFiNetworkRef network);
extern Boolean          WiFiNetworkIsWPA(WiFiNetworkRef network);
extern Boolean          WiFiNetworkIsEAP(WiFiNetworkRef network);