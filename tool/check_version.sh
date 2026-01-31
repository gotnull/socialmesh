#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Verifies version consistency between pubspec.yaml and CHANGELOG.md
#
# Usage: ./tool/check_version.sh

set -euo pipefail

cd "$(dirname "$0")/.."

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Extract version from pubspec.yaml (without build number)
PUBSPEC_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f1)

if [ -z "$PUBSPEC_VERSION" ]; then
    echo -e "${RED}Error: Could not extract version from pubspec.yaml${NC}"
    exit 1
fi

# Extract latest version from CHANGELOG.md
if [ ! -f "CHANGELOG.md" ]; then
    echo -e "${RED}Error: CHANGELOG.md not found${NC}"
    exit 1
fi

CHANGELOG_VERSION=$(grep -m1 '^\## \[' CHANGELOG.md | sed 's/## \[//' | cut -d']' -f1)

if [ -z "$CHANGELOG_VERSION" ]; then
    echo -e "${RED}Error: Could not extract version from CHANGELOG.md${NC}"
    exit 1
fi

echo "pubspec.yaml version: $PUBSPEC_VERSION"
echo "CHANGELOG.md version: $CHANGELOG_VERSION"

if [ "$PUBSPEC_VERSION" != "$CHANGELOG_VERSION" ]; then
    echo ""
    echo -e "${RED}Version mismatch!${NC}"
    echo "  pubspec.yaml: $PUBSPEC_VERSION"
    echo "  CHANGELOG.md: $CHANGELOG_VERSION"
    echo ""
    echo "Update CHANGELOG.md to include an entry for version $PUBSPEC_VERSION"
    exit 1
fi

echo ""
echo -e "${GREEN}Versions match: $PUBSPEC_VERSION${NC}"
exit 0
