APP_NAME   = Monggle
BUNDLE_ID  = com.rkskekfk.monggle
MIN_MACOS  = 14.0
BUILD_DIR  = .build
APP_BUNDLE = $(APP_NAME).app
CONTENTS   = $(APP_BUNDLE)/Contents
MACOS_DIR  = $(CONTENTS)/MacOS
RES_DIR    = $(CONTENTS)/Resources
SRC        = $(wildcard Sources/*.swift)
SWIFTC     = xcrun swiftc

.PHONY: all build app run install clean

all: run

build:
	@mkdir -p $(BUILD_DIR)
	$(SWIFTC) \
	  -swift-version 5 \
	  -O \
	  -parse-as-library \
	  -target arm64-apple-macos$(MIN_MACOS) \
	  -o $(BUILD_DIR)/$(APP_NAME) \
	  $(SRC)

app: build
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(MACOS_DIR) $(RES_DIR)
	@cp $(BUILD_DIR)/$(APP_NAME) $(MACOS_DIR)/$(APP_NAME)
	@cp Info.plist $(CONTENTS)/Info.plist
	@printf 'APPL????' > $(CONTENTS)/PkgInfo
	@codesign --force --deep --sign - --identifier $(BUNDLE_ID) $(APP_BUNDLE) 2>/dev/null
	@echo "✅ $(APP_BUNDLE) 빌드 완료"

run: app
	@pkill -x $(APP_NAME) 2>/dev/null || true
	@open $(APP_BUNDLE)
	@echo "🗓️  메뉴바 오른쪽 위를 확인해봐!"

install: app
	@pkill -x $(APP_NAME) 2>/dev/null || true
	@rm -rf /Applications/$(APP_BUNDLE)
	@cp -R $(APP_BUNDLE) /Applications/
	@open /Applications/$(APP_BUNDLE)
	@echo "✅ /Applications 에 설치 완료 — 이제 로그인 시 자동 시작도 켤 수 있어"

clean:
	@rm -rf $(BUILD_DIR) $(APP_BUNDLE)
