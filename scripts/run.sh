#!/usr/bin/env bash
set -euo pipefail

SCHEME="${SCHEME:-Runner}"
CONFIGURATION="${CONFIGURATION:-Debug}"
IOS_DIR="${IOS_DIR:-ios}"
WORKSPACE="${WORKSPACE:-Runner.xcworkspace}"

MODE="wireless"
for arg in "$@"; do
  case "$arg" in
    --wireless) MODE="wireless" ;;
    --usb) MODE="usb" ;;
    -h|--help)
      echo "Usage: $0 [--wireless|--usb] (default: wireless)"
      exit 0
      ;;
  esac
done

die() { echo "❌ $*" >&2; exit 1; }
note() { echo "ℹ️ $*"; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"; }

require_cmd xcrun
require_cmd xcodebuild
require_cmd python3

# ---- MOVE TO ios/ ----
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR/$IOS_DIR" || die "Could not cd to $ROOT_DIR/$IOS_DIR"
[ -d "$WORKSPACE" ] || die "Workspace not found: $PWD/$WORKSPACE"

# ---- DEVICE DISCOVERY via xcdevice (no devicectl dependency) ----
DEVICE_JSON="$(xcrun xcdevice list --timeout 10 2>/dev/null || true)"
if [ -z "$DEVICE_JSON" ] || [ "$DEVICE_JSON" = "[]" ]; then
  die "xcdevice returned no devices. Try: xcrun xcdevice list"
fi

DEVICE_ID="$(echo "$DEVICE_JSON" | python3 -c '
import sys, json
raw = sys.stdin.read().strip()
if not raw or raw == "[]":
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
  if d.get("available") is False:
    continue
  if d.get("error"):
    continue
  udid = d.get("identifier")
  if udid:
    print(udid)
    break
' || true)"

if [ -z "${DEVICE_ID:-}" ]; then
  note "Connected devices (xcdevice):"
  echo "$DEVICE_JSON" | python3 -c '
import sys, json
raw = sys.stdin.read().strip()
if not raw or raw == "[]":
  print("  (none)")
  sys.exit(0)
data = json.loads(raw)
for d in data:
  if not isinstance(d, dict): 
    continue
  if d.get("simulator"):
    continue
  plat = (d.get("platform") or "").lower()
  if "iphoneos" not in plat and "ipados" not in plat:
    continue
  name = d.get("name")
  ident = d.get("identifier")
  avail = d.get("available")
  err = d.get("error")
  print(f"- {name} | {ident} | available={avail} | error={err}")
'
  die "No available iOS device found. Ensure device is unlocked and trusted."
fi

echo "✅ Using device ($MODE): $DEVICE_ID"

# ---- GET BUNDLE ID FROM BUILD SETTINGS ----
note "Resolving bundle id..."
SETTINGS="$(xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -configuration "$CONFIGURATION" -destination "id=$DEVICE_ID" -showBuildSettings)"
BUNDLE_ID="$(printf '%s\n' "$SETTINGS" | awk -F' = ' '/PRODUCT_BUNDLE_IDENTIFIER/ {print $2; exit}')"
[ -n "$BUNDLE_ID" ] || die "Could not determine PRODUCT_BUNDLE_IDENTIFIER."
echo "✅ Bundle ID: $BUNDLE_ID"

# ---- BUILD WITH PROGRESS ----
note "Building..."
if command -v xcbeautify >/dev/null 2>&1; then
  set -o pipefail
  xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -configuration "$CONFIGURATION" -destination "id=$DEVICE_ID" build | xcbeautify
else
  note "Tip: brew install xcbeautify"
  xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -configuration "$CONFIGURATION" -destination "id=$DEVICE_ID" build
fi

# ---- LAUNCH ----
note "Launching..."

if command -v xcrun >/dev/null 2>&1 && xcrun -f devicectl >/dev/null 2>&1; then
  xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID"
  echo "✅ Done"
  exit 0
fi

if command -v ios-deploy >/dev/null 2>&1; then
  # ios-deploy needs the .app path. Ask xcodebuild where it put it.
  APP_PATH="$(printf '%s\n' "$SETTINGS" | awk -F' = ' '/TARGET_BUILD_DIR/ {dir=$2} /WRAPPER_NAME/ {wrap=$2} END{if(dir && wrap) print dir "/" wrap}')"
  [ -n "$APP_PATH" ] || die "Could not determine app path for ios-deploy."
  ios-deploy --id "$DEVICE_ID" --bundle "$APP_PATH" --justlaunch
  echo "✅ Done"
  exit 0
fi

note "Built successfully, but no launcher tool available."
note "If you want launch via CLI without devicectl, install ios-deploy:"
note "  brew install ios-deploy"
echo "✅ Build complete"