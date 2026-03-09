<#
.SYNOPSIS
    Quick command to update wiki sidebar and commit changes.

.EXAMPLE
    .\Update-Wiki.ps1
    .\Update-Wiki.ps1 -CommitMessage "Added new pages"
#>

param(
    [string]$CommitMessage = "Update wiki content and sidebar"
)

$WikiPath = ".\mcnamara-docs.wiki"

Write-Host "Updating wiki..." -ForegroundColor Cyan

# Regenerate sidebar
.\Generate-WikiSidebar.ps1 -WikiPath $WikiPath | Out-Null

# Commit and push
Push-Location $WikiPath
try {
    git add .
    git commit -m $CommitMessage
    git push
    Write-Host "Wiki updated successfully!" -ForegroundColor Green
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
finally {
    Pop-Location
}
