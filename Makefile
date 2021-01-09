# Target iOS 9+ Devices; use the iOS 13.3 SDK
TARGET = iphone:clang::9.0
SYSROOT = $(THEOS)/sdks/iPhoneOS13.3.sdk
XCODE11_PATH = /Applications/Xcode-11.app/Contents/Developer
XCODE12_PATH = /Applications/Xcode-12.app/Contents/Developer

ARCHS = armv7 arm64 arm64e
THEOS_PLATFORM_SDK_ROOT_armv7 = $(XCODE11_PATH)
THEOS_PLATFORM_SDK_ROOT_arm64 = $(XCODE11_PATH)
THEOS_PLATFORM_SDK_ROOT_armv64e = $(XCODE12_PATH)

INSTALL_TARGET_PROCESSES = SpringBoard

FINALPACKAGE = 1
# DEBUG = 1

include $(THEOS)/makefiles/common.mk


TWEAK_NAME = PassBy
PassBy_FILES = Tweak.xm

PassBy_FRAMEWORKS = UIKit
PassBy_PRIVATE_FRAMEWORKS = SpringBoard SpringBoardFoundation BluetoothManager BatteryCenter MobileWiFi

LDFLAGS = -F $(THEOS)/sdks/iPhoneOS13.3.sdk/System/Library/PrivateFrameworks

include $(THEOS_MAKE_PATH)/tweak.mk


after-install::
	install.exec "killall -9 SpringBoard"


SUBPROJECTS += passbyprefs
SUBPROJECTS += passbyflipswitch
include $(THEOS_MAKE_PATH)/aggregate.mk
