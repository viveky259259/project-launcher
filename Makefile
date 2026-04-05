.PHONY: all rust flutter build install clean bootstrap release-patch release-minor release-major release-dry deploy-checkout deploy-web deploy-netlaunch

# Load secrets from .env or secrets repo (check multiple locations)
-include .env
SECRETS_ENV_1 := $(HOME)/Documents/Projects/secrets/project-launcher/.env
SECRETS_ENV_2 := $(HOME)/.project-launcher-secrets/project-launcher/.env
ifneq ($(wildcard $(SECRETS_ENV_1)),)
  -include $(SECRETS_ENV_1)
else ifneq ($(wildcard $(SECRETS_ENV_2)),)
  -include $(SECRETS_ENV_2)
endif
export GEMINI_API_KEY
DART_DEFINES := --dart-define=GEMINI_API_KEY=$(GEMINI_API_KEY)

# Default target
all: build

# Bootstrap monorepo (install melos + resolve all packages)
bootstrap:
	dart pub global activate melos
	melos bootstrap

# Build Rust library
rust:
	cd rust && cargo build --release

# Get Flutter dependencies
flutter:
	flutter pub get

# Build everything
build: rust flutter
	# Copy dylib to the right location for development
	mkdir -p macos/Frameworks
	cp rust/target/release/libproject_launcher_core.dylib macos/Frameworks/
	flutter build macos --release $(DART_DEFINES)

# Build and install
install: build
	rm -rf "/Applications/Project Launcher.app"
	cp -R "build/macos/Build/Products/Release/Project Launcher.app" /Applications/
	@echo "Installed to /Applications/Project Launcher.app"
	@echo "Copying native library to app bundle..."
	mkdir -p "/Applications/Project Launcher.app/Contents/Frameworks"
	cp rust/target/release/libproject_launcher_core.dylib "/Applications/Project Launcher.app/Contents/Frameworks/"
	@echo "Done!"

# Clean build artifacts
clean:
	cd rust && cargo clean
	flutter clean
	rm -rf macos/Frameworks/libproject_launcher_core.dylib

# Development build (debug)
dev: rust
	mkdir -p macos/Frameworks
	cp rust/target/release/libproject_launcher_core.dylib macos/Frameworks/
	flutter run -d macos $(DART_DEFINES)

# Run tests
test:
	cd rust && cargo test
	flutter test

# Run static analysis on all packages
analyze:
	melos run analyze

# Release targets
release-patch:
	./scripts/release.sh patch

release-minor:
	./scripts/release.sh minor

release-major:
	./scripts/release.sh major

release-dry:
	./scripts/release.sh patch --dry-run

# NetLaunch deployment targets
deploy-checkout:
	./scripts/deploy-netlaunch.sh checkout

deploy-web:
	./scripts/deploy-netlaunch.sh web

deploy-netlaunch:
	@echo "Usage: make deploy-checkout  — Deploy checkout pages"
	@echo "       make deploy-web       — Build & deploy Flutter web"