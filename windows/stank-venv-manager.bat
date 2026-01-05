@echo off
REM ============================================================================
REM Filename: stank-venv-manager.bat
REM Created by Nick Stankiewicz on 2026.01.04
REM Updated: 2026.01.04 - Version 0.1 (Beta)
REM Stank Python Virtual Environment Manager - Launcher (Windows 10/11)
REM Status: Beta - Please report issues
REM
REM Copyright (C) 2026 Nick Stankiewicz
REM This program is free software: you can redistribute it and/or modify
REM it under the terms of the GNU General Public License as published by
REM the Free Software Foundation, version 3 of the License.
REM This program is distributed in the hope that it will be useful,
REM but WITHOUT ANY WARRANTY; without even the implied warranty of
REM MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
REM GNU General Public License for more details.
REM You should have received a copy of the GNU General Public License
REM along with this program.  If not, see <https://www.gnu.org/licenses/>.
REM ============================================================================

echo.
echo ============================================================================
echo   STANK PYTHON VIRTUAL ENVIRONMENT MANAGER - LAUNCHER
echo   Created by Nick Stankiewicz on 2026.01.04
echo ============================================================================
echo.

if not exist "%~dp0stank-venv-manager.ps1" (
    echo   [ERROR] CANNOT FIND: stank-venv-manager.ps1
    echo.
    echo   Make sure stank-venv-manager.ps1 is in the SAME folder as this .bat file
    echo   Current folder: %~dp0
    echo.
    pause
    exit /b 1
)

echo   [OK] Found stank-venv-manager.ps1
echo.
echo   Command: powershell.exe -ExecutionPolicy Bypass -NoProfile -File "stank-venv-manager.ps1"
echo.
echo ============================================================================
echo   STARTING...
echo ============================================================================
echo.

powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0stank-venv-manager.ps1"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ============================================================================
    echo   [ERROR] SCRIPT FAILED (Code: %ERRORLEVEL%)
    echo ============================================================================
    echo.
    echo   Common fixes:
    echo     1. Run: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
    echo     2. Install Python 3.11 from https://www.python.org/downloads/
    echo        (Python 3.11 recommended for best compatibility)
    echo     3. Add script folder to antivirus exceptions
    echo.
    pause
)

exit /b 0
