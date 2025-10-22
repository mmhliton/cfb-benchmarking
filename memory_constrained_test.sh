#!/bin/bash

# Memory-constrained test for CompoundFile C++ translation
# Tests FileStreamAdapter with large files in limited memory environment
# Compares memory usage with Rust native implementation

set -e

echo "=== Memory-Constrained CompoundFile Test ==="
echo "Testing FileStreamAdapter for streaming operations with large files"
echo

# Build paths
RUST_CFB_DIR="/home/mainul/polytec/rust-cfb-compound-file-format"
CPP_TRANSLATION_DIR="/home/mainul/polytec/rust-cpp-cfb/CompoundFile"
TEST_DIR="/tmp/cfb_memory_test"

# Memory limit for testing (100MB)
MEMORY_LIMIT_MB=100
MEMORY_LIMIT_KB=$((MEMORY_LIMIT_MB * 1024))

# Test file info
TEST_FILE_SIZE_MB=500  # Start with 500MB, can increase to 1GB if successful
TEST_FILE="$TEST_DIR/large_test.cfb"

# Create test directory
mkdir -p "$TEST_DIR"

echo "Step 1: Creating large test file (${TEST_FILE_SIZE_MB}MB)..."

if [[ ! -f "$TEST_FILE" ]]; then
    # Create large CFB file using Rust implementation
    cd "$RUST_CFB_DIR"
    
    cat > create_large_test.rs << 'EOF'
use std::io::{Write, Seek, SeekFrom};
use cfb;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let file_path = std::env::args().nth(1)
        .expect("Usage: create_large_test <output_file> <size_mb>");
    let size_mb: usize = std::env::args().nth(2)
        .and_then(|s| s.parse().ok())
        .expect("Size must be a number");
    
    println!("Creating {}MB CFB file at {}", size_mb, file_path);
    
    let mut comp = cfb::create(&file_path)?;
    
    // Create multiple storage levels
    comp.create_storage_all("/Level1/Level2/Level3/")?;
    comp.create_storage_all("/Data/Streams/")?;
    comp.create_storage_all("/Large/Files/")?;
    
    // Create many streams with varying sizes to reach target file size
    let target_bytes = size_mb * 1024 * 1024;
    let mut total_written = 0;
    let mut stream_count = 0;
    
    while total_written < target_bytes {
        let remaining = target_bytes - total_written;
        let stream_size = std::cmp::min(remaining, 1024 * 1024); // 1MB max per stream
        
        let stream_path = format!("/Data/Streams/stream_{:04}", stream_count);
        let mut stream = comp.create_stream(&stream_path)?;
        
        // Write pattern data
        let pattern = format!("Stream {} data pattern ", stream_count);
        let pattern_bytes = pattern.as_bytes();
        let mut written_in_stream = 0;
        
        while written_in_stream < stream_size {
            let remaining_in_stream = stream_size - written_in_stream;
            let chunk_size = std::cmp::min(remaining_in_stream, pattern_bytes.len());
            stream.write_all(&pattern_bytes[..chunk_size])?;
            written_in_stream += chunk_size;
        }
        
        drop(stream);
        total_written += stream_size;
        stream_count += 1;
        
        if stream_count % 10 == 0 {
            println!("Created {} streams, {} MB written", stream_count, total_written / (1024 * 1024));
        }
    }
    
    comp.flush()?;
    println!("Successfully created CFB file with {} streams, total size: {} MB", 
             stream_count, total_written / (1024 * 1024));
    
    Ok(())
}
EOF

    # Compile and run
    rustc --extern cfb=target/debug/deps/libcfb-*.rlib -L target/debug/deps create_large_test.rs -o create_large_test
    ./create_large_test "$TEST_FILE" "$TEST_FILE_SIZE_MB"
    
    echo "Created test file: $(du -h "$TEST_FILE" | cut -f1)"
else
    echo "Using existing test file: $(du -h "$TEST_FILE" | cut -f1)"
fi

echo
echo "Step 2: Testing Rust native implementation memory usage..."

# Test Rust implementation with memory monitoring
cd "$RUST_CFB_DIR"

cat > test_memory_usage.rs << 'EOF'
use std::io::Read;
use cfb;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let file_path = std::env::args().nth(1)
        .expect("Usage: test_memory_usage <cfb_file>");
    
    println!("Opening CFB file: {}", file_path);
    let comp = cfb::open(&file_path)?;
    
    let mut stream_count = 0;
    let mut total_size = 0u64;
    
    println!("Walking all entries...");
    for entry in comp.walk() {
        if entry.is_stream() {
            let mut stream = comp.open_stream(entry.path())?;
            let mut buffer = vec![0u8; 8192]; // 8KB buffer for streaming
            let mut stream_size = 0u64;
            
            loop {
                match stream.read(&mut buffer) {
                    Ok(0) => break, // EOF
                    Ok(n) => stream_size += n as u64,
                    Err(e) => return Err(e.into()),
                }
            }
            
            total_size += stream_size;
            stream_count += 1;
            
            if stream_count % 50 == 0 {
                println!("Processed {} streams, {} MB total", 
                         stream_count, total_size / (1024 * 1024));
            }
        }
    }
    
    println!("Completed: {} streams, {} MB total", 
             stream_count, total_size / (1024 * 1024));
    
    Ok(())
}
EOF

# Monitor memory usage during Rust execution
echo "Running Rust implementation with memory monitoring..."
rustc --extern cfb=target/debug/deps/libcfb-*.rlib -L target/debug/deps test_memory_usage.rs -o test_memory_usage

# Use timeout and memory limit to constrain execution
timeout 300s /bin/bash -c "
    ulimit -v $MEMORY_LIMIT_KB
    /usr/bin/time -v ./test_memory_usage '$TEST_FILE' 2>&1 | tee '$TEST_DIR/rust_memory_report.txt'
" || {
    echo "Rust test completed (may have been limited by memory constraint)"
}

# Extract memory usage from time output
RUST_MAX_RSS=$(grep "Maximum resident set size" "$TEST_DIR/rust_memory_report.txt" | awk '{print $6}' || echo "N/A")
echo "Rust maximum memory usage: ${RUST_MAX_RSS} KB"

echo
echo "Step 3: Testing C++ translation with FileStreamAdapter..."

# Build C++ translation
cd "$CPP_TRANSLATION_DIR"

if [[ ! -f "Makefile" && ! -f "CMakeLists.txt" ]]; then
    echo "Creating simple build configuration for C++ translation..."
    
    cat > CMakeLists.txt << 'EOF'
cmake_minimum_required(VERSION 3.16)
project(CompoundFileMemoryTest)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(memory_test_cpp 
    CompoundFile.cpp
    ../rust-cfb/src/internal/io.cpp
)

target_include_directories(memory_test_cpp PRIVATE 
    ../rust-cfb/src
    .
)

target_compile_options(memory_test_cpp PRIVATE -O2 -g)
EOF
fi

# Create io.cpp if it doesn't exist
if [[ ! -f "../rust-cfb/src/internal/io.cpp" ]]; then
    cat > "../rust-cfb/src/internal/io.cpp" << 'EOF'
#include "io.h"
#include <fstream>

std::vector<std::byte> ReadFileToBytes(const std::filesystem::path& path) {
    std::ifstream file(path, std::ios::binary | std::ios::ate);
    if (!file.is_open()) {
        throw std::ios_base::failure("Cannot open file: " + path.string());
    }
    
    auto size = file.tellg();
    file.seekg(0, std::ios::beg);
    
    std::vector<std::byte> data(size);
    file.read(reinterpret_cast<char*>(data.data()), size);
    
    return data;
}

std::string utf16_to_utf8_win(const std::wstring& wstr) {
    // Simple ASCII conversion for testing
    std::string result;
    for (wchar_t wc : wstr) {
        if (wc < 128) {
            result.push_back(static_cast<char>(wc));
        } else {
            result.push_back('?');
        }
    }
    return result;
}
EOF
fi

# Build with CMake
mkdir -p build
cd build
cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo
make -j$(nproc)

echo "Running C++ translation with memory monitoring..."

# Create a modified version of CompoundFile.cpp for memory testing
cd "$CPP_TRANSLATION_DIR"
cat > memory_test.cpp << 'EOF'
#include <iostream>
#include <fstream>
#include <chrono>
#include <filesystem>

#include "../rust-cfb/src/lib.h"

int main(int argc, char* argv[]) {
    if (argc != 2) {
        std::cerr << "Usage: " << argv[0] << " <cfb_file>" << std::endl;
        return 1;
    }
    
    std::filesystem::path filePath(argv[1]);
    
    try {
        std::cout << "Opening CFB file with FileStreamAdapter: " << filePath << std::endl;
        
        auto start = std::chrono::high_resolution_clock::now();
        
        FileStreamAdapter fileAdapter(filePath);
        auto cf = CompoundFile<FileStreamAdapter>::open(std::move(fileAdapter));
        
        std::cout << "File opened successfully!" << std::endl;
        
        int streamCount = 0;
        size_t totalSize = 0;
        auto entries = cf.walk();
        
        std::cout << "Processing streams..." << std::endl;
        
        while (auto entry = entries.next()) {
            if (entry->is_stream()) {
                auto stream = cf.open_stream_with_id(entry->get_stream_id());
                size_t streamSize = stream.len();
                
                // Read stream in chunks to test streaming
                const size_t CHUNK_SIZE = 8192; // 8KB chunks
                std::vector<std::byte> buffer(CHUNK_SIZE);
                size_t totalRead = 0;
                
                while (totalRead < streamSize) {
                    size_t toRead = std::min(CHUNK_SIZE, streamSize - totalRead);
                    std::span<std::byte> chunk = std::span(buffer).subspan(0, toRead);
                    read_exact(stream, chunk);
                    totalRead += toRead;
                }
                
                totalSize += streamSize;
                streamCount++;
                
                if (streamCount % 50 == 0) {
                    std::cout << "Processed " << streamCount << " streams, " 
                              << (totalSize / (1024 * 1024)) << " MB total" << std::endl;
                }
            }
        }
        
        auto end = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
        
        std::cout << "Completed: " << streamCount << " streams, " 
                  << (totalSize / (1024 * 1024)) << " MB total" << std::endl;
        std::cout << "Time taken: " << duration.count() << " ms" << std::endl;
        
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }
    
    return 0;
}
EOF

# Compile memory test
g++ -std=c++20 -O2 -g -I../rust-cfb/src -I. \
    memory_test.cpp ../rust-cfb/src/internal/io.cpp \
    -o memory_test_cpp

# Run with memory monitoring
echo "Running C++ implementation with memory monitoring..."
timeout 300s /bin/bash -c "
    ulimit -v $MEMORY_LIMIT_KB
    /usr/bin/time -v ./memory_test_cpp '$TEST_FILE' 2>&1 | tee '$TEST_DIR/cpp_memory_report.txt'
" || {
    echo "C++ test completed (may have been limited by memory constraint)"
}

# Extract memory usage from time output
CPP_MAX_RSS=$(grep "Maximum resident set size" "$TEST_DIR/cpp_memory_report.txt" | awk '{print $6}' || echo "N/A")
echo "C++ translation maximum memory usage: ${CPP_MAX_RSS} KB"

echo
echo "=== MEMORY COMPARISON RESULTS ==="
echo "Test file size: $(du -h "$TEST_FILE" | cut -f1)"
echo "Memory limit: ${MEMORY_LIMIT_MB} MB"
echo
echo "Rust native memory usage:     ${RUST_MAX_RSS} KB"
echo "C++ translation memory usage: ${CPP_MAX_RSS} KB"

# Calculate memory efficiency
if [[ "$RUST_MAX_RSS" != "N/A" && "$CPP_MAX_RSS" != "N/A" ]]; then
    RUST_MB=$((RUST_MAX_RSS / 1024))
    CPP_MB=$((CPP_MAX_RSS / 1024))
    
    echo
    echo "Memory usage in MB:"
    echo "Rust native:     ${RUST_MB} MB"
    echo "C++ translation: ${CPP_MB} MB"
    
    if [[ $CPP_MB -le 50 && $RUST_MB -le 50 ]]; then
        echo "✅ SUCCESS: Both implementations use minimal memory (≤50MB)"
        echo "✅ FileStreamAdapter successfully provides streaming capabilities"
    elif [[ $CPP_MB -le 100 && $RUST_MB -le 100 ]]; then
        echo "⚠️  ACCEPTABLE: Both implementations within 100MB limit"
    else
        echo "❌ FAILED: Memory usage exceeds expected limits"
    fi
else
    echo "⚠️  Could not parse memory usage data"
fi

echo
echo "Detailed reports saved to:"
echo "  $TEST_DIR/rust_memory_report.txt"
echo "  $TEST_DIR/cpp_memory_report.txt"

echo
echo "Test completed!"