#!/bin/bash
# ============================================================================
# Filename: stank-venv-manager.command
# Created by Nick Stankiewicz on 2026.01.04
# Ported to macOS by Claude on 2026.01.04
# Stank Python Virtual Environment Manager - macOS Launcher
#
# Double-click this file in Finder to launch the manager.
# First time: Right-click → Open to bypass Gatekeeper
#
# Copyright (C) 2026 Nick Stankiewicz
# GNU General Public License v3
# ============================================================================

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAIN_SCRIPT="$SCRIPT_DIR/stank-venv-manager.sh"

echo ""
echo "============================================================================"
echo "  STANK PYTHON VIRTUAL ENVIRONMENT MANAGER - LAUNCHER (macOS)"
echo "  Created by Nick Stankiewicz on 2026.01.04"
echo "============================================================================"
echo ""

# Check if main script exists
if [[ ! -f "$MAIN_SCRIPT" ]]; then
    echo "  [ERROR] CANNOT FIND: stank-venv-manager.sh"
    echo ""
    echo "  Make sure stank-venv-manager.sh is in the SAME folder as this .command file"
    echo "  Current folder: $SCRIPT_DIR"
    echo ""
    echo "  Press ENTER to close..."
    read -r
    exit 1
fi

# Make sure main script is executable
if [[ ! -x "$MAIN_SCRIPT" ]]; then
    echo "  [INFO] Making stank-venv-manager.sh executable..."
    chmod +x "$MAIN_SCRIPT"
fi

echo "  [OK] Found stank-venv-manager.sh"
echo ""
echo "  Command: bash $MAIN_SCRIPT"
echo ""
echo "============================================================================"
echo "  STARTING..."
echo "============================================================================"
echo ""

# Run the main script
bash "$MAIN_SCRIPT"
EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
    echo ""
    echo "============================================================================"
    echo "  [ERROR] SCRIPT FAILED (Code: $EXIT_CODE)"
    echo "============================================================================"
    echo ""
    echo "  Common fixes:"
    echo "    1. Install Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    echo "    2. Install jq: brew install jq"
    echo "    3. Install Python: brew install python@3.11"
    echo "    4. Install Xcode CLI: xcode-select --install"
    echo ""
    echo "  Press ENTER to close..."
    read -r
fi

exit $EXIT_CODE
