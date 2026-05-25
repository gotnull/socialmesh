#!/usr/bin/env bash
# socialmesh-lint.sh -- Check staged (or specified) files for SocialMesh coding violations.
#
# Rules:
#   no-todo-fixme-hack        TODO/FIXME/HACK comments
#   no-banned-riverpod         Riverpod 2.x patterns (StateNotifier, etc.)
#   no-material-dialogs        showDialog/AlertDialog/SimpleDialog
#   no-raw-snackbar            Raw SnackBar() construction
#   no-fab                     FloatingActionButton
#   no-bare-logging            Bare debugPrint/print (use AppLogging.<feature>)
#   no-private-log             Private _log() methods (use AppLogging.<feature> directly)
#   no-hardcoded-ui-strings    Hardcoded user-facing strings (Text('...'), title: '...')
#   no-raw-latlng              Raw LatLng(<expr>, <expr>) outside safeLatLng()
#   no-unimplemented           throw UnimplementedError
#   no-bare-scaffold           Bare Scaffold (use GlassScaffold)
#   no-bare-switch             Bare Switch/SwitchListTile (use ThemedSwitch)
#   no-bare-dropdown           Bare DropdownButton (wrap in DropdownButtonHideUnderline)
#   no-ignore-directive        // ignore: outside lib/generated/
#   no-railway-domains         Railway *.up.railway.app domains
#   socialmesh-name-casing     Wrong app-name casing (canonical: SocialMesh; banned: Socialmesh, Social Mesh, etc.)
#   spdx-wrong-path            SPDX header in prohibited dirs
#   spdx-missing               Missing SPDX header in lib/test
#   spdx-copyright-missing     Missing SPDX copyright in lib/test
#   magic-numbers              Hardcoded spacing/sizing numbers
#   no-hardcoded-color         Hardcoded colors (use SemanticColors)
#   async-safety               context/ref/setState after await
#   require-glass-scaffold     Screen class without GlassScaffold
#   textfield-maxlength        TextField without maxLength
#   help-button-needs-controller  IcoHelpAppBarButton without controller
#   require-lifecycle-mixin    ConsumerStatefulWidget async without mixin
#   stream-subscription-cancel StreamSubscription without cancel
#   keyboard-dismissal         Screen with text input, no dismissal
#   haptic-feedback            GestureDetector onTap without haptics
#   no-scrollable-in-glass-body  Scrollable in GlassScaffold.body()
#   dart-format                File not formatted (--format flag)
#
#
# Usage:
#   scripts/hooks/socialmesh-lint.sh                    # Check git-staged files
#   scripts/hooks/socialmesh-lint.sh --all              # Check all tracked files
#   scripts/hooks/socialmesh-lint.sh --diff-only        # Check only changed lines in staged files
#   scripts/hooks/socialmesh-lint.sh file1 file2        # Check specific files
#   scripts/hooks/socialmesh-lint.sh --format           # Also run dart format check
#   scripts/hooks/socialmesh-lint.sh --em-dash file ... # Also flag em-dash chars (opt-in: see below)
#   scripts/hooks/socialmesh-lint.sh --unsafe-pop file ... # Flag unsafe Navigator.pop in callbacks (opt-in)
#   scripts/hooks/socialmesh-lint.sh --no-raw-latlng file ... # Flag raw LatLng() outside safeLatLng (opt-in)
#   scripts/hooks/socialmesh-lint.sh --diff-only --format  # Combined
#
# --em-dash is opt-in by design. The em-dash character (U+2014) is banned
# project-wide, but hundreds of legacy files still contain them. Running the
# check by default would block routine edits on unrelated files. Pass
# --em-dash when you specifically want to scrub em-dashes from files you are
# touching (e.g. before committing your own changes).
#
# --unsafe-pop is opt-in by design. Closures like
#   onPressed: () => Navigator.of(context).pop()
# inside a State subclass capture this.context. State.context throws
# FlutterError("This widget has been unmounted") when accessed after the
# State is disposed - which happens when a tap-up event fires during route
# teardown. This crash signature has been seen in production Crashlytics
# (widget_import_screen.dart, e20436b6a738dc2e52cba727f13652b2). The fix is
# safeNavigatorPop from LifecycleSafeMixin (or a mounted check). The lint
# cannot distinguish State.context from a Builder/parameter context without
# AST analysis, so pass --unsafe-pop when reviewing files you are about to
# ship to surface candidates manually.
#
# --no-raw-latlng is opt-in by design. flutter_map's Crs.checkLatLng throws
# fatally when a non-finite LatLng reaches projectAtZoom, and Crashlytics
# issue 563ef91f regressed four times because new features kept introducing
# raw LatLng(expr, expr) constructions outside the safeLatLng() helper. The
# rule flags every LatLng( with an identifier-prefix first arg (i.e. not a
# numeric literal), skipping `const LatLng` and the definition file. 50+
# legacy callsites still fire today, so running by default would block
# routine edits unrelated to the LatLng family. Pass --no-raw-latlng when
# reviewing files you are about to ship; new code should route through
# safeLatLng() from lib/core/safe_lat_lng.dart.
#
# Exit codes:
#   0  All checks passed
#   1  Violations found (details printed to stderr)
#
# Output format (one line per rule per file):
#   ERROR file:line [rule] message (N occurrences)
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
CHECK_EM_DASH=false  # Opt-in: em-dash check is OFF by default. Hundreds of
                     # legacy files contain em-dashes; flipping this on by
                     # default would block routine edits on unrelated files.
                     # Pass --em-dash when you specifically want to scrub
                     # em-dashes from files you are about to touch.
CHECK_UNSAFE_POP=false  # Opt-in: surfaces Navigator.of(context).pop in
                        # arrow callbacks. False positives are unavoidable
                        # without AST analysis (Builder/parameter contexts
                        # are safe, State.context is not). Use when auditing
                        # a file before shipping to verify each site.
CHECK_RAW_LATLNG=false  # Opt-in: flags raw LatLng(<expr>, <expr>) outside
                        # safeLatLng(). flutter_map's Crs.checkLatLng throws
                        # fatally on non-finite values; every new callsite
                        # should route through safeLatLng. 50+ legacy sites
                        # would fire today, so off by default - run when
                        # auditing files before shipping.
EXPLICIT_FILES=()

while [ $# -gt 0 ]; do
  case "$1" in
    --all)          MODE="all"; shift ;;
    --diff-only)    DIFF_ONLY=true; shift ;;
    --format)       RUN_FORMAT=true; shift ;;
    --em-dash)      CHECK_EM_DASH=true; shift ;;
    --unsafe-pop)   CHECK_UNSAFE_POP=true; shift ;;
    --no-raw-latlng) CHECK_RAW_LATLNG=true; shift ;;
    -*)             echo "Unknown flag: $1" >&2; exit 2 ;;
    *)              MODE="explicit"; EXPLICIT_FILES+=("$1"); shift ;;
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
#
# Uses a temp directory with one file per source file (filename is an md5
# hash of the path) to avoid bash 4+ associative arrays, which are
# unavailable on macOS system bash 3.2.
# ---------------------------------------------------------------------------

_DIFF_DIR=""

_cleanup_temp_dirs() {
  [ -n "$_DIFF_DIR" ] && rm -rf "$_DIFF_DIR"
  [ -n "$_HIT_DIR" ]  && rm -rf "$_HIT_DIR"
}
trap _cleanup_temp_dirs EXIT

_diff_key() {
  # Produce a safe filename from an arbitrary path.
  printf '%s' "$1" | md5sum 2>/dev/null | cut -d' ' -f1 \
    || printf '%s' "$1" | md5 2>/dev/null | cut -d' ' -f1 \
    || printf '%s' "$1" | shasum -a 256 | cut -c1-32
}

if [ "$DIFF_ONLY" = true ]; then
  _DIFF_DIR=$(mktemp -d)
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
      key=$(_diff_key "$current_file")
      # Generate line numbers for this hunk
      for (( i=0; i<local_count; i++ )); do
        ln=$((local_start + i))
        if [ -f "$_DIFF_DIR/$key" ]; then
          printf ',%s' "$ln" >> "$_DIFF_DIR/$key"
        else
          printf '%s' "$ln" > "$_DIFF_DIR/$key"
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

  local key
  key=$(_diff_key "$file")

  if [ ! -f "$_DIFF_DIR/$key" ]; then
    # File has no diff lines -- skip all line checks for this file
    return 1
  fi

  # Check membership (comma-separated list)
  local lines_csv
  lines_csv=",$(cat "$_DIFF_DIR/$key"),"
  if [[ "$lines_csv" == *",$lineno,"* ]]; then
    return 0
  fi

  return 1
}

# ---------------------------------------------------------------------------
# Hit accumulator
#
# Collects hits per (file, rule) and emits one grouped line per pair after
# each file is fully scanned.  Uses temp files to stay compatible with
# macOS system bash 3.2 (which lacks associative arrays).
# ---------------------------------------------------------------------------

_HIT_DIR=$(mktemp -d)

_hit_key() {
  printf '%s' "$1" | md5sum 2>/dev/null | cut -d' ' -f1 \
    || printf '%s' "$1" | md5 2>/dev/null | cut -d' ' -f1 \
    || printf '%s' "$1" | shasum -a 256 | cut -c1-32
}

HIT_KEYS=()                 # ordered list of unique composite keys

TOTAL_VIOLATIONS=0
FILES_WITH_HITS=0

record_hit() {
  local file="$1" line="$2" rule="$3" msg="$4" severity="$5"
  local composite="${file}|${rule}"
  local hk
  hk=$(_hit_key "$composite")

  if [ ! -f "$_HIT_DIR/${hk}.count" ]; then
    printf '%s' "$line"     > "$_HIT_DIR/${hk}.line"
    printf '%s' "1"         > "$_HIT_DIR/${hk}.count"
    printf '%s' "$severity" > "$_HIT_DIR/${hk}.sev"
    printf '%s' "$msg"      > "$_HIT_DIR/${hk}.msg"
    # Store the composite key so we can recover file and rule later
    printf '%s' "$composite" > "$_HIT_DIR/${hk}.key"
    HIT_KEYS+=("$composite")
  else
    local old_count
    old_count=$(cat "$_HIT_DIR/${hk}.count")
    printf '%s' "$(( old_count + 1 ))" > "$_HIT_DIR/${hk}.count"
  fi
}

flush_file_hits() {
  local target_file="$1"
  local file_had_hits=false

  for composite in ${HIT_KEYS[@]+"${HIT_KEYS[@]}"}; do
    local kfile="${composite%%|*}"
    [ "$kfile" = "$target_file" ] || continue

    file_had_hits=true
    local rule="${composite#*|}"
    local hk
    hk=$(_hit_key "$composite")

    local first_line count severity msg
    first_line=$(cat "$_HIT_DIR/${hk}.line")
    count=$(cat "$_HIT_DIR/${hk}.count")
    severity=$(cat "$_HIT_DIR/${hk}.sev")
    msg=$(cat "$_HIT_DIR/${hk}.msg")

    local suffix=""
    if [ "$count" -gt 1 ]; then
      suffix=" ${DIM}(${count} occurrences)${NC}"
    fi

    TOTAL_VIOLATIONS=$((TOTAL_VIOLATIONS + 1))
    echo -e "${RED}${BOLD}ERROR${NC} ${kfile}:${first_line} [${rule}] ${msg}${suffix}" >&2

    rm -f "$_HIT_DIR/${hk}".{line,count,sev,msg,key}
  done

  if [ "$file_had_hits" = true ]; then
    FILES_WITH_HITS=$((FILES_WITH_HITS + 1))
  fi

  # Rebuild HIT_KEYS without the flushed file's entries
  local remaining=()
  for composite in ${HIT_KEYS[@]+"${HIT_KEYS[@]}"}; do
    local kfile="${composite%%|*}"
    [ "$kfile" != "$target_file" ] && remaining+=("$composite")
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
    lib/l10n/app_localizations*.dart) return 0 ;;
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

  # Skip this lint script itself -- it contains banned patterns as part
  # of its rule definitions (e.g. the railway domain grep pattern)
  case "$file" in
    scripts/hooks/socialmesh-lint.sh) return 0 ;;
  esac

  # Classify file
  local in_lib=false
  local in_lib_generated=false
  local in_theme=false
  local in_prohibited_spdx_dir=false
  local is_dart=false

  local is_painter=false
  local is_onboarding=false
  local is_help_system=false
  local is_visual_flow=false
  local is_ar=false
  local is_intro_anim=false
  local is_mesh3d=false
  local is_whats_new=false
  local is_splash=false

  case "$file" in
    lib/generated/*) in_lib_generated=true; in_lib=true ;;
    lib/core/theme.dart|lib/core/theme/*) in_theme=true; in_lib=true ;;
    lib/*) in_lib=true ;;
  esac

  case "$file" in
    *painter*.dart|*_painter.dart) is_painter=true ;;
  esac
  case "$file" in
    *onboarding*) is_onboarding=true ;;
  esac
  case "$file" in
    *ico_help_system*) is_help_system=true ;;
  esac
  case "$file" in
    lib/core/visual_flow/*|*visual_flow*) is_visual_flow=true ;;
  esac
  case "$file" in
    lib/features/ar/*) is_ar=true ;;
  esac
  case "$file" in
    lib/features/intro/*) is_intro_anim=true ;;
  esac
  case "$file" in
    lib/features/mesh3d/*) is_mesh3d=true ;;
  esac
  case "$file" in
    lib/core/whats_new/*) is_whats_new=true ;;
  esac
  case "$file" in
    lib/providers/splash_mesh_provider.dart) is_splash=true ;;
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

    # BLOCK: Raw showModalBottomSheet — every modal sheet MUST route through
    # AppBottomSheet (.show / .showScrollable / .showConfirm / .showPicker /
    # .showActions) so global behaviour (bounce-in arrival animation,
    # disableAnimations gate, drag-pill, safe-context handling) applies
    # uniformly. Raw showModalBottomSheet callers bypass all of this.
    # Exempt: lib/core/widgets/app_bottom_sheet.dart (the canonical wrapper).
    if [[ "$file" != *"core/widgets/app_bottom_sheet.dart" ]]; then
      grep_check "$file" \
        '\bshowModalBottomSheet[[:space:]]*[<(]' \
        "no-raw-modal-bottom-sheet" \
        "Raw showModalBottomSheet — use AppBottomSheet.show / showScrollable / showConfirm / showPicker / showActions instead" \
        "error" true true
    fi

    # BLOCK: Raw SnackBar construction (use snackbar utilities instead)
    # The app has styled snackbar helpers (showInfoSnackBar, showErrorSnackBar,
    # showSuccessSnackBar, showWarningSnackBar, showActionSnackBar) and
    # safeShowSnackBar from LifecycleSafeMixin. Raw SnackBar( bypasses the
    # glass-styled appearance and is never correct in feature code.
    # Exempt: lib/utils/snackbar.dart (defines the utilities),
    #         lib/core/safety/lifecycle_mixin.dart (defines safeShowSnackBar).
    if [[ "$file" != *"utils/snackbar.dart" ]] && [[ "$file" != *"lifecycle_mixin.dart" ]]; then
      grep_check "$file" \
        '\bSnackBar\(' \
        "no-raw-snackbar" \
        "Raw SnackBar — use showInfoSnackBar/showErrorSnackBar/showSuccessSnackBar/safeShowSnackBar instead" \
        "error" true true
    fi

    # BLOCK: FloatingActionButton (except glass_scaffold.dart which IS the FAB wrapper)
    if [[ "$file" != *"glass_scaffold.dart" ]]; then
      grep_check "$file" \
        'FloatingActionButton' \
        "no-fab" \
        "FloatingActionButton — primary actions belong in the app bar" \
        "error" true true
    fi

    # ------------------------------------------------------------------
    # BLOCK: Bare debugPrint / print calls (must use AppLogging)
    #
    # All logging in lib/ must go through AppLogging.<feature>() so it
    # is gated by .env flags and produces grep-friendly prefixed output.
    # Bare debugPrint( and print( bypass this and pollute the console.
    #
    # Exempt: lib/core/logging.dart (defines AppLogging, calls debugPrint
    #         internally — that's the ONLY file allowed to do so).
    # ------------------------------------------------------------------
    if [ "$in_lib" = true ] && [ "$in_lib_generated" = false ] \
       && [[ "$file" != *"core/logging.dart" ]]; then
      grep_check "$file" \
        '\bdebugPrint\(' \
        "no-bare-logging" \
        "Bare debugPrint() — use AppLogging.<feature>() instead (gated by .env flags)" \
        "error" true true

      # print( — but not debugPrint(, printTo(, printBuffer(, reprint(,
      # sprint(, toString, etc.
      while IFS=: read -r lineno matched_line; do
        line_in_scope "$file" "$lineno" || continue
        local trimmed="${matched_line#"${matched_line%%[![:space:]]*}"}"
        # Skip comments
        [[ "$trimmed" == //* ]] && continue
        # Skip imports
        [[ "$matched_line" == import* ]] && continue
        # Skip string literals that mention print
        [[ "$matched_line" =~ \'.*print.*\' ]] && continue
        [[ "$matched_line" =~ \".*print.*\" ]] && continue
        record_hit "$file" "$lineno" "no-bare-logging" \
          "Bare print() — use AppLogging.<feature>() instead (gated by .env flags)" "error"
      done < <(grep -nE '(^|[^a-zA-Z_])print\([^)]*\)' "$file" 2>/dev/null \
        | grep -vE '(debugPrint|printTo|printBuffer|reprint|sprint|fingerprint|footprint|imprint|blueprint|toString)' \
        || true)
    fi

    # ------------------------------------------------------------------
    # BLOCK: Private _log() method definitions
    #
    # Private _log() wrappers around AppLogging add needless indirection.
    # They obscure which AppLogging channel is being used, make grep
    # harder, and tempt copy-pasters to wire _log() to debugPrint
    # directly. Call AppLogging.<feature>() at each call site instead.
    #
    # Detects: void _log(, static void _log(, _log(String
    # Does NOT flag _log usage in test/ files (test helpers are fine).
    # ------------------------------------------------------------------
    if [ "$in_lib" = true ] && [ "$in_lib_generated" = false ]; then
      grep_check "$file" \
        '(void _log\(|static void _log\(|^\s+_log\(String)' \
        "no-private-log" \
        "Private _log() method — call AppLogging.<feature>() directly at each call site" \
        "error" true
    fi

    # ------------------------------------------------------------------
    # BLOCK: Hardcoded user-facing strings (i18n enforcement)
    #
    # Prevents regressions after Sprint 010 l10n extraction. Detects
    # Text(), title:, hintText:, tooltip:, label:, and other UI-facing
    # named parameters that take a raw string literal instead of a
    # context.l10n call.
    #
    # Scope: lib/features/ and lib/core/widgets/ only.
    # Sub-check B restricted to screen/widget files (not services,
    # providers, models, repositories, or exporters where named params
    # like title:/label:/message: are often data model fields).
    # Honors: // lint-allow: hardcoded-string (line or file level)
    #
    # Sub-check A: Text() with a direct string literal argument.
    # Sub-check B: Named UI parameters with string literal values.
    # ------------------------------------------------------------------
    if [[ "$file" == lib/features/* ]] || [[ "$file" == lib/core/widgets/* ]]; then
      if ! grep -q 'lint-allow:.*hardcoded-string' "$file" 2>/dev/null; then

        # Sub-check A: Text( with string literal
        # Runs on all files in scope — Text() is always a widget.
        while IFS=: read -r lineno matched_line; do
          line_in_scope "$file" "$lineno" || continue
          local trimmed="${matched_line#"${matched_line%%[![:space:]]*}"}"
          [[ "$trimmed" == //* ]] && continue
          [[ "$matched_line" == import* ]] && continue
          # Skip logging/debug lines
          [[ "$matched_line" =~ AppLogging ]] && continue
          [[ "$matched_line" =~ log\.(info|debug|warning|severe|fine) ]] && continue
          [[ "$matched_line" =~ debugPrint ]] && continue
          # Skip technical identifiers (keys, tags)
          [[ "$matched_line" =~ ValueKey ]] && continue
          # Skip lines inside string literals (toString, interpolation)
          [[ "$trimmed" == \'* ]] && continue
          [[ "$trimmed" == \"* ]] && continue
          # Line-level exemption
          [[ "$matched_line" =~ lint-allow:.*hardcoded-string ]] && continue
          record_hit "$file" "$lineno" "no-hardcoded-ui-strings" \
            "Hardcoded user-facing string in Text() — use context.l10n instead" "error"
        done < <(grep -nE '\bText\([[:space:]]*(const[[:space:]]+)?['"'"'"]' "$file" 2>/dev/null || true)

        # Sub-check B: Named UI parameters with string literal values
        # Only runs on screen/widget files — skips services, providers,
        # models, repositories, exporters, validators, and storage files
        # where title:/label:/message: are often data model fields.
        local run_param_check=true
        case "$file" in
          */services/*|*_service.dart) run_param_check=false ;;
          */providers/*|*_providers.dart|*_provider.dart) run_param_check=false ;;
          */models/*|*_model.dart) run_param_check=false ;;
          *_repository.dart|*_exporter.dart|*_validator.dart) run_param_check=false ;;
          *_storage*.dart) run_param_check=false ;;
        esac

        if [ "$run_param_check" = true ]; then
          # Checked params: title, subtitle, hintText, tooltip, label,
          #   labelText, message, confirmLabel, errorText, semanticsLabel
          while IFS=: read -r lineno matched_line; do
            line_in_scope "$file" "$lineno" || continue
            local trimmed="${matched_line#"${matched_line%%[![:space:]]*}"}"
            [[ "$trimmed" == //* ]] && continue
            [[ "$matched_line" == import* ]] && continue
            [[ "$matched_line" =~ AppLogging ]] && continue
            [[ "$matched_line" =~ log\.(info|debug|warning|severe|fine) ]] && continue
            [[ "$matched_line" =~ debugPrint ]] && continue
            # Skip lines inside string literals (toString patterns)
            [[ "$trimmed" == \'* ]] && continue
            [[ "$trimmed" == \"* ]] && continue
            # Line-level exemption
            [[ "$matched_line" =~ lint-allow:.*hardcoded-string ]] && continue
            record_hit "$file" "$lineno" "no-hardcoded-ui-strings" \
              "Hardcoded user-facing string in UI parameter — use context.l10n instead" "error"
          done < <(grep -nE '(title|subtitle|hintText|tooltip|label|labelText|message|confirmLabel|errorText|semanticsLabel):[[:space:]]*['"'"'"]' "$file" 2>/dev/null || true)
        fi

      fi
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
  # BLOCK: Bare Switch / SwitchListTile (use ThemedSwitch instead)
  # Exempt animations.dart which IS the ThemedSwitch implementation.
  # ------------------------------------------------------------------
  if [ "$in_lib" = true ] && [ "$in_lib_generated" = false ] \
     && [[ "$file" != *"animations.dart" ]]; then
    # Switch.adaptive(
    grep_check "$file" \
      'Switch\.adaptive[[:space:]]*\(' \
      "no-bare-switch" \
      "Bare Switch.adaptive — use ThemedSwitch instead" \
      "error" true true

    # Raw Switch( — but not ThemedSwitch( or SwitchListTile(
    while IFS=: read -r lineno matched_line; do
      line_in_scope "$file" "$lineno" || continue
      local trimmed="${matched_line#"${matched_line%%[![:space:]]*}"}"
      [[ "$trimmed" == //* ]] && continue
      [[ "$matched_line" == import* ]] && continue
      if [[ ! "$matched_line" =~ ThemedSwitch ]] && [[ ! "$matched_line" =~ SwitchListTile ]]; then
        record_hit "$file" "$lineno" "no-bare-switch" \
          "Bare Switch — use ThemedSwitch instead" "error"
      fi
    done < <(grep -nE '\bSwitch\(' "$file" 2>/dev/null || true)

    # SwitchListTile(
    grep_check "$file" \
      'SwitchListTile[[:space:]]*\(' \
      "no-switch-list-tile" \
      "SwitchListTile — use ListTile with ThemedSwitch trailing instead" \
      "error" true true
  fi

  # ------------------------------------------------------------------
  # ERROR: Bare DropdownButton (must be wrapped in DropdownButtonHideUnderline)
  # Checks preceding 5 lines for the HideUnderline wrapper.
  # ------------------------------------------------------------------
  if [ "$in_lib" = true ] && [ "$in_lib_generated" = false ]; then
    while IFS=: read -r lineno matched_line; do
      line_in_scope "$file" "$lineno" || continue
      local trimmed="${matched_line#"${matched_line%%[![:space:]]*}"}"
      [[ "$trimmed" == //* ]] && continue
      [[ "$matched_line" == import* ]] && continue
      # Skip if this line itself is the HideUnderline wrapper
      [[ "$matched_line" =~ DropdownButtonHideUnderline ]] && continue
      # Check preceding 5 lines for DropdownButtonHideUnderline
      # Also check following 12 lines for underline: override pattern
      # (generous window to handle multi-line generic type params)
      local start_line=$(( lineno > 5 ? lineno - 5 : 1 ))
      local end_line=$(( lineno + 12 ))
      local context
      context=$(sed -n "${start_line},${end_line}p" "$file" 2>/dev/null || true)
      if [[ ! "$context" =~ DropdownButtonHideUnderline ]] \
         && [[ ! "$context" =~ underline: ]]; then
        record_hit "$file" "$lineno" "no-bare-dropdown" \
          "Bare DropdownButton — wrap in DropdownButtonHideUnderline" "error"
      fi
    done < <(grep -nE '\bDropdownButton[<(]' "$file" 2>/dev/null || true)
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
    "Railway domain (*.up.railway.app) - use socialmesh.app custom domains" \
    "error"

  # ------------------------------------------------------------------
  # ERROR: Wrong app-name casing (all files, NON-NEGOTIABLE)
  #
  # Canonical form is "SocialMesh" (single word, both S and M
  # capitalized). Banned forms:
  #   Socialmesh   - capital S + lowercase m
  #   Social Mesh  - two words
  #   Social-Mesh  - hyphenated
  #   socialMesh   - camelCase with lowercase s
  #
  # Lowercase "socialmesh" is INTENTIONALLY allowed - it is the
  # correct form in identifiers, domains (socialmesh.app), emails
  # (@socialmesh.app), bundle IDs (com.gotnull.socialmesh), Dart
  # package names (package:socialmesh/...), and filesystem paths.
  #
  # Applies to every file type including ARB/HTML/MD/YAML so
  # translators and marketing copy are covered. Skip via per-file
  # `lint-allow: socialmesh-name-casing` (used in web/marketing.html
  # FAQ which documents the wrong forms intentionally).
  #
  # Path-based skips below cover identifiers baked into native
  # project structure where renaming requires invasive Xcode/Android
  # surgery (target rename, group renames, signing, build phases) and
  # the symbol is internal-only, not user-facing:
  #   - iOS widget extension target folder + its Xcode refs
  #   - Android Application class + its AndroidManifest reference
  # ------------------------------------------------------------------
  local skip_name_casing=false
  case "$file" in
    ios/SocialmeshWidgets/*) skip_name_casing=true ;;
    ios/Runner.xcodeproj/project.pbxproj) skip_name_casing=true ;;
    android/app/src/main/AndroidManifest.xml) skip_name_casing=true ;;
    android/app/src/main/kotlin/com/gotnull/socialmesh/SocialmeshApplication.kt) skip_name_casing=true ;;
  esac
  if [ "$skip_name_casing" = false ] && ! grep -q 'lint-allow:.*socialmesh-name-casing' "$file" 2>/dev/null; then
    grep_check "$file" \
      '(Socialmesh|Social[ -][Mm]esh|socialMesh)' \
      "socialmesh-name-casing" \
      "Wrong app-name casing - use 'SocialMesh' (capital S and M). Banned: Socialmesh, Social Mesh, socialMesh, Social-Mesh. Lowercase 'socialmesh' is OK in identifiers/domains/paths." \
      "error"
  fi

  # ------------------------------------------------------------------
  # ERROR: Em-dash (U+2014) anywhere - banned project-wide
  # See user memory feedback_no_em_dash. Use hyphen, colon, or split
  # sentence instead. Applies to Dart, ARB, markdown, YAML, shell, TS.
  # The skip-generated guard at the top of check_file already excludes
  # vendored / auto-generated files we do not own.
  #
  # OPT-IN: this check only runs with --em-dash because hundreds of
  # legacy files still contain em-dashes; flipping it on by default
  # would block routine edits unrelated to em-dash cleanup.
  # ------------------------------------------------------------------
  if [ "$CHECK_EM_DASH" = true ]; then
    grep_check "$file" \
      $'\xe2\x80\x94' \
      "no-em-dash" \
      "Em-dash character is banned project-wide. Use hyphen, colon, or split sentence." \
      "error"
  fi

  # ------------------------------------------------------------------
  # ERROR: Navigator.of(context).pop in arrow callback (Dart files only)
  # See feedback_navigator_pop_state_context. Closures like
  #   onPressed: () => Navigator.of(context).pop()
  # capture this.context inside a State subclass and crash with
  # FlutterError("This widget has been unmounted") when the tap-up
  # event fires after the State is disposed (route teardown race).
  # Production Crashlytics signature: e20436b6a738dc2e52cba727f13652b2.
  # Fix: use safeNavigatorPop (LifecycleSafeMixin) or guard with
  # if (!mounted) return;. Builder/parameter contexts are safe and
  # will be flagged as false positives - audit each hit manually.
  #
  # OPT-IN because the regex cannot distinguish State.context from
  # parameter contexts without AST analysis.
  # ------------------------------------------------------------------
  if [ "$CHECK_UNSAFE_POP" = true ] && [[ "$file" == *.dart ]]; then
    grep_check "$file" \
      'on(Pressed|Tap|LongPress|DoubleTap|Dismissed|Submitted|Changed):[[:space:]]*\(\)[[:space:]]*=>[[:space:]]*Navigator\.of\([^)]*\)\.pop' \
      "unsafe-navigator-pop" \
      "Navigator.of(context).pop in arrow callback - if context is State.context, swap for safeNavigatorPop or add a mounted guard. Skip if context is a Builder/parameter." \
      "error"
  fi

  # ------------------------------------------------------------------
  # ERROR: Raw LatLng(<expr>, <expr>) outside safeLatLng()
  # flutter_map's Crs.checkLatLng throws fatally on NaN / Infinity /
  # out-of-range coords. Every code path that builds a LatLng from
  # runtime numeric data must route through safeLatLng() (see
  # lib/core/safe_lat_lng.dart) so bad values drop out before reaching
  # projectAtZoom. Crashlytics issue 563ef91f regressed four times
  # before this rule was added.
  #
  # The regex flags any LatLng( with an identifier-prefix first arg
  # (i.e. not a numeric literal). Lines containing `const LatLng` and
  # the definition file itself are skipped.
  #
  # OPT-IN: 50+ legacy callsites still fire today.
  # ------------------------------------------------------------------
  if [ "$CHECK_RAW_LATLNG" = true ] && [ "$is_dart" = true ]; then
    case "$file" in
      lib/core/safe_lat_lng.dart) ;;
      *)
        while IFS=: read -r lineno matched_line; do
          line_in_scope "$file" "$lineno" || continue
          # Skip lines where the LatLng is being assigned to a const
          # binding (`const x = LatLng(...)`) or constructed inline as
          # `const LatLng(...)`. Both forms are compile-time literals
          # and cannot carry NaN at runtime.
          [[ "$matched_line" =~ (^|[^a-zA-Z_])const([[:space:]]|$).*LatLng\( ]] && continue
          # Skip comment-only lines.
          local trimmed="${matched_line#"${matched_line%%[![:space:]]*}"}"
          [[ "$trimmed" == //* ]] && continue
          record_hit "$file" "$lineno" "no-raw-latlng" \
            "Raw LatLng(<expr>) - wrap with safeLatLng() so NaN/Infinity/out-of-range coords drop out before reaching flutter_map projectAtZoom (lib/core/safe_lat_lng.dart)." \
            "error"
        done < <(grep -nE '[^a-zA-Z_]LatLng\([a-zA-Z_]' "$file" 2>/dev/null || true)
        ;;
    esac
  fi

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
  # ERROR: Hardcoded colors — use SemanticColors / theme extensions
  #
  # Two sub-checks:
  #
  # 1. Named Colors.xxx (e.g. Colors.red, Colors.grey[700]) — these
  #    ALWAYS have a semantic equivalent and must be replaced.
  #    Exempt: white, black, transparent (universal).
  #
  # 2. Color(0xFF...) hex literals — only flagged when the hex value
  #    exactly matches a known theme constant (brand colors, accent
  #    colors, status colors, surface colors, text colors). One-off
  #    decorative hex values (gradients, glows, third-party brand
  #    colors like Google blue) are allowed.
  #
  # Exempt files: theme.dart (defines constants), painters, onboarding
  # (pre-theme), help system overlay, visual flow engine, AR overlays,
  # intro animations, mesh3d, whats_new, splash provider, accessibility
  # adapter, admin screens, mesh_node_brain.
  # Contributors can add // lint-allow: hardcoded-color for edge cases.
  # ------------------------------------------------------------------
  if [ "$is_dart" = true ] && [ "$in_lib" = true ] && [ "$in_lib_generated" = false ] \
     && [ "$in_theme" = false ] && [ "$is_painter" = false ] \
     && [ "$is_onboarding" = false ] && [ "$is_help_system" = false ] \
     && [ "$is_visual_flow" = false ] && [ "$is_ar" = false ] \
     && [ "$is_intro_anim" = false ] && [ "$is_mesh3d" = false ] \
     && [ "$is_whats_new" = false ] && [ "$is_splash" = false ] \
     && [[ "$file" != *"accessibility_theme_adapter"* ]] \
     && [[ "$file" != *"admin/"* ]] \
     && [[ "$file" != *"mesh_node_brain"* ]]; then

    # Skip if file has a blanket exemption
    if ! grep -q 'lint-allow:.*hardcoded-color' "$file" 2>/dev/null; then

      # Color(0xFF...) hex literals — only flag known theme constants.
      # One-off decorative/gradient/brand hex values are fine.
      #
      # Known hex values that MUST use their named constant:
      #   Brand:    E91E8C (magenta), 8B5CF6 (purple), 4F6AF6 (blue)
      #   Accent:   6366F1 (indigo), 0EA5E9 (sky), 06B6D4 (cyan),
      #             14B8A6 (teal), 10B981 (emerald), 22C55E (green),
      #             84CC16 (lime), EAB308 (yellow), F97316 (orange),
      #             FF6B6B (coral), EF4444 (red), EC4899 (pink),
      #             F43F5E (rose), A78BFA (lavender), 64748B (slate)
      #   Status:   4ADE80 (success), FBBF24 (warning), EF4444 (error)
      #   Semantic: F97BBD (secondaryPink), FF9D6E (accentOrange)
      #   Gold:     FFCC00, D4AF37, B8860B, 996515
      #   Surface:  1F2633 (darkBg), 29303D (darkSurface), 414A5A (darkBorder),
      #             F5F7FA (lightBg), F0F2F5 (lightCardAlt), E0E4EA (lightBorder)
      #   Text:     1A1F2E, 4B5563, 9CA3AF, D1D5DB
      #   Graph:    3B82F6 (graphBlue)
      local known_hex_pattern='Color\(0xFF(E91E8C|8B5CF6|4F6AF6|6366F1|0EA5E9|06B6D4|14B8A6|10B981|22C55E|84CC16|EAB308|F97316|FF6B6B|EF4444|EC4899|F43F5E|A78BFA|64748B|4ADE80|FBBF24|F97BBD|FF9D6E|FFCC00|D4AF37|B8860B|996515|1F2633|29303D|414A5A|F5F7FA|F0F2F5|E0E4EA|1A1F2E|4B5563|9CA3AF|D1D5DB|3B82F6)\)'
      while IFS=: read -r lineno matched_line; do
        line_in_scope "$file" "$lineno" || continue
        local trimmed="${matched_line#"${matched_line%%[![:space:]]*}"}"
        [[ "$trimmed" == //* ]] && continue
        [[ "$matched_line" == import* ]] && continue
        record_hit "$file" "$lineno" "no-hardcoded-color" \
          "Hardcoded color hex — use the named constant from AppTheme/AccentColors" "error"
      done < <(grep -nE "$known_hex_pattern" "$file" 2>/dev/null || true)

      # Named Colors.xxx (but NOT Colors.white, Colors.black, Colors.transparent)
      while IFS=: read -r lineno matched_line; do
        line_in_scope "$file" "$lineno" || continue
        local trimmed="${matched_line#"${matched_line%%[![:space:]]*}"}"
        [[ "$trimmed" == //* ]] && continue
        [[ "$matched_line" == import* ]] && continue
        # Allow white, black, transparent
        if [[ "$matched_line" =~ Colors\.(white|black|transparent) ]]; then
          # Only skip if ONLY white/black/transparent appear on this line
          local stripped="${matched_line//Colors.white/}"
          stripped="${stripped//Colors.black/}"
          stripped="${stripped//Colors.transparent/}"
          if [[ ! "$stripped" =~ Colors\.[a-z] ]]; then
            continue
          fi
        fi
        record_hit "$file" "$lineno" "no-hardcoded-color" \
          "Hardcoded color — use SemanticColors, AccentColors, ChartColors, or context.* theme extensions" "error"
      done < <(grep -nE '(^|[^a-zA-Z])Colors\.(red|redAccent|blue|blueGrey|green|orange|yellow|purple|pink|teal|indigo|amber|cyan|lime|brown|grey|deepOrange|deepPurple|lightBlue|lightGreen)' "$file" 2>/dev/null || true)
    fi
  fi

  # ------------------------------------------------------------------
  # ERROR: Async safety -- context/ref/setState after await without
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

      # Reset when a closure/block closes or branches.  Matches:
      #   }          — end of block / closure
      #   },         — end of closure in argument list
      #   } else {   — else branch (await in the if-block did not execute here)
      #   } catch (  — catch branch after try with await
      #   } finally {— finally branch
      #   } on Foo { — typed catch
      # This prevents post_await state leaking into sibling branches or
      # surrounding widget-tree code.
      state == "post_await" && /^[[:space:]]*\}/ { state = "idle" }

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
        # mounted check or LifecycleSafeMixin safe* methods clear the danger zone.
        # All safe* methods check mounted internally before touching context.
        # canUpdateUI is the LifecycleSafeMixin equivalent of mounted.
        if (/mounted/ || /canUpdateUI/ || /safe[A-Z]/) { state = "idle"; next }

        # Dangerous usage after the await line itself.
        # Strip inline comments and string literals before pattern matching
        # to avoid false positives on context/ref inside log strings or comments.
        if (NR > await_ln) {
          line = $0
          sub(/\/\/.*$/, "", line)
          gsub(/"[^"]*"/, "", line)
          # Strip single-quoted string literals. \x27 is apostrophe — avoids breaking
          # the surrounding bash single-quote string that wraps this awk program.
          gsub(/\x27[^\x27]*\x27/, "", line)

          # context unsafe: four precise patterns that indicate real BuildContext usage.
          # Avoids false positives on local variables named "context" (e.g. Map context).
          #
          # Pattern 1: .of(context) — Flutter static accessor (Navigator.of, Theme.of, etc.)
          ctx_of = (line ~ /\.of\(context[),]/)
          # Pattern 2: context as first positional arg of known navigation/snackbar helpers
          ctx_first = (line ~ /Navigator\.(push|pop|pushNamed|pushReplacement|pushAndRemoveUntil|replace|canPop|maybePop)[[:space:]]*\(context[),]/ || \
                       line ~ /show(Error|Info|Success|Warning|Action)?SnackBar[[:space:]]*\(context[),]/)
          # Pattern 3: context: context — named argument passing BuildContext
          ctx_named = (line ~ /context:[[:space:]]*context[),;]/)
          # Pattern 4: context. — method or property access on BuildContext (context.l10n, context.read, etc.)
          ctx_dot = (line ~ /^[[:space:]]*context\./ || line ~ /[^A-Za-z_]context\./)
          ctx_unsafe = (ctx_of || ctx_first || ctx_named || ctx_dot)

          # ref unsafe: ref.read( / ref.watch( used as a captured WidgetRef after await.
          # Not flagged in notifier/provider files where ref is a stable class member.
          ref_unsafe = (is_notifier != "true" && (line ~ /ref\.read\(/ || line ~ /ref\.watch\(/))

          # setState unsafe: raw setState( after await without a mounted guard.
          set_unsafe = (is_notifier != "true" && line ~ /setState\(/)

          if (ctx_unsafe || ref_unsafe || set_unsafe) {
            print NR
            # Do NOT reset state — keep reporting every unsafe use in this async gap,
            # matching the behaviour of flutter analyze use_build_context_synchronously.
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

    # ERROR: Screen class without GlassScaffold
    # Honors // lint-allow: scaffold exemption (same as no-bare-scaffold)
    if grep -qE 'class[[:space:]]+[A-Za-z_]+Screen[[:space:]]+extends[[:space:]]+(ConsumerStatefulWidget|ConsumerWidget|StatefulWidget|StatelessWidget)' "$file" 2>/dev/null; then
      if ! grep -q 'GlassScaffold' "$file" 2>/dev/null; then
        if ! grep -q 'lint-allow:.*scaffold' "$file" 2>/dev/null; then
          record_hit "$file" "1" "require-glass-scaffold" \
            "Screen class without GlassScaffold — all screens must use GlassScaffold" "error"
        fi
      fi
    fi

    # ERROR: TextField/TextFormField without maxLength
    # Only check non-comment lines (grep -v strips // and /// lines)
    if grep -vE '^\s*//' "$file" 2>/dev/null | grep -qE '(TextField|TextFormField)[[:space:]]*\(' 2>/dev/null; then
      if ! grep -q 'maxLength' "$file" 2>/dev/null; then
        record_hit "$file" "1" "textfield-maxlength" \
          "TextField/TextFormField without maxLength — all text inputs must be bounded" "error"
      fi
    fi

    # ------------------------------------------------------------------
    # ERROR: IcoHelpAppBarButton without HelpTourController
    #
    # If a file uses IcoHelpAppBarButton, it MUST also have a
    # HelpTourController wrapping its scaffold. Without the controller
    # the help button toggles state but no overlay appears.
    # ------------------------------------------------------------------
    if grep -vE '^\s*//' "$file" 2>/dev/null | grep -q 'IcoHelpAppBarButton' 2>/dev/null; then
      if ! grep -q 'HelpTourController' "$file" 2>/dev/null; then
        record_hit "$file" "1" "help-button-needs-controller" \
          "IcoHelpAppBarButton without HelpTourController — the tour overlay will not render" "error"
      fi
    fi

    # ------------------------------------------------------------------
    # ERROR: ConsumerStatefulWidget with async but no LifecycleSafeMixin
    #
    # Any ConsumerStatefulWidget whose State class uses await must mix
    # in LifecycleSafeMixin for safe mounted checks and safeSetState.
    # Uses awk to analyse per-class scope so that await in unrelated
    # classes, static methods, or provider functions in the same file
    # does not trigger a false positive.
    # Skip provider/service files entirely — ref lifecycle is framework-
    # managed and widget subclasses in those files are typically inert.
    # ------------------------------------------------------------------
    if [[ "$file" != */providers/* ]] && [[ "$file" != */services/* ]] \
       && [[ "$file" != *_providers.dart ]] && [[ "$file" != *_service.dart ]] \
       && [[ "$file" != *_provider.dart ]]; then

      while IFS= read -r hit_lineno; do
        [ -n "$hit_lineno" ] || continue
        record_hit "$file" "$hit_lineno" "require-lifecycle-mixin" \
          "ConsumerStatefulWidget with async but no LifecycleSafeMixin — add LifecycleSafeMixin for safe async" "error"
      done < <(awk '
        # Track when we enter a ConsumerState class body.
        # We look for "extends ConsumerState<" and then check whether
        # LifecycleSafeMixin appears on the same declaration line (the
        # "with" clause can span multiple lines, so we also scan until
        # the opening brace).
        #
        # Once inside the class body, we check for "await ".  If we
        # reach the end of the class (next top-level class or EOF)
        # having seen await but no LifecycleSafeMixin, we emit the
        # starting line number.

        BEGIN {
          in_consumer = 0; has_await = 0; has_mixin = 0
          class_line = 0; brace_depth = 0; in_decl = 0
        }

        # Detect the start of a ConsumerState class (declaration line).
        /extends[[:space:]]+ConsumerState</ {
          # Flush any previous class that was still open
          if (in_consumer && has_await && !has_mixin) print class_line

          in_consumer = 1; has_await = 0; has_mixin = 0
          class_line = NR; brace_depth = 0; in_decl = 1
        }

        # While still in the declaration (before opening brace),
        # check for LifecycleSafeMixin on "with" line(s).
        in_decl {
          if (/LifecycleSafeMixin/) has_mixin = 1
          if (/{/) { in_decl = 0 }
        }

        # Track brace depth inside the class body.
        in_consumer && !in_decl {
          n = split($0, chars, "")
          for (i = 1; i <= n; i++) {
            if (chars[i] == "{") brace_depth++
            if (chars[i] == "}") {
              brace_depth--
              if (brace_depth <= 0) {
                # End of class body
                if (has_await && !has_mixin) print class_line
                in_consumer = 0; has_await = 0; has_mixin = 0
                break
              }
            }
          }
        }

        # Detect await inside the class body (skip comments)
        in_consumer && !in_decl {
          line = $0; sub(/^[[:space:]]+/, "", line)
          if (line !~ /^\/\//) {
            if (/await[[:space:]]/ || /await;/) has_await = 1
          }
        }

        # Also catch LifecycleSafeMixin if added later (e.g. via a
        # separate "with" block or late mixin application — unlikely
        # but defensive).
        in_consumer && /LifecycleSafeMixin/ { has_mixin = 1 }

        END {
          if (in_consumer && has_await && !has_mixin) print class_line
        }
      ' "$file" 2>/dev/null)
    fi

    # ------------------------------------------------------------------
    # ERROR: StreamSubscription field without cancel in dispose
    #
    # Every StreamSubscription declared as a field must have a
    # corresponding .cancel() call, typically in dispose(). This
    # prevents memory leaks and orphaned listeners.
    # Skip provider/service files where subscriptions are managed
    # by the framework lifecycle (ref.onDispose, etc.).
    # ------------------------------------------------------------------
    if [[ "$file" != */providers/* ]] && [[ "$file" != */services/* ]] \
       && [[ "$file" != *_providers.dart ]] && [[ "$file" != *_service.dart ]]; then
      if grep -qE 'StreamSubscription[<\?]' "$file" 2>/dev/null; then
        if ! grep -q '\.cancel()' "$file" 2>/dev/null; then
          record_hit "$file" "1" "stream-subscription-cancel" \
            "StreamSubscription without .cancel() — cancel in dispose() to prevent leaks" "error"
        fi
      fi
    fi

    # ------------------------------------------------------------------
    # ERROR: Screen with TextField but no keyboard dismissal
    #
    # Screens (class name ending in Screen) that contain TextField or
    # TextFormField should have FocusScope.of or FocusManager to
    # dismiss the keyboard on outside taps.
    # Honors // lint-allow: keyboard-dismissal exemption.
    # ------------------------------------------------------------------
    if grep -qE 'class[[:space:]]+[A-Za-z_]+Screen[[:space:]]+extends' "$file" 2>/dev/null; then
      if grep -vE '^\s*//' "$file" 2>/dev/null | grep -qE '(TextField|TextFormField)[[:space:]]*\(' 2>/dev/null; then
        if ! grep -q 'lint-allow:.*keyboard-dismissal' "$file" 2>/dev/null; then
          # Strong check: Screen must wrap content in GestureDetector + unfocus.
          # onTapOutside alone is insufficient — it only fires when the field
          # is focused, not on general taps/scrolls elsewhere on screen.
          local has_gesture_unfocus=false
          if grep -qE 'GestureDetector' "$file" 2>/dev/null &&              grep -qE 'unfocus\(\)' "$file" 2>/dev/null; then
            has_gesture_unfocus=true
          fi
          # Also accept SearchFilterHeaderDelegate which handles its own
          # keyboard dismissal via the built-in search field.
          local has_search_delegate=false
          if grep -qE 'SearchFilterHeaderDelegate' "$file" 2>/dev/null &&              grep -qE '(GestureDetector|unfocus|onTapOutside)' "$file" 2>/dev/null; then
            has_search_delegate=true
          fi
          if [ "$has_gesture_unfocus" = false ] && [ "$has_search_delegate" = false ]; then
            record_hit "$file" "1" "keyboard-dismissal" \
              "Screen with text input but no keyboard dismissal — wrap scaffold in GestureDetector(onTap: () => FocusScope.of(context).unfocus())" "error"
          fi
        fi
      fi
    fi

    # ------------------------------------------------------------------
    # ERROR: GestureDetector onTap without haptic feedback
    #
    # Interactive elements using GestureDetector.onTap should provide
    # haptic feedback via HapticFeedback or HapticService.
    # Only checks non-comment lines. Exempt test files.
    # Honors // lint-allow: haptic-feedback exemption.
    # ------------------------------------------------------------------
    if [[ "$file" != test/* ]]; then
      if grep -vE '^\s*//' "$file" 2>/dev/null | grep -q 'GestureDetector' 2>/dev/null; then
        if grep -vE '^\s*//' "$file" 2>/dev/null | grep -q 'onTap' 2>/dev/null; then
          if ! grep -qE '(HapticFeedback\.|HapticService|haptics\.)' "$file" 2>/dev/null; then
            if ! grep -q 'lint-allow:.*haptic-feedback' "$file" 2>/dev/null; then
              record_hit "$file" "1" "haptic-feedback" \
                "GestureDetector onTap without haptic feedback — add HapticFeedback.lightImpact() or use HapticService" "error"
            fi
          fi
        fi
      fi
    fi

    # ------------------------------------------------------------------
    # ERROR: GlassScaffold.body() wrapping a scrollable widget
    #
    # GlassScaffold.body() wraps its child in SliverFillRemaining with
    # hasScrollBody: false, which forces intrinsic dimension computation.
    # Scrollable widgets (ListView, CustomScrollView, TabBarView, etc.)
    # cannot compute intrinsic dimensions — their nested viewport's
    # sliver geometry is null, causing a crash:
    #   "Null check operator used on a null value" in
    #   RenderViewportBase.layoutChildSequence during performLayout().
    #
    # Fix: use GlassScaffold(slivers: [SliverFillRemaining(
    #   hasScrollBody: true, child: scrollableWidget)]) instead.
    #
    # Uses awk to detect GlassScaffold.body( followed by a body:
    # argument whose value is a scrollable widget constructor.
    # ------------------------------------------------------------------
    while IFS= read -r hit_lineno; do
      [ -n "$hit_lineno" ] || continue
      if line_in_scope "$file" "$hit_lineno"; then
        record_hit "$file" "$hit_lineno" "no-scrollable-in-glass-body" \
          "Scrollable widget in GlassScaffold.body() — use GlassScaffold(slivers: [SliverFillRemaining(hasScrollBody: true, child: ...)]) instead" "error"
      fi
    done < <(awk '
      BEGIN { in_glass_body = 0; glass_line = 0 }

      /GlassScaffold\.body\(/ {
        in_glass_body = 1
        glass_line = NR
        next
      }

      in_glass_body && /body:[[:space:]]*(ListView|CustomScrollView|TabBarView|GridView|SingleChildScrollView|ReorderableListView|PageView|NestedScrollView)/ {
        print NR
        in_glass_body = 0
        next
      }

      # Reset if we hit a new top-level construct that clearly ends the
      # GlassScaffold.body( call (new return statement, class, or closing
      # of the enclosing build method).
      in_glass_body && /^[[:space:]]*(return |class |^\}$)/ {
        in_glass_body = 0
      }
    ' "$file" 2>/dev/null)

  fi # end whole-file checks

  # ------------------------------------------------------------------
  # ARB file checks
  # BLOCK: U+2019 (right single quotation mark "’") in ARB strings.
  # When flutter gen-l10n emits the value into a Dart string literal,
  # the analyzer raises "could be confused with U+0060 (`)" on the
  # generated file. Use ASCII apostrophe (U+0027) instead.
  # ------------------------------------------------------------------
  case "$file" in
    *.arb)
      while IFS=: read -r lineno matched_line; do
        line_in_scope "$file" "$lineno" || continue
        record_hit "$file" "$lineno" "no-smart-apostrophe" \
          "ARB contains U+2019 (’) — use ASCII apostrophe (') to keep generated Dart analyzer-clean" \
          "error"
      done < <(grep -nF $'\xe2\x80\x99' "$file" 2>/dev/null || true)
      ;;
  esac

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
    lib/l10n/app_localizations*.dart) return 0 ;;
    *.g.dart|*.freezed.dart|*.pb.dart|*.pbenum.dart|*.pbjson.dart|*.pbserver.dart) return 0 ;;
  esac

  case "$file" in
    lib/*.dart|test/*.dart)
      if [ -f "$file" ]; then
        local first_line second_line
        first_line=$(head -1 "$file" 2>/dev/null) || return 0
        second_line=$(sed -n '2p' "$file" 2>/dev/null) || second_line=""
        if [[ ! "$first_line" =~ SPDX-License-Identifier ]]; then
          record_hit "$file" "1" "spdx-missing" \
            "Missing SPDX header — add: // SPDX-License-Identifier: GPL-3.0-or-later" "error"
        fi
        if [[ ! "$second_line" =~ SPDX-FileCopyrightText ]]; then
          record_hit "$file" "2" "spdx-copyright-missing" \
            "Missing SPDX copyright — add: // SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)" "error"
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
      lib/l10n/app_localizations*.dart)
        # Generated by `flutter gen-l10n`. Formatted at generation time by
        # scripts/gen_l10n.sh, so we skip them here to avoid wasting seconds
        # re-checking large generated files on every commit.
        ;;
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

if [ $TOTAL_VIOLATIONS -gt 0 ]; then
  echo "" >&2
  local_summary="${FILES_WITH_HITS} file(s)"
  echo -e "${local_summary}, ${RED}${BOLD}${TOTAL_VIOLATIONS} error(s)${NC}" >&2
fi

if [ $TOTAL_VIOLATIONS -gt 0 ]; then
  echo -e "${RED}Commit blocked. Fix the errors above before committing.${NC}" >&2
  exit 1
fi

exit 0
