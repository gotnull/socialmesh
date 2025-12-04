#!/bin/bash

# Generate Dart protobuf files from .proto definitions

set -e

echo "🔧 Generating Dart protobuf files..."

# Create output directory if it doesn't exist
mkdir -p lib/generated

# Install protoc_plugin if not already installed
if ! command -v protoc-gen-dart &> /dev/null; then
    echo "Installing protoc_plugin..."
    dart pub global activate protoc_plugin
fi

# Ensure protoc is installed
if ! command -v protoc &> /dev/null; then
    echo "❌ Error: protoc is not installed."
    echo "Please install Protocol Buffers compiler:"
    echo "  macOS: brew install protobuf"
    echo "  Linux: apt-get install protobuf-compiler"
    echo "  Or visit: https://grpc.io/docs/protoc-installation/"
    exit 1
fi

# Generate Dart files
protoc \
  --dart_out=lib/generated \
  --proto_path=protos \
  protos/meshtastic/*.proto

echo "✅ Protobuf generation complete!"
echo "Generated files in lib/generated/"
