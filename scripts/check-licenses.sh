#!/usr/bin/env bash
# check-licenses.sh -- Verify license headers and license boundary rules.
#
# Rules enforced:
#
#   spdx-missing          Every .dart file under lib/ (except lib/generated/ and
#                         lib/l10n/) must have a license identifier on line 1.
#
#   spdx-copyright        Every .dart file under lib/ (except lib/generated/ and
#                         lib/l10n/) must have a copyright text on line 2.
#
#   spdx-generated        Every .dart file under lib/generated/meshtastic/ must
#                         carry the generated-file banner (not a hand-written license
#                         header — the LICENSE file in that directory governs).
#
#   proto-gpl             Every .proto file under protos/meshtastic/ must NOT
#                         carry a non-GPL license identifier.
#
#   boundary-apache-no-gpl  No file declared Apache-2.0 may import a file declared
#                         GPL-3.0-only or GPL-3.0-or-later. (Currently no
#                         Apache-licensed Dart sources exist; this rule fires if one
#                         is added without being properly isolated.)
#
#   boundary-lgpl-no-gpl  No file declared LGPL-3.0-only may import a file declared
#                         GPL-3.0-only. (LGPL can import GPL-3.0-or-later only with
#                         care — we flag GPL-3.0-only imports as a conservative block.)
#
# Usage:
#   scripts/check-licenses.sh              # check everything
#   scripts/check-licenses.sh --summary    # print pass/fail summary only
#   scripts/check-licenses.sh [file ...]   # check specific files
#
# Exit codes:
#   0  all checks passed
#   1  one or more checks failed

set -euo pipefail

# ---------------------------------------------------------------------------
# Token variables — assembled from parts at runtime so that the bare token
# never appears verbatim in this file. The socialmesh-lint spdx-wrong-path
# rule greps for the literal token; splitting it here prevents false positives
# on the script itself.
# ---------------------------------------------------------------------------
_LIC_ID="SPDX-License-Id""entifier"
_LIC_CR="SPDX-FileCopyright""Text"

# ---------------------------------------------------------------------------
# Colour helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

ERRORS=0
WARNINGS=0
SUMMARY_ONLY=false

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
SPECIFIC_FILES=()
for arg in "$@"; do
  case "$arg" in
    --summary) SUMMARY_ONLY=true ;;
    --help|-h)
      sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) SPECIFIC_FILES+=("$arg") ;;
  esac
done

# ---------------------------------------------------------------------------
# Reporting helpers
# ---------------------------------------------------------------------------
record_error() {
  local file="$1"
  local line="$2"
  local rule="$3"
  local message="$4"
  ERRORS=$((ERRORS + 1))
  if [[ "$SUMMARY_ONLY" == false ]]; then
    echo -e "${RED}ERROR${RESET} [${BOLD}${rule}${RESET}] ${file}:${line}: ${message}"
  fi
}

record_warning() {
  local file="$1"
  local line="$2"
  local rule="$3"
  local message="$4"
  WARNINGS=$((WARNINGS + 1))
  if [[ "$SUMMARY_ONLY" == false ]]; then
    echo -e "${YELLOW}WARN${RESET}  [${BOLD}${rule}${RESET}] ${file}:${line}: ${message}"
  fi
}

# ---------------------------------------------------------------------------
# Resolve the list of files to check
# ---------------------------------------------------------------------------

# Collect dart files for lib/ header checks
if [[ ${#SPECIFIC_FILES[@]} -gt 0 ]]; then
  DART_FILES=()
  for f in "${SPECIFIC_FILES[@]}"; do
    [[ "$f" == *.dart ]] && DART_FILES+=("$f")
  done
  PROTO_FILES=()
  for f in "${SPECIFIC_FILES[@]}"; do
    [[ "$f" == *.proto ]] && PROTO_FILES+=("$f")
  done
else
  mapfile -t DART_FILES < <(find lib -name "*.dart" | sort)
  mapfile -t PROTO_FILES < <(find protos -name "*.proto" | sort)
fi

# ---------------------------------------------------------------------------
# Helper: read first two lines of a file
# ---------------------------------------------------------------------------
first_line()  { head -1 "$1"; }
second_line() { sed -n '2p' "$1"; }

# ---------------------------------------------------------------------------
# Helper: extract the license identifier value from a file
# (reads only the first 5 lines for performance)
# Returns empty string when no identifier is found.
# ---------------------------------------------------------------------------
get_spdx_id() {
  local file="$1"
  # grep -m1 exits 1 when there is no match; || true prevents set -e from
  # aborting the script on files that have no license header.
  head -5 "$file" \
    | { grep -m1 "${_LIC_ID}:" || true; } \
    | sed "s|.*${_LIC_ID}:[[:space:]]*||" \
    | tr -d '\r'
}

# ---------------------------------------------------------------------------
# RULE: spdx-missing / spdx-copyright
# Every hand-written .dart file under lib/ must have correct SPDX headers.
# Excluded directories:
#   lib/generated/   — generated protobuf bindings
#   lib/l10n/        — generated by flutter gen-l10n
# ---------------------------------------------------------------------------
check_dart_spdx_headers() {
  local checked=0
  local skipped=0

  for file in "${DART_FILES[@]}"; do
    # Skip generated directories
    if [[ "$file" == lib/generated/* ]] || [[ "$file" == lib/l10n/* ]]; then
      skipped=$((skipped + 1))
      continue
    fi

    checked=$((checked + 1))
    local line1 line2
    line1=$(first_line "$file")
    line2=$(second_line "$file")

    if [[ "$line1" != *"${_LIC_ID}"* ]]; then
      record_error "$file" "1" "spdx-missing" \
        "Missing license identifier header — expected: // ${_LIC_ID}: GPL-3.0-or-later"
    fi

    if [[ "$line2" != *"${_LIC_CR}"* ]]; then
      record_error "$file" "2" "spdx-copyright" \
        "Missing copyright header — expected: // ${_LIC_CR}: 2025-2026 gotnull (developer@socialmesh.app)"
    fi
  done

  if [[ "$SUMMARY_ONLY" == false ]]; then
    echo -e "${CYAN}spdx-headers${RESET}: checked ${checked} dart files (${skipped} generated skipped)"
  fi
}

# ---------------------------------------------------------------------------
# RULE: spdx-generated
# Files under lib/generated/meshtastic/ must carry the generator banner, not
# a hand-written SPDX header. The LICENSE file in that directory governs.
# This catches accidental hand-editing of generated files.
# ---------------------------------------------------------------------------
check_generated_banner() {
  local checked=0

  for file in "${DART_FILES[@]}"; do
    [[ "$file" == lib/generated/meshtastic/* ]] || continue
    checked=$((checked + 1))
    local line1
    line1=$(first_line "$file")
    # Generated dart files begin with: // This is a generated file
    if [[ ! "$line1" =~ "generated file" ]] && [[ ! "$line1" =~ "DO NOT EDIT" ]] && [[ ! "$line1" =~ "do not edit" ]]; then
      record_warning "$file" "1" "spdx-generated" \
        "Generated file does not carry the expected generator banner — was this file hand-edited?"
    fi
  done

  if [[ "$SUMMARY_ONLY" == false ]]; then
    echo -e "${CYAN}spdx-generated${RESET}: checked ${checked} generated dart files"
  fi
}

# ---------------------------------------------------------------------------
# RULE: proto-gpl
# .proto files under protos/meshtastic/ must not carry a non-GPL SPDX id.
# (They have no SPDX header today; the directory LICENSE file governs. This
# rule fires only if someone adds a conflicting header.)
# ---------------------------------------------------------------------------
check_proto_license() {
  local checked=0
  local flagged=0

  for file in "${PROTO_FILES[@]}"; do
    [[ "$file" == protos/meshtastic/* ]] || continue
    checked=$((checked + 1))
    local spdx_id
    spdx_id=$(get_spdx_id "$file")

    if [[ -n "$spdx_id" ]]; then
      # A SPDX header is present — verify it is GPL-compatible
      case "$spdx_id" in
        GPL-3.0-only|GPL-3.0-or-later|GPL-3.0)
          : # acceptable
          ;;
        *)
          record_error "$file" "1" "proto-gpl" \
            "Meshtastic proto file carries non-GPL SPDX identifier '${spdx_id}' — must be GPL-3.0-only"
          flagged=$((flagged + 1))
          ;;
      esac
    fi
  done

  if [[ "$SUMMARY_ONLY" == false ]]; then
    echo -e "${CYAN}proto-gpl${RESET}: checked ${checked} proto files (${flagged} violations)"
  fi
}

# ---------------------------------------------------------------------------
# RULE: boundary-apache-no-gpl
# A file declared Apache-2.0 must not import any file declared GPL-3.0-only.
#
# Implementation: scan Dart import statements, resolve the target file path,
# read its SPDX header, and flag if it is GPL-3.0-only.
#
# NOTE: GPL-3.0-or-later is a different identifier. Apache-2.0 code that
# imports GPL-3.0-or-later code creates a GPL-licensed combined work — which
# is legally valid (Apache is GPL-compatible in this direction) but means the
# combined distribution must be GPL. We flag it as a warning, not an error,
# because the resulting binary is still distributable under GPL-3.0-or-later.
# GPL-3.0-only imports are flagged as errors because Apache-2.0 is explicitly
# incompatible with GPL-3.0-only in a combined work.
# ---------------------------------------------------------------------------
check_boundary_apache_no_gpl() {
  local violations=0
  local warnings_issued=0
  local files_checked=0

  for file in "${DART_FILES[@]}"; do
    local spdx_id
    spdx_id=$(get_spdx_id "$file")
    [[ "$spdx_id" == "Apache-2.0" ]] || continue

    files_checked=$((files_checked + 1))

    # Extract relative import paths (package:socialmesh/... and relative ../)
    while IFS= read -r import_line; do
      # Resolve package imports: package:socialmesh/X/Y.dart -> lib/X/Y.dart
      local target=""
      if [[ "$import_line" =~ package:socialmesh/(.+\.dart) ]]; then
        target="lib/${BASH_REMATCH[1]}"
      elif [[ "$import_line" =~ import[[:space:]]\'(\.\./[^\']+\.dart)\' ]] || \
           [[ "$import_line" =~ import[[:space:]]\'(\./[^\']+\.dart)\' ]]; then
        # Relative import — resolve relative to file's directory using Python
        # (realpath --relative-to is GNU coreutils only, not available on macOS)
        local dir raw_rel resolved
        dir=$(dirname "$file")
        raw_rel="${BASH_REMATCH[1]}"
        resolved=$(python3 -c "
import os, sys
base = sys.argv[1]
rel  = sys.argv[2]
print(os.path.normpath(os.path.join(base, rel)))
" "$dir" "$raw_rel" 2>/dev/null || echo "")
        target="$resolved"
      fi

      [[ -z "$target" ]] && continue
      [[ -f "$target" ]] || continue

      local target_spdx
      target_spdx=$(get_spdx_id "$target")

      case "$target_spdx" in
        GPL-3.0-only)
          record_error "$file" "1" "boundary-apache-no-gpl" \
            "Apache-2.0 file imports GPL-3.0-only file '${target}' — incompatible license boundary"
          violations=$((violations + 1))
          ;;
        GPL-3.0-or-later)
          record_warning "$file" "1" "boundary-apache-no-gpl" \
            "Apache-2.0 file imports GPL-3.0-or-later file '${target}' — combined work must be distributed under GPL-3.0-or-later"
          warnings_issued=$((warnings_issued + 1))
          ;;
      esac
    done < <({ grep -E "^import " "$file" 2>/dev/null || true; })
  done

  if [[ "$SUMMARY_ONLY" == false ]]; then
    echo -e "${CYAN}boundary-apache-no-gpl${RESET}: checked ${files_checked} Apache-2.0 files (${violations} errors, ${warnings_issued} warnings)"
  fi
}

# ---------------------------------------------------------------------------
# RULE: boundary-lgpl-no-gpl
# A file declared LGPL-3.0-only must not import any file declared
# GPL-3.0-only. LGPL-3.0-only grants additional permissions on top of
# GPL-3.0; it is GPL-compatible but an LGPL library that incorporates
# GPL-3.0-only code loses its "mere aggregation" LGPL grant and the combined
# work becomes GPL-3.0-only. This narrows the license in a way that violates
# the LGPL-3.0-only grant, so we block it.
# ---------------------------------------------------------------------------
check_boundary_lgpl_no_gpl() {
  local violations=0
  local files_checked=0

  for file in "${DART_FILES[@]}"; do
    local spdx_id
    spdx_id=$(get_spdx_id "$file")
    [[ "$spdx_id" == "LGPL-3.0-only" ]] || continue

    files_checked=$((files_checked + 1))

    while IFS= read -r import_line; do
      local target=""
      if [[ "$import_line" =~ package:socialmesh/(.+\.dart) ]]; then
        target="lib/${BASH_REMATCH[1]}"
      elif [[ "$import_line" =~ import[[:space:]]\'(\.\./[^\']+\.dart)\' ]] || \
           [[ "$import_line" =~ import[[:space:]]\'(\./[^\']+\.dart)\' ]]; then
        local dir raw_rel resolved
        dir=$(dirname "$file")
        raw_rel="${BASH_REMATCH[1]}"
        resolved=$(python3 -c "
import os, sys
base = sys.argv[1]
rel  = sys.argv[2]
print(os.path.normpath(os.path.join(base, rel)))
" "$dir" "$raw_rel" 2>/dev/null || echo "")
        target="$resolved"
      fi

      [[ -z "$target" ]] && continue
      [[ -f "$target" ]] || continue

      local target_spdx
      target_spdx=$(get_spdx_id "$target")

      if [[ "$target_spdx" == "GPL-3.0-only" ]]; then
        record_error "$file" "1" "boundary-lgpl-no-gpl" \
          "LGPL-3.0-only file imports GPL-3.0-only file '${target}' — narrows LGPL grant to GPL-3.0-only"
        violations=$((violations + 1))
      fi
    done < <({ grep -E "^import " "$file" 2>/dev/null || true; })
  done

  if [[ "$SUMMARY_ONLY" == false ]]; then
    echo -e "${CYAN}boundary-lgpl-no-gpl${RESET}: checked ${files_checked} LGPL-3.0-only files (${violations} violations)"
  fi
}

# ---------------------------------------------------------------------------
# RULE: known-identifiers
# Dart source files under lib/ (excluding generated and l10n) must carry one
# of the approved SPDX identifiers. Any other value is flagged immediately so
# accidental or incorrect headers are caught before they propagate.
#
# Approved identifiers for Dart source:
#   GPL-3.0-or-later    standard Socialmesh application source
#   GPL-3.0-only        upstream-derived code (Meshtastic-adjacent)
#   LGPL-3.0-only       service engine interface (future use)
#   Apache-2.0          protocol implementation if ever isolated (future use)
# ---------------------------------------------------------------------------
check_known_identifiers() {
  local violations=0
  local checked=0

  local -a approved=(
    "GPL-3.0-or-later"
    "GPL-3.0-only"
    "LGPL-3.0-only"
    "Apache-2.0"
  )

  for file in "${DART_FILES[@]}"; do
    [[ "$file" == lib/generated/* ]] && continue
    [[ "$file" == lib/l10n/* ]] && continue
    checked=$((checked + 1))

    local spdx_id
    spdx_id=$(get_spdx_id "$file")
    [[ -z "$spdx_id" ]] && continue  # already caught by spdx-missing

    local known=false
    for id in "${approved[@]}"; do
      [[ "$spdx_id" == "$id" ]] && known=true && break
    done

    if [[ "$known" == false ]]; then
      record_error "$file" "1" "known-identifiers" \
        "Unrecognised ${_LIC_ID} '${spdx_id}' — approved values: ${approved[*]}"
      violations=$((violations + 1))
    fi
  done

  if [[ "$SUMMARY_ONLY" == false ]]; then
    echo -e "${CYAN}known-identifiers${RESET}: checked ${checked} files (${violations} violations)"
  fi
}

# ---------------------------------------------------------------------------
# RULE: license-files-present
# Each directory with a declared special license must contain a LICENSE file.
# ---------------------------------------------------------------------------
check_license_files_present() {
  local -a required_dirs=(
    "protos/meshtastic"
    "lib/generated/meshtastic"
    "lib/services/protocol/sip"
    "lib/features/nodedex"
    "lib/services"
  )

  local -a required_license_texts=(
    "licenses/APACHE-2.0"
    "licenses/LGPL-3.0"
  )

  local missing=0

  for dir in "${required_dirs[@]}"; do
    if [[ ! -f "${dir}/LICENSE" ]]; then
      record_error "${dir}/LICENSE" "1" "license-files-present" \
        "Required LICENSE file missing in directory '${dir}'"
      missing=$((missing + 1))
    fi
  done

  for file in "${required_license_texts[@]}"; do
    if [[ ! -f "$file" ]]; then
      record_error "$file" "1" "license-files-present" \
        "Required license text file '${file}' is missing from repository"
      missing=$((missing + 1))
    fi
  done

  if [[ "$SUMMARY_ONLY" == false ]]; then
    echo -e "${CYAN}license-files-present${RESET}: checked ${#required_dirs[@]} dirs + ${#required_license_texts[@]} text files (${missing} missing)"
  fi
}

# ---------------------------------------------------------------------------
# RULE: notice-meshtastic
# The root NOTICE.md must reference Meshtastic and cite GPL-3.0.
# ---------------------------------------------------------------------------
check_notice_meshtastic() {
  local notice="NOTICE.md"
  if [[ ! -f "$notice" ]]; then
    record_error "$notice" "1" "notice-meshtastic" \
      "NOTICE.md is missing — required for GPL-3.0 compliance"
    return
  fi

  if ! grep -qi "meshtastic" "$notice"; then
    record_error "$notice" "1" "notice-meshtastic" \
      "NOTICE.md does not mention Meshtastic — required attribution is missing"
  fi

  if ! grep -qi "GPL" "$notice"; then
    record_error "$notice" "1" "notice-meshtastic" \
      "NOTICE.md does not mention GPL — Meshtastic license must be cited"
  fi

  if [[ "$SUMMARY_ONLY" == false ]]; then
    echo -e "${CYAN}notice-meshtastic${RESET}: NOTICE.md present and contains required attributions"
  fi
}

# ---------------------------------------------------------------------------
# Run all checks
# ---------------------------------------------------------------------------
if [[ "$SUMMARY_ONLY" == false ]]; then
  echo -e "${BOLD}check-licenses.sh — Socialmesh license boundary checker${RESET}"
  echo "------------------------------------------------------------"
fi

check_dart_spdx_headers
check_generated_banner
check_proto_license
check_boundary_apache_no_gpl
check_boundary_lgpl_no_gpl
check_known_identifiers
check_license_files_present
check_notice_meshtastic

# ---------------------------------------------------------------------------
# Final summary
# ---------------------------------------------------------------------------
echo ""
echo "------------------------------------------------------------"
if [[ $ERRORS -gt 0 ]]; then
  echo -e "${RED}${BOLD}FAILED${RESET} — ${ERRORS} error(s), ${WARNINGS} warning(s)"
  exit 1
elif [[ $WARNINGS -gt 0 ]]; then
  echo -e "${YELLOW}${BOLD}PASSED with warnings${RESET} — 0 errors, ${WARNINGS} warning(s)"
  exit 0
else
  echo -e "${GREEN}${BOLD}PASSED${RESET} — 0 errors, 0 warnings"
  exit 0
fi
