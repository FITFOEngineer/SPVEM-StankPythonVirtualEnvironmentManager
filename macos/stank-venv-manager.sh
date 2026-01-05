#!/bin/bash
# ============================================================================
# Filename: stank-venv-manager.sh
# Created by Nick Stankiewicz on 2026.01.04
# Updated: 2026.01.04 - Version 0.1 (Beta)
# Stank Python Virtual Environment Manager v0.1 for macOS
#
# Copyright (C) 2026 Nick Stankiewicz
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3 of the License.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
# ============================================================================
#
# DESCRIPTION:
#   A verbose, beginner-friendly Python virtual environment manager designed
#   for macOS and Apple Silicon. Creates isolated Python environments with
#   pre-configured package sets for various professional roles.
#
# FEATURES:
#   - 9 pre-configured job roles (Data Scientist, ML Engineer, etc.)
#   - 31 package sets with 315 curated packages
#   - Apple Silicon GPU acceleration (PyTorch MPS, TensorFlow Metal, MLX)
#   - JupyterLab integration with automatic browser launch
#   - Session resume (press Enter to continue where you left off)
#   - Detailed progress feedback and error handling
#   - Safe by design: NEVER deletes files or environments
#
# REQUIREMENTS:
#   - macOS 13+ (Ventura, Sonoma, Sequoia)
#   - Python 3.11+ (3.11 recommended for best compatibility)
#   - Homebrew (for jq and Python installation)
#   - jq (JSON parser) - brew install jq
#
# USAGE:
#   First time:
#     chmod +x stank-venv-manager.sh
#     xattr -d com.apple.quarantine stank-venv-manager.sh  # Bypass Gatekeeper
#     ./stank-venv-manager.sh
#
#   Subsequent runs:
#     ./stank-venv-manager.sh
#     # Press Enter to resume last session (default behavior)
#
# FILES:
#   ~/.venvs/                    - Virtual environments
#   ~/JupyterProjects/           - Your work (notebooks, data, outputs)
#   stank-venv-packages-macos.json - Package definitions (same folder)
#
# ============================================================================

# ============================================================================
# CONFIGURATION
# All paths and settings are defined here for easy customization
# ============================================================================

# Where virtual environments are stored (hidden folder in home directory)
VENV_DIR="$HOME/.venvs"

# Where project files (notebooks, data) are stored - SEPARATE from environments
# This keeps your work safe even if you delete an environment
PROJECTS_DIR="$HOME/JupyterProjects"

# Tracks the last used environment for quick resume
STATE_FILE="$HOME/.venvs/.last-session.json"

# Directory where this script is located (used to find config files)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# JSON file containing package sets and job role definitions
PACKAGES_FILE="$SCRIPT_DIR/stank-venv-packages-macos.json"

# JSON file containing package descriptions (glossary)
GLOSSARY_FILE="$SCRIPT_DIR/stank-venv-glossary.json"

# Associative array cache for glossary lookups (populated by load_glossary)
# This avoids calling jq for each package during installation
declare -A GLOSSARY_CACHE
GLOSSARY_LOADED=false

# Python command - will be auto-detected (python3.11, python3.12, python3, etc.)
# Python 3.11 is preferred for maximum package compatibility
PYTHON_CMD=""

# Minimum free disk space required before warning (in GB)
MIN_DISK_GB=2

# How many times to retry a failed package installation
RETRY_ATTEMPTS=3

# Seconds to wait between retry attempts
RETRY_DELAY_SEC=5

# Package config is loaded from JSON via jq (a JSON parsing tool)

# ============================================================================
# COLOR DEFINITIONS (ANSI escape codes)
# These make terminal output colorful and easier to read
# NC = No Color (resets to default)
# ============================================================================

RED='\033[0;31m'      # Errors
GREEN='\033[0;32m'    # Success messages
YELLOW='\033[0;33m'   # Warnings and prompts
BLUE='\033[0;34m'     # (unused, available)
MAGENTA='\033[0;35m'  # "WHY" explanations
CYAN='\033[0;36m'     # Headers and commands
WHITE='\033[1;37m'    # Important text
GRAY='\033[0;90m'     # Subtle/secondary info
NC='\033[0m'          # Reset to default color

# ============================================================================
# LOGGING FUNCTIONS
# These provide consistent, colorful output throughout the script
# Each function serves a specific purpose for user feedback
#
# write_section() - Major section header (cyan banner)
# write_step()    - Numbered step header (yellow)
# write_why()     - Explanation of purpose (magenta)
# write_command() - Show command being run (cyan + white)
# write_ok()      - Success message (green)
# write_err()     - Error message (red)
# write_warn()    - Warning message (yellow)
# write_info()    - Informational note (gray)
# write_detail()  - Indented detail (gray)
# write_progress()     - Working indicator (yellow, no newline)
# write_progress_done() - Completion status (green)
# pause_prompt()  - Wait for user to press Enter
# confirm_action() - Yes/No prompt, returns 0 for yes
# ============================================================================

# Display a major section header (cyan banner)
write_section() {
    local title="$1"
    echo ""
    echo -e "${CYAN}$(printf '=%.0s' {1..78})${NC}"
    echo -e "${CYAN}  $title${NC}"
    echo -e "${CYAN}$(printf '=%.0s' {1..78})${NC}"
    echo ""
}

write_step() {
    local num="$1"
    local title="$2"
    echo ""
    echo -e "${YELLOW}  STEP $num : $title${NC}"
    echo -e "${GRAY}  $(printf -- '-%.0s' {1..72})${NC}"
}

write_why() {
    echo -e "${MAGENTA}  WHY: $1${NC}"
}

write_command() {
    echo ""
    echo -e "${CYAN}  RUNNING:${NC}"
    echo -e "${WHITE}  > $1${NC}"
    echo ""
}

write_ok() {
    echo -e "${GREEN}  [OK] $1${NC}"
}

write_err() {
    echo -e "${RED}  [ERROR] $1${NC}"
}

write_warn() {
    echo -e "${YELLOW}  [WARNING] $1${NC}"
}

write_info() {
    echo -e "${GRAY}  [INFO] $1${NC}"
}

write_detail() {
    echo -e "${GRAY}         $1${NC}"
}

write_progress() {
    echo -ne "${YELLOW}  [WORKING] $1${NC}"
}

write_progress_done() {
    echo -e " ${GREEN}${1:-Done!}${NC}"
}

pause_prompt() {
    echo ""
    echo -ne "${GRAY}  Press ENTER to continue...${NC}"
    read -r
}

confirm_action() {
    local prompt="$1"
    echo ""
    echo -ne "    $prompt [y/N] "
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

# ============================================================================
# INPUT VALIDATION
# Functions to sanitize and validate user input for safety and consistency
# ============================================================================

# Sanitize environment name: remove dangerous chars, replace spaces with dashes
# Input: raw user input
# Output: safe environment name (lowercase, alphanumeric + dashes only)
# Example: "My Test Env!" -> "my-test-env"
sanitize_env_name() {
    local raw="$1"
    local clean

    # Trim leading/trailing whitespace
    clean=$(echo "$raw" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Convert to lowercase
    clean=$(echo "$clean" | tr '[:upper:]' '[:lower:]')

    # Replace spaces and underscores with dashes
    clean=$(echo "$clean" | tr ' _' '--')

    # Remove all characters except alphanumeric and dashes
    clean=$(echo "$clean" | tr -cd 'a-z0-9-')

    # Collapse multiple dashes to single dash
    clean=$(echo "$clean" | tr -s '-')

    # Remove leading/trailing dashes
    clean=$(echo "$clean" | sed 's/^-*//;s/-*$//')

    # Truncate to 64 chars max (filesystem safety)
    clean="${clean:0:64}"

    echo "$clean"
}

# Validate that a string is a valid environment name
# Returns: 0 if valid, 1 if invalid
# Prints error message if invalid
validate_env_name() {
    local name="$1"

    if [[ -z "$name" ]]; then
        write_err "Environment name cannot be empty"
        return 1
    fi

    if [[ ${#name} -lt 2 ]]; then
        write_err "Environment name must be at least 2 characters"
        return 1
    fi

    if [[ ${#name} -gt 64 ]]; then
        write_err "Environment name cannot exceed 64 characters"
        return 1
    fi

    if [[ ! "$name" =~ ^[a-z0-9] ]]; then
        write_err "Environment name must start with a letter or number"
        return 1
    fi

    if [[ ! "$name" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$ ]]; then
        write_err "Environment name can only contain lowercase letters, numbers, and dashes"
        return 1
    fi

    return 0
}

# Validate numeric input within a range
# Usage: validate_numeric_range "$input" 1 10
# Returns: 0 if valid, 1 if invalid
validate_numeric_range() {
    local input="$1"
    local min="$2"
    local max="$3"

    if [[ ! "$input" =~ ^[0-9]+$ ]]; then
        return 1
    fi

    if [[ "$input" -lt "$min" ]] || [[ "$input" -gt "$max" ]]; then
        return 1
    fi

    return 0
}

# ============================================================================
# DEPENDENCY CHECKS
# These functions verify that required tools are installed before proceeding
# They offer to install missing tools when possible
# ============================================================================

# Check if 'jq' is installed (required for parsing JSON config files)
# Offers to install via Homebrew if missing
# Returns: 0 if jq available, 1 if not and user declined install
check_jq() {
    if ! command -v jq &> /dev/null; then
        write_warn "jq not found (needed for JSON parsing)"
        echo ""
        echo -e "  ${CYAN}Install with:${NC}"
        echo -e "  ${WHITE}  brew install jq${NC}"
        echo ""
        if confirm_action "Attempt to install jq via Homebrew?"; then
            if command -v brew &> /dev/null; then
                brew install jq
                write_ok "jq installed"
            else
                write_err "Homebrew not found. Install jq manually."
                return 1
            fi
        else
            write_err "jq is required. Exiting."
            return 1
        fi
    fi
    return 0
}

# Check if Xcode Command Line Tools are installed
# These provide compilers needed to build some Python packages from source
# Offers to install if missing (triggers macOS installer dialog)
check_xcode_cli() {
    if ! xcode-select -p &> /dev/null; then
        write_warn "Xcode Command Line Tools not found"
        echo ""
        echo -e "  ${CYAN}Some packages require compilation tools.${NC}"
        if confirm_action "Install Xcode Command Line Tools?"; then
            xcode-select --install
            write_info "A dialog should appear. Complete the installation, then restart this script."
            exit 0
        fi
    fi
}

# Detect if running on Apple Silicon (ARM64) or Intel (x86_64)
# Apple Silicon Macs use the arm64 architecture and benefit from native packages
# Returns: 0 always (just informational)
detect_architecture() {
    local arch
    arch=$(uname -m)
    if [[ "$arch" == "arm64" ]]; then
        write_ok "Apple Silicon detected (ARM64)"
        return 0
    elif [[ "$arch" == "x86_64" ]]; then
        write_info "Intel Mac detected (x86_64)"
        return 0
    else
        write_warn "Unknown architecture: $arch"
        return 1
    fi
}

# Detect Homebrew installation location and add to PATH
# Apple Silicon Macs: /opt/homebrew
# Intel Macs: /usr/local
# This ensures 'brew' and Homebrew-installed tools are available
# Sets HOMEBREW_PREFIX global variable for use elsewhere
HOMEBREW_PREFIX=""

detect_homebrew() {
    if [[ -x "/opt/homebrew/bin/brew" ]]; then
        # Apple Silicon
        HOMEBREW_PREFIX="/opt/homebrew"
        export PATH="$HOMEBREW_PREFIX/bin:$PATH"
        write_ok "Homebrew found at $HOMEBREW_PREFIX (Apple Silicon)"
    elif [[ -x "/usr/local/bin/brew" ]]; then
        # Intel
        HOMEBREW_PREFIX="/usr/local"
        export PATH="$HOMEBREW_PREFIX/bin:$PATH"
        write_ok "Homebrew found at $HOMEBREW_PREFIX (Intel)"
    else
        write_warn "Homebrew not found"
        echo ""
        echo -e "  ${CYAN}Install with:${NC}"
        echo -e "  ${WHITE}  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"${NC}"
        echo ""
    fi
}

# ============================================================================
# VALIDATION FUNCTIONS
# Pre-flight checks to ensure the system is ready for operations
# These prevent failures partway through installations
# ============================================================================

# Test internet connectivity by checking if pypi.org is reachable
# All package installations require network access to PyPI
# Returns: 0 if network OK, 1 if unreachable
test_network() {
    write_info "Checking network connectivity..."
    if curl -Is --max-time 5 https://pypi.org | head -n 1 | grep -q "200\|301\|302"; then
        write_ok "Network OK (pypi.org reachable)"
        return 0
    else
        write_err "Cannot reach pypi.org"
        write_detail "Check your internet connection"
        return 1
    fi
}

# Check available disk space on the home directory volume
# Parameters:
#   $1 - Required free space in GB (defaults to MIN_DISK_GB)
# Returns: 0 if enough space, 1 if low
test_disk_space() {
    local required_gb="${1:-$MIN_DISK_GB}"
    write_info "Checking disk space..."

    # Get free space in GB (macOS df output)
    local free_gb
    free_gb=$(df -g "$HOME" | awk 'NR==2 {print $4}')

    if [[ "$free_gb" -lt "$required_gb" ]]; then
        write_err "Low disk space: ${free_gb}GB free (need ${required_gb}GB)"
        return 1
    fi
    write_ok "Disk space OK: ${free_gb}GB free"
    return 0
}

get_folder_size() {
    local path="$1"
    if [[ -d "$path" ]]; then
        du -sh "$path" 2>/dev/null | cut -f1
    else
        echo "0"
    fi
}

# ============================================================================
# PYTHON DETECTION
# Finds a suitable Python 3.11+ installation
# Checks multiple common locations and verifies version requirements
# Also validates that pip and venv modules are available
# ============================================================================

# Find and validate Python installation
# PREFERS Python 3.11 for maximum package compatibility
# Python 3.11 is the "sweet spot" - mature, stable, widely supported
# Python 3.12+ has compatibility issues with some packages (distutils removed, etc.)
# Searches for: python3.11, python3.12, python3, python (3.11 first!)
# Sets PYTHON_CMD global variable on success
# Offers to install Python 3.11 via Homebrew if not found
# Returns: 0 if suitable Python found/installed, 1 if not
detect_python() {
    write_section "CHECKING PYTHON INSTALLATION"
    write_info "Preferring Python 3.11 for maximum package compatibility"

    # IMPORTANT: python3.11 FIRST for best compatibility
    local candidates=("python3.11" "python3.12" "python3" "python")
    local found=""
    local found_version=""

    for cmd in "${candidates[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            local version
            version=$("$cmd" --version 2>&1)
            if [[ "$version" =~ Python\ 3\.(1[1-9]|[2-9][0-9]) ]]; then
                found="$cmd"
                found_version=$(echo "$version" | grep -oE '3\.[0-9]+')
                break
            fi
        fi
    done

    if [[ -z "$found" ]]; then
        write_err "Python 3.11+ not found"
        echo ""
        echo -e "  ${CYAN}Python 3.11 is required (recommended for compatibility).${NC}"
        echo ""

        # Check if Homebrew is available and offer to install
        if command -v brew &> /dev/null; then
            echo -e "  ${GREEN}Homebrew detected!${NC}"
            echo ""
            if confirm_action "Install Python 3.11 via Homebrew? (recommended)"; then
                write_progress "Installing Python 3.11..."
                echo ""
                if brew install python@3.11 2>&1; then
                    write_progress_done
                    write_ok "Python 3.11 installed"
                    echo ""

                    # Add to PATH for this session (uses detected Homebrew prefix)
                    local brew_python_path="${HOMEBREW_PREFIX:-/opt/homebrew}/opt/python@3.11/bin"
                    export PATH="$brew_python_path:$PATH"

                    # Re-check for Python
                    for cmd in "python3.11" "python3" "python"; do
                        if command -v "$cmd" &> /dev/null; then
                            local version
                            version=$("$cmd" --version 2>&1)
                            if [[ "$version" =~ Python\ 3\.(1[1-9]|[2-9][0-9]) ]]; then
                                found="$cmd"
                                found_version=$(echo "$version" | grep -oE '3\.[0-9]+')
                                break
                            fi
                        fi
                    done

                    if [[ -z "$found" ]]; then
                        write_warn "Python installed but not in PATH"
                        echo ""
                        local brew_python_path="${HOMEBREW_PREFIX:-/opt/homebrew}/opt/python@3.11/bin"
                        echo -e "  ${YELLOW}Add this to your ~/.zshrc or ~/.bash_profile:${NC}"
                        echo -e "  ${WHITE}  export PATH=\"$brew_python_path:\$PATH\"${NC}"
                        echo ""
                        echo -e "  ${YELLOW}Then restart Terminal or run:${NC}"
                        echo -e "  ${WHITE}  source ~/.zshrc${NC}"
                        echo ""
                        return 1
                    fi
                else
                    write_progress_done "FAILED"
                    write_err "Homebrew installation failed"
                    return 1
                fi
            else
                echo ""
                echo -e "  ${CYAN}Manual install options:${NC}"
                echo -e "  ${WHITE}  brew install python@3.11${NC}        # Recommended"
                echo -e "  ${WHITE}  brew install python@3.12${NC}        # Also works"
                echo -e "  ${WHITE}  https://www.python.org/downloads/${NC}  # Official installer"
                echo ""
                return 1
            fi
        else
            echo -e "  ${CYAN}Install options:${NC}"
            echo -e "  ${WHITE}  brew install python@3.11${NC}        # Recommended (install Homebrew first)"
            echo -e "  ${WHITE}  https://www.python.org/downloads/${NC}  # Official installer"
            echo ""
            echo -e "  ${GRAY}Install Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"${NC}"
            echo ""
            return 1
        fi
    fi

    PYTHON_CMD="$found"
    local py_version py_path
    py_version=$("$PYTHON_CMD" --version 2>&1)
    py_path=$(which "$PYTHON_CMD")

    write_ok "Python found: $py_version"
    write_detail "Path: $py_path"

    # Warn if using 3.12+ (some packages may have issues)
    if [[ "$found_version" == "3.12" ]] || [[ "$found_version" > "3.12" ]]; then
        write_warn "Using Python $found_version - some packages may have compatibility issues"
        write_detail "Python 3.11 is recommended for maximum compatibility"
        write_detail "Install with: brew install python@3.11"
    fi

    # Check architecture
    local py_arch
    py_arch=$("$PYTHON_CMD" -c "import platform; print(platform.machine())")
    if [[ "$py_arch" == "arm64" ]]; then
        write_ok "Python running native ARM64"
    elif [[ "$py_arch" == "x86_64" ]] && [[ "$(uname -m)" == "arm64" ]]; then
        write_warn "Python running under Rosetta 2 (x86_64 emulation)"
        write_detail "Consider installing ARM64 native Python for better performance"
    fi

    # Check pip
    if "$PYTHON_CMD" -m pip --version &> /dev/null; then
        write_ok "pip available"
    else
        write_warn "pip not available"
    fi

    # Check venv
    if "$PYTHON_CMD" -c "import venv" &> /dev/null; then
        write_ok "venv module available"
    else
        write_err "venv module not available"
        return 1
    fi

    return 0
}

# ============================================================================
# JSON CONFIGURATION LOADER
# Loads package definitions and job roles from external JSON file
# This allows customization without editing the script
# Falls back to built-in defaults if JSON file is missing or invalid
# ============================================================================

# Load and validate the JSON configuration file
# Sets PACKAGES_FILE to valid config path
# Returns: 0 on success, 1 if no valid config (will use defaults)
load_package_config() {
    if [[ ! -f "$PACKAGES_FILE" ]]; then
        # Try fallback to non-macos version
        local fallback="$SCRIPT_DIR/stank-venv-packages.json"
        if [[ -f "$fallback" ]]; then
            PACKAGES_FILE="$fallback"
            write_warn "Using fallback config: $fallback"
        else
            write_warn "Package config not found: $PACKAGES_FILE"
            write_detail "Using built-in defaults"
            return 1
        fi
    fi

    if ! jq empty "$PACKAGES_FILE" 2>/dev/null; then
        write_err "Invalid JSON in config file"
        write_detail "Check for syntax errors"
        return 1
    fi

    local set_count role_count
    set_count=$(jq '.package_sets | length' "$PACKAGES_FILE")
    role_count=$(jq '.job_roles | length' "$PACKAGES_FILE")

    write_ok "Loaded config: $set_count package sets, $role_count job roles"
    return 0
}

# Load and validate the glossary file (optional - provides package descriptions)
# If missing, package installs will work but won't show descriptions
# Populates GLOSSARY_CACHE associative array for fast lookups
load_glossary() {
    if [[ ! -f "$GLOSSARY_FILE" ]]; then
        write_info "Glossary not found (package descriptions unavailable)"
        write_detail "Expected: $GLOSSARY_FILE"
        return 1
    fi

    if ! jq empty "$GLOSSARY_FILE" 2>/dev/null; then
        write_warn "Invalid JSON in glossary file"
        return 1
    fi

    # Load all package descriptions into cache (one jq call instead of hundreds)
    # Uses tab delimiter to avoid issues with special characters in descriptions
    write_progress "Loading package descriptions..."
    local pkg_data
    pkg_data=$(jq -r '.packages | to_entries[] | "\(.key)\t\(.value.description // "")"' "$GLOSSARY_FILE" 2>/dev/null)

    local count=0
    while IFS=$'\t' read -r pkg_name pkg_desc; do
        if [[ -n "$pkg_name" ]]; then
            GLOSSARY_CACHE["$pkg_name"]="$pkg_desc"
            ((count++))
        fi
    done <<< "$pkg_data"

    GLOSSARY_LOADED=true
    write_progress_done
    write_ok "Loaded glossary: $count package descriptions (cached)"
    return 0
}

# Get list of packages in a specific package set
# Falls back to hardcoded defaults if JSON not available
# Parameters: $1 - Set name (e.g., "jupyter", "data_science")
# Returns: One package name per line
get_package_set() {
    local set_name="$1"
    if [[ -f "$PACKAGES_FILE" ]]; then
        jq -r ".package_sets.${set_name}.packages // [] | .[]" "$PACKAGES_FILE" 2>/dev/null
    else
        # Fallback defaults
        case "$set_name" in
            jupyter) echo -e "jupyterlab\nnotebook\nipykernel\nipywidgets" ;;
            data_science) echo -e "numpy\npandas\nmatplotlib\nseaborn\nscikit-learn\nscipy" ;;
        esac
    fi
}

# Get list of package sets for a job role
# Parameters: $1 - Role name (e.g., "data_scientist")
# Returns: One set name per line
get_job_role_sets() {
    local role_name="$1"
    if [[ -f "$PACKAGES_FILE" ]]; then
        jq -r ".job_roles.${role_name}.sets // [] | .[]" "$PACKAGES_FILE" 2>/dev/null
    fi
}

# Get all unique packages from multiple sets (deduped)
# Parameters: $@ - Set names
# Returns: Sorted unique package names
get_all_packages_from_sets() {
    local sets=("$@")
    local all_packages=()

    for set_name in "${sets[@]}"; do
        while IFS= read -r pkg; do
            [[ -n "$pkg" ]] && all_packages+=("$pkg")
        done < <(get_package_set "$set_name")
    done

    # Remove duplicates
    printf '%s\n' "${all_packages[@]}" | sort -u
}

# Get package description from glossary cache
# Parameters:
#   $1 - Package name (e.g., "numpy")
# Output: Short description or empty string
# Uses GLOSSARY_CACHE for O(1) lookup instead of calling jq
get_package_description() {
    local pkg_name="$1"

    # Use cache if loaded
    if [[ "$GLOSSARY_LOADED" == "true" ]]; then
        echo "${GLOSSARY_CACHE[$pkg_name]:-}"
        return
    fi

    # Fallback to jq if cache not loaded (shouldn't happen in normal use)
    if [[ -f "$GLOSSARY_FILE" ]]; then
        local desc
        desc=$(jq -r ".packages.\"${pkg_name}\".description // \"\"" "$GLOSSARY_FILE" 2>/dev/null)
        [[ "$desc" != "null" ]] && echo "$desc"
    fi
}

# Get package display name from glossary file
# Parameters:
#   $1 - Package name (e.g., "numpy")
# Output: Display name or package name if not found
# ============================================================================
# PACKAGE INSTALLATION
# Functions for installing Python packages with progress feedback
# Includes retry logic for transient failures (network issues, etc.)
# Shows real-time progress and handles failures gracefully
# ============================================================================

# Install a single package and measure time
# Parameters:
#   $1 - Path to Python executable in virtual environment
#   $2 - Package name to install
# Output: "OK:Xs" or "FAILED:Xs" with elapsed time
# Returns: 0 on success, 1 on failure
install_single_package() {
    local python_exe="$1"
    local package="$2"
    local start_time end_time elapsed

    start_time=$(date +%s)

    if "$python_exe" -m pip install "$package" --quiet 2>&1; then
        end_time=$(date +%s)
        elapsed=$((end_time - start_time))
        echo "OK:${elapsed}s"
        return 0
    else
        end_time=$(date +%s)
        elapsed=$((end_time - start_time))
        echo "FAILED:${elapsed}s"
        return 1
    fi
}

# Install multiple packages with progress bar, ETA, and retry logic
# Shows package descriptions from glossary during installation
# Parameters:
#   $1 - Python executable path
#   $2 - Set name (for display)
#   $@ - Remaining args are package names
install_packages_with_progress() {
    local python_exe="$1"
    local set_name="$2"
    shift 2
    local packages=("$@")

    local total=${#packages[@]}
    local success=0
    local failed=0
    local failed_list=()

    echo ""
    echo -e "${YELLOW}  ╔══════════════════════════════════════════════════════════════════════════╗${NC}"
    printf "${YELLOW}  ║  INSTALLING: %-60s ║${NC}\n" "$set_name"
    echo -e "${YELLOW}  ╚══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "    Packages: $total"

    local est_minutes=$((total * 15 / 100 + 1))
    local est_max=$((est_minutes * 3 / 2))
    echo -e "${GRAY}    Estimated time: ${est_minutes}-${est_max} minutes${NC}"
    echo ""
    echo -e "${GRAY}  ──────────────────────────────────────────────────────────────────────────${NC}"
    echo ""

    local start_time current i pkg result
    start_time=$(date +%s)

    for i in "${!packages[@]}"; do
        pkg="${packages[$i]}"
        current=$((i + 1))
        local pct=$((current * 100 / total))

        # Get package description from glossary
        local pkg_desc
        pkg_desc=$(get_package_description "$pkg")

        # Progress bar
        local bar_width=20
        local filled=$((bar_width * current / total))
        local empty=$((bar_width - filled))
        # Progress bar - use string multiplication for efficiency
        local bar_filled="" bar_empty=""
        for ((j=0; j<filled; j++)); do bar_filled+="="; done
        for ((j=0; j<empty; j++)); do bar_empty+=" "; done
        local bar="[${bar_filled}${bar_empty}]"

        # Show package name and description
        if [[ -n "$pkg_desc" ]]; then
            # Truncate description if too long
            local max_desc_len=35
            if [[ ${#pkg_desc} -gt $max_desc_len ]]; then
                pkg_desc="${pkg_desc:0:$max_desc_len}..."
            fi
            printf "\r    $bar %3d%% (%d/%d) %-20s ${GRAY}%s${NC}          " "$pct" "$current" "$total" "$pkg" "$pkg_desc"
        else
            printf "\r    $bar %3d%% (%d/%d) Installing: %-25s          " "$pct" "$current" "$total" "$pkg"
        fi

        # Try install with retries
        local installed=false
        for attempt in $(seq 1 $RETRY_ATTEMPTS); do
            if "$python_exe" -m pip install "$pkg" --quiet 2>/dev/null; then
                ((success++))
                installed=true
                break
            elif [[ $attempt -lt $RETRY_ATTEMPTS ]]; then
                printf "\r    $bar %3d%% (%d/%d) Retrying:   %-25s          " "$pct" "$current" "$total" "$pkg"
                sleep "$RETRY_DELAY_SEC"
            fi
        done

        if [[ "$installed" != "true" ]]; then
            ((failed++))
            failed_list+=("$pkg")
        fi

        # Show ETA every 5 packages
        if [[ $((current % 5)) -eq 0 ]] && [[ $current -lt $total ]]; then
            local elapsed=$(($(date +%s) - start_time))
            local avg=$((elapsed / current))
            local remaining=$(((total - current) * avg / 60))
            echo ""
            echo -e "${GRAY}    ETA: ~${remaining} min remaining${NC}"
        fi
    done

    echo ""
    echo ""

    local total_time=$(( ($(date +%s) - start_time) / 60 ))

    echo -e "${GRAY}  ──────────────────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${GREEN}    INSTALL COMPLETE${NC}"
    echo ""
    echo -e "${GREEN}    Successful: $success/$total${NC}"
    [[ $failed -gt 0 ]] && echo -e "${RED}    Failed:     $failed${NC}"
    echo -e "${GRAY}    Time:       ${total_time} min${NC}"

    if [[ $failed -gt 0 ]]; then
        echo ""
        echo -e "${RED}    Failed packages:${NC}"
        for pkg in "${failed_list[@]}"; do
            echo -e "${GRAY}      - $pkg${NC}"
        done
    fi
    echo ""

    return $failed
}

install_package_set() {
    local python_exe="$1"
    local set_name="$2"
    local env_path="$3"

    # Check if already installed
    if is_set_installed "$env_path" "$set_name"; then
        local display_name
        display_name=$(jq -r ".package_sets.${set_name}.name // \"$set_name\"" "$PACKAGES_FILE" 2>/dev/null)
        write_info "Package set '$display_name' already installed - skipping"
        return 0
    fi

    local packages=()
    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] && packages+=("$pkg")
    done < <(get_package_set "$set_name")

    if [[ ${#packages[@]} -eq 0 ]]; then
        write_warn "Package set '$set_name' not found or empty"
        return 1
    fi

    local display_name
    display_name=$(jq -r ".package_sets.${set_name}.name // \"$set_name\"" "$PACKAGES_FILE" 2>/dev/null)

    install_packages_with_progress "$python_exe" "$display_name" "${packages[@]}"

    # Update manifest with set and individual packages
    add_manifest_entry "$env_path" "$set_name" "" "${#packages[@]}"
    add_manifest_packages "$env_path" "${packages[@]}"
}

install_job_role() {
    local python_exe="$1"
    local role_name="$2"
    local env_path="$3"

    local sets=()
    while IFS= read -r s; do
        [[ -n "$s" ]] && sets+=("$s")
    done < <(get_job_role_sets "$role_name")

    if [[ ${#sets[@]} -eq 0 ]]; then
        write_err "Job role '$role_name' not found"
        return 1
    fi

    local role_display role_desc install_time disk_est
    role_display=$(jq -r ".job_roles.${role_name}.name // \"$role_name\"" "$PACKAGES_FILE" 2>/dev/null)
    role_desc=$(jq -r ".job_roles.${role_name}.description // \"\"" "$PACKAGES_FILE" 2>/dev/null)
    install_time=$(jq -r ".job_roles.${role_name}.install_time // \"unknown\"" "$PACKAGES_FILE" 2>/dev/null)
    disk_est=$(jq -r ".job_roles.${role_name}.disk_estimate // \"unknown\"" "$PACKAGES_FILE" 2>/dev/null)

    # Count total packages
    local total_pkgs
    total_pkgs=$(get_all_packages_from_sets "${sets[@]}" | wc -l | tr -d ' ')

    echo ""
    echo -e "${MAGENTA}  ╔══════════════════════════════════════════════════════════════════════════╗${NC}"
    printf "${MAGENTA}  ║  JOB ROLE: %-62s ║${NC}\n" "$role_display"
    echo -e "${MAGENTA}  ╚══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GRAY}    $role_desc${NC}"
    echo ""
    echo -e "    Package sets:    ${#sets[@]}"
    echo -e "    Total packages:  $total_pkgs"
    echo -e "${GRAY}    Estimated time:  $install_time${NC}"
    echo -e "${GRAY}    Disk estimate:   $disk_est${NC}"
    echo ""

    local set_num=0
    for set_name in "${sets[@]}"; do
        ((set_num++))
        local set_display
        set_display=$(jq -r ".package_sets.${set_name}.name // \"$set_name\"" "$PACKAGES_FILE" 2>/dev/null)
        echo -e "${CYAN}    [$set_num/${#sets[@]}] $set_display...${NC}"
        install_package_set "$python_exe" "$set_name" "$env_path"
    done

    # Update manifest with role
    add_manifest_entry "$env_path" "" "$role_name" "$total_pkgs"

    echo ""
    echo -e "${MAGENTA}  ══════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}    JOB ROLE INSTALLATION COMPLETE: $role_display${NC}"
    echo -e "${MAGENTA}  ══════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ============================================================================
# ENVIRONMENT MANIFEST
# Tracks what package sets have been installed in each environment
# Stored as JSON file (stank-manifest.json) inside each environment folder
# Allows viewing installation history and prevents duplicate installs
# Also tracks individual packages and linked project directories
# ============================================================================

# Get path to manifest file for an environment
get_manifest_file() {
    echo "$1/stank-manifest.json"
}

# Initialize manifest file for a new environment
# Creates the JSON structure if it doesn't exist
init_manifest() {
    local env_path="$1"
    local manifest_file
    manifest_file=$(get_manifest_file "$env_path")

    if [[ ! -f "$manifest_file" ]]; then
        cat > "$manifest_file" << EOF
{
    "created": "$(date '+%Y-%m-%d %H:%M:%S')",
    "updated": "$(date '+%Y-%m-%d %H:%M:%S')",
    "python_version": "$("$env_path/bin/python" --version 2>&1 | cut -d' ' -f2)",
    "installed_sets": [],
    "installed_roles": [],
    "installed_packages": [],
    "project_path": null,
    "install_history": []
}
EOF
    fi
}

# Add a package set or role to the manifest
# Parameters:
#   $1 - Environment path
#   $2 - Package set name (optional)
#   $3 - Role name (optional)
#   $4 - Package count
add_manifest_entry() {
    local env_path="$1"
    local set_name="$2"
    local role_name="$3"
    local pkg_count="$4"
    local manifest_file
    manifest_file=$(get_manifest_file "$env_path")

    init_manifest "$env_path"

    local tmp_file="${manifest_file}.tmp"
    local now
    now=$(date '+%Y-%m-%d %H:%M:%S')

    # Add to appropriate array and update timestamp
    if [[ -n "$set_name" ]]; then
        jq --arg set "$set_name" --arg now "$now" --arg count "$pkg_count" \
            '.updated = $now | .installed_sets = (.installed_sets + [$set] | unique) | .install_history = .install_history + [{"type":"set","name":$set,"count":($count|tonumber),"date":$now}]' \
            "$manifest_file" > "$tmp_file" && mv "$tmp_file" "$manifest_file"
    fi

    if [[ -n "$role_name" ]]; then
        jq --arg role "$role_name" --arg now "$now" --arg count "$pkg_count" \
            '.updated = $now | .installed_roles = (.installed_roles + [$role] | unique) | .install_history = .install_history + [{"type":"role","name":$role,"count":($count|tonumber),"date":$now}]' \
            "$manifest_file" > "$tmp_file" && mv "$tmp_file" "$manifest_file"
    fi
}

# Record individual packages installed in the manifest
# Parameters:
#   $1 - Environment path
#   $2 - Array of package names (passed as string, space-separated)
add_manifest_packages() {
    local env_path="$1"
    shift
    local packages=("$@")
    local manifest_file
    manifest_file=$(get_manifest_file "$env_path")

    init_manifest "$env_path"

    local tmp_file="${manifest_file}.tmp"
    local now
    now=$(date '+%Y-%m-%d %H:%M:%S')

    # Convert packages array to JSON array string
    local pkg_json="["
    local first=true
    for pkg in "${packages[@]}"; do
        if [[ "$first" == "true" ]]; then
            pkg_json+="\"$pkg\""
            first=false
        else
            pkg_json+=",\"$pkg\""
        fi
    done
    pkg_json+="]"

    # Merge with existing packages (unique)
    jq --argjson pkgs "$pkg_json" --arg now "$now" \
        '.updated = $now | .installed_packages = (.installed_packages + $pkgs | unique | sort)' \
        "$manifest_file" > "$tmp_file" && mv "$tmp_file" "$manifest_file"
}

# Link project directory to environment manifest
# Parameters:
#   $1 - Environment path
#   $2 - Project path
update_manifest_project() {
    local env_path="$1"
    local proj_path="$2"
    local manifest_file
    manifest_file=$(get_manifest_file "$env_path")

    init_manifest "$env_path"

    local tmp_file="${manifest_file}.tmp"
    jq --arg proj "$proj_path" '.project_path = $proj' \
        "$manifest_file" > "$tmp_file" && mv "$tmp_file" "$manifest_file"
}

# Check if a package set is already installed
# Parameters:
#   $1 - Environment path
#   $2 - Package set name
# Returns: 0 if installed, 1 if not
is_set_installed() {
    local env_path="$1"
    local set_name="$2"
    local manifest_file
    manifest_file=$(get_manifest_file "$env_path")

    if [[ ! -f "$manifest_file" ]]; then
        return 1
    fi

    jq -e ".installed_sets | index(\"$set_name\")" "$manifest_file" &>/dev/null
}

show_environment_manifest() {
    local env_path="$1"
    local env_name="$2"
    local manifest_file
    manifest_file=$(get_manifest_file "$env_path")

    echo ""
    echo -e "${CYAN}  ╔══════════════════════════════════════════════════════════════════════════╗${NC}"
    printf "${CYAN}  ║                    ENVIRONMENT DETAILS: %-28s      ║${NC}\n" "$env_name"
    echo -e "${CYAN}  ╚══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [[ -f "$manifest_file" ]]; then
        local roles sets created updated py_version proj_path pkg_count
        roles=$(jq -r '.installed_roles // [] | .[]' "$manifest_file" 2>/dev/null)
        sets=$(jq -r '.installed_sets // [] | .[]' "$manifest_file" 2>/dev/null)
        created=$(jq -r '.created // "unknown"' "$manifest_file" 2>/dev/null)
        updated=$(jq -r '.updated // "unknown"' "$manifest_file" 2>/dev/null)
        py_version=$(jq -r '.python_version // "unknown"' "$manifest_file" 2>/dev/null)
        proj_path=$(jq -r '.project_path // null' "$manifest_file" 2>/dev/null)
        pkg_count=$(jq -r '.installed_packages | length' "$manifest_file" 2>/dev/null)

        # Basic info
        echo -e "${WHITE}    Python: ${py_version}${NC}"
        echo -e "${WHITE}    Path:   ${env_path}${NC}"
        if [[ "$proj_path" != "null" ]] && [[ -d "$proj_path" ]]; then
            echo -e "${WHITE}    Project: ${proj_path}${NC}"
        fi
        echo ""

        if [[ -n "$roles" ]]; then
            echo -e "${YELLOW}    Job Roles:${NC}"
            while IFS= read -r role; do
                local role_display
                role_display=$(jq -r ".job_roles.${role}.name // \"$role\"" "$PACKAGES_FILE" 2>/dev/null)
                echo -e "${GREEN}      ✓ $role_display${NC}"
            done <<< "$roles"
            echo ""
        fi

        if [[ -n "$sets" ]]; then
            echo -e "${YELLOW}    Package Sets Installed:${NC}"
            while IFS= read -r set_name; do
                local set_display set_pkg_count
                set_display=$(jq -r ".package_sets.${set_name}.name // \"$set_name\"" "$PACKAGES_FILE" 2>/dev/null)
                set_pkg_count=$(jq -r ".package_sets.${set_name}.packages | length" "$PACKAGES_FILE" 2>/dev/null)
                echo -e "${CYAN}      ✓ $set_display ($set_pkg_count pkgs)${NC}"
            done <<< "$sets"
            echo ""
        fi

        echo -e "${GRAY}    Total packages tracked: ${pkg_count:-0}${NC}"
        echo -e "${GRAY}    Created: $created${NC}"
        echo -e "${GRAY}    Updated: $updated${NC}"
    else
        echo -e "${GRAY}    No manifest found.${NC}"
        echo -e "${GRAY}    (Created before tracking was implemented)${NC}"
    fi
    echo ""
}

# ============================================================================
# STATE MANAGEMENT
# Remembers the last used environment for quick resume
# State is stored in .last-session.json in the .venvs directory
# ============================================================================

# Save current session info for later resume
# Parameters:
#   $1 - Environment name
#   $2 - Working directory path
save_last_session() {
    local env_name="$1"
    local work_dir="$2"

    mkdir -p "$(dirname "$STATE_FILE")"
    cat > "$STATE_FILE" << EOF
{
    "env_name": "$env_name",
    "work_dir": "$work_dir",
    "date": "$(date '+%Y-%m-%d %H:%M:%S')"
}
EOF
}

get_last_session() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    fi
}

get_last_session_env() {
    if [[ -f "$STATE_FILE" ]]; then
        jq -r '.env_name // ""' "$STATE_FILE" 2>/dev/null
    fi
}

# ============================================================================
# ENVIRONMENT MANAGEMENT
# Functions for listing, selecting, and displaying virtual environments
# Each environment is a folder in ~/.venvs containing an isolated Python
# ============================================================================

# Get list of all valid environments
# Output: pipe-separated lines: name|path|python_version|has_jupyter|size
get_all_environments() {
    if [[ ! -d "$VENV_DIR" ]]; then
        return
    fi

    for dir in "$VENV_DIR"/*/; do
        [[ -d "$dir" ]] || continue
        local name python_exe
        name=$(basename "$dir")
        python_exe="$dir/bin/python"

        if [[ -x "$python_exe" ]]; then
            local py_version has_jupyter env_size proj_dir
            py_version=$("$python_exe" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" 2>/dev/null || echo "unknown")

            if [[ -x "$dir/bin/jupyter" ]]; then
                has_jupyter="yes"
            else
                has_jupyter="no"
            fi

            env_size=$(get_folder_size "$dir")
            proj_dir="$PROJECTS_DIR/$name"

            echo "$name|$dir|$py_version|$has_jupyter|$env_size"
        fi
    done
}

show_environment_table() {
    local envs=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && envs+=("$line")
    done < <(get_all_environments)

    echo ""
    echo -e "${CYAN}  ╔══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}  ║                         YOUR PYTHON ENVIRONMENTS                         ║${NC}"
    echo -e "${CYAN}  ╚══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [[ ${#envs[@]} -eq 0 ]]; then
        echo -e "${GRAY}    No environments found. Use options 1-5 to create one.${NC}"
        return
    fi

    local last_env
    last_env=$(get_last_session_env)

    echo -e "${GRAY}    #   NAME                 PYTHON     JUPYTER  SIZE${NC}"
    echo -e "${GRAY}    ─────────────────────────────────────────────────────────────────────${NC}"

    local i=1
    for env_line in "${envs[@]}"; do
        IFS='|' read -r name path py_version has_jupyter env_size <<< "$env_line"

        local marker=" "
        [[ "$name" == "$last_env" ]] && marker="*"

        local color="${YELLOW}"
        [[ "$has_jupyter" == "yes" ]] && color="${GREEN}"

        printf "    ${color}%s%-3d %-20s %-10s %-8s %s${NC}\n" "$marker" "$i" "$name" "$py_version" "$has_jupyter" "$env_size"
        ((i++))
    done
    echo ""
}

select_environment() {
    local prompt="${1:-Select environment}"

    local envs=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && envs+=("$line")
    done < <(get_all_environments)

    if [[ ${#envs[@]} -eq 0 ]]; then
        echo ""
        write_warn "No environments available. Create one first."
        return 1
    fi

    show_environment_table
    echo -e "${GRAY}    [0]  Cancel${NC}"
    echo ""
    echo -e "${GRAY}  ──────────────────────────────────────────────────────────────────────────${NC}"
    echo -ne "    $prompt (1-${#envs[@]}): "
    read -r sel

    if [[ "$sel" == "0" ]] || [[ -z "$sel" ]]; then
        return 1
    fi

    if [[ "$sel" =~ ^[0-9]+$ ]] && [[ "$sel" -ge 1 ]] && [[ "$sel" -le ${#envs[@]} ]]; then
        local idx=$((sel - 1))
        IFS='|' read -r name path py_version has_jupyter env_size <<< "${envs[$idx]}"
        SELECTED_ENV_NAME="$name"
        SELECTED_ENV_PATH="$path"
        SELECTED_ENV_PYTHON="$path/bin/python"
        echo ""
        write_ok "Selected: $name"
        return 0
    fi

    write_err "Invalid selection"
    return 1
}

# ============================================================================
# ENVIRONMENT CREATION
# Creates new virtual environments with optional package presets
# Validates inputs, checks disk space, and handles errors gracefully
# ============================================================================

# Create a new virtual environment
# Parameters:
#   $1 - Environment name (will be sanitized - alphanumeric + dashes only)
#   $2 - Package preset: "none", "jupyter", "data_science", or a job role name
#   $3 - Create project directory: "true" or "false"
# Returns: 0 on success, 1 on failure
create_environment() {
    local name="$1"
    local package_preset="$2"
    local create_project_dir="$3"

    write_section "CREATING ENVIRONMENT: $name"

    # Validate name using our validation function
    if ! validate_env_name "$name"; then
        return 1
    fi
    write_ok "Name '$name' is valid"

    # Check if exists
    local env_path="$VENV_DIR/$name"
    if [[ -d "$env_path" ]]; then
        write_err "Environment '$name' already exists"
        return 1
    fi

    # Pre-flight checks
    if ! test_disk_space 1; then
        if ! confirm_action "Continue anyway?"; then
            return 1
        fi
    fi

    # Create directories
    mkdir -p "$VENV_DIR"
    write_ok "Created: $VENV_DIR"

    # Create virtual environment
    write_step 1 "CREATING VIRTUAL ENVIRONMENT"
    write_why "venv creates an isolated Python with its own packages"
    write_command "$PYTHON_CMD -m venv $env_path"
    write_progress "Creating..."

    if "$PYTHON_CMD" -m venv "$env_path" 2>&1; then
        write_progress_done
    else
        write_progress_done "FAILED"
        write_err "venv creation failed"
        return 1
    fi

    # Verify
    local python_exe="$env_path/bin/python"
    if [[ ! -x "$python_exe" ]]; then
        write_err "Environment created but python not found"
        return 1
    fi
    write_ok "Environment created: $env_path"

    # Initialize manifest
    init_manifest "$env_path"

    # Upgrade pip
    write_step 2 "UPGRADING PIP"
    write_why "Ensures latest pip for best compatibility"
    write_progress "Upgrading..."
    if "$python_exe" -m pip install --upgrade pip --quiet 2>/dev/null; then
        write_progress_done
    else
        write_progress_done "Warning"
        write_warn "pip upgrade failed (continuing anyway)"
    fi

    # Install packages based on preset
    if [[ "$package_preset" != "none" ]]; then
        write_step 3 "INSTALLING PACKAGES"

        if ! test_network; then
            write_warn "Skipping package installation (no network)"
        else
            case "$package_preset" in
                jupyter)
                    install_package_set "$python_exe" "jupyter" "$env_path"
                    ;;
                data_science)
                    install_package_set "$python_exe" "jupyter" "$env_path"
                    install_package_set "$python_exe" "data_science" "$env_path"
                    ;;
                full|full_stack)
                    # Install ALL package sets (full 315 package install)
                    echo ""
                    echo -e "${MAGENTA}  INSTALLING ALL PACKAGE SETS${NC}"
                    echo -e "${GRAY}  This will install all 31 sets with 315 packages.${NC}"
                    echo ""
                    local all_sets=()
                    while IFS= read -r s; do
                        [[ -n "$s" ]] && all_sets+=("$s")
                    done < <(jq -r '.package_sets | keys[]' "$PACKAGES_FILE" 2>/dev/null)
                    
                    local set_num=0
                    for set_name in "${all_sets[@]}"; do
                        ((set_num++))
                        local set_display
                        set_display=$(jq -r ".package_sets.${set_name}.name // \"$set_name\"" "$PACKAGES_FILE" 2>/dev/null)
                        echo -e "${CYAN}    [$set_num/${#all_sets[@]}] $set_display...${NC}"
                        install_package_set "$python_exe" "$set_name" "$env_path"
                    done
                    ;;
                *)
                    # Check if it's a job role
                    if jq -e ".job_roles.${package_preset}" "$PACKAGES_FILE" &>/dev/null; then
                        install_job_role "$python_exe" "$package_preset" "$env_path"
                    fi
                    ;;
            esac
        fi
    fi

    # Create project directory (safely - never clobber existing files)
    if [[ "$create_project_dir" == "true" ]]; then
        local proj_path="$PROJECTS_DIR/$name"

        if [[ -d "$proj_path" ]]; then
            write_warn "Project directory already exists: $proj_path"
            write_info "Existing files preserved - creating only missing subdirectories"
            # Only create subdirectories that don't exist (never overwrite)
            [[ ! -d "$proj_path/notebooks" ]] && mkdir -p "$proj_path/notebooks"
            [[ ! -d "$proj_path/data" ]] && mkdir -p "$proj_path/data"
            [[ ! -d "$proj_path/outputs" ]] && mkdir -p "$proj_path/outputs"
            [[ ! -d "$proj_path/scripts" ]] && mkdir -p "$proj_path/scripts"
        else
            mkdir -p "$proj_path"/{notebooks,data,outputs,scripts}
            write_ok "Created project: $proj_path"
        fi

        # Link project to environment manifest
        update_manifest_project "$env_path" "$proj_path"
    fi

    write_section "ENVIRONMENT CREATED SUCCESSFULLY"
    echo "  Name: $name"
    echo "  Path: $env_path"
    echo "  Activate: source $env_path/bin/activate"

    return 0
}

# ============================================================================
# JUPYTER LAUNCH
# Functions for starting JupyterLab in a virtual environment
# Opens in the project directory and saves session for quick resume
# ============================================================================

# Start JupyterLab in the specified environment
# Parameters:
#   $1 - Environment path (e.g., ~/.venvs/myenv)
#   $2 - Environment name (for display and session tracking)
#   $3 - Working directory (optional, defaults to project dir or current dir)
#   $4 - Port number (optional, defaults to 8888)
start_jupyter_lab() {
    local env_path="$1"
    local env_name="$2"
    local work_dir="$3"
    local port="${4:-8888}"

    write_section "LAUNCHING JUPYTERLAB"

    local jupyter_exe="$env_path/bin/jupyter"
    local python_exe="$env_path/bin/python"

    if [[ ! -x "$jupyter_exe" ]]; then
        write_warn "JupyterLab not installed"
        if confirm_action "Install JupyterLab now?"; then
            install_package_set "$python_exe" "jupyter" "$env_path"
        else
            return 1
        fi
    fi

    local proj_dir="$PROJECTS_DIR/$env_name"
    if [[ -z "$work_dir" ]]; then
        if [[ -d "$proj_dir" ]]; then
            work_dir="$proj_dir"
        else
            work_dir="$PWD"
        fi
    fi

    if [[ ! -d "$work_dir" ]]; then
        write_err "Directory not found: $work_dir"
        return 1
    fi

    save_last_session "$env_name" "$work_dir"

    echo ""
    echo -e "${GREEN}  $(printf '=%.0s' {1..60})${NC}"
    echo -e "${GREEN}  JUPYTERLAB STARTING${NC}"
    echo -e "${CYAN}  Environment: $env_name${NC}"
    echo -e "${CYAN}  Directory  : $work_dir${NC}"
    echo -e "${YELLOW}  TO STOP    : Press Ctrl+C${NC}"
    echo -e "${GREEN}  $(printf '=%.0s' {1..60})${NC}"
    echo ""

    cd "$work_dir"
    "$python_exe" -m jupyter lab --port="$port"
}

start_last_session() {
    local last_env last_work_dir
    last_env=$(get_last_session_env)
    last_work_dir=$(jq -r '.work_dir // ""' "$STATE_FILE" 2>/dev/null)

    if [[ -z "$last_env" ]]; then
        write_warn "No previous session found"
        return 1
    fi

    local env_path="$VENV_DIR/$last_env"
    if [[ ! -d "$env_path" ]]; then
        write_err "Environment '$last_env' no longer exists"
        return 1
    fi

    start_jupyter_lab "$env_path" "$last_env" "$last_work_dir"
}

# ============================================================================
# RUNNING SESSIONS
# Detect and display active Jupyter processes
# Helps users avoid conflicts and find running notebooks
# ============================================================================

# Find running Jupyter processes and their ports
# Output: pipe-separated lines: pid|port|environment_name
get_running_jupyter_sessions() {
    # Find jupyter processes
    ps aux 2>/dev/null | grep -E "jupyter.*lab|jupyter.*notebook" | grep -v grep | while read -r line; do
        local pid port env_name
        pid=$(echo "$line" | awk '{print $2}')

        # Try to find port from lsof
        port=$(lsof -Pan -p "$pid" -i 2>/dev/null | grep LISTEN | grep -oE ':\d+' | head -1 | tr -d ':')
        [[ -z "$port" ]] && port="unknown"

        # Try to identify environment
        env_name="unknown"
        if echo "$line" | grep -q "\.venvs/"; then
            env_name=$(echo "$line" | grep -oE '\.venvs/[^/]+' | cut -d'/' -f2)
        fi

        echo "$pid|$port|$env_name"
    done
}

show_running_sessions() {
    echo ""
    echo -e "${CYAN}  RUNNING JUPYTER SESSIONS${NC}"
    echo -e "${GRAY}  ════════════════════════════════════════════════════════════════${NC}"
    echo ""

    local sessions=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && sessions+=("$line")
    done < <(get_running_jupyter_sessions)

    if [[ ${#sessions[@]} -eq 0 ]]; then
        echo -e "${GRAY}    No running Jupyter sessions detected.${NC}"
    else
        echo -e "${GRAY}    PID      PORT   ENVIRONMENT${NC}"
        echo -e "${GRAY}    ─────────────────────────────────────────────────────────${NC}"

        for session in "${sessions[@]}"; do
            IFS='|' read -r pid port env_name <<< "$session"
            printf "    %-8s %-6s %s\n" "$pid" "$port" "$env_name"
        done
    fi
    echo ""
}

# ============================================================================
# JOB ROLE MENU
# Interactive menu for selecting pre-configured job role packages
# Each role includes curated package sets for specific professions
# ============================================================================

# Display job role selection menu and capture user choice
# Sets SELECTED_ROLE global variable on success
# Returns: 0 if role selected, 1 if cancelled
show_job_role_menu() {
    clear
    echo ""
    echo -e "${CYAN}  ╔══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}  ║                        SELECT YOUR JOB ROLE                              ║${NC}"
    echo -e "${CYAN}  ╚══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [[ ! -f "$PACKAGES_FILE" ]]; then
        write_err "Job roles not available (config not loaded)"
        return 1
    fi

    echo -e "${GRAY}    Pre-configured package bundles optimized for your profession:${NC}"
    echo ""

    local roles=()
    while IFS= read -r role; do
        [[ -n "$role" ]] && roles+=("$role")
    done < <(jq -r '.job_roles | keys[]' "$PACKAGES_FILE" 2>/dev/null)

    local i=1
    for role in "${roles[@]}"; do
        local name desc install_time disk_est pkg_count
        name=$(jq -r ".job_roles.${role}.name" "$PACKAGES_FILE")
        install_time=$(jq -r ".job_roles.${role}.install_time" "$PACKAGES_FILE")
        disk_est=$(jq -r ".job_roles.${role}.disk_estimate" "$PACKAGES_FILE")

        # Count packages
        local sets
        sets=$(jq -r ".job_roles.${role}.sets[]" "$PACKAGES_FILE" 2>/dev/null)
        pkg_count=0
        for s in $sets; do
            local c
            c=$(jq -r ".package_sets.${s}.packages | length" "$PACKAGES_FILE" 2>/dev/null)
            pkg_count=$((pkg_count + c))
        done

        printf "${YELLOW}    [%d]${NC}  ${WHITE}%-32s${NC} ${CYAN}%d pkgs${NC}  ${GRAY}%-12s %s${NC}\n" \
            "$i" "$name" "$pkg_count" "$install_time" "$disk_est"
        ((i++))
    done

    echo ""
    echo -e "${GRAY}    [0]  Cancel - return to main menu${NC}"
    echo ""
    echo -e "${GRAY}  ──────────────────────────────────────────────────────────────────────────${NC}"
    echo -ne "    Select role (1-${#roles[@]}): "
    read -r choice

    if [[ "$choice" == "0" ]] || [[ -z "$choice" ]]; then
        return 1
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#roles[@]} ]]; then
        local idx=$((choice - 1))
        SELECTED_ROLE="${roles[$idx]}"
        local role_name
        role_name=$(jq -r ".job_roles.${SELECTED_ROLE}.name" "$PACKAGES_FILE")
        echo ""
        write_ok "Selected: $role_name"
        return 0
    fi

    write_err "Invalid selection"
    return 1
}

# ============================================================================
# PACKAGE SETS MENU
# Interactive menu for adding individual package sets to an environment
# Allows mixing and matching packages after initial creation
# ============================================================================

# Display package sets menu for adding packages to existing environment
# Parameters:
#   $1 - Environment path
#   $2 - Environment name
# Returns: 0 if packages installed, 1 if cancelled
show_package_sets_menu() {
    local env_path="$1"
    local env_name="$2"
    local python_exe="$env_path/bin/python"

    clear
    echo ""
    echo -e "${CYAN}  ╔══════════════════════════════════════════════════════════════════════════╗${NC}"
    printf "${CYAN}  ║                      ADD PACKAGE SETS TO: %-26s     ║${NC}\n" "$env_name"
    echo -e "${CYAN}  ╚══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [[ ! -f "$PACKAGES_FILE" ]]; then
        write_warn "Package configuration not loaded"
        return 1
    fi

    local sets=()
    while IFS= read -r set_name; do
        [[ -n "$set_name" ]] && sets+=("$set_name")
    done < <(jq -r '.package_sets | keys[]' "$PACKAGES_FILE" 2>/dev/null)

    local i=1
    for set_name in "${sets[@]}"; do
        local name pkg_count category
        name=$(jq -r ".package_sets.${set_name}.name" "$PACKAGES_FILE")
        pkg_count=$(jq -r ".package_sets.${set_name}.packages | length" "$PACKAGES_FILE")
        category=$(jq -r ".package_sets.${set_name}.category // \"other\"" "$PACKAGES_FILE")

        printf "    [%2d]  %-30s (%2d pkgs)  %s\n" "$i" "$name" "$pkg_count" "$category"
        ((i++))
    done

    echo ""
    echo -e "${GRAY}    [0]  Cancel${NC}"
    echo ""
    echo -ne "    Select set to install (1-${#sets[@]}): "
    read -r choice

    if [[ "$choice" == "0" ]] || [[ -z "$choice" ]]; then
        return 1
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#sets[@]} ]]; then
        local idx=$((choice - 1))
        local selected_set="${sets[$idx]}"
        install_package_set "$python_exe" "$selected_set" "$env_path"
        return 0
    fi

    write_err "Invalid selection"
    return 1
}

# ============================================================================
# HELP MENU
# Reference information for manual commands and cleanup
# NOTE: This script never deletes files - deletion commands shown for reference
# ============================================================================

# Display help information including manual activation commands
show_help_menu() {
    clear
    echo ""
    echo -e "${CYAN}  HELP: MANUAL COMMANDS${NC}"
    echo -e "${GRAY}  ════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}  ACTIVATE AN ENVIRONMENT:${NC}"
    echo -e "${WHITE}    source ~/.venvs/<env-name>/bin/activate${NC}"
    echo ""
    echo -e "${YELLOW}  DEACTIVATE:${NC}"
    echo -e "${WHITE}    deactivate${NC}"
    echo ""
    echo -e "${YELLOW}  DIRECTORIES:${NC}"
    echo -e "    Environments: ${WHITE}~/.venvs/${NC}"
    echo -e "    Projects:     ${WHITE}~/JupyterProjects/${NC}"
    echo ""
    echo -e "${YELLOW}  EXPORT REQUIREMENTS:${NC}"
    echo -e "${WHITE}    source ~/.venvs/<name>/bin/activate${NC}"
    echo -e "${WHITE}    pip freeze > requirements.txt${NC}"
    echo ""
    echo -e "${YELLOW}  INSTALL FROM REQUIREMENTS:${NC}"
    echo -e "${WHITE}    pip install -r requirements.txt${NC}"
    echo ""
    echo -e "${GRAY}  ════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${RED}  DELETING ENVIRONMENTS${NC}"
    echo ""
    echo -e "${GRAY}  This script contains zero delete operations.${NC}"
    echo -e "${GRAY}  It never removes files, folders, or environments.${NC}"
    echo -e "${GRAY}  Commands below are for reference - run them yourself.${NC}"
    echo ""
    echo -e "${CYAN}  1. DELETE AN ENVIRONMENT:${NC}"
    echo -e "     - Close any running Jupyter sessions for that environment"
    echo -e "     - Delete the folder: ${WHITE}rm -rf ~/.venvs/<env-name>${NC}"
    echo -e "     - Optionally delete project: ${WHITE}rm -rf ~/JupyterProjects/<env-name>${NC}"
    echo ""
    echo -e "${CYAN}  2. LIST ENVIRONMENTS:${NC}"
    echo -e "${WHITE}     ls -la ~/.venvs/${NC}"
    echo ""
    echo -e "${GREEN}  3. KEEP YOUR WORK:${NC}"
    echo -e "     - Your notebooks/data are in JupyterProjects (separate from envs)"
    echo -e "     - Deleting an environment does NOT delete your project files"
    echo -e "     - Back up JupyterProjects before any cleanup"
    echo ""
}

# ============================================================================
# MAIN MENU
# Primary user interface - displays options and handles navigation
# ============================================================================

# Display the main menu with all available options
show_menu() {
    clear
    local last_env running_count
    last_env=$(get_last_session_env)
    running_count=$(get_running_jupyter_sessions | wc -l | tr -d ' ')

    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │         STANK PYTHON VENV MANAGER v0.1  (macOS)              │${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────────┘${NC}"
    [[ "$running_count" -gt 0 ]] && echo -e "${GREEN}    ● $running_count Jupyter session(s) running${NC}"
    echo ""

    if [[ -n "$last_env" ]]; then
        echo -e "  ${GREEN}[0]${NC}  Resume: ${WHITE}$last_env${NC}  ${GRAY}← Enter${NC}"
    else
        echo -e "  ${GRAY}[0]  Resume: (no previous session)${NC}"
    fi
    echo ""

    echo -e "  ${YELLOW}CREATE${NC}"
    echo -e "  ${WHITE}[1]${NC}  Empty environment"
    echo -e "  ${WHITE}[2]${NC}  With JupyterLab"
    echo -e "  ${WHITE}[3]${NC}  By Job Role              ${GRAY}9 professional roles${NC}"
    echo -e "  ${WHITE}[4]${NC}  Full install             ${GRAY}315 packages${NC}"
    echo ""

    echo -e "  ${YELLOW}USE${NC}"
    echo -e "  ${WHITE}[5]${NC}  View / Launch environments"
    echo -e "  ${WHITE}[6]${NC}  Add packages to environment"
    echo -e "  ${WHITE}[S]${NC}  Show running sessions"
    echo ""

    echo -e "  ${YELLOW}HELP${NC}"
    echo -e "  ${WHITE}[7]${NC}  Manual commands & directories"
    echo ""

    echo -e "  ${GRAY}[Q]  Quit${NC}"
    echo ""
}

# ============================================================================
# MAIN FUNCTION
# Entry point - runs dependency checks, then starts the menu loop
# ============================================================================

# Main program entry point
# 1. Checks all dependencies (jq, Python, etc.)
# 2. Loads configuration
# 3. Runs interactive menu loop until user quits
main() {
    # Initial checks
    check_jq || exit 1
    detect_architecture
    detect_homebrew
    check_xcode_cli

    load_package_config
    load_glossary  # Optional - provides package descriptions during install

    if ! detect_python; then
        pause_prompt
        exit 1
    fi

    write_info "Ready. Loading menu..."
    sleep 0.5

    while true; do
        show_menu
        echo -ne "  Select [0]: "
        read -r choice

        # Default to 0 (Resume) if empty
        [[ -z "$choice" ]] && choice="0"

        choice_upper=$(echo "$choice" | tr '[:lower:]' '[:upper:]')
        case "$choice_upper" in
            1)
                echo -ne "    Environment name: "
                read -r name
                name=$(sanitize_env_name "$name")
                [[ -z "$name" ]] && { write_err "Name cannot be empty"; pause_prompt; continue; }
                create_project="false"
                confirm_action "Create project directory?" && create_project="true"
                create_environment "$name" "none" "$create_project"
                pause_prompt
                ;;
            2)
                echo -ne "    Environment name: "
                read -r name
                name=$(sanitize_env_name "$name")
                [[ -z "$name" ]] && { write_err "Name cannot be empty"; pause_prompt; continue; }
                if create_environment "$name" "jupyter" "true"; then
                    if confirm_action "Launch JupyterLab now?"; then
                        start_jupyter_lab "$VENV_DIR/$name" "$name" ""
                    fi
                fi
                pause_prompt
                ;;
            3)
                if show_job_role_menu; then
                    echo -ne "    Environment name: "
                    read -r name
                    name=$(sanitize_env_name "$name")
                    [[ -z "$name" ]] && { write_err "Name cannot be empty"; pause_prompt; continue; }
                    if create_environment "$name" "$SELECTED_ROLE" "true"; then
                        if confirm_action "Launch JupyterLab now?"; then
                            start_jupyter_lab "$VENV_DIR/$name" "$name" ""
                        fi
                    fi
                fi
                pause_prompt
                ;;
            4)
                echo ""
                echo -e "${MAGENTA}  FULL INSTALLATION${NC}"
                echo -e "${GRAY}  Installs ALL packages (315) from all categories.${NC}"
                echo -e "${YELLOW}  Time: 2-3 hours | Disk: 10-12 GB${NC}"
                echo ""
                echo -ne "    Environment name: "
                read -r name
                name=$(sanitize_env_name "$name")
                [[ -z "$name" ]] && { write_err "Name cannot be empty"; pause_prompt; continue; }
                if ! test_disk_space 12; then
                    confirm_action "Low disk space. Continue anyway?" || { pause_prompt; continue; }
                fi
                if create_environment "$name" "full" "true"; then
                    if confirm_action "Launch JupyterLab now?"; then
                        start_jupyter_lab "$VENV_DIR/$name" "$name" ""
                    fi
                fi
                pause_prompt
                ;;
            5)
                if select_environment "Select environment"; then
                    show_environment_manifest "$SELECTED_ENV_PATH" "$SELECTED_ENV_NAME"
                    echo -e "${GRAY}    [L] Launch JupyterLab   [A] Show activation command${NC}"
                    echo ""
                    echo -ne "    Select or Enter to go back: "
                    read -r sub
                    sub_upper=$(echo "$sub" | tr '[:lower:]' '[:upper:]')
                    case "$sub_upper" in
                        L)
                            start_jupyter_lab "$SELECTED_ENV_PATH" "$SELECTED_ENV_NAME" ""
                            ;;
                        A)
                            echo ""
                            echo -e "${CYAN}    Activate:${NC}"
                            echo -e "${WHITE}    source $SELECTED_ENV_PATH/bin/activate${NC}"
                            ;;
                    esac
                fi
                pause_prompt
                ;;
            6)
                if select_environment "Select environment"; then
                    show_package_sets_menu "$SELECTED_ENV_PATH" "$SELECTED_ENV_NAME"
                fi
                pause_prompt
                ;;
            0|"")
                start_last_session
                pause_prompt
                ;;
            7)
                show_help_menu
                pause_prompt
                ;;
            S)
                show_running_sessions
                pause_prompt
                ;;
            Q)
                echo ""
                write_ok "Goodbye!"
                echo ""
                exit 0
                ;;
            *)
                write_warn "Invalid selection: '$choice'"
                write_info "Enter 0-7, S, or Q"
                sleep 0.8
                ;;
        esac
    done
}

# ============================================================================
# START
# ============================================================================

echo ""
echo -e "${CYAN}  Stank Python Virtual Environment Manager${NC}"
echo -e "${GRAY}  Version 0.1 (Beta) (macOS)${NC}"
echo -e "${GRAY}  Created by Nick Stankiewicz${NC}"
echo -e "${GRAY}  2026.01.04${NC}"
echo ""

main
