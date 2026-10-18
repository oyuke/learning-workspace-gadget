# Learning Workspace secure bootstrap installer.
# Publish this file at an immutable raw Git commit URL, then keep the one-line UX:
#   irm https://raw.githubusercontent.com/oyuke/learning-workspace-gadget/<commit>/install.ps1 | iex
# Messages are ASCII because Windows PowerShell 5.1 can garble non-ASCII text piped to iex.
param([switch]$DownloadOnly)

Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repository = 'oyuke/learning-workspace-gadget'
$MinimumVersion = [version]'0.1.13'
$InstallerPrefix = 'Learning-Workspace-Setup-'
$StateFile = Join-Path $env:LOCALAPPDATA 'Fosterlink\LearningWorkspace\installer-state.json'
$ReleaseCertificateBase64 = 'MIIEFzCCAn+gAwIBAgIQI7vMPa2qRq5L+z65kFq5bDANBgkqhkiG9w0BAQsFADAuMSwwKgYDVQQDDCNMZWFybmluZyBXb3Jrc3BhY2UgUmVsZWFzZSBNYW5pZmVzdDAeFw0yNjEwMTgxMDM1NThaFw0zMTEwMTgxMDQ1NThaMC4xLDAqBgNVBAMMI0xlYXJuaW5nIFdvcmtzcGFjZSBSZWxlYXNlIE1hbmlmZXN0MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA1/s5h7ETzdTka+vfeTRyoJD/K/VQ9k3U5nHLrS2obEBLlgX4Z7eqeRtjMnDGXq3Vd3NJGYAb9c0PPP9LIPp505rVa22a+ONnkET/xmh3DzicQbox+KlR9otG1FBEvuMx7D6nO4OXkC3k8HYOQnTEx03kSEvccpnDW/egKhZjff3JlJ3e0vGnJMc4ilQdI9PlPqxr/AzcbsOSIr3y+VI5c2I0m5QLBoUgl8GcaNRljEWhAKz2eFzm++B38fObO+K+Wlk6y/695BHK3z7Fom5x1DKW1mStB94phpvJmN5vM0F0OCvktF0tK6fzD/jLzN2V4Iqeq2/8f5JFeE5BR2NjKqfQizPv9XSWTJLIBUI/3T1huQN56QbW1eYe7SNfrcUUuAGhdNmCGwsJsLKBDyhkK8tclkkHVzWKWUhmH37mUT2+QKiZAgcZW5HIL/xQs3xYsVnxIeKc2L0j92EMcOKIgAN4Sn+HAsCxl9lusCXqk1SPRKO8hF2Nuh2tZRHktMVtAgMBAAGjMTAvMA4GA1UdDwEB/wQEAwIHgDAdBgNVHQ4EFgQUnhPJfgkV9aCmU9NwfT48P5M5UW0wDQYJKoZIhvcNAQELBQADggGBAEr5U4hpcB8e054YIsbQ8dfsFc47GO7Dn4/Z/9CELeflysXTcv+2J1V/oLqOtAMYByExiDelt3KQ/Fh3rBXI+FHYrzWqLjd6f9sR7JgE0ggYpBgj2G0puuYrclV6jgmiH6/B1bei3/WrOh6Ckx8OKAXptlRigPpWlly7Ol3V8edwW78r+vrLx/Mvz0EyfZdgUKzlMmJ99XZC27wyFpzNAUPSEQGSiKSuXQZt6Y37SKqIgPqHxco3JtEqpuUTiCjGZcVENRCdjdGMqSUVA0Kx29eB/uHhYp0/8Afd7Dhg7HC4t6e3HnHhmmjmQ8nj92qCiLpdlr6kzIHwiQJN5VkVJl1/dTYkBEtK8dS9IabGl2DqXqJNkGMtSt+OqTPGsaSFs4Ktsw8c+m+3ax5cI/GV94H9DB35xHL90/KWvHCDfXmn0Fi8/KAxdbMkrhB97Bl//94MnJeJqMXO1Nq2IsYWYLTLLaAZxA8kCZRKVQYHOmWATOO4Q2Rr0KZ+x1n5Ofbg0g=='

function Get-ReleaseVersion([string]$Tag) {
    if ($Tag -notmatch '^v(?<version>\d+\.\d+\.\d+)$') { throw "Invalid release tag: $Tag" }
    return [version]$Matches.version
}

function Assert-ReleaseAssetUrl([string]$Url, [string]$Tag, [string]$Name) {
    $uri = [uri]$Url
    $expectedPath = "/$Repository/releases/download/$Tag/$Name"
    if ($uri.Scheme -ne 'https' -or $uri.Host -ne 'github.com' -or $uri.AbsolutePath -ne $expectedPath) {
        throw "Unexpected release asset URL: $Url"
    }
}

function Get-OneAsset($Release, [string]$Name) {
    $assets = @($Release.assets | Where-Object { $_.name -ceq $Name })
    if ($assets.Count -ne 1) { throw "Release must contain exactly one $Name asset." }
    Assert-ReleaseAssetUrl $assets[0].browser_download_url $Release.tag_name $Name
    return $assets[0]
}

function Get-HighestInstalledVersion {
    if (-not (Test-Path -LiteralPath $StateFile)) { return $null }
    try {
        $state = Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json
        return [version]$state.highestVersion
    }
    catch { throw 'Local installer security state is invalid. Refusing to weaken rollback protection.' }
}

function Save-HighestInstalledVersion([version]$Version) {
    $directory = Split-Path -Parent $StateFile
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    @{ highestVersion = $Version.ToString(); verifiedAt = [DateTime]::UtcNow.ToString('o') } |
        ConvertTo-Json -Compress | Set-Content -LiteralPath $StateFile -Encoding UTF8
}

function Get-Base64Sha512([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $hash = [Security.Cryptography.SHA512]::Create()
        try { return [Convert]::ToBase64String($hash.ComputeHash($stream)) }
        finally { $hash.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Get-HexSha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $hash = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($hash.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
        finally { $hash.Dispose() }
    }
    finally { $stream.Dispose() }
}

Write-Host 'Checking the latest cryptographically signed release...'
$release = Invoke-RestMethod "https://api.github.com/repos/$Repository/releases/latest" -Headers @{ 'User-Agent' = 'learning-workspace-secure-installer' }
if ($release.draft -or $release.prerelease) { throw 'GitHub returned a draft or prerelease as latest.' }
$version = Get-ReleaseVersion $release.tag_name
if ($version -lt $MinimumVersion) { throw "Release $version is below the bootstrap minimum $MinimumVersion." }

$manifestAsset = Get-OneAsset $release 'release-manifest.json'
$signatureAsset = Get-OneAsset $release 'release-manifest.sig'
$installerName = "$InstallerPrefix$version.exe"
$installerAsset = Get-OneAsset $release $installerName
$updaterAsset = Get-OneAsset $release 'latest.yml'

$directory = Join-Path $env:TEMP ('learning-workspace-' + [guid]::NewGuid().ToString('N'))
$manifestFile = Join-Path $directory 'release-manifest.json'
$signatureFile = Join-Path $directory 'release-manifest.sig'
$installerFile = Join-Path $directory $installerName
$updaterFile = Join-Path $directory 'latest.yml'
New-Item -ItemType Directory -Path $directory | Out-Null
try {
    Invoke-WebRequest $manifestAsset.browser_download_url -OutFile $manifestFile -UseBasicParsing
    Invoke-WebRequest $signatureAsset.browser_download_url -OutFile $signatureFile -UseBasicParsing
    $manifestBytes = [IO.File]::ReadAllBytes($manifestFile)
    $signatureBytes = [IO.File]::ReadAllBytes($signatureFile)
    $certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2 (,[Convert]::FromBase64String($ReleaseCertificateBase64))
    $rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($certificate)
    try {
        $valid = $rsa.VerifyData($manifestBytes, $signatureBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
    }
    finally { $rsa.Dispose(); $certificate.Dispose() }
    if (-not $valid) { throw 'Release manifest signature is invalid. Nothing was installed.' }

    $manifest = [Text.Encoding]::UTF8.GetString($manifestBytes) | ConvertFrom-Json
    if ($manifest.schema -ne 1 -or $manifest.repository -cne $Repository -or $manifest.tag -cne $release.tag_name -or $manifest.version -cne $version.ToString()) {
        throw 'Signed manifest identity does not match the selected release.'
    }
    if ($manifest.installer.name -cne $installerName -or $manifest.updater.name -cne 'latest.yml') {
        throw 'Signed manifest contains unexpected asset names.'
    }
    $highest = Get-HighestInstalledVersion
    if ($highest -and $version -lt $highest) { throw "Rollback blocked: release $version is older than previously installed $highest." }

    Write-Host "Downloading $installerName ($([math]::Round($installerAsset.size / 1MB)) MB)..."
    Invoke-WebRequest $installerAsset.browser_download_url -OutFile $installerFile -UseBasicParsing
    Invoke-WebRequest $updaterAsset.browser_download_url -OutFile $updaterFile -UseBasicParsing
    if ((Get-Base64Sha512 $installerFile) -cne $manifest.installer.sha512) { throw 'Signed installer hash mismatch. Nothing was installed.' }
    if ((Get-HexSha256 $updaterFile) -cne $manifest.updater.sha256) { throw 'Signed updater manifest hash mismatch. Nothing was installed.' }
    if ((Get-Item -LiteralPath $installerFile).Length -ne [int64]$manifest.installer.size) { throw 'Signed installer size mismatch. Nothing was installed.' }
    Write-Host "Verified release signature and hashes for $version."

    if ($DownloadOnly) { Write-Host 'DownloadOnly: verification passed; execution was skipped.'; return }
    Unblock-File -LiteralPath $installerFile
    Write-Host 'Starting the verified installer...'
    $process = Start-Process -FilePath $installerFile -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "Installer exited with code $($process.ExitCode)." }
    Save-HighestInstalledVersion $version
    Write-Host 'Done.'
}
finally {
    Remove-Item -LiteralPath $manifestFile, $signatureFile, $installerFile, $updaterFile -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $directory -Force -ErrorAction SilentlyContinue
}
