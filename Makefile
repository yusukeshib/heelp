APP = Jogen.app
BIN = .build/release/Jogen
# Keep a stable signature so Accessibility permission survives local rebuilds.
SIGN_IDENTITY ?= Apple Development: Yusuke Shibata (6F8N535B8W)
CODESIGN_FLAGS ?=

.PHONY: all build bundle run clean

all: bundle

build:
	swift build -c release

bundle: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp Info.plist $(APP)/Contents/
	cp $(BIN) $(APP)/Contents/MacOS/
	codesign --force $(CODESIGN_FLAGS) --sign "$(SIGN_IDENTITY)" $(APP)

run: bundle
	open $(APP)

clean:
	swift package clean
	rm -rf $(APP)
