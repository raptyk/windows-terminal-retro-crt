<#
.SYNOPSIS
    Removes the "Retro CRT" profiles from Windows Terminal.

.DESCRIPTION
    Removes the Retro CRT profiles (matched by GUID) and color schemes from every
    Windows Terminal settings.json found (backed up first) and deletes
    %LOCALAPPDATA%\Microsoft\Windows Terminal\RetroCRT (shaders). Fonts stay installed unless -RemoveFonts is given, because other
    applications may use them. Windows Terminal itself and PowerShell 7 are never removed.

.PARAMETER RemoveFonts
    Also remove the fonts installed by install.ps1 for the current user.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\uninstall.ps1 -RemoveFonts
#>
[CmdletBinding()]
param(
    [switch]$RemoveFonts
)

$ErrorActionPreference = 'Stop'

$AppName = 'RetroCRT'
$RepoRoot = $PSScriptRoot
$DataDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\$AppName"
$UserFontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$FontRegistryKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'

# Font files installed by install.ps1 (user font folder file names).
$FontFiles = @(
    'PxPlus_IBM_VGA_9x16.ttf',
    'PxPlus_IBM_VGA_8x14.ttf',
    'PxPlus_IBM_VGA_9x14.ttf',
    'PxPlus_IBM_EGA_8x14.ttf',
    'C64_Pro_Mono-STYLE.ttf',
    'TerminusTTFWindows-4.49.3.ttf',
    'TerminusTTFWindows-Bold-4.49.3.ttf',
    'TerminusTTFWindows-Italic-4.49.3.ttf',
    'TerminusTTFWindows-Bold-Italic-4.49.3.ttf',
    'IBMPlexMono-Regular.ttf',
    'IBMPlexMono-Bold.ttf',
    'IBMPlexMono-Italic.ttf',
    'IBMPlexMono-BoldItalic.ttf'
)

. (Join-Path $RepoRoot 'lib\TerminalSettings.ps1')

$definition = [IO.File]::ReadAllText((Join-Path $RepoRoot 'terminal\retro-crt.json')) | ConvertFrom-Json
$profileGuids = @($definition.profiles | ForEach-Object { $_.guid })
$schemeNames = @($definition.schemes | ForEach-Object { $_.name })

$paths = Get-ExistingTerminalSettingsPaths
if ($paths.Count -eq 0) {
    Write-Host 'Windows Terminal settings.json not found.'
}
foreach ($path in $paths) {
    $settings = Read-TerminalSettings $path
    $container = Get-ProfileContainer $settings
    $before = @($container.list).Count + @($settings.schemes).Count
    Remove-RetroCrtEntries $settings $profileGuids $schemeNames
    $after = @($container.list).Count + @($settings.schemes).Count
    if ($before -eq $after) {
        Write-Host "No Retro CRT profiles in $path"
        continue
    }
    $backup = Write-TerminalSettings $path $settings
    Write-Host "Removed Retro CRT profiles and color schemes from $path"
    Write-Host "Backup: $backup"
}

if (Test-Path $DataDir) {
    Remove-Item $DataDir -Recurse -Force
    Write-Host "Removed $DataDir"
}

if ($RemoveFonts) {
    if (-not ('RetroCrt.FontRemoval' -as [type])) {
        Add-Type -Namespace RetroCrt -Name FontRemoval -MemberDefinition @'
[DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
public static extern bool RemoveFontResource(string fileName);
'@
    }
    $registry = Get-ItemProperty -Path $FontRegistryKey
    foreach ($file in $FontFiles) {
        $path = Join-Path $UserFontDir $file
        $registry.PSObject.Properties |
            Where-Object { $_.Value -is [string] -and $_.Value -ieq $path } |
            ForEach-Object { Remove-ItemProperty -Path $FontRegistryKey -Name $_.Name }
        if (Test-Path $path) {
            [void][RetroCrt.FontRemoval]::RemoveFontResource($path)
            try {
                Remove-Item $path -Force
                Write-Host "Removed font $file"
            } catch {
                Write-Host "Font $file is in use; it will be removed after you sign out and run this again." -ForegroundColor Yellow
            }
        }
    }
}

Write-Host 'Restart Windows Terminal to apply the changes.'
