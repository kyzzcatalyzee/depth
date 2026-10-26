TARGET := iphone:clang:16.5:15.0
ARCHS = arm64
THEOS_PACKAGE_SCHEME = roothide
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DepthLock

DepthLock_FILES = Tweak.x
DepthLock_CFLAGS = -fobjc-arc -Wno-unguarded-availability-new -Wno-error
DepthLock_FRAMEWORKS = UIKit Vision CoreImage CoreVideo

include $(THEOS_MAKE_PATH)/tweak.mk
