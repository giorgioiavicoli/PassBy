include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TimePass
TimePass_FILES = NSData+AES.m Tweak.xm
TimePass_PRIVATE_FRAMEWORKS = SpringBoardFoundation

LDFLAGS = -F /Users/giorgioiavicoli/theos/sdks/iPhoneOS11.2.sdk/System/Library/PrivateFrameworks

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"

SUBPROJECTS += timepassprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
