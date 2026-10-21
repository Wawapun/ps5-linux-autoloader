# Native installer plus a standalone PC setup host.
PYTHON := python3
LOADER := third_party/ps5-webkit-remote-loader
INSTALLER_COMMON := $(LOADER)/installer/common
include $(INSTALLER_COMMON)/common.mk
SDK := /opt/ps5-payload-sdk
CC := $(SDK)/bin/prospero-clang
STRIP := $(SDK)/bin/prospero-strip
TARGET := $(SDK)/target
CFLAGS := -Os -Wall -ffunction-sections -fdata-sections -Iinclude -I$(INSTALLER_COMMON) -I$(TARGET)/include
LDFLAGS := -Wl,--gc-sections
LIBS := $(TARGET)/lib/libmicrohttpd.a -L$(TARGET)/lib -lpthread \
        -lSceNetCtl -lSceUserService -lSceSystemService -lSceAppInstUtil
SRCS := src/main.c src/http_server.c $(INSTALLER_COMMON_SRCS)
ELF := installer.elf

# One version per make invocation, including dirty-tree builds.
ifndef BUILD_VERSION
BUILD_VERSION := $(shell $(PYTHON) tools/gen_version.py --print)
endif
export BUILD_VERSION

ifndef BUILD_TITLE
BUILD_TITLE := $(shell $(PYTHON) tools/gen_version.py --title)
endif

BUILDER := $(PYTHON) $(LOADER)/tools/build_standalone.py
CHAINS := poops relapse
# One standalone page per chain, carrying elfldr-check.js, the chain's exploit,
# then autoload.js. The chain sources are unmodified
# submodule payloads; each exploit prefetches elfldr/kexp itself.
# Autoloader appearance is embedded through the upstream builder's hooks.
# Each variable accepts a whitespace-separated list of file paths.
PAGE_CSS ?= frontend/autoloader/style.css
PAGE_JS ?= frontend/autoloader/app.js
PAGE_CONFIG := build/page-config.js
ELFLDR_TAG := v0.26-bb1e117
ELFLDR_VIRTUAL := shared/elfldr-ps5-$(ELFLDR_TAG).elf
PAGE_FLAGS := --elfldr $(ELFLDR_VIRTUAL)=build/deps/elfldr.elf \
              $(foreach file,$(PAGE_CSS),--css "$(file)") \
              --js "$(PAGE_CONFIG)" \
              $(foreach file,$(PAGE_JS),--js "$(file)")
APP_PAGE := build/autoloader/index.html
HOST_PAGE := build/host/index.html
STAGE := frontend/dist
REGISTRY := include/file_registry.h include/file_registry.c
ICONS := assets/icon0.png assets/icon.ico
INSTALLER_LOGO := frontend/installer-page/logo.svg
HOST_PAYLOAD ?= $(ELF)
PAYLOAD_TAG ?= $(shell git -C third_party/ps5-unified-autoloader describe --tags --always 2>/dev/null || echo v0.1.5-915a65e)
AUTOLOAD_PAYLOAD_VIRTUAL ?= ps5-unified-autoloader-$(PAYLOAD_TAG).elf
# Bake a custom ELF into the page instead of the unified autoloader. When the file
# below exists it is embedded as the autoload payload; otherwise the downloaded
# unified autoloader is used as before.
CUSTOM_PAYLOAD ?= custom/Linuxloader.elf
AUTOLOAD_ELF := $(if $(wildcard $(CUSTOM_PAYLOAD)),$(CUSTOM_PAYLOAD),build/deps/autoload.elf)
HOST_PAYLOAD_VIRTUAL ?= $(if $(filter-out installer.elf,$(notdir $(HOST_PAYLOAD))),$(notdir $(HOST_PAYLOAD)),webkit-autoloader-installer_v$(BUILD_VERSION).elf)

# Optional cache-repair hardware test builds; use make clean all when changing.
SIMULATE ?= 0
ifneq ($(SIMULATE),0)
CFLAGS += -DINSTALLER_SIMULATE_CACHE_CORRUPTION=$(SIMULATE)
endif

all: $(ELF)

version:
	$(PYTHON) tools/gen_version.py

print-version:
	@echo $(BUILD_VERSION)

test:
	node tools/test_elfldr_check.js
	node tools/test_autoload_payload.js
	node tools/test_installer.js
	node tools/test_selection_flow.js

# Run on Linux or in the SDK container; PS5 services are stubbed.
test-native:
	$(PYTHON) $(LOADER)/tools/installer_common_test.py

icons: $(ICONS) $(INSTALLER_LOGO)
assets/icon0.png: assets/icon.svg tools/gen_icons.py
	$(PYTHON) tools/gen_icons.py
assets/icon.ico: assets/icon0.png
	@test -f $@ || $(PYTHON) tools/gen_icons.py

$(INSTALLER_LOGO): assets/icon.svg
	cp $< $@

payload-deps:
	./tools/download_deps.sh

# One page per chain: ELF loader check first, then exploit and autoload. Both
# are cached, so the choice of chain never has to invalidate anything.
page: payload-deps
	@mkdir -p build/autoloader
	@echo "autoload payload: $(AUTOLOAD_ELF)"
	$(PYTHON) tools/gen_version.py --page-config $(PAGE_CONFIG)
	@for chain in $(CHAINS); do \
	    echo "$(BUILDER) payloads/$$chain.js -> build/autoloader/$$chain.html"; \
	    $(BUILDER) $(CURDIR)/payloads/elfldr-check.js payloads/$$chain.js $(CURDIR)/payloads/autoload.js::$(AUTOLOAD_PAYLOAD_VIRTUAL) \
	        --title "$(BUILD_TITLE)" $(PAGE_FLAGS) \
	        --embed $(AUTOLOAD_PAYLOAD_VIRTUAL)=$(AUTOLOAD_ELF) \
	        -o $(CURDIR)/build/autoloader/$$chain.html || exit 1; \
	done

registry: version page $(INSTALLER_LOGO)
	rm -rf $(STAGE)
	@mkdir -p $(STAGE)/app/$(BUILD_VERSION)
	cp frontend/installer-page/index.html $(INSTALLER_LOGO) $(STAGE)/
	cp frontend/pointer/index.html $(STAGE)/app/index.html
	@for chain in $(CHAINS); do \
	    cp build/autoloader/$$chain.html $(STAGE)/app/$(BUILD_VERSION)/$$chain.html || exit 1; \
	done
	@echo "$(BUILD_VERSION)" > $(STAGE)/VERSION
	$(PYTHON) tools/gen_file_registry.py $(STAGE) $(word 1,$(REGISTRY)) $(word 2,$(REGISTRY))

$(ELF): registry icons $(SRCS) $(wildcard include/*.h) $(INSTALLER_COMMON_HEADERS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(SRCS) include/file_registry.c $(LIBS)
	$(STRIP) $@

# The setup host embeds the installer ELF. It packages both chains (Relapse as
# default index.html, Poops as poops.html) so firmwares where Relapse is
# unsupported (9.05, 11.40) are automatically routed to Poops.
HOST_RELAPSE := build/host/relapse.html
HOST_POOPS := build/host/poops.html

host: $(HOST_PAYLOAD) payload-deps assets/icon.ico
	@mkdir -p build/host
	$(PYTHON) tools/gen_version.py --page-config $(PAGE_CONFIG)
	$(BUILDER) $(CURDIR)/payloads/elfldr-check.js payloads/relapse.js $(CURDIR)/payloads/autoload.js::$(HOST_PAYLOAD_VIRTUAL) \
	    --title "$(BUILD_TITLE)" $(PAGE_FLAGS) \
	    --embed $(HOST_PAYLOAD_VIRTUAL)=$(HOST_PAYLOAD) -o $(CURDIR)/$(HOST_RELAPSE)
	$(BUILDER) $(CURDIR)/payloads/elfldr-check.js payloads/poops.js $(CURDIR)/payloads/autoload.js::$(HOST_PAYLOAD_VIRTUAL) \
	    --title "$(BUILD_TITLE)" $(PAGE_FLAGS) \
	    --embed $(HOST_PAYLOAD_VIRTUAL)=$(HOST_PAYLOAD) -o $(CURDIR)/$(HOST_POOPS)
	$(PYTHON) $(LOADER)/tools/build_host.py \
	    --page index.html=$(HOST_RELAPSE) \
	    --page poops.html=$(HOST_POOPS) \
	    --version $(BUILD_VERSION) --name "PS5 WEBKIT AUTOLOADER" --output webkit-autoloader-host.py

dev: page
	$(PYTHON) -m http.server 8123 --bind 127.0.0.1 --directory build/autoloader

clean:
	rm -rf $(STAGE) build/autoloader build/host
	rm -f $(ELF) $(REGISTRY) include/wkali_version.h webkit-autoloader-host.py
	rm -f $(PAGE_CONFIG)

.PHONY: all version print-version test test-native icons payload-deps page registry host dev clean
