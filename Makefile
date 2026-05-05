PYTHON_VERSION  ?= 3.13
BEEWARE_BUILD   ?= b13
ARCHIVE          = Python-$(PYTHON_VERSION)-macOS-support.$(BEEWARE_BUILD).tar.gz
DOWNLOAD_URL     = https://github.com/beeware/Python-Apple-support/releases/download/$(PYTHON_VERSION)-$(BEEWARE_BUILD)/$(ARCHIVE)

# Identity passed to `codesign --sign`. Use '-' for ad-hoc (local dev/testing).
# For App Store distribution set to your certificate CN or SHA-1 hash, e.g.:
#   make sign-python SIGN_IDENTITY="Apple Development: Your Name (TEAMID)"
SIGN_IDENTITY   ?= -

ARTIFACTS_DIR    = Artifacts
XCFRAMEWORK      = $(ARTIFACTS_DIR)/Python.xcframework
FRAMEWORK        = $(XCFRAMEWORK)/macos-arm64_x86_64/Python.framework
FRAMEWORK_HOME   = $(FRAMEWORK)/Versions/$(PYTHON_VERSION)
FRAMEWORK_PYLIB  = $(FRAMEWORK_HOME)/lib/python$(PYTHON_VERSION)
SITE_PACKAGES    = $(FRAMEWORK_PYLIB)/site-packages

.PHONY: bootstrap download-python extract xcframework install-cfabric sign-python clean help

## Full one-time setup: download → extract → install-cfabric → sign
bootstrap: download-python extract install-cfabric sign-python
	@echo ""
	@echo "Bootstrap complete. Run 'swift build' to verify."

## Download the BeeWare Python-Apple-support archive
download-python:
	@mkdir -p $(ARTIFACTS_DIR)
	@if [ ! -f "$(ARTIFACTS_DIR)/$(ARCHIVE)" ]; then \
		echo "Downloading $(ARCHIVE)..."; \
		curl -fL --progress-bar -o "$(ARTIFACTS_DIR)/$(ARCHIVE)" "$(DOWNLOAD_URL)"; \
	else \
		echo "$(ARCHIVE) already present, skipping download."; \
	fi

## Extract Python.xcframework from the archive (stdlib lives inside it)
extract: download-python
	@if [ ! -d "$(XCFRAMEWORK)" ]; then \
		echo "Extracting $(ARCHIVE)..."; \
		tar -xzf "$(ARTIFACTS_DIR)/$(ARCHIVE)" -C "$(ARTIFACTS_DIR)"; \
		echo "Extraction complete."; \
	else \
		echo "$(XCFRAMEWORK) already extracted, skipping."; \
	fi

## Alias matching CLAUDE.md nomenclature
xcframework: extract

## Install cfabric into the embedded Python's site-packages.
## Requires python$(PYTHON_VERSION) on PATH (e.g. from Homebrew).
install-cfabric: extract
	@mkdir -p "$(SITE_PACKAGES)"
	@echo "Installing cfabric into embedded Python site-packages..."
	@python$(PYTHON_VERSION) -m pip install --target "$(SITE_PACKAGES)" context-fabric
	@echo "cfabric installed."

## Codesign .so libraries and re-sign the framework.
## Defaults to ad-hoc signing ('-') for local dev.
## For App Store / notarization set SIGN_IDENTITY to your certificate CN or hash:
##   make sign-python SIGN_IDENTITY="Apple Development: Your Name (TEAMID)"
sign-python:
	@echo "Signing .so libraries (identity: $(SIGN_IDENTITY))..."
	@find "$(FRAMEWORK_PYLIB)/lib-dynload" -name "*.so" -exec \
		/usr/bin/codesign --force --sign "$(SIGN_IDENTITY)" {} \;
	@echo "Re-signing Python.framework..."
	@/usr/bin/codesign --force --deep --sign "$(SIGN_IDENTITY)" "$(FRAMEWORK)"
	@echo "Signing complete."

## Remove all downloaded artifacts
clean:
	@rm -rf $(ARTIFACTS_DIR)
	@echo "Cleaned."

help:
	@echo "Usage: make <target> [VARIABLE=value]"
	@echo ""
	@echo "Targets:"
	@echo "  bootstrap        Full one-time setup (download → extract → install-cfabric → sign)"
	@echo "  download-python  Download BeeWare Python-Apple-support archive"
	@echo "  extract          Unpack Python.xcframework (stdlib is inside)"
	@echo "  xcframework      Alias for extract"
	@echo "  install-cfabric  Install cfabric into embedded Python site-packages"
	@echo "  sign-python      Re-sign .so libs and framework  [SIGN_IDENTITY='-' by default]"
	@echo "  clean            Delete all artifacts"
	@echo ""
	@echo "Variables (override on command line):"
	@echo "  PYTHON_VERSION   $(PYTHON_VERSION)   (Python version to embed)"
	@echo "  BEEWARE_BUILD    $(BEEWARE_BUILD)    (BeeWare build suffix)"
	@echo "  SIGN_IDENTITY    $(SIGN_IDENTITY)  (certificate CN/hash; '-' = ad-hoc)"
