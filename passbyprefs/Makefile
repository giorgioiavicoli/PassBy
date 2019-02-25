include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = PassByPrefs
PassByPrefs_FILES = PassByRootListController.m
PassByPrefs_INSTALL_PATH = /Library/PreferenceBundles
PassByPrefs_FRAMEWORKS = UIKit Message
PassByPrefs_PRIVATE_FRAMEWORKS = Preferences MobileWiFi BluetoothManager

LDFLAGS = -F $(THEOS)/sdks/iPhoneOS11.2.sdk/System/Library/PrivateFrameworks

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/PassByPrefs.plist$(ECHO_END)
