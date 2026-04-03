.PHONY: all rust flutter build install clean bootstrap release-patch release-minor release-major release-dry build-admin build-all serve build-backend build-docker run-docker stop-docker push-docker

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
	./scripts/release.sh patch

release-minor:
	./scripts/release.sh minor

release-major:
	./scripts/release.sh major

release-dry:
	./scripts/release.sh patch --dry-run

## Build the admin SPA (Flutter web)
build-admin:
	cd web_app && flutter pub get && flutter build web --release

## Build everything including admin SPA and backend
build-all: rust build-admin build-backend build

## Run the catalog server (dev mode)
serve:
	PLAUNCHER_JWT_SECRET=$${PLAUNCHER_JWT_SECRET:-dev-secret} \
	GITHUB_CLIENT_ID=$${GITHUB_CLIENT_ID:-} \
	GITHUB_CLIENT_SECRET=$${GITHUB_CLIENT_SECRET:-} \
	cargo run --manifest-path cli/Cargo.toml -- serve --catalog catalog.example.yaml

## Backend
build-backend:
	cd backend && cargo build --release

## Docker
build-docker:
	docker compose build

run-docker:
	docker compose up -d

stop-docker:
	docker compose down

push-docker:
	docker tag project-launcher-plauncher plauncher/org-server:latest
	docker push plauncher/org-server:latest