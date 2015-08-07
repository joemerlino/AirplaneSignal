include theos/makefiles/common.mk

BUNDLE_NAME = AirplaneSignalPrefs
AirplaneSignalPrefs_FILES = AirplaneSignalPrefs.mm
AirplaneSignalPrefs_INSTALL_PATH = /Library/PreferenceBundles
AirplaneSignalPrefs_FRAMEWORKS = UIKit
AirplaneSignalPrefs_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/AirplaneSignalPrefs.plist$(ECHO_END)
