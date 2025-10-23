# Debug memory monitoring
Write-Host "Testing memory monitoring directly..."

# Test the memory monitoring script
$memoryMonitorScript = {
    param($ProcessNamePatterns, $MonitoringDurationSeconds)
    
    Write-Output "Starting memory monitoring for $MonitoringDurationSeconds seconds..."
    Write-Output "Monitoring patterns: $($ProcessNamePatterns -join ', ')"
    
    $maxMemoryMB = 0
    $startTime = Get-Date
    $processMemories = @{}
    $iterations = 0
    
    while (((Get-Date) - $startTime).TotalSeconds -lt $MonitoringDurationSeconds) {
        $iterations++
        try {
            # Get all processes matching our patterns
            $allProcesses = Get-Process | Where-Object { 
                $processMatches = $false
                foreach ($pattern in $ProcessNamePatterns) {
                    if ($_.ProcessName -like $pattern) {
                        $processMatches = $true
                        break
                    }
                }
                $processMatches
            } -ErrorAction SilentlyContinue
            
            if ($allProcesses) {
                Write-Output "Found $($allProcesses.Count) matching processes in iteration $iterations"
                foreach ($proc in $allProcesses) {
                    try {
                        $procMemoryMB = $proc.WorkingSet64 / 1MB
                        Write-Output "Process $($proc.ProcessName) (PID: $($proc.Id)): ${procMemoryMB}MB"
                        
                        # Track per-process peak memory
                        $procKey = "$($proc.Id)-$($proc.ProcessName)"
                        if (-not $processMemories.ContainsKey($procKey) -or $processMemories[$procKey] -lt $procMemoryMB) {
                            $processMemories[$procKey] = $procMemoryMB
                        }
                        
                        # Update overall maximum
                        if ($procMemoryMB -gt $maxMemoryMB) {
                            $maxMemoryMB = $procMemoryMB
                            Write-Output "New max memory: ${maxMemoryMB}MB"
                        }
                    } catch {
                        Write-Output "Error accessing process $($proc.ProcessName): ${_}"
                    }
                }
            } else {
                Write-Output "No matching processes found in iteration $iterations"
            }
        } catch {
            Write-Output "Monitoring error in iteration ${iterations}: ${_}"
        }
        
        Start-Sleep -Milliseconds 500
    }
    
    # Calculate total memory across all tracked processes
    $totalPeakMemoryMB = if ($processMemories.Values) { ($processMemories.Values | Measure-Object -Sum).Sum } else { 0 }
    
    Write-Output "Final results:"
    Write-Output "- Iterations: $iterations"
    Write-Output "- Processes tracked: $($processMemories.Count)"
    Write-Output "- Max single process: ${maxMemoryMB}MB"  
    Write-Output "- Total peak memory: ${totalPeakMemoryMB}MB"
    
    return @{ 
        MaxSingleProcessMB = $maxMemoryMB
        TotalPeakMemoryMB = $totalPeakMemoryMB
        ProcessCount = $processMemories.Count
        Iterations = $iterations
    }
}

# Test monitoring cargo processes
Write-Host "`nStarting cargo build and monitoring memory..."
$processPatterns = @("*cargo*", "*rustc*", "*cfb*")
$memoryJob = Start-Job -ScriptBlock $memoryMonitorScript -ArgumentList $processPatterns, 10

# Start a simple cargo command
cd e:\polytec\rust-cfb-compound-file-format
Start-Process -FilePath "cargo" -ArgumentList "check", "--quiet" -NoNewWindow -Wait

# Get results
$jobOutput = Wait-Job $memoryJob -Timeout 15 | Receive-Job
$memoryResult = $jobOutput | Where-Object { $_ -is [hashtable] } | Select-Object -First 1

Write-Host "`nJob output:"
$jobOutput | ForEach-Object { Write-Host $_ }

Write-Host "`nMemory result:"
if ($memoryResult) {
    Write-Host "Max Single Process: $($memoryResult.MaxSingleProcessMB)MB"
    Write-Host "Total Peak Memory: $($memoryResult.TotalPeakMemoryMB)MB" 
    Write-Host "Process Count: $($memoryResult.ProcessCount)"
    Write-Host "Iterations: $($memoryResult.Iterations)"
} else {
    Write-Host "No memory result received"
}

Remove-Job $memoryJob -Force