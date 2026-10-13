function Restart-Explorer {
    <#
    .SYNOPSIS
        Safely restarts the Windows shell (explorer.exe).

    .DESCRIPTION
        Stops every explorer.exe process, waits for the shell to auto-restart, and starts
        it manually if Windows did not bring it back within the timeout. The taskbar
        disappears for 1-3 seconds. Use after tray changes that Explorer has not picked
        up live.

    .PARAMETER TimeoutSec
        Seconds to wait for the shell to come back before starting it manually (2-30).

    .PARAMETER Force
        Skip the confirmation prompt.

    .EXAMPLE
        Restart-Explorer -Force

    .OUTPUTS
        System.Management.Automation.PSCustomObject

    .LINK
        https://github.com/paulmann/windows-show-all-tray-icons/blob/main/docs/CLI-REFERENCE.md
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [ValidateRange(2, 30)]
        [int] $TimeoutSec = 8,

        [switch] $Force
    )

    if ($Force) { $ConfirmPreference = 'None' }
    script:Assert-WindowsPlatform | Out-Null

    if ($PSCmdlet.ShouldProcess('explorer.exe', "Restart the Windows shell (taskbar flashes for ~$TimeoutSec s max)")) {
        script:Restart-ExplorerCore -TimeoutSec $TimeoutSec
    }
}
