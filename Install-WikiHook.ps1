<#
.SYNOPSIS
    Installs a Git pre-commit hook to automatically regenerate the wiki sidebar.

.DESCRIPTION
    Creates a pre-commit hook in the wiki repository that regenerates _Sidebar.md
    whenever markdown files are added, modified, or deleted.
#>

param(
    [string]$WikiPath = ".\mcnamara-docs.wiki",
    [string]$ScriptPath = ".\Generate-WikiSidebar.ps1"
)

$WikiPath = Resolve-Path $WikiPath -ErrorAction Stop
$ScriptPath = Resolve-Path $ScriptPath -ErrorAction Stop

$hooksDir = Join-Path $WikiPath ".git\hooks"
$hookFile = Join-Path $hooksDir "pre-commit"
$hookPsFile = Join-Path $hooksDir "pre-commit.ps1"

# Create the PowerShell hook script
$hookPsContent = @"
# Auto-generate wiki sidebar before commit
param()

`$WikiDir = git rev-parse --show-toplevel
`$ScriptPath = "$($ScriptPath.Replace('\', '\\'))"

# Check if any .md files (except _Sidebar.md) are being committed
`$mdFiles = git diff --cached --name-only --diff-filter=ACM | Where-Object { `$_ -match '\.md$' -and `$_ -ne '_Sidebar.md' }

if (`$mdFiles) {
    Write-Host "Markdown files changed, regenerating sidebar..." -ForegroundColor Yellow
    
    # Run the sidebar generation script
    & `$ScriptPath -WikiPath `$WikiDir | Out-Null
    
    # Stage the updated sidebar
    `$sidebarFile = Join-Path `$WikiDir "_Sidebar.md"
    if (Test-Path `$sidebarFile) {
        git add `$sidebarFile
        Write-Host "Sidebar regenerated and staged for commit" -ForegroundColor Green
    }
}

exit 0
"@

# Write the PowerShell hook
$hookPsContent | Out-File -FilePath $hookPsFile -Encoding UTF8 -Force

# Create wrapper shell script for Git
$hookShContent = @"
#!/bin/sh
# Git pre-commit hook - calls PowerShell script
powershell.exe -ExecutionPolicy Bypass -NoProfile -File ".git/hooks/pre-commit.ps1"
"@

# Write the shell hook
$hookShContent | Out-File -FilePath $hookFile -Encoding UTF8 -Force -NoNewline

Write-Host ""
Write-Host "Git pre-commit hook installed successfully!" -ForegroundColor Green
Write-Host "Location: $hookFile" -ForegroundColor Gray
Write-Host ""
Write-Host "The sidebar will now auto-update whenever you commit .md files to the wiki." -ForegroundColor Cyan
