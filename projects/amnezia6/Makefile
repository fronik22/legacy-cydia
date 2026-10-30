# Amnezia6 — lightweight AmneziaWG client for jailbroken iOS 4–7 devices.
#
# Usage:
#   make host       build daemon + ctl + tests for the local macOS host (arm64/x86_64)
#   make test       run offline regression tests (test-live CONFIG=... for a server)
#   make device     cross-compile daemon + ctl for armv7 / iOS 6
#   make clean

# ---------------------------------------------------------------- toolchain ---
SDK      ?= /Users/mak/Documents/Codex/2026-09-18/new-chat/work/iPhoneOS13.7-armv7.sdk
DEVCLANG ?= /Users/mak/Documents/Codex/2026-07-01/new-chat/work/oldpipe-toolchain/swift55/expanded/swift-5.5.2-RELEASE-osx-package.pkg/Payload/usr/bin/clang

HOSTCC   ?= cc

WARN     := -Wall -Wextra -Wno-unused-parameter
DEFS     := -D_GNU_SOURCE

SRC_COMMON := \
	src/blake2s.c \
	src/crypto.c \
	src/config.c \
	src/protocol.c \
	src/log.c

SRC_DAEMON := \
	src/route.c \
	src/utun.c \
	src/dns.c \
	src/tunnel.c \
	src/control.c \
	src/daemon.c

SRC_CTL := src/ctl.c src/client.c

BUILD    := build

# --------------------------------------------------------------- host build ---
HOST_CFLAGS := -MMD -MP -std=gnu99 -O2 $(WARN) -Isrc -Ithird_party/monocypher -Ithird_party/senko -Ithird_party/quirc
HOST_LIBS   := -framework CoreFoundation

HOST_OBJDIR := $(BUILD)/host
HOST_DAEMON := $(BUILD)/amnezia6d-host
HOST_CTL    := $(BUILD)/amnezia6ctl-host
HOST_TESTS  := $(BUILD)/test_crypto $(BUILD)/test_dns $(BUILD)/test_handshake

host: $(HOST_DAEMON) $(HOST_CTL) $(HOST_TESTS)

$(HOST_OBJDIR):
	@mkdir -p $@

$(HOST_OBJDIR)/%.o: src/%.c | $(HOST_OBJDIR)
	$(HOSTCC) $(HOST_CFLAGS) $(DEFS) -c $< -o $@

$(HOST_OBJDIR)/monocypher.o: third_party/monocypher/monocypher.c | $(HOST_OBJDIR)
	$(HOSTCC) $(HOST_CFLAGS) $(DEFS) -c $< -o $@

HOST_COMMON_OBJ := $(SRC_COMMON:src/%.c=$(HOST_OBJDIR)/%.o) $(HOST_OBJDIR)/monocypher.o
HOST_DAEMON_OBJ := $(SRC_DAEMON:src/%.c=$(HOST_OBJDIR)/%.o)

$(HOST_DAEMON): $(HOST_COMMON_OBJ) $(HOST_DAEMON_OBJ)
	$(HOSTCC) $(HOST_CFLAGS) $^ -o $@ $(HOST_LIBS)

HOST_CTL_OBJ := $(SRC_CTL:src/%.c=$(HOST_OBJDIR)/%.o)

$(HOST_CTL): $(HOST_CTL_OBJ)
	$(HOSTCC) $(HOST_CFLAGS) $^ -o $@ $(HOST_LIBS)

$(BUILD)/test_%.o: tests/test_%.c | $(BUILD)
	$(HOSTCC) $(HOST_CFLAGS) $(DEFS) -c $< -o $@

$(BUILD)/test_crypto: $(BUILD)/test_crypto.o $(HOST_COMMON_OBJ)
	$(HOSTCC) $(HOST_CFLAGS) $^ -o $@ $(HOST_LIBS)

$(BUILD)/test_handshake: $(BUILD)/test_handshake.o $(HOST_COMMON_OBJ)
	$(HOSTCC) $(HOST_CFLAGS) $^ -o $@ $(HOST_LIBS)

$(BUILD):
	@mkdir -p $@

$(BUILD)/test_dns: $(BUILD)/test_dns.o $(HOST_OBJDIR)/log.o
	$(HOSTCC) $(HOST_CFLAGS) $^ -o $@ $(HOST_LIBS)

$(BUILD)/test_config_save: tests/test_config_save.m app/A6Daemon.m app/A6Daemon.h src/client.c src/client.h | $(BUILD)
	$(HOSTCC) -O2 -fno-objc-arc -Iapp -Isrc tests/test_config_save.m app/A6Daemon.m src/client.c -framework Foundation -o $@

$(BUILD)/test_route: tests/test_route.c src/route.c src/route.h | $(BUILD)
	$(HOSTCC) $(HOST_CFLAGS) tests/test_route.c -o $@

$(BUILD)/test_client: tests/test_client.c src/client.c src/client.h | $(BUILD)
	$(HOSTCC) $(HOST_CFLAGS) tests/test_client.c src/client.c -o $@

$(BUILD)/test_tunnel_send: tests/test_tunnel_send.c src/tunnel.c $(HOST_COMMON_OBJ) $(HOST_OBJDIR)/route.o $(HOST_OBJDIR)/utun.o $(HOST_OBJDIR)/dns.o | $(BUILD)
	$(HOSTCC) $(HOST_CFLAGS) tests/test_tunnel_send.c $(HOST_COMMON_OBJ) $(HOST_OBJDIR)/route.o $(HOST_OBJDIR)/utun.o $(HOST_OBJDIR)/dns.o -o $@ $(HOST_LIBS)

$(BUILD)/test_command_reply: tests/test_command_reply.m app/A6Daemon.m app/A6Daemon.h src/client.c src/client.h | $(BUILD)
	$(HOSTCC) -O2 -fno-objc-arc -Iapp -Isrc tests/test_command_reply.m app/A6Daemon.m src/client.c -framework Foundation -o $@

$(BUILD)/test_tunnel_retry: tests/test_tunnel_retry.c src/tunnel.c $(HOST_COMMON_OBJ) | $(BUILD)
	$(HOSTCC) $(HOST_CFLAGS) tests/test_tunnel_retry.c $(HOST_COMMON_OBJ) -o $@ $(HOST_LIBS)

test: $(BUILD)/test_clock $(BUILD)/dns-fixtures/animated-profile.json $(BUILD)/test_qr_parts $(BUILD)/test_control_permissions $(BUILD)/test_profiles $(BUILD)/test_protocol $(BUILD)/test_qr $(BUILD)/test_tunnel_retry $(BUILD)/test_command_reply $(BUILD)/test_tunnel_send $(BUILD)/test_client $(BUILD)/test_crypto $(BUILD)/test_dns $(BUILD)/test_config_save $(BUILD)/test_route
	$(BUILD)/test_clock
	$(BUILD)/test_qr_parts tests/fixtures $(BUILD)/dns-fixtures
	$(BUILD)/test_control_permissions
	$(BUILD)/test_profiles tests/fixtures
	$(BUILD)/test_protocol
	$(BUILD)/test_qr tests/fixtures/profile-qr.pgm
	$(BUILD)/test_tunnel_retry
	$(BUILD)/test_command_reply
	$(BUILD)/test_tunnel_send
	$(BUILD)/test_client
	$(BUILD)/test_crypto
	$(BUILD)/test_dns
	$(BUILD)/test_config_save
	$(BUILD)/test_route

test-live: $(BUILD)/test_handshake
	@test -n "$(CONFIG)" || (echo 'Set CONFIG to a private test profile'; exit 1)
	$(BUILD)/test_handshake "$(CONFIG)"

# ------------------------------------------------------------- device build ---
# iOS 4.3 keeps the client usable on every iOS 4-7 device. The newer SDK no
# longer ships crt1.3.3.o / libgcc_s.1, so toolchain/oldlibs carries copies.
DEV_TARGET  := armv7-apple-ios4.3
DEV_CFLAGS  := -MMD -MP -target $(DEV_TARGET) -isysroot $(SDK) -std=gnu99 -O2 $(WARN) \
               -fsigned-char -fno-common \
               -D__IPHONE_OS_VERSION_MIN_REQUIRED=43000 \
               -Isrc -Ithird_party/monocypher -Ithird_party/senko -Ithird_party/quirc $(DEFS)
DEV_LDFLAGS := -target $(DEV_TARGET) -isysroot $(SDK) -Wl,-dead_strip \
               -L"$(CURDIR)/toolchain/oldlibs" \
               -framework CoreFoundation

DEV_OBJDIR  := $(BUILD)/dev
DEV_DAEMON  := $(BUILD)/amnezia6d
DEV_CTL     := $(BUILD)/amnezia6ctl

# iOS 7 arm64 slice. SpringBoard is 64-bit on A7+ devices, so the injected
# badge hook needs arm64 even though the app and daemon remain armv7.
IOS9_SDK   ?= /Users/mak/Documents/Codex/2026-07-01/new-chat/work/oldpipe-toolchain/sdks/iPhoneOS9.3.sdk
ARM64_SDK  := $(BUILD)/sdk-arm64
ARM64_OBJ  := $(BUILD)/arm64
ARM64_FLAGS := -target arm64-apple-ios7.0 -isysroot $(ARM64_SDK) -Os \
               -fno-objc-arc -Wall -Wno-deprecated-declarations -Isrc
STATUS_ARMV7 := $(BUILD)/A6Status.armv7.dylib
STATUS_ARM64 := $(ARM64_OBJ)/A6Status.dylib
STATUS_FAT   := $(BUILD)/A6Status.dylib

device: $(DEV_DAEMON) $(DEV_CTL) $(STATUS_FAT)

$(DEV_OBJDIR):
	@mkdir -p $@

$(DEV_OBJDIR)/%.o: src/%.c | $(DEV_OBJDIR)
	$(DEVCLANG) $(DEV_CFLAGS) -c $< -o $@

$(DEV_OBJDIR)/monocypher.o: third_party/monocypher/monocypher.c | $(DEV_OBJDIR)
	$(DEVCLANG) $(DEV_CFLAGS) -c $< -o $@

DEV_COMMON_OBJ := $(SRC_COMMON:src/%.c=$(DEV_OBJDIR)/%.o) $(DEV_OBJDIR)/monocypher.o
DEV_DAEMON_OBJ := $(SRC_DAEMON:src/%.c=$(DEV_OBJDIR)/%.o)

$(DEV_DAEMON): $(DEV_COMMON_OBJ) $(DEV_DAEMON_OBJ)
	$(DEVCLANG) $(DEV_LDFLAGS) $^ -o $@
	$(LDID) -S $@

DEV_CTL_OBJ := $(SRC_CTL:src/%.c=$(DEV_OBJDIR)/%.o)

$(DEV_CTL): $(DEV_CTL_OBJ)
	$(DEVCLANG) $(DEV_LDFLAGS) $^ -o $@
	$(LDID) -S $@

$(ARM64_SDK)/SDKSettings.plist:
	python3 tools/prepare_arm64_sdk.py "$(IOS9_SDK)" "$(ARM64_SDK)"

$(ARM64_OBJ):
	@mkdir -p $@

$(STATUS_ARMV7): status/A6Status.m src/client.c src/client.h | $(BUILD)
	$(DEVCLANG) $(DEV_CFLAGS) -fno-objc-arc -dynamiclib -install_name /Library/MobileSubstrate/DynamicLibraries/A6Status.dylib status/A6Status.m src/client.c -L"$(CURDIR)/toolchain/oldlibs" -framework UIKit -framework Foundation -o $@
	$(LDID) -S $@

$(STATUS_ARM64): status/A6Status.m src/client.c src/client.h | $(ARM64_OBJ) $(ARM64_SDK)/SDKSettings.plist
	xcrun clang $(ARM64_FLAGS) -c status/A6Status.m -o $(ARM64_OBJ)/A6Status.o
	xcrun clang $(ARM64_FLAGS) -c src/client.c -o $(ARM64_OBJ)/client.o
	xcrun ld-classic -dylib -arch arm64 -iphoneos_version_min 7.0 \
	    -install_name /Library/MobileSubstrate/DynamicLibraries/A6Status.dylib \
	    -syslibroot "$(ARM64_SDK)" -undefined dynamic_lookup \
	    -o $@ $(ARM64_OBJ)/A6Status.o $(ARM64_OBJ)/client.o \
	    -framework UIKit -framework Foundation -lobjc
	$(LDID) -S $@

$(STATUS_FAT): $(STATUS_ARMV7) $(STATUS_ARM64)
	lipo -create $^ -output $@

# --------------------------------------------------------------- app build ---
APP_NAME    := Amnezia6
APP_DIR     := $(BUILD)/$(APP_NAME).app
APP_OBJDIR  := $(BUILD)/app
APP_BIN     := $(BUILD)/$(APP_NAME)

APP_CFLAGS  := -MMD -MP -target $(DEV_TARGET) -isysroot $(SDK) -std=gnu99 -O2 $(WARN) \
               -fsigned-char -fno-common -fno-objc-arc \
               -D__IPHONE_OS_VERSION_MIN_REQUIRED=43000 \
               -Iapp -Isrc -Ithird_party/monocypher -Ithird_party/senko -Ithird_party/quirc $(DEFS)
APP_LDFLAGS := -target $(DEV_TARGET) -isysroot $(SDK) -Wl,-dead_strip \
               -L"$(CURDIR)/toolchain/oldlibs" \
               -framework Foundation -framework UIKit -framework QuartzCore \
               -framework CoreGraphics -framework AVFoundation -framework CoreMedia -framework CoreVideo -lz -lm

APP_SRC_M := app/main.m app/A6AppDelegate.m app/A6RootController.m \
             app/A6LogController.m app/A6ConfigController.m app/A6Daemon.m \
             app/A6Profiles.m app/A6ProfilesController.m app/A6Import.m app/A6QR.m app/A6QRParts.m app/A6QRScannerController.m
APP_SRC_C := src/qr_frame.c src/client.c $(SRC_COMMON) third_party/monocypher/monocypher.c \
             third_party/senko/amnezia_bundle.c third_party/senko/b64.c third_party/senko/third_party/cJSON.c \
             third_party/quirc/quirc.c third_party/quirc/identify.c third_party/quirc/decode.c third_party/quirc/version_db.c
APP_OBJ   := $(APP_SRC_M:app/%.m=$(APP_OBJDIR)/app/%.o) \
             $(APP_SRC_C:%.c=$(APP_OBJDIR)/%.o)

ICONS := app/Icon.png app/Icon@2x.png app/Icon-72.png app/Icon-72@2x.png app/iTunesArtwork
LDID  ?= /Users/mak/Documents/Codex/2026-07-01/new-chat/work/oldpipe-toolchain/ldid

app: $(APP_DIR)

$(APP_OBJDIR)/app:
	@mkdir -p $@
$(APP_OBJDIR)/src:
	@mkdir -p $@

$(APP_OBJDIR)/app/%.o: app/%.m | $(APP_OBJDIR)/app
	$(DEVCLANG) $(APP_CFLAGS) -c $< -o $@

$(APP_OBJDIR)/%.o: %.c
	@mkdir -p $(dir $@)
	$(DEVCLANG) $(APP_CFLAGS) -c $< -o $@

$(APP_BIN): $(APP_OBJ)
	$(DEVCLANG) $(APP_LDFLAGS) $^ -o $@

# The source artwork is private and not part of the published tree. Regenerate
# icons only when both the source and the generator are present.
ifneq ($(wildcard artwork/Icon-source.png),)
$(ICONS): artwork/Icon-source.png tools/make_icon.py
	python3 tools/make_icon.py app
endif

$(APP_DIR): $(APP_BIN) app/Info.plist $(ICONS)
	@mkdir -p $(APP_DIR)
	cp app/Info.plist $(APP_DIR)/Info.plist
	cp $(ICONS) $(APP_DIR)/
	cp $(APP_BIN) $(APP_DIR)/$(APP_NAME)
	$(LDID) -Sapp/entitlements.plist $(APP_DIR)/$(APP_NAME)
	@echo "built $(APP_DIR)"

$(BUILD)/ToggleRegression.bundle: tests/ToggleRegression.m app/A6Daemon.h | $(BUILD)
	$(DEVCLANG) $(APP_CFLAGS) -L"$(CURDIR)/toolchain/oldlibs" -bundle tests/ToggleRegression.m -framework Foundation -framework UIKit -framework CoreGraphics -o $@
	$(LDID) -S $@

deb: device app
	python3 tools/build_deb.py
	python3 tests/test_package.py $(BUILD)/com.mak.amnezia6_1.3.4_iphoneos-arm.deb

-include $(wildcard build/host/*.d build/dev/*.d $(APP_OBJ:.o=.d) build/test_*.d)

.PHONY: host device app deb test test-live clean
clean:
	rm -rf $(BUILD)

IMPORT_C := third_party/senko/amnezia_bundle.c third_party/senko/b64.c third_party/senko/third_party/cJSON.c
$(BUILD)/test_profiles: tests/test_profiles.m app/A6Profiles.m app/A6Daemon.m app/A6Import.m $(IMPORT_C) $(HOST_COMMON_OBJ) src/client.c
	$(HOSTCC) $(HOST_CFLAGS) -Iapp -fno-objc-arc tests/test_profiles.m app/A6Profiles.m app/A6Daemon.m app/A6Import.m $(IMPORT_C) $(HOST_COMMON_OBJ) src/client.c -framework Foundation -lz -lm -o $@

$(BUILD)/test_protocol: tests/test_protocol.c tests/cookie_vector.h $(HOST_COMMON_OBJ)
	$(HOSTCC) $(HOST_CFLAGS) tests/test_protocol.c $(HOST_COMMON_OBJ) -framework CoreFoundation -o $@

$(BUILD)/test_qr: tests/test_qr.c third_party/quirc/quirc.c third_party/quirc/identify.c third_party/quirc/decode.c third_party/quirc/version_db.c
	$(HOSTCC) $(HOST_CFLAGS) $(filter %.c %.o,$^) -lm -o $@

$(BUILD)/test_protocol-device: tests/test_protocol.c tests/cookie_vector.h $(DEV_COMMON_OBJ)
	$(DEVCLANG) $(DEV_CFLAGS) tests/test_protocol.c $(DEV_COMMON_OBJ) $(DEV_LDFLAGS) -o $@
	$(LDID) -S $@
$(BUILD)/test_handshake-device: tests/test_handshake.c $(DEV_COMMON_OBJ)
	$(DEVCLANG) $(DEV_CFLAGS) tests/test_handshake.c $(DEV_COMMON_OBJ) $(DEV_LDFLAGS) -o $@
	$(LDID) -S $@
$(BUILD)/test_profiles-device: tests/test_profiles.m app/A6Profiles.m app/A6Daemon.m app/A6Import.m $(IMPORT_C) $(DEV_COMMON_OBJ) src/client.c
	$(DEVCLANG) $(APP_CFLAGS) tests/test_profiles.m app/A6Profiles.m app/A6Daemon.m app/A6Import.m $(IMPORT_C) $(DEV_COMMON_OBJ) src/client.c -L"$(CURDIR)/toolchain/oldlibs" -framework Foundation -framework CoreFoundation -lz -lm -o $@
	$(LDID) -S $@

$(BUILD)/test_control_permissions: tests/test_control_permissions.c src/control.c src/control.h | $(BUILD)
	$(HOSTCC) $(HOST_CFLAGS) tests/test_control_permissions.c -o $@

$(BUILD)/device_tunnel_probe: tests/device_tunnel_probe.c $(DEV_COMMON_OBJ) $(DEV_OBJDIR)/utun.o $(DEV_OBJDIR)/dns.o $(DEV_OBJDIR)/tunnel.o
	$(DEVCLANG) $(DEV_CFLAGS) tests/device_tunnel_probe.c $(DEV_COMMON_OBJ) $(DEV_OBJDIR)/utun.o $(DEV_OBJDIR)/dns.o $(DEV_OBJDIR)/tunnel.o $(DEV_LDFLAGS) -o $@
	$(LDID) -S $@

$(BUILD)/device_control_probe: tests/device_control_probe.c $(DEV_OBJDIR)/control.o
	$(DEVCLANG) $(DEV_CFLAGS) tests/device_control_probe.c $(DEV_OBJDIR)/control.o $(DEV_LDFLAGS) -o $@
	$(LDID) -S $@

# Test-only upstream QR encoder; never linked into the application.
$(BUILD)/make_animated_qr: tools/make_animated_qr.cpp third_party/qrcodegen/qrcodegen.cpp third_party/qrcodegen/qrcodegen.hpp $(BUILD)/b64-fixture.o | $(BUILD)
	$(CXX) -std=c++11 -O2 -Ithird_party/qrcodegen -Ithird_party/senko tools/make_animated_qr.cpp third_party/qrcodegen/qrcodegen.cpp $(BUILD)/b64-fixture.o -lz -o $@
$(BUILD)/b64-fixture.o: third_party/senko/b64.c | $(BUILD)
	$(HOSTCC) $(HOST_CFLAGS) -c $< -o $@
$(BUILD)/test_qr_parts: tests/test_qr_parts.m app/A6QRParts.m app/A6QRParts.h app/A6Import.m app/A6Import.h src/qr_frame.c src/qr_frame.h $(IMPORT_C) $(HOST_COMMON_OBJ) third_party/quirc/quirc.c third_party/quirc/identify.c third_party/quirc/decode.c third_party/quirc/version_db.c
	$(HOSTCC) $(HOST_CFLAGS) -Iapp -fno-objc-arc $(filter %.m %.c %.o,$^) -framework Foundation -lz -lm -o $@
fixtures-animated: $(BUILD)/make_animated_qr
	$(BUILD)/make_animated_qr tests/fixtures/profile.json tests/fixtures
.PHONY: fixtures-animated

$(BUILD)/test_qr_parts-device: tests/test_qr_parts.m app/A6QRParts.m app/A6QRParts.h app/A6Import.m app/A6Import.h src/qr_frame.c src/qr_frame.h $(IMPORT_C) $(DEV_COMMON_OBJ) third_party/quirc/quirc.c third_party/quirc/identify.c third_party/quirc/decode.c third_party/quirc/version_db.c
	$(DEVCLANG) $(APP_CFLAGS) $(filter %.m %.c %.o,$^) -L"$(CURDIR)/toolchain/oldlibs" -framework Foundation -framework CoreFoundation -lz -lm -o $@
	$(LDID) -S $@

$(BUILD)/QRRegression.bundle: tests/QRRegression.m app/A6QRScannerController.h | $(BUILD)
	$(DEVCLANG) $(APP_CFLAGS) -L"$(CURDIR)/toolchain/oldlibs" -bundle tests/QRRegression.m -framework Foundation -framework UIKit -framework AVFoundation -framework CoreMedia -framework CoreVideo -o $@
	$(LDID) -S $@

$(BUILD)/test_dns-device: tests/test_dns.c src/dns.c src/dns.h src/log.c src/log.h | $(BUILD)
	$(DEVCLANG) $(DEV_CFLAGS) tests/test_dns.c src/log.c $(DEV_LDFLAGS) -o $@
	$(LDID) -S $@

$(BUILD)/dns-fixtures/animated-profile.json: tests/fixtures/profile-awg31-full-template.json $(BUILD)/make_animated_qr
	@mkdir -p $(BUILD)/dns-fixtures
	$(BUILD)/make_animated_qr $< $(BUILD)/dns-fixtures two

$(BUILD)/test_tunnel_retry-device: tests/test_tunnel_retry.c src/tunnel.c src/tunnel.h $(DEV_COMMON_OBJ)
	$(DEVCLANG) $(DEV_CFLAGS) tests/test_tunnel_retry.c $(DEV_COMMON_OBJ) $(DEV_LDFLAGS) -o $@
	$(LDID) -S $@

$(BUILD)/test_clock: tests/test_clock.c src/protocol.c $(filter-out $(HOST_OBJDIR)/protocol.o,$(HOST_COMMON_OBJ))
	$(HOSTCC) $(HOST_CFLAGS) tests/test_clock.c $(filter-out $(HOST_OBJDIR)/protocol.o,$(HOST_COMMON_OBJ)) -o $@ $(HOST_LIBS)

$(BUILD)/test_clock-device: tests/test_clock.c src/protocol.c $(filter-out $(DEV_OBJDIR)/protocol.o,$(DEV_COMMON_OBJ))
	$(DEVCLANG) $(DEV_CFLAGS) tests/test_clock.c $(filter-out $(DEV_OBJDIR)/protocol.o,$(DEV_COMMON_OBJ)) $(DEV_LDFLAGS) -o $@
	$(LDID) -S $@
