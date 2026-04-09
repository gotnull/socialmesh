#!/bin/bash

# Generate Dart protobuf files from .proto definitions
# Usage:
#   ./scripts/generate_protos.sh          # Generate from existing protos
#   ./scripts/generate_protos.sh update   # Update protos from upstream and generate
#   ./scripts/generate_protos.sh update v2.7.0  # Update to specific version

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PROTO_DIR="$PROJECT_ROOT/protos"
PROTO_REPO="https://github.com/meshtastic/protobufs"
VERSION_FILE="$PROTO_DIR/VERSION"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Function to get current version
get_current_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE" | tr -d '\n'
    else
        echo "unknown"
    fi
}

# Function to get latest version from GitHub
get_latest_version() {
    curl -s https://api.github.com/repos/meshtastic/protobufs/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/'
}

# Function to update protobufs from upstream
update_protobufs() {
    local target_version="${1:-latest}"
    local temp_dir="$PROJECT_ROOT/temp_protobufs"
    
    print_status "Fetching Meshtastic protobufs..."
    
    # Get the actual version tag if "latest" was requested
    if [ "$target_version" = "latest" ]; then
        target_version=$(get_latest_version)
        print_status "Latest version: $target_version"
    fi
    
    local current_version=$(get_current_version)
    print_status "Current version: $current_version"
    
    if [ "$current_version" = "$target_version" ]; then
        print_warning "Already at version $target_version"
        read -p "Update anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    # Cleanup any existing temp directory
    rm -rf "$temp_dir"
    
    # Clone the protobufs repo at the specified version
    print_status "Cloning protobufs at $target_version..."
    if ! git clone --depth 1 --branch "$target_version" "$PROTO_REPO" "$temp_dir" 2>/dev/null; then
        print_error "Failed to clone protobufs at version $target_version"
        print_status "Available versions can be found at: $PROTO_REPO/releases"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Backup current protos
    if [ -d "$PROTO_DIR/meshtastic" ]; then
        print_status "Backing up current protos..."
        cp -r "$PROTO_DIR/meshtastic" "$PROTO_DIR/meshtastic.backup"
    fi
    
    # Copy new proto files
    print_status "Copying proto files..."
    mkdir -p "$PROTO_DIR/meshtastic"
    cp "$temp_dir/meshtastic/"*.proto "$PROTO_DIR/meshtastic/"
    
    # Update version file
    echo "$target_version" > "$VERSION_FILE"
    
    # Cleanup
    rm -rf "$temp_dir"
    
    print_success "Protobufs updated to $target_version"
    
    # Show what changed
    if [ -d "$PROTO_DIR/meshtastic.backup" ]; then
        print_status "Changes from previous version:"
        diff -rq "$PROTO_DIR/meshtastic.backup" "$PROTO_DIR/meshtastic" 2>/dev/null || true
        rm -rf "$PROTO_DIR/meshtastic.backup"
    fi
}

# Function to check for updates
check_updates() {
    local current=$(get_current_version)
    local latest=$(get_latest_version)
    
    echo ""
    echo "📦 Meshtastic Protobufs Version Check"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Current version: $current"
    echo "  Latest version:  $latest"
    echo ""
    
    if [ "$current" = "$latest" ]; then
        print_success "You're up to date!"
    else
        print_warning "Update available!"
        echo ""
        echo "Run: ./scripts/generate_protos.sh update"
        echo "Or:  ./scripts/generate_protos.sh update $latest"
    fi
}

# Function to generate Dart files
generate_dart() {
    print_status "Generating Dart protobuf files..."
    
    # Create output directory if it doesn't exist
    mkdir -p "$PROJECT_ROOT/lib/generated"
    
    # Install protoc_plugin if not already installed
    if ! command -v protoc-gen-dart &> /dev/null; then
        print_status "Installing protoc_plugin..."
        dart pub global activate protoc_plugin
    fi
    
    # Ensure protoc is installed
    if ! command -v protoc &> /dev/null; then
        print_error "protoc is not installed."
        echo "Please install Protocol Buffers compiler:"
        echo "  macOS: brew install protobuf"
        echo "  Linux: apt-get install protobuf-compiler"
        echo "  Or visit: https://grpc.io/docs/protoc-installation/"
        exit 1
    fi
    
    # Fetch nanopb.proto if needed (required by some meshtastic protos)
    if [ ! -f "$PROTO_DIR/nanopb.proto" ]; then
        print_status "Fetching nanopb.proto..."
        curl -sL "https://raw.githubusercontent.com/nanopb/nanopb/master/generator/proto/nanopb.proto" -o "$PROTO_DIR/nanopb.proto"
    fi
    
    # Build list of proto files, excluding device-only protos that have nanopb dependencies
    # These are for firmware/device use only, not needed for client apps
    local proto_files=""
    for f in "$PROTO_DIR/meshtastic/"*.proto; do
        filename=$(basename "$f")
        # Skip device-only protos that use nanopb C++ features not compatible with Dart
        case "$filename" in
            deviceonly.proto|localonly.proto|interdevice.proto)
                print_status "Skipping $filename (device-only, not needed for client)"
                ;;
            *)
                proto_files="$proto_files $f"
                ;;
        esac
    done
    
    # Generate Dart files
    protoc \
      --dart_out="$PROJECT_ROOT/lib/generated" \
      --proto_path="$PROTO_DIR" \
      $proto_files
    
    local current_version=$(get_current_version)
    print_success "Protobuf generation complete! (version: $current_version)"
    echo "Generated files in lib/generated/"
}

# Main script logic
case "${1:-generate}" in
    update)
        update_protobufs "${2:-latest}"
        generate_dart
        ;;
    check)
        check_updates
        ;;
    generate)
        generate_dart
        ;;
    version)
        echo "$(get_current_version)"
        ;;
    help|--help|-h)
        echo "Meshtastic Protobuf Management Script"
        echo ""
        echo "Usage: $0 [command] [options]"
        echo ""
        echo "Commands:"
        echo "  generate       Generate Dart files from existing protos (default)"
        echo "  update [ver]   Update protos from upstream and generate"
        echo "                 Use 'latest' or specific version like 'v2.7.0'"
        echo "  check          Check if updates are available"
        echo "  version        Print current protobuf version"
        echo "  help           Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0                    # Generate from existing protos"
        echo "  $0 update             # Update to latest and generate"
        echo "  $0 update v2.7.0      # Update to v2.7.0 and generate"
        echo "  $0 check              # Check for available updates"
        ;;
    *)
        print_error "Unknown command: $1"
        echo "Run '$0 help' for usage information."
        exit 1
        ;;
esac
