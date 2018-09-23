THEOS_DEVICE_IP = iPhone.local
#192.168.1.7
#iPhone.local
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PassBy
PassBy_FILES = Tweak.xm
#PassBy_LIBRARIES = activator
PassBy_FRAMEWORKS = UIKit
PassBy_PRIVATE_FRAMEWORKS = SpringBoardFoundation BluetoothManager WatchConnectivity

#ADDITIONAL_CFLAGS = -objc-arc

LDFLAGS = -F /Users/giorgioiavicoli/theos/sdks/iPhoneOS11.2.sdk/System/Library/PrivateFrameworks

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"

SUBPROJECTS += passbyprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
