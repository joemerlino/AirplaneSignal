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
