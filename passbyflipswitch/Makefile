THEOS_DEVICE_IP = iP7.local
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = PassByFlipswitch
PassByFlipswitch_FILES = Switch.xm
PassByFlipswitch_FRAMEWORKS = UIKit
PassByFlipswitch_LIBRARIES = flipswitch activator
PassByFlipswitch_INSTALL_PATH = /Library/Switches

include $(THEOS_MAKE_PATH)/bundle.mk

after-install::
	install.exec "killall -9 SpringBoard"
