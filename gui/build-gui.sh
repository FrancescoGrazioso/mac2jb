#!/bin/bash
# build-gui.sh — Build script for the native mac2jb Cocoa + WebKit GUI
#
# Usage (run from repository root):
#   bash gui/build-gui.sh

set -euo pipefail

APP_NAME="Mac2jb"
BUNDLE_DIR="gui/${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
EXECUTABLE_NAME="mac2jb-gui"
SOURCE_FILE="gui/main.m"
HTML_SOURCE="gui/index.html"
PLIST_SOURCE="gui/Info.plist"

echo "----------------------------------------------------"
echo "  mac2jb: building graphical interface (GUI)"
echo "----------------------------------------------------"
echo ""

# Check source files
if [ ! -f "${SOURCE_FILE}" ]; then
    echo "Error: ${SOURCE_FILE} not found." >&2
    exit 1
fi

if [ ! -f "${HTML_SOURCE}" ]; then
    echo "Error: ${HTML_SOURCE} not found." >&2
    exit 1
fi

# Locate macOS SDK
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
if [ -z "${SDK_PATH}" ]; then
    echo "Error: macOS SDK not found. Install Xcode Command Line Tools (xcode-select --install)" >&2
    exit 1
fi

echo "SDK: ${SDK_PATH}"
echo "Setting up .app bundle directory structure..."

rm -rf "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy resources
cp "${PLIST_SOURCE}" "${CONTENTS_DIR}/Info.plist"
cp "${HTML_SOURCE}" "${RESOURCES_DIR}/index.html"

echo "Compiling with clang..."

clang -O2 -fobjc-arc \
    -arch arm64 \
    -isysroot "${SDK_PATH}" \
    -framework Cocoa \
    -framework WebKit \
    -framework IOKit \
    "${SOURCE_FILE}" \
    -o "${MACOS_DIR}/${EXECUTABLE_NAME}"

echo "Ad-hoc code signing bundle..."
codesign -s - "${BUNDLE_DIR}"

echo ""
echo "----------------------------------------------------"
echo "  GUI build completed successfully."
echo "----------------------------------------------------"
echo ""
echo "To launch the app:"
echo "  open ${BUNDLE_DIR}"
echo ""
