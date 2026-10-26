TARGET := iphone:clang:latest:15.0
ARCHS = arm64
THEOS_PACKAGE_SCHEME = roothide
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DepthLock

DepthLock_FILES = Tweak.x
DepthLock_CFLAGS = -fobjc-arc
DepthLock_FRAMEWORKS = UIKit Vision CoreImage CoreVideo

include $(THEOS_MAKE_PATH)/tweak.mk
