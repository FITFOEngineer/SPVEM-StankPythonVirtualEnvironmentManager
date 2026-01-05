# SPVEM - STANK PYTHON VIRTUAL ENVIRONMENT MANAGER (Windows)

A verbose, beginner-friendly Python virtual environment manager for Windows 10/11.

**Status: Beta** - Please report issues

---

## Rationale

### The Problem

Python environment management is a mess for beginners:

1. **Too many tools** - venv, virtualenv, conda, pyenv, poetry, pipenv, pdm, hatch, uv. Which one? Nobody agrees.

2. **Silent failures** - Commands succeed with exit code 0 but nothing works. Hours wasted.

3. **No explanations** - Tutorials say "run this command" but never explain *why*. Users copy-paste without understanding.

4. **Package chaos** - "I need pandas for data science" turns into researching 50 packages and their compatibility.

5. **Reproducibility theater** - requirements.txt files that don't actually reproduce environments.

### The Solution

One script that:

- **Shows every command** before execution with explanation of what it does
- **Bundles packages by job role** - select "Data Scientist" and get 150+ relevant packages
- **Never deletes silently** - all destructive actions require confirmation
- **Fails loudly** - clear error messages with actionable fixes
- **Teaches while working** - users learn proper practices by watching the verbose output

### Design Philosophy

| Principle | Implementation |
|-----------|----------------|
| Transparency | Every command shown with WHY explanation |
| Safety | Never auto-delete; explicit opt-in for destructive actions |
| Education | Verbose output teaches environment management |
| Reproducibility | JSON config makes setups portable and consistent |
| Isolation | One environment per project, no cross-contamination |

---

## Features

- **9 job roles** with pre-configured package bundles
- **29 package sets** (413 packages) organized by purpose
- **Verbose output** explaining every step
- **Network/disk validation** before installs
- **Retry logic** for failed packages
- **Package tracking** - tracks successful and failed installs per environment
- **JSON configuration** - customize without editing code
- **JupyterLab integration** - launch directly from menu
- **Session resume** - pick up where you left off

---

## Quick Start

### Step 1: Install Python 3.11

Download from: https://www.python.org/downloads/release/python-3119/

**IMPORTANT - Installer Options:**

On the first screen:
- `[ ] Add python.exe to PATH` - **LEAVE UNCHECKED** (prevents conflicts)
- `[x] Install py launcher for all users` - **CHECK THIS**

Click "Customize installation", then on Advanced Options:
- `[ ] Add Python to environment variables` - **LEAVE UNCHECKED**

This installs Python 3.11 safely alongside any existing Python versions. Your system defaults are NOT changed.

**If you have Microsoft Store Python:** Disable it in Settings > Apps > Advanced app settings > App execution aliases. Turn OFF both `python.exe` and `python3.exe`.

### Step 2: Download Files

Download all 5 files to the **same folder**:
- `stank-venv-manager.bat` (launcher)
- `stank-venv-manager.ps1` (main script)
- `stank-venv-packages.json` (package definitions)
- `stank-venv-manager-readme.html` (documentation)
- `README.md` (this file)

### Step 3: Run

```
Double-click: stank-venv-manager.bat
```

That's it! The .bat file handles PowerShell execution policy automatically.

> **Why use the .bat file?** It bypasses PowerShell execution policy restrictions without requiring admin rights or permanent system changes. Just double-click and go.

### Verify Installation

Open Command Prompt and run:
```
py --list
py -3.11 --version
```

You should see Python 3.11.x listed.

---

## Files

| File | Purpose |
|------|---------|
| `stank-venv-manager.bat` | **START HERE** - Double-click to launch |
| `stank-venv-manager.ps1` | Main PowerShell script (1,957 lines) |
| `stank-venv-packages.json` | Package configurations (413 packages, 29 sets) |
| `stank-venv-manager-readme.html` | Visual documentation (open in browser) |
| `README.md` | This documentation |

---

## Job Roles

Pre-configured for real job titles:

| Role | Packages | Install Time | Disk |
|------|----------|--------------|------|
| Data Scientist | 158 | 50-80 min | 5 GB |
| Data Analyst | 111 | 25-40 min | 1.5 GB |
| Data Engineer | 199 | 45-70 min | 3 GB |
| Machine Learning Engineer | 204 | 60-90 min | 6 GB |
| Security Analyst | 152 | 35-55 min | 2 GB |
| Backend Developer | 155 | 30-50 min | 1.5 GB |
| DevOps Engineer | 139 | 35-55 min | 1.5 GB |
| Document Automation Specialist | 123 | 30-50 min | 1.2 GB |
| Full Stack Developer | 180 | 40-65 min | 2 GB |

---

## Package Sets

29 atomic sets that can be mixed and matched:

**Core:** JupyterLab, Data Science, Data Formats, Math/Scientific

**ML:** Deep Learning (PyTorch/TensorFlow), LLM & AI (OpenAI/Anthropic/LangChain)

**Web:** Web Scraping, API & Web Services (FastAPI/Flask/Django)

**Security:** Cybersecurity, Network Analysis

**Files:** PDF Tools, Document Creation, Office Docs, Image/OCR, Archives, Email, Audio/Video

**Dev:** Databases, Multithreading, Templates, CLI & REPL, Automation/RPA

**DevOps:** Testing, Logging, Log Parsing, Cloud SDKs

**Data:** Text Processing & NLP, Geospatial & Mapping, Financial & Trading

---

## Menu

```
  [0] RESUME last session

  CREATE
    1  Empty environment
    2  With JupyterLab
    3  Data Science starter
    4  By Job Role
    5  Full install (all 413 packages)

  USE
    6  View / Launch environments
    7  Add packages to environment
    S  Show running Jupyter sessions

  HELP
    8  Manual activation / directories / requirements

    Q  Quit
```

---

## Directory Structure

```
%USERPROFILE%\
├── .venvs\                     # Environments (auto-created)
│   ├── my-project\
│   │   └── Scripts\python.exe
│   └── .last-session.json
│
└── JupyterProjects\            # Your work (BACK THIS UP)
    └── my-project\
        ├── notebooks\
        ├── data\
        └── outputs\
```

---

## Requirements

| Requirement | Details |
|-------------|---------|
| OS | Windows 10/11 |
| Python | **3.11 only** from python.org (NOT 3.12+, NOT Microsoft Store) |
| Disk | 500 MB - 12 GB |

### Why Python 3.11 Only?

This tool **requires Python 3.11** - not 3.12, not 3.13, not 3.10. Here's why:

- **Python 3.12+ breaks packages** - The `distutils` module was removed, causing many data science and ML packages to fail
- **Python 3.10 and earlier** - Missing performance improvements and some package support
- **Python 3.11 is the sweet spot** - Mature, fast, widely tested, supported until October 2027

### Installing Python 3.11 (Safe - Won't Change Defaults)

```
1. Download: https://www.python.org/downloads/release/python-3119/
2. Run installer with these options:
   [x] Install py launcher for all users
   [ ] Add Python to PATH  (optional - not required)
3. Restart this script
```

**Python 3.11 coexists safely with other versions.** Your existing Python installation and system defaults are NOT changed. This tool uses `py -3.11` to specifically target Python 3.11.

### External Dependencies (some packages)

Some packages require external software to be installed separately:

| Package | Requires | Install |
|---------|----------|---------|
| pytesseract | Tesseract-OCR | https://github.com/UB-Mannheim/tesseract/wiki |
| tabula-py | Java Runtime 8+ | https://adoptium.net/ (set JAVA_HOME) |
| pyshark | Wireshark/tshark | https://www.wireshark.org/download.html |
| playwright | Browser binaries | Run: `playwright install` after pip install |
| scapy | Npcap driver | https://npcap.com/#download |
| python-nmap | Nmap | https://nmap.org/download.html |

### Windows-Specific Limitations

| Package | Limitation | Workaround |
|---------|------------|------------|
| **TensorFlow GPU** | CPU only on native Windows | Use WSL2 for GPU, or use PyTorch instead |
| **LightGBM GPU** | No Windows GPU wheels | CPU only, or use Linux/WSL2 |
| **Ansible** | Cannot run as control node | Use WSL2 or Docker |

### Cybersecurity Packages - Antivirus Warning

> **WARNING:** Security research tools like `yara-python`, `scapy`, and `oletools` may trigger Windows Defender or other antivirus software as "potentially unwanted" or "hacking tools." These are legitimate packages used by security professionals, but their capabilities can be flagged as malicious. If you install the Security Analyst role or cybersecurity package set, you may need to add an exclusion for your `~/.venvs` folder in Windows Security settings.

### Prerequisites for Some Packages

**Visual C++ Redistributable** - Required for XGBoost, LightGBM, faiss-cpu:
- Download: https://aka.ms/vs/17/release/vc_redist.x64.exe

---

## Why pip (not uv)

This tool uses **pip** instead of the newer **uv** package manager:

- **Pre-installed** - pip comes with Python, no extra setup
- **Familiar** - most tutorials and docs use pip
- **Stable** - mature tooling, predictable behavior
- **Beginner-friendly** - one less thing to install/learn

uv is 10-100x faster but requires separate installation. May add as optional mode in future versions.

---

## Customization

Edit `stank-venv-packages.json` to add packages, create sets, or define roles. Script falls back to defaults if JSON is invalid.

---

## Deleting Environments

**This script contains zero delete operations.** It never removes files, folders, or environments. The help menu shows deletion commands for reference only - you must run them yourself in a separate PowerShell window.

To remove manually:

```powershell
# List environments
Get-ChildItem $env:USERPROFILE\.venvs

# Delete one environment
Remove-Item -Recurse -Force $env:USERPROFILE\.venvs\<name>

# Delete project folder (optional - contains your notebooks)
Remove-Item -Recurse -Force $env:USERPROFILE\JupyterProjects\<name>
```

Your work in `JupyterProjects` is separate from environments - back it up before cleanup.

---

## Troubleshooting

**"Running scripts is disabled"**
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**"Python not found"**
- Reinstall from python.org with "Add to PATH"
- Restart terminal

**Package failed**
- Check internet
- Install Visual C++ Build Tools
- Check system requirements section


---

## Appendix: Excluded Packages

### impacket (Not Included)

**What it is:** A collection of Python classes for working with network protocols. Used by security professionals for penetration testing, network protocol analysis, and security research.

**Why excluded:** This package frequently triggers antivirus/EDR software as "hacking tools" or "potentially unwanted software." While legitimate for security research, the false positive rate causes installation failures and user confusion.

**To install separately:**
```powershell
# In an activated environment
pip install impacket
```

**Note:** You may need to add your `.venvs` folder to Windows Defender exclusions if installation fails or files are quarantined.

---

## License

Copyright (C) 2026 Nick Stankiewicz

GNU General Public License v3.0

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.

See [LICENSE](LICENSE) or <https://www.gnu.org/licenses/gpl-3.0.html>

---

## Author

Created by Nick Stankiewicz on 2026.01.04
Updated: 2026.01.04 - Version 0.1 (Beta)
