# Simple test of performance measurement function
. .\performance_benchmark.ps1

Write-Host "Testing performance measurement on a simple cargo build..."

$RustProjectPath = "e:\polytec\rust-cfb-compound-file-format"
Set-Location $RustProjectPath

$result = Measure-Performance "Test Rust Build" "cargo build --release --quiet" $RustProjectPath 60

Write-Host "`nTest Results:"
Write-Host "Success: $($result.Success)"
Write-Host "Time: $($result.Time)"
Write-Host "Memory: $($result.Memory)" 
Write-Host "CPU Usage: $($result.CpuUsage)"
Write-Host "Exit Code: $($result.ExitCode)"