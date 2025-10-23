#!/bin/bash

# Quick Performance Test - Focused on speed without verbose output
set -e

echo "========================================="
echo "Quick Performance Test (Silent Mode)"
echo "========================================="
echo "Date: $(date)"
echo "CPU: $(cat /proc/cpuinfo | grep 'model name' | head -1 | cut -d: -f2 | xargs)"
echo "Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
echo "========================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to measure time quickly
quick_measure() {
    local name="$1"
    local command="$2"
    local workdir="$3"
    
    echo -e "${BLUE}Testing: $name${NC}"
    
    # Expand tilde to home directory
    workdir_expanded="${workdir/#\~/$HOME}"
    cd "$workdir_expanded"
    
    # Silent execution with time measurement
    echo "Running silently..."
    start_time=$(date +%s.%N)
    
    # Execute command silently
    if timeout 120s bash -c "$command > /dev/null 2>&1"; then
        end_time=$(date +%s.%N)
        duration=$(echo "$end_time - $start_time" | bc -l)
        echo -e "${GREEN}SUCCESS: Completed in ${duration}s${NC}"
        return 0
    else
        echo -e "${RED}FAILED or TIMEOUT${NC}"
        return 1
    fi
}

echo -e "\n${CYAN}=== BUILDING PROJECTS ===${NC}"

echo -e "\n${YELLOW}Building Rust...${NC}"
cd "$HOME/polytec/rust-cfb-compound-file-format"
cargo build --examples --release --quiet

echo -e "\n${YELLOW}Building CompoundFile C++...${NC}"
cd "$HOME/polytec/rust-cpp-cfb/compoundfile-rust-cpp"
if [ ! -d "build" ]; then
    mkdir build && cd build && cmake .. && cd ..
fi
cd build && make -j4

echo -e "\n${CYAN}=== QUICK PERFORMANCE TESTS ===${NC}"

# Test small operations first
echo -e "\n${YELLOW}1. CompoundFile C++ - DIFAT Stress Test${NC}"
quick_measure "CompoundFile DIFAT" \
    "./CompoundFileDifatStressTest" \
    "$HOME/polytec/rust-cpp-cfb/compoundfile-rust-cpp/build"

echo -e "\n${YELLOW}2. CompoundFile C++ - Write Test${NC}"
quick_measure "CompoundFile Write" \
    "./CompoundFileWriteTest" \
    "$HOME/polytec/rust-cpp-cfb/compoundfile-rust-cpp/build"

echo -e "\n${YELLOW}3. Rust CFB - Quick Test${NC}"
quick_measure "Rust CFB Quick" \
    "cargo run --release --example cfbtool --quiet" \
    "$HOME/polytec/rust-cfb-compound-file-format"

echo -e "\n${YELLOW}4. Rust CFB - Medium File Test${NC}"
quick_measure "Rust Medium" \
    "timeout 60s cargo run --release --example create_1gb_cfb --quiet || true" \
    "$HOME/polytec/rust-cfb-compound-file-format"

echo -e "\n${CYAN}=== MEMORY USAGE COMPARISON ===${NC}"

echo -e "\n${YELLOW}CompoundFile C++ Memory Test${NC}"
cd "$HOME/polytec/rust-cpp-cfb/compoundfile-rust-cpp/build"
echo "Starting memory monitoring..."
/usr/bin/time -f "CompoundFile: Real=%E MaxMemory=%MkB" ./CompoundFileDifatStressTest > /dev/null 2>&1 || true

echo -e "\n${YELLOW}Rust CFB Memory Test${NC}"
cd "$HOME/polytec/rust-cfb-compound-file-format"
echo "Starting memory monitoring..."
/usr/bin/time -f "Rust CFB: Real=%E MaxMemory=%MkB" cargo run --release --example cfbtool --quiet > /dev/null 2>&1 || true

echo -e "\n${GREEN}=== QUICK TEST COMPLETED ===${NC}"
echo "This quick test focuses on immediate performance without verbose output"
echo "For detailed analysis, run the full performance_benchmark.sh (after fixing verbose output)"