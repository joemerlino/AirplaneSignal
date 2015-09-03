TARGET := iphone:clang
SDKVERSION = 8.4
TARGET_IPHONEOS_DEPLOYMENT_VERSION = 7.0
ARCHS = armv7 armv7s arm64

include theos/makefiles/common.mk

TWEAK_NAME = AirplaneSignal
AirplaneSignal_FILES = Tweak.xm
AirplaneSignal_LIBRARIES = Flipswitch
AirplaneSignal_FRAMEWORKS = AudioToolbox

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
SUBPROJECTS += airplanesignalprefs
SUBPROJECTS += airplanesignaltoggle
include $(THEOS_MAKE_PATH)/aggregate.mk
