# Shared helpers for reading and writing Windows Terminal settings.json.
# Dot-sourced by install.ps1 and uninstall.ps1; must stay compatible with Windows PowerShell 5.1.

$TerminalSettingsCandidates = @(
    (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
    (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
    (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
)

# Windows PowerShell's default profile; used as defaultProfile when we create settings.json,
# so Terminal does not pick the first Retro CRT profile as the default.
$WindowsPowerShellProfileGuid = '{61c54bbd-c2c6-5271-96e7-009a87ff44bf}'

function Get-ExistingTerminalSettingsPaths {
    return @($TerminalSettingsCandidates | Where-Object { Test-Path $_ })
}

# Where a not-yet-started Terminal will look for settings.json.
function Get-NewTerminalSettingsPath {
    try {
        if (Get-AppxPackage -Name 'Microsoft.WindowsTerminal' -ErrorAction Stop) { return $TerminalSettingsCandidates[0] }
        if (Get-AppxPackage -Name 'Microsoft.WindowsTerminalPreview' -ErrorAction Stop) { return $TerminalSettingsCandidates[1] }
    } catch { }
    return $TerminalSettingsCandidates[2]
}

# settings.json is JSON with comments; Windows PowerShell 5.1 cannot parse comments.
function Remove-JsonComments([string]$Text) {
    $Text = [regex]::Replace($Text, '/\*[\s\S]*?\*/', '')
    return [regex]::Replace($Text, '(?m)^\s*//.*$', '')
}

function Read-TerminalSettings([string]$Path) {
    $text = [IO.File]::ReadAllText($Path)
    if ([string]::IsNullOrWhiteSpace($text)) { return [pscustomobject]@{} }
    try {
        return (Remove-JsonComments $text) | ConvertFrom-Json
    } catch {
        throw "Cannot parse $Path ($($_.Exception.Message)). Fix the file or remove inline comments and try again."
    }
}

function Write-TerminalSettings([string]$Path, $Settings) {
    if (Test-Path $Path) {
        $backup = "$Path.retrocrt-$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"
        Copy-Item $Path $backup -Force
    }
    New-Item -ItemType Directory -Path (Split-Path $Path) -Force | Out-Null
    $json = $Settings | ConvertTo-Json -Depth 64
    $null = $json | ConvertFrom-Json
    [IO.File]::WriteAllText($Path, $json, (New-Object Text.UTF8Encoding $false))
    return $backup
}

function Set-JsonProperty($Object, [string]$Name, $Value) {
    if ($Object.PSObject.Properties[$Name]) {
        $Object.$Name = $Value
    } else {
        $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
    }
}

# Returns the profile list object, normalizing the legacy format where "profiles" is an array.
function Get-ProfileContainer($Settings) {
    $profiles = $Settings.PSObject.Properties['profiles']
    if (-not $profiles) {
        Set-JsonProperty $Settings 'profiles' ([pscustomobject]@{ list = @() })
    } elseif ($profiles.Value -is [array]) {
        Set-JsonProperty $Settings 'profiles' ([pscustomobject]@{ list = @($profiles.Value) })
    }
    if (-not $Settings.profiles.PSObject.Properties['list']) {
        Set-JsonProperty $Settings.profiles 'list' @()
    }
    return $Settings.profiles
}

# Removes Retro CRT profiles (by GUID, or left over from the fragment-based layout) and color schemes.
function Remove-RetroCrtEntries($Settings, [string[]]$ProfileGuids, [string[]]$SchemeNames) {
    $container = Get-ProfileContainer $Settings
    $container.list = @($container.list | Where-Object {
            $guid = if ($_.PSObject.Properties['guid']) { $_.guid } else { '' }
            $source = if ($_.PSObject.Properties['source']) { $_.source } else { '' }
            ($ProfileGuids -notcontains $guid) -and ($source -ne 'RetroCRT')
        })
    if ($Settings.PSObject.Properties['schemes']) {
        $Settings.schemes = @($Settings.schemes | Where-Object { $SchemeNames -notcontains $_.name })
    }
}
