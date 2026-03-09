<#
.SYNOPSIS
    Generates a _Sidebar.md file for GitHub wiki based on file naming conventions.

.DESCRIPTION
    Scans wiki directory for markdown files and creates a hierarchical table of contents
    based on underscore-separated naming convention (e.g., UserGuide_Section_Page).

.PARAMETER WikiPath
    Path to the wiki repository. Defaults to .\wiki

.EXAMPLE
    .\Generate-WikiSidebar.ps1
    .\Generate-WikiSidebar.ps1 -WikiPath "C:\path\to\wiki"
#>

param(
    [string]$WikiPath = ".\mcnamara-docs.wiki"
)

# Repository URLs for reference
$MainRepo = "https://github.com/BrianMcNamaraJustice/mcnamara-docs.git"
$WikiRepo = "https://github.com/BrianMcNamaraJustice/mcnamara-docs.wiki.git"

# Files to exclude from sidebar
$ExcludeFiles = @('_Sidebar.md', 'Home.md', '_Footer.md', '_Header.md')

function Convert-ToTitleCase {
    param([string]$Text)
    
    # Split on capital letters but keep consecutive capitals together
    $words = $Text -creplace '([A-Z]+)([A-Z][a-z])', '$1 $2' -creplace '([a-z\d])([A-Z])', '$1 $2'
    
    # Clean up and return
    return $words.Trim()
}

function Build-SidebarStructure {
    param([string]$Path)
    
    # Get all markdown files
    $files = Get-ChildItem -Path $Path -Filter "*.md" | 
             Where-Object { $ExcludeFiles -notcontains $_.Name }
    
    if ($files.Count -eq 0) {
        Write-Warning "No markdown files found in $Path"
        return $null
    }
    
    # Build hierarchical structure
    $structure = @{}
    
    foreach ($file in $files) {
        $nameWithoutExt = $file.BaseName
        $parts = $nameWithoutExt -split '_'
        
        # Navigate/create the hierarchy
        $currentLevel = $structure
        
        for ($i = 0; $i -lt $parts.Count; $i++) {
            $part = $parts[$i]
            $isLastPart = ($i -eq $parts.Count - 1)
            
            if ($isLastPart) {
                # This is the actual page - store with link
                if (-not $currentLevel.ContainsKey('_pages')) {
                    $currentLevel['_pages'] = @()
                }
                $currentLevel['_pages'] += @{
                    Title = Convert-ToTitleCase $part
                    Link = $nameWithoutExt
                }
            }
            else {
                # This is a category/section
                if (-not $currentLevel.ContainsKey($part)) {
                    $currentLevel[$part] = @{}
                }
                $currentLevel = $currentLevel[$part]
            }
        }
    }
    
    return $structure
}

function Write-SidebarContent {
    param(
        [hashtable]$Structure,
        [int]$HeaderLevel = 2,
        [string]$ParentPath = ""
    )
    
    $output = @()
    
    # Sort keys alphabetically, but process _pages last
    $keys = $Structure.Keys | Where-Object { $_ -ne '_pages' } | Sort-Object
    
    foreach ($key in $keys) {
        $displayName = Convert-ToTitleCase $key
        $headerPrefix = "#" * $HeaderLevel
        
        # Add header for this category
        $output += ""
        $output += "$headerPrefix $displayName"
        $output += ""
        
        # Check if this level has pages
        if ($Structure[$key].ContainsKey('_pages')) {
            $pages = $Structure[$key]['_pages'] | Sort-Object -Property Title
            foreach ($page in $pages) {
                $output += "- [$($page.Title)]($($page.Link))"
            }
        }
        
        # Check if this level has subcategories (keys other than _pages)
        $subKeys = $Structure[$key].Keys | Where-Object { $_ -ne '_pages' }
        if ($subKeys.Count -gt 0) {
            # Recursively process nested structure
            $nestedOutput = Write-SidebarContent -Structure $Structure[$key] -HeaderLevel ($HeaderLevel + 1) -ParentPath "$ParentPath$key/"
            $output += $nestedOutput
        }
    }
    
    return $output
}

# Main execution
Write-Host "Generating Wiki Sidebar..." -ForegroundColor Cyan
Write-Host "Wiki Path: $WikiPath" -ForegroundColor Gray

if (-not (Test-Path $WikiPath)) {
    Write-Error "Wiki path not found: $WikiPath"
    exit 1
}

# Build the structure
$structure = Build-SidebarStructure -Path $WikiPath

if ($null -eq $structure) {
    exit 1
}

# Generate sidebar content
$sidebarContent = @()
$sidebarContent += "# Documentation"
$sidebarContent += ""
$sidebarContent += Write-SidebarContent -Structure $structure
$sidebarContent += ""
$sidebarContent += "---"
$sidebarContent += ""
$sidebarContent += "_Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm')_"

# Write to file
$sidebarPath = Join-Path $WikiPath "_Sidebar.md"
$sidebarContent | Out-File -FilePath $sidebarPath -Encoding UTF8 -Force

Write-Host ""
Write-Host "Sidebar generated successfully!" -ForegroundColor Green
Write-Host "Output: $sidebarPath" -ForegroundColor Gray
Write-Host ""
Write-Host "Preview:" -ForegroundColor Cyan
$sidebarContent | ForEach-Object { Write-Host $_ -ForegroundColor White }
