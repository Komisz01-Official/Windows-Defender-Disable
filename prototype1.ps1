# -- Windows Defender Management Script --
# Comprehensive approach with realistic expectations
# Run as Administrator

Write-Host "Windows Defender Management Tool" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

# Admin check
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $IsAdmin) {
    Write-Host "Administrator privileges REQUIRED" -ForegroundColor Red
    Write-Host "Please run as Administrator" -ForegroundColor Yellow
    exit 1
}

Write-Host "Running as Administrator: YES" -ForegroundColor Green

# Initial diagnostics
Write-Host "`n-- Initial System Diagnostics --" -ForegroundColor Yellow

try {
    $mpStatus = Get-MpComputerStatus -ErrorAction Stop
    $mpPref = Get-MpPreference -ErrorAction Stop
    
    Write-Host "Defender Status:" -ForegroundColor White
    Write-Host "  Real-time Protection: $($mpStatus.RealTimeProtectionEnabled)" -ForegroundColor $(if($mpStatus.RealTimeProtectionEnabled){'Red'}else{'Green'})
    Write-Host "  Tamper Protection: $($mpStatus.IsTamperProtected)" -ForegroundColor $(if($mpStatus.IsTamperProtected){'Red'}else{'Green'})
    Write-Host "  Antivirus Enabled: $($mpStatus.AntivirusEnabled)" -ForegroundColor $(if($mpStatus.AntivirusEnabled){'Yellow'}else{'Green'})
    Write-Host "  Antispyware Enabled: $($mpStatus.AntispywareEnabled)" -ForegroundColor $(if($mpStatus.AntispywareEnabled){'Yellow'}else{'Green'})
    
    # Check management status
    if ($mpStatus.IsTamperProtected) {
        Write-Host "`n⚠️  TAMPER PROTECTION IS ACTIVE" -ForegroundColor Red
        Write-Host "Many disabling attempts will be blocked by system security" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Could not retrieve Defender status" -ForegroundColor Red
}

# Service status
Write-Host "`n-- Service Status --" -ForegroundColor Yellow
try {
    $service = Get-Service -Name WinDefend -ErrorAction Stop
    Write-Host "WinDefend Service: $($service.Status)" -ForegroundColor $(if($service.Status -eq 'Running'){'Red'}else{'Green'})
    Write-Host "Startup Type: $($service.StartType)" -ForegroundColor White
} catch {
    Write-Host "WinDefend service not found" -ForegroundColor Green
}

# Process check
Write-Host "`n-- Process Check --" -ForegroundColor Yellow
$process = Get-Process -Name MsMpEng -ErrorAction SilentlyContinue
if ($process) {
    Write-Host "MsMpEng.exe running (PID: $($process.Id))" -ForegroundColor Red
} else {
    Write-Host "MsMpEng.exe not running" -ForegroundColor Green
}

# User confirmation
Write-Host "`n⚠️  WARNING: This script will attempt to configure Windows Defender" -ForegroundColor Red
Write-Host "This includes disabling features and adding exclusions." -ForegroundColor Yellow
Write-Host "Your system security will be reduced." -ForegroundColor Red

$confirmation = Read-Host "`nDo you want to proceed? (yes/no)"
if ($confirmation -ne 'yes') {
    Write-Host "Operation cancelled by user." -ForegroundColor Yellow
    exit 0
}

# Phase 1: Attempt to disable Tamper Protection (may fail)
Write-Host "`n-- Phase 1: Attempting to configure Tamper Protection --" -ForegroundColor Yellow

try {
    # Official method - usually fails if Tamper Protection is active
    Set-MpPreference -DisableTamperProtection $true -ErrorAction SilentlyContinue
    if ($?) {
        Write-Host "✓ Tamper Protection configuration attempted" -ForegroundColor Green
    } else {
        Write-Host "✗ Tamper Protection configuration blocked" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Tamper Protection configuration failed" -ForegroundColor Red
}

# Phase 2: Comprehensive exclusions
Write-Host "`n-- Phase 2: Adding comprehensive exclusions --" -ForegroundColor Yellow

$exclusionPaths = @(
    "$env:USERPROFILE\*",
    "C:\Program Files\*",
    "C:\Program Files (x86)\*", 
    "D:\*",
    "E:\*",
    "C:\Windows\Temp\*",
    "$env:TEMP\*",
    "C:\Users\Public\*"
)

$exclusionProcesses = @(
    "devenv.exe", "code.exe", "msbuild.exe", "node.exe", "python.exe",
    "java.exe", "pwsh.exe", "docker.exe", "chrome.exe", "firefox.exe",
    "steam.exe", "discord.exe", "telegram.exe", "notepad++.exe"
)

$exclusionExtensions = @(
    ".log", ".tmp", ".cache", ".db", ".sqlite", ".json", ".xml",
    ".txt", ".md", ".config", ".ini", ".cfg"
)

$addedExclusions = 0

foreach ($path in $exclusionPaths) {
    try {
        Add-MpPreference -ExclusionPath $path -ErrorAction SilentlyContinue
        $addedExclusions++
        Write-Host "✓ Added path exclusion: $path" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to add: $path" -ForegroundColor Red
    }
}

foreach ($process in $exclusionProcesses) {
    try {
        Add-MpPreference -ExclusionProcess $process -ErrorAction SilentlyContinue
        $addedExclusions++
        Write-Host "✓ Added process exclusion: $process" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to add: $process" -ForegroundColor Red
    }
}

foreach ($extension in $exclusionExtensions) {
    try {
        Add-MpPreference -ExclusionExtension $extension -ErrorAction SilentlyContinue
        $addedExclusions++
        Write-Host "✓ Added extension exclusion: $extension" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to add: $extension" -ForegroundColor Red
    }
}

Write-Host "`nTotal exclusions added: $addedExclusions" -ForegroundColor $(if($addedExclusions -gt 0){'Green'}else{'Red'})

# Phase 3: Disable Defender features
Write-Host "`n-- Phase 3: Disabling Defender features --" -ForegroundColor Yellow

$disabledFeatures = @()

$featuresToDisable = @(
    @{Name = "Real-time Monitoring"; Command = {Set-MpPreference -DisableRealtimeMonitoring $true}},
    @{Name = "Behavior Monitoring"; Command = {Set-MpPreference -DisableBehaviorMonitoring $true}},
    @{Name = "IOAV Protection"; Command = {Set-MpPreference -DisableIOAVProtection $true}},
    @{Name = "Script Scanning"; Command = {Set-MpPreference -DisableScriptScanning $true}},
    @{Name = "Email Scanning"; Command = {Set-MpPreference -DisableEmailScanning $true}},
    @{Name = "Archive Scanning"; Command = {Set-MpPreference -DisableArchiveScanning $true}},
    @{Name = "Cloud Protection"; Command = {Set-MpPreference -MAPSReporting 0}},
    @{Name = "Auto Sample Submission"; Command = {Set-MpPreference -SubmitSamplesConsent 2}}
)

foreach ($feature in $featuresToDisable) {
    try {
        & $feature.Command -ErrorAction SilentlyContinue
        if ($?) {
            $disabledFeatures += $feature.Name
            Write-Host "✓ Disabled: $($feature.Name)" -ForegroundColor Green
        } else {
            Write-Host "✗ Failed to disable: $($feature.Name)" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Error disabling: $($feature.Name)" -ForegroundColor Red
    }
}

# Phase 4: Service control
Write-Host "`n-- Phase 4: Service control --" -ForegroundColor Yellow

try {
    Stop-Service -Name WinDefend -Force -ErrorAction SilentlyContinue
    Write-Host "✓ Attempted to stop WinDefend service" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to stop WinDefend service" -ForegroundColor Red
}

try {
    Set-Service -Name WinDefend -StartupType Disabled -ErrorAction SilentlyContinue
    Write-Host "✓ Set WinDefend startup to Disabled" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to disable WinDefend service" -ForegroundColor Red
}

# Phase 5: Process termination
Write-Host "`n-- Phase 5: Process termination --" -ForegroundColor Yellow

try {
    Stop-Process -Name MsMpEng -Force -ErrorAction SilentlyContinue
    Write-Host "✓ Attempted to terminate MsMpEng.exe" -ForegroundColor Green
} catch {
    Write-Host "✗ MsMpEng.exe not running or couldn't be terminated" -ForegroundColor Green
}

# Final status check
Write-Host "`n-- Final System Status --" -ForegroundColor Cyan
Start-Sleep -Seconds 3

try {
    $finalStatus = Get-MpComputerStatus -ErrorAction Stop
    Write-Host "Real-time Protection: $($finalStatus.RealTimeProtectionEnabled)" -ForegroundColor $(if($finalStatus.RealTimeProtectionEnabled){'Red'}else{'Green'})
    Write-Host "Antivirus Enabled: $($finalStatus.AntivirusEnabled)" -ForegroundColor $(if($finalStatus.AntivirusEnabled){'Yellow'}else{'Green'})
    Write-Host "Tamper Protection: $($finalStatus.IsTamperProtected)" -ForegroundColor $(if($finalStatus.IsTamperProtected){'Red'}else{'Green'})
} catch {
    Write-Host "Could not retrieve final status - Defender may be disabled" -ForegroundColor Green
}

# Check if process is still running
$finalProcess = Get-Process -Name MsMpEng -ErrorAction SilentlyContinue
if ($finalProcess) {
    Write-Host "MsMpEng.exe is STILL RUNNING (PID: $($finalProcess.Id))" -ForegroundColor Red
    Write-Host "Tamper Protection is likely active and preventing changes" -ForegroundColor Yellow
} else {
    Write-Host "MsMpEng.exe is not running" -ForegroundColor Green
}

# Summary
Write-Host "`n-- Operation Summary --" -ForegroundColor Cyan
Write-Host "Features disabled: $($disabledFeatures.Count)/$($featuresToDisable.Count)" -ForegroundColor White
Write-Host "Exclusions added: $addedExclusions" -ForegroundColor White
Write-Host "Services stopped: $(if((Get-Service -Name WinDefend -ErrorAction SilentlyContinue).Status -eq 'Stopped'){'Yes'}else{'No'})" -ForegroundColor White

Write-Host "`n-- Important Notes --" -ForegroundColor Yellow
Write-Host "• Tamper Protection may revert some changes automatically" -ForegroundColor White
Write-Host "• Some changes may require reboot to take full effect" -ForegroundColor White
Write-Host "• Windows may re-enable Defender after updates" -ForegroundColor White
Write-Host "• Consider installing third-party antivirus for permanent solution" -ForegroundColor White

Write-Host "`nOperation completed." -ForegroundColor Cyan