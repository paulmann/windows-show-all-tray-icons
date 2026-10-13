# ---------------------------------------------------------------------------
# Trace-Log.ps1 -- file + stream logging for the whole module.
# Log file: %LOCALAPPDATA%\ShowAllTrayIcons\logs\ShowAllTrayIcons-yyyyMMdd.log
# Rotation: keeps the 14 most recent daily logs.
#
# NOTE (audit R4-1): file I/O here uses .NET APIs, NOT Add-Content/New-Item/
# Remove-Item. Those cmdlets implement SupportsShouldProcess, so under -WhatIf
# they print "What if: Performing the operation "Add Content" ..." to the HOST,
# which in a redirected child process lands on STDOUT and corrupts the
# documented machine-readable output of ... -AsJson -WhatIf. Logging is
# infrastructure, not a user-visible action: it must never be announced and
# never suppressed.
# ---------------------------------------------------------------------------

$script:TrayLogRoot = $null
$script:TrayLogFile = $null

function script:Get-LogRootDirectory {
    if (-not $script:TrayLogRoot) {
        $base = if ($IsWindows) { $env:LOCALAPPDATA } else { Join-Path ([Environment]::GetFolderPath('UserProfile')) '.local/state' }
        $script:TrayLogRoot = [System.IO.Path]::Combine($base, [TrayPolicy]::AppFolderName, [TrayPolicy]::LogFolderName)
    }
    $script:TrayLogRoot
}

function script:Get-CurrentLogFile {
    if (-not $script:TrayLogFile) {
        $root = script:Get-LogRootDirectory
        try {
            if (-not [System.IO.Directory]::Exists($root)) {
                $null = [System.IO.Directory]::CreateDirectory($root)
            }
            # Rotation is best-effort; never fail logging because of it.
            Get-ChildItem -LiteralPath $root -Filter '*.log' -File -ErrorAction SilentlyContinue |
                Sort-Object -Property LastWriteTime -Descending |
                Select-Object -Skip 14 |
                ForEach-Object { try { [System.IO.File]::Delete($_.FullName) } catch { Write-Debug "Log rotation skipped '$($_.Name)': $($_.Exception.Message)" } }
        }
        catch {
            Write-Debug "Log rotation ignored an error: $($_.Exception.Message)"
        }
        $script:TrayLogFile = [System.IO.Path]::Combine($root, ('ShowAllTrayIcons-{0:yyyyMMdd}.log' -f (Get-Date)))
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
        $file = script:Get-CurrentLogFile
        $dir = [System.IO.Path]::GetDirectoryName($file)
        if ($dir -and -not [System.IO.Directory]::Exists($dir)) {
            $null = [System.IO.Directory]::CreateDirectory($dir)
        }
        # .NET append: immune to $WhatIfPreference, so stdout stays pure.
        [System.IO.File]::AppendAllText($file, $line + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
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
