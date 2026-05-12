# Raspberry Pi Zero 2W - Minimal Buildroot Linux

A size-optimized, python-enabled headless Linux distribution for the Raspberry Pi Zero 2W built with Buildroot 2025.02.x

## What This Is

This is a deliberately minimal, headless Linux system built for the Raspberry Pi Zero 2W. The design philosophy is to strip everything down to the bare essentials needed for network-accessible development.

**What has been removed:**
- Display stack: no DRM, no framebuffer, no VT, no console output to screen
- Audio: no sound subsystem
- USB gadget/HID, Bluetooth, NFC
- All virtual/tunnel network interfaces (TUN, VETH, GRE, VXLAN, etc.)
- IPv6, netfilter/iptables, multicast
- Most kernel debugging infrastructure (KALLSYMS, FTRACE, kprobes, etc.)
- All Buildroot packages not needed for WiFi+SSH+Python development

**What remains:**
- **WiFi only** — the only network interface. The brcmfmac driver is built as a kernel module and loaded at boot via `S34wifi_module`.
- **SSH via Dropbear** — the sole way to interact with the device after first boot
- **Static IP** — configured at build time in the iwd PSK file; the device always comes up on a known, predictable address, so `ssh root@<IP>` works immediately after boot
- **Python 3.12** with pip, SSL, and SQLite for development work
- **Serial console** — available on GPIO 14/15 as a fallback for debugging

This system has no display, no keyboard input, no mouse — it is intended to be used entirely over SSH. The serial console (UART) is the only non-network access path and is only needed if WiFi fails to connect.

## Software Versions

- **Buildroot**: 2025.02.12
- **Linux Kernel**: Raspberry Pi 6.12.y (LTS)
- **Toolchain**: GCC 13.4.0, musl libc
- **Python**: 3.12
- **Init**: BusyBox init

---

## Prerequisites

### System Requirements

- **Host OS**: Ubuntu 20.04+ or Debian 11+ (64-bit)
- **Disk Space**: ~50 GB free for build
- **RAM**: 8 GB minimum (16 GB recommended)
- **Internet**: Required for downloading packages

### Install Build Dependencies

```bash
# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install required packages
sudo apt-get install -y \
    build-essential gcc g++ \
    patch gawk git \
    libncurses5-dev \
    python3 python3-pip \
    unzip rsync cpio \
    wget file bc \
    libssl-dev \
    dosfstools mtools \
    bison flex texinfo \
    device-tree-compiler

# Optional: Install ccache for faster rebuilds
sudo apt-get install -y ccache
mkdir -p ~/.buildroot-ccache
```

---

## Getting the Source

### Clone this Repository

```bash
# Clone the configuration repository
git clone https://github.com/yy2h8/pizero2w-buildroot rpi-zero-2w-build
cd rpi-zero-2w-build
```

### Clone and Setup Buildroot

Buildroot must be cloned into the root of the project directory:

```bash
# Clone Buildroot
git clone https://git.buildroot.net/buildroot

# Navigate to buildroot directory
cd buildroot

# Checkout the specific version (2025.02.12)
git checkout 2025.02.12

# Return to project root
cd ..
```

**Important**: The buildroot directory should be at the same level as `br2-external-pizero2w/`.

**Directory structure after cloning:**
```
rpi-zero-2w-build/
├── buildroot/              # ← Cloned Buildroot source
├── br2-external-pizero2w/  # ← Custom configuration
├── AGENTS.md
└── README.md
```

---

## Building

### Quick Start

```bash
# Navigate to buildroot directory
cd buildroot

# Load configuration
make BR2_EXTERNAL=../br2-external-pizero2w raspberrypizero2w_minimal_defconfig

# Remove legacy flag (temporary workaround)
sed -i '/^BR2_LEGACY=/d' .config

# Build (use all CPU cores)
make -j$(nproc)
```

**Build time**: 30-90 minutes depending on CPU

**Output**: `buildroot/output/images/sdcard.img`

### Build Steps Explained

1. **Load defconfig**: Loads the pre-configured Raspberry Pi Zero 2W settings
2. **Remove legacy flag**: Temporary workaround for Buildroot 2025.02 compatibility
3. **Build**: Compiles toolchain, kernel, packages, and generates bootable image

### Clean Builds

```bash
# Clean everything (keeps downloads)
make clean

# Nuclear clean (removes all output including downloads)
make distclean

# Clean specific package
make <package>-dirclean
make <package>-rebuild
```

---

## Flashing to SD Card

### Linux

```bash
# Identify SD card device (be careful!)
lsblk

# Flash image (replace /dev/sdX with your SD card)
sudo dd if=output/images/sdcard.img of=/dev/sdX bs=4M status=progress conv=fsync

# Ensure all data is written
sync
```

### macOS

```bash
# List disks
diskutil list

# Unmount SD card (replace diskN with your disk)
diskutil unmountDisk /dev/diskN

# Flash image
sudo dd if=output/images/sdcard.img of=/dev/rdiskN bs=4m

# Eject
diskutil eject /dev/diskN
```

---

## First Boot

### Boot Sequence

1. **Insert SD card** into Raspberry Pi Zero 2W
2. **Power on** the device
3. **Wait for auto-resize**: Device will automatically expand root partition and reboot (~30 seconds)
4. **Second boot**: Filesystem resize completes, WiFi module loads, iwd connects, NTP syncs
5. **System ready**: SSH is available at the static IP you configured

### Default Credentials

- **Username**: `root`
- **Password**: `changeme`

⚠️ **IMPORTANT**: Change the default password immediately after first login!

```bash
# Change root password
passwd
```

---

## Connecting to Device

### Serial Console (Recommended for First Setup)

**Hardware connections:**
- Pin 6 (GND) → USB-to-Serial GND
- Pin 8 (GPIO14/TXD) → USB-to-Serial RXD
- Pin 10 (GPIO15/RXD) → USB-to-Serial TXD

**Connect from host:**

```bash
# Using screen
screen /dev/ttyUSB0 115200

# Using minicom
minicom -D /dev/ttyUSB0 -b 115200

# Exit screen: Ctrl+A then K
```

### WiFi Configuration

WiFi is managed by **iwd** and configured via a PSK file in the rootfs overlay.

**Before building**, create your network credentials file:

```bash
# Copy the example file, naming it after your WiFi SSID
cp br2-external-pizero2w/board/raspberrypizero2w/rootfs_overlay/var/lib/iwd/YourNetwork.psk.example \
   br2-external-pizero2w/board/raspberrypizero2w/rootfs_overlay/var/lib/iwd/<YourSSID>.psk
```

Then edit `<YourSSID>.psk` and fill in:
- `Address` — the static IP you want to assign to the device (e.g. `192.168.1.100`)
- `Gateway` — your router's IP address (e.g. `192.168.1.1`)
- `DNS` — your DNS servers (e.g. `192.168.1.1 8.8.8.8`)
- `Passphrase` — your WiFi password

Also update `rootfs_overlay/etc/resolv.conf` to match your gateway IP.

> The `.psk` file is excluded from git via `.gitignore` — it will never be accidentally committed.

After powering on the device, SSH to it at whatever static IP you configured:
```bash
ssh root@<YOUR_DEVICE_IP>
```

**Note for file transfers**: When using `scp` from your computer to transfer files,
add the `-O` flag for Dropbear compatibility (e.g., `scp -O file.txt root@<YOUR_DEVICE_IP>:/root/`).

**Comprehensive WiFi help** is available on the device:
```bash
man iwctl              # Full manual page
iwctl --help           # Quick command reference
```

### SSH Access

Once WiFi is configured and the device has booted, SSH is available immediately:

```bash
# From your computer (use the static IP you configured in the .psk file)
ssh root@<YOUR_DEVICE_IP>

# First login will show RSA fingerprint, type 'yes'
```

---

## Customization

### Modifying Configuration

```bash
cd buildroot

# Edit Buildroot packages and settings
make menuconfig

# Edit kernel configuration
make linux-menuconfig

# Edit BusyBox configuration
make busybox-menuconfig

# Save changes to defconfig
make savedefconfig BR2_DEFCONFIG=../br2-external-pizero2w/configs/raspberrypizero2w_minimal_defconfig
```

### Adding Packages

**Option 1: Use existing Buildroot package**

1. Run `make menuconfig`
2. Navigate to package category
3. Select package with space bar
4. Save and exit
5. Rebuild: `make`

**Option 2: Edit defconfig directly**

```bash
# Edit the defconfig
vim br2-external-pizero2w/configs/raspberrypizero2w_minimal_defconfig

# Add line like:
# BR2_PACKAGE_<NAME>=y

# Reload and build
make BR2_EXTERNAL=../br2-external-pizero2w raspberrypizero2w_minimal_defconfig
sed -i '/^BR2_LEGACY=/d' .config
make
```

### Modifying Root Filesystem

**Add files via rootfs_overlay:**

```bash
# Files here are copied verbatim to the device
echo "test content" > br2-external-pizero2w/board/raspberrypizero2w/rootfs_overlay/root/myfile.txt

# Rebuild
make
```

**Modify post-build script:**

```bash
# Edit the script
vim br2-external-pizero2w/board/raspberrypizero2w/post-build.sh

# This script runs after filesystem is assembled
# Use it to:
# - Remove unwanted files
# - Create directories
# - Generate configuration files
# - Set permissions
```

---

## Common Issues

### Build fails: "legacy configuration"

**Solution**: Remove the BR2_LEGACY flag
```bash
sed -i '/^BR2_LEGACY=/d' .config
make
```

### Out of space during build

- Free up ~50 GB disk space
- Use `make clean` to remove build artifacts
- Downloads are cached in `buildroot/dl/` (~5-10 GB)

---

## Pre-installed Software

### Languages
- Python 3.12 (with pip, SSL, SQLite, zlib, bzip2, curses, readline)

### Development Tools
- git (with HTTPS support)
- vi (BusyBox full-featured)
- SQLite3 CLI with full-text search support

### Network Tools
- curl (with OpenSSL)
- wget
- dropbear (SSH server/client, size-optimized)
- iwd + iwctl (WiFi daemon and management tool)

### Documentation System
- **BusyBox man applet** - Manual page viewer (CONFIG_MAN=y in BusyBox)
- **less** - Pager for viewing documentation
- **All man pages preserved** - For all installed packages
- **BusyBox verbose help** - Detailed `--help` for all commands

### System Utilities
- BusyBox (comprehensive Unix utilities with verbose help)
- util-linux tools (findmnt, lsblk, etc.)
- Standard init scripts

---

## Security Notes

⚠️ **This build is optimized for size, NOT security**

**Disabled security features:**
- Stack smashing protection (SSP)
- RELRO (relocation read-only)
- FORTIFY_SOURCE

**Recommendations:**
- Change default password immediately
- Use for development/prototyping only
- For production, re-enable security features in defconfig

**No firewall** - netfilter/iptables are disabled for size.

---

## Project Structure

```
rpi-zero-2w-build/
├── buildroot/                     # Buildroot source (2025.02.12)
├── br2-external-pizero2w/         # Custom configuration
│   ├── board/raspberrypizero2w/   # Board-specific files
│   │   ├── config.txt             # Boot configuration
│   │   ├── cmdline.txt            # Kernel command line
│   │   ├── kernel-minimal.fragment # Kernel customization
│   │   ├── busybox-minimal.config # BusyBox config
│   │   ├── dropbear-localoptions.h # Dropbear compile-time options (SFTP disabled)
│   │   ├── post-build.sh          # Post-build cleanup (~80 lines)
│   │   ├── post-image.sh          # Image generation script
│   │   ├── genimage.cfg           # Partition layout
│   │   └── rootfs_overlay/        # Static config files
│   │       ├── etc/init.d/
│   │       │   ├── S00runlock     # Create /run/lock structure
│   │       │   ├── S00resize      # Auto-expand partition (first boot, triggers reboot)
│   │       │   ├── S01resize_fs   # Resize filesystem (second boot)
│   │       │   ├── S34wifi_module # Load brcmfmac kernel module
│   │       │   ├── S35wifi_init   # Wait for wlan0 and bring it up
│   │       │   ├── S40iwd         # WiFi daemon (waits for dbus readiness)
│   │       │   ├── S42ntp         # One-shot NTP time sync after WiFi connects
│   │       │   └── S50crond       # Cron daemon
│   │       ├── etc/hosts          # Hostname resolution
│   │       ├── etc/resolv.conf    # DNS servers (update to match your network)
│   │       └── var/lib/iwd/       # WiFi credentials directory
│   ├── configs/
│   │   └── raspberrypizero2w_minimal_defconfig
│   ├── Config.in                   # Custom package configurations
│   └── external.mk                 # Custom package makefiles
├── AGENTS.md                       # AI assistant guidance
└── README.md                       # This file
```

---

## Backup and Recovery

### Backup SD Card

```bash
# Backup entire SD card
sudo dd if=/dev/sdX of=backup-$(date +%Y%m%d).img bs=4M status=progress

# Compress backup
gzip backup-*.img
```

### Restore from Backup

```bash
# Decompress if needed
gunzip backup-*.img.gz

# Restore
sudo dd if=backup-*.img of=/dev/sdX bs=4M status=progress conv=fsync
sync
```
