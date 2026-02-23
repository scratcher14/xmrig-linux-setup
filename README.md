# XMRig Linux Desktop Setup

Optimized XMRig setup script for Linux desktop CPU mining. Supports RandomX (Monero), CryptoNight, and Argon2 algorithms with performance optimizations including huge pages and MSR mod.

## Features

- 🚀 **Performance Optimized** - Huge pages support for 15-20% boost
- ⚙️ **MSR Mod Support** - Additional 5-10% performance for RandomX
- 🔄 **Easy Reconfiguration** - Switch coins/pools without rebuilding
- 🎯 **Multi-Distribution** - Works on Ubuntu, Debian, Fedora, Arch, and more
- 📊 **Systemd Service** - Run as daemon with auto-start on boot
- 💪 **Static Build** - Better performance, fewer dependencies

## Supported Algorithms

**RandomX (CPU-optimized):**
- `rx/0` - Monero (XMR)
- `rx/wow` - Wownero (WOW)
- `rx/arq` - ArQmA (ARQ)
- `rx/keva` - Kevacoin

**CryptoNight:**
- `cn/r` - CryptoNight R
- `cn/half` - CryptoNight Half
- And more...

**Other:**
- `argon2/chukwa` - Argon2

## Requirements

- Linux system (Ubuntu, Debian, Fedora, Arch, etc.)
- At least 2GB RAM (4GB+ recommended for RandomX)
- Root access (for huge pages and MSR mod)
- Build tools (automatically installed by script)

## Quick Start

### 1. Download and Run Setup

```bash
# Download the setup script
wget https://raw.githubusercontent.com/scratcher14/xmrig-linux-setup/main/xmrig-linux-setup.sh && chmod +x xmrig-linux-setup.sh && ./xmrig-linux-setup.sh

# Make it executable
chmod +x xmrig-linux-setup.sh

# Run the setup
./xmrig-linux-setup.sh
```

The script will:
1. Install dependencies
2. Clone and compile XMRig
3. Configure huge pages (optional but recommended)
4. Enable MSR mod (optional, for extra performance)
5. Guide you through pool/wallet configuration
6. Create helper scripts and systemd service

### 2. Start Mining

**Option A: Foreground (manual)**
```bash
cd ~/xmrig/build
./start.sh
```

**Option B: Background with screen**
```bash
screen -dmS xmrig ~/xmrig/build/start.sh
screen -r xmrig  # to view
# Ctrl+A, then D to detach
```

**Option C: System service (runs at boot)**
```bash
sudo cp ~/xmrig/build/xmrig.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable xmrig
sudo systemctl start xmrig
sudo systemctl status xmrig
```

## Configuration

### View Current Configuration

```bash
cd ~/xmrig/build
./info.sh
```

This displays:
- Current algorithm and coin
- Pool settings
- Wallet and worker name
- System stats (CPU, RAM, huge pages)
- Available commands

### Reconfigure Settings

```bash
cd ~/xmrig/build
./reconfigure.sh
```

You can change:
1. Everything (full reconfiguration)
2. Algorithm and/or coin only
3. Pools only (primary and backup)
4. Wallet and/or worker name
5. Thread configuration
6. Manual edit of config.json

No need to rebuild XMRig - just reconfigure and restart!

## Performance Optimization

### Huge Pages (15-20% boost)

The setup script configures this automatically if you choose "yes".

**Manual configuration:**
```bash
# Calculate pages needed (CPU threads * 1280)
sudo sysctl -w vm.nr_hugepages=5120  # for 4-thread CPU

# Make permanent
echo "vm.nr_hugepages=5120" | sudo tee -a /etc/sysctl.conf
```

**Verify huge pages:**
```bash
cat /proc/meminfo | grep Huge
```

### MSR Mod (5-10% boost for RandomX)

The setup script configures this automatically if you choose "yes".

**Manual configuration:**
```bash
# Load MSR module
sudo modprobe msr
echo "msr" | sudo tee -a /etc/modules

# Give xmrig permission
sudo setcap cap_sys_rawio=+ep ~/xmrig/build/xmrig
```

### Thread Optimization

- **Auto (recommended)** - XMRig detects optimal configuration
- **All threads** - Maximum hashrate, may slow system
- **Reduced threads** - Leave 1-2 threads for system tasks

Example: 8-core CPU
- Auto: Let XMRig decide
- 8 threads: Maximum mining
- 6 threads: Balance mining and system responsiveness

## Management Commands

### Using systemd service

```bash
# Start mining
sudo systemctl start xmrig

# Stop mining
sudo systemctl stop xmrig

# Restart (after config changes)
sudo systemctl restart xmrig

# View status
sudo systemctl status xmrig

# View logs
sudo journalctl -u xmrig -f

# Enable auto-start on boot
sudo systemctl enable xmrig

# Disable auto-start
sudo systemctl disable xmrig
```

### Using screen (background)

```bash
# Start in background
screen -dmS xmrig ~/xmrig/build/start.sh

# Attach to view
screen -r xmrig

# Detach (keep running)
# Press: Ctrl+A, then D

# Stop mining
screen -X -S xmrig quit
```

### Manual (foreground)

```bash
# Start
cd ~/xmrig/build
./start.sh

# Stop
# Press: Ctrl+C
```

## File Locations

```
~/xmrig/
├── build/
│   ├── xmrig              # Main binary
│   ├── config.json        # Configuration file
│   ├── start.sh           # Start script
│   ├── info.sh            # Info/stats script
│   ├── reconfigure.sh     # Reconfiguration tool
│   ├── xmrig.service      # Systemd service file
│   └── xmrig-config.txt   # Saved configuration
```

## Troubleshooting

### Low Hashrate

1. **Enable huge pages** - Run `./info.sh` to check status
2. **Enable MSR mod** - Gives 5-10% boost for RandomX
3. **Check thread count** - Use auto or all threads
4. **Verify pool connection** - Check pool dashboard
5. **Let it stabilize** - Wait 5-10 minutes for optimal speed

### Connection Issues

1. **Check pool address** - Verify `address:port` format
2. **Try backup pool** - Reconfigure with `./reconfigure.sh`
3. **Check firewall** - Ensure outbound connections allowed
4. **Test pool ping** - `ping pool.supportxmr.com`

### High CPU Temperature

1. **Reduce threads** - Use `./reconfigure.sh` option 5
2. **Improve cooling** - Check case airflow
3. **Lower CPU frequency** - Use CPU governor settings
4. **Monitor temps** - Install `lm-sensors`: `sensors`

### Systemd Service Won't Start

```bash
# Check service status
sudo systemctl status xmrig

# View logs
sudo journalctl -u xmrig -n 50

# Verify paths in service file
cat /etc/systemd/system/xmrig.service

# Reload daemon
sudo systemctl daemon-reload
```

### Huge Pages Not Working

```bash
# Check current allocation
cat /proc/meminfo | grep Huge

# Free memory first
sudo sync
echo 3 | sudo tee /proc/sys/vm/drop_caches

# Try setting again
sudo sysctl -w vm.nr_hugepages=5120

# Reboot if needed
sudo reboot
```

## Expected Hashrate (RandomX/Monero)

Approximate hashrates for common CPUs:

| CPU | Threads | Hashrate (H/s) | Notes |
|-----|---------|----------------|-------|
| Intel i3-10100 | 8 | 2,000-2,500 | With huge pages |
| Intel i5-12400 | 12 | 4,500-5,500 | With huge pages + MSR |
| Intel i7-12700K | 20 | 8,000-10,000 | With huge pages + MSR |
| AMD Ryzen 5 3600 | 12 | 6,500-7,500 | With huge pages |
| AMD Ryzen 7 5800X | 16 | 11,000-13,000 | With huge pages + MSR |
| AMD Ryzen 9 5950X | 32 | 18,000-21,000 | With huge pages + MSR |

*Actual results vary based on RAM speed, cooling, and optimizations*

## Pool Recommendations

Popular Monero pools:

- **SupportXMR** - `pool.supportxmr.com:3333` (Low fees, reliable)
- **MoneroOcean** - `gulf.moneroocean.stream:10128` (Auto-profit switching)
- **Nanopool** - `xmr-us-east1.nanopool.org:14433` (User-friendly)
- **MineXMR** - `pool.minexmr.com:4444` (Large pool)
- **HashVault** - `pool.hashvault.pro:3333` (EU-based)

Choose a pool geographically close to you for lower latency.

## Security & Privacy

- XMRig has a 1% dev donation (can be modified in config.json)
- Never share your wallet address publicly
- Use worker names to identify rigs, not personally identifiable info
- Keep your system updated
- Monitor for unusual activity
- Consider using a firewall

## Profitability

Before mining, calculate profitability:

**Factors:**
- Electricity cost ($/kWh)
- CPU power consumption (watts)
- Current XMR price
- Your hashrate

**Example calculation:**
- Hashrate: 10,000 H/s
- Power: 150W
- Electricity: $0.12/kWh
- XMR price: $200

Daily earnings: ~$0.30
Daily electricity: ~$0.43
**Net: -$0.13/day (loss)**

Mining is often unprofitable unless you have free/cheap electricity or mine for ideological reasons (supporting network decentralization).

## Support & Contribution

- **Issues**: Report bugs or request features in GitHub Issues
- **XMRig Official**: https://github.com/xmrig/xmrig
- **Monero**: https://www.getmonero.org/
- **Pull Requests**: Contributions welcome!

## Credits

- **XMRig** - https://xmrig.com/
- Script inspired by Darktron's Termux builds
- Community contributions

## License

This setup script is provided as-is under MIT License. XMRig itself is licensed under GPLv3.

---

**⚠️ Disclaimer:** Cryptocurrency mining consumes significant electricity. Ensure you have permission to mine on your hardware and understand the costs involved. This software is provided without warranty. Mine responsibly.
