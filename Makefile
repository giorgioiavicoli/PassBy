THEOS_DEVICE_IP = iPhone.local
#i5.local
#iPhone.local
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PassBy
PassBy_FILES = Tweak.xm
PassBy_LIBRARIES = activator
PassBy_FRAMEWORKS = UIKit
PassBy_PRIVATE_FRAMEWORKS = SpringBoardFoundation BluetoothManager WatchConnectivity

#ADDITIONAL_CFLAGS = -I /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/usr/include/
#-objc-arc

ADDITIONAL_CFLAGS = -std=c++14 -stdlib=libc++

LDFLAGS = -F $(THEOS)/sdks/iPhoneOS11.2.sdk/System/Library/PrivateFrameworks

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"

SUBPROJECTS += passbyprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
