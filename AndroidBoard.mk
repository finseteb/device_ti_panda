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

# WARNING: Everything listed here will be built on ALL platforms,
# including x86, the emulator, and the SDK.  Modules must be uniquely
# named (liblights.panda), and must build everywhere, or limit themselves
# to only building on ARM if they include assembly. Individual makefiles
# are responsible for having their own logic, for fine-grained control.

LOCAL_PATH := $(call my-dir)

ifneq ($(TARGET_NO_KERNEL),true)
ifeq ($(TARGET_BUILD_KERNEL),true)
    include $(LOCAL_PATH)/kernel.mk
    LOCAL_KERNEL := $(KERNEL_BUILD_IMAGE)
else
ifneq ($(TARGET_PREBUILT_KERNEL),)
    LOCAL_KERNEL := $(TARGET_PREBUILT_KERNEL)
endif
endif

file := $(INSTALLED_KERNEL_TARGET)
ALL_PREBUILT += $(file)
$(file) : $(LOCAL_KERNEL) | $(ACP)
	$(transform-prebuilt-to-target)
endif
