# SPVEM - STANK PYTHON VIRTUAL ENVIRONMENT MANAGER

A verbose, beginner-friendly Python virtual environment manager with pre-configured package bundles for data science, machine learning, web development, security, and more.

**Status: Beta** - Please report issues

---

## What Is This?

Setting up Python environments is confusing for beginners: too many tools (venv, conda, pyenv, poetry...), silent failures, no explanations, and hundreds of packages to research.

**SPVEM** (pronounced "SPEVEM") solves this by:

- **Showing every command** before execution with explanations
- **Bundling packages by job role** - select "Data Scientist" and get 150+ relevant packages
- **Never deleting silently** - zero delete operations in the scripts
- **Failing loudly** - clear error messages with actionable fixes

---

## Platform Versions

| Platform | Version | Status | Python | Link |
| --- | --- | --- | --- | --- |
| **Windows 10/11** | 0.1 | Beta | 3.11 (strict) | [windows/](windows/) |
| **macOS** | 0.1 | Beta | 3.11+ (Homebrew) | [macos/](macos/) |

### Windows

- PowerShell script with .bat launcher (bypasses execution policy)
- Uses `py -3.11` launcher for version management
- 29 package sets, 413 packages, 9 job roles

### macOS

- Bash script for Terminal
- Supports Apple Silicon (M1/M2/M3) and Intel
- Native GPU acceleration (PyTorch MPS, TensorFlow Metal, MLX)
- 31 package sets, 329 packages, 9 job roles

---

## Quick Start

### Windows

**Step 1: Install Python 3.11**

Download from [python.org/downloads/release/python-3119](https://python.org/downloads/release/python-3119)

> **IMPORTANT - Installer Options:**
> 
> - `[ ] Add python.exe to PATH` - **LEAVE UNCHECKED**
> - `[x] Install py launcher for all users` - **CHECK THIS**
> 
> This installs Python 3.11 safely alongside existing versions.

**Step 2: Download Files**

Place all 5 files in the same folder:

- `stank-venv-manager.bat` - launcher
- `stank-venv-manager.ps1` - main script
- `stank-venv-packages.json` - package definitions
- `stank-venv-manager-readme.html` - documentation
- `README.md` - text documentation

**Step 3: Run**

Double-click: `stank-venv-manager.bat`

**Verify Installation**

```
py --list
py -3.11 --version
```

---

### macOS

**Step 1: Install Python 3.11**

Install via Homebrew (recommended):

```bash
brew install python@3.11
```

> **Don't have Homebrew?** Install it first:
> 
> ```bash
> /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
> ```

> **IMPORTANT - After Installation:**
> 
> - Add to your shell profile (~/.zshrc or ~/.bash_profile):
>   
>   ```bash
>   export PATH="/opt/homebrew/opt/python@3.11/bin:$PATH"
>   ```
>   
> - Then restart Terminal or run: `source ~/.zshrc`

**Step 2: Install jq (Required)**

```bash
brew install jq
```

**Step 3: Download Files**

Place all files in the same folder:

- `stank-venv-manager.command` - Finder launcher (double-click)
- `stank-venv-manager.sh` - main script
- `stank-venv-packages-macos.json` - package definitions
- `stank-venv-glossary.json` - package descriptions
- `stank-venv-manager-readme-macos.html` - visual documentation
- `README.md` - text documentation

**Step 4: Run**

```bash
# First time only - make executable and bypass Gatekeeper
chmod +x stank-venv-manager.sh stank-venv-manager.command
xattr -d com.apple.quarantine stank-venv-manager.sh stank-venv-manager.command

# Run via Terminal
./stank-venv-manager.sh

# OR double-click stank-venv-manager.command in Finder
```

**Verify Installation**

```bash
python3.11 --version
which python3.11
```

---

## Features

- **9 Job Roles**: Data Scientist, ML Engineer, Backend Developer, Security Analyst, DevOps Engineer, Data Analyst, Data Engineer, Document Automation Specialist, Full Stack Developer
  
- **Pre-configured Package Sets**: JupyterLab, data science, machine learning, deep learning, NLP, web scraping, API development, database tools, cloud SDKs, and more
  
- **Session Resume**: Press Enter to continue where you left off
  
- **JupyterLab Integration**: Automatic browser launch with project directories
  
- **Safe by Design**: Scripts contain zero delete operations - deletion commands shown in help menu for reference only
  
- **Manifest Tracking**: Each environment records what was installed and when
  

---

## Directory Structure

After running, your system will have:

```
~/.venvs/                    # Virtual environments (hidden)
    my-env/
        bin/ or Scripts/     # Python executables
        stank-manifest.json  # Installation history

~/JupyterProjects/           # Your work (separate from envs)
    my-env/
        notebooks/
        data/
        outputs/
        scripts/
```

---

## Requirements

| Requirement | Windows | macOS |
| --- | --- | --- |
| OS  | Windows 10/11 | macOS 13+ (Ventura, Sonoma, Sequoia) |
| Python | 3.11 from python.org | 3.11+ via Homebrew |
| Other | -   | jq, Xcode CLI Tools |
| Disk | 500 MB - 12 GB | 500 MB - 12 GB |
| Internet | Required | Required |

---

## Repository Structure

```
SPVEM-StankPythonVirtualEnvironmentManager/
    README.md                          # This file
    LICENSE                            # GPL v3.0

    windows/
        README.md                      # Windows-specific docs
        stank-venv-manager.bat         # Entry point - double-click
        stank-venv-manager.ps1         # Main script (1,957 lines)
        stank-venv-packages.json       # Package definitions (413 packages)
        stank-venv-manager-readme.html # Visual HTML documentation

    macos/
        README.md                      # macOS-specific docs
        stank-venv-manager.command     # Entry point - double-click in Finder
        stank-venv-manager.sh          # Main script (2,016 lines)
        stank-venv-packages-macos.json # Package definitions (329 packages)
        stank-venv-glossary.json       # Package descriptions
        stank-venv-manager-readme-macos.html # Visual HTML documentation
```

---

## Safety

Both versions follow the same safety principles:

1. **Zero delete operations** - Scripts never remove files, folders, or environments
2. **Explicit confirmation** - Destructive commands shown in help menu only
3. **Separate work directories** - JupyterProjects is independent from environments
4. **Manifest tracking** - Know exactly what was installed

---

## Troubleshooting

See platform-specific README files:

- [Windows Troubleshooting](windows/README.md#troubleshooting)
- [macOS Troubleshooting](macos/README.md#troubleshooting)

---

## License

Copyright (C) 2026 Nick Stankiewicz

GNU General Public License v3.0

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.

See [LICENSE](LICENSE) or <https://www.gnu.org/licenses/gpl-3.0.html>

---

## Author

Created by Nick Stankiewicz

- Version: 0.1 (Beta)
- Created: 2026.01.04
- Updated: 2026.01.04
