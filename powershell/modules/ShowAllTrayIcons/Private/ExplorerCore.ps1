# ---------------------------------------------------------------------------
# ExplorerCore.ps1 -- safe Explorer restart shared by all public commands.
# Strategy: kill every explorer.exe (the shell normally auto-restarts within
# ~2 s), wait, and start explorer.exe manually if the shell did not come back.
# ---------------------------------------------------------------------------

function script:Restart-ExplorerCore {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [ValidateRange(2, 30)]
        [int] $TimeoutSec = 8
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $killed = 0

    foreach ($process in @(Get-Process -Name 'explorer' -ErrorAction SilentlyContinue)) {
        try {
            $process.Kill()
            $killed++
        }
        catch {
            script:Write-TraceLog "Could not stop explorer PID $($process.Id): $($_.Exception.Message)" 'WARN'
        }
    }

    if ($killed -eq 0) {
        script:Write-TraceLog 'No explorer.exe process was running; starting the shell.' 'WARN'
    }

    # Wait for the shell to come back on its own.
    $deadline = [System.TimeSpan]::FromSeconds($TimeoutSec)
    $shellBack = $false
    while ($stopwatch.Elapsed -lt $deadline) {
        Start-Sleep -Milliseconds 250
        if (Get-Process -Name 'explorer' -ErrorAction SilentlyContinue) {
            $shellBack = $true
            break
        }
    }

    $hadToStartManually = $false
    if (-not $shellBack) {
        $hadToStartManually = $true
        try {
            Start-Process -FilePath 'explorer.exe' -ErrorAction Stop
        }
        catch {
            script:Write-TraceLog "Could not start explorer.exe: $($_.Exception.Message)" 'ERROR'
        }
        $startDeadline = $stopwatch.Elapsed.Add([System.TimeSpan]::FromSeconds(5))
        while ($stopwatch.Elapsed -lt $startDeadline) {
            Start-Sleep -Milliseconds 250
            if (Get-Process -Name 'explorer' -ErrorAction SilentlyContinue) {
                $shellBack = $true
                break
            }
        }
    }

    $stopwatch.Stop()
    $result = [pscustomobject]@{
        Success            = [bool] $shellBack
        KilledProcesses    = $killed
        HadToStartManually = $hadToStartManually
        DurationMs         = $stopwatch.ElapsedMilliseconds
    }
    $message = 'Explorer restart finished: success={0} killed={1} manualStart={2} in {3} ms' -f $result.Success, $result.KilledProcesses, $result.HadToStartManually, $result.DurationMs
    script:Write-TraceLog $message
    $result
}
