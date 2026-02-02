#!/usr/bin/env bash
set -euo pipefail

SCHEME="${SCHEME:-Runner}"
CONFIGURATION="${CONFIGURATION:-Debug}"
IOS_DIR="${IOS_DIR:-ios}"
WORKSPACE="${WORKSPACE:-Runner.xcworkspace}"

MODE="wireless"
VERBOSE=false
for arg in "$@"; do
  case "$arg" in
    --wireless) MODE="wireless" ;;
    --usb) MODE="usb" ;;
    --verbose|-v) VERBOSE=true ;;
    -h|--help)
      echo "Usage: $0 [--wireless|--usb] [--verbose|-v]"
      echo "  --wireless  Deploy over WiFi (default)"
      echo "  --usb       Deploy over USB cable"
      echo "  --verbose   Show full xcodebuild output"
      exit 0
      ;;
  esac
done

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

die() { echo -e "${RED}x $*${NC}" >&2; exit 1; }
success() { echo -e "${GREEN}ok${NC} $*"; }
info() { echo -e "${BLUE}->${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"; }

require_cmd xcrun
require_cmd xcodebuild
require_cmd python3

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR/$IOS_DIR" || die "Could not cd to $ROOT_DIR/$IOS_DIR"
[ -d "$WORKSPACE" ] || die "Workspace not found: $PWD/$WORKSPACE"

echo ""
echo -e "${BOLD}Socialmesh iOS Build${NC}"
echo -e "   Mode: ${YELLOW}$MODE${NC}"
echo ""

info "Searching for iOS devices..."
DEVICE_JSON="$(xcrun xcdevice list --timeout 10 2>/dev/null || true)"
if [ -z "$DEVICE_JSON" ] || [ "$DEVICE_JSON" = "[]" ]; then
  die "No devices found. Run: xcrun xcdevice list"
fi

DEVICE_INFO="$(echo "$DEVICE_JSON" | python3 -c '
import sys, json
raw = sys.stdin.read().strip()
if not raw:
    sys.exit(0)
data = json.loads(raw)
for d in data:
    if not isinstance(d, dict):
        continue
    plat = (d.get("platform") or "").lower()
    if "iphoneos" not in plat and "ipados" not in plat:
        continue
    if d.get("simulator"):
        continue
    if d.get("available") == False:
        continue
    if d.get("error"):
        continue
    udid = d.get("identifier")
    name = d.get("name", "Unknown")
    if udid:
        print(f"{udid}|{name}")
        break
' 2>/dev/null || true)"

if [ -z "${DEVICE_INFO:-}" ]; then
  die "No available iOS device. Ensure device is unlocked and trusted."
fi

DEVICE_ID="${DEVICE_INFO%%|*}"
DEVICE_NAME="${DEVICE_INFO#*|}"
success "Found: ${BOLD}$DEVICE_NAME${NC}"

info "Resolving bundle identifier..."
SETTINGS="$(xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -configuration "$CONFIGURATION" -destination "id=$DEVICE_ID" -showBuildSettings 2>/dev/null)"
BUNDLE_ID="$(printf '%s\n' "$SETTINGS" | awk -F' = ' '/PRODUCT_BUNDLE_IDENTIFIER/ {print $2; exit}')"
[ -n "$BUNDLE_ID" ] || die "Could not determine PRODUCT_BUNDLE_IDENTIFIER"
success "Bundle: $BUNDLE_ID"

echo ""
info "Building ${BOLD}$SCHEME${NC} (${CONFIGURATION})..."
echo ""

BUILD_LOG="/tmp/socialmesh_build_$$.log"
BUILD_START=$(date +%s)

if [ "$VERBOSE" = true ]; then
  xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -configuration "$CONFIGURATION" \
    -destination "id=$DEVICE_ID" build 2>&1 | tee "$BUILD_LOG"
  BUILD_EXIT=${PIPESTATUS[0]}
else
  xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -configuration "$CONFIGURATION" \
    -destination "id=$DEVICE_ID" build > "$BUILD_LOG" 2>&1 &
  BUILD_PID=$!
  
  SPINNER='/-\|'
  i=0
  LAST_TARGET=""
  
  while kill -0 $BUILD_PID 2>/dev/null; do
    CURRENT_TARGET=$(tail -50 "$BUILD_LOG" 2>/dev/null | grep -oE "in target '[^']+'" | tail -1 | sed "s/in target '//;s/'//" 2>/dev/null || true)
    
    if [ -n "$CURRENT_TARGET" ] && [ "$CURRENT_TARGET" != "$LAST_TARGET" ]; then
      printf "\r\033[K   [%c] %s" "${SPINNER:i%4:1}" "$CURRENT_TARGET"
      LAST_TARGET="$CURRENT_TARGET"
    else
      printf "\r   [%c] Building..." "${SPINNER:i%4:1}"
    fi
    i=$((i + 1))
    sleep 0.2
  done
  
  wait $BUILD_PID
  BUILD_EXIT=$?
  printf "\r\033[K"
fi

BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))

if [ $BUILD_EXIT -ne 0 ]; then
  echo ""
  echo -e "${RED}Build failed!${NC} Last 30 lines:"
  echo ""
  tail -30 "$BUILD_LOG"
  echo ""
  die "Build failed after ${BUILD_TIME}s"
fi

success "Build completed in ${BUILD_TIME}s"

WARN_COUNT=$(grep -c "warning:" "$BUILD_LOG" 2>/dev/null || echo "0")
if [ "$WARN_COUNT" -gt 0 ]; then
  warn "$WARN_COUNT warnings (use --verbose to see)"
fi

echo ""
info "Launching on ${BOLD}$DEVICE_NAME${NC}..."

if xcrun -f devicectl >/dev/null 2>&1; then
  xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  success "App launched!"
elif command -v ios-deploy >/dev/null 2>&1; then
  APP_PATH="$(printf '%s\n' "$SETTINGS" | awk -F' = ' '/TARGET_BUILD_DIR/ {dir=$2} /WRAPPER_NAME/ {wrap=$2} END{if(dir && wrap) print dir "/" wrap}')"
  if [ -n "$APP_PATH" ]; then
    ios-deploy --id "$DEVICE_ID" --bundle "$APP_PATH" --justlaunch >/dev/null 2>&1 || true
    success "App launched!"
  else
    warn "Could not determine app path"
  fi
else
  warn "No launcher available (install: brew install ios-deploy)"
  info "Build complete - launch manually"
fi

echo ""
echo -e "${GREEN}${BOLD}Done!${NC}"
echo ""

rm -f "$BUILD_LOG" 2>/dev/null || true
