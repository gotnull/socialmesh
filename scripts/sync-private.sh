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

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PUBLIC_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
PRIVATE_REPO="$(cd "$PUBLIC_REPO/.." && pwd)/socialmesh-private"
PRIVATE_REMOTE="https://github.com/gotnull/socialmesh-private.git"

# Directories to sync (relative to repo root)
SYNC_DIRS=(
  .github
  deploy
  docs
  functions
  mesh-observer
  scripts
  sigil-api
  web
)

# Individual files to sync (relative to repo root)
SYNC_FILES=(
  .env
  .firebaserc
  firebase.json
  firestore.rules
  firestore.indexes.json
  storage.rules
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
  ".pub-cache"
  "__pycache__"
  "*.pyc"
  ".DS_Store"
  "workflows"
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

  # Sync directories
  for dir in "${SYNC_DIRS[@]}"; do
    if [ -d "$PUBLIC_REPO/$dir" ]; then
      mkdir -p "$PRIVATE_REPO/$dir"
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

  echo ""
  ok "Push complete. Now commit in the private repo:"
  echo "  cd $PRIVATE_REPO"
  echo "  git add -A && git commit -m 'sync: $(date +%Y-%m-%d)' && git push"
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
        -not -name ".DS_Store" | wc -l | tr -d ' ')
      echo -e "  ${GREEN}$dir/${NC}  ($count files)"
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
  init)   cmd_init ;;
  *)
    echo "Usage: $0 {push|pull|status|init}"
    echo ""
    echo "  init    Clone or create the private companion repo"
    echo "  push    Copy sensitive files TO private repo"
    echo "  pull    Copy sensitive files FROM private repo"
    echo "  status  Show what would be synced"
    exit 1
    ;;
esac
