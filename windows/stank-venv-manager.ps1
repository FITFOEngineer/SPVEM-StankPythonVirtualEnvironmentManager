<#
.SYNOPSIS
    Stank Python Virtual Environment Manager for Windows 10/11
.DESCRIPTION
    Filename: stank-venv-manager.ps1
    Every command shown with full explanation of WHAT and WHY.
    Designed for learning and complete transparency.
    Supports package sets and job roles from stank-venv-packages.json
.NOTES
    Requires: Python 3.11+ from python.org (3.11 recommended)
    Python 3.11 provides the best package compatibility.
    Python 3.12+ works but some packages may have issues.
    Status: Beta - Please report issues
.AUTHOR
    Created by Nick Stankiewicz on 2026.01.04
    Updated: 2026.01.04 - Version 0.1 (Beta)
.LICENSE
    Copyright (C) 2026 Nick Stankiewicz
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, version 3 of the License.
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
#>

# ============================================================================
# Filename: stank-venv-manager.ps1
# Created by Nick Stankiewicz on 2026.01.04
# Stank Python Virtual Environment Manager v0.1 (Beta) for Windows 10/11
# ============================================================================

# ============================================================================
# CONFIGURATION
# ============================================================================

$script:VENV_DIR = "$HOME\.venvs"
$script:PROJECTS_DIR = "$HOME\JupyterProjects"
$script:STATE_FILE = "$HOME\.venvs\.last-session.json"
$script:PACKAGES_FILE = Join-Path $PSScriptRoot "stank-venv-packages.json"
$script:PYTHON = "python"
$script:PYTHON_ARGS = @()  # Additional args for py launcher (e.g., "-3.11")
$script:MAX_PARALLEL_JOBS = 4
$script:PackageConfig = $null
$script:MIN_DISK_GB = 2
$script:RETRY_ATTEMPTS = 3
$script:RETRY_DELAY_SEC = 5

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 78) -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ("=" * 78) -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([int]$Num, [string]$Title)
    Write-Host ""
    Write-Host "  STEP $Num : $Title" -ForegroundColor Yellow
    Write-Host "  $("-" * 72)" -ForegroundColor DarkGray
}

function Write-Why {
    param([string]$Message)
    Write-Host "  WHY: $Message" -ForegroundColor Magenta
}

function Write-Command {
    param([string]$Cmd)
    Write-Host ""
    Write-Host "  RUNNING:" -ForegroundColor Cyan
    Write-Host "  > $Cmd" -ForegroundColor White
    Write-Host ""
}

function Write-OK {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Err {
    param([string]$Message)
    Write-Host "  [ERROR] $Message" -ForegroundColor Red
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  [WARNING] $Message" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$Message)
    Write-Host "  [INFO] $Message" -ForegroundColor Gray
}

function Write-Detail {
    param([string]$Message)
    Write-Host "         $Message" -ForegroundColor DarkGray
}

function Write-Progress2 {
    param([string]$Message)
    Write-Host "  [WORKING] $Message" -ForegroundColor Yellow -NoNewline
}

function Write-ProgressDone {
    param([string]$Message = "Done!")
    Write-Host " $Message" -ForegroundColor Green
}

function Write-ProgressItem {
    param([int]$Current, [int]$Total, [string]$Name, [string]$Status, [string]$Time = "")
    $pct = [math]::Round(($Current / $Total) * 100)
    $statusColor = switch ($Status) {
        "OK" { "Green" }
        "FAILED" { "Red" }
        "SKIP" { "Yellow" }
        default { "Gray" }
    }
    $timeStr = if ($Time) { " ($Time)" } else { "" }
    Write-Host ("  [{0,3}%] [{1}/{2}] {3,-30} " -f $pct, $Current, $Total, $Name) -NoNewline
    Write-Host "[$Status]$timeStr" -ForegroundColor $statusColor
}

function Pause {
    Write-Host ""
    Write-Host "  Press ENTER to continue..." -ForegroundColor DarkGray -NoNewline
    Read-Host | Out-Null
}

function Confirm-Action {
    param([string]$Prompt)
    Write-Host ""
    $response = Read-Host "    $Prompt [y/N]"
    return ($response -eq 'y' -or $response -eq 'Y' -or $response -eq 'yes')
}

# ============================================================================
# VALIDATION & ERROR HANDLING
# ============================================================================

function Test-NetworkConnection {
    Write-Info "Checking network connectivity..."
    try {
        $result = Test-NetConnection -ComputerName "pypi.org" -Port 443 -WarningAction SilentlyContinue -ErrorAction Stop
        if ($result.TcpTestSucceeded) {
            Write-OK "Network OK (pypi.org reachable)"
            return $true
        }
    }
    catch { }
    
    # Fallback test
    try {
        $response = Invoke-WebRequest -Uri "https://pypi.org" -Method Head -TimeoutSec 10 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-OK "Network OK"
            return $true
        }
    }
    catch { }
    
    Write-Err "Cannot reach pypi.org"
    Write-Detail "Check your internet connection or firewall settings"
    return $false
}

function Test-DiskSpace {
    param([int]$RequiredGB = $script:MIN_DISK_GB)
    
    Write-Info "Checking disk space..."
    try {
        $drive = (Get-Item $HOME).PSDrive.Name
        $freeGB = [math]::Round((Get-PSDrive $drive).Free / 1GB, 1)
        
        if ($freeGB -lt $RequiredGB) {
            Write-Err "Low disk space: ${freeGB}GB free (need ${RequiredGB}GB)"
            return $false
        }
        Write-OK "Disk space OK: ${freeGB}GB free"
        return $true
    }
    catch {
        Write-Warn "Could not check disk space"
        return $true
    }
}

function Test-PackageExists {
    param([string]$PackageName)
    try {
        $uri = "https://pypi.org/pypi/$PackageName/json"
        $response = Invoke-WebRequest -Uri $uri -Method Head -TimeoutSec 5 -ErrorAction Stop
        return ($response.StatusCode -eq 200)
    }
    catch {
        return $false
    }
}

# ============================================================================
# DISK USAGE FUNCTIONS
# ============================================================================

function Get-FolderSize {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    try {
        $size = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | 
                 Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        if ($null -eq $size) { return 0 }
        return $size
    }
    catch { return 0 }
}

function Format-FileSize {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    elseif ($Bytes -ge 1MB) { return "{0:N1} MB" -f ($Bytes / 1MB) }
    elseif ($Bytes -ge 1KB) { return "{0:N0} KB" -f ($Bytes / 1KB) }
    else { return "$Bytes B" }
}

function Get-DiskUsageSummary {
    $envSize = Get-FolderSize -Path $script:VENV_DIR
    $projSize = Get-FolderSize -Path $script:PROJECTS_DIR
    $totalSize = $envSize + $projSize
    return [PSCustomObject]@{
        EnvironmentsSize = $envSize
        ProjectsSize = $projSize
        TotalSize = $totalSize
        EnvironmentsSizeFormatted = Format-FileSize -Bytes $envSize
        ProjectsSizeFormatted = Format-FileSize -Bytes $projSize
        TotalSizeFormatted = Format-FileSize -Bytes $totalSize
    }
}

# ============================================================================
# PACKAGE CONFIGURATION LOADER
# ============================================================================

function Load-PackageConfig {
    if (-not (Test-Path $script:PACKAGES_FILE)) {
        Write-Warn "Package config not found: $script:PACKAGES_FILE"
        Write-Detail "Using built-in defaults"
        return $null
    }
    
    try {
        $config = Get-Content $script:PACKAGES_FILE -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $setCount = ($config.package_sets.PSObject.Properties | Measure-Object).Count
        $roleCount = if ($config.job_roles) { ($config.job_roles.PSObject.Properties | Measure-Object).Count } else { 0 }
        Write-OK "Loaded config: $setCount package sets, $roleCount job roles"
        $script:PackageConfig = $config
        return $config
    }
    catch {
        Write-Err "Failed to parse JSON config"
        Write-Detail "Error: $($_.Exception.Message)"
        Write-Detail "Check for syntax errors (trailing commas, missing quotes)"
        return $null
    }
}

function Get-PackageSet {
    param([string]$SetName)
    if ($null -eq $script:PackageConfig) {
        $defaults = @{
            "jupyter" = @("jupyterlab")
            "data_science" = @("numpy", "pandas", "matplotlib", "seaborn", "scikit-learn", "scipy")
        }
        if ($defaults.ContainsKey($SetName)) { return $defaults[$SetName] }
        return @()
    }
    $set = $script:PackageConfig.package_sets.$SetName
    if ($null -eq $set) { return @() }
    return $set.packages
}

function Get-JobRoleSets {
    param([string]$RoleName)
    if ($null -eq $script:PackageConfig -or $null -eq $script:PackageConfig.job_roles) {
        return @()
    }
    $role = $script:PackageConfig.job_roles.$RoleName
    if ($null -eq $role) { return @() }
    return $role.sets
}

function Get-AllPackagesFromSets {
    param([string[]]$SetNames)
    $allPackages = @()
    foreach ($setName in $SetNames) {
        $packages = Get-PackageSet -SetName $setName
        $allPackages += $packages
    }
    return $allPackages | Select-Object -Unique
}

# ============================================================================
# PACKAGE INSTALLATION WITH ERROR HANDLING
# ============================================================================

function Install-SinglePackage {
    param(
        [string]$PythonExe,
        [string]$Package,
        [int]$Attempt = 1
    )
    
    $startTime = Get-Date
    try {
        $output = & $PythonExe -m pip install $Package --quiet 2>&1
        $exitCode = $LASTEXITCODE
        $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
        
        if ($exitCode -eq 0) {
            return @{ Success = $true; Time = "${elapsed}s"; Message = "" }
        }
        else {
            $errorMsg = ($output | Out-String).Trim()
            return @{ Success = $false; Time = "${elapsed}s"; Message = $errorMsg }
        }
    }
    catch {
        $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
        return @{ Success = $false; Time = "${elapsed}s"; Message = $_.Exception.Message }
    }
}

function Install-PackagesWithProgress {
    param(
        [string]$PythonExe,
        [string[]]$Packages,
        [string]$SetName = "Packages",
        [string]$EnvPath = ""
    )
    
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "  ║  INSTALLING: $($SetName.PadRight(58)) ║" -ForegroundColor Yellow
    Write-Host "  ╚══════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    
    $total = $Packages.Count
    Write-Host "    Packages: $total" -ForegroundColor White
    
    # Estimate time
    $estMinutes = [math]::Ceiling($total * 0.15)
    $estMax = [math]::Ceiling($estMinutes * 1.5)
    Write-Host "    Estimated time: $estMinutes-$estMax minutes" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  ──────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
    
    $results = @{
        Success = @()
        Failed = @()
        Skipped = @()
    }
    
    $startTime = Get-Date
    
    for ($i = 0; $i -lt $total; $i++) {
        $pkg = $Packages[$i]
        $current = $i + 1
        $pct = [math]::Round(($current / $total) * 100)
        
        # Progress bar
        $barWidth = 30
        $filled = [math]::Floor($barWidth * $current / $total)
        $empty = $barWidth - $filled
        $bar = "[" + ("=" * $filled) + (" " * $empty) + "]"
        
        # Show current package being installed
        Write-Host "`r    $bar $pct% ($current/$total) Installing: $($pkg.PadRight(25))" -NoNewline -ForegroundColor White
        
        # Try install with retries
        $installed = $false
        $lastError = ""
        
        for ($attempt = 1; $attempt -le $script:RETRY_ATTEMPTS; $attempt++) {
            $result = Install-SinglePackage -PythonExe $PythonExe -Package $pkg -Attempt $attempt
            
            if ($result.Success) {
                $results.Success += $pkg
                $installed = $true
                break
            }
            else {
                $lastError = $result.Message
                if ($attempt -lt $script:RETRY_ATTEMPTS) {
                    Write-Host "`r    $bar $pct% ($current/$total) Retrying: $($pkg.PadRight(26))" -NoNewline -ForegroundColor Yellow
                    Start-Sleep -Seconds $script:RETRY_DELAY_SEC
                }
            }
        }
        
        if (-not $installed) {
            $results.Failed += @{ Package = $pkg; Error = $lastError }
        }
        
        # Show ETA every 5 packages
        if ($current % 5 -eq 0 -and $current -lt $total) {
            $elapsed = ((Get-Date) - $startTime).TotalSeconds
            $avgPerPkg = $elapsed / $current
            $remaining = ($total - $current) * $avgPerPkg
            $eta = [math]::Round($remaining / 60, 1)
            Write-Host ""
            Write-Host "    ETA: ~$eta min remaining" -ForegroundColor DarkGray
        }
    }
    
    # Clear line and show completion
    Write-Host ""
    Write-Host ""
    
    # Summary
    $totalTime = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
    
    Write-Host "  ──────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "    INSTALL COMPLETE" -ForegroundColor Green
    Write-Host ""
    Write-Host "    Successful: $($results.Success.Count)/$total" -ForegroundColor Green
    
    if ($results.Failed.Count -gt 0) {
        Write-Host "    Failed:     $($results.Failed.Count)" -ForegroundColor Red
    }
    Write-Host "    Time:       $totalTime min" -ForegroundColor DarkGray
    
    if ($results.Failed.Count -gt 0) {
        Write-Host ""
        Write-Host "    Failed packages:" -ForegroundColor Red
        foreach ($fail in $results.Failed) {
            Write-Host "      - $($fail.Package)" -ForegroundColor DarkGray
            if ($fail.Error -match "Microsoft Visual C\+\+") {
                Write-Host "        (needs Visual C++ Build Tools)" -ForegroundColor Yellow
            }
            elseif ($fail.Error -match "No matching distribution") {
                Write-Host "        (not found or incompatible)" -ForegroundColor Yellow
            }
        }
    }
    Write-Host ""
    
    return $results
}

function Install-PackageSet {
    param(
        [string]$PythonExe,
        [string]$SetName,
        [string]$EnvPath = ""
    )
    
    $packages = Get-PackageSet -SetName $SetName
    if ($packages.Count -eq 0) {
        Write-Warn "Package set '$SetName' not found or empty"
        return $null
    }
    
    $setInfo = $script:PackageConfig.package_sets.$SetName
    $displayName = if ($setInfo) { $setInfo.name } else { $SetName }
    
    # Get env path from python exe if not provided
    if (-not $EnvPath) {
        $EnvPath = Split-Path (Split-Path $PythonExe -Parent) -Parent
    }
    
    $results = Install-PackagesWithProgress -PythonExe $PythonExe -Packages $packages -SetName $displayName -EnvPath $EnvPath
    
    # Track in manifest
    if ($results -and $EnvPath) {
        Add-ManifestEntry -EnvPath $EnvPath -SetName $SetName -PackageCount $packages.Count -SuccessCount $results.Success.Count -FailedCount $results.Failed.Count
    }
    
    return $results
}

function Install-JobRole {
    param(
        [string]$PythonExe,
        [string]$RoleName,
        [string]$EnvPath = ""
    )
    
    $sets = Get-JobRoleSets -RoleName $RoleName
    if ($sets.Count -eq 0) {
        Write-Err "Job role '$RoleName' not found"
        return $null
    }
    
    # Get env path from python exe if not provided
    if (-not $EnvPath) {
        $EnvPath = Split-Path (Split-Path $PythonExe -Parent) -Parent
    }
    
    $roleInfo = $script:PackageConfig.job_roles.$RoleName
    
    # Calculate total packages
    $allPkgs = @{}
    foreach ($s in $sets) {
        foreach ($p in $script:PackageConfig.package_sets.$s.packages) {
            $allPkgs[$p] = $true
        }
    }
    $totalPkgs = $allPkgs.Count
    
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "  ║  JOB ROLE: $($roleInfo.name.PadRight(60)) ║" -ForegroundColor Magenta
    Write-Host "  ╚══════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "    $($roleInfo.description)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "    Package sets:    $($sets.Count)" -ForegroundColor White
    Write-Host "    Total packages:  $totalPkgs" -ForegroundColor White
    Write-Host "    Estimated time:  $($roleInfo.install_time)" -ForegroundColor DarkGray
    Write-Host "    Disk estimate:   $($roleInfo.disk_estimate)" -ForegroundColor DarkGray
    Write-Host ""
    
    $allResults = @{ Success = @(); Failed = @() }
    $setNum = 0
    
    foreach ($setName in $sets) {
        $setNum++
        $setInfo = $script:PackageConfig.package_sets.$setName
        if ($setInfo) {
            Write-Host "    [$setNum/$($sets.Count)] $($setInfo.name)..." -ForegroundColor Cyan
        }
        $result = Install-PackageSet -PythonExe $PythonExe -SetName $setName -EnvPath $EnvPath
        if ($result) {
            $allResults.Success += $result.Success
            $allResults.Failed += $result.Failed
        }
    }
    
    # Track role in manifest
    Add-ManifestEntry -EnvPath $EnvPath -RoleName $RoleName -PackageCount $totalPkgs -SuccessCount $allResults.Success.Count -FailedCount $allResults.Failed.Count
    
    # Final summary
    Write-Host ""
    Write-Host "  ══════════════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "    JOB ROLE INSTALLATION COMPLETE: $($roleInfo.name)" -ForegroundColor Magenta
    Write-Host "  ══════════════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "    Successful: $($allResults.Success.Count)" -ForegroundColor Green
    if ($allResults.Failed.Count -gt 0) {
        Write-Host "    Failed:     $($allResults.Failed.Count)" -ForegroundColor Red
    }
    Write-Host ""
    
    return $allResults
}

# ============================================================================
# JUPYTER SESSION DETECTION
# ============================================================================

function Get-RunningJupyterSessions {
    $sessions = @()
    
    try {
        # Find jupyter processes
        $jupyterProcs = Get-Process -Name "jupyter*", "python" -ErrorAction SilentlyContinue | 
            Where-Object { $_.CommandLine -match "jupyter" -or $_.MainWindowTitle -match "jupyter" }
        
        # Also check via netstat for jupyter ports (typically 8888+)
        $listeners = netstat -ano 2>$null | Select-String ":88[89][0-9]\s+.*LISTENING"
        
        foreach ($listener in $listeners) {
            if ($listener -match ":(\d+)\s+.*LISTENING\s+(\d+)") {
                $port = $matches[1]
                $pid = $matches[2]
                
                try {
                    $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
                    if ($proc) {
                        $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId=$pid" -ErrorAction SilentlyContinue).CommandLine
                        
                        # Try to identify environment from command line
                        $envName = "Unknown"
                        if ($cmdLine -match "\.venvs[\\\/]([^\\\/]+)[\\\/]") {
                            $envName = $matches[1]
                        }
                        elseif ($cmdLine -match "envs[\\\/]([^\\\/]+)[\\\/]") {
                            $envName = $matches[1]
                        }
                        
                        $sessions += [PSCustomObject]@{
                            Port = $port
                            PID = $pid
                            URL = "http://localhost:$port"
                            Environment = $envName
                            ProcessName = $proc.ProcessName
                        }
                    }
                }
                catch { }
            }
        }
    }
    catch { }
    
    return $sessions
}

function Show-RunningSessions {
    Write-Host ""
    Write-Host "  RUNNING JUPYTER SESSIONS" -ForegroundColor Cyan
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host ""
    
    $sessions = Get-RunningJupyterSessions
    
    if ($sessions.Count -eq 0) {
        Write-Host "    No running Jupyter sessions detected." -ForegroundColor DarkGray
    }
    else {
        Write-Host "    #   URL                        ENVIRONMENT" -ForegroundColor DarkGray
        Write-Host "    ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        
        $i = 1
        foreach ($s in $sessions) {
            $urlStr = $s.URL.PadRight(26)
            $envColor = if ($s.Environment -eq "Unknown") { "DarkGray" } else { "Green" }
            Write-Host "    $i   $urlStr " -NoNewline
            Write-Host $s.Environment -ForegroundColor $envColor
            $i++
        }
    }
    Write-Host ""
}

# ============================================================================
# ENVIRONMENT MANIFEST (TRACKS INSTALLED SETS)
# ============================================================================

function Get-EnvironmentManifest {
    param([string]$EnvPath)
    $manifestFile = Join-Path $EnvPath "stank-manifest.json"
    if (Test-Path $manifestFile) {
        try {
            return Get-Content $manifestFile -Raw | ConvertFrom-Json
        }
        catch { }
    }
    return @{
        created = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        updated = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        installed_sets = @()
        installed_roles = @()
        install_history = @()
    }
}

function Save-EnvironmentManifest {
    param([string]$EnvPath, [PSCustomObject]$Manifest)
    $manifestFile = Join-Path $EnvPath "stank-manifest.json"
    $Manifest.updated = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    try {
        $Manifest | ConvertTo-Json -Depth 10 | Set-Content $manifestFile -Encoding UTF8
    }
    catch { Write-Warn "Could not save manifest" }
}

function Add-ManifestEntry {
    param(
        [string]$EnvPath,
        [string]$SetName = "",
        [string]$RoleName = "",
        [int]$PackageCount = 0,
        [int]$SuccessCount = 0,
        [int]$FailedCount = 0
    )
    $manifest = Get-EnvironmentManifest -EnvPath $EnvPath
    
    # Convert to hashtable if needed
    if ($manifest -is [PSCustomObject]) {
        $manifest = @{
            created = $manifest.created
            updated = $manifest.updated
            installed_sets = @($manifest.installed_sets)
            installed_roles = @($manifest.installed_roles)
            install_history = @($manifest.install_history)
        }
    }
    
    $entry = @{
        date = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        set = $SetName
        role = $RoleName
        packages = $PackageCount
        success = $SuccessCount
        failed = $FailedCount
    }
    
    if ($SetName -and $SetName -notin $manifest.installed_sets) {
        $manifest.installed_sets += $SetName
    }
    if ($RoleName -and $RoleName -notin $manifest.installed_roles) {
        $manifest.installed_roles += $RoleName
    }
    $manifest.install_history += $entry
    
    Save-EnvironmentManifest -EnvPath $EnvPath -Manifest ([PSCustomObject]$manifest)
}

function Show-EnvironmentManifest {
    param([PSCustomObject]$Env)
    
    $manifest = Get-EnvironmentManifest -EnvPath $Env.Path
    
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                    INSTALLED PACKAGES: $($Env.Name.PadRight(28))       ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    if ($manifest.installed_roles -and $manifest.installed_roles.Count -gt 0) {
        Write-Host "    Job Roles:" -ForegroundColor Yellow
        foreach ($role in $manifest.installed_roles) {
            $roleInfo = $script:PackageConfig.job_roles.$role
            $name = if ($roleInfo) { $roleInfo.name } else { $role }
            Write-Host "      - $name" -ForegroundColor Green
        }
        Write-Host ""
    }
    
    if ($manifest.installed_sets -and $manifest.installed_sets.Count -gt 0) {
        Write-Host "    Package Sets:" -ForegroundColor Yellow
        foreach ($set in $manifest.installed_sets) {
            $setInfo = $script:PackageConfig.package_sets.$set
            $name = if ($setInfo) { $setInfo.name } else { $set }
            $pkgCount = if ($setInfo) { $setInfo.packages.Count } else { "?" }
            Write-Host "      - $name ($pkgCount pkgs)" -ForegroundColor Cyan
        }
        Write-Host ""
    }
    
    if ((-not $manifest.installed_sets -or $manifest.installed_sets.Count -eq 0) -and 
        (-not $manifest.installed_roles -or $manifest.installed_roles.Count -eq 0)) {
        Write-Host "    No package sets tracked yet." -ForegroundColor DarkGray
        Write-Host "    (Packages installed manually via pip are not tracked)" -ForegroundColor DarkGray
        Write-Host ""
    }
    
    Write-Host "    Created: $($manifest.created)" -ForegroundColor DarkGray
    Write-Host "    Updated: $($manifest.updated)" -ForegroundColor DarkGray
    Write-Host ""
}

# ============================================================================
# STATE MANAGEMENT
# ============================================================================

function Get-LastSession {
    if (Test-Path $script:STATE_FILE) {
        try {
            return Get-Content $script:STATE_FILE -Raw | ConvertFrom-Json
        }
        catch { return $null }
    }
    return $null
}

function Save-LastSession {
    param([string]$EnvName, [string]$WorkDir)
    $dir = Split-Path $script:STATE_FILE -Parent
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
    $sessionData = @{
        EnvName = $EnvName
        WorkDir = $WorkDir
        Date = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
    try {
        $sessionData | ConvertTo-Json | Set-Content $script:STATE_FILE -Encoding UTF8
    }
    catch { }
}

# ============================================================================
# ENVIRONMENT MANAGEMENT
# ============================================================================

function Get-AllEnvironments {
    if (-not (Test-Path $script:VENV_DIR)) { return @() }
    
    $folders = Get-ChildItem -Path $script:VENV_DIR -Directory -ErrorAction SilentlyContinue
    $envs = @()
    
    foreach ($folder in $folders) {
        $pythonExe = Join-Path $folder.FullName "Scripts\python.exe"
        if (Test-Path $pythonExe) {
            $jupExe = Join-Path $folder.FullName "Scripts\jupyter.exe"
            $hasJupyter = Test-Path $jupExe
            
            $pyVer = "unknown"
            try {
                $pyVer = & $pythonExe -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" 2>$null
            }
            catch { }
            
            $projDir = Join-Path $script:PROJECTS_DIR $folder.Name
            $hasProjectDir = Test-Path $projDir
            $envSize = Get-FolderSize -Path $folder.FullName
            $projSize = if ($hasProjectDir) { Get-FolderSize -Path $projDir } else { 0 }
            
            # Get manifest info
            $manifest = Get-EnvironmentManifest -EnvPath $folder.FullName
            $installedSets = if ($manifest.installed_sets) { @($manifest.installed_sets).Count } else { 0 }
            $installedRoles = if ($manifest.installed_roles) { @($manifest.installed_roles) } else { @() }
            
            $envs += [PSCustomObject]@{
                Name = $folder.Name
                Path = $folder.FullName
                Python = $pythonExe
                PyVersion = $pyVer
                HasJupyter = $hasJupyter
                ProjectDir = $projDir
                HasProjectDir = $hasProjectDir
                EnvSize = $envSize
                EnvSizeFormatted = Format-FileSize -Bytes $envSize
                ProjSize = $projSize
                ProjSizeFormatted = Format-FileSize -Bytes $projSize
                InstalledSets = $installedSets
                InstalledRoles = $installedRoles
            }
        }
    }
    return $envs
}

function Show-EnvironmentTable {
    param([array]$Envs, [switch]$Numbered, [switch]$Detailed)
    
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                         YOUR PYTHON ENVIRONMENTS                         ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    if ($Envs.Count -eq 0) {
        Write-Host "    No environments found. Use options 1-5 to create one." -ForegroundColor DarkGray
        return
    }
    
    $last = Get-LastSession
    
    # Header
    Write-Host "    #   NAME                 PYTHON     SETS   SIZE       ROLE" -ForegroundColor DarkGray
    Write-Host "    ─────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    
    for ($i = 0; $i -lt $Envs.Count; $i++) {
        $e = $Envs[$i]
        $marker = if ($last -and $e.Name -eq $last.EnvName) { "*" } else { " " }
        $num = if ($Numbered) { "$($i+1)." } else { "  " }
        
        $numStr = "$marker$num".PadRight(4)
        $nameStr = $e.Name.PadRight(20)
        $pyStr = $e.PyVersion.PadRight(10)
        $setsStr = "$($e.InstalledSets)".PadRight(6)
        $sizeStr = $e.EnvSizeFormatted.PadRight(10)
        
        # Show primary role if any
        $roleStr = ""
        if ($e.InstalledRoles -and $e.InstalledRoles.Count -gt 0) {
            $firstRole = $e.InstalledRoles[0]
            $roleInfo = $script:PackageConfig.job_roles.$firstRole
            $roleStr = if ($roleInfo) { $roleInfo.name } else { $firstRole }
            if ($e.InstalledRoles.Count -gt 1) { $roleStr += " +$($e.InstalledRoles.Count - 1)" }
        }
        
        if ($e.HasJupyter) {
            Write-Host "    $numStr " -NoNewline
            Write-Host $nameStr -NoNewline -ForegroundColor Green
            Write-Host " $pyStr $setsStr $sizeStr " -NoNewline
            Write-Host $roleStr -ForegroundColor Cyan
        }
        else {
            Write-Host "    $numStr " -NoNewline
            Write-Host $nameStr -NoNewline -ForegroundColor Yellow
            Write-Host " $pyStr $setsStr $sizeStr $roleStr" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
    
    if ($Detailed) {
        $totalEnvSize = ($Envs | Measure-Object -Property EnvSize -Sum).Sum
        $totalProjSize = ($Envs | Measure-Object -Property ProjSize -Sum).Sum
        Write-Host "    Total: $(Format-FileSize -Bytes $totalEnvSize) (envs) + $(Format-FileSize -Bytes $totalProjSize) (projects)" -ForegroundColor DarkGray
        Write-Host ""
    }
}

function Select-Environment {
    param([string]$Prompt = "Select environment")
    $envs = Get-AllEnvironments
    if ($envs.Count -eq 0) { 
        Write-Host ""
        Write-Warn "No environments available. Create one first."
        return $null 
    }
    Show-EnvironmentTable -Envs $envs -Numbered
    Write-Host "    [0]  Cancel" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  ──────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    $sel = Read-Host "    $Prompt (1-$($envs.Count))"
    if ($sel -eq '0' -or $sel -eq '') { return $null }
    if ($sel -match '^\d+$') {
        $idx = [int]$sel - 1
        if ($idx -ge 0 -and $idx -lt $envs.Count) {
            Write-Host ""
            Write-OK "Selected: $($envs[$idx].Name)"
            return $envs[$idx]
        }
    }
    Write-Err "Invalid selection"
    return $null
}

# ============================================================================
# PYTHON CHECK
# ============================================================================

function Test-PythonInstalled {
    Write-Section "CHECKING PYTHON 3.11 INSTALLATION"
    Write-Info "This tool REQUIRES Python 3.11 (not 3.12+, not 3.10-)"
    
    # =========================================================================
    # STRICT PYTHON 3.11 REQUIREMENT
    # Python 3.11 is required because:
    #   - 3.12+ removed distutils (breaks many packages)
    #   - 3.10 and earlier lack performance improvements
    #   - 3.11 is the "sweet spot" for compatibility
    # Using py -3.11 ensures we get exactly 3.11, not the system default
    # =========================================================================
    
    $python311Found = $false
    
    # Method 1: py launcher with -3.11 flag (preferred - isolated from defaults)
    try {
        $result = & py -3.11 --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $result -match "Python 3\.11") {
            $python311Found = $true
            $script:PYTHON = "py"
            $script:PYTHON_ARGS = @("-3.11")
            Write-OK "Python 3.11 found: $result"
            Write-Detail "Using: py -3.11 (isolated from system default)"
        }
    }
    catch { }
    
    # Method 2: Direct python3.11 command
    if (-not $python311Found) {
        try {
            $result = & python3.11 --version 2>&1
            if ($LASTEXITCODE -eq 0 -and $result -match "Python 3\.11") {
                $python311Found = $true
                $script:PYTHON = "python3.11"
                $script:PYTHON_ARGS = @()
                Write-OK "Python 3.11 found: $result"
            }
        }
        catch { }
    }
    
    # Python 3.11 found - verify pip and venv
    if ($python311Found) {
        $allGood = $true
        
        # Verify pip
        try {
            $pipArgs = $script:PYTHON_ARGS + @("-m", "pip", "--version")
            $pipResult = & $script:PYTHON @pipArgs 2>&1
            if ($LASTEXITCODE -eq 0) { 
                Write-OK "pip available" 
            } else { 
                Write-Warn "pip not available"
                $allGood = $false
            }
        }
        catch { 
            Write-Warn "pip check failed"
            $allGood = $false
        }
        
        # Verify venv module
        try {
            $venvArgs = $script:PYTHON_ARGS + @("-c", "import venv")
            & $script:PYTHON @venvArgs 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { 
                Write-OK "venv module available" 
            } else {
                Write-Warn "venv module not available"
                $allGood = $false
            }
        }
        catch { 
            Write-Warn "venv check failed"
            $allGood = $false
        }
        
        if ($allGood) {
            Write-Host ""
            Write-OK "Python 3.11 ready for virtual environments"
            return $true
        }
    }
    
    # =========================================================================
    # PYTHON 3.11 NOT FOUND - Show installation instructions
    # =========================================================================
    
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "  ║              PYTHON 3.11 IS REQUIRED                             ║" -ForegroundColor Red
    Write-Host "  ╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    
    # Check what Python versions ARE installed
    $foundOther = $false
    foreach ($ver in @("3.13", "3.12", "3.10", "3.9")) {
        try {
            $result = & py -$ver --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                if (-not $foundOther) {
                    Write-Host "  Other Python versions found (but not compatible):" -ForegroundColor Yellow
                    $foundOther = $true
                }
                Write-Host "    - $result" -ForegroundColor Gray
            }
        }
        catch { }
    }
    
    if ($foundOther) {
        Write-Host ""
        Write-Host "  Why not use these versions?" -ForegroundColor Yellow
        Write-Host "    - Python 3.12/3.13: distutils removed, breaks many packages" -ForegroundColor Gray
        Write-Host "    - Python 3.10/3.9: missing performance and compatibility" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host "  ┌────────────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "  │  HOW TO INSTALL PYTHON 3.11 (safe, won't change defaults)     │" -ForegroundColor Cyan
    Write-Host "  └────────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Step 1: Download Python 3.11.9" -ForegroundColor White
    Write-Host "          https://www.python.org/downloads/release/python-3119/" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Step 2: Run installer - IMPORTANT OPTIONS:" -ForegroundColor White
    Write-Host "          [ ] Add python.exe to PATH      <- LEAVE UNCHECKED" -ForegroundColor Red
    Write-Host "          [x] Install py launcher         <- CHECK THIS" -ForegroundColor Green
    Write-Host ""
    Write-Host "          Click 'Customize installation', then on Advanced Options:" -ForegroundColor Gray
    Write-Host "          [ ] Add Python to environment variables <- LEAVE UNCHECKED" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Step 3: Disable Microsoft Store Python (if installed)" -ForegroundColor White
    Write-Host "          Settings > Apps > Advanced app settings > App execution aliases" -ForegroundColor Gray
    Write-Host "          Turn OFF both 'python.exe' and 'python3.exe'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Step 4: Restart this script" -ForegroundColor White
    Write-Host ""
    Write-Host "  ┌────────────────────────────────────────────────────────────────┐" -ForegroundColor Green
    Write-Host "  │  SAFE: Python 3.11 installs alongside other versions.         │" -ForegroundColor Green
    Write-Host "  │  Your existing Python and settings are NOT changed.           │" -ForegroundColor Green
    Write-Host "  │  This tool uses 'py -3.11' to target 3.11 specifically.       │" -ForegroundColor Green
    Write-Host "  └────────────────────────────────────────────────────────────────┘" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Verify after install: Open Command Prompt and run:" -ForegroundColor Gray
    Write-Host "          py --list" -ForegroundColor Cyan
    Write-Host "          py -3.11 --version" -ForegroundColor Cyan
    Write-Host ""
    
    return $false
}

# ============================================================================
# ENVIRONMENT CREATION
# ============================================================================

function New-Environment {
    param(
        [string]$Name,
        [string]$PackagePreset = "none",
        [switch]$CreateProjectDir
    )
    
    Write-Section "CREATING ENVIRONMENT: $Name"
    
    # Validate name
    if ([string]::IsNullOrWhiteSpace($Name)) {
        Write-Err "Name cannot be empty"
        return $false
    }
    if ($Name -match '[\\/:*?"<>|\s]') {
        Write-Err "Name contains invalid characters"
        return $false
    }
    Write-OK "Name '$Name' is valid"
    
    # Check if exists
    $envPath = Join-Path $script:VENV_DIR $Name
    if (Test-Path $envPath) {
        Write-Err "Environment '$Name' already exists"
        return $false
    }
    
    # Pre-flight checks
    if (-not (Test-DiskSpace -RequiredGB 1)) {
        if (-not (Confirm-Action "Continue anyway?")) { return $false }
    }
    
    # Create directories
    if (-not (Test-Path $script:VENV_DIR)) {
        New-Item -Path $script:VENV_DIR -ItemType Directory -Force | Out-Null
        Write-OK "Created: $script:VENV_DIR"
    }
    
    # Create virtual environment
    Write-Step 1 "CREATING VIRTUAL ENVIRONMENT"
    Write-Progress2 "Creating..."
    
    try {
        $venvArgs = $script:PYTHON_ARGS + @("-m", "venv", $envPath)
        & $script:PYTHON @venvArgs 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "venv creation failed" }
        Write-ProgressDone
    }
    catch {
        Write-Host " FAILED" -ForegroundColor Red
        Write-Err $_.Exception.Message
        return $false
    }
    
    # Verify
    $pythonExe = Join-Path $envPath "Scripts\python.exe"
    if (-not (Test-Path $pythonExe)) {
        Write-Err "Environment created but python.exe missing"
        return $false
    }
    Write-OK "Environment created: $envPath"
    
    # Upgrade pip
    Write-Step 2 "UPGRADING PIP"
    Write-Progress2 "Upgrading..."
    try {
        & $pythonExe -m pip install --upgrade pip --quiet 2>&1 | Out-Null
        Write-ProgressDone
    }
    catch { Write-Warn "pip upgrade had issues" }
    
    # Install packages based on preset
    if ($PackagePreset -ne "none") {
        Write-Step 3 "INSTALLING PACKAGES"
        
        # Check network before installing
        if (-not (Test-NetworkConnection)) {
            Write-Warn "Skipping package installation (no network)"
        }
        else {
            switch ($PackagePreset) {
                "jupyter" {
                    Install-PackageSet -PythonExe $pythonExe -SetName "jupyter" | Out-Null
                }
                "data_science" {
                    Install-PackageSet -PythonExe $pythonExe -SetName "jupyter" | Out-Null
                    Install-PackageSet -PythonExe $pythonExe -SetName "data_science" | Out-Null
                }
                default {
                    # Check if it's a job role
                    if ($script:PackageConfig.job_roles.$PackagePreset) {
                        Install-JobRole -PythonExe $pythonExe -RoleName $PackagePreset | Out-Null
                    }
                    # Or a preset bundle
                    elseif ($script:PackageConfig.preset_bundles.$PackagePreset) {
                        $bundle = $script:PackageConfig.preset_bundles.$PackagePreset
                        foreach ($setName in $bundle.sets) {
                            Install-PackageSet -PythonExe $pythonExe -SetName $setName | Out-Null
                        }
                    }
                }
            }
        }
    }
    
    # Create project directory
    if ($CreateProjectDir) {
        $projPath = Join-Path $script:PROJECTS_DIR $Name
        if (-not (Test-Path $projPath)) {
            New-Item -Path $projPath -ItemType Directory -Force | Out-Null
            foreach ($sub in @("notebooks", "data", "outputs", "scripts")) {
                New-Item -Path (Join-Path $projPath $sub) -ItemType Directory -Force | Out-Null
            }
            Write-OK "Created project: $projPath"
        }
    }
    
    Write-Section "ENVIRONMENT CREATED SUCCESSFULLY"
    Write-Host "  Name: $Name"
    Write-Host "  Path: $envPath"
    
    return $true
}

# ============================================================================
# JUPYTER LAUNCH
# ============================================================================

function Start-JupyterLab {
    param([PSCustomObject]$Env, [string]$WorkDir, [int]$Port = 8888)
    
    Write-Section "LAUNCHING JUPYTERLAB"
    
    $jupExe = Join-Path $Env.Path "Scripts\jupyter.exe"
    if (-not (Test-Path $jupExe)) {
        Write-Warn "JupyterLab not installed"
        if (Confirm-Action "Install JupyterLab now?") {
            Install-PackageSet -PythonExe $Env.Python -SetName "jupyter" | Out-Null
        }
        else { return }
    }
    
    $projDir = Join-Path $script:PROJECTS_DIR $Env.Name
    if ([string]::IsNullOrWhiteSpace($WorkDir)) {
        $WorkDir = if (Test-Path $projDir) { $projDir } else { $PWD.Path }
    }
    
    if (-not (Test-Path $WorkDir)) {
        Write-Err "Directory not found: $WorkDir"
        return
    }
    
    Save-LastSession -EnvName $Env.Name -WorkDir $WorkDir
    
    Write-Host ""
    Write-Host ("  " + "=" * 60) -ForegroundColor Green
    Write-Host "  JUPYTERLAB STARTING" -ForegroundColor Green
    Write-Host "  Environment: $($Env.Name)" -ForegroundColor Cyan
    Write-Host "  Directory  : $WorkDir" -ForegroundColor Cyan
    Write-Host "  TO STOP    : Press Ctrl+C" -ForegroundColor Yellow
    Write-Host ("  " + "=" * 60) -ForegroundColor Green
    Write-Host ""
    
    Set-Location $WorkDir
    & $Env.Python -m jupyter lab --port=$Port
}

function Start-LastSession {
    $last = Get-LastSession
    if (-not $last) {
        Write-Warn "No previous session found"
        return
    }
    
    $envPath = Join-Path $script:VENV_DIR $last.EnvName
    if (-not (Test-Path $envPath)) {
        Write-Err "Environment '$($last.EnvName)' no longer exists"
        return
    }
    
    $env = [PSCustomObject]@{
        Name = $last.EnvName
        Path = $envPath
        Python = Join-Path $envPath "Scripts\python.exe"
    }
    Start-JupyterLab -Env $env -WorkDir $last.WorkDir
}

# ============================================================================
# JOB ROLE MENU
# ============================================================================

function Show-JobRoleMenu {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                        SELECT YOUR JOB ROLE                              ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    if ($null -eq $script:PackageConfig -or $null -eq $script:PackageConfig.job_roles) {
        Write-Err "Job roles not available (config not loaded)"
        return $null
    }
    
    Write-Host "    Pre-configured package bundles optimized for your profession:" -ForegroundColor Gray
    Write-Host ""
    
    $roleNum = 1
    $roleMap = @{}
    
    foreach ($roleProp in $script:PackageConfig.job_roles.PSObject.Properties) {
        $role = $roleProp.Value
        $roleMap[$roleNum] = $roleProp.Name
        
        # Calculate actual package count
        $pkgCount = 0
        $pkgs = @{}
        foreach ($s in $role.sets) {
            foreach ($p in $script:PackageConfig.package_sets.$s.packages) {
                $pkgs[$p] = $true
            }
        }
        $pkgCount = $pkgs.Count
        
        # Format with colors
        $numStr = "[$roleNum]".PadRight(4)
        $nameStr = $role.name.PadRight(32)
        $pkgStr = "$pkgCount pkgs".PadRight(10)
        $timeStr = $role.install_time.PadRight(12)
        $diskStr = $role.disk_estimate
        
        Write-Host "    $numStr " -NoNewline -ForegroundColor Yellow
        Write-Host "$nameStr " -NoNewline -ForegroundColor White
        Write-Host "$pkgStr " -NoNewline -ForegroundColor Cyan
        Write-Host "$timeStr " -NoNewline -ForegroundColor DarkGray
        Write-Host "$diskStr" -ForegroundColor DarkGray
        
        $roleNum++
    }
    
    Write-Host ""
    Write-Host "    [0]  Cancel - return to main menu" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  ──────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    
    $choice = Read-Host "    Select role (1-$($roleNum - 1))"
    
    if ($choice -eq '0' -or $choice -eq '') { return $null }
    
    if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -lt $roleNum) {
        $selected = $roleMap[[int]$choice]
        $selectedRole = $script:PackageConfig.job_roles.$selected
        Write-Host ""
        Write-OK "Selected: $($selectedRole.name)"
        return $selected
    }
    
    Write-Err "Invalid selection"
    return $null
}

# ============================================================================
# PACKAGE SET MENU
# ============================================================================

function Show-PackageSetsMenu {
    param([PSCustomObject]$Env)
    
    Clear-Host
    
    # Get manifest to show what's installed
    $manifest = Get-EnvironmentManifest -EnvPath $Env.Path
    $installedSets = @($manifest.installed_sets)
    
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                      ADD PACKAGE SETS TO: $($Env.Name.PadRight(26))     ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    if ($installedSets.Count -gt 0) {
        Write-Host "    Already installed: $($installedSets.Count) sets" -ForegroundColor Green
        Write-Host ""
    }
    
    if ($null -eq $script:PackageConfig) {
        Write-Warn "Package configuration not loaded"
        return
    }
    
    # Group by category
    $categories = [ordered]@{
        "core" = @()
        "data" = @()
        "ml" = @()
        "web" = @()
        "security" = @()
        "files" = @()
        "dev" = @()
        "devops" = @()
    }
    
    foreach ($setProp in $script:PackageConfig.package_sets.PSObject.Properties) {
        $set = $setProp.Value
        $cat = if ($set.category) { $set.category } else { "other" }
        if (-not $categories.Contains($cat)) { $categories[$cat] = @() }
        $categories[$cat] += @{ Key = $setProp.Name; Value = $set }
    }
    
    $setNum = 1
    $setMap = @{}
    
    $catColors = @{
        "core" = "Cyan"
        "data" = "Green"
        "ml" = "Magenta"
        "web" = "Yellow"
        "security" = "Red"
        "files" = "DarkYellow"
        "dev" = "Blue"
        "devops" = "Gray"
    }
    
    foreach ($cat in $categories.Keys) {
        if ($categories[$cat].Count -eq 0) { continue }
        
        $catDisplay = $cat.ToUpper()
        $color = if ($catColors.ContainsKey($cat)) { $catColors[$cat] } else { "White" }
        Write-Host "    ── $catDisplay ──" -ForegroundColor $color
        
        foreach ($item in $categories[$cat]) {
            $set = $item.Value
            $setMap[$setNum] = $item.Key
            $numStr = "[$setNum]".PadLeft(4)
            $nameStr = $set.name.PadRight(30)
            $pkgStr = "$($set.packages.Count) pkgs"
            
            # Check if already installed
            $isInstalled = $item.Key -in $installedSets
            
            if ($isInstalled) {
                Write-Host "    $numStr $nameStr " -NoNewline -ForegroundColor DarkGray
                Write-Host "$pkgStr " -NoNewline -ForegroundColor DarkGray
                Write-Host "[INSTALLED]" -ForegroundColor Green
            }
            else {
                Write-Host "    $numStr $nameStr " -NoNewline
                Write-Host $pkgStr -ForegroundColor DarkGray
            }
            $setNum++
        }
        Write-Host ""
    }
    
    Write-Host "    [0]  Cancel" -ForegroundColor DarkGray
    Write-Host "    [V]  View installed details" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  ──────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    
    $choice = Read-Host "    Select set (1-$($setNum - 1))"
    
    if ($choice -eq '0' -or $choice -eq '') { return }
    
    if ($choice -eq 'V' -or $choice -eq 'v') {
        Show-EnvironmentManifest -Env $Env
        Pause
        Show-PackageSetsMenu -Env $Env
        return
    }
    
    if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -lt $setNum) {
        $selected = $setMap[[int]$choice]
        
        # Check if already installed
        if ($selected -in $installedSets) {
            Write-Host ""
            Write-Warn "This set is already installed"
            if (-not (Confirm-Action "Reinstall anyway?")) {
                return
            }
        }
        
        Install-PackageSet -PythonExe $Env.Python -SetName $selected -EnvPath $Env.Path | Out-Null
    }
    else {
        Write-Err "Invalid selection"
    }
}

# ============================================================================
# HELP SCREENS
# ============================================================================

function Show-ManualActivation {
    Write-Section "MANUAL ACTIVATION"
    Write-Host '  & "$HOME\.venvs\YOUR-ENV-NAME\Scripts\Activate.ps1"' -ForegroundColor White
    Write-Host ""
    Write-Host "  After activation:" -ForegroundColor Gray
    Write-Host "    jupyter lab             # Start JupyterLab" -ForegroundColor DarkGray
    Write-Host "    pip install <package>   # Install package" -ForegroundColor DarkGray
    Write-Host "    deactivate              # Exit environment" -ForegroundColor DarkGray
}

function Show-DirectoryInfo {
    Write-Section "DIRECTORY STRUCTURE"
    Write-Host "  ENVIRONMENTS: $script:VENV_DIR" -ForegroundColor Yellow
    Write-Host "    Contains Python installations and packages." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  PROJECTS: $script:PROJECTS_DIR" -ForegroundColor Yellow
    Write-Host "    Your notebooks, data, and work files." -ForegroundColor Gray
    Write-Host "    BACK THIS UP!" -ForegroundColor Red
}

function Show-SystemRequirements {
    Write-Section "SYSTEM REQUIREMENTS"
    
    if ($null -eq $script:PackageConfig) {
        Write-Warn "Config not loaded"
        return
    }
    
    $reqs = $script:PackageConfig.system_requirements
    
    Write-Host "  NOTES:" -ForegroundColor Yellow
    foreach ($note in $reqs.notes) {
        Write-Host "    - $note" -ForegroundColor Gray
    }
    
    if ($reqs.package_dependencies) {
        Write-Host ""
        Write-Host "  PACKAGE DEPENDENCIES:" -ForegroundColor Yellow
        foreach ($dep in $reqs.package_dependencies.PSObject.Properties) {
            $info = $dep.Value
            Write-Host "    $($dep.Name): $($info.requires)" -ForegroundColor Cyan
            if ($info.url) { Write-Host "      $($info.url)" -ForegroundColor DarkGray }
            if ($info.notes) { Write-Host "      $($info.notes)" -ForegroundColor DarkGray }
        }
    }
}

# ============================================================================
# MAIN MENU
# ============================================================================

function Show-HelpMenu {
    Clear-Host
    Write-Host ""
    Write-Host "  HELP" -ForegroundColor Cyan
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [1] Manual activation commands"
    Write-Host "  [2] Directory locations"
    Write-Host "  [3] System requirements"
    Write-Host "  [4] How to delete environments"
    Write-Host "  [5] Disk usage"
    Write-Host ""
    Write-Host "  [0] Back to main menu" -ForegroundColor DarkGray
    Write-Host ""
    
    $sub = Read-Host "  Select"
    switch ($sub) {
        "1" { Show-ManualActivation }
        "2" { Show-DirectoryInfo }
        "3" { Show-SystemRequirements }
        "4" { Show-DeletionHelp }
        "5" { Show-DiskUsage }
    }
}

function Show-DiskUsage {
    Write-Host ""
    Write-Host "  DISK USAGE" -ForegroundColor Cyan
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Calculating..." -ForegroundColor DarkGray
    
    $diskUsage = Get-DiskUsageSummary
    
    Write-Host "`r  Environments: $($diskUsage.EnvironmentsSizeFormatted)     " -ForegroundColor White
    Write-Host "  Projects:     $($diskUsage.ProjectsSizeFormatted)" -ForegroundColor White
    Write-Host "  ────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  Total:        $($diskUsage.TotalSizeFormatted)" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Locations:" -ForegroundColor DarkGray
    Write-Host "    Environments: $script:VENV_DIR" -ForegroundColor DarkGray
    Write-Host "    Projects:     $script:PROJECTS_DIR" -ForegroundColor DarkGray
    Write-Host ""
}

function Show-DeletionHelp {
    Write-Host ""
    Write-Host "  HOW TO DELETE ENVIRONMENTS" -ForegroundColor Yellow
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  THIS SCRIPT CONTAINS ZERO DELETE OPERATIONS." -ForegroundColor Green
    Write-Host "  It never removes files, folders, or environments." -ForegroundColor Gray
    Write-Host "  Commands below are for reference - run them yourself." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  1. DELETE AN ENVIRONMENT:" -ForegroundColor Cyan
    Write-Host "     - Close any running Jupyter sessions for that environment"
    Write-Host "     - Delete the folder: %USERPROFILE%\.venvs\<env-name>"
    Write-Host "     - Optionally delete project: %USERPROFILE%\JupyterProjects\<env-name>"
    Write-Host ""
    Write-Host "  2. DELETE ALL ENVIRONMENTS:" -ForegroundColor Cyan
    Write-Host "     - Close all Jupyter sessions"
    Write-Host "     - Delete folder: %USERPROFILE%\.venvs"
    Write-Host ""
    Write-Host "  3. KEEP YOUR WORK:" -ForegroundColor Green
    Write-Host "     - Your notebooks/data are in JupyterProjects (separate from envs)"
    Write-Host "     - Deleting an environment does NOT delete your project files"
    Write-Host "     - Back up JupyterProjects before any cleanup"
    Write-Host ""
    Write-Host "  COMMANDS (run in PowerShell):" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    # List environments" -ForegroundColor DarkGray
    Write-Host "    Get-ChildItem `$env:USERPROFILE\.venvs" -ForegroundColor White
    Write-Host ""
    Write-Host "    # Delete one environment" -ForegroundColor DarkGray
    Write-Host "    Remove-Item -Recurse -Force `$env:USERPROFILE\.venvs\<name>" -ForegroundColor White
    Write-Host ""
    Write-Host "    # Delete all environments (CAREFUL)" -ForegroundColor DarkGray
    Write-Host "    Remove-Item -Recurse -Force `$env:USERPROFILE\.venvs" -ForegroundColor White
    Write-Host ""
}

function Show-Menu {
    Clear-Host
    $last = Get-LastSession
    $runningSessions = Get-RunningJupyterSessions
    
    Write-Host ""
    Write-Host "  STANK PYTHON VENV MANAGER v0.1" -ForegroundColor Cyan
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    if ($runningSessions.Count -gt 0) {
        Write-Host "  Running Jupyter sessions: $($runningSessions.Count)" -ForegroundColor DarkGray
    }
    Write-Host ""
    
    # Quick resume if available
    if ($last) {
        Write-Host "  [0] RESUME: $($last.EnvName)" -ForegroundColor Green
        Write-Host ""
    }
    
    Write-Host "  CREATE" -ForegroundColor Yellow
    Write-Host "    1  Empty environment"
    Write-Host "    2  With JupyterLab"
    Write-Host "    3  Data Science starter"
    Write-Host "    4  By Job Role            " -NoNewline
    Write-Host "(9 pre-configured roles)" -ForegroundColor DarkGray
    Write-Host "    5  Full install           " -NoNewline
    Write-Host "(all 416 packages)" -ForegroundColor DarkGray
    Write-Host ""
    
    Write-Host "  USE" -ForegroundColor Yellow
    Write-Host "    6  View / Launch environments"
    Write-Host "    7  Add packages to environment"
    Write-Host "    S  Show running Jupyter sessions"
    Write-Host ""
    
    Write-Host "  HELP" -ForegroundColor Yellow
    Write-Host "    8  Manual activation / directories / requirements"
    Write-Host ""
    
    Write-Host "    Q  Quit" -ForegroundColor DarkGray
    Write-Host ""
}

function Main {
    # Load config
    Load-PackageConfig | Out-Null
    
    if (-not (Test-PythonInstalled)) { Pause; return }
    
    Write-Info "Ready. Loading menu..."
    Start-Sleep -Milliseconds 500
    
    while ($true) {
        Show-Menu
        $choice = Read-Host "  Select"
        
        switch ($choice.ToUpper()) {
            "1" {
                $name = Read-Host "    Environment name"
                if ([string]::IsNullOrWhiteSpace($name)) { Write-Err "Name cannot be empty"; Pause; continue }
                $createDir = Confirm-Action "Create project directory?"
                New-Environment -Name $name -PackagePreset "none" -CreateProjectDir:$createDir | Out-Null
                Pause
            }
            "2" {
                $name = Read-Host "    Environment name"
                if ([string]::IsNullOrWhiteSpace($name)) { Write-Err "Name cannot be empty"; Pause; continue }
                if (New-Environment -Name $name -PackagePreset "jupyter" -CreateProjectDir) {
                    if (Confirm-Action "Launch JupyterLab now?") {
                        $envPath = Join-Path $script:VENV_DIR $name
                        $env = [PSCustomObject]@{ Name = $name; Path = $envPath; Python = Join-Path $envPath "Scripts\python.exe" }
                        Start-JupyterLab -Env $env
                    }
                }
                Pause
            }
            "3" {
                $name = Read-Host "    Environment name"
                if ([string]::IsNullOrWhiteSpace($name)) { Write-Err "Name cannot be empty"; Pause; continue }
                if (New-Environment -Name $name -PackagePreset "data_science" -CreateProjectDir) {
                    if (Confirm-Action "Launch JupyterLab now?") {
                        $envPath = Join-Path $script:VENV_DIR $name
                        $env = [PSCustomObject]@{ Name = $name; Path = $envPath; Python = Join-Path $envPath "Scripts\python.exe" }
                        Start-JupyterLab -Env $env
                    }
                }
                Pause
            }
            "4" {
                $roleName = Show-JobRoleMenu
                if ($roleName) {
                    $name = Read-Host "    Environment name"
                    if ([string]::IsNullOrWhiteSpace($name)) { Write-Err "Name cannot be empty"; Pause; continue }
                    if (New-Environment -Name $name -PackagePreset $roleName -CreateProjectDir) {
                        if (Confirm-Action "Launch JupyterLab now?") {
                            $envPath = Join-Path $script:VENV_DIR $name
                            $env = [PSCustomObject]@{ Name = $name; Path = $envPath; Python = Join-Path $envPath "Scripts\python.exe" }
                            Start-JupyterLab -Env $env
                        }
                    }
                }
                Pause
            }
            "5" {
                Write-Host ""
                Write-Host "  FULL INSTALLATION" -ForegroundColor Magenta
                Write-Host "  Installs ALL packages (~400+) from all categories." -ForegroundColor Gray
                Write-Host "  Time: 2-3 hours | Disk: 10-12 GB" -ForegroundColor Yellow
                Write-Host ""
                $name = Read-Host "    Environment name"
                if ([string]::IsNullOrWhiteSpace($name)) { Write-Err "Name cannot be empty"; Pause; continue }
                if (-not (Test-DiskSpace -RequiredGB 12)) {
                    if (-not (Confirm-Action "Low disk space. Continue anyway?")) { Pause; continue }
                }
                if (New-Environment -Name $name -PackagePreset "full_stack" -CreateProjectDir) {
                    if (Confirm-Action "Launch JupyterLab now?") {
                        $envPath = Join-Path $script:VENV_DIR $name
                        $env = [PSCustomObject]@{ Name = $name; Path = $envPath; Python = Join-Path $envPath "Scripts\python.exe" }
                        Start-JupyterLab -Env $env
                    }
                }
                Pause
            }
            "6" {
                $env = Select-Environment -Prompt "Select environment"
                if ($env) {
                    Show-EnvironmentManifest -Env $env
                    Write-Host "    [L] Launch JupyterLab   [A] Show activation command" -ForegroundColor DarkGray
                    Write-Host ""
                    $sub = Read-Host "    Select or Enter to go back"
                    if ($sub -eq 'L' -or $sub -eq 'l') {
                        Start-JupyterLab -Env $env
                    }
                    elseif ($sub -eq 'A' -or $sub -eq 'a') {
                        Write-Host ""
                        Write-Host "    Activate:" -ForegroundColor Cyan
                        Write-Host "    & `"$($env.Path)\Scripts\Activate.ps1`"" -ForegroundColor White
                    }
                }
                Pause
            }
            "7" {
                $env = Select-Environment -Prompt "Select environment"
                if ($env) { Show-PackageSetsMenu -Env $env }
                Pause
            }
            "0" { Start-LastSession; Pause }
            "8" {
                Show-HelpMenu
                Pause
            }
            "S" {
                Show-RunningSessions
                Pause
            }
            "Q" { Write-Host ""; Write-OK "Goodbye!"; Write-Host ""; return }
            default { Write-Warn "Invalid: '$choice'"; Start-Sleep -Milliseconds 500 }
        }
    }
}

# ============================================================================
# START
# ============================================================================

Write-Host ""
Write-Host "  Stank Python Virtual Environment Manager" -ForegroundColor Cyan
Write-Host "  Version 0.1" -ForegroundColor DarkGray
Write-Host "  Created by Nick Stankiewicz" -ForegroundColor DarkGray
Write-Host ""

Main
