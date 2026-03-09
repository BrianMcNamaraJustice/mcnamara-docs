<#
.SYNOPSIS
    Monitors the wiki directory and automatically regenerates the sidebar when files change.

.DESCRIPTION
    Starts a background file system watcher that monitors the wiki directory for
    markdown file changes and automatically regenerates the _Sidebar.md file.

.PARAMETER WikiPath
    Path to the wiki repository. Defaults to .\mcnamara-docs.wiki

.PARAMETER AutoCommit
    If specified, automatically commits and pushes the updated sidebar to Git.

.EXAMPLE
    .\Watch-Wiki.ps1
    .\Watch-Wiki.ps1 -AutoCommit
#>

param(
    [string]$WikiPath = ".\mcnamara-docs.wiki",
    [switch]$AutoCommit
)

$WikiPath = Resolve-Path $WikiPath -ErrorAction Stop
$ScriptPath = Join-Path $PSScriptRoot "Generate-WikiSidebar.ps1"

Write-Host "Starting Wiki Sidebar Auto-Generator..." -ForegroundColor Cyan
Write-Host "Monitoring: $WikiPath" -ForegroundColor Gray
Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Yellow
Write-Host ""

# Create file system watcher
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $WikiPath
$watcher.Filter = "*.md"
$watcher.IncludeSubdirectories = $false
$watcher.NotifyFilter = [System.IO.NotifyFilters]::FileName -bor 
                        [System.IO.NotifyFilters]::LastWrite

# Debounce mechanism to avoid multiple rapid triggers
$script:lastRun = [DateTime]::MinValue
$debounceSeconds = 3

# Define the action to take when a file changes
$action = {
    param($sender, $eventArgs)
    
    $fileName = $eventArgs.Name
    
    # Ignore _Sidebar.md itself
    if ($fileName -eq "_Sidebar.md") {
        return
    }
    
    # Debounce - only run if enough time has passed
    $now = [DateTime]::Now
    if (($now - $script:lastRun).TotalSeconds -lt $debounceSeconds) {
        return
    }
    $script:lastRun = $now
    
    Write-Host ""
    Write-Host "[$($now.ToString('HH:mm:ss'))] Detected change: $fileName" -ForegroundColor Yellow
    Write-Host "Regenerating sidebar..." -ForegroundColor Gray
    
    # Regenerate the sidebar
    try {
        & $using:ScriptPath -WikiPath $using:WikiPath | Out-Null
        Write-Host "Sidebar updated successfully!" -ForegroundColor Green
        
        # Auto-commit if requested
        if ($using:AutoCommit) {
            Push-Location $using:WikiPath
            try {
                git add _Sidebar.md
                $status = git status --porcelain _Sidebar.md
                
                if ($status) {
                    git commit -m "Auto-update sidebar (detected change in $fileName)"
                    git push
                    Write-Host "Changes committed and pushed!" -ForegroundColor Green
                }
            }
            catch {
                Write-Host "Git operation failed: $_" -ForegroundColor Red
            }
            finally {
                Pop-Location
            }
        }
    }
    catch {
        Write-Host "Error regenerating sidebar: $_" -ForegroundColor Red
    }
}

# Register event handlers
$handlers = @()
$handlers += Register-ObjectEvent -InputObject $watcher -EventName Created -Action $action
$handlers += Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $action
$handlers += Register-ObjectEvent -InputObject $watcher -EventName Deleted -Action $action
$handlers += Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action $action

# Start watching
$watcher.EnableRaisingEvents = $true

Write-Host "Monitoring started. Waiting for changes..." -ForegroundColor Green
Write-Host ""

try {
    # Keep the script running
    while ($true) {
        Start-Sleep -Seconds 1
    }
}
finally {
    # Cleanup
    Write-Host ""
    Write-Host "Stopping monitoring..." -ForegroundColor Yellow
    
    $watcher.EnableRaisingEvents = $false
    $handlers | ForEach-Object { Unregister-Event -SourceIdentifier $_.Name }
    $watcher.Dispose()
    
    Write-Host "Monitoring stopped." -ForegroundColor Gray
}
