TARGET := iphone:clang:latest:7.0
INSTALL_TARGET_PROCESSES = apsd


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = getsslkeylog

getsslkeylog_FILES = Tweak.xm
getsslkeylog_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
