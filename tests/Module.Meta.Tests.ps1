#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Meta-tests: run on ANY OS (Linux CI included). They validate structure,
    syntax, help, analyzer cleanliness, BAT hygiene and app-project sanity
    without touching the Windows registry.
#>

# Discovery-phase variables MUST use $script: scope: plain names can leak in
# from the invoking session (e.g. build.ps1) because discovery code runs there.
BeforeDiscovery {
    $script:RepoRoot   = Split-Path -Parent $PSScriptRoot
    $script:ModulePath = Join-Path $script:RepoRoot 'powershell/modules/ShowAllTrayIcons'
}

BeforeAll {
    $RepoRoot   = Split-Path -Parent $PSScriptRoot
    $ModulePath = Join-Path $RepoRoot 'powershell/modules/ShowAllTrayIcons'
    $Manifest   = Import-PowerShellDataFile (Join-Path $ModulePath 'ShowAllTrayIcons.psd1')
}

Describe 'Module manifest' {
    It 'declares version 7.0.3' {
        $Manifest.ModuleVersion | Should -Be '7.0.3'
    }

    It 'requires PowerShell 7.6+ and Core edition only' {
        $Manifest.PowerShellVersion    | Should -Be '7.6'
        $Manifest.CompatiblePSEditions | Should -Be @('Core')
    }

    It 'has a stable GUID' {
        $Manifest.GUID | Should -Be '52f95744-327f-4889-9151-2ada389e7bed'
    }

    It 'exports exactly the Public/*.ps1 functions' {
        $public = Get-ChildItem (Join-Path $ModulePath 'Public') -Filter '*.ps1' -File |
            Select-Object -ExpandProperty BaseName | Sort-Object
        ($Manifest.FunctionsToExport | Sort-Object) | Should -Be $public
    }

    It 'exports 12 commands including the core surface' {
        $Manifest.FunctionsToExport.Count | Should -Be 12
        $Manifest.FunctionsToExport | Should -Contain 'Enable-AllTrayIcons'
        $Manifest.FunctionsToExport | Should -Contain 'Start-TrayIconWatcher'
        $Manifest.FunctionsToExport | Should -Contain 'Get-TrayIconState'
    }

    It 'exports no variables, aliases or cmdlets' {
        $Manifest.VariablesToExport | Should -BeNullOrEmpty
        $Manifest.AliasesToExport   | Should -BeNullOrEmpty
        $Manifest.CmdletsToExport   | Should -BeNullOrEmpty
    }

    It 'does not use the invalid CompatibleOSPlatform manifest member' {
        $Manifest.ContainsKey('CompatibleOSPlatform') | Should -BeFalse
    }
}

Describe 'PowerShell syntax' {
    $psFiles = Get-ChildItem (Join-Path $script:RepoRoot 'powershell') -Recurse -Include '*.ps1', '*.psm1' -File
    $psFiles += Get-Item (Join-Path $script:RepoRoot 'build.ps1')

    It 'parses without errors: <Name>' -TestCases ($psFiles | ForEach-Object {
            @{ Name = $_.Name; FullName = $_.FullName }
        }) {
        $tokens = $null; $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($FullName, [ref] $tokens, [ref] $errors) | Out-Null
        $errors | Should -BeNullOrEmpty -Because ('file must parse: ' + ($errors | ForEach-Object Message))
    }
}

Describe 'Comment-based help' {
    $publicFiles = Get-ChildItem (Join-Path $script:ModulePath 'Public') -Filter '*.ps1' -File

    It '<Name> documents SYNOPSIS and at least one EXAMPLE' -TestCases ($publicFiles | ForEach-Object {
            @{ Name = $_.Name; FullName = $_.FullName }
        }) {
        $tokens = $null; $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($FullName, [ref] $tokens, [ref] $errors)
        $function = $ast.FindAll(
            { $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -eq $Name.Split('.')[0] }, $true) |
            Select-Object -First 1
        $function | Should -Not -BeNullOrEmpty
        $help = $function.GetHelpContent()
        $help.Synopsis | Should -Not -BeNullOrEmpty
        $help.Examples.Count | Should -BeGreaterThan 0
    }
}

Describe 'Static analysis' {
    It 'PSScriptAnalyzer reports zero Error/Warning findings' `
        -Skip:(-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
        Import-Module PSScriptAnalyzer -Force
        $settings = Join-Path $RepoRoot 'PSScriptAnalyzerSettings.psd1'
        $params = @{ Path = (Join-Path $RepoRoot 'powershell'); Recurse = $true; Severity = @('Error', 'Warning') }
        if (Test-Path $settings) { $params.Settings = $settings }
        $findings = @(Invoke-ScriptAnalyzer @params)
        $findings | Should -BeNullOrEmpty -Because ($findings | ForEach-Object { "$($_.RuleName) @ $($_.ScriptName):$($_.Line)" })
    }
}

Describe 'BAT hygiene' {
    $batFiles = Get-ChildItem (Join-Path $script:RepoRoot 'bat') -Filter '*.bat' -File

    It '<Name> is ASCII-only, CRLF, and starts with @echo off' -TestCases ($batFiles | ForEach-Object {
            @{ Name = $_.Name; FullName = $_.FullName }
        }) {
        $bytes = [System.IO.File]::ReadAllBytes($FullName)
        @($bytes | Where-Object { $_ -gt 127 }) | Should -BeNullOrEmpty -Because 'BAT must be pure ASCII'
        $text = [System.Text.Encoding]::ASCII.GetString($bytes)
        $text | Should -Match '^@echo off'
        ($text -match "(?<!`r)`n") | Should -BeFalse -Because 'BAT requires CRLF line endings'
    }
}

Describe 'GUI project sanity' {
    BeforeAll {
        $CsprojPath  = Join-Path $RepoRoot 'app/src/TrayIconGuard/TrayIconGuard.csproj'
        [xml] $Csproj = Get-Content $CsprojPath -Raw
    }

    It 'targets net10.0-windows with WPF + WinForms' {
        $Csproj.Project.PropertyGroup.TargetFramework | Should -Contain 'net10.0-windows'
        ($Csproj.Project.PropertyGroup.UseWPF | Where-Object { $_ -eq 'true' })          | Should -Not -BeNullOrEmpty
        ($Csproj.Project.PropertyGroup.UseWindowsForms | Where-Object { $_ -eq 'true' })   | Should -Not -BeNullOrEmpty
    }

    It 'has ZERO NuGet dependencies (offline supply-chain safety)' {
        $refs = @($Csproj.SelectNodes('//PackageReference'))
        $refs | Should -HaveCount 0
    }

    It 'declares an application manifest and icon' {
        $Csproj.Project.PropertyGroup.ApplicationManifest | Should -Be 'app.manifest'
        $Csproj.Project.PropertyGroup.ApplicationIcon     | Should -Be 'Assets\app.ico'
    }

    It 'manifest requests asInvoker and PerMonitorV2 DPI' {
        $manifest = Get-Content (Join-Path $RepoRoot 'app/src/TrayIconGuard/app.manifest') -Raw
        $manifest | Should -Match 'requestedExecutionLevel level="asInvoker"'
        $manifest | Should -Match 'PerMonitorV2'
    }
}

Describe 'Entry scripts' {
    It 'all three wrappers require PowerShell 7.6' {
        foreach ($script in 'Enable-AllTrayIcons.ps1', 'Disable-AllTrayIcons.ps1', 'Watch-TrayIcons.ps1') {
            $content = Get-Content (Join-Path $RepoRoot "powershell/$script") -Raw
            $content | Should -Match '#Requires -Version 7\.6' -Because "$script must gate on PS 7.6"
        }
    }

    # Regression guard for audit defect P0-2: module-scoped classes/enums are NOT
    # resolvable from caller scripts; wrappers must never reference them as types.
    It '<Name> references no module-scoped types' -TestCases (
        @(Get-ChildItem (Join-Path $script:RepoRoot 'powershell') -Filter '*.ps1' -File) | ForEach-Object {
            @{ Name = $_.Name; FullName = $_.FullName }
        }) {
        $tokens = $null; $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($FullName, [ref] $tokens, [ref] $errors)
        $forbidden = @('TrayFixComponents', 'TrayIconInfo', 'TrayStatusReport', 'TrayPolicy')
        $typeRefs = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.TypeExpressionAst] }, $true) |
            ForEach-Object { $_.TypeName.FullName }
        ($typeRefs | Where-Object { $_ -in $forbidden }) | Should -BeNullOrEmpty
    }

    It '<Name> supports -WhatIf/-Confirm passthrough' -TestCases (
        @(Get-ChildItem (Join-Path $script:RepoRoot 'powershell') -Filter '*.ps1' -File) | ForEach-Object {
            @{ Name = $_.Name; FullName = $_.FullName }
        }) {
        $content = Get-Content $FullName -Raw
        $content | Should -Match 'SupportsShouldProcess'
        $content | Should -Match 'WhatIf'
    }
}

Describe 'Launcher statics (audit N1 regression)' {
    BeforeAll {
        $LauncherRaw = Get-Content (Join-Path $RepoRoot 'bat/Run-PowerShell-Edition.bat') -Raw
        # Only executable lines count: comments legitimately mention %~dp0/shift.
        $LauncherLines = @(Get-Content (Join-Path $RepoRoot 'bat/Run-PowerShell-Edition.bat') |
            Where-Object { $_ -notmatch '^\s*(::|[rR][eE][mM]\b)' })
    }

    It 'never calls shift (shift corrupts %~dp0 by moving %0)' {
        $shiftLines = @($LauncherLines | Where-Object { $_ -match '^\s*shift' })
        $shiftLines.Count | Should -Be 0
    }

    It 'captures SCRIPT_DIR=%~dp0 before anything else' {
        $captureIdx = -1; $firstDp0Idx = [int]::MaxValue
        for ($i = 0; $i -lt $LauncherLines.Count; $i++) {
            if ($LauncherLines[$i] -match [regex]::Escape('%~dp0')) { $firstDp0Idx = [Math]::Min($firstDp0Idx, $i) }
            if ($LauncherLines[$i] -match [regex]::Escape('set "SCRIPT_DIR=%~dp0"')) { $captureIdx = $i }
        }
        $captureIdx    | Should -BeGreaterOrEqual 0
        $firstDp0Idx   | Should -Be $captureIdx -Because 'the ONLY %~dp0 use must be the early capture'
    }

    It 'runs pwsh against the captured SCRIPT_DIR and offers help' {
        $LauncherRaw.Contains('%SCRIPT_DIR%..\powershell\%SCRIPT%') | Should -BeTrue
        $LauncherRaw.Contains(':HELP') | Should -BeTrue
    }
}

Describe 'Machine-readable WhatIf (audit R3-1 regression)' {
    BeforeAll {
        Import-Module (Join-Path $ModulePath 'ShowAllTrayIcons.psd1') -Force
    }

    It 'JSON mode routes the WhatIf announcement to the information stream, stdout stays pure' {
        $result = & (Get-Module ShowAllTrayIcons) {
            function script:R3Probe {
                [CmdletBinding(SupportsShouldProcess = $true)]
                param([switch] $Machine)
                script:Invoke-ShouldProcess -Cmdlet $PSCmdlet -Target 'T' -Action 'A' -MachineReadable:$Machine
            }
            $infoRecords = $null
            $executed = script:R3Probe -WhatIf -Machine -InformationVariable infoRecords
            [pscustomobject]@{
                Executed  = $executed
                InfoCount = @($infoRecords).Count
                InfoText  = (@($infoRecords) | ForEach-Object MessageData | Out-String)
            }
        }
        $result.Executed  | Should -BeFalse
        $result.InfoCount | Should -Be 1
        $result.InfoText  | Should -Match 'machine-readable mode'
    }

    It 'interactive mode still delegates to ShouldProcess (WhatIf stays safe, no info record)' {
        $result = & (Get-Module ShowAllTrayIcons) {
            function script:R3Probe2 {
                [CmdletBinding(SupportsShouldProcess = $true)]
                param([switch] $Machine)
                script:Invoke-ShouldProcess -Cmdlet $PSCmdlet -Target 'T' -Action 'A' -MachineReadable:$Machine
            }
            $infoRecords = $null
            $executed = script:R3Probe2 -WhatIf -InformationVariable infoRecords
            [pscustomobject]@{ Executed = $executed; InfoCount = @($infoRecords).Count }
        }
        $result.Executed  | Should -BeFalse
        $result.InfoCount | Should -Be 0
    }
}

Describe 'Native P/Invoke compilation (audit P0-1 regression)' {
    It 'compiles ShowAllTrayIcons.Native.RegistryNotify at import on ANY OS' {
        # Add-Type compilation is platform-independent; importing on Linux must
        # produce the type, exactly as on Windows (CS0105 guard).
        Import-Module (Join-Path $ModulePath 'ShowAllTrayIcons.psd1') -Force
        $type = 'ShowAllTrayIcons.Native.RegistryNotify' -as [type]
        $type | Should -Not -BeNullOrEmpty
        $type::REG_NOTIFY_CHANGE_NAME | Should -Be 1
        $type::REG_NOTIFY_CHANGE_LAST_SET | Should -Be 4
        $type::ERROR_KEY_DELETED | Should -Be 1018
    }
}

Describe 'BAT regression guards (audit P1-1 / P1-2)' {
    BeforeAll {
        $MainBat = Get-Content (Join-Path $RepoRoot 'bat/Show-AllTrayIcons.bat') -Raw
    }

    # NOTE: Pester 6 mis-parses bare method calls in Should's positional
    # argument (e.g. [regex]::Escape('x') binds as ExpectedValue='[regex]::Escape'
    # + Because='x'). Use literal .Contains() checks - identical on Pester 5/6.
    It 'detects /restart and -restart as literal strings' {
        $MainBat.Contains('findstr /i /c:"/restart"') | Should -BeTrue
        $MainBat.Contains('findstr /i /c:"-restart"') | Should -BeTrue
    }

    It 'enumerates only HKEY_-prefixed subkey lines in all three scan loops' {
        ([regex]::Matches($MainBat, [regex]::Escape('findstr /b "HKEY_"'))).Count | Should -Be 3
    }

    It 'never passes bare /restart patterns to findstr' {
        $MainBat.Contains('findstr /i "/restart"') | Should -BeFalse
        $MainBat.Contains('findstr /i "-restart"') | Should -BeFalse
    }
}
