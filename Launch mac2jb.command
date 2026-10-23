#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  mac2jb — Launcher
# ═══════════════════════════════════════════════════════════
#
#  Double-click this file in Finder to launch the graphical
#  mac2jb interface.
#

# Navigate to this script's directory (the mac2jb project root)
cd "$(dirname "$0")" || exit 1

# ── Remove macOS quarantine flags ────────────────────────────────────────────
xattr -cr . 2>/dev/null || true

# ── Welcome ──────────────────────────────────────────────────────────────────
clear
echo ""
echo "  mac2jb: preparing graphical interface..."
echo ""

# ── Build GUI if needed ──────────────────────────────────────────────────────
NEEDS_BUILD=false

if [ ! -d "gui/Mac2jb.app" ]; then
    NEEDS_BUILD=true
elif [ ! -f "gui/Mac2jb.app/Contents/MacOS/mac2jb-gui" ]; then
    NEEDS_BUILD=true
elif [ "gui/main.m" -nt "gui/Mac2jb.app/Contents/MacOS/mac2jb-gui" ] || [ "gui/index.html" -nt "gui/Mac2jb.app/Contents/Resources/index.html" ]; then
    NEEDS_BUILD=true
fi

if [ "${NEEDS_BUILD}" = true ]; then
    echo "  First run: compiling graphical interface..."
    echo "  (this takes less than a second)"
    echo ""
    echo "  ─────────────────────────────────────────────────"
    echo ""

    if bash gui/build-gui.sh; then
        echo ""
        echo "  ─────────────────────────────────────────────────"
        echo ""
        echo "  Build completed successfully."
        echo ""
    else
        echo ""
        echo "  ─────────────────────────────────────────────────"
        echo ""
        echo "  Error: build failed."
        echo ""
        echo "  Make sure Xcode Command Line Tools are installed:"
        echo "    xcode-select --install"
        echo ""
        echo "  Press any key to close..."
        read -n 1 -s -r
        exit 1
    fi
fi

# ── Launch the app ───────────────────────────────────────────────────────────
echo "  Launching mac2jb..."
echo ""

open gui/Mac2jb.app

# ── Close this Terminal window ───────────────────────────────────────────────
sleep 1
osascript -e 'tell application "Terminal" to close front window' 2>/dev/null &
exit 0
