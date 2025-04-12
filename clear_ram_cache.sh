#!/bin/bash

# Description: This script clears the system's RAM cache and provides before/after memory statistics
# Requirements: bc (calculator) - will be installed automatically if missing

# Function to check and install bc if needed
install_bc_if_needed() {
    if ! command -v bc &> /dev/null; then
        echo "bc is not installed. Installing it now..."
        if [ -x "$(command -v apt-get)" ]; then
            sudo apt-get install -y bc
        elif [ -x "$(command -v yum)" ]; then
            sudo yum install -y bc
        elif [ -x "$(command -v dnf)" ]; then
            sudo dnf install -y bc
        else
            echo "Error: Package manager not found. Please install bc manually."
            exit 1
        fi
    fi
}

# Function to get memory in MiB
get_memory() {
    local mem_type=$1
    local mem_value=$(grep -E "^${mem_type}:" /proc/meminfo | awk '{print $2}')
    echo "scale=2; $mem_value/1024" | bc
}

# Main script
install_bc_if_needed

echo -e "\n=== RAM Cache Cleaner ==="
echo "This script will clear cached memory and free up your RAM."

# Get initial memory values
freemem_before=$(get_memory "MemFree")
cachedmem_before=$(get_memory "Cached")

echo -e "\nCurrent Memory Status:"
echo " - Free Memory: ${freemem_before} MiB"
echo " - Cached Memory: ${cachedmem_before} MiB"

# Ask for confirmation
read -p "Do you want to clear the RAM cache? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

# Clear caches
echo -e "\nClearing RAM cache..."
sync
echo 3 > /proc/sys/vm/drop_caches

# Get new memory values
freemem_after=$(get_memory "MemFree")
freed_mem=$(echo "$freemem_after - $freemem_before" | bc)

echo -e "\nMemory Status After Clearing:"
echo " - Freed Memory: ${freed_mem} MiB"
echo " - Free Memory Now: ${freemem_after} MiB"
echo -e "\nDone.\n"

exit 0