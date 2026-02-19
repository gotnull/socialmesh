#!/usr/bin/env bash
# sync-private.sh -- Sync gitignored files to/from a private companion repo.
#
# Usage:
#   ./scripts/sync-private.sh push    # Copy sensitive files TO private repo
#   ./scripts/sync-private.sh pull    # Copy sensitive files FROM private repo
#   ./scripts/sync-private.sh status  # Show what would be synced
#   ./scripts/sync-private.sh init    # Clone the private repo into ../socialmesh-private
#
# The private repo lives at ../socialmesh-private (sibling directory).
# It mirrors the directory structure of the public repo for gitignored files only.
#
# Auto-deploy: When `push` detects changes in web hosting directories, it
# automatically runs `firebase deploy --only hosting:<target>` for each
# changed target. Requires the Firebase CLI to be installed and authenticated.

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PUBLIC_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
PRIVATE_REPO="${PRIVATE_REPO:-$(cd "$PUBLIC_REPO/.." && pwd)/socialmesh-private}"
PRIVATE_REMOTE="https://github.com/gotnull/socialmesh-private.git"

# Directories to sync (relative to repo root)
SYNC_DIRS=(
  .github
  backend
  docs
  scripts
  tools
  web
  web-admin-redirect
  web-bugs-redirect
  web-redirect
  web-sprints-redirect
)

# Individual files to sync (relative to repo root)
SYNC_FILES=(
  .env
  .env.ci
  .env.example
  .firebaserc
  firebase.json
  firestore.rules
  firestore.indexes.json
  storage.rules
  docker-compose.yml
  android/key.properties
  android/app/google-services.json
  ios/Runner/GoogleService-Info.plist
  android/app/upload-keystore.jks
  android/upload-keystore.jks
)

# Patterns to exclude from rsync (node_modules, build artifacts, CI workflows, etc.)
EXCLUDE_PATTERNS=(
  "node_modules"
  ".dart_tool"
  "build"
  "dist"
  ".pub-cache"
  "__pycache__"
  "*.pyc"
  ".venv"
  ".DS_Store"
  "workflows"
)

# Mapping from sync directory names to Firebase hosting target names.
# Only directories listed here trigger an auto-deploy on push.
declare -A HOSTING_TARGETS=(
  [web]="app"
  [web-redirect]="www-redirect"
  [web-admin-redirect]="admin-redirect"
  [web-bugs-redirect]="bugs-redirect"
  [web-sprints-redirect]="sprints-redirect"
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[info]${NC}  $*"; }
ok()    { echo -e "${GREEN}[ok]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC}  $*"; }
error() { echo -e "${RED}[error]${NC} $*" >&2; }

build_excludes() {
  local args=()
  for pat in "${EXCLUDE_PATTERNS[@]}"; do
    args+=(--exclude "$pat")
  done
  echo "${args[@]}"
}

check_private_repo() {
  if [ ! -d "$PRIVATE_REPO/.git" ]; then
    error "Private repo not found at $PRIVATE_REPO"
    echo ""
    echo "Run:  ./scripts/sync-private.sh init"
    echo "Or:   git clone $PRIVATE_REMOTE $PRIVATE_REPO"
    exit 1
  fi
}

# Check if a directory has changes by doing a dry-run rsync with itemized output.
# Returns 0 (true) if changes detected, 1 (false) if identical.
dir_has_changes() {
  local src="$1"
  local dst="$2"
  local excludes
  excludes=$(build_excludes)

  # shellcheck disable=SC2086
  local changes
  changes=$(rsync -a --delete --dry-run --itemize-changes $excludes "$src/" "$dst/" 2>/dev/null || true)

  [ -n "$changes" ]
}

# Check if an individual file has changes (missing or different in destination).
# Returns 0 (true) if changed, 1 (false) if identical.
file_has_changes() {
  local src="$1"
  local dst="$2"
  [ ! -f "$dst" ] || ! diff -q "$src" "$dst" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# cmd_check -- machine-readable change detection for bot consumption
# ---------------------------------------------------------------------------
# Outputs structured markers (one per line, no ANSI):
#   CHECK:DIRS:<space-separated list of changed dirs>
#   CHECK:HOSTING:<space-separated hosting targets>
#   CHECK:NO_CHANGES
#   CHECK:ERROR:<message>
cmd_check() {
  if [ ! -d "$PRIVATE_REPO/.git" ]; then
    echo "CHECK:ERROR:Private repo not found at $PRIVATE_REPO"
    exit 0
  fi

  local excludes
  excludes=$(build_excludes)
  local changed_dirs=()
  local hosting_targets=()

  # Check directories for changes
  for dir in "${SYNC_DIRS[@]}"; do
    if [ -d "$PUBLIC_REPO/$dir" ]; then
      if [ ! -d "$PRIVATE_REPO/$dir" ]; then
        # New directory -- definitely changed
        changed_dirs+=("$dir")
        if [[ -v "HOSTING_TARGETS[$dir]" ]]; then
          hosting_targets+=("hosting:${HOSTING_TARGETS[$dir]}")
        fi
      elif dir_has_changes "$PUBLIC_REPO/$dir" "$PRIVATE_REPO/$dir"; then
        changed_dirs+=("$dir")
        if [[ -v "HOSTING_TARGETS[$dir]" ]]; then
          hosting_targets+=("hosting:${HOSTING_TARGETS[$dir]}")
        fi
      fi
    fi
  done

  # Check individual files for changes
  for file in "${SYNC_FILES[@]}"; do
    if [ -f "$PUBLIC_REPO/$file" ]; then
      if file_has_changes "$PUBLIC_REPO/$file" "$PRIVATE_REPO/$file"; then
        local fdir
        fdir=$(dirname "$file")
        # Dedupe: only add if parent dir not already listed
        local already=false
        for d in "${changed_dirs[@]}"; do
          if [ "$d" = "$fdir" ] || [ "$fdir" = "." ]; then
            already=true
            break
          fi
        done
        if [ "$already" = false ]; then
          changed_dirs+=("$fdir")
        fi
        # Root-level files show as "."
        if [ "$fdir" = "." ]; then
          # Add a synthetic "root" marker if not already present
          local has_root=false
          for d in "${changed_dirs[@]}"; do
            [ "$d" = "." ] && has_root=true && break
          done
          if [ "$has_root" = false ]; then
            changed_dirs+=(".")
          fi
        fi
      fi
    fi
  done

  if [ ${#changed_dirs[@]} -eq 0 ]; then
    echo "CHECK:NO_CHANGES"
  else
    echo "CHECK:DIRS:${changed_dirs[*]}"
    if [ ${#hosting_targets[@]} -gt 0 ]; then
      echo "CHECK:HOSTING:${hosting_targets[*]}"
    fi
  fi
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

cmd_init() {
  if [ -d "$PRIVATE_REPO/.git" ]; then
    warn "Private repo already exists at $PRIVATE_REPO"
    return 0
  fi

  info "Cloning private repo to $PRIVATE_REPO ..."

  # Try cloning; if it fails (repo doesn't exist yet), create it locally
  if git clone "$PRIVATE_REMOTE" "$PRIVATE_REPO" 2>/dev/null; then
    ok "Cloned successfully"
  else
    info "Remote repo not found. Creating local repo (push to GitHub manually)."
    mkdir -p "$PRIVATE_REPO"
    cd "$PRIVATE_REPO"
    git init
    git remote add origin "$PRIVATE_REMOTE"

    # Create initial README
    cat > README.md << 'EOF'
# socialmesh-private

Private companion repo for [socialmesh](https://github.com/gotnull/socialmesh).

Contains gitignored files: environment configs, backend services, deploy configs,
signing keys, Firebase configs, and internal documentation.

Synced via `scripts/sync-private.sh` in the public repo.

## Setup on a new machine

```bash
# 1. Clone both repos side by side
git clone git@github.com:gotnull/socialmesh.git
git clone git@github.com:gotnull/socialmesh-private.git

# 2. Pull private files into the public repo working directory
cd socialmesh
./scripts/sync-private.sh pull
```

## Sync workflow

```bash
# After changing any private files, push to this repo:
./scripts/sync-private.sh push
cd ../socialmesh-private && git add -A && git commit -m "sync" && git push

# On another machine, pull updates:
cd ../socialmesh-private && git pull
cd ../socialmesh && ./scripts/sync-private.sh pull
```
EOF

    git add -A
    git commit -m "Initial commit"
    ok "Created local repo at $PRIVATE_REPO"
    echo ""
    echo "Next steps:"
    echo "  1. Create the repo on GitHub: https://github.com/new"
    echo "     Name: socialmesh-private  |  Visibility: Private"
    echo "  2. Push:  cd $PRIVATE_REPO && git push -u origin main"
  fi
}

cmd_push() {
  check_private_repo
  info "Pushing sensitive files to private repo ..."

  local excludes
  excludes=$(build_excludes)

  # Track which hosting directories changed so we can auto-deploy.
  local changed_hosting_dirs=()

  # Sync directories
  for dir in "${SYNC_DIRS[@]}"; do
    if [ -d "$PUBLIC_REPO/$dir" ]; then
      mkdir -p "$PRIVATE_REPO/$dir"

      # Detect changes before syncing (for hosting auto-deploy).
      if [[ -v "HOSTING_TARGETS[$dir]" ]]; then
        if dir_has_changes "$PUBLIC_REPO/$dir" "$PRIVATE_REPO/$dir"; then
          changed_hosting_dirs+=("$dir")
        fi
      fi

      # shellcheck disable=SC2086
      rsync -a --delete $excludes "$PUBLIC_REPO/$dir/" "$PRIVATE_REPO/$dir/"
      ok "  $dir/"
    else
      warn "  $dir/ (not found, skipping)"
    fi
  done

  # Sync individual files
  for file in "${SYNC_FILES[@]}"; do
    if [ -f "$PUBLIC_REPO/$file" ]; then
      mkdir -p "$PRIVATE_REPO/$(dirname "$file")"
      cp "$PUBLIC_REPO/$file" "$PRIVATE_REPO/$file"
      ok "  $file"
    else
      warn "  $file (not found, skipping)"
    fi
  done

  # ---------------------------------------------------------------------------
  # Auto-deploy changed hosting targets
  # ---------------------------------------------------------------------------

  local deployed_targets=()
  local deploy_failed=false

  if [ ${#changed_hosting_dirs[@]} -gt 0 ]; then
    echo ""

    # Check for Firebase CLI
    if ! command -v firebase &>/dev/null; then
      warn "Firebase CLI not found. Skipping auto-deploy for changed hosting targets:"
      for dir in "${changed_hosting_dirs[@]}"; do
        local target="${HOSTING_TARGETS[$dir]}"
        warn "  hosting:$target ($dir/)"
      done
      echo ""
      warn "Install Firebase CLI and run manually:"
      # Build the --only flag for all targets
      local manual_targets=()
      for dir in "${changed_hosting_dirs[@]}"; do
        manual_targets+=("hosting:${HOSTING_TARGETS[$dir]}")
      done
      local joined
      joined=$(IFS=,; echo "${manual_targets[*]}")
      warn "  firebase deploy --only $joined"
    else
      # Build the list of hosting targets to deploy
      local deploy_targets=()
      for dir in "${changed_hosting_dirs[@]}"; do
        deploy_targets+=("hosting:${HOSTING_TARGETS[$dir]}")
      done
      local deploy_spec
      deploy_spec=$(IFS=,; echo "${deploy_targets[*]}")

      info "Web hosting changes detected. Deploying: $deploy_spec"

      if (cd "$PUBLIC_REPO" && firebase deploy --only "$deploy_spec" 2>&1); then
        for dir in "${changed_hosting_dirs[@]}"; do
          deployed_targets+=("${HOSTING_TARGETS[$dir]}")
          ok "  Deployed hosting:${HOSTING_TARGETS[$dir]} ($dir/)"
        done
      else
        deploy_failed=true
        error "Firebase deploy failed. Deploy manually after committing:"
        error "  cd $PUBLIC_REPO"
        error "  firebase deploy --only $deploy_spec"
      fi
    fi
  fi

  # ---------------------------------------------------------------------------
  # Final summary
  # ---------------------------------------------------------------------------

  echo ""

  if [ ${#deployed_targets[@]} -gt 0 ]; then
    local target_list
    target_list=$(IFS=', '; echo "${deployed_targets[*]}")
    ok "Push complete. Firebase hosting deployed: $target_list"
    echo ""
    ok "Now commit in the private repo (deploy already done):"
    echo "  cd $PRIVATE_REPO"
    echo "  git add -A && git commit -m 'sync: $(date +%Y-%m-%d) (deployed $target_list)' && git push"
  elif [ "$deploy_failed" = true ]; then
    ok "Push complete. Firebase deploy FAILED -- retry manually before committing."
    echo "  cd $PRIVATE_REPO"
    echo "  git add -A && git commit -m 'sync: $(date +%Y-%m-%d)' && git push"
  else
    ok "Push complete. Now commit in the private repo:"
    echo "  cd $PRIVATE_REPO"
    echo "  git add -A && git commit -m 'sync: $(date +%Y-%m-%d)' && git push"
  fi
}

cmd_pull() {
  check_private_repo
  info "Pulling sensitive files from private repo ..."

  local excludes
  excludes=$(build_excludes)

  # Sync directories
  for dir in "${SYNC_DIRS[@]}"; do
    if [ -d "$PRIVATE_REPO/$dir" ]; then
      mkdir -p "$PUBLIC_REPO/$dir"
      # shellcheck disable=SC2086
      rsync -a $excludes "$PRIVATE_REPO/$dir/" "$PUBLIC_REPO/$dir/"
      ok "  $dir/"
    else
      warn "  $dir/ (not in private repo, skipping)"
    fi
  done

  # Sync individual files
  for file in "${SYNC_FILES[@]}"; do
    if [ -f "$PRIVATE_REPO/$file" ]; then
      mkdir -p "$PUBLIC_REPO/$(dirname "$file")"
      cp "$PRIVATE_REPO/$file" "$PUBLIC_REPO/$file"
      ok "  $file"
    else
      warn "  $file (not in private repo, skipping)"
    fi
  done

  echo ""
  ok "Pull complete. Private files restored to working directory."
}

cmd_status() {
  info "Sensitive files that would be synced:"
  echo ""

  echo "Directories:"
  for dir in "${SYNC_DIRS[@]}"; do
    if [ -d "$PUBLIC_REPO/$dir" ]; then
      local count
      count=$(find "$PUBLIC_REPO/$dir" -type f \
        -not -path "*/node_modules/*" \
        -not -path "*/.dart_tool/*" \
        -not -path "*/build/*" \
        -not -path "*/__pycache__/*" \
        -not -path "*/.venv/*" \
        -not -name "*.pyc" \
        -not -name ".DS_Store" | wc -l | tr -d ' ')

      local suffix=""
      if [[ -v "HOSTING_TARGETS[$dir]" ]]; then
        suffix="  -> hosting:${HOSTING_TARGETS[$dir]}"
      fi

      echo -e "  ${GREEN}$dir/${NC}  ($count files)$suffix"
    else
      echo -e "  ${YELLOW}$dir/${NC}  (missing)"
    fi
  done

  echo ""
  echo "Files:"
  for file in "${SYNC_FILES[@]}"; do
    if [ -f "$PUBLIC_REPO/$file" ]; then
      echo -e "  ${GREEN}$file${NC}"
    else
      echo -e "  ${YELLOW}$file${NC}  (missing)"
    fi
  done

  # Show pending hosting changes if private repo exists
  if [ -d "$PRIVATE_REPO/.git" ]; then
    echo ""

    local pending_deploys=()
    local excludes
    excludes=$(build_excludes)

    for dir in "${!HOSTING_TARGETS[@]}"; do
      if [ -d "$PUBLIC_REPO/$dir" ] && [ -d "$PRIVATE_REPO/$dir" ]; then
        if dir_has_changes "$PUBLIC_REPO/$dir" "$PRIVATE_REPO/$dir"; then
          pending_deploys+=("hosting:${HOSTING_TARGETS[$dir]} ($dir/)")
        fi
      elif [ -d "$PUBLIC_REPO/$dir" ] && [ ! -d "$PRIVATE_REPO/$dir" ]; then
        pending_deploys+=("hosting:${HOSTING_TARGETS[$dir]} ($dir/) [new]")
      fi
    done

    if [ ${#pending_deploys[@]} -gt 0 ]; then
      echo -e "${YELLOW}Pending hosting deploys (will auto-deploy on push):${NC}"
      for item in "${pending_deploys[@]}"; do
        echo -e "  ${YELLOW}$item${NC}"
      done
    else
      echo "No pending hosting changes."
    fi
  fi

  echo ""
  if [ -d "$PRIVATE_REPO/.git" ]; then
    ok "Private repo: $PRIVATE_REPO"
    cd "$PRIVATE_REPO"
    echo "  Last commit: $(git log -1 --format='%h %s (%cr)' 2>/dev/null || echo 'none')"
  else
    warn "Private repo not initialized. Run: ./scripts/sync-private.sh init"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

case "${1:-help}" in
  push)   cmd_push ;;
  pull)   cmd_pull ;;
  status) cmd_status ;;
  check)  cmd_check ;;
  init)   cmd_init ;;
  *)
    echo "Usage: $0 {push|pull|status|check|init}"
    echo ""
    echo "  init    Clone or create the private companion repo"
    echo "  push    Copy sensitive files TO private repo (auto-deploys changed hosting)"
    echo "  pull    Copy sensitive files FROM private repo"
    echo "  status  Show what would be synced (and pending hosting deploys)"
    echo "  check   Machine-readable change detection (for bot/CI consumption)"
    exit 1
    ;;
esac
