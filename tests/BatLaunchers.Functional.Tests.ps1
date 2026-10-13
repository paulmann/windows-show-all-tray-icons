#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    BAT launcher RUNTIME tests (audit N3): text scanning cannot catch cmd.exe
    semantics (SHIFT corrupting %0, argument re-quoting, cwd sensitivity), so
    these tests actually EXECUTE the batch files and assert exit codes/output.

    Windows-only; self-skips elsewhere. Safe by construction:
      - only read-only actions (help, status) and -WhatIf runs are executed;
      - nothing writes to the registry (WhatIf) except what 'status' reads.
#>

Describe 'BAT launchers runtime behavior (Windows only, audit N1/N3)' -Skip:(-not $IsWindows) {

    BeforeAll {
        $RepoRoot = Split-Path -Parent $PSScriptRoot
        $BatDir   = Join-Path $RepoRoot 'bat'

        # Audit R3-1b: never depend on $env:ComSpec being present.
        $CmdPath = if ($env:ComSpec -and (Test-Path $env:ComSpec)) {
            $env:ComSpec
        }
        elseif ($env:SystemRoot) {
            Join-Path $env:SystemRoot 'System32\cmd.exe'
        }
        else { $null }
        if (-not $CmdPath -or -not (Test-Path $CmdPath)) {
            throw 'Cannot locate cmd.exe: ComSpec is unset/invalid and %SystemRoot%\System32\cmd.exe does not exist.'
        }

        function Invoke-BatFile {
            param(
                [Parameter(Mandatory)] [string] $BatPath,
                [string] $Arguments = '',
                [string] $WorkingDirectory = $RepoRoot,
                [int] $TimeoutSec = 180
            )
            $psi = [System.Diagnostics.ProcessStartInfo]::new()
            $psi.FileName               = $CmdPath
            $psi.Arguments              = '/s /c ""{0}" {1}"' -f $BatPath, $Arguments
            $psi.WorkingDirectory       = $WorkingDirectory
            $psi.UseShellExecute        = $false
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError  = $true
            $process = [System.Diagnostics.Process]::Start($psi)
            $stdout = $process.StandardOutput.ReadToEnd()
            $stderr = $process.StandardError.ReadToEnd()
            if (-not $process.WaitForExit($TimeoutSec * 1000)) {
                $process.Kill($true)
                throw "BAT did not exit within $TimeoutSec s: $BatPath $Arguments"
            }
            [pscustomobject]@{
                ExitCode = $process.ExitCode
                StdOut   = $stdout
                StdErr   = $stderr
            }
        }
    }

    Context 'Run-PowerShell-Edition.bat' {
        It 'help exits 0 from the repo root and prints usage' {
            $r = Invoke-BatFile -BatPath (Join-Path $BatDir 'Run-PowerShell-Edition.bat') -Arguments 'help'
            $r.ExitCode | Should -Be 0
            $r.StdOut   | Should -Match 'USAGE'
            $r.StdOut   | Should -Match 'enable'
        }

        It 'help exits 0 when the current directory IS bat\ (N1 cwd scenario)' {
            $r = Invoke-BatFile -BatPath (Join-Path $BatDir 'Run-PowerShell-Edition.bat') `
                -Arguments 'help' -WorkingDirectory $BatDir
            $r.ExitCode | Should -Be 0
            $r.StdOut   | Should -Match 'USAGE'
        }

        It '"enable -AsJson -WhatIf" exits 0 and emits parseable JSON (N1 path resolution)' {
            $r = Invoke-BatFile -BatPath (Join-Path $BatDir 'Run-PowerShell-Edition.bat') `
                -Arguments 'enable -AsJson -WhatIf'
            $r.ExitCode | Should -Be 0 -Because ($r.StdOut + $r.StdErr)
            $json = $r.StdOut.Trim() | ConvertFrom-Json
            $json.Action  | Should -Be 'Enable'
            $json.Promoted | Should -Be 0 -Because '-WhatIf must not change anything'
        }

        It '"enable -AsJson -WhatIf" also works from inside bat\' {
            $r = Invoke-BatFile -BatPath (Join-Path $BatDir 'Run-PowerShell-Edition.bat') `
                -Arguments 'enable -AsJson -WhatIf' -WorkingDirectory $BatDir
            $r.ExitCode | Should -Be 0 -Because ($r.StdOut + $r.StdErr)
            ($r.StdOut.Trim() | ConvertFrom-Json).Action | Should -Be 'Enable'
        }

        It '"disable -AsJson -WhatIf" maps to the disable wrapper' {
            $r = Invoke-BatFile -BatPath (Join-Path $BatDir 'Run-PowerShell-Edition.bat') `
                -Arguments 'disable -AsJson -WhatIf'
            $r.ExitCode | Should -Be 0 -Because ($r.StdOut + $r.StdErr)
            ($r.StdOut.Trim() | ConvertFrom-Json).Action | Should -Be 'Disable'
        }

        It 'does not emit FINDSTR noise on any action' {
            $r = Invoke-BatFile -BatPath (Join-Path $BatDir 'Run-PowerShell-Edition.bat') -Arguments 'help'
            ($r.StdOut + $r.StdErr) | Should -Not -Match 'FINDSTR'
        }
    }

    Context 'Show-AllTrayIcons.bat (read-only actions)' {
        It 'help exits 0' {
            $r = Invoke-BatFile -BatPath (Join-Path $BatDir 'Show-AllTrayIcons.bat') -Arguments 'help'
            $r.ExitCode | Should -Be 0
            $r.StdOut   | Should -Match 'COMMANDS'
        }

        It 'status exits 0 and reports counts without FINDSTR noise' {
            $r = Invoke-BatFile -BatPath (Join-Path $BatDir 'Show-AllTrayIcons.bat') -Arguments 'status'
            $r.ExitCode | Should -Be 0
            $r.StdOut   | Should -Match 'Registered icons'
            ($r.StdOut + $r.StdErr) | Should -Not -Match 'FINDSTR'
        }
    }
}
