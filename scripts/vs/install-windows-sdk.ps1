$ErrorActionPreference = 'Stop'
$sdkVersion = $env:VS_WINDOWS_SDK_VERSION
if ($sdkVersion -ne '10.0.28000.0' -or $env:WINDOWS_SDK_RELEASE -ne '10.0.28000.2957') {
    throw 'This installer is pinned to Windows SDK release 10.0.28000.2957 (SDK directory 10.0.28000.0).'
}
$url = 'https://download.microsoft.com/download/e6cfffdc-0d3e-4c6c-96d7-d491da459a07/KIT_BUNDLE_WINDOWSSDK_MEDIACREATION/winsdksetup.exe'
$expected = 'e8e264aca8bc34abdf592352bf09f986a85cdb96db0efba405ca9e149181fe61'
$installer = Join-Path $env:RUNNER_TEMP 'winsdk-10.0.28000.2957.exe'
$log = Join-Path $env:RUNNER_TEMP 'winsdk-10.0.28000.2957.log'
Invoke-WebRequest -Uri $url -OutFile $installer
if ((Get-FileHash -Algorithm SHA256 $installer).Hash.ToLowerInvariant() -ne $expected) {
    throw 'Windows SDK installer SHA-256 mismatch'
}
# Install the exact release even if an earlier 28000 patch uses the same SDK directory.
$arguments = '/features OptionId.DesktopCPPx86 OptionId.DesktopCPPx64 OptionId.DesktopCPPARM64 OptionId.UWPCPP /quiet /norestart /log "' + $log + '"'
$process = Start-Process -FilePath $installer -ArgumentList $arguments -Wait -PassThru
if ($process.ExitCode -notin @(0, 3010)) {
    if (Test-Path $log) { Get-Content $log -Tail 100 }
    throw "Windows SDK installation failed: $($process.ExitCode)"
}
$kits = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
foreach ($relative in @("Include/$sdkVersion/um/Windows.h", "Include/$sdkVersion/ucrt/stdio.h",
                         "Lib/$sdkVersion/um/x64/kernel32.lib", "Lib/$sdkVersion/um/arm64/kernel32.lib")) {
    if (-not (Test-Path (Join-Path $kits $relative))) { throw "SDK output missing: $relative" }
}
Write-Host "Installed SDK release $env:WINDOWS_SDK_RELEASE; CMake SDK version $sdkVersion"
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
if (Test-Path $vswhere) {
    & $vswhere -all -products '*' -format json
    if ($LASTEXITCODE -ne 0) { throw 'Cannot report installed Visual Studio compiler hosts' }
}
