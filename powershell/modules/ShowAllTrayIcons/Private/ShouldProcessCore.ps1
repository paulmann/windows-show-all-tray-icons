# ---------------------------------------------------------------------------
# ShouldProcessCore.ps1 -- confirmation gate with a machine-readable mode.
#
# WHY THIS EXISTS (audit R3-1, measured on Windows 11 + reproduced on Linux):
#   $PSCmdlet.ShouldProcess() prints the "What if:" announcement to the HOST.
#   In a redirected child process (pwsh -File wrapper 1>out) that text lands on
#   STDOUT (stream 1), corrupting documented machine-readable output
#   ("-AsJson emits JSON on stdout"). Neither -InformationAction
#   SilentlyContinue nor 6>$null suppresses it -- measured, not assumed.
#
#   Therefore, when the caller requested machine-readable output (-AsJson) and
#   -WhatIf is in effect, we DO NOT call ShouldProcess. We announce on the
#   information stream (capturable via 6> / -InformationVariable; never the
#   success stream, so pipelines and redirected stdout stay pure) and return
#   $false. Safety is fully preserved: the guarded action does not run.
# ---------------------------------------------------------------------------

function script:Invoke-ShouldProcess {
    <#
    .SYNOPSIS
        Internal ShouldProcess gate; keeps stdout pure in machine-readable mode.
    .OUTPUTS
        System.Boolean -- $true when the guarded action should execute.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The calling advanced function's $PSCmdlet.
        [Parameter(Mandatory)] $Cmdlet,

        [Parameter(Mandatory)][string] $Target,

        [Parameter(Mandatory)][string] $Action,

        # Caller was invoked with -AsJson: host text is forbidden.
        [switch] $MachineReadable
    )

    if ($MachineReadable -and $WhatIfPreference) {
        Write-Information ("What if: [machine-readable mode] Would perform the operation '{0}' on target '{1}'." -f $Action, $Target)
        return $false
    }

    [bool] $Cmdlet.ShouldProcess($Target, $Action)
}
