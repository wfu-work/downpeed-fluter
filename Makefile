SHELL := bash
.DEFAULT_GOAL := help

ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BACKEND_DIR := $(ROOT_DIR)/backend
APP_DIR := $(ROOT_DIR)/app
BUILD_DIR := $(ROOT_DIR)/.build
DIST_DIR := $(ROOT_DIR)/dist

GO ?= go
FLUTTER ?= flutter
DART ?= dart
GOCACHE ?= $(BUILD_DIR)/go-cache

VERSION ?= $(shell awk '/^version:/ { print $$2; exit }' $(APP_DIR)/pubspec.yaml)
BUILD_NUMBER ?= 1
COMMIT ?= $(shell git -C $(ROOT_DIR) rev-parse --short HEAD 2>/dev/null || printf local)
BUILD_DATE ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
RELEASE_CHANNEL ?= local
TARGET_ARCH ?= $(shell $(GO) env GOARCH)

ENGINE_ADDRESS ?= 127.0.0.1:17680
API_BASE_URL ?= http://$(ENGINE_ADDRESS)
DATA_DIR ?= $(BACKEND_DIR)/.data
MAX_CONCURRENT_TASKS ?= 3
MAX_RETRIES ?= 2
RETRY_BASE_DELAY ?= 1s
DOWNLOAD_RATE_LIMIT ?= 0

ENGINE_FLAGS := \
	--address '$(ENGINE_ADDRESS)' \
	--data-dir '$(DATA_DIR)' \
	--max-concurrent-tasks '$(MAX_CONCURRENT_TASKS)' \
	--max-retries '$(MAX_RETRIES)' \
	--retry-base-delay '$(RETRY_BASE_DELAY)' \
	--download-rate-limit '$(DOWNLOAD_RATE_LIMIT)'

BUILDINFO_PACKAGE := github.com/wfu-work/downpeed-fluter/backend/internal/buildinfo
GO_LDFLAGS := -s -w \
	-X=$(BUILDINFO_PACKAGE).Version=$(VERSION) \
	-X=$(BUILDINFO_PACKAGE).Commit=$(COMMIT) \
	-X=$(BUILDINFO_PACKAGE).Date=$(BUILD_DATE)

ifeq ($(OS),Windows_NT)
HOST_OS := windows
HOST_DEVICE := windows
HOST_ENGINE_NAME := downpeedd.exe
else
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
HOST_OS := macos
HOST_DEVICE := macos
HOST_LIBRARY_NAME := libdownpeed.dylib
else ifeq ($(UNAME_S),Linux)
HOST_OS := linux
HOST_DEVICE := linux
HOST_LIBRARY_NAME := libdownpeed.so
else
HOST_OS := unsupported
HOST_DEVICE := unsupported
endif
HOST_ENGINE_NAME := downpeedd
endif

ifeq ($(OS),Windows_NT)
HOST_LIBRARY_NAME := downpeed.dll
endif

ifeq ($(TARGET_ARCH),amd64)
FLUTTER_ARCH := x64
else
FLUTTER_ARCH := $(TARGET_ARCH)
endif

ENGINE_HOST_BIN := $(BUILD_DIR)/engine/$(HOST_OS)-$(TARGET_ARCH)/$(HOST_ENGINE_NAME)
ENGINE_HOST_LIBRARY := $(BUILD_DIR)/engine/$(HOST_OS)-$(TARGET_ARCH)/$(HOST_LIBRARY_NAME)
MACOS_APP := $(APP_DIR)/build/macos/Build/Products/Release/Downpeed.app
WINDOWS_BUNDLE := $(APP_DIR)/build/windows/$(FLUTTER_ARCH)/runner/Release
LINUX_BUNDLE := $(APP_DIR)/build/linux/$(FLUTTER_ARCH)/release/bundle
RELEASE_WORK_DIR := $(BUILD_DIR)/release
THIRD_PARTY_NOTICES := $(RELEASE_WORK_DIR)/THIRD_PARTY_NOTICES.txt
PACKAGE_BASENAME := downpeed-$(VERSION)-$(HOST_OS)-$(TARGET_ARCH)
DIST_NOTICES := $(DIST_DIR)/$(PACKAGE_BASENAME)-THIRD_PARTY_NOTICES.txt
RELEASE_MANIFEST := $(DIST_DIR)/$(PACKAGE_BASENAME)-manifest.json
RELEASE_CHECKSUMS := $(DIST_DIR)/$(PACKAGE_BASENAME)-SHA256SUMS

ifeq ($(HOST_OS),macos)
PACKAGE_ARTIFACT := $(DIST_DIR)/$(PACKAGE_BASENAME).dmg
PACKAGE_EXECUTABLE := $(DIST_DIR)/$(PACKAGE_BASENAME)/Downpeed.app/Contents/MacOS/Downpeed
SIGNING_MODE ?= adhoc
else ifeq ($(HOST_OS),windows)
PACKAGE_ARTIFACT := $(DIST_DIR)/$(PACKAGE_BASENAME).zip
PACKAGE_EXECUTABLE := $(DIST_DIR)/$(PACKAGE_BASENAME)/downpeed.exe
SIGNING_MODE ?= unsigned
else
PACKAGE_ARTIFACT := $(DIST_DIR)/$(PACKAGE_BASENAME).tar.gz
PACKAGE_EXECUTABLE := $(DIST_DIR)/$(PACKAGE_BASENAME)/downpeed
SIGNING_MODE ?= unsigned
endif

FLUTTER_BUILD_DEFINES := \
	--dart-define=DOWNPEED_APP_VERSION=$(VERSION) \
	--dart-define=DOWNPEED_BUILD_NUMBER=$(BUILD_NUMBER) \
	--dart-define=DOWNPEED_COMMIT=$(COMMIT) \
	--dart-define=DOWNPEED_BUILD_DATE=$(BUILD_DATE) \
	--dart-define=DOWNPEED_RELEASE_CHANNEL=$(RELEASE_CHANNEL)

.PHONY: help doctor deps go-deps flutter-deps format check test test-go test-race \
	test-flutter integration-test analyze license-check third-party-notices \
	release-metadata verify-release-metadata engine app dev start run build package release \
	build-engine build-engines build-engine-macos build-engine-windows build-engine-linux \
	build-engine-library build-engine-libraries build-engine-library-macos \
	build-engine-library-windows build-engine-library-linux install-engine-library \
	build-macos build-windows build-linux package-macos package-windows package-linux \
	verify-package verify-package-macos verify-package-windows verify-package-linux \
	smoke-package clean

help: ## 显示可用命令
	@awk 'BEGIN { FS = ":.*## "; print "Downpeed build commands\n" } /^[a-zA-Z0-9_.-]+:.*## / { printf "  %-24s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@printf '\n当前宿主平台: %s/%s；版本: %s\n' '$(HOST_OS)' '$(TARGET_ARCH)' '$(VERSION)'
	@printf 'Flutter 桌面包必须在目标系统原生构建；Windows/Linux 当前生成便携发布包。\n'

doctor: ## 检查 Go、Flutter 和当前桌面设备
	@$(GO) version
	@$(FLUTTER) --version
	@$(FLUTTER) doctor
	@$(FLUTTER) devices

go-deps: ## 下载 Go 依赖
	@cd $(BACKEND_DIR) && GOCACHE='$(GOCACHE)' $(GO) mod download

flutter-deps: ## 下载 Flutter 依赖
	@cd $(APP_DIR) && $(FLUTTER) pub get

deps: go-deps flutter-deps ## 下载全部开发依赖

format: ## 格式化 Go 和 Dart 源码
	@cd $(BACKEND_DIR) && GOCACHE='$(GOCACHE)' $(GO) fmt ./...
	@cd $(APP_DIR) && $(DART) format lib test integration_test ../tool

test-go: ## 运行 Go 单元测试
	@cd $(BACKEND_DIR) && GOCACHE='$(GOCACHE)' $(GO) test ./...

test-race: ## 运行 Go 竞态检测
	@cd $(BACKEND_DIR) && GOCACHE='$(GOCACHE)' $(GO) test -race ./...

analyze: ## 运行 Flutter 静态分析
	@cd $(APP_DIR) && $(FLUTTER) analyze
	@cd $(APP_DIR) && $(DART) analyze ../tool/package_smoke.dart

test-flutter: ## 运行 Flutter 测试
	@cd $(APP_DIR) && $(FLUTTER) test

integration-test: flutter-deps build-engine-library ## 运行内嵌引擎真实下载生命周期测试
	@cd $(APP_DIR) && $(FLUTTER) test integration_test/download_lifecycle_test.dart \
		-d $(HOST_DEVICE) $(FLUTTER_BUILD_DEFINES)

test: test-go test-flutter ## 运行 Go 与 Flutter 测试

license-check: ## 校验 BT 候选证据与 c-shared 发布依赖闭包
	@cd $(BACKEND_DIR) && GOCACHE='$(GOCACHE)' $(GO) run ./cmd/licensecheck -mode candidate
	@cd $(BACKEND_DIR) && GOCACHE='$(GOCACHE)' $(GO) run ./cmd/licensecheck -mode release

check: ## 执行格式、静态分析、单测、竞态和引擎构建检查
	@cd $(BACKEND_DIR) && unformatted="$$(gofmt -l $$(find . -type f -name '*.go'))"; \
		test -z "$$unformatted" || { printf 'Go files need formatting:\n%s\n' "$$unformatted"; exit 1; }
	@cd $(APP_DIR) && $(DART) format --output=none --set-exit-if-changed lib test integration_test ../tool
	@$(MAKE) --no-print-directory test-go
	@$(MAKE) --no-print-directory test-race
	@$(MAKE) --no-print-directory analyze
	@$(MAKE) --no-print-directory test-flutter
	@$(MAKE) --no-print-directory license-check
	@cd $(BACKEND_DIR) && GOCACHE='$(GOCACHE)' $(GO) build ./...
	@$(MAKE) --no-print-directory build-engine-library

third-party-notices: flutter-deps ## 从实际发布依赖图生成第三方许可证文件
	@mkdir -p '$(RELEASE_WORK_DIR)'
	@cd $(BACKEND_DIR) && GOCACHE='$(GOCACHE)' $(GO) run ./cmd/releasectl notices \
		--repo-root '$(ROOT_DIR)' --output '$(THIRD_PARTY_NOTICES)'

release-metadata: third-party-notices ## 为当前平台发布物生成 Manifest 和 SHA256
	@test -f '$(PACKAGE_ARTIFACT)' || { echo 'Missing release artifact: $(PACKAGE_ARTIFACT)' >&2; exit 1; }
	@mkdir -p '$(DIST_DIR)'
	@cp '$(THIRD_PARTY_NOTICES)' '$(DIST_NOTICES)'
	@cd $(BACKEND_DIR) && GOCACHE='$(GOCACHE)' $(GO) run ./cmd/releasectl manifest \
		--version '$(VERSION)' --build-number '$(BUILD_NUMBER)' \
		--commit '$(COMMIT)' --build-date '$(BUILD_DATE)' \
		--channel '$(RELEASE_CHANNEL)' --platform '$(HOST_OS)' \
		--arch '$(TARGET_ARCH)' --signing '$(SIGNING_MODE)' \
		--artifact '$(PACKAGE_ARTIFACT)' --notices '$(DIST_NOTICES)' \
		--output '$(RELEASE_MANIFEST)' --checksums '$(RELEASE_CHECKSUMS)'

verify-release-metadata: ## 校验当前发布 Manifest 与所有 SHA256
	@cd $(BACKEND_DIR) && GOCACHE='$(GOCACHE)' $(GO) run ./cmd/releasectl verify \
		--manifest '$(RELEASE_MANIFEST)' --checksums '$(RELEASE_CHECKSUMS)'

engine: go-deps ## 启动 Go 下载引擎（阻塞当前终端）
	@cd $(BACKEND_DIR) && GOCACHE='$(GOCACHE)' $(GO) run ./cmd/downpeedd $(ENGINE_FLAGS)

app: flutter-deps ## 启动当前平台 Flutter 客户端（需另开终端运行 engine）
	@cd $(APP_DIR) && $(FLUTTER) run -d $(HOST_DEVICE) \
		--dart-define=DOWNPEED_API_BASE_URL=$(API_BASE_URL) \
		--dart-define=DOWNPEED_ENGINE_ADDRESS=$(ENGINE_ADDRESS) \
		--dart-define=DOWNPEED_ENGINE_MODE=external \
		$(FLUTTER_BUILD_DEFINES)

dev: deps build-engine ## 单终端启动 Go 引擎和当前平台 Flutter 客户端
	@set -eu; \
		mkdir -p '$(DATA_DIR)'; \
		'$(ENGINE_HOST_BIN)' $(ENGINE_FLAGS) & \
		engine_pid=$$!; \
		cleanup() { kill $$engine_pid 2>/dev/null || true; wait $$engine_pid 2>/dev/null || true; }; \
		trap cleanup EXIT INT TERM; \
		sleep 1; \
		if ! kill -0 $$engine_pid 2>/dev/null; then \
			echo 'Downpeed engine failed to start; check whether port $(ENGINE_ADDRESS) is available.' >&2; \
			exit 1; \
		fi; \
		cd '$(APP_DIR)'; \
			$(FLUTTER) run -d '$(HOST_DEVICE)' \
				--dart-define=DOWNPEED_API_BASE_URL='$(API_BASE_URL)' \
				--dart-define=DOWNPEED_ENGINE_ADDRESS='$(ENGINE_ADDRESS)' \
				--dart-define=DOWNPEED_ENGINE_MODE=external \
				$(FLUTTER_BUILD_DEFINES)

start: dev ## dev 的别名
run: dev ## dev 的别名

build-engine: build-engine-$(HOST_OS) ## 编译当前平台 Go 引擎

build-engines: build-engine-macos build-engine-windows build-engine-linux ## 交叉编译三平台 Go 引擎

build-engine-macos: ## 编译 macOS Go 引擎
	@mkdir -p $(BUILD_DIR)/engine/macos-$(TARGET_ARCH)
	@cd $(BACKEND_DIR) && GOCACHE='$(GOCACHE)' CGO_ENABLED=0 GOOS=darwin GOARCH=$(TARGET_ARCH) $(GO) build \
		-trimpath -ldflags='$(GO_LDFLAGS)' \
		-o $(BUILD_DIR)/engine/macos-$(TARGET_ARCH)/downpeedd ./cmd/downpeedd

build-engine-windows: ## 编译 Windows Go 引擎
	@mkdir -p $(BUILD_DIR)/engine/windows-$(TARGET_ARCH)
	@cd $(BACKEND_DIR) && GOCACHE='$(GOCACHE)' CGO_ENABLED=0 GOOS=windows GOARCH=$(TARGET_ARCH) $(GO) build \
		-trimpath -ldflags='$(GO_LDFLAGS)' \
		-o $(BUILD_DIR)/engine/windows-$(TARGET_ARCH)/downpeedd.exe ./cmd/downpeedd

build-engine-linux: ## 编译 Linux Go 引擎
	@mkdir -p $(BUILD_DIR)/engine/linux-$(TARGET_ARCH)
	@cd $(BACKEND_DIR) && GOCACHE='$(GOCACHE)' CGO_ENABLED=0 GOOS=linux GOARCH=$(TARGET_ARCH) $(GO) build \
		-trimpath -ldflags='$(GO_LDFLAGS)' \
		-o $(BUILD_DIR)/engine/linux-$(TARGET_ARCH)/downpeedd ./cmd/downpeedd

build-engine-library: build-engine-library-$(HOST_OS) ## 编译并安装当前平台 Go 动态库

build-engine-libraries: build-engine-library-macos build-engine-library-windows build-engine-library-linux ## 编译三平台 Go 动态库（需要各平台 CGO 工具链）

build-engine-library-macos: ## 编译 macOS Go 动态库
	@if [ '$(HOST_OS)' != macos ]; then echo 'macOS c-shared 动态库必须在 macOS 或已配置交叉 CGO 工具链的环境构建' >&2; exit 1; fi
	@mkdir -p '$(BUILD_DIR)/engine/macos-$(TARGET_ARCH)' '$(APP_DIR)/macos/Runner/Frameworks'
	@cd $(BACKEND_DIR) && GOCACHE='$(GOCACHE)' CGO_ENABLED=1 GOOS=darwin GOARCH=$(TARGET_ARCH) $(GO) build \
		-tags=nosqlite -buildmode=c-shared -trimpath -ldflags='$(GO_LDFLAGS)' \
		-o '$(ENGINE_HOST_LIBRARY)' ./cmd/downpeedlib
	@cp '$(ENGINE_HOST_LIBRARY)' '$(APP_DIR)/macos/Runner/Frameworks/libdownpeed.dylib'
	@cp '$(basename $(ENGINE_HOST_LIBRARY)).h' '$(APP_DIR)/macos/Runner/Frameworks/libdownpeed.h'

build-engine-library-windows: ## 编译 Windows Go 动态库
	@if [ '$(HOST_OS)' != windows ]; then echo 'Windows c-shared 动态库必须在 Windows 或已配置交叉 CGO 工具链的环境构建' >&2; exit 1; fi
	@mkdir -p '$(BUILD_DIR)/engine/windows-$(TARGET_ARCH)' '$(APP_DIR)/windows/runner/resources'
	@cd $(BACKEND_DIR) && GOCACHE='$(GOCACHE)' CGO_ENABLED=1 GOOS=windows GOARCH=$(TARGET_ARCH) $(GO) build \
		-tags=nosqlite -buildmode=c-shared -trimpath -ldflags='$(GO_LDFLAGS)' \
		-o '$(ENGINE_HOST_LIBRARY)' ./cmd/downpeedlib
	@cp '$(ENGINE_HOST_LIBRARY)' '$(APP_DIR)/windows/runner/resources/downpeed.dll'
	@cp '$(basename $(ENGINE_HOST_LIBRARY)).h' '$(APP_DIR)/windows/runner/resources/downpeed.h'

build-engine-library-linux: ## 编译 Linux Go 动态库
	@if [ '$(HOST_OS)' != linux ]; then echo 'Linux c-shared 动态库必须在 Linux 或已配置交叉 CGO 工具链的环境构建' >&2; exit 1; fi
	@mkdir -p '$(BUILD_DIR)/engine/linux-$(TARGET_ARCH)' '$(APP_DIR)/linux/runner/resources'
	@cd $(BACKEND_DIR) && GOCACHE='$(GOCACHE)' CGO_ENABLED=1 GOOS=linux GOARCH=$(TARGET_ARCH) $(GO) build \
		-tags=nosqlite -buildmode=c-shared -trimpath -ldflags='$(GO_LDFLAGS)' \
		-o '$(ENGINE_HOST_LIBRARY)' ./cmd/downpeedlib
	@cp '$(ENGINE_HOST_LIBRARY)' '$(APP_DIR)/linux/runner/resources/libdownpeed.so'
	@cp '$(basename $(ENGINE_HOST_LIBRARY)).h' '$(APP_DIR)/linux/runner/resources/libdownpeed.h'

install-engine-library: build-engine-library ## 当前平台动态库已复制到 Flutter 原生工程

build: build-$(HOST_OS) ## 构建当前平台 Release 客户端与引擎

build-macos: flutter-deps build-engine-library-macos ## 构建内嵌引擎的 macOS Release
	@if [ '$(HOST_OS)' != macos ]; then echo 'macOS Flutter 包必须在 macOS 上构建' >&2; exit 1; fi
	@cd $(APP_DIR) && $(FLUTTER) build macos --release \
		--build-name=$(VERSION) --build-number=$(BUILD_NUMBER) \
		--dart-define=DOWNPEED_API_BASE_URL=$(API_BASE_URL) \
		--dart-define=DOWNPEED_ENGINE_ADDRESS=$(ENGINE_ADDRESS) \
		--dart-define=DOWNPEED_ENGINE_MODE=embedded \
		$(FLUTTER_BUILD_DEFINES)

build-windows: flutter-deps build-engine-library-windows ## 构建内嵌引擎的 Windows Release
	@if [ '$(HOST_OS)' != windows ]; then echo 'Windows Flutter 包必须在 Windows 上构建' >&2; exit 1; fi
	@cd $(APP_DIR) && $(FLUTTER) build windows --release \
		--build-name=$(VERSION) --build-number=$(BUILD_NUMBER) \
		--dart-define=DOWNPEED_API_BASE_URL=$(API_BASE_URL) \
		--dart-define=DOWNPEED_ENGINE_ADDRESS=$(ENGINE_ADDRESS) \
		--dart-define=DOWNPEED_ENGINE_MODE=embedded \
		$(FLUTTER_BUILD_DEFINES)

build-linux: flutter-deps build-engine-library-linux ## 构建内嵌引擎的 Linux Release
	@if [ '$(HOST_OS)' != linux ]; then echo 'Linux Flutter 包必须在 Linux 上构建' >&2; exit 1; fi
	@cd $(APP_DIR) && $(FLUTTER) build linux --release \
		--build-name=$(VERSION) --build-number=$(BUILD_NUMBER) \
		--dart-define=DOWNPEED_API_BASE_URL=$(API_BASE_URL) \
		--dart-define=DOWNPEED_ENGINE_ADDRESS=$(ENGINE_ADDRESS) \
		--dart-define=DOWNPEED_ENGINE_MODE=embedded \
		$(FLUTTER_BUILD_DEFINES)

package: package-$(HOST_OS) ## 打包当前宿主平台发布物
release: package ## package 的别名

package-macos: third-party-notices build-macos ## 生成 macOS Ad-hoc 签名、未公证 DMG
	@rm -rf '$(DIST_DIR)/downpeed-$(VERSION)-macos-$(TARGET_ARCH)'
	@mkdir -p '$(DIST_DIR)/downpeed-$(VERSION)-macos-$(TARGET_ARCH)'
	@ditto '$(MACOS_APP)' '$(DIST_DIR)/downpeed-$(VERSION)-macos-$(TARGET_ARCH)/Downpeed.app'
	@cp '$(THIRD_PARTY_NOTICES)' '$(DIST_DIR)/downpeed-$(VERSION)-macos-$(TARGET_ARCH)/THIRD_PARTY_NOTICES.txt'
	@rm -f '$(DIST_DIR)/downpeed-$(VERSION)-macos-$(TARGET_ARCH).dmg'
	@hdiutil create -quiet -ov -format UDZO -volname 'Downpeed $(VERSION)' \
		-srcfolder '$(DIST_DIR)/downpeed-$(VERSION)-macos-$(TARGET_ARCH)' \
		'$(DIST_DIR)/downpeed-$(VERSION)-macos-$(TARGET_ARCH).dmg'
	@$(MAKE) --no-print-directory release-metadata BUILD_DATE='$(BUILD_DATE)' \
		COMMIT='$(COMMIT)' BUILD_NUMBER='$(BUILD_NUMBER)' RELEASE_CHANNEL='$(RELEASE_CHANNEL)'
	@printf 'Created %s\n' '$(DIST_DIR)/downpeed-$(VERSION)-macos-$(TARGET_ARCH).dmg'

package-windows: third-party-notices build-windows ## 生成 Windows 便携 ZIP
	@rm -rf '$(DIST_DIR)/downpeed-$(VERSION)-windows-$(TARGET_ARCH)'
	@mkdir -p '$(DIST_DIR)/downpeed-$(VERSION)-windows-$(TARGET_ARCH)'
	@cp -R '$(WINDOWS_BUNDLE)/.' '$(DIST_DIR)/downpeed-$(VERSION)-windows-$(TARGET_ARCH)/'
	@cp '$(THIRD_PARTY_NOTICES)' '$(DIST_DIR)/downpeed-$(VERSION)-windows-$(TARGET_ARCH)/THIRD_PARTY_NOTICES.txt'
	@rm -f '$(DIST_DIR)/downpeed-$(VERSION)-windows-$(TARGET_ARCH).zip'
	@powershell.exe -NoProfile -Command \
		"Compress-Archive -Path '$(DIST_DIR)/downpeed-$(VERSION)-windows-$(TARGET_ARCH)/*' -DestinationPath '$(DIST_DIR)/downpeed-$(VERSION)-windows-$(TARGET_ARCH).zip' -Force"
	@$(MAKE) --no-print-directory release-metadata BUILD_DATE='$(BUILD_DATE)' \
		COMMIT='$(COMMIT)' BUILD_NUMBER='$(BUILD_NUMBER)' RELEASE_CHANNEL='$(RELEASE_CHANNEL)'
	@printf 'Created %s\n' '$(DIST_DIR)/downpeed-$(VERSION)-windows-$(TARGET_ARCH).zip'

package-linux: third-party-notices build-linux ## 生成 Linux 便携 tar.gz
	@rm -rf '$(DIST_DIR)/downpeed-$(VERSION)-linux-$(TARGET_ARCH)'
	@mkdir -p '$(DIST_DIR)/downpeed-$(VERSION)-linux-$(TARGET_ARCH)'
	@cp -R '$(LINUX_BUNDLE)/.' '$(DIST_DIR)/downpeed-$(VERSION)-linux-$(TARGET_ARCH)/'
	@cp '$(THIRD_PARTY_NOTICES)' '$(DIST_DIR)/downpeed-$(VERSION)-linux-$(TARGET_ARCH)/THIRD_PARTY_NOTICES.txt'
	@rm -f '$(DIST_DIR)/downpeed-$(VERSION)-linux-$(TARGET_ARCH).tar.gz'
	@tar -C '$(DIST_DIR)' -czf '$(DIST_DIR)/downpeed-$(VERSION)-linux-$(TARGET_ARCH).tar.gz' \
		'downpeed-$(VERSION)-linux-$(TARGET_ARCH)'
	@$(MAKE) --no-print-directory release-metadata BUILD_DATE='$(BUILD_DATE)' \
		COMMIT='$(COMMIT)' BUILD_NUMBER='$(BUILD_NUMBER)' RELEASE_CHANNEL='$(RELEASE_CHANNEL)'
	@printf 'Created %s\n' '$(DIST_DIR)/downpeed-$(VERSION)-linux-$(TARGET_ARCH).tar.gz'

verify-package: verify-release-metadata verify-package-$(HOST_OS) ## 校验当前平台发布包

verify-package-macos:
	@test -f '$(MACOS_APP)/Contents/Frameworks/libdownpeed.dylib'
	@test "$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes:0:CFBundleURLSchemes:0' '$(MACOS_APP)/Contents/Info.plist')" = downpeed
	@codesign --verify --deep --strict --verbose=2 '$(MACOS_APP)'
	@hdiutil verify -quiet '$(PACKAGE_ARTIFACT)'

verify-package-windows:
	@powershell.exe -NoProfile -Command \
		"if (!(Test-Path '$(WINDOWS_BUNDLE)/downpeed.exe') -or !(Test-Path '$(WINDOWS_BUNDLE)/downpeed.dll')) { exit 1 }"

verify-package-linux:
	@test -x '$(LINUX_BUNDLE)/downpeed'
	@test -f '$(LINUX_BUNDLE)/lib/libdownpeed.so'
	@test -f '$(LINUX_BUNDLE)/share/applications/com.xiaoxi.downpeed.desktop'
	@tar -tzf '$(PACKAGE_ARTIFACT)' >/dev/null

smoke-package: package ## 启动归档前的 Release 应用并完成隔离下载冒烟测试
	@$(MAKE) --no-print-directory verify-package
	@cd '$(APP_DIR)' && $(DART) run ../tool/package_smoke.dart \
		--executable '$(PACKAGE_EXECUTABLE)'

clean: ## 删除项目生成的构建和发布目录
	@rm -rf '$(BUILD_DIR)' '$(DIST_DIR)' '$(APP_DIR)/build'
