include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = TimePassPrefs
TimePassPrefs_FILES = TTURootListController.m
TimePassPrefs_INSTALL_PATH = /Library/PreferenceBundles
TimePassPrefs_FRAMEWORKS = UIKit
TimePassPrefs_PRIVATE_FRAMEWORKS = Preferences

LDFLAGS = -F /Users/giorgioiavicoli/theos/sdks/iPhoneOS11.2.sdk/System/Library/PrivateFrameworks

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/TimePassPrefs.plist$(ECHO_END)
