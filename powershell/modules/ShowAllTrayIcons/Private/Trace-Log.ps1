# ---------------------------------------------------------------------------
# Trace-Log.ps1 -- file + stream logging for the whole module.
# Log file: %LOCALAPPDATA%\ShowAllTrayIcons\logs\ShowAllTrayIcons-yyyyMMdd.log
# Rotation: keeps the 14 most recent daily logs.
# ---------------------------------------------------------------------------

$script:TrayLogRoot = $null
$script:TrayLogFile = $null

function script:Get-LogRootDirectory {
    if (-not $script:TrayLogRoot) {
        $base = if ($IsWindows) { $env:LOCALAPPDATA } else { Join-Path $HOME '.local/state' }
        $script:TrayLogRoot = Join-Path $base ([TrayPolicy]::AppFolderName) ([TrayPolicy]::LogFolderName)
    }
    $script:TrayLogRoot
}

function script:Get-CurrentLogFile {
    if (-not $script:TrayLogFile) {
        $root = script:Get-LogRootDirectory
        if (-not (Test-Path -LiteralPath $root)) {
            New-Item -Path $root -ItemType Directory -Force | Out-Null
        }
        try {
            Get-ChildItem -LiteralPath $root -Filter '*.log' -File -ErrorAction SilentlyContinue |
                Sort-Object -Property LastWriteTime -Descending |
                Select-Object -Skip 14 |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }
        catch {
            # Rotation is best-effort; never fail logging because of it.
            Write-Debug "Log rotation ignored an error: $($_.Exception.Message)"
        }
        $script:TrayLogFile = Join-Path $root ('ShowAllTrayIcons-{0:yyyyMMdd}.log' -f (Get-Date))
    }
    $script:TrayLogFile
}

function script:Write-TraceLog {
    <#
    .SYNOPSIS
        Internal logger: appends to the daily log file and routes to a PS stream.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Message,

        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
        [string] $Level = 'INFO'
    )

    $line = '[{0:yyyy-MM-dd HH:mm:ss.fff}] [{1,-5}] [pid {2}] {3}' -f (Get-Date), $Level, $PID, $Message

    try {
        Add-Content -LiteralPath (script:Get-CurrentLogFile) -Value $line -Encoding utf8NoBOM -ErrorAction Stop
    }
    catch {
        # Logging must never break the product; stay silent.
        Write-Debug "File logging unavailable: $($_.Exception.Message)"
    }

    switch ($Level) {
        'WARN' { Write-Warning $Message }
        default { Write-Verbose $line }
    }
}
