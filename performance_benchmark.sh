#!/bin/bash

# Performance Benchmark Script for Compound File Implementations
# Compares Rust native, C++ cfbcpp wrapper, and C++ CompoundFile implementations

set -e

echo "==================================================================="
echo "Performance Benchmark for Compound File Implementations"
echo "==================================================================="
echo "Date: $(date)"
echo "System: $(uname -a)"
echo "CPU: $(cat /proc/cpuinfo | grep 'model name' | head -1 | cut -d: -f2 | xargs)"
echo "Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
echo "==================================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to measure time and memory
measure_performance() {
    local name="$1"
    local command="$2"
    local workdir="$3"
    
    echo -e "${BLUE}Testing: $name${NC}"
    echo "Command: $command"
    echo "Working Directory: $workdir"
    
    # Expand tilde to home directory
    workdir_expanded="${workdir/#\~/$HOME}"
    cd "$workdir_expanded"
    
    # Use /usr/bin/time for detailed measurements (suppress verbose output)
    echo "Starting measurement..."
    # Use /usr/bin/time for detailed measurements (suppress verbose output)
    echo "Starting measurement..."
    /usr/bin/time -f "STATS: Real=%E User=%U System=%S MaxMemory=%MkB CPUUsage=%P" \
        timeout 300s bash -c "$command > /dev/null 2>&1" 2>&1 | grep -E "(STATS:|timeout|error|Error|ERROR)" | tee "/tmp/benchmark_${name// /_}.log"    local exit_code=${PIPESTATUS[0]}
    
    if [ $exit_code -eq 124 ]; then
        echo -e "${RED}TIMEOUT: Test exceeded 5 minutes${NC}"
        return 124
    elif [ $exit_code -ne 0 ]; then
        echo -e "${RED}ERROR: Test failed with exit code $exit_code${NC}"
        return $exit_code
    else
        echo -e "${GREEN}SUCCESS: Test completed${NC}"
        return 0
    fi
}

# Function to extract performance stats
extract_stats() {
    local log_file="$1"
    local name="$2"
    
    if [ -f "$log_file" ]; then
        local stats_line=$(grep "STATS:" "$log_file" | tail -1)
        if [ -n "$stats_line" ]; then
            echo "$name: $stats_line"
        else
            echo "$name: No performance stats found"
        fi
    else
        echo "$name: Log file not found"
    fi
}

# Function to check file sizes
check_file_size() {
    local file="$1"
    local name="$2"
    
    if [ -f "$file" ]; then
        local size=$(du -h "$file" | cut -f1)
        local size_bytes=$(stat --format=%s "$file")
        echo "$name output file: $size ($size_bytes bytes)"
    else
        echo "$name: Output file not found"
    fi
}

echo -e "\n${PURPLE}=== PHASE 1: BUILD ALL PROJECTS ===${NC}"

# Detect workspace root (cross-platform)
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$HOME/polytec}"
if [ ! -d "$WORKSPACE_ROOT" ]; then
    WORKSPACE_ROOT="$(dirname "$(dirname "$(readlink -f "$0")")")"
fi

echo -e "\n${CYAN}Using workspace root: $WORKSPACE_ROOT${NC}"

echo -e "\n${CYAN}Building Rust project...${NC}"
cd "$WORKSPACE_ROOT/rust-cfb-compound-file-format"
cargo build --examples --release

echo -e "\n${CYAN}Building cfbcpp project...${NC}"
cd "$WORKSPACE_ROOT/cfbcpp"
if [ ! -d "build" ]; then
    mkdir build
    cd build
    cmake ..
    cd ..
fi
cd build && make -j4

echo -e "\n${CYAN}Building CompoundFile project (Linux only)...${NC}"
if command -v gcc >/dev/null 2>&1; then
    cd "$WORKSPACE_ROOT/rust-cpp-cfb/compoundfile-rust-cpp"
    if [ ! -d "build" ]; then
        mkdir build
        cd build
        cmake ..
        cd ..
    fi
    cd build && make -j4
else
    echo -e "${YELLOW}GCC not available - skipping CompoundFile build${NC}"
fi

echo -e "\n${PURPLE}=== PHASE 2: 1GB FILE CREATION BENCHMARKS ===${NC}"

# Clean up any existing large files
rm -f "$HOME/polytec/rust-cfb-compound-file-format/large_1gb.cfb"
rm -f "$HOME/polytec/cfbcpp/build/large_1gb_memory.cfb"  
rm -f "$HOME/polytec/rust-cpp-cfb/compoundfile-rust-cpp/build/large_1gb_mscompoundfile.cfb"

echo -e "\n${YELLOW}1. Rust Implementation (Native)${NC}"
measure_performance "Rust 1GB Creation" \
    "cargo run --release --example create_1gb_cfb --quiet" \
    "$HOME/polytec/rust-cfb-compound-file-format"

echo -e "\n${YELLOW}2. C++ cfbcpp Implementation (FFI Wrapper)${NC}"
measure_performance "cfbcpp 1GB Creation" \
    "./create_1gb_cfb" \
    "$HOME/polytec/cfbcpp/build"

echo -e "\n${YELLOW}3. C++ CompoundFile Implementation (Translated Headers)${NC}"
measure_performance "CompoundFile 1GB Creation" \
    "./create_1gb_cfb" \
    "$HOME/polytec/rust-cpp-cfb/compoundfile-rust-cpp/build"

echo -e "\n${PURPLE}=== PHASE 3: STREAM TRAVERSAL BENCHMARKS ===${NC}"

# Create smaller test files for traversal if 1GB files don't exist or are too large
echo -e "\n${CYAN}Creating smaller test files for traversal benchmarks...${NC}"

# Create a smaller Rust file for testing
cd "$HOME/polytec/rust-cfb-compound-file-format"
if [ ! -f "test_medium.cfb" ]; then
    echo "Creating medium-sized test file with Rust..."
    timeout 120s cargo run --release --example create_1gb_cfb || true
    if [ -f "large_1gb.cfb" ]; then
        cp large_1gb.cfb test_medium.cfb
    fi
fi

echo -e "\n${YELLOW}1. Rust Stream Traversal${NC}"
if [ -f "large_1gb.cfb" ]; then
    measure_performance "Rust Stream Traversal" \
        "timeout 300s cargo run --release --example traverse_streams --quiet" \
        "$HOME/polytec/rust-cfb-compound-file-format"
else
    echo "Skipping Rust traversal - no input file available"
fi

echo -e "\n${YELLOW}2. C++ cfbcpp Stream Traversal${NC}"
measure_performance "cfbcpp Stream Traversal" \
    "./traverse_streams" \
    "$HOME/polytec/cfbcpp/build"

echo -e "\n${YELLOW}3. C++ CompoundFile Stream Traversal${NC}"
measure_performance "CompoundFile Stream Traversal" \
    "./traverse_streams" \
    "$HOME/polytec/rust-cpp-cfb/compoundfile-rust-cpp/build"

echo -e "\n${PURPLE}=== PHASE 4: STREAM MODIFICATION BENCHMARKS ===${NC}"

echo -e "\n${YELLOW}1. Rust Stream Modification${NC}"
measure_performance "Rust Stream Modification" \
    "cargo run --release --example modify_streams --quiet" \
    "$HOME/polytec/rust-cfb-compound-file-format"

echo -e "\n${YELLOW}2. C++ cfbcpp Stream Modification${NC}"
measure_performance "cfbcpp Stream Modification" \
    "./modify_streams" \
    "$HOME/polytec/cfbcpp/build"

echo -e "\n${YELLOW}3. C++ CompoundFile Stream Modification${NC}"
measure_performance "CompoundFile Stream Modification" \
    "./modify_streams" \
    "$HOME/polytec/rust-cpp-cfb/compoundfile-rust-cpp/build"

echo -e "\n${PURPLE}=== PHASE 5: PERFORMANCE SUMMARY ===${NC}"

echo -e "\n${CYAN}=== File Creation Performance ===${NC}"
extract_stats "/tmp/benchmark_Rust_1GB_Creation.log" "Rust (Native)"
extract_stats "/tmp/benchmark_cfbcpp_1GB_Creation.log" "cfbcpp (FFI)"
extract_stats "/tmp/benchmark_CompoundFile_1GB_Creation.log" "CompoundFile (Translated)"

echo -e "\n${CYAN}=== Output File Sizes ===${NC}"
check_file_size "$HOME/polytec/rust-cfb-compound-file-format/large_1gb.cfb" "Rust"
check_file_size "$HOME/polytec/cfbcpp/build/large_1gb_memory.cfb" "cfbcpp"  
check_file_size "$HOME/polytec/rust-cpp-cfb/compoundfile-rust-cpp/build/large_1gb_mscompoundfile.cfb" "CompoundFile"

echo -e "\n${CYAN}=== Stream Traversal Performance ===${NC}"
extract_stats "/tmp/benchmark_Rust_Stream_Traversal.log" "Rust (Native)"
extract_stats "/tmp/benchmark_cfbcpp_Stream_Traversal.log" "cfbcpp (FFI)"
extract_stats "/tmp/benchmark_CompoundFile_Stream_Traversal.log" "CompoundFile (Translated)"

echo -e "\n${CYAN}=== Stream Modification Performance ===${NC}"
extract_stats "/tmp/benchmark_Rust_Stream_Modification.log" "Rust (Native)"
extract_stats "/tmp/benchmark_cfbcpp_Stream_Modification.log" "cfbcpp (FFI)"
extract_stats "/tmp/benchmark_CompoundFile_Stream_Modification.log" "CompoundFile (Translated)"

echo -e "\n${GREEN}=== BENCHMARK COMPLETED ===${NC}"
echo "Individual test logs saved to /tmp/benchmark_*.log"
echo "Run 'cat /tmp/benchmark_*.log' to see detailed outputs"

# Create a summary report
echo -e "\n${PURPLE}=== GENERATING SUMMARY REPORT ===${NC}"
{
    echo "# Compound File Implementation Performance Report"
    echo "Generated on: $(date)"
    echo ""
    echo "## System Information"
    echo "- OS: $(uname -o)"
    echo "- Kernel: $(uname -r)"
    echo "- Architecture: $(uname -m)"
    echo "- CPU: $(cat /proc/cpuinfo | grep 'model name' | head -1 | cut -d: -f2 | xargs)"
    echo "- Total Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
    echo ""
    echo "## Test Results Summary"
    echo ""
    echo "### 1GB File Creation Performance"
    extract_stats "/tmp/benchmark_Rust_1GB_Creation.log" "- **Rust (Native)**"
    extract_stats "/tmp/benchmark_cfbcpp_1GB_Creation.log" "- **cfbcpp (FFI Wrapper)**"
    extract_stats "/tmp/benchmark_CompoundFile_1GB_Creation.log" "- **CompoundFile (Translated Headers)**"
    echo ""
    echo "### Stream Traversal Performance"
    extract_stats "/tmp/benchmark_Rust_Stream_Traversal.log" "- **Rust (Native)**"
    extract_stats "/tmp/benchmark_cfbcpp_Stream_Traversal.log" "- **cfbcpp (FFI Wrapper)**"
    extract_stats "/tmp/benchmark_CompoundFile_Stream_Traversal.log" "- **CompoundFile (Translated Headers)**"
    echo ""
    echo "### Stream Modification Performance"
    extract_stats "/tmp/benchmark_Rust_Stream_Modification.log" "- **Rust (Native)**"
    extract_stats "/tmp/benchmark_cfbcpp_Stream_Modification.log" "- **cfbcpp (FFI Wrapper)**"
    extract_stats "/tmp/benchmark_CompoundFile_Stream_Modification.log" "- **CompoundFile (Translated Headers)**"
    echo ""
    echo "## Output File Analysis"
    check_file_size "$HOME/polytec/rust-cfb-compound-file-format/large_1gb.cfb" "- **Rust**:"
    check_file_size "$HOME/polytec/cfbcpp/build/large_1gb_memory.cfb" "- **cfbcpp**:"
    check_file_size "$HOME/polytec/rust-cpp-cfb/compoundfile-rust-cpp/build/large_1gb_mscompoundfile.cfb" "- **CompoundFile**:"
    echo ""
    echo "## Notes"
    echo "- Time format: Real=Wall_Clock_Time User=User_CPU_Time System=System_CPU_Time"
    echo "- Memory in KB (MaxMemory=Peak_Memory_Usage)"
    echo "- CPU Usage as percentage of total available CPU time"
    echo "- Tests had 10-minute timeout limit"
} > "$HOME/polytec/performance_report.md"

echo "Summary report saved to: $HOME/polytec/performance_report.md"