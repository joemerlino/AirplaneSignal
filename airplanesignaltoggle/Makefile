TARGET := iphone:clang
SDKVERSION = 8.4
TARGET_IPHONEOS_DEPLOYMENT_VERSION = 7.0
ARCHS = armv7 armv7s arm64

include theos/makefiles/common.mk

BUNDLE_NAME = AirplaneSignalToggle
AirplaneSignalToggle_FILES = Switch.x
AirplaneSignalToggle_FRAMEWORKS = UIKit
AirplaneSignalToggle_LIBRARIES = flipswitch
AirplaneSignalToggle_INSTALL_PATH = /Library/Switches

include $(THEOS_MAKE_PATH)/bundle.mk