APP = Jogen.app
BIN = .build/release/Jogen
# Keep a stable signature so Accessibility permission survives local rebuilds.
# Distribution builds override this with a Developer ID Application identity.
SIGN_IDENTITY ?= Apple Development: Yusuke Shibata (6F8N535B8W)
# Distribution builds enable Hardened Runtime and a secure timestamp.
CODESIGN_FLAGS ?=
RUN_ARGS ?=

.PHONY: all build bundle run release clean

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
	@pkill -x Jogen 2>/dev/null || true
	@if [ -n "$(RUN_ARGS)" ]; then \
		open $(APP) --args $(RUN_ARGS); \
	else \
		open $(APP); \
	fi

release:
	./Scripts/release.sh

clean:
	swift package clean
	rm -rf $(APP) Jogen.dmg
