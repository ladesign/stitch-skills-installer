@echo off
setlocal EnableExtensions DisableDelayedExpansion

title Stitch Skills -> OpenCode Sync

echo.
echo ============================================================
echo   Stitch Skills - OpenCode Skills Sync
echo ============================================================
echo.

REM ============================================================
REM 1. Basic configuration
REM ============================================================

set "REPO=https://github.com/google-labs-code/stitch-skills.git"
set "BRANCH=main"

set "BATCH_SCRIPT=%~f0"
set "PROJECT_ROOT=%~dp0"
if "%PROJECT_ROOT:~-1%"=="\" set "PROJECT_ROOT=%PROJECT_ROOT:~0,-1%"

set "TARGET=%PROJECT_ROOT%\.opencode\skills"

set "TEMP_ROOT=%TEMP%\stitch-skills-opencode"
set "SOURCE=%TEMP_ROOT%\repo"

echo [INFO] Project:
echo        %PROJECT_ROOT%
echo.
echo [INFO] Target:
echo        %TARGET%
echo.
echo [INFO] Repository:
echo        %REPO%
echo.

REM ============================================================
REM 2. Check dependencies
REM ============================================================

echo [1/6] Checking dependencies...

where git >nul 2>&1
if errorlevel 1 (
    echo.
    echo [ERROR] Git was not found.
    echo.
    echo Please install Git first:
    echo https://git-scm.com/
    echo.
    pause
    exit /b 1
)

where powershell >nul 2>&1
if errorlevel 1 (
    echo.
    echo [ERROR] PowerShell was not found.
    echo.
    pause
    exit /b 1
)

echo [OK] Git and PowerShell are available.
echo.

REM ============================================================
REM 2b. Clean up stray files from previous runs
REM ============================================================

if exist "%PROJECT_ROOT%\OpenCode" (
    echo [CLEANUP] Removing stray file: %PROJECT_ROOT%\OpenCode
    del /f "%PROJECT_ROOT%\OpenCode" >nul 2>&1
)

REM ============================================================
REM 3. Download latest Stitch Skills
REM ============================================================

echo [2/6] Downloading latest Stitch Skills...

if exist "%TEMP_ROOT%" (
    rmdir /s /q "%TEMP_ROOT%" >nul 2>&1
)

mkdir "%TEMP_ROOT%" >nul 2>&1

git clone --depth 1 --branch "%BRANCH%" "%REPO%" "%SOURCE%"

if errorlevel 1 (
    echo.
    echo [ERROR] Failed to download repository.
    echo.
    pause
    exit /b 1
)

echo.
echo [OK] Repository downloaded.
echo.

REM ============================================================
REM 4. Run embedded PowerShell synchronizer
REM ============================================================

echo [3/6] Synchronizing Stitch Skills...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$env:BATCH_SCRIPT='%BATCH_SCRIPT%'; $batch=$env:BATCH_SCRIPT; $lines=Get-Content -LiteralPath $batch; $start=($lines | Select-String '^:__PS_SCRIPT_START__$').LineNumber; $end=($lines | Select-String '^:__PS_SCRIPT_END__$').LineNumber; if(-not $start -or -not $end){throw 'Embedded PowerShell script markers not found.'}; $code=($lines[($start)..($end-2)] -join [Environment]::NewLine); & ([scriptblock]::Create($code))"

if errorlevel 1 (
    echo.
    echo [ERROR] Stitch Skills synchronization failed.
    echo.
    echo Temporary files:
    echo %TEMP_ROOT%
    echo.
    pause
    exit /b 1
)

REM ============================================================
REM 5. Show result
REM ============================================================

echo.
echo [4/6] Current OpenCode Skills
echo.
echo ------------------------------------------------------------

if exist "%TARGET%" (
    dir /b /ad "%TARGET%"
)

echo ------------------------------------------------------------
echo.

REM ============================================================
REM 6. Cleanup
REM ============================================================

echo [5/6] Cleaning temporary files...

if exist "%TEMP_ROOT%" (
    rmdir /s /q "%TEMP_ROOT%" >nul 2>&1
)

echo [OK] Temporary files removed.
echo.

echo [6/6] Completed.
echo.
echo ============================================================
echo   Stitch Skills synchronization completed successfully
echo ============================================================
echo.
echo Project:
echo   %PROJECT_ROOT%
echo.
echo OpenCode Skills:
echo   %TARGET%
echo.
echo Manifest:
echo   %TARGET%\.stitch-sync-manifest.json
echo.

REM ============================================================
REM Final cleanup
REM ============================================================

if exist "%PROJECT_ROOT%\OpenCode" (
    echo [CLEANUP] Removing stray file: %PROJECT_ROOT%\OpenCode
    del /f "%PROJECT_ROOT%\OpenCode" >nul 2>&1
)

echo ============================================================
echo.

pause
exit /b 0


REM =================================================================
REM DO NOT PUT CMD CODE BELOW THIS LINE
REM =================================================================

:__PS_SCRIPT_START__

$ErrorActionPreference = "Stop"

$source = Join-Path $env:TEMP "stitch-skills-opencode\repo"
$projectRoot = Split-Path -Parent $env:BATCH_SCRIPT
$target = Join-Path $projectRoot ".opencode\skills"
$manifestPath = Join-Path $target ".stitch-sync-manifest.json"

Write-Host "[INFO] Source:"
Write-Host "       $source"
Write-Host ""

Write-Host "[INFO] Target:"
Write-Host "       $target"
Write-Host ""

# ------------------------------------------------------------
# Validate source
# ------------------------------------------------------------

if (-not (Test-Path -LiteralPath $source)) {
    throw "Source repository was not found: $source"
}

$pluginsPath = Join-Path $source "plugins"

if (-not (Test-Path -LiteralPath $pluginsPath)) {
    throw "plugins directory was not found: $pluginsPath"
}

# ------------------------------------------------------------
# Ensure target exists
# ------------------------------------------------------------

if (-not (Test-Path -LiteralPath $target)) {
    New-Item -ItemType Directory -Path $target -Force | Out-Null
}

# ------------------------------------------------------------
# Discover all Stitch skills
#
# Repository structure:
#
# plugins/
#   stitch-design/
#     skills/
#       code-to-design/
#       generate-design/
#       ...
#
#   stitch-build/
#     skills/
#       react-components/
#       ...
#
#   stitch-utilities/
#     skills/
#       design-md/
#       ...
# ------------------------------------------------------------

Write-Host "[INFO] Discovering Stitch Skills..."

$skillDirectories = Get-ChildItem `
    -LiteralPath $pluginsPath `
    -Directory `
    -Recurse |
    Where-Object {
        $_.Parent.Name -eq "skills" -and
        (Test-Path -LiteralPath (Join-Path $_.FullName "SKILL.md"))
    } |
    Sort-Object FullName

if ($skillDirectories.Count -eq 0) {
    throw "No Stitch Skills were found."
}

Write-Host "[OK] Found $($skillDirectories.Count) skills."
Write-Host ""

# ------------------------------------------------------------
# Convert directory / skill name to OpenCode-safe name
#
# Example:
#
# stitch::generate-design
#        ->
# stitch-generate-design
#
# react-vite-dashboard
#        ->
# react-vite-dashboard
# ------------------------------------------------------------

function Get-SafeSkillName {
    param(
        [string]$Name
    )

    $safe = $Name.ToLowerInvariant()

    $safe = $safe -replace "::", "-"
    $safe = $safe -replace "[^a-z0-9]+", "-"
    $safe = $safe -replace "^-+", ""
    $safe = $safe -replace "-+$", ""

    return $safe
}

# ------------------------------------------------------------
# Load existing manifest
# ------------------------------------------------------------

$oldManagedSkills = @()

if (Test-Path -LiteralPath $manifestPath) {

    try {

        $manifest = Get-Content `
            -LiteralPath $manifestPath `
            -Raw `
            -Encoding UTF8 |
            ConvertFrom-Json

        if ($manifest.skills) {
            $oldManagedSkills = @($manifest.skills)
        }

    }
    catch {

        Write-Host "[WARN] Existing manifest could not be read."
        Write-Host "[WARN] A new manifest will be generated."
        Write-Host ""

    }
}

# ------------------------------------------------------------
# Build current managed skill list
# ------------------------------------------------------------

$currentSkills = @()

foreach ($skillDir in $skillDirectories) {

    $originalName = $skillDir.Name
    $safeName = Get-SafeSkillName $originalName

    if ([string]::IsNullOrWhiteSpace($safeName)) {
        Write-Host "[WARN] Skipping invalid skill name: $originalName"
        continue
    }

    $currentSkills += [PSCustomObject]@{
        OriginalName = $originalName
        SafeName     = $safeName
        SourcePath   = $skillDir.FullName
    }
}

# ------------------------------------------------------------
# Remove managed skills that no longer exist upstream
#
# IMPORTANT:
# Only directories recorded in the previous manifest are removed.
# Custom skills are preserved.
# ------------------------------------------------------------

$currentSafeNames = @(
    $currentSkills | ForEach-Object { $_.SafeName }
)

foreach ($oldSkill in $oldManagedSkills) {

    if ($oldSkill -and
        ($currentSafeNames -notcontains [string]$oldSkill)) {

        $oldPath = Join-Path $target ([string]$oldSkill)

        if (Test-Path -LiteralPath $oldPath) {

            Write-Host "[REMOVE] $oldSkill"

            Remove-Item `
                -LiteralPath $oldPath `
                -Recurse `
                -Force
        }
    }
}

# ------------------------------------------------------------
# Update each Stitch Skill
# ------------------------------------------------------------

Write-Host ""
Write-Host "[INFO] Installing / updating skills..."
Write-Host ""

foreach ($skill in $currentSkills) {

    $sourcePath = $skill.SourcePath
    $safeName = $skill.SafeName

    $destinationPath = Join-Path $target $safeName

    Write-Host "------------------------------------------------------------"
    Write-Host "[SYNC] $($skill.OriginalName)"
    Write-Host "       -> $safeName"
    Write-Host "------------------------------------------------------------"

    # --------------------------------------------------------
    # Remove previous managed copy
    # --------------------------------------------------------

    if (Test-Path -LiteralPath $destinationPath) {

        Write-Host "[INFO] Replacing existing managed skill..."

        Remove-Item `
            -LiteralPath $destinationPath `
            -Recurse `
            -Force
    }

    # --------------------------------------------------------
    # Copy complete skill directory
    # --------------------------------------------------------

    Copy-Item `
        -LiteralPath $sourcePath `
        -Destination $destinationPath `
        -Recurse `
        -Force

    # --------------------------------------------------------
    # Fix SKILL.md frontmatter
    # --------------------------------------------------------

    $skillFile = Join-Path $destinationPath "SKILL.md"

    if (-not (Test-Path -LiteralPath $skillFile)) {
        throw "SKILL.md missing after copying: $safeName"
    }

    $content = Get-Content `
        -LiteralPath $skillFile `
        -Raw `
        -Encoding UTF8

    # --------------------------------------------------------
    # Detect YAML frontmatter
    # --------------------------------------------------------

    if ($content -match "^(?s)---\s*\r?\n(.*?)\r?\n---\s*\r?\n(.*)$") {

        $frontmatter = $Matches[1]
        $body = $Matches[2]

        # Existing name field
        if ($frontmatter -match "(?m)^\s*name\s*:") {

            $frontmatter = $frontmatter -replace `
                "(?m)^\s*name\s*:.*$", `
                "name: $safeName"
        }
        else {

            $frontmatter = "name: $safeName`r`n$frontmatter"
        }

        $newContent = "---`r`n$frontmatter`r`n---`r`n$body"
    }
    else {

        # No frontmatter
        $newContent = "---`r`nname: $safeName`r`n---`r`n`r`n$content"
    }

    # --------------------------------------------------------
    # Save UTF-8 without BOM
    # --------------------------------------------------------

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    [System.IO.File]::WriteAllText(
        $skillFile,
        $newContent,
        $utf8NoBom
    )

    Write-Host "[OK] $safeName"
    Write-Host ""
}

# ------------------------------------------------------------
# Write manifest
# ------------------------------------------------------------

$managedNames = @(
    $currentSkills |
    ForEach-Object { $_.SafeName } |
    Sort-Object
)

$manifestObject = [ordered]@{
    source    = "https://github.com/google-labs-code/stitch-skills"
    branch    = "main"
    updatedAt = (Get-Date).ToUniversalTime().ToString("o")
    skills    = $managedNames
}

$manifestJson = $manifestObject |
    ConvertTo-Json -Depth 5

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

[System.IO.File]::WriteAllText(
    $manifestPath,
    $manifestJson,
    $utf8NoBom
)

# ------------------------------------------------------------
# Validate
# ------------------------------------------------------------

Write-Host ""
Write-Host "[INFO] Validating installed skills..."
Write-Host ""

$validationFailed = $false

foreach ($name in $managedNames) {

    $skillPath = Join-Path $target $name
    $skillFile = Join-Path $skillPath "SKILL.md"

    if (-not (Test-Path -LiteralPath $skillFile)) {

        Write-Host "[FAIL] $name"
        $validationFailed = $true

    }
    else {

        Write-Host "[PASS] $name"
    }
}

if ($validationFailed) {
    throw "One or more skills failed validation."
}

# ------------------------------------------------------------
# Show result
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================================"
Write-Host " Installed Stitch Skills"
Write-Host "============================================================"
Write-Host ""

foreach ($name in $managedNames) {
    Write-Host "  [OK] $name"
}

Write-Host ""
Write-Host "Manifest:"
Write-Host "  $manifestPath"
Write-Host ""

Write-Host "Target:"
Write-Host "  $target"
Write-Host ""

Write-Host "[SUCCESS] Stitch Skills synchronization completed."

:__PS_SCRIPT_END__
