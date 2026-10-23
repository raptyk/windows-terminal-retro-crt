<#
.SYNOPSIS
    Installs the "Retro CRT" profiles for Windows Terminal.

.DESCRIPTION
    Sets up everything the four Retro CRT profiles need, for the current user only
    (no administrator rights required, except when winget installs PowerShell 7):

      * Windows Terminal and PowerShell 7, when missing (winget, or a portable
        GitHub release when winget is not available),
      * fonts: C64 Pro Mono, PxPlus IBM VGA/EGA, Terminus (TTF), IBM Plex Mono,
      * CRT pixel shaders (in %LOCALAPPDATA%\Microsoft\Windows Terminal\RetroCRT),
      * the profiles and color schemes in Windows Terminal's settings.json.

    settings.json is backed up next to itself before every change. Only the Retro CRT
    profiles (matched by GUID) and color schemes are replaced; other settings stay as they are.
    The script is idempotent: running it again updates an existing installation.

.PARAMETER SkipDependencies
    Do not install Windows Terminal or PowerShell 7 when they are missing.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1
#>
[CmdletBinding()]
param(
    [switch]$SkipDependencies
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$AppName = 'RetroCRT'
$RepoRoot = $PSScriptRoot
# The Store version of Terminal (MSIX) does not see new folders directly in %LOCALAPPDATA%,
# but it does see its own "Microsoft\Windows Terminal" folder (also used for JSON fragments).
$DataDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\$AppName"
$UserFontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$UserProgramsDir = Join-Path $env:LOCALAPPDATA 'Programs'
$FontRegistryKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'

# Downloaded font packages are pinned to a version and verified by SHA256.
$FontPackages = @(
    @{
        Name   = 'C64 Pro Mono (Style64)'
        Url    = 'https://style64.org/file/C64_TrueType_v1.2.1-STYLE.zip'
        Sha256 = 'B630FF545DF6FED324BD9B6DC7336B7B93E8777668F45CBB3679561F9960EF2D'
        Files  = @('fonts\C64_Pro_Mono-STYLE.ttf')
    },
    @{
        Name   = 'Terminus (TTF) 4.49.3'
        Url    = 'https://files.ax86.net/terminus-ttf/files/4.49.3/terminus-ttf-4.49.3-windows.zip'
        Sha256 = '84E673237E90FDD8BB26950C2D87FD005700A5CD71672C803BD6E4977FDD557A'
        Files  = @(
            'TerminusTTFWindows-4.49.3.ttf',
            'TerminusTTFWindows-Bold-4.49.3.ttf',
            'TerminusTTFWindows-Italic-4.49.3.ttf',
            'TerminusTTFWindows-Bold-Italic-4.49.3.ttf'
        )
    },
    @{
        Name   = 'IBM Plex Mono 2.5.0'
        Url    = 'https://github.com/IBM/plex/releases/download/%40ibm/plex-mono%402.5.0/ibm-plex-mono.zip'
        Sha256 = '6D23F01257663D8CC49A0D64C22CED630B79E0E2A0AC08A0DA86E9A38BBC481C'
        Files  = @(
            'complete\ttf\IBMPlexMono-Regular.ttf',
            'complete\ttf\IBMPlexMono-Bold.ttf',
            'complete\ttf\IBMPlexMono-Italic.ttf',
            'complete\ttf\IBMPlexMono-BoldItalic.ttf'
        )
    }
)

function Write-Step([string]$Message) {
    Write-Host ''
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Info([string]$Message) {
    Write-Host "    $Message"
}

function Write-Warn([string]$Message) {
    Write-Host "    WARNING: $Message" -ForegroundColor Yellow
}

function New-TempDirectory {
    $path = Join-Path ([IO.Path]::GetTempPath()) ("$AppName-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function Save-Download([string]$Url, [string]$Destination) {
    Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -UserAgent "$AppName-installer"
}

function Get-LatestGitHubAsset([string]$Repository, [string]$AssetPattern) {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases/latest" -UseBasicParsing -Headers @{ 'User-Agent' = "$AppName-installer" }
    $asset = $release.assets | Where-Object { $_.name -match $AssetPattern } | Select-Object -First 1
    if (-not $asset) {
        throw "No asset matching '$AssetPattern' in the latest $Repository release ($($release.tag_name))."
    }
    return $asset
}

function Test-Command([string]$Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# ---------------------------------------------------------------- dependencies

function Find-WindowsTerminal {
    try {
        if (Get-AppxPackage -Name 'Microsoft.WindowsTerminal*' -ErrorAction Stop) { return $true }
    } catch { }
    if (Test-Command 'wt.exe') { return $true }
    return Test-Path (Join-Path $UserProgramsDir 'WindowsTerminal\wt.exe')
}

function New-StartMenuShortcut([string]$Name, [string]$Target) {
    $shortcutPath = Join-Path ([Environment]::GetFolderPath('Programs')) "$Name.lnk"
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $Target
    $shortcut.WorkingDirectory = $env:USERPROFILE
    $shortcut.Save()
}

function Install-PortableWindowsTerminal {
    $asset = Get-LatestGitHubAsset 'microsoft/terminal' '^Microsoft\.WindowsTerminal_[\d\.]+_x64\.zip$'
    $temp = New-TempDirectory
    try {
        $zip = Join-Path $temp $asset.name
        Write-Info "Downloading $($asset.name)"
        Save-Download $asset.browser_download_url $zip
        Expand-Archive -Path $zip -DestinationPath (Join-Path $temp 'x') -Force
        $wt = Get-ChildItem (Join-Path $temp 'x') -Recurse -Filter 'WindowsTerminal.exe' | Select-Object -First 1
        $target = Join-Path $UserProgramsDir 'WindowsTerminal'
        if (Test-Path $target) { Remove-Item $target -Recurse -Force }
        New-Item -ItemType Directory -Path $UserProgramsDir -Force | Out-Null
        Move-Item $wt.Directory.FullName $target
        New-StartMenuShortcut 'Windows Terminal' (Join-Path $target 'WindowsTerminal.exe')
        Write-Info "Installed to $target (Start menu: Windows Terminal)"
    } finally {
        Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Install-WindowsTerminal {
    if (Find-WindowsTerminal) {
        Write-Info 'Windows Terminal is installed.'
        return
    }
    if ($SkipDependencies) {
        Write-Warn 'Windows Terminal is missing (skipped because of -SkipDependencies).'
        return
    }
    if (Test-Command 'winget.exe') {
        Write-Info 'Installing Windows Terminal with winget...'
        & winget install --id Microsoft.WindowsTerminal --exact --source winget --silent --accept-package-agreements --accept-source-agreements
        if (Find-WindowsTerminal) { return }
        Write-Warn 'winget did not install Windows Terminal, trying the portable release.'
    }
    Install-PortableWindowsTerminal
}

function Find-Pwsh {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'),
        (Join-Path $UserProgramsDir 'PowerShell\pwsh.exe')
    )
    $command = Get-Command 'pwsh.exe' -ErrorAction SilentlyContinue
    if ($command) { $candidates = @($command.Source) + $candidates }
    foreach ($path in $candidates) {
        if ($path -and (Test-Path $path)) { return $path }
    }
    return $null
}

function Install-PortablePwsh {
    $asset = Get-LatestGitHubAsset 'PowerShell/PowerShell' '^PowerShell-[\d\.]+-win-x64\.zip$'
    $temp = New-TempDirectory
    try {
        $zip = Join-Path $temp $asset.name
        Write-Info "Downloading $($asset.name)"
        Save-Download $asset.browser_download_url $zip
        $target = Join-Path $UserProgramsDir 'PowerShell'
        if (Test-Path $target) { Remove-Item $target -Recurse -Force }
        Expand-Archive -Path $zip -DestinationPath $target -Force
        Write-Info "Installed to $target"
    } finally {
        Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Install-Pwsh {
    $pwsh = Find-Pwsh
    if ($pwsh) {
        Write-Info "PowerShell 7 is installed: $pwsh"
        return $pwsh
    }
    if ($SkipDependencies) {
        Write-Warn 'PowerShell 7 is missing (skipped because of -SkipDependencies).'
        return $null
    }
    if (Test-Command 'winget.exe') {
        Write-Info 'Installing PowerShell 7 with winget (Windows may ask for administrator approval)...'
        & winget install --id Microsoft.PowerShell --exact --source winget --silent --accept-package-agreements --accept-source-agreements
        $pwsh = Find-Pwsh
        if ($pwsh) { return $pwsh }
        Write-Warn 'winget did not install PowerShell 7, trying the portable release.'
    }
    try {
        Install-PortablePwsh
    } catch {
        Write-Warn "Portable PowerShell 7 install failed: $($_.Exception.Message)"
    }
    return Find-Pwsh
}

# ----------------------------------------------------------------------- fonts

if (-not ('RetroCrt.FontNative' -as [type])) {
    Add-Type -Namespace RetroCrt -Name FontNative -MemberDefinition @'
[DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
public static extern int AddFontResource(string fileName);
[DllImport("user32.dll", SetLastError = true)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam, uint flags, uint timeout, out IntPtr result);
'@
}

function Read-UInt16BE([byte[]]$Bytes, [int]$Offset) {
    return [int]$Bytes[$Offset] * 256 + [int]$Bytes[$Offset + 1]
}

function Read-UInt32BE([byte[]]$Bytes, [int]$Offset) {
    return [int64](Read-UInt16BE $Bytes $Offset) * 65536 + (Read-UInt16BE $Bytes ($Offset + 2))
}

# Full font name (name ID 4) from the TrueType 'name' table; this is what the
# Fonts registry key uses, e.g. "IBM Plex Mono Bold".
function Get-FontFullName([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    $tableCount = Read-UInt16BE $bytes 4
    $nameTable = -1
    for ($i = 0; $i -lt $tableCount; $i++) {
        $record = 12 + 16 * $i
        if ([Text.Encoding]::ASCII.GetString($bytes, $record, 4) -eq 'name') {
            $nameTable = [int](Read-UInt32BE $bytes ($record + 8))
        }
    }
    if ($nameTable -lt 0) { throw "No 'name' table in $Path" }

    $count = Read-UInt16BE $bytes ($nameTable + 2)
    $storage = $nameTable + (Read-UInt16BE $bytes ($nameTable + 4))
    $fallback = $null
    for ($i = 0; $i -lt $count; $i++) {
        $record = $nameTable + 6 + 12 * $i
        $platformId = Read-UInt16BE $bytes $record
        $languageId = Read-UInt16BE $bytes ($record + 4)
        $nameId = Read-UInt16BE $bytes ($record + 6)
        if ($platformId -ne 3 -or $nameId -ne 4) { continue }
        $length = Read-UInt16BE $bytes ($record + 8)
        $offset = Read-UInt16BE $bytes ($record + 10)
        $value = [Text.Encoding]::BigEndianUnicode.GetString($bytes, $storage + $offset, $length)
        if ($languageId -eq 0x409) { return $value }
        if (-not $fallback) { $fallback = $value }
    }
    if ($fallback) { return $fallback }
    return [IO.Path]::GetFileNameWithoutExtension($Path)
}

function Install-UserFont([string]$SourcePath) {
    New-Item -ItemType Directory -Path $UserFontDir -Force | Out-Null
    $fileName = Split-Path $SourcePath -Leaf
    $target = Join-Path $UserFontDir $fileName
    $fullName = Get-FontFullName $SourcePath

    $sourceHash = (Get-FileHash $SourcePath -Algorithm SHA256).Hash
    $isCurrent = (Test-Path $target) -and ((Get-FileHash $target -Algorithm SHA256).Hash -eq $sourceHash)
    if (-not $isCurrent) {
        try {
            Copy-Item $SourcePath $target -Force
        } catch {
            Write-Warn "Could not replace $fileName (font in use?). Close Windows Terminal and run the installer again."
            return
        }
    }
    New-ItemProperty -Path $FontRegistryKey -Name "$fullName (TrueType)" -Value $target -PropertyType String -Force | Out-Null
    [void][RetroCrt.FontNative]::AddFontResource($target)
    $state = if ($isCurrent) { 'up to date' } else { 'installed' }
    Write-Info ("{0,-34} {1}" -f $fullName, $state)
}

function Install-FontPackage([hashtable]$Package) {
    $temp = New-TempDirectory
    try {
        $zip = Join-Path $temp 'package.zip'
        Write-Info "Downloading $($Package.Name)"
        Save-Download $Package.Url $zip
        $hash = (Get-FileHash $zip -Algorithm SHA256).Hash
        if ($hash -ne $Package.Sha256) {
            throw "Checksum mismatch for $($Package.Url): expected $($Package.Sha256), got $hash."
        }
        $extracted = Join-Path $temp 'x'
        Expand-Archive -Path $zip -DestinationPath $extracted -Force
        $all = Get-ChildItem $extracted -Recurse -File
        foreach ($relative in $Package.Files) {
            $file = $all | Where-Object { $_.FullName.EndsWith('\' + $relative, [StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
            if (-not $file) { throw "File '$relative' not found in $($Package.Url)." }
            Install-UserFont $file.FullName
        }
    } finally {
        Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Install-Fonts {
    Get-ChildItem (Join-Path $RepoRoot 'fonts\int10h') -Filter '*.ttf' | ForEach-Object { Install-UserFont $_.FullName }
    foreach ($package in $FontPackages) {
        Install-FontPackage $package
    }
    $result = [IntPtr]::Zero
    $HWND_BROADCAST = [IntPtr]0xffff
    $WM_FONTCHANGE = 0x001D
    [void][RetroCrt.FontNative]::SendMessageTimeout($HWND_BROADCAST, $WM_FONTCHANGE, [IntPtr]::Zero, [IntPtr]::Zero, 2, 1000, [ref]$result)
}

# -------------------------------------------------------------------- terminal

function ConvertTo-JsonStringContent([string]$Value) {
    return $Value.Replace('\', '\\').Replace('"', '\"')
}

. (Join-Path $RepoRoot 'lib\TerminalSettings.ps1')

function Get-RetroCrtDefinition([string]$PwshPath, [string]$ShaderDir) {
    if ($PwshPath) {
        $commandline = "`"$PwshPath`" -NoLogo"
    } else {
        Write-Warn 'Retro CRT - C64 will use Windows PowerShell because PowerShell 7 is not available.'
        $commandline = '%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoLogo'
    }
    $template = [IO.File]::ReadAllText((Join-Path $RepoRoot 'terminal\retro-crt.json'))
    $json = $template.Replace('__SHADER_DIR__', (ConvertTo-JsonStringContent $ShaderDir)).Replace('__PWSH_COMMANDLINE__', (ConvertTo-JsonStringContent $commandline))
    return $json | ConvertFrom-Json
}

function Install-Profiles([string]$PwshPath) {
    $shaderDir = Join-Path $DataDir 'shaders'
    New-Item -ItemType Directory -Path $shaderDir -Force | Out-Null
    Copy-Item (Join-Path $RepoRoot 'shaders\*.hlsl') $shaderDir -Force
    Write-Info "Shaders: $shaderDir"

    $definition = Get-RetroCrtDefinition $PwshPath $shaderDir
    $profileGuids = @($definition.profiles | ForEach-Object { $_.guid })
    $schemeNames = @($definition.schemes | ForEach-Object { $_.name })

    $paths = Get-ExistingTerminalSettingsPaths
    $isNew = $paths.Count -eq 0
    if ($isNew) { $paths = @(Get-NewTerminalSettingsPath) }

    foreach ($path in $paths) {
        if ($isNew) {
            $settings = [pscustomobject]@{ defaultProfile = $WindowsPowerShellProfileGuid }
        } else {
            $settings = Read-TerminalSettings $path
        }
        Remove-RetroCrtEntries $settings $profileGuids $schemeNames
        $container = Get-ProfileContainer $settings
        $container.list = @($container.list) + @($definition.profiles)
        if ($settings.PSObject.Properties['schemes']) {
            $settings.schemes = @($settings.schemes) + @($definition.schemes)
        } else {
            Set-JsonProperty $settings 'schemes' @($definition.schemes)
        }
        $backup = Write-TerminalSettings $path $settings
        Write-Info "Updated: $path"
        if ($backup) { Write-Info "Backup:  $backup" }
    }
}

# ------------------------------------------------------------------------ main

Write-Host 'Retro CRT profiles for Windows Terminal' -ForegroundColor Green

Write-Step 'Windows Terminal'
Install-WindowsTerminal

Write-Step 'PowerShell 7'
$pwsh = Install-Pwsh

Write-Step 'Fonts (current user)'
Install-Fonts

Write-Step 'Profiles, color schemes and shaders'
Install-Profiles $pwsh

Write-Host ''
Write-Host 'Done.' -ForegroundColor Green
Write-Host 'Close ALL Windows Terminal windows and start it again, so it loads the new fonts.'
Write-Host 'New profiles: Retro CRT - C64, VGA, Terminus, Plex (in the new tab dropdown).'
Write-Host "Font test:    powershell -ExecutionPolicy Bypass -File `"$(Join-Path $RepoRoot 'tools\font-test.ps1')`""
