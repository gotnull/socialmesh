#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Socialmesh Developer Bootstrap Script
# Sets up a development environment for contributors.
#
# Usage: ./tool/dev_bootstrap.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  Socialmesh Developer Bootstrap${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

check_pass() {
    echo -e "  ${GREEN}✓${NC} $1"
}

check_warn() {
    echo -e "  ${YELLOW}!${NC} $1"
}

check_fail() {
    echo -e "  ${RED}✗${NC} $1"
}

section() {
    echo ""
    echo -e "${CYAN}▸ $1${NC}"
}

# Change to script directory's parent (project root)
cd "$(dirname "$0")/.."

print_header

# ─────────────────────────────────────────────────────────────────────────────
# Flutter Check
# ─────────────────────────────────────────────────────────────────────────────
section "Checking Flutter installation"

if command -v flutter &> /dev/null; then
    FLUTTER_VERSION=$(flutter --version --machine 2>/dev/null | grep -o '"frameworkVersion":"[^"]*"' | cut -d'"' -f4 || flutter --version | head -1)
    check_pass "Flutter installed: $FLUTTER_VERSION"
else
    check_fail "Flutter not found. Install from: https://flutter.dev/docs/get-started/install"
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# Platform Toolchains
# ─────────────────────────────────────────────────────────────────────────────
section "Checking platform toolchains"

# macOS / iOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v xcodebuild &> /dev/null; then
        XCODE_VERSION=$(xcodebuild -version 2>/dev/null | head -1 || echo "unknown")
        check_pass "Xcode: $XCODE_VERSION"
    else
        check_warn "Xcode not installed (required for iOS builds)"
    fi

    if command -v pod &> /dev/null; then
        POD_VERSION=$(pod --version 2>/dev/null || echo "unknown")
        check_pass "CocoaPods: $POD_VERSION"
    else
        check_warn "CocoaPods not installed (run: sudo gem install cocoapods)"
    fi
fi

# Android / Java
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | head -1 | cut -d'"' -f2 || echo "unknown")
    check_pass "Java: $JAVA_VERSION"
else
    check_warn "Java not installed (required for Android builds)"
fi

if [ -n "${ANDROID_HOME:-}" ] || [ -n "${ANDROID_SDK_ROOT:-}" ]; then
    SDK_PATH="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
    check_pass "Android SDK: $SDK_PATH"
else
    check_warn "Android SDK not configured (ANDROID_HOME not set)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Backend Config Detection
# ─────────────────────────────────────────────────────────────────────────────
section "Checking backend configuration"

BACKEND_CONFIGURED="NO"

# Check for Firebase config files
if [ -f "android/app/google-services.json" ]; then
    check_pass "Android Firebase config: google-services.json"
    BACKEND_CONFIGURED="YES"
else
    check_warn "Android Firebase config: not found"
fi

if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
    check_pass "iOS Firebase config: GoogleService-Info.plist"
    BACKEND_CONFIGURED="YES"
else
    check_warn "iOS Firebase config: not found"
fi

# Check for .env file
if [ -f ".env" ]; then
    check_pass "Environment file: .env"
else
    check_warn "Environment file: not found (will use defaults)"
    if [ -f ".env.example" ]; then
        echo -e "       Creating .env from .env.example..."
        cp .env.example .env
        check_pass "Created .env from template"
    fi
fi

echo ""
echo -e "  Backend config detected: ${CYAN}${BACKEND_CONFIGURED}${NC}"

if [ "$BACKEND_CONFIGURED" = "NO" ]; then
    echo ""
    echo -e "  ${YELLOW}Note:${NC} Backend config is optional. Use demo mode to run without it:"
    echo -e "        flutter run --dart-define=SOCIALMESH_DEMO=1"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Dependencies
# ─────────────────────────────────────────────────────────────────────────────
section "Installing dependencies"

echo "  Running flutter pub get..."
flutter pub get

check_pass "Dependencies installed"

# ─────────────────────────────────────────────────────────────────────────────
# iOS Pod Install (macOS only)
# ─────────────────────────────────────────────────────────────────────────────
if [[ "$OSTYPE" == "darwin"* ]] && command -v pod &> /dev/null; then
    section "Installing iOS dependencies"
    echo "  Running pod install..."
    (cd ios && pod install --silent 2>/dev/null) || check_warn "Pod install had warnings (may still work)"
    check_pass "iOS pods installed"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Bootstrap complete!${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Next steps:"
echo ""

if [ "$BACKEND_CONFIGURED" = "YES" ]; then
    echo -e "    ${CYAN}flutter run${NC}"
    echo "      Run with full backend connectivity"
    echo ""
fi

echo -e "    ${CYAN}flutter run --dart-define=SOCIALMESH_DEMO=1${NC}"
echo "      Run in demo mode (no backend required)"
echo ""
echo "  Connect a device or start an emulator, then run one of the above."
echo ""
