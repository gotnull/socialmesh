#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
#
# Detect and purge a wrong-platform `objective_c.framework` from the
# Flutter native-assets build cache before the build proceeds.
#
# WHY THIS EXISTS
# ===============
# `package:objective_c` ships its native FFI library through Flutter's
# native-assets pipeline. The pipeline writes its build outputs to
# `${PROJECT_DIR}/../build/native_assets/ios/objective_c.framework/`.
# Xcode's "[CP] Embed Pods Frameworks" phase copies that framework
# into `Runner.app/Frameworks/` for the current build target.
#
# If a *previous* build wrote the framework for a different target
# (e.g. an iOS-simulator build via xcodebuildmcp followed by an
# iOS-device build via Xcode), the bundle ends up shipping a sim-arch
# dylib on a device build. iOS rejects the dlopen with
# "incompatible platform (have 'iOS-simulator')" and any code path
# that touches Keychain / native FFI throws ArgumentError.
#
# Repro footprint:
#  - SIP DM Accept/Decline tap throws → "This conversation has ended"
#  - logs.txt: `Couldn't resolve native function 'DOBJC_initializeApi'`
#
# WHAT THIS DOES
# ==============
# - Reads the LC_BUILD_VERSION platform tag of the cached
#   `objective_c` Mach-O.
# - If it does not match the current build's PLATFORM_NAME, deletes
#   the framework directory.
# - The downstream Flutter "Run Build Phase" then regenerates it for
#   the correct target.
# - On a clean / matching build, the script exits in milliseconds.
#
# This phase should run BEFORE "Run Build Phase" / "[CP] Embed Pods
# Frameworks" so the regeneration happens within the same Xcode
# invocation. Adding it post-hoc to the Runner target is handled by
# the Podfile `post_install` hook.

set -e

PROJECT_ROOT="${PROJECT_DIR}/.."
FRAMEWORK_DIR="${PROJECT_ROOT}/build/native_assets/ios/objective_c.framework"
FRAMEWORK_BIN="${FRAMEWORK_DIR}/objective_c"

# No cached framework yet? Nothing to check; the build will populate.
if [ ! -f "${FRAMEWORK_BIN}" ]; then
  echo "[Socialmesh] native-assets cache: no objective_c framework cached yet, skipping check"
  exit 0
fi

# Determine expected platform tag from the current Xcode target.
# `vtool -show-build` outputs "platform IOS" for device, "platform
# IOSSIMULATOR" for simulator. We do not handle Mac Catalyst here —
# this build runs against iOS only.
case "${PLATFORM_NAME}" in
  iphoneos)
    EXPECTED_PLATFORM="IOS"
    ;;
  iphonesimulator)
    EXPECTED_PLATFORM="IOSSIMULATOR"
    ;;
  *)
    echo "[Socialmesh] native-assets cache: unsupported PLATFORM_NAME=${PLATFORM_NAME}, skipping check"
    exit 0
    ;;
esac

CACHED_PLATFORM=$(vtool -show-build "${FRAMEWORK_BIN}" 2>/dev/null | awk '/platform/ {print $2; exit}')

if [ -z "${CACHED_PLATFORM}" ]; then
  echo "[Socialmesh] native-assets cache: vtool failed to read platform from ${FRAMEWORK_BIN}, purging defensively"
  rm -rf "${FRAMEWORK_DIR}"
  exit 0
fi

if [ "${CACHED_PLATFORM}" = "${EXPECTED_PLATFORM}" ]; then
  # Cache matches current target — fast path, nothing to do.
  exit 0
fi

# Mismatch — log loudly and purge so the downstream native-assets
# build phase regenerates with the correct target.
echo "warning: [Socialmesh] native-assets cache has wrong-platform objective_c.framework"
echo "warning: [Socialmesh]   PLATFORM_NAME=${PLATFORM_NAME} expected=${EXPECTED_PLATFORM} cached=${CACHED_PLATFORM}"
echo "warning: [Socialmesh]   Purging ${FRAMEWORK_DIR} so the next build regenerates for the current target."
echo "warning: [Socialmesh]   This typically means a previous sim build (via xcodebuildmcp) populated the cache and a device build is now running."
echo "warning: [Socialmesh]   See lib/services/protocol/CLAUDE.md or memory entry feedback_native_assets_cache_per_platform.md."

rm -rf "${FRAMEWORK_DIR}"

# Removing the framework alone is not enough. Flutter's incremental
# build tracks the install step with a per-config stamp file at
# `.dart_tool/flutter_build/<hash>/install_code_assets.stamp`. If the
# stamp is fresh, `flutter assemble` skips re-installing the asset
# even when the output is missing. Nuke every such stamp so the
# next build re-runs the install step for the current target.
STAMP_GLOB="${PROJECT_ROOT}/.dart_tool/flutter_build"
if [ -d "${STAMP_GLOB}" ]; then
  find "${STAMP_GLOB}" -name 'install_code_assets.stamp' -print0 | while IFS= read -r -d '' stamp; do
    echo "warning: [Socialmesh]   Removing stamp ${stamp}"
    rm -f "${stamp}"
  done
fi
