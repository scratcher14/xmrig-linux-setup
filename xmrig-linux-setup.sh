#!/bin/bash

#########################################
# XMRig Setup Script for Linux Desktop
# Optimized for maximum CPU performance
# RandomX and CryptoNight algorithms
#########################################

echo "========================================="
echo "  XMRig Setup for Linux Desktop"
echo "  High-Performance CPU Mining"
echo "========================================="
echo ""
echo "XMRig v6.22.0+ for Linux x64"
echo "Supports: RandomX, CryptoNight, Argon2"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo "⚠️  Warning: Running as root"
    echo "This is OK for setup, but consider running miner as non-root user"
    echo ""
fi

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    echo "Detected OS: $OS"
else
    echo "Cannot detect OS. Proceeding with generic setup..."
    OS="Unknown"
fi

# Step 1: Check and install dependencies
echo ""
echo "[1/7] Checking and installing build dependencies..."
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for required dependencies
MISSING_DEPS=false
echo "Checking for required packages..."

if ! command_exists git; then
    echo "  ✗ git - MISSING"
    MISSING_DEPS=true
else
    echo "  ✓ git - installed"
fi

if ! command_exists cmake; then
    echo "  ✗ cmake - MISSING"
    MISSING_DEPS=true
else
    echo "  ✓ cmake - installed"
fi

if ! command_exists make; then
    echo "  ✗ make - MISSING"
    MISSING_DEPS=true
else
    echo "  ✓ make - installed"
fi

if ! command_exists gcc; then
    echo "  ✗ gcc - MISSING"
    MISSING_DEPS=true
else
    echo "  ✓ gcc - installed"
fi

# Auto-install missing dependencies based on distribution
if [ "$MISSING_DEPS" = true ]; then
    echo ""
    echo "Missing dependencies detected. Installing automatically..."
    echo ""
    
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]] || [[ "$OS" == *"Linux Mint"* ]] || [[ "$OS" == *"Pop!_OS"* ]] || [[ "$OS" == *"Elementary"* ]]; then
        echo "Using apt package manager (Debian/Ubuntu-based)..."
        sudo apt update
        sudo apt install -y git build-essential cmake libuv1-dev libssl-dev libhwloc-dev
        
        # Ask if user wants static libraries for better portability
        echo ""
        read -p "Install static libraries for portable build? (Recommended: y/n): " INSTALL_STATIC
        if [[ "$INSTALL_STATIC" =~ ^[Yy]$ ]]; then
            echo "Installing static libraries..."
            sudo apt install -y libhwloc-dev:native || sudo apt install -y libhwloc-dev
        fi
    elif [[ "$OS" == *"Fedora"* ]] || [[ "$OS" == *"Red Hat"* ]] || [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Rocky"* ]] || [[ "$OS" == *"AlmaLinux"* ]]; then
        echo "Using dnf package manager (Red Hat-based)..."
        sudo dnf install -y git gcc gcc-c++ cmake libuv-devel openssl-devel hwloc-devel
    elif [[ "$OS" == *"Arch"* ]] || [[ "$OS" == *"Manjaro"* ]] || [[ "$OS" == *"EndeavourOS"* ]]; then
        echo "Using pacman package manager (Arch-based)..."
        sudo pacman -S --noconfirm git base-devel cmake libuv openssl hwloc
    else
        echo "⚠️  Unable to auto-detect package manager for: $OS"
        echo ""
        echo "Please install these packages manually:"
        echo ""
        echo "For Ubuntu/Debian/Mint:"
        echo "  sudo apt update"
        echo "  sudo apt install -y git build-essential cmake libuv1-dev libssl-dev libhwloc-dev"
        echo ""
        echo "For Fedora/RHEL/CentOS:"
        echo "  sudo dnf install -y git gcc gcc-c++ cmake libuv-devel openssl-devel hwloc-devel"
        echo ""
        echo "For Arch/Manjaro:"
        echo "  sudo pacman -S --noconfirm git base-devel cmake libuv openssl hwloc"
        echo ""
        read -p "Press Enter after installing dependencies to continue..."
    fi
    
    # Verify dependencies were installed
    echo ""
    echo "Verifying installation..."
    if ! command_exists git || ! command_exists cmake || ! command_exists make || ! command_exists gcc; then
        echo ""
        echo "✗ Some dependencies are still missing. Please install them manually and run this script again."
        exit 1
    fi
    echo "✓ All dependencies installed successfully!"
else
    echo ""
    echo "✓ All required dependencies are already installed!"
fi

# Step 2: Clone XMRig
echo ""
echo "[2/7] Cloning XMRig from official repository..."
cd ~
if [ -d "xmrig" ]; then
    echo "Removing old xmrig directory..."
    rm -rf xmrig
fi

git clone https://github.com/xmrig/xmrig.git
cd xmrig
mkdir build
cd build

# Step 3: Compile with optimizations
echo ""
echo "[3/7] Compiling XMRig with optimizations..."
echo "This will take 5-15 minutes depending on your CPU..."
echo ""

# Try static build first, fall back to dynamic if it fails
echo "Attempting static build..."
cmake .. -DXMRIG_DEPS=scripts/deps -DBUILD_STATIC=ON

if make -j$(nproc); then
    if [ -f "xmrig" ]; then
        echo ""
        echo "✓ Static build successful!"
        BUILD_TYPE="static"
    else
        STATIC_FAILED=true
    fi
else
    STATIC_FAILED=true
fi

if [ "$STATIC_FAILED" = true ]; then
    echo ""
    echo "⚠️  Static build failed (usually due to missing static libraries)"
    echo "Attempting dynamic build instead..."
    echo ""
    
    # Clean build directory
    cd ..
    rm -rf build
    mkdir build
    cd build
    
    # Build dynamically (no static flag)
    cmake ..
    make -j$(nproc)
    
    if [ ! -f "xmrig" ]; then
        echo ""
        echo "✗ Build failed. Check errors above."
        exit 1
    fi
    
    echo ""
    echo "✓ Dynamic build successful!"
    BUILD_TYPE="dynamic"
fi

# Check if build was successful
if [ -f "xmrig" ]; then
    echo ""
    echo "✓ Build successful! ($BUILD_TYPE)"
else
    echo ""
    echo "✗ Build failed. Check errors above."
    exit 1
fi

# Step 4: Configure huge pages (critical for RandomX)
echo ""
echo "[4/7] Configuring system for optimal performance..."
echo ""
echo "========================================="
echo "  Huge Pages Configuration"
echo "========================================="
echo ""

# Get CPU info
CPU_THREADS=$(nproc)
REQUIRED_PAGES=$((CPU_THREADS * 1280))
REQUIRED_MB=$((REQUIRED_PAGES * 2))

echo "System Analysis:"
echo "  CPU Threads: $CPU_THREADS"
echo "  Required huge pages: $REQUIRED_PAGES (${REQUIRED_MB}MB)"
echo "  Performance boost: ~15-20% for RandomX"
echo ""
echo "What are huge pages?"
echo "  Huge pages use 2MB memory blocks instead of standard 4KB."
echo "  This reduces memory overhead and speeds up RandomX mining."
echo "  Your system will allocate ~${REQUIRED_MB}MB for mining."
echo ""
echo "Impact on your system:"
echo "  ✓ Doesn't lock memory away from other apps"
echo "  ✓ Safe for both dedicated and multi-use systems"
echo "  ✓ Can be reverted by editing /etc/sysctl.conf"
echo ""

read -p "Enable huge pages? (y/n): " ENABLE_HUGEPAGES

if [[ "$ENABLE_HUGEPAGES" =~ ^[Yy]$ ]]; then
    echo ""
    echo "Configuring $REQUIRED_PAGES huge pages..."
    
    # Set huge pages temporarily
    sudo sysctl -w vm.nr_hugepages=$REQUIRED_PAGES
    
    # Make permanent
    if ! grep -q "vm.nr_hugepages" /etc/sysctl.conf; then
        echo "vm.nr_hugepages=$REQUIRED_PAGES" | sudo tee -a /etc/sysctl.conf
        echo "✓ Huge pages configured permanently"
    else
        sudo sed -i "s/vm.nr_hugepages=.*/vm.nr_hugepages=$REQUIRED_PAGES/" /etc/sysctl.conf
        echo "✓ Huge pages updated in /etc/sysctl.conf"
    fi
    
    echo "✓ Huge pages enabled: $REQUIRED_PAGES pages"
fi

# Step 5: MSR mod for RandomX (advanced users)
echo ""
echo "========================================="
echo "  MSR Mod Configuration"
echo "========================================="
echo ""
echo "What is MSR mod?"
echo "  MSR (Model-Specific Register) mod optimizes CPU cache"
echo "  settings specifically for RandomX mining."
echo ""
echo "Performance:"
echo "  ✓ Additional 5-10% hashrate boost for RandomX"
echo "  ✓ Works alongside huge pages (not instead of)"
echo ""
echo "Requirements:"
echo "  • Requires root access to modify CPU registers"
echo "  • Only affects mining, not other applications"
echo ""
echo "Recommended for:"
echo "  ✓ Dedicated mining rigs"
echo "  ✓ Part-time miners (generally safe)"
echo ""
read -p "Enable MSR mod? (y/n): " ENABLE_MSR

if [[ "$ENABLE_MSR" =~ ^[Yy]$ ]]; then
    echo ""
    echo "Loading MSR kernel module..."
    sudo modprobe msr
    
    # Make permanent
    if ! grep -q "msr" /etc/modules; then
        echo "msr" | sudo tee -a /etc/modules
        echo "✓ MSR module will load on boot"
    fi
    
    # Set permissions for xmrig to write MSR
    sudo setcap cap_sys_rawio=+ep $(pwd)/xmrig
    
    echo "✓ MSR mod enabled"
    echo "⚠️  Note: XMRig will optimize CPU cache on first run"
fi

# Step 6: Interactive configuration
echo ""
echo "[5/7] Configuring XMRig for your mining setup..."
echo ""
echo "========================================="
echo "  Algorithm Configuration"
echo "========================================="
echo ""
echo "Common RandomX algorithms:"
echo "  • rx/0 - Monero (XMR)"
echo "  • rx/wow - Wownero (WOW)"
echo "  • rx/arq - ArQmA (ARQ)"
echo "  • rx/keva - Kevacoin"
echo ""
echo "Other algorithms:"
echo "  • cn/r - CryptoNight R"
echo "  • cn/half - CryptoNight Half"
echo "  • argon2/chukwa - Argon2"
echo ""
read -p "Enter algorithm (e.g., rx/0 for Monero): " ALGO

echo ""
echo "========================================="
echo "  Coin Configuration (Optional)"
echo "========================================="
echo ""
echo "Specify coin for auto-tuning (optional)"
echo "Examples: monero, wownero, arqma"
echo "Press Enter to skip"
echo ""
read -p "Enter coin name (or press Enter to skip): " COIN
if [ -z "$COIN" ]; then
    COIN="null"
else
    COIN="\"$COIN\""
fi

echo ""
echo "========================================="
echo "  Primary Pool Configuration"
echo "========================================="
echo ""
echo "Enter primary pool address"
echo "Format: pool-address.com:port"
echo "Example: pool.supportxmr.com:3333"
echo ""
read -p "Primary pool address: " PRIMARY_POOL

echo ""
echo "========================================="
echo "  Backup Pool Configuration (Optional)"
echo "========================================="
echo ""
read -p "Do you want to add a backup pool? (y/n): " ADD_BACKUP

if [[ "$ADD_BACKUP" =~ ^[Yy]$ ]]; then
    echo ""
    read -p "Backup pool address: " BACKUP_POOL
    HAS_BACKUP=true
    echo "✓ Backup pool configured: $BACKUP_POOL"
else
    HAS_BACKUP=false
    BACKUP_POOL=""
    echo "✓ No backup pool - using primary only"
fi

echo ""
echo "========================================="
echo "  Wallet Configuration"
echo "========================================="
echo ""
echo "Enter your wallet address for this coin"
echo ""
read -p "Wallet address: " WALLET_ADDRESS

echo ""
echo "Optional: Add fixed difficulty after wallet"
echo "Example: +50000 for fixed difficulty"
echo "Press Enter to skip"
echo ""
read -p "Difficulty (or press Enter to skip): " DIFFICULTY
if [ ! -z "$DIFFICULTY" ]; then
    WALLET_WITH_DIFF="$WALLET_ADDRESS$DIFFICULTY"
else
    WALLET_WITH_DIFF="$WALLET_ADDRESS"
fi

echo ""
echo "========================================="
echo "  Worker/Rig ID Configuration"
echo "========================================="
echo ""
echo "Worker name helps identify this rig"
echo "Examples: desktop-1, ryzen-rig, xmr-miner-01"
echo ""
read -p "Worker/Rig name: " WORKER_NAME

echo ""
echo "========================================="
echo "  Thread Configuration"
echo "========================================="
echo ""
CPU_THREADS=$(nproc)
CPU_MODEL=$(lscpu | grep 'Model name' | cut -d: -f2 | xargs)
echo "CPU Detected: $CPU_MODEL"
echo "Available CPU threads: $CPU_THREADS"
echo ""
echo "Recommended configurations:"
echo "  • Auto (default) - XMRig will test and optimize automatically"
echo "  • All threads ($CPU_THREADS) - Maximum hashrate (100% CPU usage)"
echo "  • Reduced threads (e.g., $(($CPU_THREADS - 2))) - Leaves headroom for other tasks"
echo ""
echo "Auto-detection will likely select: ~$CPU_THREADS threads for mining"
echo ""
echo "For dedicated mining rigs: Use Auto or All threads"
echo "For desktop/laptop (multi-use): Use reduced threads (e.g., $(($CPU_THREADS - 2)))"
echo ""
read -p "Number of threads (press Enter for Auto, or specify number): " THREADS
if [ -z "$THREADS" ]; then
    THREADS_CONFIG="null"
    echo "✓ Auto-detection enabled - XMRig will optimize on first run"
else
    THREADS_CONFIG="$THREADS"
    echo "✓ Using $THREADS threads"
fi

# Step 7: Create config.json
echo ""
echo "[6/7] Creating configuration files..."

cat > config.json << EOF
{
    "api": {
        "id": null,
        "worker-id": "$WORKER_NAME"
    },
    "http": {
        "enabled": false,
        "host": "127.0.0.1",
        "port": 0,
        "access-token": null,
        "restricted": true
    },
    "autosave": true,
    "background": false,
    "colors": true,
    "title": true,
    "randomx": {
        "init": -1,
        "init-avx2": -1,
        "mode": "auto",
        "1gb-pages": false,
        "rdmsr": true,
        "wrmsr": true,
        "cache_qos": false,
        "numa": true,
        "scratchpad_prefetch_mode": 1
    },
    "cpu": {
        "enabled": true,
        "huge-pages": true,
        "huge-pages-jit": false,
        "hw-aes": null,
        "priority": null,
        "memory-pool": false,
        "yield": true,
        "max-threads-hint": 100,
        "asm": true,
        "argon2-impl": null,
        "cn/0": false,
        "cn-lite/0": false
    },
    "opencl": {
        "enabled": false
    },
    "cuda": {
        "enabled": false
    },
    "donate-level": 1,
    "donate-over-proxy": 1,
    "log-file": null,
    "pools": [
        {
            "algo": "$ALGO",
            "coin": $COIN,
            "url": "$PRIMARY_POOL",
            "user": "$WALLET_WITH_DIFF",
            "pass": "$WORKER_NAME",
            "rig-id": "$WORKER_NAME",
            "keepalive": true,
            "enabled": true,
            "tls": false,
            "tls-fingerprint": null,
            "daemon": false,
            "socks5": null,
            "self-select": null,
            "submit-to-origin": false
        }
EOF

if [ "$HAS_BACKUP" = true ]; then
cat >> config.json << EOF
,
        {
            "algo": "$ALGO",
            "coin": $COIN,
            "url": "$BACKUP_POOL",
            "user": "$WALLET_WITH_DIFF",
            "pass": "$WORKER_NAME",
            "rig-id": "$WORKER_NAME",
            "keepalive": true,
            "enabled": true,
            "tls": false,
            "tls-fingerprint": null,
            "daemon": false,
            "socks5": null,
            "self-select": null,
            "submit-to-origin": false
        }
EOF
fi

cat >> config.json << EOF

    ],
    "retries": 5,
    "retry-pause": 5,
    "print-time": 60,
    "health-print-time": 60,
    "dmi": true,
    "syslog": false,
    "tls": {
        "enabled": false
    },
    "user-agent": null,
    "verbose": 0,
    "watch": true,
    "pause-on-battery": false,
    "pause-on-active": false
}
EOF

# Create start script
cat > start.sh << 'EOF'
#!/bin/bash
cd ~/xmrig/build
./xmrig -c config.json
EOF

chmod +x start.sh

# Create systemd service (optional)
cat > xmrig.service << EOF
[Unit]
Description=XMRig Cryptocurrency Miner
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/xmrig/build
ExecStart=$HOME/xmrig/build/xmrig -c $HOME/xmrig/build/config.json
Restart=always
RestartSec=10
Nice=10

[Install]
WantedBy=multi-user.target
EOF

echo ""
echo "[7/7] Creating management scripts..."

# Create reconfigure script (embedded in setup)
cat > reconfigure.sh << 'RECONFIGEOF'
#!/bin/bash

#########################################
# XMRig Reconfiguration Tool
# Update settings without rebuilding
#########################################

echo "========================================="
echo "  XMRig Reconfiguration Tool"
echo "========================================="
echo ""

# Check if we're in the build directory
if [ ! -f "xmrig" ]; then
    echo "Error: xmrig binary not found"
    echo "Please run this script from ~/xmrig/build/"
    exit 1
fi

# Load current config if it exists
if [ -f "xmrig-config.txt" ]; then
    source xmrig-config.txt
    echo "Current configuration loaded"
else
    echo "No previous configuration found"
    echo "Creating new configuration..."
fi

echo ""
echo "What would you like to change?"
echo ""
echo "1) Everything (full reconfiguration)"
echo "2) Algorithm and/or coin only"
echo "3) Pools only (primary and backup)"
echo "4) Wallet and/or worker name only"
echo "5) Thread configuration"
echo "6) Edit config.json manually"
echo ""
read -p "Enter choice (1-6): " RECONFIG_CHOICE

case $RECONFIG_CHOICE in
    6)
        nano config.json
        echo ""
        echo "✓ Configuration edited manually"
        echo ""
        echo "Restart mining for changes to take effect:"
        echo "  • If using systemd: sudo systemctl restart xmrig"
        echo "  • If running manually: Stop (Ctrl+C) and run ./start.sh"
        exit 0
        ;;
esac

# Function to regenerate config.json
regenerate_config() {
    cat > config.json << EOF
{
    "api": {
        "id": null,
        "worker-id": "$WORKER_NAME"
    },
    "http": {
        "enabled": false,
        "host": "127.0.0.1",
        "port": 0,
        "access-token": null,
        "restricted": true
    },
    "autosave": true,
    "background": false,
    "colors": true,
    "title": true,
    "randomx": {
        "init": -1,
        "init-avx2": -1,
        "mode": "auto",
        "1gb-pages": false,
        "rdmsr": true,
        "wrmsr": true,
        "cache_qos": false,
        "numa": true,
        "scratchpad_prefetch_mode": 1
    },
    "cpu": {
        "enabled": true,
        "huge-pages": true,
        "huge-pages-jit": false,
        "hw-aes": null,
        "priority": null,
        "memory-pool": false,
        "yield": true,
        "max-threads-hint": 100,
        "asm": true,
        "argon2-impl": null,
        "cn/0": false,
        "cn-lite/0": false
    },
    "opencl": {
        "enabled": false
    },
    "cuda": {
        "enabled": false
    },
    "donate-level": 1,
    "donate-over-proxy": 1,
    "log-file": null,
    "pools": [
        {
            "algo": "$ALGO",
            "coin": $COIN,
            "url": "$PRIMARY_POOL",
            "user": "$WALLET_WITH_DIFF",
            "pass": "$WORKER_NAME",
            "rig-id": "$WORKER_NAME",
            "keepalive": true,
            "enabled": true,
            "tls": false,
            "tls-fingerprint": null,
            "daemon": false,
            "socks5": null,
            "self-select": null,
            "submit-to-origin": false
        }
EOF

    if [ "$HAS_BACKUP" = true ]; then
cat >> config.json << EOF
,
        {
            "algo": "$ALGO",
            "coin": $COIN,
            "url": "$BACKUP_POOL",
            "user": "$WALLET_WITH_DIFF",
            "pass": "$WORKER_NAME",
            "rig-id": "$WORKER_NAME",
            "keepalive": true,
            "enabled": true,
            "tls": false,
            "tls-fingerprint": null,
            "daemon": false,
            "socks5": null,
            "self-select": null,
            "submit-to-origin": false
        }
EOF
    fi

cat >> config.json << EOF

    ],
    "retries": 5,
    "retry-pause": 5,
    "print-time": 60,
    "health-print-time": 60,
    "dmi": true,
    "syslog": false,
    "tls": {
        "enabled": false
    },
    "user-agent": null,
    "verbose": 0,
    "watch": true,
    "pause-on-battery": false,
    "pause-on-active": false
}
EOF

    # Save configuration
    cat > xmrig-config.txt << EOF
# XMRig configuration
# Updated: $(date)
ALGO="$ALGO"
COIN=$COIN
PRIMARY_POOL="$PRIMARY_POOL"
BACKUP_POOL="$BACKUP_POOL"
WALLET_ADDRESS="$WALLET_ADDRESS"
WALLET_WITH_DIFF="$WALLET_WITH_DIFF"
WORKER_NAME="$WORKER_NAME"
THREADS_CONFIG=$THREADS_CONFIG
HAS_BACKUP=$HAS_BACKUP
EOF
}

# Reconfiguration logic
case $RECONFIG_CHOICE in
    1)
        # Full reconfiguration
        echo ""
        echo "========================================="
        echo "  Full Reconfiguration"
        echo "========================================="
        echo ""
        
        echo "Algorithm Configuration"
        echo "---------------------"
        echo "Current: $ALGO"
        echo ""
        echo "Common algorithms:"
        echo "  • rx/0 - Monero (XMR)"
        echo "  • rx/wow - Wownero (WOW)"
        echo "  • rx/arq - ArQmA (ARQ)"
        echo "  • cn/r - CryptoNight R"
        echo ""
        read -p "New algorithm: " ALGO
        
        echo ""
        read -p "Coin name (or press Enter to skip): " COIN_INPUT
        if [ -z "$COIN_INPUT" ]; then
            COIN="null"
        else
            COIN="\"$COIN_INPUT\""
        fi
        
        echo ""
        echo "Pool Configuration"
        echo "---------------------"
        echo "Current primary: $PRIMARY_POOL"
        echo ""
        read -p "New primary pool (address:port): " PRIMARY_POOL
        
        echo ""
        read -p "Add backup pool? (y/n): " ADD_BACKUP
        if [[ "$ADD_BACKUP" =~ ^[Yy]$ ]]; then
            read -p "Backup pool (address:port): " BACKUP_POOL
            HAS_BACKUP=true
        else
            HAS_BACKUP=false
            BACKUP_POOL=""
        fi
        
        echo ""
        echo "Wallet Configuration"
        echo "---------------------"
        echo "Current: $WALLET_ADDRESS"
        echo ""
        read -p "New wallet address: " WALLET_ADDRESS
        read -p "Difficulty (e.g., +50000 or press Enter): " DIFFICULTY
        if [ ! -z "$DIFFICULTY" ]; then
            WALLET_WITH_DIFF="$WALLET_ADDRESS$DIFFICULTY"
        else
            WALLET_WITH_DIFF="$WALLET_ADDRESS"
        fi
        
        echo ""
        echo "Worker Configuration"
        echo "---------------------"
        echo "Current: $WORKER_NAME"
        echo ""
        read -p "New worker name: " WORKER_NAME
        
        echo ""
        echo "Thread Configuration"
        echo "---------------------"
        CPU_THREADS=$(nproc)
        echo "Current: $THREADS_CONFIG"
        echo "Available threads: $CPU_THREADS"
        echo ""
        read -p "Number of threads (or press Enter for auto): " THREADS
        if [ -z "$THREADS" ]; then
            THREADS_CONFIG="null"
        else
            THREADS_CONFIG="$THREADS"
        fi
        ;;
        
    2)
        # Algorithm/coin only
        echo ""
        echo "========================================="
        echo "  Algorithm & Coin Configuration"
        echo "========================================="
        echo ""
        echo "Current algorithm: $ALGO"
        echo "Current coin: $COIN"
        echo ""
        read -p "New algorithm (or press Enter to keep): " NEW_ALGO
        if [ ! -z "$NEW_ALGO" ]; then
            ALGO=$NEW_ALGO
        fi
        
        echo ""
        read -p "New coin name (or press Enter to skip): " NEW_COIN
        if [ -z "$NEW_COIN" ]; then
            COIN="null"
        else
            COIN="\"$NEW_COIN\""
        fi
        ;;
        
    3)
        # Pools only
        echo ""
        echo "========================================="
        echo "  Pool Configuration"
        echo "========================================="
        echo ""
        echo "Current primary: $PRIMARY_POOL"
        if [ "$HAS_BACKUP" = true ]; then
            echo "Current backup: $BACKUP_POOL"
        fi
        echo ""
        read -p "New primary pool (address:port): " NEW_PRIMARY
        PRIMARY_POOL=$NEW_PRIMARY
        
        echo ""
        read -p "Update backup pool? (y/n): " UPDATE_BACKUP
        if [[ "$UPDATE_BACKUP" =~ ^[Yy]$ ]]; then
            read -p "New backup pool (address:port or blank to remove): " NEW_BACKUP
            if [ -z "$NEW_BACKUP" ]; then
                HAS_BACKUP=false
                BACKUP_POOL=""
                echo "✓ Backup pool removed"
            else
                BACKUP_POOL=$NEW_BACKUP
                HAS_BACKUP=true
                echo "✓ Backup pool updated"
            fi
        fi
        ;;
        
    4)
        # Wallet/worker only
        echo ""
        echo "========================================="
        echo "  Wallet & Worker Configuration"
        echo "========================================="
        echo ""
        echo "Current wallet: $WALLET_ADDRESS"
        echo "Current worker: $WORKER_NAME"
        echo ""
        read -p "New wallet address: " NEW_WALLET
        WALLET_ADDRESS=$NEW_WALLET
        
        echo ""
        read -p "Add difficulty? (e.g., +50000 or press Enter): " NEW_DIFF
        if [ ! -z "$NEW_DIFF" ]; then
            WALLET_WITH_DIFF="$NEW_WALLET$NEW_DIFF"
        else
            WALLET_WITH_DIFF=$NEW_WALLET
        fi
        
        echo ""
        read -p "New worker name: " NEW_WORKER
        WORKER_NAME=$NEW_WORKER
        ;;
        
    5)
        # Thread configuration only
        echo ""
        echo "========================================="
        echo "  Thread Configuration"
        echo "========================================="
        echo ""
        CPU_THREADS=$(nproc)
        echo "Current: $THREADS_CONFIG"
        echo "Available CPU threads: $CPU_THREADS"
        echo ""
        echo "Options:"
        echo "  • Auto - Let XMRig optimize"
        echo "  • All ($CPU_THREADS) - Maximum hashrate"
        echo "  • Reduced (e.g., $(($CPU_THREADS - 2))) - Leave headroom"
        echo ""
        read -p "Number of threads (or press Enter for auto): " NEW_THREADS
        if [ -z "$NEW_THREADS" ]; then
            THREADS_CONFIG="null"
            echo "✓ Auto-detection enabled"
        else
            THREADS_CONFIG="$NEW_THREADS"
            echo "✓ Using $NEW_THREADS threads"
        fi
        ;;
        
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

# Regenerate config.json
echo ""
echo "Regenerating config.json..."
regenerate_config

echo ""
echo "✓ Configuration updated successfully!"
echo ""
echo "New settings:"
echo "  Algorithm: $ALGO"
if [ "$COIN" != "null" ]; then
    echo "  Coin: $COIN"
fi
echo "  Primary Pool: $PRIMARY_POOL"
if [ "$HAS_BACKUP" = true ]; then
    echo "  Backup Pool: $BACKUP_POOL"
fi
echo "  Wallet: $WALLET_ADDRESS"
echo "  Worker: $WORKER_NAME"
echo "  Threads: $THREADS_CONFIG"
echo ""
echo "========================================="
echo "  Apply Changes"
echo "========================================="
echo ""
echo "Restart mining for changes to take effect:"
echo ""
echo "If using systemd:"
echo "  sudo systemctl restart xmrig"
echo ""
echo "If running manually:"
echo "  1. Stop the miner (Ctrl+C)"
echo "  2. Run: ./start.sh"
echo ""
echo "If using screen:"
echo "  screen -X -S xmrig quit"
echo "  screen -dmS xmrig ./start.sh"
echo ""
RECONFIGEOF

chmod +x reconfigure.sh

# Create info script
cat > info.sh << EOF
#!/bin/bash

echo "========================================="
echo "  XMRig Configuration"
echo "========================================="
echo ""
echo "Algorithm: $ALGO"
echo "Coin: $COIN"
echo "Primary Pool: $PRIMARY_POOL"
EOF

if [ "$HAS_BACKUP" = true ]; then
    cat >> info.sh << EOF
echo "Backup Pool: $BACKUP_POOL"
EOF
fi

cat >> info.sh << EOF
echo "Wallet: $WALLET_ADDRESS"
echo "Worker: $WORKER_NAME"
echo "Threads: $THREADS_CONFIG"
echo "Huge Pages: $ENABLE_HUGEPAGES"
echo "MSR Mod: $ENABLE_MSR"
echo ""
echo "========================================="
echo "  Performance Stats"
echo "========================================="
echo ""
echo "CPU: \$(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
echo "Threads: \$(nproc)"
echo "RAM: \$(free -h | grep Mem | awk '{print \$2}')"
echo ""
echo "Huge Pages Status:"
cat /proc/meminfo | grep Huge
echo ""
echo "========================================="
echo "  Commands"
echo "========================================="
echo ""
echo "Start mining (foreground):"
echo "  cd ~/xmrig/build && ./start.sh"
echo ""
echo "Start mining (background with screen):"
echo "  screen -dmS xmrig ~/xmrig/build/start.sh"
echo "  screen -r xmrig  # to view"
echo "  Ctrl+A, then D   # to detach"
echo ""
echo "Install as systemd service:"
echo "  sudo cp ~/xmrig/build/xmrig.service /etc/systemd/system/"
echo "  sudo systemctl daemon-reload"
echo "  sudo systemctl enable xmrig"
echo "  sudo systemctl start xmrig"
echo "  sudo systemctl status xmrig"
echo ""
echo "View logs (if using systemd):"
echo "  sudo journalctl -u xmrig -f"
echo ""
echo "Reconfigure settings:"
echo "  cd ~/xmrig/build && ./reconfigure.sh"
echo ""
echo "Stop mining:"
echo "  Ctrl+C (if foreground)"
echo "  sudo systemctl stop xmrig (if systemd)"
echo "  screen -X -S xmrig quit (if screen)"
echo ""
EOF

chmod +x info.sh

# Save configuration for reconfigure script
cat > xmrig-config.txt << EOF
# XMRig configuration
# Created: $(date)
ALGO="$ALGO"
COIN=$COIN
PRIMARY_POOL="$PRIMARY_POOL"
BACKUP_POOL="$BACKUP_POOL"
WALLET_ADDRESS="$WALLET_ADDRESS"
WALLET_WITH_DIFF="$WALLET_WITH_DIFF"
WORKER_NAME="$WORKER_NAME"
THREADS_CONFIG=$THREADS_CONFIG
HAS_BACKUP=$HAS_BACKUP
EOF

# Final success message
echo ""
echo "========================================="
echo "  ✓ XMRig Setup Complete!"
echo "========================================="
echo ""
echo "Your configuration:"
echo "  Algorithm: $ALGO"
if [ "$COIN" != "null" ]; then
    echo "  Coin: $COIN"
fi
echo "  Primary Pool: $PRIMARY_POOL"
if [ "$HAS_BACKUP" = true ]; then
    echo "  Backup Pool: $BACKUP_POOL"
fi
echo "  Wallet: $WALLET_ADDRESS"
echo "  Worker: $WORKER_NAME"
echo "  Location: ~/xmrig/build/"
echo ""

if [[ "$ENABLE_HUGEPAGES" =~ ^[Yy]$ ]]; then
    echo "✓ Huge pages enabled ($REQUIRED_PAGES pages)"
fi

if [[ "$ENABLE_MSR" =~ ^[Yy]$ ]]; then
    echo "✓ MSR mod enabled"
fi

echo ""
echo "========================================="
echo "  Quick Start"
echo "========================================="
echo ""
echo "Start mining NOW (foreground):"
echo "  cd ~/xmrig/build && ./start.sh"
echo ""
echo "Start mining in background:"
echo "  screen -dmS xmrig ~/xmrig/build/start.sh"
echo "  screen -r xmrig  # to attach and view"
echo ""
echo "Install as system service (runs at boot):"
echo "  sudo cp ~/xmrig/build/xmrig.service /etc/systemd/system/"
echo "  sudo systemctl daemon-reload"
echo "  sudo systemctl enable xmrig"
echo "  sudo systemctl start xmrig"
echo ""
echo "View configuration and stats:"
echo "  cd ~/xmrig/build && ./info.sh"
echo ""
echo "Reconfigure settings:"
echo "  cd ~/xmrig/build && ./reconfigure.sh"
echo ""
echo "========================================="
echo "  Performance Tips"
echo "========================================="
echo ""
echo "• Let miner run 5-10 minutes to stabilize"
echo "• Monitor temps: watch sensors"
echo "• Check hashrate at your pool dashboard"
echo "• Huge pages give ~15-20% boost for RandomX"
echo "• MSR mod gives additional 5-10% for RandomX"
echo "• Reduce threads if system feels sluggish"
echo ""
echo "========================================="
echo "  Ready to mine!"
echo "========================================="
echo ""
