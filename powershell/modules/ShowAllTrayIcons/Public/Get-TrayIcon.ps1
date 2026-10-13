function Get-TrayIcon {
    <#
    .SYNOPSIS
        Lists the notification-area (system tray) icons registered for the current user.

    .DESCRIPTION
        Enumerates HKCU\Control Panel\NotifyIconSettings -- the store Windows 10 1703+/11
        uses to remember per-icon taskbar visibility -- and returns one [TrayIconInfo] per
        registered icon: its id, owning executable, visibility (IsPromoted), last
        notification time, and whether an icon snapshot exists.

        Results can be filtered by wildcard name and by visibility, excluded from the
        promotion list, or emitted as JSON for automation.

    .PARAMETER Name
        Wildcard filter matched against DisplayName, Id, and ExecutablePath.

    .PARAMETER Promoted
        When set, returns only visible ($true) or only hidden ($false) icons.

    .PARAMETER ExcludeExecutable
        Executable names, full paths, or wildcards (e.g. 'onedrive.exe') that should be
        marked as excluded. Excluded icons are never auto-promoted by watchers.

    .PARAMETER AsJson
        Emits a JSON array instead of objects.

    .EXAMPLE
        Get-TrayIcon

    .EXAMPLE
        Get-TrayIcon -Promoted $false | Format-Table DisplayName, ExecutablePath, Id -AutoSize

    .EXAMPLE
        Get-TrayIcon -Name '*discord*' -AsJson

    .OUTPUTS
        TrayIconInfo
    .OUTPUTS
        System.String

    .LINK
        https://github.com/paulmann/windows-show-all-tray-icons/blob/main/docs/CLI-REFERENCE.md
    #>
    [CmdletBinding()]
    [OutputType('TrayIconInfo')]
    [OutputType([string])]
    param(
        [SupportsWildcards()]
        [string] $Name,

        [Nullable[bool]] $Promoted,

        [string[]] $ExcludeExecutable,

        [switch] $AsJson
    )

    script:Assert-WindowsPlatform | Out-Null

    $root = script:Open-TraySettingsRoot
    try {
        $icons = [System.Collections.Generic.List[TrayIconInfo]](
            script:Get-AllTrayIconEntries -Root $root -ExcludeExecutable $ExcludeExecutable)
    }
    finally {
        $root.Dispose()
    }

    if ($PSBoundParameters.ContainsKey('Name') -and $Name) {
        $icons = [System.Collections.Generic.List[TrayIconInfo]](
            $icons | Where-Object {
                $_.DisplayName -like $Name -or $_.Id -like $Name -or $_.ExecutablePath -like $Name
            })
    }
    if ($null -ne $Promoted) {
        $icons = [System.Collections.Generic.List[TrayIconInfo]](
            $icons | Where-Object { $_.IsPromoted -eq $Promoted })
    }

    $icons = [System.Collections.Generic.List[TrayIconInfo]]($icons | Sort-Object -Property DisplayName)

    if ($AsJson) {
        return ($icons | ConvertTo-Json -Depth 4 -AsArray)
    }
    $icons
}
