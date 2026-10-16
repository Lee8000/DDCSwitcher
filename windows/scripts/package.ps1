$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$repo = Split-Path -Parent $root
$folder = Join-Path $root 'dist/DDCSwitcher-windows-x64'
New-Item -ItemType Directory -Force -Path $folder | Out-Null
Copy-Item "$root/build/Release/DDCSwitcher.exe" $folder -Force
Copy-Item "$root/README.md" "$folder/README.md" -Force
Copy-Item "$repo/LICENSE" $folder -Force
Copy-Item "$repo/THIRD_PARTY.md" $folder -Force
Compress-Archive -Path $folder -DestinationPath "$root/dist/DDCSwitcher-windows-x64.zip" -Force
Write-Host "Packaged $root/dist/DDCSwitcher-windows-x64.zip"
