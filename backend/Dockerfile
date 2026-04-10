# Stage 1: Build Rust backend
FROM rust:1.77-bookworm AS rust-builder
WORKDIR /build
COPY backend/ ./
RUN cargo build --release

# Stage 2: Build Flutter web apps
FROM ghcr.io/cirruslabs/flutter:stable AS flutter-builder
WORKDIR /build
# Copy packages needed by web apps
COPY packages/ packages/
# Build org admin SPA
COPY web_app/ web_app/
RUN cd web_app && flutter pub get && flutter build web --release
# Build super admin SPA
COPY super_admin_web/ super_admin_web/
RUN cd super_admin_web && flutter pub get && flutter build web --release

# Stage 3: Runtime
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates git && rm -rf /var/lib/apt/lists/*
WORKDIR /app

# Copy backend binary
COPY --from=rust-builder /build/target/release/plauncher-backend /app/plauncher-backend

# Copy web SPAs
COPY --from=flutter-builder /build/web_app/build/web /app/static/admin
COPY --from=flutter-builder /build/super_admin_web/build/web /app/static/super-admin

# Default env vars — MONGODB_URI should be provided at runtime via .env or
# docker-compose environment. Falls back to local mongo service name.
ENV PORT=8743
ENV PLAUNCHER_MODE=self-hosted
ENV PLAUNCHER_DB_NAME=plauncher

EXPOSE 8743

CMD ["/app/plauncher-backend"]
