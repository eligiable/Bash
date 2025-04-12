#!/bin/bash

# Exit immediately if any command fails
set -e

# Configuration variables
XMRIG_VERSION="6.21.0"  # Latest stable version
LOG_FILE="/var/log/xmrig_install.log"
INSTALL_DIR="/opt/xmrig"
BUILD_DIR="$INSTALL_DIR/build"

# Function to print section headers
print_header() {
    echo ""
    echo "===================================="
    echo " $1"
    echo "===================================="
    echo ""
}

# Enhanced error handling
error_exit() {
    echo "[ERROR] $1" >&2
    echo "Check $LOG_FILE for details"
    exit 1
}

# Check command success with descriptive error
check_success() {
    if [ $? -ne 0 ]; then
        error_exit "Failed at: $1"
    fi
}

# Initialize logging
setup_logging() {
    touch "$LOG_FILE"
    exec > >(tee -a "$LOG_FILE") 2>&1
    echo "XMRig installation started at $(date)"
    echo "Logging to $LOG_FILE"
}

# Verify system requirements
verify_system() {
    print_header "System Verification"
    
    # Check root privileges
    if [ "$(id -u)" -ne 0 ]; then
        error_exit "This script must be run as root or with sudo"
    fi

    # Check Ubuntu version
    if ! command -v lsb_release >/dev/null; then
        apt-get install -y lsb-release
    fi

    UBUNTU_VERSION=$(lsb_release -rs)
    UBUNTU_NAME=$(lsb_release -cs)
    echo "Detected: Ubuntu $UBUNTU_VERSION ($UBUNTU_NAME)"

    # Version validation
    if [[ "$UBUNTU_VERSION" =~ ^1[4-6]\. ]]; then
        error_exit "Unsupported Ubuntu version (14.04-16.04). Requires Ubuntu 18.04+"
    fi

    # Check available memory
    local MEM_GB=$(free -g | awk '/Mem:/ {print $2}')
    if [ "$MEM_GB" -lt 2 ]; then
        echo "[WARNING] Low memory detected ($MEM_GB GB). XMRig recommends at least 2GB for optimal performance."
    fi
}

# Install dependencies
install_dependencies() {
    print_header "Installing Dependencies"

    # Update package lists
    apt-get update -y
    check_success "apt-get update"

    # Install essential packages
    local DEPS=(
        build-essential
        cmake
        git
        wget
        libuv1-dev
        libssl-dev
        libhwloc-dev
        libmicrohttpd-dev
        pkg-config
        ca-certificates
    )

    apt-get install -y "${DEPS[@]}"
    check_success "Installing core dependencies"

    # Install appropriate GCC version
    if [[ "$UBUNTU_VERSION" =~ ^1[8-9]\. ]]; then
        apt-get install -y gcc-9 g++-9
        update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 90 \
            --slave /usr/bin/g++ g++ /usr/bin/g++-9
    else
        apt-get install -y gcc g++
    fi
}

# Build XMRig from source
build_xmrig() {
    print_header "Building XMRig"

    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    # Clone or update repository
    if [ ! -d "$INSTALL_DIR/xmrig" ]; then
        git clone https://github.com/xmrig/xmrig.git --branch v$XMRIG_VERSION --depth 1
        check_success "Cloning XMRig repository"
    else
        cd xmrig
        git fetch --tags
        git checkout v$XMRIG_VERSION
        cd ..
    fi

    # Prepare build directory
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    # Configure build with optimizations
    local CMAKE_FLAGS=(
        -DCMAKE_BUILD_TYPE=Release
        -DWITH_HWLOC=ON
        -DWITH_OPENCL=OFF
        -DWITH_CUDA=OFF
        -DWITH_TLS=ON
        -DWITH_HTTP=ON
    )

    # Add compiler flags if custom GCC is used
    if command -v gcc-9 >/dev/null; then
        CMAKE_FLAGS+=(
            -DCMAKE_C_COMPILER=gcc-9
            -DCMAKE_CXX_COMPILER=g++-9
        )
    fi

    cmake "${CMAKE_FLAGS[@]}" ../xmrig
    check_success "CMake configuration"

    # Build with maximum available threads
    local THREADS=$(nproc)
    make -j$THREADS
    check_success "Building XMRig"

    # Verify the binary was built
    if [ ! -f xmrig ]; then
        error_exit "Build failed - xmrig binary not found"
    fi
}

# System optimization
optimize_system() {
    print_header "System Optimization"

    # Hugepages configuration
    local CPU_CORES=$(nproc)
    local RECOMMENDED_HUGEPAGES=$((CPU_CORES * 2 + 1))

    echo "CPU Cores: $CPU_CORES"
    echo "Recommended hugepages: $RECOMMENDED_HUGEPAGES"
    echo "Current hugepages: $(grep HugePages_Total /proc/meminfo | awk '{print $2}')"

    read -p "Configure hugepages? (recommended) [Y/n] " -r
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        sysctl -w vm.nr_hugepages=$RECOMMENDED_HUGEPAGES
        echo "vm.nr_hugepages=$RECOMMENDED_HUGEPAGES" >> /etc/sysctl.conf
        check_success "Configuring hugepages"
    fi

    # Disable transparent hugepages if enabled
    if grep -q "\[always\]" /sys/kernel/mm/transparent_hugepage/enabled; then
        echo "Disabling transparent hugepages..."
        echo never > /sys/kernel/mm/transparent_hugepage/enabled
        echo "echo never > /sys/kernel/mm/transparent_hugepage/enabled" >> /etc/rc.local
        chmod +x /etc/rc.local
    fi

    # CPU governor optimization
    if command -v cpupower >/dev/null; then
        echo "Setting CPU performance governor..."
        cpupower frequency-set -g performance
    fi
}

# Create systemd service
create_service() {
    print_header "Creating Systemd Service"

    local SERVICE_FILE="/etc/systemd/system/xmrig.service"

    if [ -f "$SERVICE_FILE" ]; then
        echo "XMRig service already exists at $SERVICE_FILE"
        return
    fi

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=XMRig Miner
After=network.target

[Service]
Type=simple
ExecStart=$BUILD_DIR/xmrig --config=$INSTALL_DIR/config.json
Restart=always
RestartSec=3
User=root
Nice=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    echo "Service created. To enable:"
    echo "  systemctl enable xmrig"
    echo "  systemctl start xmrig"
}

# Installation summary
installation_summary() {
    print_header "Installation Complete"
    echo "XMRig v$XMRIG_VERSION successfully installed to:"
    echo "  Binary: $BUILD_DIR/xmrig"
    echo "  Config: $INSTALL_DIR/config.json"
    echo "  Logs: $LOG_FILE"
    echo ""
    echo "To start mining:"
    echo "1. Edit the config file:"
    echo "   nano $INSTALL_DIR/config.json"
    echo "2. Start manually:"
    echo "   $BUILD_DIR/xmrig"
    echo "3. Or using systemd:"
    echo "   systemctl start xmrig"
    echo ""
    echo "Optimization notes:"
    echo "- Hugepages configured: $RECOMMENDED_HUGEPAGES"
    echo "- CPU governor set to performance"
    echo "- Transparent hugepages disabled"
}

# Main execution
main() {
    setup_logging
    verify_system

    read -p "Continue with XMRig v$XMRIG_VERSION installation? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        exit 0
    fi

    install_dependencies
    build_xmrig
    optimize_system
    create_service
    installation_summary
}

main