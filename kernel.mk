#
# Copyright (C) 2011 The Android Open-Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author: Eric Finseth
# Based on: AndroidKernel.mk found in the msm Linux/Android kernel tree
#
# This Makefile builds a Linux kernel within the Android
# build system
#
#
# Required make variables (to be defined by the user or device .mk files)
# TARGET_KERNEL_DEFCONFIG
#
# Optional make variables:
# TARGET_KERNEL_LOCATION
#     Defaults to "kernel" (relative to ANDROID_BUILD_TOP)
#
# TARGET_KERNEL_CROSS_COMPILE
#     Defaults to "arm-eabi-"
#     Can be in the PATH or a full absolute path
#
# TARGET_KERNEL_ARCH
#     Defaults to TARGET_ARCH
#
# TARGET_KERNEL_SUBARCH
#     If defined, will call the kernel make with
#     SUBARCH=$(TARGET_KERNEL_SUBARCH)
#
# TARGET_UNCOMPRESSED_KERNEL
#     If defined, will gunzip the zImage to use the uncompressed version
#
# TARGET_KERNEL_MODULES_OUTDIR
#     Defaults to system/lib/modules
#     Only used if TARGET_BUILD_KERNEL_MODULES is true
#
# TARGET_KERNEL_HEADERS_OUTDIR
#     Defaults to usr/ in the kernel output directory
#     Only used for 'make kernelheaders'
#
# Required make variables (from Android build system):
# ANDROID_BUILD_TOP
# ANDROID_PRODUCT_OUT
# TARGET_OUT_INTERMEDIATES

ifeq ($(TARGET_KERNEL_DEFCONFIG),)
    $(error TARGET_KERNEL_DEFCONFIG not defined)
endif


# Variable definitions
TARGET_KERNEL_LOCATION ?= kernel
TARGET_KERNEL_CROSS_COMPILE ?= arm-eabi-
TARGET_KERNEL_ARCH ?= $(TARGET_ARCH)

TARGET_KERNEL_HEADERS_OUTDIR ?= $(KERNEL_ABSOLUTE_OUT)/usr
TARGET_KERNEL_MODULES_OUTDIR ?= $(ANDROID_PRODUCT_OUT)/lib/modules

KERNEL_RELATIVE_OUT := $(TARGET_OUT_INTERMEDIATES)/KERNEL
KERNEL_ABSOLUTE_OUT := $(ANDROID_BUILD_TOP)/$(KERNEL_RELATIVE_OUT)
KERNEL_MODULES_OUT_INT := $(KERNEL_ABSOLUTE_OUT)/modules
KERNEL_MODULES_OUT := $(KERNEL_MODULES_OUT_INT)/lib/modules
KERNEL_BUILD_IMAGE_INTERMEDIATE := $(KERNEL_RELATIVE_OUT)/arch/arm/boot/zImage

kernel_out_mkdir := $(shell test -d $(KERNEL_ABSOLUTE_OUT) || mkdir -p $(KERNEL_ABSOLUTE_OUT))

KERNEL_CONFIG := $(KERNEL_ABSOLUTE_OUT)/.config
KERNEL_DEFCONFIG_SRC := $(shell find $(TARGET_KERNEL_LOCATION)/arch/$(TARGET_KERNEL_ARCH)/configs -name $(TARGET_KERNEL_DEFCONFIG))
KERNEL_LAST_DEFCONFIG_SRC := $(KERNEL_ABSOLUTE_OUT)/.last_defconfig
KERNEL_LAST_TARGET_DEFCONFIG := $(shell cat $(KERNEL_LAST_DEFCONFIG_SRC) 2>/dev/null)


$(info TARGET_KERNEL_DEFCONFIG=$(TARGET_KERNEL_DEFCONFIG))
$(info TARGET_KERNEL_LOCATION=$(TARGET_KERNEL_LOCATION))
$(info ============================================)

ifeq ($(KERNEL_DEFCONFIG_SRC),)
    $(error $(TARGET_KERNEL_DEFCONFIG) source not found)
endif

ifeq ($(TARGET_UNCOMPRESSED_KERNEL),true)
    $(info Using uncompressed kernel)
    KERNEL_BUILD_IMAGE := $(KERNEL_ABSOLUTE_OUT)/piggy
else
    KERNEL_BUILD_IMAGE := $(KERNEL_BUILD_IMAGE_INTERMEDIATE)
endif

KERNEL_MAKE_ARGS_INT :=
KERNEL_MAKE_ARGS_INT += -C $(TARGET_KERNEL_LOCATION)
KERNEL_MAKE_ARGS_INT += CROSS_COMPILE=$(TARGET_KERNEL_CROSS_COMPILE)
KERNEL_MAKE_ARGS_INT += ARCH=$(TARGET_KERNEL_ARCH)
ifneq ($(TARGET_KERNEL_SUBARCH),)
    KERNEL_MAKE_ARGS_INT += SUBARCH=$(TARGET_KERNEL_SUBARCH)
endif
KERNEL_MAKE_ARGS := $(KERNEL_MAKE_ARGS_INT) O=$(KERNEL_ABSOLUTE_OUT)



# Build the kernel
$(KERNEL_LAST_DEFCONFIG_SRC): kernelforce
ifneq ($(KERNEL_LAST_TARGET_DEFCONFIG),$(TARGET_KERNEL_DEFCONFIG))
	echo $(TARGET_KERNEL_DEFCONFIG) > $(KERNEL_LAST_DEFCONFIG_SRC)
endif

$(KERNEL_CONFIG): $(KERNEL_DEFCONFIG_SRC) $(KERNEL_LAST_DEFCONFIG_SRC)
	$(hide) $(MAKE) $(KERNEL_MAKE_ARGS) $(TARGET_KERNEL_DEFCONFIG)

$(KERNEL_BUILD_IMAGE_INTERMEDIATE): $(KERNEL_CONFIG) kernelforce
	$(hide) $(MAKE) $(KERNEL_MAKE_ARGS)
ifeq ($(TARGET_BUILD_KERNEL_MODULES),true)
	$(hide) test -d $(TARGET_KERNEL_MODULES_OUTDIR) || mkdir -p $(TARGET_KERNEL_MODULES_OUTDIR)
	$(hide) $(MAKE) $(KERNEL_MAKE_ARGS) INSTALL_MOD_PATH=$(KERNEL_MODULES_OUT_INT) modules_install
	$(hide) $(mv-modules)
	$(hide) $(clean-modules-folder)
endif


# Helper functions and targets
.PHONY: kernelforce kerneltags kernelconfig kernelheaders kernelclean
kernelforce:

kerneltags: $(KERNEL_CONFIG)
	$(MAKE) $(KERNEL_MAKE_ARGS_INT) tags

kernelconfig: $(KERNEL_CONFIG)
	$(MAKE) $(KERNEL_MAKE_ARGS) menuconfig
	$(MAKE) $(KERNEL_MAKE_ARGS) savedefconfig
	cp $(KERNEL_ABSOLUTE_OUT)/defconfig $(KERNEL_DEFCONFIG_SRC)

kernelheaders: $(KERNEL_CONFIG)
	$(MAKE) $(KERNEL_MAKE_ARGS) INSTALL_HDR_PATH=$(TARGET_KERNEL_HEADERS_OUTDIR) headers_install

kernelclean:
	rm -rf $(KERNEL_ABSOLUTE_OUT)
	$(MAKE) -C $(TARGET_KERNEL_LOCATION) mrproper

ifeq ($(TARGET_UNCOMPRESSED_KERNEL),true)
$(KERNEL_ABSOLUTE_OUT)/piggy : $(KERNEL_BUILD_IMAGE_INTERMEDIATE)
	$(hide) gunzip -c $(KERNEL_ABSOLUTE_OUT)/arch/arm/boot/compressed/piggy.gzip > $(KERNEL_ABSOLUTE_OUT)/piggy
endif

ifeq ($(TARGET_BUILD_KERNEL_MODULES),true)
define mv-modules
    mdpath=`find $(KERNEL_MODULES_OUT) -type f -name modules.dep`; \
    if [ "$$mdpath" != "" ]; then \
        mpath=`dirname $$mdpath`; \
        ko=`find $$mpath/kernel -type f -name *.ko`; \
        for i in $$ko; do cp $$i $(TARGET_KERNEL_MODULES_OUTDIR)/; done; \
    fi
endef

define clean-module-folder
    mdpath=`find $(KERNEL_MODULES_OUT) -type f -name modules.dep`; \
    if [ "$$mdpath" != "" ]; then \
        mpath=`dirname $$mdpath`; rm -rf $$mpath; \
    fi
endef
endif

