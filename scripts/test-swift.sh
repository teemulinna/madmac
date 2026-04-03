#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="${REPO_ROOT}/macmd-tests/swift-tests"
OUT_BINARY="${TEST_DIR}/run-tests"

echo "Building Swift document model tests..."

swiftc \
    -target arm64-apple-macosx14.0 \
    -sdk "$(xcrun --show-sdk-path)" \
    -framework AppKit \
    -framework WebKit \
    -framework UniformTypeIdentifiers \
    -O \
    -o "${OUT_BINARY}" \
    "${REPO_ROOT}/macmd-app/Sources/Document/MarkdownDocument.swift" \
    "${REPO_ROOT}/macmd-app/Sources/Editor/EditorViewController.swift" \
    "${TEST_DIR}/DocumentModelTests.swift"

echo "Build succeeded."
echo ""
echo "Running tests..."
echo ""

"${OUT_BINARY}"
