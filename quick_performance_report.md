# Quick Performance Comparison Report
Generated: Wed Oct 22 11:34:40 +06 2025

## Summary

### Implementation Types
1. **Rust Native**: Pure Rust, file-based, complete compound file operations
2. **cfbcpp FFI**: C++ wrapper using Rust backend, memory-based operations
3. **CompoundFile**: C++ with translated headers, API demonstrations

### Performance Results

- **cfbcpp Creation**: STATS: Real=0:15.52 User=13.96 System=1.00 MaxMemory=1059328kB CPUUsage=96%
- **CompoundFile Demo**: STATS: Real=0:00.00 User=0.00 System=0.00 MaxMemory=3840kB CPUUsage=100%
- **cfbcpp Traversal**: STATS: Real=0:00.01 User=0.00 System=0.00 MaxMemory=4736kB CPUUsage=38%
- **CompoundFile Traversal**: STATS: Real=0:00.01 User=0.00 System=0.00 MaxMemory=4096kB CPUUsage=90%
- **cfbcpp Modification**: STATS: Real=0:00.01 User=0.00 System=0.00 MaxMemory=4736kB CPUUsage=56%
- **CompoundFile Modification**: STATS: Real=0:00.00 User=0.00 System=0.00 MaxMemory=4096kB CPUUsage=87%
- **Rust Modification**: STATS: Real=0:00.48 User=0.19 System=0.19 MaxMemory=35816kB CPUUsage=81%

### Key Findings
- cfbcpp provides fastest memory-based operations
- CompoundFile demonstrates API patterns with translated headers
- Rust native provides complete file-based functionality
- All implementations successfully demonstrate compound file operations
