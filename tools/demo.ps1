<#
.SYNOPSIS
    Prints sample output to show off a Retro CRT profile (used for the README screenshots).

.PARAMETER Style
    Daily - font test, directory listing, warning and error. C64 - a Commodore 64 style boot screen.

.PARAMETER HoldSeconds
    Print a prompt, wait this many seconds and exit (lets a screenshot tool capture the window).
#>
param(
    [ValidateSet('Daily', 'C64')]
    [string]$Style = 'Daily',
    [int]$HoldSeconds = 0
)

if ($Style -eq 'C64') {
    Write-Host ''
    Write-Host '    **** COMMODORE 64 BASIC V2 ****'
    Write-Host ''
    Write-Host ' 64K RAM SYSTEM  38911 BASIC BYTES FREE'
    Write-Host ''
    Write-Host 'READY.'
    Write-Host 'LOAD "RETRO CRT",8,1'
    Write-Host ''
    Write-Host 'SEARCHING FOR RETRO CRT'
    Write-Host 'LOADING'
    Write-Host 'READY.'
    Write-Host 'RUN'
    Get-ChildItem C:\Windows -Directory | Select-Object -First 6 | Format-Table Mode, LastWriteTime, Name -AutoSize | Out-Host
} else {
    & (Join-Path $PSScriptRoot 'font-test.ps1')
    Write-Host ''
    Write-Host 'PS C:\> Get-ChildItem C:\Windows -Directory | Select-Object -First 6'
    Get-ChildItem C:\Windows -Directory | Select-Object -First 6 | Format-Table Mode, LastWriteTime, Name -AutoSize | Out-Host
    Write-Warning 'Disk C: is 87% full.'
    $Host.UI.WriteErrorLine("Get-Item : Cannot find path 'C:\does-not-exist' because it does not exist.")
}

if ($HoldSeconds -gt 0) {
    Write-Host ''
    Write-Host 'PS C:\> ' -NoNewline
    Start-Sleep -Seconds $HoldSeconds
    exit 0
}
