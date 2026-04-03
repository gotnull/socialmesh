#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# crashlytics.sh — Query Firebase Crashlytics data via BigQuery
#
# Requires Crashlytics → BigQuery export enabled in Firebase Console:
#   https://console.firebase.google.com/project/social-mesh-app/crashlytics
#   → ⋮ menu → BigQuery integration → Enable
#
# Prerequisites:
#   - gcloud CLI authenticated: gcloud auth login
#   - bq CLI available (bundled with gcloud)
#   - BigQuery export enabled for Crashlytics
#
# Usage:
#   scripts/crashlytics.sh                     # latest 20 crashes (iOS)
#   scripts/crashlytics.sh --limit 50          # latest 50 crashes
#   scripts/crashlytics.sh --android           # Android crashes
#   scripts/crashlytics.sh --all               # both platforms
#   scripts/crashlytics.sh --since 24h         # last 24 hours
#   scripts/crashlytics.sh --since 7d          # last 7 days
#   scripts/crashlytics.sh --fatal             # only fatal crashes
#   scripts/crashlytics.sh --nonfatal          # only non-fatal exceptions
#   scripts/crashlytics.sh --search "Null"     # filter by issue title
#   scripts/crashlytics.sh --issues            # group by issue (top crashers)
#   scripts/crashlytics.sh --devices           # group by device model
#   scripts/crashlytics.sh --versions          # group by app version
#   scripts/crashlytics.sh --raw "SELECT ..."  # run arbitrary SQL
#   scripts/crashlytics.sh --check             # verify BigQuery export setup
#
# Combine flags:
#   scripts/crashlytics.sh --android --fatal --since 48h --limit 10
#   scripts/crashlytics.sh --all --issues --since 7d
#
# Environment:
#   CRASHLYTICS_PROJECT   BigQuery project (default: social-mesh-app)
#   CRASHLYTICS_DATASET   BigQuery dataset (default: firebase_crashlytics)
# ---------------------------------------------------------------------------

PROJECT="${CRASHLYTICS_PROJECT:-social-mesh-app}"
DATASET="${CRASHLYTICS_DATASET:-firebase_crashlytics}"

# BigQuery table names (discovered via `bq ls social-mesh-app:firebase_crashlytics`)
# Streaming/realtime tables use the app bundle ID format, not Firebase App ID format.
IOS_TABLE_NAME="com_gotnull_socialmesh_IOS_REALTIME"
ANDROID_TABLE_NAME="com_gotnull_socialmesh_ANDROID_REALTIME"
# Batch (daily) tables use the Firebase App ID format — these appear once daily export runs.
IOS_TABLE_NAME_BATCH="1_571509151050_ios_34008143a4671f9c515db3"
ANDROID_TABLE_NAME_BATCH="1_571509151050_android_db85cbb852c9098a515db3"

# Colours
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  DIM='\033[2m'
  RESET='\033[0m'
else
  RED='' GREEN='' YELLOW='' CYAN='' BOLD='' DIM='' RESET=''
fi

log()  { echo -e "${CYAN}[crashlytics]${RESET} $*"; }
ok()   { echo -e "${GREEN}[crashlytics] ✓${RESET} $*"; }
warn() { echo -e "${YELLOW}[crashlytics] ⚠${RESET} $*"; }
err()  { echo -e "${RED}[crashlytics] ✗${RESET} $*" >&2; }

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------

LIMIT=20
PLATFORM="ios"           # ios | android | all
SINCE=""                  # e.g. 24h, 7d, 30d
FATAL_FILTER=""           # WHERE clause fragment
SEARCH=""                 # issue_title LIKE filter
MODE="latest"             # latest | issues | devices | versions | raw | check
RAW_SQL=""

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit)
      LIMIT="$2"; shift 2 ;;
    --limit=*)
      LIMIT="${1#*=}"; shift ;;
    --ios)
      PLATFORM="ios"; shift ;;
    --android)
      PLATFORM="android"; shift ;;
    --all)
      PLATFORM="all"; shift ;;
    --since)
      SINCE="$2"; shift 2 ;;
    --since=*)
      SINCE="${1#*=}"; shift ;;
    --fatal)
      FATAL_FILTER="AND is_fatal = TRUE"; shift ;;
    --nonfatal)
      FATAL_FILTER="AND is_fatal = FALSE"; shift ;;
    --search)
      SEARCH="$2"; shift 2 ;;
    --search=*)
      SEARCH="${1#*=}"; shift ;;
    --issues)
      MODE="issues"; shift ;;
    --devices)
      MODE="devices"; shift ;;
    --versions)
      MODE="versions"; shift ;;
    --raw)
      MODE="raw"; RAW_SQL="$2"; shift 2 ;;
    --raw=*)
      MODE="raw"; RAW_SQL="${1#*=}"; shift ;;
    --check)
      MODE="check"; shift ;;
    -h|--help)
      # Print the usage block from the header comment
      sed -n '/^# Usage:/,/^# ---/p' "$0" | sed '$d' | sed -E 's/^# ?//'
      exit 0
      ;;
    *)
      err "Unknown option: $1 (use --help)"
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------

if ! command -v bq &>/dev/null; then
  err "bq CLI not found. Install Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
  exit 2
fi

if ! command -v gcloud &>/dev/null; then
  err "gcloud CLI not found. Install Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
  exit 2
fi

# Verify authentication
if ! gcloud auth print-access-token &>/dev/null 2>&1; then
  err "Not authenticated. Run: gcloud auth login"
  exit 2
fi

# ---------------------------------------------------------------------------
# Resolve table names
# ---------------------------------------------------------------------------

resolve_table() {
  local table_name="$1"
  echo "\`${PROJECT}.${DATASET}.${table_name}\`"
}

# Prefer realtime streaming tables; fall back to batch tables if needed.
# Check which tables actually exist.
pick_table() {
  local realtime="$1"
  local batch="$2"
  # Check if realtime table exists (fast — just metadata)
  if bq show --project_id="$PROJECT" "${PROJECT}:${DATASET}.${realtime}" &>/dev/null 2>&1; then
    resolve_table "$realtime"
  elif bq show --project_id="$PROJECT" "${PROJECT}:${DATASET}.${batch}" &>/dev/null 2>&1; then
    resolve_table "$batch"
  else
    resolve_table "$realtime"  # default — will produce a clear BQ error if missing
  fi
}

IOS_TABLE=$(pick_table "$IOS_TABLE_NAME" "$IOS_TABLE_NAME_BATCH")
ANDROID_TABLE=$(pick_table "$ANDROID_TABLE_NAME" "$ANDROID_TABLE_NAME_BATCH")

# Build FROM clause based on platform
build_from_clause() {
  case "$PLATFORM" in
    ios)
      echo "$IOS_TABLE"
      ;;
    android)
      echo "$ANDROID_TABLE"
      ;;
    all)
      # UNION ALL both tables with a platform column
      echo "(
        SELECT *, 'ios' AS platform FROM $IOS_TABLE
        UNION ALL
        SELECT *, 'android' AS platform FROM $ANDROID_TABLE
      )"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Check mode — verify BigQuery export is set up
# ---------------------------------------------------------------------------

if [[ "$MODE" == "check" ]]; then
  log "Checking BigQuery export setup..."
  echo ""

  # List datasets
  DATASETS=$(bq ls --project_id="$PROJECT" 2>&1 || true)
  if echo "$DATASETS" | grep -q "firebase_crashlytics"; then
    ok "Dataset ${BOLD}${DATASET}${RESET} exists"
  else
    err "Dataset ${BOLD}${DATASET}${RESET} not found!"
    echo ""
    warn "BigQuery export is not enabled. To enable:"
    echo "  1. Go to: https://console.firebase.google.com/project/${PROJECT}/crashlytics"
    echo "  2. Click the ⋮ menu → BigQuery integration"
    echo "  3. Enable the export"
    echo ""
    warn "Data will start flowing within ~30 minutes after enabling."
    exit 1
  fi

  # Check for tables (both realtime and batch)
  TABLES=$(bq ls "${PROJECT}:${DATASET}" 2>&1 || true)

  IOS_FOUND=false
  if echo "$TABLES" | grep -q "$IOS_TABLE_NAME"; then
    ok "iOS realtime table found (${IOS_TABLE_NAME})"
    IOS_FOUND=true
  elif echo "$TABLES" | grep -q "$IOS_TABLE_NAME_BATCH"; then
    ok "iOS batch table found (${IOS_TABLE_NAME_BATCH})"
    IOS_FOUND=true
  fi
  if [[ "$IOS_FOUND" == "false" ]]; then
    warn "iOS table not found (may need time to populate)"
  fi

  ANDROID_FOUND=false
  if echo "$TABLES" | grep -q "$ANDROID_TABLE_NAME"; then
    ok "Android realtime table found (${ANDROID_TABLE_NAME})"
    ANDROID_FOUND=true
  elif echo "$TABLES" | grep -q "$ANDROID_TABLE_NAME_BATCH"; then
    ok "Android batch table found (${ANDROID_TABLE_NAME_BATCH})"
    ANDROID_FOUND=true
  fi
  if [[ "$ANDROID_FOUND" == "false" ]]; then
    warn "Android table not found (may need time to populate)"
  fi

  echo ""
  ok "BigQuery export is configured. You can query crashes now."
  exit 0
fi

# ---------------------------------------------------------------------------
# Build WHERE clause
# ---------------------------------------------------------------------------

WHERE_PARTS=("1=1")

# Time filter
if [[ -n "$SINCE" ]]; then
  # Parse duration: 24h, 7d, 30d, 1h, etc.
  NUM="${SINCE//[!0-9]/}"
  UNIT="${SINCE//[0-9]/}"
  case "$UNIT" in
    h) INTERVAL_EXPR="INTERVAL $NUM HOUR" ;;
    d) INTERVAL_EXPR="INTERVAL $NUM DAY" ;;
    w) INTERVAL_EXPR="INTERVAL $((NUM * 7)) DAY" ;;
    m) INTERVAL_EXPR="INTERVAL $((NUM * 30)) DAY" ;;
    *) err "Invalid duration unit '$UNIT' in --since. Use h/d/w/m."; exit 1 ;;
  esac
  WHERE_PARTS+=("event_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), $INTERVAL_EXPR)")
fi

# Fatal filter
if [[ -n "$FATAL_FILTER" ]]; then
  WHERE_PARTS+=("${FATAL_FILTER#AND }")
fi

# Search filter
if [[ -n "$SEARCH" ]]; then
  WHERE_PARTS+=("LOWER(issue_title) LIKE LOWER('%${SEARCH}%')")
fi

WHERE_CLAUSE=""
for part in "${WHERE_PARTS[@]}"; do
  if [[ -z "$WHERE_CLAUSE" ]]; then
    WHERE_CLAUSE="WHERE $part"
  else
    WHERE_CLAUSE="$WHERE_CLAUSE AND $part"
  fi
done

FROM_CLAUSE=$(build_from_clause)

# ---------------------------------------------------------------------------
# Build and execute query
# ---------------------------------------------------------------------------

run_query() {
  local sql="$1"
  local desc="${2:-}"

  if [[ -n "$desc" ]]; then
    log "$desc"
    echo ""
  fi

  # Show query in dim text for debugging
  echo -e "${DIM}${sql}${RESET}"
  echo ""

  bq query \
    --project_id="$PROJECT" \
    --use_legacy_sql=false \
    --format=prettyjson \
    --max_rows="$LIMIT" \
    "$sql" 2>&1
}

case "$MODE" in
  # -------------------------------------------------------------------------
  latest)
    PLATFORM_COL=""
    if [[ "$PLATFORM" == "all" ]]; then
      PLATFORM_COL="platform,"
    fi

    SQL="SELECT
  event_timestamp,
  ${PLATFORM_COL}
  issue_id,
  issue_title,
  CASE WHEN is_fatal THEN '💀 FATAL' ELSE '⚡ NON-FATAL' END AS severity,
  blame_frame.file AS file,
  blame_frame.line AS line,
  blame_frame.symbol AS symbol,
  device.model AS device,
  application.display_version AS app_version,
  operating_system.display_version AS os_version
FROM ${FROM_CLAUSE}
${WHERE_CLAUSE}
ORDER BY event_timestamp DESC
LIMIT ${LIMIT}"

    run_query "$SQL" "Latest ${LIMIT} crashes (${PLATFORM})${SINCE:+ — last ${SINCE}}${SEARCH:+ — matching '${SEARCH}'}"
    ;;

  # -------------------------------------------------------------------------
  issues)
    PLATFORM_COL=""
    PLATFORM_GROUP=""
    if [[ "$PLATFORM" == "all" ]]; then
      PLATFORM_COL="platform,"
      PLATFORM_GROUP="platform,"
    fi

    SQL="SELECT
  ${PLATFORM_COL}
  issue_id,
  issue_title,
  CASE WHEN LOGICAL_OR(is_fatal) THEN '💀 FATAL' ELSE '⚡ NON-FATAL' END AS severity,
  COUNT(*) AS crash_count,
  COUNT(DISTINCT installation_uuid) AS affected_users,
  MAX(event_timestamp) AS last_seen,
  MIN(event_timestamp) AS first_seen
FROM ${FROM_CLAUSE}
${WHERE_CLAUSE}
GROUP BY ${PLATFORM_GROUP} issue_id, issue_title
ORDER BY crash_count DESC
LIMIT ${LIMIT}"

    run_query "$SQL" "Top ${LIMIT} crash issues (${PLATFORM})${SINCE:+ — last ${SINCE}}"
    ;;

  # -------------------------------------------------------------------------
  devices)
    SQL="SELECT
  device.model AS device_model,
  device.manufacturer AS manufacturer,
  operating_system.display_version AS os_version,
  COUNT(*) AS crash_count,
  COUNT(DISTINCT issue_id) AS unique_issues,
  COUNT(DISTINCT installation_uuid) AS affected_users
FROM ${FROM_CLAUSE}
${WHERE_CLAUSE}
GROUP BY device_model, manufacturer, os_version
ORDER BY crash_count DESC
LIMIT ${LIMIT}"

    run_query "$SQL" "Crashes by device (${PLATFORM})${SINCE:+ — last ${SINCE}}"
    ;;

  # -------------------------------------------------------------------------
  versions)
    SQL="SELECT
  application.display_version AS app_version,
  application.build_version AS build_number,
  COUNT(*) AS crash_count,
  SUM(CASE WHEN is_fatal THEN 1 ELSE 0 END) AS fatal_count,
  SUM(CASE WHEN NOT is_fatal THEN 1 ELSE 0 END) AS nonfatal_count,
  COUNT(DISTINCT issue_id) AS unique_issues,
  COUNT(DISTINCT installation_uuid) AS affected_users,
  MAX(event_timestamp) AS last_crash
FROM ${FROM_CLAUSE}
${WHERE_CLAUSE}
GROUP BY app_version, build_number
ORDER BY last_crash DESC
LIMIT ${LIMIT}"

    run_query "$SQL" "Crashes by app version (${PLATFORM})${SINCE:+ — last ${SINCE}}"
    ;;

  # -------------------------------------------------------------------------
  raw)
    if [[ -z "$RAW_SQL" ]]; then
      err "No SQL provided. Usage: --raw \"SELECT ...\""
      exit 1
    fi
    run_query "$RAW_SQL" "Custom query"
    ;;
esac
