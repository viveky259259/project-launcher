#!/bin/bash
set -e

# ═══════════════════════════════════════════════════════════════
#  Project Launcher — NetLaunch Deployment
#
#  Usage:
#    ./deploy-netlaunch.sh checkout             # Deploy checkout pages
#    ./deploy-netlaunch.sh web                  # Build & deploy Flutter web
#    ./deploy-netlaunch.sh <dir>                # Deploy any directory
#    ./deploy-netlaunch.sh checkout --dry-run   # Preview without deploying
#
#  Environment:
#    NETLAUNCH_KEY   — API key (required in CI, optional locally)
#    NETLAUNCH_SITE  — Site name override (default: per-target)
# ═══════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET=""
DRY_RUN=false
SITE_NAME="${NETLAUNCH_SITE:-}"
STEP=0
TOTAL_STEPS=5  # adjusted dynamically below

# ─── Progress helpers ───
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
DIM='\033[2m'
RESET='\033[0m'

step() {
  STEP=$((STEP + 1))
  echo ""
  echo -e "${CYAN}[$STEP/$TOTAL_STEPS]${RESET} ${BOLD}$1${RESET}"
}

progress() {
  echo -e "     ${DIM}→${RESET} $1"
}

success() {
  echo -e "     ${GREEN}✓${RESET} $1"
}

warn() {
  echo -e "     ${YELLOW}!${RESET} $1"
}

fail() {
  echo -e "     ${RED}✗${RESET} $1"
  exit 1
}

# ─── Parse arguments ───
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --site) SITE_NAME="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: ./deploy-netlaunch.sh <target> [--site <name>] [--dry-run]"
      echo ""
      echo "Targets:"
      echo "  checkout    Deploy checkout pages (checkout/)"
      echo "  web         Build Flutter web & deploy (build/web/)"
      echo "  <dir>       Deploy any directory containing index.html"
      echo ""
      echo "Options:"
      echo "  --site      Override site name (default: project-launcher-<target>)"
      echo "  --dry-run   Build and zip but skip the actual deploy"
      echo ""
      echo "Environment:"
      echo "  NETLAUNCH_KEY   API key (required in CI, auto-generated locally if logged in)"
      echo "  NETLAUNCH_SITE  Site name override (same as --site flag)"
      exit 0
      ;;
    *) TARGET="$1"; shift ;;
  esac
done

if [ -z "$TARGET" ]; then
  echo "ERROR: Target required. Usage: ./deploy-netlaunch.sh <target>"
  echo "  Run with --help for details."
  exit 1
fi

# ─── Resolve target directory and default site name ───
case "$TARGET" in
  checkout)
    DEPLOY_DIR="$PROJECT_ROOT/checkout"
    DEFAULT_SITE="project-launcher-checkout"
    ;;
  web)
    DEPLOY_DIR="$PROJECT_ROOT/build/web"
    DEFAULT_SITE="project-launcher"
    ;;
  *)
    DEPLOY_DIR="$TARGET"
    if [[ ! "$DEPLOY_DIR" = /* ]]; then
      DEPLOY_DIR="$PROJECT_ROOT/$DEPLOY_DIR"
    fi
    DEFAULT_SITE="project-launcher-$(basename "$DEPLOY_DIR")"
    ;;
esac

SITE_NAME="${SITE_NAME:-$DEFAULT_SITE}"

# Adjust total steps: web target adds a build step, dry-run skips deploy
if [ "$TARGET" = "web" ]; then
  TOTAL_STEPS=6
fi
if [ "$DRY_RUN" = true ]; then
  TOTAL_STEPS=$((TOTAL_STEPS - 1))
fi

echo ""
echo -e "${BOLD}══════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  NetLaunch Deploy${RESET}"
echo -e "${BOLD}══════════════════════════════════════════════════${RESET}"
echo -e "  Target:    ${CYAN}$TARGET${RESET}"
echo -e "  Directory: ${DIM}$DEPLOY_DIR${RESET}"
echo -e "  Site:      ${CYAN}$SITE_NAME${RESET}.web.app"
if [ "$DRY_RUN" = true ]; then
  echo -e "  Mode:      ${YELLOW}dry run${RESET}"
fi
echo -e "${BOLD}══════════════════════════════════════════════════${RESET}"

# ─── Step: Check prerequisites ───
step "Checking prerequisites"

# Check Node.js
if command -v node &>/dev/null; then
  NODE_VERSION=$(node --version)
  success "Node.js $NODE_VERSION"
else
  fail "Node.js is required but not installed. Install from https://nodejs.org"
fi

# Check npm
if command -v npm &>/dev/null; then
  NPM_VERSION=$(npm --version)
  success "npm $NPM_VERSION"
else
  fail "npm is required but not installed."
fi

# Check netlaunch CLI — offer one-click install if missing
if command -v netlaunch &>/dev/null; then
  NL_VERSION=$(netlaunch --version 2>/dev/null || echo "installed")
  success "netlaunch CLI ($NL_VERSION)"
  NETLAUNCH_CMD="netlaunch"
else
  warn "netlaunch CLI not found"
  echo ""
  echo -e "     ${BOLD}NetLaunch CLI is required to deploy.${RESET}"
  echo -e "     Install it now? This runs: ${DIM}npm install -g netlaunch${RESET}"
  echo ""
  printf "     Install netlaunch globally? [Y/n] "

  # In non-interactive (CI) environments, fall back to npx
  if [ ! -t 0 ]; then
    echo "(non-interactive — using npx)"
    NETLAUNCH_CMD="npx --yes netlaunch"
    warn "Using npx (one-time download, not persisted)"
  else
    read -r REPLY
    REPLY="${REPLY:-Y}"
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
      progress "Installing netlaunch globally..."
      npm install -g netlaunch
      if command -v netlaunch &>/dev/null; then
        success "netlaunch installed successfully"
        NETLAUNCH_CMD="netlaunch"

        # Check if logged in
        if ! netlaunch whoami &>/dev/null 2>&1; then
          echo ""
          warn "You're not logged in to NetLaunch yet."
          echo -e "     Run ${BOLD}netlaunch login${RESET} to authenticate (opens browser)."
          printf "     Log in now? [Y/n] "
          read -r LOGIN_REPLY
          LOGIN_REPLY="${LOGIN_REPLY:-Y}"
          if [[ "$LOGIN_REPLY" =~ ^[Yy]$ ]]; then
            progress "Opening browser for Google authentication..."
            netlaunch login
            success "Logged in to NetLaunch"
          else
            if [ -z "$NETLAUNCH_KEY" ]; then
              warn "Continuing without login — NETLAUNCH_KEY env var required"
            fi
          fi
        fi
      else
        fail "Installation failed. Try manually: npm install -g netlaunch"
      fi
    else
      progress "Skipping install — falling back to npx (downloads on each run)"
      NETLAUNCH_CMD="npx --yes netlaunch"
      warn "Using npx as fallback"
    fi
  fi
fi

# Check zip
if command -v zip &>/dev/null; then
  success "zip utility available"
else
  fail "zip is required but not installed."
fi

# ─── Step: Build (web target only) ───
if [ "$TARGET" = "web" ]; then
  step "Building Flutter web"
  progress "Running flutter build web --release..."
  cd "$PROJECT_ROOT"
  flutter build web --release 2>&1 | while IFS= read -r line; do
    echo -e "     ${DIM}$line${RESET}"
  done
  success "Flutter web build complete"
fi

# ─── Step: Validate deploy directory ───
step "Validating deploy directory"

if [ ! -d "$DEPLOY_DIR" ]; then
  fail "Directory not found: $DEPLOY_DIR"
fi
success "Directory exists: $DEPLOY_DIR"

if [ ! -f "$DEPLOY_DIR/index.html" ]; then
  fail "No index.html found in $DEPLOY_DIR"
fi
success "index.html found"

FILE_COUNT=$(find "$DEPLOY_DIR" -type f | wc -l | tr -d ' ')
DIR_SIZE=$(du -sh "$DEPLOY_DIR" | cut -f1)
success "$FILE_COUNT files, $DIR_SIZE total"

# ─── Step: Create ZIP archive ───
step "Creating ZIP archive"

ZIP_FILE="$PROJECT_ROOT/build/netlaunch-deploy.zip"
mkdir -p "$PROJECT_ROOT/build"
rm -f "$ZIP_FILE"

progress "Compressing $FILE_COUNT files..."
cd "$DEPLOY_DIR"
zip -r "$ZIP_FILE" . -x '*.DS_Store' -x '__MACOSX/*' > /dev/null

ZIP_SIZE=$(du -h "$ZIP_FILE" | cut -f1)
success "Archive created ($ZIP_SIZE)"
progress "$ZIP_FILE"

# ─── Dry run exit ───
if [ "$DRY_RUN" = true ]; then
  step "Dry run complete"
  success "Would deploy to https://$SITE_NAME.web.app"
  progress "Archive: $ZIP_FILE"
  rm -f "$ZIP_FILE"
  echo ""
  echo -e "${BOLD}══════════════════════════════════════════════════${RESET}"
  echo -e "  ${YELLOW}Dry run — nothing was deployed${RESET}"
  echo -e "${BOLD}══════════════════════════════════════════════════${RESET}"
  echo ""
  exit 0
fi

# ─── Step: Deploy ───
step "Deploying to NetLaunch"

DEPLOY_ARGS="deploy --site $SITE_NAME --file $ZIP_FILE"

if [ -n "$NETLAUNCH_KEY" ]; then
  progress "Using API key from NETLAUNCH_KEY"
  DEPLOY_ARGS="$DEPLOY_ARGS --key $NETLAUNCH_KEY"
else
  progress "Using login session credentials"
fi

progress "Uploading to $SITE_NAME.web.app..."
$NETLAUNCH_CMD $DEPLOY_ARGS 2>&1 | while IFS= read -r line; do
  echo -e "     ${DIM}$line${RESET}"
done
success "Upload complete"

# ─── Cleanup ───
rm -f "$ZIP_FILE"
progress "Cleaned up temporary archive"

echo ""
echo -e "${BOLD}══════════════════════════════════════════════════${RESET}"
echo -e "  ${GREEN}✓ Deployed successfully!${RESET}"
echo -e "  ${BOLD}https://$SITE_NAME.web.app${RESET}"
echo -e "${BOLD}══════════════════════════════════════════════════${RESET}"
echo ""
