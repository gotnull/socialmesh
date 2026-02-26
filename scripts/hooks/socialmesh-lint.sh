#!/usr/bin/env bash
# socialmesh-lint.sh -- Check staged (or specified) files for Socialmesh coding violations.
#
# Usage:
#   scripts/hooks/socialmesh-lint.sh                    # Check git-staged files
#   scripts/hooks/socialmesh-lint.sh --all              # Check all tracked files
#   scripts/hooks/socialmesh-lint.sh --diff-only        # Check only changed lines in staged files
#   scripts/hooks/socialmesh-lint.sh file1 file2        # Check specific files
#   scripts/hooks/socialmesh-lint.sh --format           # Also run dart format check
#   scripts/hooks/socialmesh-lint.sh --diff-only --format  # Combined
#
# Exit codes:
#   0  All checks passed
#   1  Violations found (details printed to stderr)
#
# Output format (one line per rule per file):
#   ERROR file:line [rule] message (N occurrences)
#   WARN  file:line [rule] message
#
# The first occurrence's line number is preserved so VS Code's problem
# matcher can create a clickable entry in the Problems panel.
#
# This script enforces the same rules as .claude/hookify.*.local.md rules
# but works at the git layer -- independent of any AI tool or editor.

set -euo pipefail

# ---------------------------------------------------------------------------
# Colors (disabled when not a terminal or when NO_COLOR is set)
# ---------------------------------------------------------------------------

if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
  RED='\033[0;31m'
  YELLOW='\033[1;33m'
  GREEN='\033[0;32m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  DIM='\033[2m'
  NC='\033[0m'
else
  RED='' YELLOW='' GREEN='' CYAN='' BOLD='' DIM='' NC=''
fi

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------

MODE="staged"       # staged | all | explicit
DIFF_ONLY=false
RUN_FORMAT=false
EXPLICIT_FILES=()

while [ $# -gt 0 ]; do
  case "$1" in
    --all)        MODE="all"; shift ;;
    --diff-only)  DIFF_ONLY=true; shift ;;
    --format)     RUN_FORMAT=true; shift ;;
    -*)           echo "Unknown flag: $1" >&2; exit 2 ;;
    *)            MODE="explicit"; EXPLICIT_FILES+=("$1"); shift ;;
  esac
done

# ---------------------------------------------------------------------------
# Collect files to check
# ---------------------------------------------------------------------------

FILES=()

case "$MODE" in
  staged)
    while IFS= read -r f; do
      [ -n "$f" ] && FILES+=("$f")
    done < <(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
    ;;
  all)
    while IFS= read -r f; do
      [ -n "$f" ] && FILES+=("$f")
    done < <(git ls-files 2>/dev/null || true)
    ;;
  explicit)
    FILES=("${EXPLICIT_FILES[@]}")
    ;;
esac

if [ ${#FILES[@]} -eq 0 ]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Diff-only mode: collect changed line numbers per file
#
# When --diff-only is active, only lines that appear in the staged diff
# are checked. This eliminates noise from pre-existing violations when
# you're editing a file with legacy patterns.
# ---------------------------------------------------------------------------

declare -A DIFF_LINES  # key="file" -> comma-separated line numbers

if [ "$DIFF_ONLY" = true ]; then
  # Parse unified diff to extract added line numbers
  current_file=""
  while IFS= read -r diffline; do
    # New file header: +++ b/path/to/file
    if [[ "$diffline" =~ ^\+\+\+\ b/(.+)$ ]]; then
      current_file="${BASH_REMATCH[1]}"
    # Hunk header: @@ -old,count +new,count @@
    elif [[ "$diffline" =~ ^@@\ .+\ \+([0-9]+)(,([0-9]+))?\ @@  ]]; then
      local_start="${BASH_REMATCH[1]}"
      local_count="${BASH_REMATCH[3]:-1}"
      # Generate line numbers for this hunk
      for (( i=0; i<local_count; i++ )); do
        ln=$((local_start + i))
        if [ -n "${DIFF_LINES[$current_file]+x}" ]; then
          DIFF_LINES[$current_file]="${DIFF_LINES[$current_file]},$ln"
        else
          DIFF_LINES[$current_file]="$ln"
        fi
      done
    fi
  done < <(git diff --cached -U0 2>/dev/null || true)
fi

# Check if a line number is in the diff for a given file.
# Returns 0 (true) if not in diff-only mode or if the line is changed.
line_in_scope() {
  local file="$1" lineno="$2"

  if [ "$DIFF_ONLY" = false ]; then
    return 0
  fi

  if [ -z "${DIFF_LINES[$file]+x}" ]; then
    # File has no diff lines -- skip all line checks for this file
    return 1
  fi

  # Check membership (comma-separated list)
  local lines_csv=",${DIFF_LINES[$file]},"
  if [[ "$lines_csv" == *",$lineno,"* ]]; then
    return 0
  fi

  return 1
}

# ---------------------------------------------------------------------------
# Hit accumulator
#
# Collects hits per (file, rule) and emits one grouped line per pair after
# each file is fully scanned.  Uses bash 4+ associative arrays.
# ---------------------------------------------------------------------------

declare -A HIT_FIRST_LINE   # key="file|rule" -> first line number
declare -A HIT_COUNT        # key="file|rule" -> occurrence count
declare -A HIT_SEVERITY     # key="file|rule" -> "error" or "warn"
declare -A HIT_MESSAGE      # key="file|rule" -> message text
HIT_KEYS=()                 # ordered list of unique keys

TOTAL_VIOLATIONS=0
TOTAL_WARNINGS=0
FILES_WITH_HITS=0

record_hit() {
  local file="$1" line="$2" rule="$3" msg="$4" severity="$5"
  local key="${file}|${rule}"

  if [ -z "${HIT_COUNT[$key]+x}" ]; then
    HIT_FIRST_LINE[$key]="$line"
    HIT_COUNT[$key]=1
    HIT_SEVERITY[$key]="$severity"
    HIT_MESSAGE[$key]="$msg"
    HIT_KEYS+=("$key")
  else
    HIT_COUNT[$key]=$(( ${HIT_COUNT[$key]} + 1 ))
  fi
}

flush_file_hits() {
  local target_file="$1"
  local file_had_hits=false

  for key in "${HIT_KEYS[@]}"; do
    local kfile="${key%%|*}"
    [ "$kfile" = "$target_file" ] || continue

    file_had_hits=true
    local rule="${key#*|}"
    local first_line="${HIT_FIRST_LINE[$key]}"
    local count="${HIT_COUNT[$key]}"
    local severity="${HIT_SEVERITY[$key]}"
    local msg="${HIT_MESSAGE[$key]}"

    local suffix=""
    if [ "$count" -gt 1 ]; then
      suffix=" ${DIM}(${count} occurrences)${NC}"
    fi

    if [ "$severity" = "error" ]; then
      TOTAL_VIOLATIONS=$((TOTAL_VIOLATIONS + 1))
      echo -e "${RED}${BOLD}ERROR${NC} ${kfile}:${first_line} [${rule}] ${msg}${suffix}" >&2
    else
      TOTAL_WARNINGS=$((TOTAL_WARNINGS + 1))
      echo -e "${YELLOW}WARN${NC}  ${kfile}:${first_line} [${rule}] ${msg}${suffix}" >&2
    fi

    unset "HIT_FIRST_LINE[$key]"
    unset "HIT_COUNT[$key]"
    unset "HIT_SEVERITY[$key]"
    unset "HIT_MESSAGE[$key]"
  done

  if [ "$file_had_hits" = true ]; then
    FILES_WITH_HITS=$((FILES_WITH_HITS + 1))
  fi

  # Rebuild HIT_KEYS without the flushed file's entries
  local remaining=()
  for key in "${HIT_KEYS[@]}"; do
    local kfile="${key%%|*}"
    [ "$kfile" != "$target_file" ] && remaining+=("$key")
  done
  HIT_KEYS=("${remaining[@]+"${remaining[@]}"}")
}

# ---------------------------------------------------------------------------
# grep-based pattern checks (fast path)
#
# Uses grep -nE to find matches, then filters by file category and
# diff scope. Much faster than line-by-line bash for large files.
# ---------------------------------------------------------------------------

# Run a grep pattern against a file and record hits.
# Usage: grep_check FILE PATTERN RULE MESSAGE SEVERITY [SKIP_COMMENTS] [SKIP_IMPORTS]
grep_check() {
  local file="$1"
  local pattern="$2"
  local rule="$3"
  local msg="$4"
  local severity="$5"
  local skip_comments="${6:-false}"
  local skip_imports="${7:-false}"

  while IFS=: read -r lineno matched_line; do
    # Skip if outside diff scope
    line_in_scope "$file" "$lineno" || continue

    # Skip comment lines
    if [ "$skip_comments" = true ]; then
      local trimmed="${matched_line#"${matched_line%%[![:space:]]*}"}"
      [[ "$trimmed" == //* ]] && continue
    fi

    # Skip import lines
    if [ "$skip_imports" = true ]; then
      [[ "$matched_line" == import* ]] && continue
    fi

    record_hit "$file" "$lineno" "$rule" "$msg" "$severity"
  done < <(grep -nE "$pattern" "$file" 2>/dev/null || true)
}

# ---------------------------------------------------------------------------
# Per-file checks
# ---------------------------------------------------------------------------

check_file() {
  local file="$1"

  [ -f "$file" ] || return 0

  # Skip generated files entirely -- they contain upstream patterns
  # (TODO comments, etc.) that we don't control
  case "$file" in
    lib/generated/*) return 0 ;;
    *.pb.dart|*.pbenum.dart|*.pbjson.dart|*.pbserver.dart) return 0 ;;
    *.g.dart|*.freezed.dart) return 0 ;;
    lib/core/widgets/glass_scaffold.dart) return 0 ;;
  esac

  # Skip Flutter SDK template files -- these are auto-generated and
  # contain upstream TODO comments that we don't control
  case "$file" in
    android/app/build.gradle.kts) return 0 ;;
    linux/flutter/CMakeLists.txt) return 0 ;;
    windows/flutter/CMakeLists.txt) return 0 ;;
  esac

  # Classify file
  local in_lib=false
  local in_lib_generated=false
  local in_theme=false
  local in_prohibited_spdx_dir=false
  local is_dart=false

  case "$file" in
    lib/generated/*) in_lib_generated=true; in_lib=true ;;
    lib/core/theme/*) in_theme=true; in_lib=true ;;
    lib/*) in_lib=true ;;
  esac

  case "$file" in
    backend/*|docs/*|scripts/*|tools/*|web/*|.github/*) in_prohibited_spdx_dir=true ;;
  esac

  case "$file" in
    *.dart) is_dart=true ;;
  esac

  # ------------------------------------------------------------------
  # BLOCK: TODO / FIXME / HACK comments (all files)
  # In Dart files, skip lines where the pattern appears inside a string
  # literal (e.g., test assertions that search for TODO patterns).
  # ------------------------------------------------------------------
  if [ "$is_dart" = true ]; then
    while IFS=: read -r lineno matched_line; do
      line_in_scope "$file" "$lineno" || continue
      local trimmed="${matched_line#"${matched_line%%[![:space:]]*}"}"
      # Skip if the TODO/FIXME/HACK appears inside a string literal
      # (single or double quotes containing the pattern)
      if [[ "$matched_line" =~ \'.*(TODO|FIXME|HACK).*\' ]] || \
         [[ "$matched_line" =~ \".*(TODO|FIXME|HACK).*\" ]]; then
        continue
      fi
      record_hit "$file" "$lineno" "no-todo-fixme-hack" \
        "TODO/FIXME/HACK comment — implement now or create a sprint task" "error"
    done < <(grep -nE '(//[[:space:]]*(TODO|FIXME|HACK)|#[[:space:]]*(TODO|FIXME|HACK))' "$file" 2>/dev/null || true)
  else
    grep_check "$file" \
      '(//[[:space:]]*(TODO|FIXME|HACK)|#[[:space:]]*(TODO|FIXME|HACK))' \
      "no-todo-fixme-hack" \
      "TODO/FIXME/HACK comment — implement now or create a sprint task" \
      "error"
  fi

  # ------------------------------------------------------------------
  # Dart-specific checks
  # ------------------------------------------------------------------
  if [ "$is_dart" = true ]; then

    # BLOCK: Banned Riverpod 2.x patterns
    # Use word boundaries (\b) to avoid false positives on identifiers
    # that merely contain these strings as substrings (e.g.
    # PurchaseStateNotifier, connectionStateProvider).
    grep_check "$file" \
      '(\bStateNotifier\b|\bStateNotifierProvider\b|\bStateProvider\b|\bChangeNotifierProvider\b)' \
      "no-banned-riverpod" \
      "Banned Riverpod 2.x pattern — use Notifier/AsyncNotifier/NotifierProvider instead" \
      "error" true true

    # BLOCK: Material dialogs
    grep_check "$file" \
      '(showDialog[[:space:]]*\(|AlertDialog[[:space:]]*\(|SimpleDialog[[:space:]]*\()' \
      "no-material-dialogs" \
      "Material dialog — use AppBottomSheet, DatePickerSheet, or TimePickerSheet" \
      "error" true true

    # BLOCK: FloatingActionButton (except glass_scaffold.dart which IS the FAB wrapper)
    if [[ "$file" != *"glass_scaffold.dart" ]]; then
      grep_check "$file" \
        'FloatingActionButton' \
        "no-fab" \
        "FloatingActionButton — primary actions belong in the app bar" \
        "error" true true
    fi

    # BLOCK: throw UnimplementedError (skip noSuchMethod overrides in test fakes
    # and string literals that search for the pattern in audit tests)
    if [[ "$file" == test/* ]]; then
      # In test files, only flag actual throw statements — skip noSuchMethod
      # fakes and string-literal audit pattern matches
      while IFS=: read -r lineno matched_line; do
        line_in_scope "$file" "$lineno" || continue
        local trimmed="${matched_line#"${matched_line%%[![:space:]]*}"}"
        [[ "$trimmed" == //* ]] && continue
        # noSuchMethod pattern is standard Dart test fake
        [[ "$matched_line" == *"noSuchMethod"* ]] && continue
        # Skip string literals containing the pattern (audit tests)
        if [[ "$matched_line" =~ \'.*UnimplementedError.*\' ]] || \
           [[ "$matched_line" =~ \".*UnimplementedError.*\" ]]; then
          continue
        fi
        record_hit "$file" "$lineno" "no-unimplemented" \
          "Unimplemented stub — implement the method or remove the dead code" "error"
      done < <(grep -nE 'throw[[:space:]]+UnimplementedError' "$file" 2>/dev/null || true)
    else
      grep_check "$file" \
        'throw[[:space:]]+UnimplementedError' \
        "no-unimplemented" \
        "Unimplemented stub — implement the method or remove the dead code" \
        "error" true
    fi

    # BLOCK: Bare Scaffold( usage (not GlassScaffold, not in theme layer)
    # Exempt glass_scaffold.dart which IS the GlassScaffold implementation.
    # Files that legitimately need bare Scaffold (immersive overlays,
    # navigation shells, pre-auth gates) can add a file-level comment:
    #   // lint-allow: scaffold — <reason>
    if [ "$in_lib" = true ] && [ "$in_lib_generated" = false ] && [ "$in_theme" = false ] \
       && [[ "$file" != *"glass_scaffold.dart" ]]; then
      # Check for file-level scaffold exemption
      local scaffold_exempt=false
      if grep -q 'lint-allow:.*scaffold' "$file" 2>/dev/null; then
        scaffold_exempt=true
      fi

      if [ "$scaffold_exempt" = false ]; then
        # Match Scaffold( but not GlassScaffold(, not imports, not comments
        while IFS=: read -r lineno matched_line; do
          line_in_scope "$file" "$lineno" || continue
          local trimmed="${matched_line#"${matched_line%%[![:space:]]*}"}"
          [[ "$trimmed" == //* ]] && continue
          [[ "$matched_line" == import* ]] && continue
          # Exclude GlassScaffold and ScaffoldMessenger
          if [[ ! "$matched_line" =~ GlassScaffold ]] && [[ ! "$matched_line" =~ ScaffoldMessenger ]] && [[ ! "$matched_line" =~ ScaffoldState ]]; then
            record_hit "$file" "$lineno" "no-bare-scaffold" \
              "Bare Scaffold — use GlassScaffold instead" "error"
          fi
        done < <(grep -nE '\bScaffold\(' "$file" 2>/dev/null || true)
      fi
    fi
  fi

  # ------------------------------------------------------------------
  # BLOCK: // ignore: directives outside lib/generated/
  # Only check Dart files -- markdown and yaml mention ignore: as documentation
  # ------------------------------------------------------------------
  if [ "$in_lib_generated" = false ] && [ "$is_dart" = true ]; then
    grep_check "$file" \
      '//[[:space:]]*ignore:' \
      "no-ignore-directive" \
      "Lint ignore directive outside lib/generated/ — fix the underlying issue instead" \
      "error"
  fi

  # ------------------------------------------------------------------
  # ERROR: Railway domains (all files)
  # ------------------------------------------------------------------
  grep_check "$file" \
    '\.up\.railway\.app' \
    "no-railway-domains" \
    "Railway domain (*.up.railway.app) — use socialmesh.app custom domains" \
    "error"

  # ------------------------------------------------------------------
  # ERROR: SPDX header in prohibited directories
  # ------------------------------------------------------------------
  if [ "$in_prohibited_spdx_dir" = true ]; then
    grep_check "$file" \
      'SPDX-License-Identifier' \
      "spdx-wrong-path" \
      "SPDX header not allowed here — only lib/ and test/ files get SPDX headers" \
      "error"
  fi

  # ------------------------------------------------------------------
  # ERROR: Magic numbers for spacing/sizing (Dart files under lib/)
  # Exempt theme.dart — that's where the constants are defined.
  # ------------------------------------------------------------------
  if [ "$is_dart" = true ] && [ "$in_lib" = true ] && [ "$in_lib_generated" = false ] \
     && [[ "$file" != *"core/theme.dart" ]]; then
    grep_check "$file" \
      '(EdgeInsets\.[a-zA-Z]+\([[:space:]]*[0-9]+\.?[0-9]*|SizedBox\([[:space:]]*(width|height)[[:space:]]*:[[:space:]]*[0-9]+\.?[0-9]*|BorderRadius\.[a-zA-Z]+\([[:space:]]*[0-9]+\.?[0-9]*)' \
      "magic-numbers" \
      "Magic number — use AppTheme spacing/sizing constants" \
      "error" true
  fi

  # ------------------------------------------------------------------
  # WARN: Async safety -- context/ref/setState after await without
  # mounted check.  Uses an awk state machine (10x faster than bash
  # while-read on large files):
  #   idle       -> post_await  (on seeing `await`)
  #   post_await -> idle        (on seeing `mounted` or new method)
  #   post_await + dangerous use -> emit line number
  # Only runs on Dart files under lib/ (not generated).
  # Fast gate: skip entirely if the file has no `await` usage.
  # ------------------------------------------------------------------
  if [ "$is_dart" = true ] && [ "$in_lib" = true ] && [ "$in_lib_generated" = false ] \
     && grep -q 'await ' "$file" 2>/dev/null; then

    # Determine if this is a Notifier/AsyncNotifier class file where ref is a class member.
    # In those files, ref.read/ref.watch after await is safe (ref is stable, not captured).
    # Also treat provider and service files the same way — ref is always a function param
    # or class field in those contexts, never a captured WidgetRef.
    local is_notifier_file=false
    if grep -qE 'extends\s+(Auto[Dd]ispose)?(Family)?(Async)?Notifier\b' "$file" 2>/dev/null; then
      is_notifier_file=true
    fi
    # Provider/service files: ref is always safe (function param or class member)
    # Also match files ending in _providers.dart or _repository.dart
    # (e.g. widget_sync_providers.dart, bug_report_repository.dart)
    if [[ "$file" == */providers/* ]] || [[ "$file" == */services/* ]] \
       || [[ "$file" == *_providers.dart ]] || [[ "$file" == *_repository.dart ]]; then
      is_notifier_file=true
    fi

    while IFS= read -r hit_lineno; do
      [ -n "$hit_lineno" ] || continue
      if line_in_scope "$file" "$hit_lineno"; then
        record_hit "$file" "$hit_lineno" "async-safety" \
          "context/ref/setState used after await without mounted check" "error"
      fi
    done < <(awk -v is_notifier="$is_notifier_file" '
      BEGIN { state = "idle"; await_ln = 0 }

      # Skip comment-only lines
      { trimmed = $0; sub(/^[[:space:]]+/, "", trimmed) }
      /^[[:space:]]*\/\// { next }

      # Reset on new method/function declaration or @override
      /^[[:space:]]*(void|Future|Widget|State|bool|int|double|String|dynamic|List|Map|Set|FutureOr)[[:space:]].*\(/ {
        state = "idle"; next
      }
      /^[[:space:]]*@override[[:space:]]*$/ { state = "idle"; next }

      # Reset on new async scope (anonymous closures like () async {)
      # to prevent post_await state from leaking across scope boundaries.
      /async[[:space:]]*\{/ { state = "idle" }

      # Detect await — only enter post_await when the statement completes.
      # Multi-line await expressions (e.g. await AppBottomSheet.show(
      #   context: context, child: ...)) stay in in_await_expr until
      # the closing ;, so context/ref inside the argument list is not
      # flagged as a false positive.
      /await[[:space:]]/ || /await;/ {
        t = trimmed; sub(/\/\/.*$/, "", t); sub(/[[:space:]]+$/, "", t)
        if (t ~ /;$/) {
          state = "post_await"; await_ln = NR
        } else {
          state = "in_await_expr"; await_ln = NR
        }
      }

      # Await expression spans multiple lines — wait for statement to end
      state == "in_await_expr" {
        t = trimmed; sub(/\/\/.*$/, "", t); sub(/[[:space:]]+$/, "", t)
        if (t ~ /;$/) {
          state = "post_await"; await_ln = NR
        }
      }

      # In post_await state
      state == "post_await" {
        # mounted check clears the danger zone.
        # safeSetState() checks mounted internally, so treat it the same.
        if (/mounted/ || /safeSetState/) { state = "idle"; next }

        # Dangerous usage after the await line itself
        if (NR > await_ln) {
          # In notifier/provider files, ref.read/ref.watch and .setState() are safe
          # (.setState() on notifiers sets provider state, not Flutter setState)
          if (is_notifier == "true") {
            if (/context\./) {
              print NR
              state = "idle"
            }
          } else {
            if (/context\./ || /ref\.read\(/ || /ref\.watch\(/ || /setState\(/) {
              print NR
              state = "idle"
            }
          }
        }
      }
    ' "$file" 2>/dev/null)
  fi

  # ------------------------------------------------------------------
  # Whole-file checks (Dart files under lib/, not generated)
  # These always run regardless of --diff-only because they check
  # structural properties of the entire file.
  # ------------------------------------------------------------------
  if [ "$is_dart" = true ] && [ "$in_lib" = true ] && [ "$in_lib_generated" = false ]; then

    # WARN: Screen class without GlassScaffold
    # Honors // lint-allow: scaffold exemption (same as no-bare-scaffold)
    if grep -qE 'class[[:space:]]+[A-Za-z_]+Screen[[:space:]]+extends[[:space:]]+(ConsumerStatefulWidget|ConsumerWidget|StatefulWidget|StatelessWidget)' "$file" 2>/dev/null; then
      if ! grep -q 'GlassScaffold' "$file" 2>/dev/null; then
        if ! grep -q 'lint-allow:.*scaffold' "$file" 2>/dev/null; then
          record_hit "$file" "1" "require-glass-scaffold" \
            "Screen class without GlassScaffold — all screens must use GlassScaffold" "error"
        fi
      fi
    fi

    # WARN: TextField/TextFormField without maxLength
    # Only check non-comment lines (grep -v strips // and /// lines)
    if grep -vE '^\s*//' "$file" | grep -qE '(TextField|TextFormField)[[:space:]]*\(' 2>/dev/null; then
      if ! grep -q 'maxLength' "$file" 2>/dev/null; then
        record_hit "$file" "1" "textfield-maxlength" \
          "TextField/TextFormField without maxLength — all text inputs must be bounded" "error"
      fi
    fi
  fi # end whole-file checks

  # Flush grouped output for this file
  flush_file_hits "$file"
}

# ---------------------------------------------------------------------------
# SPDX header presence check (lib/ and test/ Dart files must have it)
# ---------------------------------------------------------------------------

check_spdx_required() {
  local file="$1"

  case "$file" in
    lib/generated/*) return 0 ;;
    *.g.dart|*.freezed.dart|*.pb.dart|*.pbenum.dart|*.pbjson.dart|*.pbserver.dart) return 0 ;;
  esac

  case "$file" in
    lib/*.dart|test/*.dart)
      if [ -f "$file" ]; then
        local first_line
        first_line=$(head -1 "$file" 2>/dev/null) || return 0
        if [[ ! "$first_line" =~ SPDX-License-Identifier ]]; then
          record_hit "$file" "1" "spdx-missing" \
            "Missing SPDX header — add: // SPDX-License-Identifier: GPL-3.0-or-later" "error"
        fi
      fi
      ;;
  esac
}

# ---------------------------------------------------------------------------
# dart format check
# ---------------------------------------------------------------------------

FORMAT_FAILURES=()

check_dart_format() {
  local dart_files=()
  for file in "${FILES[@]}"; do
    case "$file" in
      *.dart)
        [ -f "$file" ] && dart_files+=("$file")
        ;;
    esac
  done

  [ ${#dart_files[@]} -eq 0 ] && return 0

  # Check if dart is available
  if ! command -v dart &>/dev/null; then
    echo -e "${YELLOW}WARN${NC}  dart not found — skipping format check" >&2
    return 0
  fi

  # Run dart format in dry-run mode
  local output
  output=$(dart format --set-exit-if-changed --output=none "${dart_files[@]}" 2>&1) || true

  # Parse output for files that need formatting.
  # dart format outputs "Changed <file>" for unformatted files.
  while IFS= read -r fmtline; do
    if [[ "$fmtline" =~ ^Changed[[:space:]]+(.+)$ ]]; then
      local unformatted="${BASH_REMATCH[1]}"
      FORMAT_FAILURES+=("$unformatted")
    fi
  done <<< "$output"
}

# ---------------------------------------------------------------------------
# Run all checks
# ---------------------------------------------------------------------------

# dart format (if requested)
if [ "$RUN_FORMAT" = true ]; then
  check_dart_format
fi

# Pattern checks
for file in "${FILES[@]}"; do
  check_file "$file"
  check_spdx_required "$file"
  flush_file_hits "$file"
done

# ---------------------------------------------------------------------------
# Report format failures
# ---------------------------------------------------------------------------

if [ ${#FORMAT_FAILURES[@]} -gt 0 ]; then
  for ff in "${FORMAT_FAILURES[@]}"; do
    TOTAL_VIOLATIONS=$((TOTAL_VIOLATIONS + 1))
    echo -e "${RED}${BOLD}ERROR${NC} ${ff}:1 [dart-format] File is not formatted — run: dart format ${ff}" >&2
  done
  FILES_WITH_HITS=$((FILES_WITH_HITS + ${#FORMAT_FAILURES[@]}))
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

if [ $TOTAL_VIOLATIONS -gt 0 ] || [ $TOTAL_WARNINGS -gt 0 ]; then
  echo "" >&2
  local_summary="${FILES_WITH_HITS} file(s)"
  if [ $TOTAL_VIOLATIONS -gt 0 ]; then
    echo -e "${local_summary}, ${RED}${BOLD}${TOTAL_VIOLATIONS} error(s)${NC}, ${YELLOW}${TOTAL_WARNINGS} warning(s)${NC}" >&2
  else
    echo -e "${local_summary}, ${GREEN}0 errors${NC}, ${YELLOW}${TOTAL_WARNINGS} warning(s)${NC}" >&2
  fi
fi

if [ $TOTAL_VIOLATIONS -gt 0 ]; then
  echo -e "${RED}Commit blocked. Fix the errors above before committing.${NC}" >&2
  exit 1
fi

exit 0
