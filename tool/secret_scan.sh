#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Scans the working tree for accidentally committed secrets.
# Run this before committing or as part of CI.
#
# Usage: ./tool/secret_scan.sh

set -euo pipefail

cd "$(dirname "$0")/.."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Directories to exclude from scanning
EXCLUDE_DIRS=(
    "build"
    ".dart_tool"
    "ios/Pods"
    "macos/Pods"
    "android/.gradle"
    "android/build"
    ".pub-cache"
    "lib/generated"
    "node_modules"
    ".git"
    ".venv"
    "functions/lib"
)

# Build grep exclude arguments
EXCLUDE_ARGS=""
for dir in "${EXCLUDE_DIRS[@]}"; do
    EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude-dir=$dir"
done

# Also exclude binary and generated files
EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude=*.pb.dart"
EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude=*.pbenum.dart"
EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude=*.pbserver.dart"
EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude=*.pbjson.dart"
EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude=*.g.dart"
EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude=*.freezed.dart"
EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude=Podfile.lock"
EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude=pubspec.lock"
# Firebase client config (API keys are safe - restricted by security rules)
EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude=firebase_options.dart"
EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude=google-services.json"
EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude=GoogleService-Info.plist"

FOUND_SECRETS=0

scan_pattern() {
    local pattern="$1"
    local description="$2"
    
    # shellcheck disable=SC2086
    if grep -rn $EXCLUDE_ARGS -E "$pattern" . 2>/dev/null | grep -v "secret_scan.sh" | grep -v ".env.example" | grep -v ".env.ci"; then
        echo -e "${YELLOW}  Pattern: $description${NC}"
        echo ""
        FOUND_SECRETS=1
    fi
}

echo ""
echo "Scanning for secrets in working tree..."
echo ""

# Private keys
scan_pattern "BEGIN PRIVATE KEY|BEGIN RSA PRIVATE KEY|BEGIN EC PRIVATE KEY|BEGIN DSA PRIVATE KEY" "Private key header"
scan_pattern "PRIVATE KEY-----" "Private key footer"
scan_pattern "BEGIN CERTIFICATE-----" "Certificate"

# API keys and tokens
scan_pattern "AIza[0-9A-Za-z_-]{35}" "Google API key"
scan_pattern "xox[bpras]-[0-9A-Za-z-]+" "Slack token"
scan_pattern "sk_live_[0-9a-zA-Z]{24,}" "Stripe live secret key"
scan_pattern "rk_live_[0-9a-zA-Z]{24,}" "Stripe live restricted key"
scan_pattern "sk_test_[0-9a-zA-Z]{24,}" "Stripe test key (warning)"

# Service accounts
scan_pattern '"type":\s*"service_account"' "GCP service account JSON"
scan_pattern '"client_email":\s*"[^"]+@[^"]+\.iam\.gserviceaccount\.com"' "Service account email"

# Common sensitive environment variable patterns in code (not in .env files)
# Only flag if they appear to have actual values assigned
scan_pattern '(API_KEY|SECRET_KEY|PRIVATE_KEY|ACCESS_TOKEN|AUTH_TOKEN)\s*[=:]\s*["\x27][A-Za-z0-9+/=_-]{20,}["\x27]' "Hardcoded secret value"

# AWS keys
scan_pattern "AKIA[0-9A-Z]{16}" "AWS access key"

# GitHub tokens
scan_pattern "ghp_[0-9a-zA-Z]{36}" "GitHub personal access token"
scan_pattern "gho_[0-9a-zA-Z]{36}" "GitHub OAuth token"
scan_pattern "ghu_[0-9a-zA-Z]{36}" "GitHub user-to-server token"

if [ "$FOUND_SECRETS" -eq 1 ]; then
    echo ""
    echo -e "${RED}Potential secrets detected!${NC}"
    echo ""
    echo "Review the matches above. If they are false positives:"
    echo "  - Add exclusions to tool/secret_scan.sh"
    echo "  - Or use .env files (which are gitignored)"
    echo ""
    exit 1
fi

echo -e "${GREEN}No secrets detected.${NC}"
exit 0
