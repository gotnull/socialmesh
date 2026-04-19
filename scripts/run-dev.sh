#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# run-dev.sh — Interactive launcher for Socialmesh on iOS, Android, or both
#
# Usage:
#   ./scripts/run-dev.sh [OPTIONS]
#
# Options:
#   --ios        Run iOS only (skip prompt)
#   --android    Run Android only (skip prompt)
#   --both       Run both (skip prompt)
#   --forget     Clear saved preference and exit
#   -h | --help  Show this help and exit
#
# The last-used platform selection is saved to ~/.socialmesh_run_prefs
# and pre-selected on the next run.
# ---------------------------------------------------------------------------

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

die()     { echo -e "${RED}x $*${NC}" >&2; exit 1; }
info()    { echo -e "${BLUE}->${NC} $*"; }
success() { echo -e "${GREEN}ok${NC} $*"; }

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_SCRIPT="$SCRIPTS_DIR/run.sh"
ANDROID_SCRIPT="$SCRIPTS_DIR/run-android.sh"
PREFS_FILE="${HOME}/.socialmesh_run_prefs"

# Saved preference key
PREF_KEY="last_platform"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

load_pref() {
  if [[ -f "$PREFS_FILE" ]]; then
    grep "^${PREF_KEY}=" "$PREFS_FILE" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]'
  fi
}

save_pref() {
  local value="$1"
  # Write or update the key in the prefs file.
  if [[ -f "$PREFS_FILE" ]] && grep -q "^${PREF_KEY}=" "$PREFS_FILE" 2>/dev/null; then
    # Replace existing line (works on macOS sed).
    sed -i '' "s/^${PREF_KEY}=.*/${PREF_KEY}=${value}/" "$PREFS_FILE"
  else
    echo "${PREF_KEY}=${value}" >> "$PREFS_FILE"
  fi
}

require_script() {
  local path="$1"
  local name="$2"
  [[ -f "$path" ]] || die "Could not find $name at: $path"
  [[ -x "$path" ]] || chmod +x "$path"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

FORCED_PLATFORM=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ios)      FORCED_PLATFORM="ios";     shift ;;
    --android)  FORCED_PLATFORM="android"; shift ;;
    --both)     FORCED_PLATFORM="both";    shift ;;
    --forget)
      if [[ -f "$PREFS_FILE" ]]; then
        sed -i '' "/^${PREF_KEY}=/d" "$PREFS_FILE" 2>/dev/null || rm -f "$PREFS_FILE"
      fi
      echo -e "${GREEN}ok${NC} Saved platform preference cleared."
      exit 0
      ;;
    -h|--help)
      cat <<'EOF'
Usage:
  ./scripts/run-dev.sh [OPTIONS]

Options:
  --ios        Run iOS only (skip prompt)
  --android    Run Android only (skip prompt)
  --both       Run both iOS and Android (skip prompt)
  --forget     Clear saved platform preference and exit
  -h | --help  Show this help and exit

The last-used selection is saved to ~/.socialmesh_run_prefs and
pre-selected automatically on the next run.
EOF
      exit 0
      ;;
    *)
      die "Unknown option: $1 (see --help)"
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------

echo ""
echo -e "${BOLD}Socialmesh Dev Launcher${NC}"
echo -e "${DIM}────────────────────────────────────${NC}"
echo ""

# ---------------------------------------------------------------------------
# Platform selection
# ---------------------------------------------------------------------------

PLATFORM=""

if [[ -n "$FORCED_PLATFORM" ]]; then
  PLATFORM="$FORCED_PLATFORM"
else
  SAVED="$(load_pref)"

  echo -e "${BOLD}Where do you want to run?${NC}"
  echo ""
  echo -e "  ${BOLD}1)${NC} iOS only"
  [[ "$SAVED" == "ios" ]]     && echo -e "     ${DIM}↑ last used${NC}"
  echo -e "  ${BOLD}2)${NC} Android only"
  [[ "$SAVED" == "android" ]] && echo -e "     ${DIM}↑ last used${NC}"
  echo -e "  ${BOLD}3)${NC} Both"
  [[ "$SAVED" == "both" ]]    && echo -e "     ${DIM}↑ last used${NC}"
  echo ""

  # Determine default choice number from saved pref.
  DEFAULT_CHOICE=""
  case "$SAVED" in
    ios)     DEFAULT_CHOICE="1" ;;
    android) DEFAULT_CHOICE="2" ;;
    both)    DEFAULT_CHOICE="3" ;;
  esac

  if [[ -n "$DEFAULT_CHOICE" ]]; then
    PROMPT="  Enter choice [1-3] (default: ${DEFAULT_CHOICE}): "
  else
    PROMPT="  Enter choice [1-3]: "
  fi

  while true; do
    read -rp "$PROMPT" CHOICE

    # Accept empty input to use default.
    if [[ -z "$CHOICE" && -n "$DEFAULT_CHOICE" ]]; then
      CHOICE="$DEFAULT_CHOICE"
    fi

    case "$CHOICE" in
      1) PLATFORM="ios";     break ;;
      2) PLATFORM="android"; break ;;
      3) PLATFORM="both";    break ;;
      *) echo -e "  ${RED}Invalid choice. Enter 1, 2, or 3.${NC}" ;;
    esac
  done
fi

# Save the selection.
save_pref "$PLATFORM"

echo ""
case "$PLATFORM" in
  ios)     info "Running on ${BOLD}iOS${NC}" ;;
  android) info "Running on ${BOLD}Android${NC}" ;;
  both)    info "Running on ${BOLD}iOS and Android${NC}" ;;
esac
echo ""

# ---------------------------------------------------------------------------
# Execute
# ---------------------------------------------------------------------------

run_ios() {
  require_script "$IOS_SCRIPT" "run.sh"
  bash "$IOS_SCRIPT"
}

run_android() {
  require_script "$ANDROID_SCRIPT" "run-android.sh"
  bash "$ANDROID_SCRIPT"
}

case "$PLATFORM" in
  ios)
    run_ios
    ;;
  android)
    run_android
    ;;
  both)
    # Run iOS first (builds via xcodebuild and exits cleanly), then Android.
    # Android's flutter run is left detached after launch so both apps end
    # up running simultaneously on their respective devices.
    run_ios
    echo ""
    echo -e "${DIM}────────────────────────────────────${NC}"
    echo ""
    run_android
    ;;
esac
