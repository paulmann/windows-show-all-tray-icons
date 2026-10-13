#!/usr/bin/env pwsh
#Requires -Version 7.6
<#
.SYNOPSIS
    One-shot build orchestrator for windows-show-all-tray-icons v7 "Phoenix".

.DESCRIPTION
    Runs quality gates and produces distributables:

      Clean      Remove artifacts, bin, obj
      Analyze    PSScriptAnalyzer (PowerShell) + BAT hygiene (ASCII/CRLF)
      Test       Pester 5 suite (Windows-only functional tests self-skip elsewhere)
      BuildExe   dotnet build app/TrayIconGuard.sln
      PublishExe dotnet publish single-file EXE into artifacts/publish/<rid>
      Package    Portable ZIP bundle (EXE + BAT + PowerShell + docs) into artifacts/
      Verify     Import module, count exports, parse every script
      All        Analyze -> Test -> BuildExe -> PublishExe -> Package

    Works on Windows (full pipeline) and on Linux/macOS CI (Analyze/Test/Verify
    and, with EnableWindowsTargeting, BuildExe/PublishExe as well).

.PARAMETER Task
    Task to run (default: All).

.PARAMETER Configuration
    Debug or Release (default: Release).

.PARAMETER Runtime
    Target RID for publish: win-x64 (default) or win-arm64.

.PARAMETER SelfContained
    Publish a self-contained EXE. This is the DEFAULT since v7.0.3 (audit R3-2):
    a self-contained EXE is immune to ambient DOTNET_ROOT and to a missing
    Desktop Runtime. The switch is kept for explicitness/backward compatibility.

.PARAMETER FrameworkDependent
    Opt out of the self-contained default: publish a smaller EXE that requires
    the .NET 10 Desktop Runtime on the target machine.

.PARAMETER SkipTests
    With -Task All: skip the Pester stage.

.EXAMPLE
    ./build.ps1
.EXAMPLE
    ./build.ps1 -Task PublishExe -SelfContained
.EXAMPLE
    ./build.ps1 -Task All -Configuration Debug

.NOTES
    Part of windows-show-all-tray-icons v7.0.3 (MIT). See docs/BUILD-AND-RELEASE.md.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('All', 'Clean', 'Analyze', 'Test', 'BuildExe', 'PublishExe', 'Package', 'Verify')]
    [string] $Task = 'All',

    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Release',

    [ValidateSet('win-x64', 'win-arm64')]
    [string] $Runtime = 'win-x64',

    [switch] $SelfContained,

    [switch] $FrameworkDependent,

    [switch] $SkipTests
)

$ErrorActionPreference = 'Stop'

$RepoRoot     = $PSScriptRoot
$Version      = '7.0.3'
$ArtifactsDir = Join-Path $RepoRoot 'artifacts'
$PublishDir   = Join-Path $ArtifactsDir "publish/$Runtime"
$SolutionPath = Join-Path $RepoRoot 'app/TrayIconGuard.sln'
$ProjectPath  = Join-Path $RepoRoot 'app/src/TrayIconGuard/TrayIconGuard.csproj'

function Write-Step {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Build orchestrator; colored console output is intended UX.')]
    param([Parameter(Mandatory)][string] $Message)
    Write-Host "`n==== $Message ====" -ForegroundColor Cyan
}

function Write-Ok   { param([string] $m) Write-Host "  [OK] $m" -ForegroundColor Green }
function Write-Info { param([string] $m) Write-Host "  [..] $m" -ForegroundColor Gray }

function Assert-ExitCode {
    param([int] $Code, [string] $What)
    if ($Code -ne 0) { throw "$What failed with exit code $Code." }
}

function Invoke-CleanTask {
    Write-Step 'CLEAN'
    if (Test-Path $ArtifactsDir) { Remove-Item $ArtifactsDir -Recurse -Force }
    Get-ChildItem -Path (Join-Path $RepoRoot 'app') -Directory -Recurse -Include 'bin', 'obj' -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Ok 'Removed artifacts/bin/obj.'
}

function Invoke-AnalyzeTask {
    Write-Step 'ANALYZE (PSScriptAnalyzer + BAT hygiene)'
    if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
        Write-Info 'Installing PSScriptAnalyzer (CurrentUser)...'
        Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -AllowClobber
    }
    Import-Module PSScriptAnalyzer -Force

    $settingsFile = Join-Path $RepoRoot 'PSScriptAnalyzerSettings.psd1'
    $analyzerParams = @{
        Path      = (Join-Path $RepoRoot 'powershell')
        Recurse   = $true
        Severity  = @('Error', 'Warning')
    }
    if (Test-Path $settingsFile) { $analyzerParams.Settings = $settingsFile }

    $findings = @(Invoke-ScriptAnalyzer @analyzerParams)
    if ($findings.Count -gt 0) {
        $findings | Format-Table -Property Severity, RuleName, ScriptName, Line -AutoSize | Out-String | Write-Host
        throw "PSScriptAnalyzer found $($findings.Count) issue(s)."
    }
    Write-Ok 'PowerShell: 0 analyzer findings.'

    # BAT hygiene: ASCII-only, CRLF line endings, @echo off header.
    $batFailures = 0
    Get-ChildItem -Path (Join-Path $RepoRoot 'bat') -Filter '*.bat' -File | ForEach-Object {
        $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
        $nonAscii = @($bytes | Where-Object { $_ -gt 127 })
        $text = [System.Text.Encoding]::ASCII.GetString($bytes)
        $hasLfOnly = $text -match "(?<!`r)`n"
        if ($nonAscii.Count -gt 0 -or $hasLfOnly -or -not $text.StartsWith('@echo off')) {
            Write-Host "  [FAIL] $($_.Name): nonAscii=$($nonAscii.Count) lfOnly=$hasLfOnly" -ForegroundColor Red
            $batFailures++
        }
        else {
            Write-Ok "$($_.Name): ASCII, CRLF, header OK"
        }
    }
    if ($batFailures -gt 0) { throw "$batFailures BAT file(s) failed hygiene checks." }
}

function Invoke-TestTask {
    Write-Step 'TEST (Pester 5)'
    if (-not (Get-Module -ListAvailable -Name Pester | Where-Object Version -ge '5.0.0')) {
        Write-Info 'Installing Pester (CurrentUser)...'
        Install-Module -Name Pester -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck
    }
    Import-Module Pester -MinimumVersion 5.0.0 -Force

    $config = New-PesterConfiguration
    $config.Run.Path = (Join-Path $RepoRoot 'tests')
    $config.Run.Throw = $true
    $config.Output.Verbosity = 'Detailed'
    Invoke-Pester -Configuration $config
}

function Invoke-BuildExeTask {
    Write-Step "BUILD EXE ($Configuration)"
    dotnet build $SolutionPath -c $Configuration -p:EnableWindowsTargeting=true --nologo
    Assert-ExitCode $LASTEXITCODE 'dotnet build'
    Write-Ok 'TrayIconGuard built.'
}

function Invoke-PublishExeTask {
    # R3-2: self-contained is the default so neither DOTNET_ROOT nor a missing
    # Desktop Runtime can block the published EXE.
    $script:IsSelfContained = -not $FrameworkDependent
    Write-Step "PUBLISH EXE ($Runtime, selfContained=$($script:IsSelfContained))"
    if (-not (Test-Path $PublishDir)) { New-Item -Path $PublishDir -ItemType Directory -Force | Out-Null }

    $publishArgs = @(
        'publish', $ProjectPath
        '-c', $Configuration
        '-r', $Runtime
        "--self-contained:$($script:IsSelfContained)"
        '-p:PublishSingleFile=true'
        '-p:IncludeNativeLibrariesForSelfExtract=true'
        '-p:EnableWindowsTargeting=true'
        '-p:DebugType=none'
        '-p:DebugSymbols=false'
        '-o', $PublishDir
        '--nologo'
    )
    dotnet @publishArgs
    Assert-ExitCode $LASTEXITCODE 'dotnet publish'

    $exe = Join-Path $PublishDir 'TrayIconGuard.exe'
    if (Test-Path $exe) {
        $sizeMb = [math]::Round((Get-Item $exe).Length / 1MB, 1)
        Write-Ok "TrayIconGuard.exe published ($sizeMb MB) -> $PublishDir"
    }
    else {
        Write-Ok "Publish output at $PublishDir (EXE materializes on Windows targets)."
    }
}

function Invoke-PackageTask {
    Write-Step "PACKAGE (portable ZIP, $Runtime)"
    $stageName = "ShowAllTrayIcons-$Version-$Runtime$(if ($FrameworkDependent) { '-framework' })"
    $stage = Join-Path $ArtifactsDir "package/$stageName"
    if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
    New-Item -Path $stage -ItemType Directory -Force | Out-Null

    # GUI exe (if published)
    if (Test-Path $PublishDir) {
        New-Item -Path (Join-Path $stage 'gui') -ItemType Directory -Force | Out-Null
        Copy-Item -Path (Join-Path $PublishDir '*') -Destination (Join-Path $stage 'gui') -Recurse -Force
    }
    # Script editions + docs
    Copy-Item -Path (Join-Path $RepoRoot 'bat')       -Destination $stage -Recurse -Force
    Copy-Item -Path (Join-Path $RepoRoot 'powershell') -Destination $stage -Recurse -Force
    Copy-Item -Path (Join-Path $RepoRoot 'docs')      -Destination $stage -Recurse -Force
    Copy-Item -Path (Join-Path $RepoRoot 'installer') -Destination $stage -Recurse -Force -ErrorAction SilentlyContinue
    foreach ($file in 'README.md', 'LICENSE', 'CHANGELOG.md') {
        Copy-Item -Path (Join-Path $RepoRoot $file) -Destination $stage -Force -ErrorAction SilentlyContinue
    }

    $zipPath = Join-Path $ArtifactsDir "$stageName.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zipPath -CompressionLevel Optimal
    $zipMb = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
    Write-Ok "Package created: $zipPath ($zipMb MB)"
}

function Invoke-VerifyTask {
    Write-Step 'VERIFY (module import + exports + full parse)'
    $parseFailures = 0
    Get-ChildItem -Path (Join-Path $RepoRoot 'powershell') -Recurse -Include '*.ps1', '*.psm1' -File | ForEach-Object {
        $tokens = $null; $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref] $tokens, [ref] $errors) | Out-Null
        if ($errors.Count -gt 0) {
            $parseFailures++
            Write-Host "  [FAIL] $($_.Name): $($errors.Count) parse error(s)" -ForegroundColor Red
            $errors | ForEach-Object { Write-Host "         L$($_.Extent.StartLineNumber): $($_.Message)" }
        }
    }
    if ($parseFailures -gt 0) { throw "$parseFailures file(s) failed to parse." }
    Write-Ok 'All PowerShell files parse cleanly.'

    $manifestFile = Join-Path $RepoRoot 'powershell/modules/ShowAllTrayIcons/ShowAllTrayIcons.psd1'
    Import-Module $manifestFile -Force
    $commands = @(Get-Command -Module ShowAllTrayIcons)
    if ($commands.Count -ne 12) {
        throw "Expected 12 exported commands, found $($commands.Count): $($commands.Name -join ', ')"
    }
    Write-Ok "Module imports; $($commands.Count) commands exported."

    $publicDir = Join-Path $RepoRoot 'powershell/modules/ShowAllTrayIcons/Public'
    foreach ($file in (Get-ChildItem -Path $publicDir -Filter '*.ps1' -File)) {
        $tokens = $null; $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref] $tokens, [ref] $errors)
        $functionAst = $ast.FindAll(
            { $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -eq $file.BaseName }, $true) |
            Select-Object -First 1
        $help = $functionAst.GetHelpContent()
        if (-not $help.Synopsis -or $help.Examples.Count -eq 0) {
            throw "Missing help (synopsis/example) for $($file.BaseName)."
        }
    }
    Write-Ok 'Every exported command has help.'
}

# ---- Dispatch ----------------------------------------------------------------
$started = Get-Date
Write-Host "build.ps1 - task '$Task' - configuration '$Configuration' - runtime '$Runtime'" -ForegroundColor Magenta

switch ($Task) {
    'Clean'      { Invoke-CleanTask }
    'Analyze'    { Invoke-AnalyzeTask }
    'Test'       { Invoke-TestTask }
    'BuildExe'   { Invoke-BuildExeTask }
    'PublishExe' { Invoke-PublishExeTask }
    'Package'    { Invoke-PackageTask }
    'Verify'     { Invoke-VerifyTask }
    'All' {
        Invoke-AnalyzeTask
        if (-not $SkipTests) { Invoke-TestTask }
        Invoke-VerifyTask
        Invoke-BuildExeTask
        Invoke-PublishExeTask
        Invoke-PackageTask
    }
}

$elapsed = (Get-Date) - $started
Write-Host ("`nDONE: '{0}' finished in {1:n1}s" -f $Task, $elapsed.TotalSeconds) -ForegroundColor Green
exit 0
