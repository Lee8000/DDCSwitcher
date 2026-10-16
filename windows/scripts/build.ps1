$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
cmake -S $root -B "$root/build" -A x64
if ($LASTEXITCODE -ne 0) { throw 'CMake configure failed' }
cmake --build "$root/build" --config Release --parallel
if ($LASTEXITCODE -ne 0) { throw 'Build failed' }
Write-Host "Built $root/build/Release/DDCSwitcher.exe"
