$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
ctest --test-dir "$root/build" -C Release --output-on-failure
if ($LASTEXITCODE -ne 0) { throw 'Core tests failed' }
$report = Join-Path $root 'build/native-self-test.txt'
$process = Start-Process -FilePath "$root/build/Release/DDCSwitcher.exe" -ArgumentList @('--self-test', ('"{0}"' -f $report)) -Wait -PassThru
if (Test-Path $report) { Get-Content $report -Encoding UTF8 }
if ($process.ExitCode -ne 0) { throw "Native self-test failed: $($process.ExitCode)" }
if (-not (Test-Path $report)) { throw 'Native self-test report missing' }
