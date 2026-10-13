#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Functional tests against the REAL Windows tray registry.
    Self-skip on non-Windows so cross-platform CI stays green; GitHub Actions
    runs them on windows-latest.

    Strategy: create a synthetic icon subkey ({aaaaaaaa-...-eee1}) under
    HKCU\Control Panel\NotifyIconSettings, exercise the cmdlets on it, then
    remove it. No real application icons are touched beyond read-only scans.
#>

Describe 'Functional tray operations (Windows only)' -Skip:(-not $IsWindows) {

    BeforeAll {
        $RepoRoot   = Split-Path -Parent $PSScriptRoot
        $ModulePath = Join-Path $RepoRoot 'powershell/modules/ShowAllTrayIcons/ShowAllTrayIcons.psd1'
        Import-Module $ModulePath -Force

        # Snapshot the REAL icon state: several tests run Enable/Disable-AllTrayIcons
        # -Force, which touches every live icon. AfterAll restores it (audit note).
        $script:RealState = @{}
        $rootKeyPath = 'HKCU:\Control Panel\NotifyIconSettings'
        if (Test-Path $rootKeyPath) {
            foreach ($sub in (Get-ChildItem $rootKeyPath -ErrorAction SilentlyContinue)) {
                $props = Get-ItemProperty -Path $sub.PSPath -Name 'IsPromoted' -ErrorAction SilentlyContinue
                if ($null -ne $props) {
                    $script:RealState[$sub.PSChildName] = ([int] $props.IsPromoted) -ne 0
                }
            }
        }

        $script:TestId  = '{aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeee1}'
        $script:TestKey = "HKCU:\Control Panel\NotifyIconSettings\$TestId"
        $script:TestExe = 'C:\FakeApps\traytest-app.exe'

        function script:New-TestIcon([int] $Promoted) {
            if (-not (Test-Path $script:TestKey)) {
                New-Item -Path $script:TestKey -Force | Out-Null
            }
            New-ItemProperty -Path $script:TestKey -Name 'IsPromoted' -Value $Promoted -PropertyType DWord -Force | Out-Null
            New-ItemProperty -Path $script:TestKey -Name 'ExecutablePath' -Value $script:TestExe -PropertyType String -Force | Out-Null
        }
        function script:Remove-TestIcon {
            if (Test-Path $script:TestKey) { Remove-Item -Path $script:TestKey -Recurse -Force }
        }
        function script:Get-TestPromoted {
            (Get-ItemProperty -Path $script:TestKey -Name 'IsPromoted').IsPromoted
        }
    }

    AfterAll {
        script:Remove-TestIcon

        # Restore the real icons' promoted bits captured in BeforeAll.
        foreach ($id in @($script:RealState.Keys)) {
            $key = "HKCU:\Control Panel\NotifyIconSettings\$id"
            if (Test-Path $key) {
                Set-ItemProperty -Path $key -Name 'IsPromoted' -Value ([int] $script:RealState[$id]) -Type DWord -ErrorAction SilentlyContinue
            }
        }

        Remove-Module ShowAllTrayIcons -Force -ErrorAction SilentlyContinue
    }

    Context 'Discovery' {
        BeforeAll { script:New-TestIcon -Promoted 0 }
        AfterAll  { script:Remove-TestIcon }

        It 'Get-TrayIcon finds the synthetic icon as hidden' {
            $icon = Get-TrayIcon -Name 'traytest-app' | Select-Object -First 1
            $icon           | Should -Not -BeNullOrEmpty
            $icon.Id        | Should -Be $script:TestId
            $icon.IsPromoted | Should -BeFalse
        }

        It 'Get-TrayIcon -Promoted $true excludes it' {
            Get-TrayIcon -Promoted $true -Name 'traytest-app' | Should -BeNullOrEmpty
        }

        It 'Get-TrayIconState reports a supported platform and counts' {
            $state = Get-TrayIconState
            $state.PlatformSupported | Should -BeTrue
            $state.TotalIcons        | Should -BeGreaterOrEqual 1
            $state.WindowsBuild      | Should -BeGreaterOrEqual 15063
        }
    }

    Context 'Per-icon control' {
        BeforeAll { script:New-TestIcon -Promoted 0 }
        AfterAll  { script:Remove-TestIcon }

        It 'Set-TrayIcon -Id promotes it in the registry' {
            Set-TrayIcon -Id $script:TestId -Promoted $true -Confirm:$false | Out-Null
            script:Get-TestPromoted | Should -Be 1
        }

        It 'Set-TrayIcon -ExecutablePath wildcard demotes it' {
            Set-TrayIcon -ExecutablePath 'traytest-app*' -Promoted $false -Confirm:$false | Out-Null
            script:Get-TestPromoted | Should -Be 0
        }
    }

    Context 'Enable / Disable / WhatIf / exclusions' {
        BeforeAll { script:New-TestIcon -Promoted 0 }
        AfterAll  { script:Remove-TestIcon }

        It 'Enable-AllTrayIcons -WhatIf changes nothing' {
            Enable-AllTrayIcons -WhatIf | Out-Null
            script:Get-TestPromoted | Should -Be 0
        }

        It 'Enable-AllTrayIcons -Force promotes it and reports a summary' {
            $summary = Enable-AllTrayIcons -Force
            script:Get-TestPromoted | Should -Be 1
            $summary.Promoted   | Should -BeGreaterOrEqual 1
            $summary.TotalIcons | Should -BeGreaterOrEqual 1
        }

        It 'exclusions are honored' {
            Set-TrayIcon -Id $script:TestId -Promoted $false -Confirm:$false | Out-Null
            $summary = Enable-AllTrayIcons -Force -ExcludeExecutable 'traytest-app.exe'
            script:Get-TestPromoted | Should -Be 0
            $summary.Excluded | Should -BeGreaterOrEqual 1
        }

        It 'Disable-AllTrayIcons -Force returns it to hidden' {
            Set-TrayIcon -Id $script:TestId -Promoted $true -Confirm:$false | Out-Null
            Disable-AllTrayIcons -Force | Out-Null
            script:Get-TestPromoted | Should -Be 0
        }
    }

    Context 'Backup / Restore' {
        BeforeAll { script:New-TestIcon -Promoted 1 }
        AfterAll  { script:Remove-TestIcon }

        It 'backs up to JSON, restores, and round-trips IsPromoted' {
            $backup = Backup-TrayIconState -Path (Join-Path ([System.IO.Path]::GetTempPath()) "traytest-$([guid]::NewGuid()).json")
            $backup | Should -Not -BeNullOrEmpty
            $data = Get-Content $backup.FullName -Raw | ConvertFrom-Json -AsHashtable
            $data.schemaVersion | Should -Be 7
            ($data.icons | Where-Object { $_.id -eq $script:TestId }) | Should -Not -BeNullOrEmpty

            # Flip state, then restore.
            Set-TrayIcon -Id $script:TestId -Promoted $false -Confirm:$false | Out-Null
            script:Get-TestPromoted | Should -Be 0

            Restore-TrayIconState -Path $backup.FullName -Confirm:$false | Out-Null
            script:Get-TestPromoted | Should -Be 1

            Remove-Item $backup.FullName -Force
        }
    }

    Context 'Watcher' {
        BeforeAll { script:New-TestIcon -Promoted 0 }
        AfterAll  { script:Remove-TestIcon }

        It 'auto-promotes a hidden icon within its timeout (polling mode)' {
            Start-TrayIconWatcher -UsePolling -IntervalSec 1 -TimeoutSec 5 | Out-Null
            script:Get-TestPromoted | Should -Be 1
        }
    }

    Context 'Autostart management' {
        It 'installs and removes the Run value idempotently' {
            $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
            Install-TrayIconAutostart -Target Watcher -Confirm:$false | Out-Null
            (Get-ItemProperty -Path $runKey -Name 'TrayIconGuard' -ErrorAction SilentlyContinue).TrayIconGuard |
                Should -Match '-EncodedCommand'

            Install-TrayIconAutostart -Target Watcher -Confirm:$false | Out-Null   # idempotent

            $removed = Uninstall-TrayIconAutostart -Confirm:$false
            $removed.Removed | Should -BeTrue
            (Get-ItemProperty -Path $runKey -Name 'TrayIconGuard' -ErrorAction SilentlyContinue) | Should -BeNullOrEmpty
        }
    }

    Context 'Platform guard' {
        It 'commands expose ShouldProcess where they mutate state' {
            (Get-Command Enable-AllTrayIcons).Parameters.ContainsKey('WhatIf')  | Should -BeTrue
            (Get-Command Disable-AllTrayIcons).Parameters.ContainsKey('WhatIf') | Should -BeTrue
            (Get-Command Start-TrayIconWatcher).Parameters.ContainsKey('WhatIf') | Should -BeTrue
            (Get-Command Restart-Explorer).Parameters.ContainsKey('WhatIf')     | Should -BeTrue
        }
    }
}
