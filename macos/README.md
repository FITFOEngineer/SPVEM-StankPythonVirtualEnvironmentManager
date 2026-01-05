# SPVEM - STANK PYTHON VIRTUAL ENVIRONMENT MANAGER (macOS)

A verbose, beginner-friendly **Python 3.11** virtual environment manager for macOS and Apple Silicon.

---

## Why This Project?

**Python environment setup is unnecessarily hard.** New developers and data scientists face a maze of decisions: Which Python version? venv or conda? pip or pip3? Why won't TensorFlow install? What's this "externally-managed-environment" error?

This tool eliminates those frustrations by providing:

### 🎯 One-Command Setup

Instead of researching which packages you need, hunting down compatibility issues, and debugging cryptic errors, just pick your job role. A Data Scientist gets pandas, scikit-learn, matplotlib, and 120+ validated packages installed automatically.

### 🍎 Apple Silicon Done Right

M1/M2/M3 Macs have incredible ML capabilities, but unlocking GPU acceleration requires specific packages and configurations. This tool installs PyTorch with MPS backend, TensorFlow with Metal plugin, and Apple's MLX framework, all pre-validated to work together.

### 📦 Curated, Not Chaotic

The 329 packages aren't random. They're organized into 31 logical sets (databases, web scraping, PDF tools, etc.) that you can mix and match. Each package is tested for Python 3.11 compatibility, avoiding the dependency conflicts that plague pip installs.

### 🔰 Beginner-Friendly by Design

Every action shows exactly what's happening and why. Progress bars, colored output, package descriptions during install, and plain-English explanations replace silent failures and stack traces. If something goes wrong, you'll know what and how to fix it.

### 💾 Your Work Stays Safe

The script never deletes environments, never overwrites files, and maintains a manifest of everything installed. Experiment freely. Your notebooks and data remain untouched in `~/JupyterProjects`.

---

## Features

- **Python 3.11** - Explicitly requires Python 3.11 for maximum package compatibility
- **9 Job Roles** - Pre-configured package sets for Data Scientists, ML Engineers, etc.
- **31 Package Sets** - 329 curated packages validated for Python 3.11 on macOS
- **Apple Silicon GPU** - PyTorch MPS, TensorFlow Metal, MLX frameworks
- **JupyterLab** - Auto-launch with proper environment activation
- **Session Resume** - Press Enter to continue where you left off (default)
- **Package Tracking** - Manifest tracks all installed packages per environment
- **Safety First** - Never deletes or overwrites existing files
- **Auto-Install** - Offers to install Python 3.11 and jq via Homebrew if missing

---

## Safety Guarantees

This script is designed to **never delete or overwrite** your data:

| Protection | Description |
| --- | --- |
| **Existing environments** | Refuses to create if name already exists |
| **Project directories** | Preserves existing files, only adds missing subdirs |
| **Package tracking** | Manifest tracks all installed sets and packages |
| **Duplicate installs** | Skips package sets already installed |
| **No delete function** | Script cannot delete environments (manual only) |

Each environment contains a `stank-manifest.json` tracking:

- Python version
- All installed package sets
- All individual packages
- Job roles applied
- Linked project directory
- Installation history with timestamps

---

## Quick Start

```bash
# 1. Install prerequisites (copy and paste entire block)
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
source ~/.zprofile
brew install jq python@3.11

# 2. Download all 6 files to the same folder

# 3. Make executable and run
xattr -d com.apple.quarantine stank-venv-manager.command stank-venv-manager.sh; chmod +x stank-venv-manager.command stank-venv-manager.sh
./stank-venv-manager.sh

# OR double-click stank-venv-manager.command in Finder
# First time: Right-click → Open (to bypass Gatekeeper)
```

> **Why Python 3.11?** Python 3.11 offers the best package compatibility. Many data science and ML packages still have issues with Python 3.12+ (distutils removed, dependency conflicts). Python 3.11 is the "sweet spot" - mature, fast, widely tested, and supported until October 2027.

---

## Files

| File | Purpose |
| --- | --- |
| `stank-venv-manager.command` | **START HERE** - Double-click in Finder |
| `stank-venv-manager.sh` | Main bash script (2,016 lines) |
| `stank-venv-packages-macos.json` | Package configurations (329 packages, 31 sets) |
| `stank-venv-glossary.json` | Package descriptions (315 entries) |
| `stank-venv-manager-readme-macos.html` | Visual documentation (open in browser) |
| `README.md` | This documentation |

---

## Requirements

| Requirement | Details | Auto-Install |
| --- | --- | --- |
| OS  | macOS 13+ (Ventura, Sonoma, Sequoia) | -   |
| Hardware | Apple Silicon (M1/M2/M3) or Intel | -   |
| Python | 3.11+ (3.11 recommended) | ✓ via Homebrew |
| jq  | JSON parser | ✓ via Homebrew |
| Disk | 500 MB - 12 GB depending on selection | -   |

> **Note:** If Python 3.11+ or jq is missing, the script will detect this and offer to install via Homebrew automatically.

### Required Tools

```bash
# Install all prerequisites at once
xcode-select --install
brew install jq python@3.11
```

| Tool | Install | Purpose |
| --- | --- | --- |
| Xcode CLI | `xcode-select --install` | Compilers, git, Unix tools |
| Homebrew | See brew.sh | Package manager for macOS |
| jq  | `brew install jq` | JSON parsing (required by script) |
| Python 3.11 | `brew install python@3.11` | Python runtime (recommended) |

---

## Apple Silicon (M1/M2/M3) Notes

### GPU Acceleration

| Framework | Package | Notes |
| --- | --- | --- |
| PyTorch | `torch` | MPS backend automatic |
| TensorFlow | `tensorflow` + `tensorflow-metal` | Metal acceleration |
| MLX | `mlx` | Apple's native ML framework |

### Verify Native ARM64

```bash
# Check Python architecture
python3 -c "import platform; print(platform.machine())"
# Should print: arm64

# If it prints x86_64, Python is running under Rosetta 2 (20-30% slower)
# Install native ARM64 Python:
brew uninstall python@3.11
arch -arm64 brew install python@3.11
```

### Unified Memory Advantage

Apple Silicon's unified memory architecture means:

- No PCIe bottleneck between CPU and GPU
- Larger models can fit in "GPU memory" (it's all the same RAM)
- Fast data transfer for ML training

---

## Directory Structure

```
~/
├── .venvs/                     # Virtual environments (auto-created)
│   ├── my-project/
│   │   ├── bin/
│   │   │   ├── python          # Environment's Python
│   │   │   ├── pip             # Environment's pip
│   │   │   ├── activate        # Activation script
│   │   │   └── jupyter         # JupyterLab (if installed)
│   │   ├── lib/                # Installed packages
│   │   └── stank-manifest.json # Tracks installed sets
│   └── .last-session.json      # Resume state
│
└── JupyterProjects/            # Your work (BACK THIS UP!)
    └── my-project/
        ├── notebooks/          # Jupyter notebooks (.ipynb)
        ├── data/               # Input data files
        ├── outputs/            # Generated outputs
        └── scripts/            # Python scripts (.py)
```

> **Important:** Your work in `JupyterProjects` is separate from environments in `.venvs`. Deleting an environment does NOT delete your notebooks and data.

---

## Menu

```
  ┌──────────────────────────────────────────────────────────────┐
  │         STANK PYTHON VENV MANAGER v0.1  (macOS)              │
  └──────────────────────────────────────────────────────────────┘

  [0]  Resume: <last-environment>  ← Enter (default)

  CREATE
  [1]  Empty environment
  [2]  With JupyterLab
  [3]  By Job Role              9 professional roles
  [4]  Full install             329 packages

  USE
  [5]  View / Launch environments
  [6]  Add packages to environment
  [S]  Show running sessions

  HELP
  [7]  Manual commands & directories

  [Q]  Quit

  Select [0]: _
```

**Default behavior:** Pressing Enter without typing anything resumes your last session.

---

## Job Roles

| Role | Packages | Install Time | Disk |
| --- | --- | --- | --- |
| Data Scientist | 124 | 50-80 min | 5 GB |
| Data Analyst | 81  | 25-40 min | 1.5 GB |
| Data Engineer | 141 | 45-70 min | 3 GB |
| Machine Learning Engineer | 149 | 60-90 min | 6 GB |
| Security Analyst | 124 | 35-55 min | 2 GB |
| Backend Developer | 92  | 30-50 min | 1.5 GB |
| DevOps Engineer | 96  | 35-55 min | 1.5 GB |
| Document Automation Specialist | 95  | 30-50 min | 1.2 GB |
| Full Stack Developer | 115 | 40-65 min | 2 GB |

> ⚠️ **Antivirus Warning (Security Analyst Role):** Some packages in the Security Analyst role and Cybersecurity/Network Analysis package sets may trigger antivirus or endpoint protection alerts. Tools like `scapy`, `impacket`, `python-nmap`, `yara-python`, and `pefile` are legitimate security research tools, but they use techniques that security software may flag as potentially malicious. You may need to whitelist your `~/.venvs/` folder or add exceptions for specific packages. This is normal for penetration testing and security analysis tools.

---

## External Dependencies

Some packages require additional system tools:

| Package | Requires | Install |
| --- | --- | --- |
| pytesseract | Tesseract-OCR | `brew install tesseract` |
| tabula-py | Java Runtime | `brew install openjdk` |
| camelot-py | Ghostscript | `brew install ghostscript` |
| pyshark | Wireshark | `brew install wireshark` |
| pyaudio | PortAudio | `brew install portaudio` |
| ffmpeg-python | FFmpeg | `brew install ffmpeg` |
| geopandas | GDAL | `brew install gdal` |
| playwright | Browser binaries | `playwright install` |
| spacy | Language models | `python -m spacy download en_core_web_sm` |
| nltk | Data files | `python -c "import nltk; nltk.download('popular')"` |

---

## Tips & Tricks

### 1. Speed Up Package Installation

```bash
# Use pip's cache (enabled by default)
# Cache location: ~/Library/Caches/pip

# Pre-download packages for offline install
pip download -d ./packages numpy pandas matplotlib
pip install --no-index --find-links=./packages numpy pandas matplotlib
```

### 2. Check What's Installed

```bash
# Activate environment first
source ~/.venvs/<env-name>/bin/activate

# List all packages
pip list

# Show specific package info
pip show numpy

# Check for outdated packages
pip list --outdated
```

### 3. Export & Reproduce Environments

```bash
# Export exact versions (for reproduction)
pip freeze > requirements.txt

# Export without versions (for flexibility)
pip list --format=freeze | cut -d'=' -f1 > requirements-loose.txt

# Recreate environment elsewhere
python3 -m venv ~/.venvs/new-env
source ~/.venvs/new-env/bin/activate
pip install -r requirements.txt
```

### 4. JupyterLab Tips

```bash
# Start on specific port (if 8888 is busy)
jupyter lab --port=8889

# Start without opening browser
jupyter lab --no-browser

# List running servers
jupyter server list

# Stop all servers
jupyter server stop

# Install JupyterLab extensions
pip install jupyterlab-git jupyterlab-lsp
```

### 5. Using PyTorch with MPS (Metal)

```python
import torch

# Check MPS availability
print(f"MPS available: {torch.backends.mps.is_available()}")
print(f"MPS built: {torch.backends.mps.is_built()}")

# Use MPS device
device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")
print(f"Using device: {device}")

# Move tensors/models to MPS
tensor = torch.randn(3, 3).to(device)
model = model.to(device)
```

### 6. Using TensorFlow with Metal

```python
import tensorflow as tf

# Check GPU availability
gpus = tf.config.list_physical_devices('GPU')
print(f"GPUs available: {gpus}")

# TensorFlow automatically uses Metal if available
# No device placement needed for most cases
```

### 7. Multiple Python Versions

```bash
# Install multiple versions
brew install python@3.11 python@3.12

# Create env with specific version
/opt/homebrew/opt/python@3.11/bin/python3 -m venv ~/.venvs/py311-env
/opt/homebrew/opt/python@3.12/bin/python3 -m venv ~/.venvs/py312-env
```

### 8. Keyboard Shortcuts in Terminal

| Shortcut | Action |
| --- | --- |
| Ctrl+C | Stop current process (e.g., Jupyter) |
| Ctrl+D | Exit Python REPL / deactivate |
| Ctrl+Z | Suspend process (use `fg` to resume) |
| Ctrl+L | Clear terminal screen |
| Tab | Autocomplete paths/commands |

### 9. Quick Environment Switching

```bash
# Add to ~/.zshrc for quick activation
function venv() {
    source ~/.venvs/$1/bin/activate
}

# Usage: venv my-project
```

### 10. Disk Space Management

```bash
# Check environment sizes
du -sh ~/.venvs/*/

# Clear pip cache (saves space)
pip cache purge

# Remove unused environments
rm -rf ~/.venvs/<unused-env>
```

---

## Manual Commands

### Activate Environment

```bash
source ~/.venvs/<env-name>/bin/activate

# Your prompt will change to show (env-name)
# Example: (my-project) user@mac ~ %
```

### Deactivate

```bash
deactivate
```

### Check Active Environment

```bash
# Shows path if in venv, empty if not
echo $VIRTUAL_ENV

# Or check which Python
which python
```

### Install Single Package

```bash
# Activate first, then:
pip install package-name

# Specific version
pip install numpy==1.26.0

# Upgrade existing
pip install --upgrade pandas
```

### Uninstall Package

```bash
pip uninstall package-name
```

### Export Requirements

```bash
source ~/.venvs/<env>/bin/activate
pip freeze > requirements.txt
```

### Install from Requirements

```bash
pip install -r requirements.txt
```

---

## Deleting Environments

**This script contains zero delete operations.** It never removes files, folders, or environments.

To remove manually:

```bash
# 1. First, stop any Jupyter sessions using this environment
#    (Check with menu option S, or: jupyter server list)

# 2. List all environments
ls -la ~/.venvs/

# 3. Delete the environment
rm -rf ~/.venvs/<env-name>

# 4. Optionally delete the project folder (contains your work!)
#    BACK UP FIRST if you have important notebooks/data
rm -rf ~/JupyterProjects/<env-name>
```

---

## Troubleshooting

### Script Won't Run

**"zsh: permission denied"**

```bash
chmod +x stank-venv-manager.sh stank-venv-manager.command
```

**Gatekeeper blocks script (macOS security)**

```bash
# Option 1: Right-click → Open in Finder

# Option 2: Remove quarantine flag
xattr -d com.apple.quarantine stank-venv-manager.command
xattr -d com.apple.quarantine stank-venv-manager.sh
```

**"Operation not permitted" errors**

```bash
# Grant Terminal full disk access:
# System Settings → Privacy & Security → Full Disk Access → Add Terminal
```

---

### Python Issues

**"command not found: python"**

```bash
# Option 1: Use python3 explicitly
python3 --version

# Option 2: Create alias (add to ~/.zshrc)
echo 'alias python="python3"' >> ~/.zshrc
source ~/.zshrc

# Option 3: Install Python
brew install python@3.12
```

**"Python not found" in script**

```bash
# Check if Python is in PATH
which python3

# If using Homebrew Python, ensure shell is configured
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
source ~/.zprofile
```

**Wrong Python version**

```bash
# Check version
python3 --version

# Install correct version
brew install python@3.12

# Use specific version
/opt/homebrew/opt/python@3.12/bin/python3 --version
```

**Python running under Rosetta 2 (x86_64 on Apple Silicon)**

```bash
# Check architecture
python3 -c "import platform; print(platform.machine())"

# If it shows x86_64, reinstall native Python:
brew uninstall python@3.12
brew install python@3.12

# Or check if Terminal is running under Rosetta:
# Get Info on Terminal.app → uncheck "Open using Rosetta"
```

---

### Homebrew Issues

**"brew: command not found"**

```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add to PATH (Apple Silicon)
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
source ~/.zprofile
```

**"jq: command not found"**

```bash
brew install jq
```

**Homebrew packages not found after install**

```bash
# Reload shell configuration
source ~/.zprofile
source ~/.zshrc

# Or restart Terminal
```

---

### Package Installation Issues

**"ERROR: Could not build wheels"**

```bash
# Install/update Xcode Command Line Tools
xcode-select --install

# If already installed, try reinstalling
sudo rm -rf /Library/Developer/CommandLineTools
xcode-select --install
```

**Package needs specific system dependency**

```bash
# Check error message for hints, common fixes:
brew install openssl readline sqlite3 xz zlib  # Common build deps
brew install pkg-config  # For packages that use pkg-config
```

**SSL/TLS errors during pip install**

```bash
# Update certificates
pip install --upgrade certifi

# Or use trusted hosts
pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org package-name
```

**pip install hangs or times out**

```bash
# Check network
curl -I https://pypi.org

# Use different mirror
pip install -i https://pypi.org/simple/ package-name

# Increase timeout
pip install --timeout 100 package-name
```

---

### JupyterLab Issues

**"jupyter: command not found"**

```bash
# Make sure environment is activated
source ~/.venvs/<env-name>/bin/activate

# Install JupyterLab
pip install jupyterlab
```

**Port already in use**

```bash
# Find what's using port 8888
lsof -i :8888

# Use different port
jupyter lab --port=8889

# Or kill existing process
kill -9 <PID>
```

**Kernel not found / wrong kernel**

```bash
# List kernels
jupyter kernelspec list

# Install kernel for current environment
pip install ipykernel
python -m ipykernel install --user --name=<env-name>

# Remove old kernel
jupyter kernelspec uninstall <kernel-name>
```

**Browser doesn't open**

```bash
# Start with URL displayed
jupyter lab --no-browser
# Then manually open: http://localhost:8888/lab
```

---

### GPU/ML Issues

**PyTorch MPS not available**

```python
import torch
print(torch.backends.mps.is_available())  # Should be True
print(torch.backends.mps.is_built())      # Should be True

# If False, reinstall PyTorch
# pip uninstall torch torchvision torchaudio
# pip install torch torchvision torchaudio
```

**TensorFlow not seeing GPU**

```python
import tensorflow as tf
print(tf.config.list_physical_devices('GPU'))

# If empty list, install tensorflow-metal
# pip install tensorflow-metal
```

**"MPS backend out of memory"**

```python
# Reduce batch size
# Or set environment variable to use less memory
import os
os.environ['PYTORCH_MPS_HIGH_WATERMARK_RATIO'] = '0.0'
```

---

### Common Error Messages

| Error | Cause | Fix |
| --- | --- | --- |
| `ModuleNotFoundError` | Package not installed | `pip install <package>` |
| `Permission denied` | Need chmod or sudo | `chmod +x file.sh` |
| `command not found` | Not in PATH | Check PATH or install tool |
| `No such file or directory` | Wrong path | Check path exists with `ls` |
| `Connection refused` | Service not running | Start the service |
| `Killed: 9` | Out of memory | Reduce batch size / close apps |

---

## macOS Sequoia (15.x) Notes

- **Gatekeeper**: First run requires right-click → Open
- **Network permissions**: Script may trigger "allow network access" dialogs - click Allow
- **Accessibility**: Some automation packages need System Settings → Privacy & Security → Accessibility
- **Input Monitoring**: Packages like `pynput` need Input Monitoring permission

---

## Best Practices

1. **One environment per project** - Keeps dependencies isolated
2. **Back up JupyterProjects regularly** - Your work is precious
3. **Use requirements.txt** - Makes environments reproducible
4. **Don't install packages globally** - Always use virtual environments
5. **Check disk space before full install** - Need 10-12 GB free
6. **Stop Jupyter before deleting environment** - Avoid orphaned processes
7. **Use native ARM64 Python on Apple Silicon** - 20-30% faster

---

## Troubleshooting

### "command not found: python3.11"

Python 3.11 is not in your PATH.

**Fix:**

```bash
# Add to ~/.zshrc or ~/.bash_profile:
export PATH="/opt/homebrew/opt/python@3.11/bin:$PATH"

# Then reload:
source ~/.zshrc
```

### "jq: command not found"

jq is required for parsing JSON configuration.

**Fix:**

```bash
brew install jq
```

### "externally-managed-environment" error

This happens if you try to pip install globally on macOS.

**Fix:** Always use virtual environments (this script creates them for you).

### Script won't run / "Permission denied"

**Fix:**

```bash
chmod +x stank-venv-manager.sh
```

### "Operation not permitted" or Gatekeeper block

**Fix:**

```bash
xattr -d com.apple.quarantine stank-venv-manager.sh
```

### Python running under Rosetta (x86_64 on Apple Silicon)

If you see a warning about Rosetta emulation:

**Fix:**

```bash
# Install native ARM64 Python
brew uninstall python@3.11
brew install python@3.11
```

### Package installation fails

1. Check internet connection: `curl -Is https://pypi.org | head -1`
2. Check disk space: `df -h ~`
3. Try running the script again (it will retry failed packages)

### Jupyter won't start

1. Ensure JupyterLab is installed in the environment
2. Check if port 8888 is already in use: `lsof -i :8888`
3. Try a different port from the script menu

---

## Getting Help

1. **Script help menu**: Press `8` in the main menu
2. **This README**: You're reading it!
3. **HTML documentation**: Open `stank-venv-manager-readme-macos.html` in browser
4. **Python docs**: https://docs.python.org/3/
5. **pip docs**: https://pip.pypa.io/
6. **Homebrew docs**: https://docs.brew.sh/

---

## License

Copyright (C) 2026 Nick Stankiewicz

GNU General Public License v3.0

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.

---

## Author

Created by Nick Stankiewicz

- Version: 0.1 (Beta)
- Created: 2026.01.04
- Updated: 2026.01.04
