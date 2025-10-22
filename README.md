# Performance Benchmarking Suite

This directory contains comprehensive performance testing and analysis tools for compound file format implementations.

## 📁 Contents

### 🧪 **Benchmark Scripts**
- **`quick_benchmark.sh`** - Fast performance comparison (recommended for regular testing)
- **`performance_benchmark.sh`** - Comprehensive performance benchmarks
- **`cross_platform_benchmark.sh`** - Cross-platform testing script (Linux/macOS/Windows)
- **`windows_benchmark.bat`** - Windows batch file version
- **`windows_benchmark.ps1`** - Windows PowerShell version

### 🧠 **Memory Testing**
- **`memory_comparison_test.sh`** - Memory efficiency comparison between implementations
- **`memory_constrained_test.sh`** - Tests large file processing in limited memory environments

### 📊 **Analysis Reports**
- **`comprehensive_performance_analysis.md`** - Complete performance analysis with FileStreamAdapter results
- **`PERFORMANCE_ANALYSIS_REPORT.md`** - Detailed benchmark results and comparisons
- **`quick_performance_report.md`** - Latest quick benchmark results
- **`CompoundFile_Implementation_Report.md`** - FileStreamAdapter implementation report

## 🚀 **Quick Start**

### Run Quick Benchmark
```bash
cd ~/polytec/benchmarking
./quick_benchmark.sh
```

### Run Memory Tests
```bash
./memory_comparison_test.sh
```

### Cross-Platform Testing
```bash
./cross_platform_benchmark.sh
```

## 🎯 **What Gets Tested**

### Implementations Compared
1. **Rust Native** - Pure Rust compound file library
2. **cfbcpp (FFI)** - C++ wrapper using Rust FFI backend
3. **CompoundFile (C++ Translation)** - Direct C++ port with FileStreamAdapter

### Performance Metrics
- **File Creation Time** - 1GB compound file generation
- **Memory Usage** - Peak memory consumption during operations
- **Stream Operations** - Traversal and modification performance
- **Memory Efficiency** - Large files in constrained memory (FileStreamAdapter)

## 🏆 **Key Findings**

| Implementation | Best For | Memory Usage | Performance |
|---|---|---|---|
| **Rust Native** | Balanced functionality | 35MB | Complete features |
| **cfbcpp FFI** | High-speed operations | 1GB+ | Fastest creation |
| **CompoundFile** | Memory-constrained | **4MB** ⭐ | Most efficient |

## 🔧 **Requirements**

- **Linux/WSL2** environment
- **Rust** toolchain (`cargo`)
- **CMake** and **C++20** compiler
- **Git** for repository management
- **`time` command** for performance measurement

## 📈 **Results Summary**

- **FileStreamAdapter Achievement**: 97% memory reduction (4MB vs 104MB)
- **Production Ready**: All three implementations validated
- **Memory Champion**: CompoundFile C++ translation with streaming capabilities
- **Speed Champion**: cfbcpp FFI for memory-abundant scenarios
- **Balance Champion**: Rust native for comprehensive functionality

## 🛠️ **Usage Examples**

### Test Memory Efficiency
```bash
# Test FileStreamAdapter vs Rust native
./memory_comparison_test.sh
```

### Full Benchmark Suite
```bash
# Complete performance analysis
./performance_benchmark.sh
```

### Windows Testing
```powershell
# PowerShell version
./windows_benchmark.ps1
```

---
**Generated:** October 22, 2025  
**Environment:** Linux WSL2, 12th Gen Intel i7-1255U, 7.6GB RAM  
**Status:** ✅ All implementations production-ready with FileStreamAdapter integration complete