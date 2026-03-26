.PHONY: all rust flutter build install clean bootstrap release-patch release-minor release-major release-dry

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
	flutter build macos --release

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
	flutter run -d macos

# Run tests
test:
	cd rust && cargo test
	flutter test

# Run static analysis on all packages
analyze:
	melos run analyze

# Release targets
release-patch:
	./release.sh patch

release-minor:
	./release.sh minor

release-major:
	./release.sh major

release-dry:
	./release.sh patch --dry-run
