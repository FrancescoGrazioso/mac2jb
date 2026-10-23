# mac2jb — GUI (Graphical User Interface)

A native macOS application for **mac2jb**, designed specifically for users who prefer a graphical, foolproof interface over the command line.

## Overview

The mac2jb GUI is a lightweight, zero-dependency native Cocoa application that wraps the existing CLI tools in a friendly point-and-click interface. It lives entirely in the `gui/` directory and **does not modify any existing files** in the project.

### Key Highlights for Non-Technical Users

- **Double-Click & Go**: Double-click `Avvia mac2jb.command` in Finder to launch.
- **Visual Step-by-Step Wizard**: Explains every step in plain language (Italian/English).
- **Interactive Checklist**: Automatic preflight verification of prerequisites.
- **Port & Cable Assistant**: Guidance on connecting the Switch 2 and selecting the right USB controller.
- **Live Progress Counter**: Shows real-time line-by-line typing progress during the bootstrap transfer.
- **Safe Command Sequence**: Guided buttons for `RUN`, `REMOVE NSR,...` and `V=START(...)` with clear expectations (e.g. reassuring that "Out of memory" is normal).
- **Collapsible Activity Log**: Full console output available at any time for troubleshooting.

### Architecture

```
gui/
├── main.m                 # Native Cocoa controller (manages processes & WebKit bridge)
├── index.html             # Clean, responsive Apple-styled UI
├── build-gui.sh           # 1-second clang build script
├── Info.plist             # macOS app bundle metadata
├── README.md              # Documentation
└── Mac2jb.app/            # Compiled macOS .app bundle
    └── Contents/
        ├── Info.plist
        ├── MacOS/
        │   └── mac2jb-gui
        └── Resources/
            └── index.html
```

The top-level `Avvia mac2jb.command` file is the user-facing launcher in the project root.

## Requirements

| Requirement | Details |
|---|---|
| **macOS** | 14.0 or later |
| **Architecture** | Apple Silicon (arm64: M1, M2, M3, M4) |
| **Compiler** | Standard `clang` via Xcode CLI Tools (`xcode-select --install`) |

## Quick Start

### Option A: Double-click (recommended for end users)

1. Double-click **`Avvia mac2jb.command`** in Finder.
2. On first run, it compiles the GUI with `clang` in under a second.
3. The app window opens and the terminal window closes automatically.

### Option B: Terminal

```bash
# From the mac2jb project root:
bash gui/build-gui.sh
open gui/Mac2jb.app
```

## Integration with Existing CLI

The GUI is a **strict wrapper** — it calls the existing CLI tools (`scripts/check.sh`, `make`, `./mac2jb-send`, `scripts/host.sh`) as asynchronous subprocesses and displays their output visually:

- ✅ **Zero modifications** to `sender.c`, `commands.c`, or `Makefile`
- ✅ **100% logic parity**: Uses the exact same battle-tested C binaries and shell scripts
- ✅ **Completely optional**: CLI users are unaffected and can continue using scripts directly
- ✅ **Isolated PR**: All GUI files are contained cleanly inside `gui/` and `Avvia mac2jb.command`
