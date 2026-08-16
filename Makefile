APP = ppp.app
BIN = .build/release/ppp
# Keep a stable signature so Accessibility permission survives local rebuilds.
# Distribution builds override this with a Developer ID Application identity.
SIGN_IDENTITY ?= Apple Development: Yusuke Shibata (6F8N535B8W)
BUNDLE_IDENTIFIER ?= dev.yusukeshib.ppp.dev
BUNDLE_NAME ?= ppp Dev
# Distribution builds enable Hardened Runtime and a secure timestamp.
CODESIGN_FLAGS ?=
RUN_ARGS ?=

.PHONY: all build bundle run release clean

all: bundle

build:
	swift build -c release

bundle: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp Info.plist $(APP)/Contents/
	/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $(BUNDLE_IDENTIFIER)" $(APP)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleName $(BUNDLE_NAME)" $(APP)/Contents/Info.plist
	cp $(BIN) $(APP)/Contents/MacOS/
	cp Assets/ppp.icns $(APP)/Contents/Resources/
	cp -R Resources/*.lproj $(APP)/Contents/Resources/
	codesign --force $(CODESIGN_FLAGS) --sign "$(SIGN_IDENTITY)" $(APP)

run: bundle
	@pkill -x ppp 2>/dev/null || true
	@if [ -n "$(RUN_ARGS)" ]; then \
		open $(APP) --args $(RUN_ARGS); \
	else \
		open $(APP); \
	fi

release:
	./Scripts/release.sh

clean:
	swift package clean
	rm -rf $(APP) ppp.dmg
