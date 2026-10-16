# Learning Workspace gadget installer.
# Usage (PowerShell):  irm https://raw.githubusercontent.com/oyuke/learning-workspace-gadget/main/install.ps1 | iex
# Downloads the latest release, verifies its SHA512 against latest.yml, then runs the installer.
# Downloading from PowerShell does not mark the file as "from the internet", so no browser or SmartScreen warning appears.
# Messages are ASCII on purpose: piping through iex can garble non-ASCII text on Windows PowerShell 5.1.
param([switch]$DownloadOnly)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repo = 'oyuke/learning-workspace-gadget'
Write-Host 'Checking the latest release...'
$release = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -Headers @{ 'User-Agent' = 'lw-installer' }
$exe = $release.assets | Where-Object { $_.name -like 'Learning-Workspace-Setup-*.exe' } | Select-Object -First 1
$yml = $release.assets | Where-Object { $_.name -eq 'latest.yml' } | Select-Object -First 1
if (-not $exe -or -not $yml) { throw 'The release is missing the installer or latest.yml.' }

$dir = Join-Path $env:TEMP ('lw-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dir | Out-Null
try {
    $file = Join-Path $dir $exe.name
    Write-Host "Downloading $($exe.name) ($([math]::Round($exe.size / 1MB)) MB)..."
    Invoke-WebRequest $exe.browser_download_url -OutFile $file -UseBasicParsing

    $ymlFile = Join-Path $dir 'latest.yml'
    Invoke-WebRequest $yml.browser_download_url -OutFile $ymlFile -UseBasicParsing
    $expected = [regex]::Match([IO.File]::ReadAllText($ymlFile), '(?m)^sha512:\s*(\S+)').Groups[1].Value
    $sha = [Security.Cryptography.SHA512]::Create()
    $actual = [Convert]::ToBase64String($sha.ComputeHash([IO.File]::ReadAllBytes($file)))
    if (-not $expected -or $expected -ne $actual) { throw 'Checksum mismatch. The download is corrupt or has been tampered with. Nothing was installed.' }
    Write-Host 'Checksum OK.'

    if ($DownloadOnly) { Write-Host 'DownloadOnly: skipped running the installer.'; return }
    Unblock-File $file
    Write-Host 'Starting the installer...'
    Start-Process -FilePath $file -Wait
    Write-Host 'Done.'
}
finally {
    Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
}
