#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="${REPO_ROOT}/madmac-tests/swift-tests"
OUT_BINARY="${TEST_DIR}/run-tests"

echo "Building Swift document model tests..."

# Exclude MacmdApp.swift — test binary has its own @main in DocumentModelTests.swift
SWIFT_SOURCES=$(find "${REPO_ROOT}/madmac-app/Sources" -name '*.swift' -type f | grep -v 'MacmdApp.swift')
TEST_SOURCES=$(find "${TEST_DIR}" -name '*.swift' -type f)

swiftc \
    -target arm64-apple-macosx14.0 \
    -sdk "$(xcrun --show-sdk-path)" \
    -framework AppKit \
    -framework WebKit \
    -framework UniformTypeIdentifiers \
    -O \
    -o "${OUT_BINARY}" \
    $SWIFT_SOURCES \
    $TEST_SOURCES

echo "Build succeeded."
echo ""
echo "Running tests..."
echo ""

"${OUT_BINARY}"
