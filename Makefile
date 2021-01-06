THEOS_DEVICE_IP = iP7.local

FINALPACKAGE = 1
DEBUG = 0

include $(THEOS)/makefiles/common.mk

export ARCHS = armv7 arm64 arm64e

TWEAK_NAME = PassBy
PassBy_FILES = Tweak.xm

PassBy_FRAMEWORKS = UIKit
PassBy_PRIVATE_FRAMEWORKS = SpringBoardFoundation BluetoothManager BatteryCenter MobileWiFi

LDFLAGS = -F $(THEOS)/sdks/iPhoneOS11.2.sdk/System/Library/PrivateFrameworks

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"

SUBPROJECTS += passbyprefs
SUBPROJECTS += passbyflipswitch
include $(THEOS_MAKE_PATH)/aggregate.mk
