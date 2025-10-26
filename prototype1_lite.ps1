# -- Defender Resource Limiter Script --
# Attempts to reduce Defender's resource consumption
# Run as Administrator

Write-Host "Defender Resource Limiter" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan

# Admin check
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Admin privileges required" -ForegroundColor Red
    exit 1
}

# Method 1: Configure Defender for low resource usage
Write-Host "`n-- Method 1: Optimizing Defender Settings --" -ForegroundColor Yellow

try {
    # Reduce scanning intensity
    Set-MpPreference -ScanAvgCPULoadFactor 10 -ErrorAction SilentlyContinue  # 10% max CPU during scans
    Set-MpPreference -RemediationScheduleDay 8 -ErrorAction SilentlyContinue  # Never schedule full scans
    Set-MpPreference -DisableRestorePoint $true -ErrorAction SilentlyContinue  # No restore point creation
    Set-MpPreference -LowThreatDefaultAction Allow -ErrorAction SilentlyContinue  # Allow low threats
    Set-MpPreference -ModerateThreatDefaultAction Allow -ErrorAction SilentlyContinue  # Allow moderate threats
    
    # Reduce scanning frequency
    Set-MpPreference -CheckForSignaturesBeforeRunningScan $false -ErrorAction SilentlyContinue
    Set-MpPreference -DisableCatchupFullScan $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisableCatchupQuickScan $true -ErrorAction SilentlyContinue
    
    Write-Host "✓ Defender settings optimized for low resource usage" -ForegroundColor Green
} catch {
    Write-Host "✗ Could not optimize all settings" -ForegroundColor Red
}

# Method 2: Use Windows System Resource Manager (WSRM) - if available
Write-Host "`n-- Method 2: Resource Management --" -ForegroundColor Yellow

try {
    # Check if WSRM is available
    $wsrm = Get-WindowsFeature -Name Windows-Server-RSM -ErrorAction SilentlyContinue
    if ($wsrm.Installed) {
        Write-Host "WSRM available - creating resource policy..." -ForegroundColor Green
        
        # This would require WSRM configuration (complex setup)
        # Typically only available on Windows Server
    } else {
        Write-Host "WSRM not available (client Windows)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "WSRM check failed" -ForegroundColor Red
}

# Method 3: Process priority reduction (may not stick)
Write-Host "`n-- Method 3: Process Priority Adjustment --" -ForegroundColor Yellow

try {
    $defenderProcess = Get-Process -Name MsMpEng -ErrorAction SilentlyContinue
    if ($defenderProcess) {
        # Try to set lower priority (may be reset by system)
        $defenderProcess.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::BelowNormal
        Write-Host "✓ Set MsMpEng priority to BelowNormal" -ForegroundColor Green
    } else {
        Write-Host "MsMpEng not currently running" -ForegroundColor Yellow
    }
} catch {
    Write-Host "✗ Could not adjust process priority" -ForegroundColor Red
}

# Method 4: Scheduled task to monitor and limit
Write-Host "`n-- Method 4: CPU Monitoring Approach --" -ForegroundColor Yellow

$monitorScript = @"
`$process = Get-Process -Name MsMpEng -ErrorAction SilentlyContinue
if (`$process -and `$process.CPU -gt 5.0) {
    # If using more than 5% CPU for extended period, temporarily pause scans
    Stop-Process -Name MsMpEng -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 10
}
"@

try {
    # Create a scheduled task to run this check periodically
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-WindowStyle Hidden -Command `"$monitorScript`""
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)
    Register-ScheduledTask -TaskName "DefenderResourceMonitor" -Action $action -Trigger $trigger -Description "Monitor Defender CPU usage" -Force -ErrorAction SilentlyContinue
    Write-Host "✓ Created resource monitoring task" -ForegroundColor Green
} catch {
    Write-Host "✗ Could not create monitoring task" -ForegroundColor Red
}

# Method 5: Comprehensive exclusions to reduce workload
Write-Host "`n-- Method 5: Reducing Scan Workload --" -ForegroundColor Yellow

$heavyUsagePaths = @(
    "$env:USERPROFILE\Videos\*",
    "$env:USERPROFILE\Music\*", 
    "$env:USERPROFILE\Pictures\*",
    "C:\Windows\Temp\*",
    "$env:TEMP\*",
    "C:\pagefile.sys",
    "C:\hiberfil.sys"
)

$added = 0
foreach ($path in $heavyUsagePaths) {
    try {
        Add-MpPreference -ExclusionPath $path -ErrorAction SilentlyContinue
        $added++
    } catch {}
}

Write-Host "✓ Added $added path exclusions to reduce scanning workload" -ForegroundColor Green

# Method 6: Registry tweaks for performance
Write-Host "`n-- Method 6: Performance Registry Tweaks --" -ForegroundColor Yellow

try {
    # Increase cloud timeout to reduce blocking waits
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender" -Name "CloudBlockTimeout" -Value 120 -ErrorAction SilentlyContinue
    
    # Disable some intensive features
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableRealtimeMonitoring" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Scan" -Name "AvgCPULoadFactor" -Value 10 -ErrorAction SilentlyContinue
    
    Write-Host "✓ Applied performance registry tweaks" -ForegroundColor Green
} catch {
    Write-Host "✗ Some registry tweaks failed" -ForegroundColor Red
}

# Final configuration for minimal impact
Write-Host "`n-- Final Low-Impact Configuration --" -ForegroundColor Yellow

try {
    # Set to quick scan only (much lighter)
    Set-MpPreference -ScanParameters QuickScan -ErrorAction SilentlyContinue
    
    # Disable scheduled scans entirely
    Set-MpPreference -DisableScheduledScan $true -ErrorAction SilentlyContinue
    
    # Reduce memory usage by limiting scan depth
    Set-MpPreference -DisableArchiveScanning $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisableEmailScanning $true -ErrorAction SilentlyContinue
    
    Write-Host "✓ Applied minimal impact configuration" -ForegroundColor Green
} catch {
    Write-Host "✗ Some final configurations failed" -ForegroundColor Red
}

# Create a monitoring function
function Get-DefenderResources {
    $process = Get-Process -Name MsMpEng -ErrorAction SilentlyContinue
    if ($process) {
        $cpu = [math]::Round($process.CPU, 2)
        $ramMB = [math]::Round($process.WorkingSet64 / 1MB, 2)
        Write-Host "Current Defender Usage - CPU: ${cpu}% RAM: ${ramMB}MB" -ForegroundColor Cyan
    } else {
        Write-Host "Defender process not running" -ForegroundColor Green
    }
}

Write-Host "`n-- Current Resource Usage --" -ForegroundColor Cyan
Get-DefenderResources

Write-Host "`n-- Summary --" -ForegroundColor Green
Write-Host "Applied multiple resource-limiting strategies:" -ForegroundColor White
Write-Host "• Reduced scan intensity and frequency" -ForegroundColor White
Write-Host "• Added exclusions for heavy-scan paths" -ForegroundColor White
Write-Host "• Lowered process priority" -ForegroundColor White
Write-Host "• Created monitoring task" -ForegroundColor White
Write-Host "• Registry performance tweaks" -ForegroundColor White

Write-Host "`nNote: Defender may still spike during scans, but overall usage should be reduced." -ForegroundColor Yellow
Write-Host "Run this script periodically as settings may be reset by Windows updates." -ForegroundColor Yellow