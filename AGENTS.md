# AGENTS.md

This file provides guidance to LLM agents when working with code in this repository.

## Quick Facts

**IMPORTANT**: Read these key facts before making any suggestions:

1. **BR2_EXTERNAL name**: `BR2_EXTERNAL_PIZERO2W` (defined in external.desc)
   - All defconfig paths use `$(BR2_EXTERNAL_BR2_EXTERNAL_PIZERO2W_PATH)` - note the double naming
2. **Buildroot version**: 2025.02.12 (defconfig is free of legacy symbols; no `BR2_LEGACY` workaround needed)
3. **Kernel**: Linux 6.12.y (Raspberry Pi fork), modules enabled (`CONFIG_MODULES=y`) but only for brcmfmac WiFi driver (loaded at boot by `S34wifi_module`)
4. **Toolchain**: GCC 13.4.0, glibc 2.41 (switched from musl — required by the prebuilt uv binaries; also enables manylinux armv7 wheels and uv-managed Pythons)
5. **Python**: NOT included in the image — uv/uvx installs prebuilt CPython (3.10–3.14, armv7 gnueabihf) at runtime, on demand
6. **Image size**: ~161 MB total, ~128 MB root filesystem
7. **Documentation**: Fully self-documenting with BusyBox man applet and BusyBox verbose help
8. **Root partition**: Auto-expands on first boot via S00resize → reboot → S01resize_fs
9. **Static config files**: All init scripts and config files are in `rootfs_overlay/`, post-build.sh only does dynamic operations (cleanup, permissions, CA certs)
10. **WiFi credentials**: Not included — copy `rootfs_overlay/var/lib/iwd/YourNetwork.psk.example` to `<YourSSID>.psk` and fill in your details before building
11. **Working directory during build**: Always use `cd buildroot` before make commands

## Project Overview

This is a **Buildroot-based embedded Linux system** designed for the **Raspberry Pi Zero 2W**. The configuration creates a minimalist yet developer-friendly distribution with uv-powered Python at runtime, HTTPS support, SQLite, and essential development tools.

**Software Versions:**
- Buildroot: 2025.02.12
- Linux Kernel: Raspberry Pi 6.12.y (LTS)
- Toolchain: GCC 13.4.0, glibc 2.41
- Python: none baked in; managed at runtime by uv
- Documentation: BusyBox man applet, less, comprehensive offline help system

**Key Features:**
- ARM Cortex-A53 optimization with NEON/VFPv4
- Size-optimized build (~161 MB image, ~128 MB root filesystem)
- Fully self-documenting with man pages and built-in help
- Python development via uv at runtime (no interpreter in the image)
- WiFi configurable via iwd PSK file — see `rootfs_overlay/var/lib/iwd/YourNetwork.psk.example`
- HTTPS-enabled tools (git, curl, wget with OpenSSL)
- SSH access via Dropbear
- Auto-expanding root partition on first boot

## Architecture

### Directory Structure

```
rpi-zero-2w-build/
├── buildroot/                     # Upstream Buildroot (2025.02.12)
├── br2-external-pizero2w/         # BR2_EXTERNAL tree (name: BR2_EXTERNAL_PIZERO2W)
│   ├── board/raspberrypizero2w/   # Board-specific files
│   │   ├── config.txt             # Raspberry Pi boot config
│   │   ├── cmdline.txt            # Kernel command line
│   │   ├── kernel-minimal.fragment # Kernel config customization
│   │   ├── busybox-minimal.config # BusyBox configuration (includes CONFIG_MAN=y)
│   │   ├── dropbear-localoptions.h # Dropbear compile-time options (SFTP disabled)
│   │   ├── post-build.sh          # Post-build cleanup (~80 lines)
│   │   ├── post-image.sh          # SD card image generation
│   │   ├── genimage.cfg           # Partition layout definition
│   │   └── rootfs_overlay/        # Files to overlay on root filesystem
│   │       ├── etc/init.d/        # Init scripts
│   │       │   ├── S00runlock     # Create /run/lock structure
│   │       │   ├── S00resize      # Auto-expand partition (first boot, triggers reboot)
│   │       │   ├── S01resize_fs   # Resize filesystem (second boot)
│   │       │   ├── S34wifi_module # Load brcmfmac kernel module
│   │       │   ├── S35wifi_init   # WiFi interface initialization (waits for wlan0)
│   │       │   ├── S40iwd         # WiFi daemon (waits for dbus readiness)
│   │       │   ├── S42ntp         # One-shot NTP time sync after WiFi connects
│   │       │   └── S50crond       # Cron daemon
│   │       ├── etc/inittab        # Init configuration
│   │       ├── etc/fstab          # Filesystem mount table
│   │       ├── etc/hosts          # Hostname resolution
│   │       ├── etc/resolv.conf    # DNS servers (update to match your network)
│   │       ├── etc/iwd/main.conf  # WiFi daemon configuration
│   │       ├── etc/network/interfaces # Network interfaces
│   │       ├── etc/gitconfig      # Git HTTPS configuration
│   │       ├── etc/issue          # Pre-login banner
│   │       ├── var/lib/iwd/YourNetwork.psk.example # WiFi credential template
│   │       └── root/
│   │           ├── .profile       # Shell environment
│   ├── configs/                   # Buildroot defconfig
│   │   └── raspberrypizero2w_minimal_defconfig
│   ├── external.desc              # BR2_EXTERNAL name declaration
│   ├── external.mk                # Includes custom package makefiles
│   └── Config.in                  # Custom package configurations
├── AGENTS.md                      # This file
└── README.md                      # User-facing documentation
```

### Build System

**Buildroot** is the core build system that:
1. Cross-compiles the toolchain (GCC 13.4.0, glibc 2.41)
2. Builds the Linux kernel (Raspberry Pi 6.12.y fork)
3. Builds all userspace packages
4. Creates the root filesystem
5. Generates the bootable SD card image

**BR2_EXTERNAL mechanism** allows custom configurations outside the Buildroot tree:
- `external.desc`: Declares the external tree name (`BR2_EXTERNAL_PIZERO2W`)
- `external.mk`: Includes custom package makefiles (includes all `package/*/*.mk`)
- `Config.in`: Custom package configurations (ready for adding custom packages)

### Key Components

**Kernel:** Custom Linux 6.12.y (Raspberry Pi fork, LTS) with aggressive size optimization
- Base: `bcm2709_defconfig` with custom fragment (`kernel-minimal.fragment`)
- Optimizations: `-Os`, LZ4 compression, dead code elimination, SLUB_TINY
- Disabled: DRM, sound, USB gadget/HID, VT, framebuffer console, debugging, power management
- Enabled: WiFi (brcmfmac built as module, loaded by S34wifi_module), ext4, VFAT, crypto for WPA2, serial console (PL011)
- Modules: `CONFIG_MODULES=y`, but only brcmfmac is built as a module (to avoid firmware loading race condition at boot)

**Init System:** BusyBox init with custom scripts in `/etc/init.d/` (all in rootfs_overlay)
- `S00runlock`: Creates /run/lock directory structure
- `S00resize`: Auto-expands root partition on first boot
- `S01resize_fs`: Completes filesystem resize after reboot
- `S34wifi_module`: Loads brcmfmac kernel module via `modprobe`
- `S35wifi_init`: Initializes WiFi interface with SDIO stabilization
- `S40iwd`: WiFi management daemon with dbus readiness check
- `S42ntp`: One-shot NTP time sync after WiFi connects
- `S50crond`: Cron daemon

**Package Optimization:**
- glibc 2.41 (chosen over musl so the prebuilt armv7 `uv` binaries run and manylinux2014 armv7 wheels work; size compensated by aggressive stripping and locale purge)
- Aggressive compiler flags: `-Os -march=armv8-a+crc -mtune=cortex-a53 -mfpu=neon-vfpv4`, LTO, Graphite, dead code elimination
- LDFLAGS: `--gc-sections`, `--as-needed`, `-O1`
- Binary stripping; locale purge with en_US.UTF-8 generated (C.UTF-8 built in)
- No system Python in the image (uv fetches managed interpreters at runtime); docs, git, SQLite CLI remain
- Shared-only libs (no static archives built; stray .a/.la swept by post-build)
- Development files removed (include, pkgconfig)
- **Documentation PRESERVED** (man pages, doc, info) for fully self-documenting system

## Common Commands

### Building the Image

```bash
# Initial setup (from buildroot directory)
cd buildroot
make BR2_EXTERNAL=../br2-external-pizero2w raspberrypizero2w_minimal_defconfig


# Build everything (use all CPU cores)
make -j$(nproc)

# Build output: buildroot/output/images/sdcard.img
```


### Modifying Configuration

```bash
# Edit Buildroot configuration (packages, toolchain, etc.)
make menuconfig

# Edit kernel configuration
make linux-menuconfig

# Edit BusyBox configuration
make busybox-menuconfig

# Save changes back to defconfig
make savedefconfig BR2_DEFCONFIG=../br2-external-pizero2w/configs/raspberrypizero2w_minimal_defconfig
```

### Rebuilding Specific Components

```bash
# Rebuild kernel after config changes
make linux-rebuild

# Rebuild a specific package
make <package>-rebuild

# Clean a package completely
make <package>-dirclean

# Regenerate filesystem and image
make
```

### Cleaning

```bash
# Clean everything (keeps downloads)
make clean

# Nuclear clean (removes all output)
make distclean

# Clean just the target filesystem
rm -rf output/target output/images
make
```

### Debugging and Analysis

```bash
# List all available defconfigs
make list-defconfigs

# Show package size breakdown
make graph-size

# Show dependency tree
make graph-depends

# Show build order
make show-build-order

# Check specific package info
make <package>-show-info
```

## Development Workflow

### Modifying Board Configuration Files

Files in `br2-external-pizero2w/board/raspberrypizero2w/` are copied during build:
- Edit files directly
- Run `make` to regenerate the image
- No need to run `make clean` for these changes

### Adding rootfs_overlay Files

Files in `rootfs_overlay/` are copied verbatim to the target filesystem:
```bash
# Add a file that will appear on the device
echo "test" > br2-external-pizero2w/board/raspberrypizero2w/rootfs_overlay/root/test.txt
make
```

### Modifying Scripts

**post-build.sh** (br2-external-pizero2w/board/raspberrypizero2w/post-build.sh) runs after root filesystem is assembled but before image creation. It is intentionally minimal (~75 lines) and only performs dynamic operations:
- Removes development files (includes, static libraries, pkgconfig)
- (No Python cleanup needed since system Python was removed)
- **Preserves documentation** (man pages, doc, info) for self-documenting system
- Creates directories (/root/.ssh, /var/lib/iwd, /boot)
- Creates symlink /var/lock → /run/lock
- Sets permissions (chmod 700 for /root and .ssh)
- Updates shadow file timestamp (required for BusyBox login)
- Generates CA certificate bundle (/etc/ssl/certs/ca-certificates.crt)

**Note**: /etc/dropbear is created by the dropbear package as a symlink to /var/run/dropbear.

**Static configuration files** are in `rootfs_overlay/` (not generated by post-build.sh):
- All init scripts (S00runlock, S00resize, S01resize_fs, S34wifi_module, S35wifi_init, S40iwd, S42ntp, S50crond)
- /etc/issue, /etc/gitconfig, /etc/hosts, /etc/resolv.conf
- /root/.profile
- /etc/network/interfaces, /etc/iwd/main.conf
- /var/lib/iwd/YourNetwork.psk.example (WiFi credential template)

**post-image.sh** (br2-external-pizero2w/board/raspberrypizero2w/post-image.sh) runs after images are created:
- Calls genimage to create the SD card image from boot.vfat and rootfs.ext4
- Outputs sdcard.img to buildroot/output/images/

After modifying these scripts, just run `make`.

### Adding Packages

1. **Use existing Buildroot package:**
   - Edit `configs/raspberrypizero2w_minimal_defconfig`
   - Add `BR2_PACKAGE_<NAME>=y`
   - Run `make` to rebuild

2. **Create custom package:**
   - Create `package/<name>/Config.in` and `<name>.mk`
   - Add to `br2-external-pizero2w/Config.in`
   - Add to `br2-external-pizero2w/external.mk`

## Important Constraints

### Size Optimization Philosophy

This build prioritizes **small size** and **fast boot** over features, with one exception:
- Every package increases size and boot time
- Consider if a feature is truly necessary
- Python interpreters and packages are installed at runtime by uv (`uv python install`, `uv pip install`)
- **Documentation is prioritized**: Man pages and comprehensive help are preserved (~8 MB) for excellent UX

### Security Hardening Enabled

Standard compiler/linker hardening is ON (compatibility/robustness over minimal size):
- SSP: `-fstack-protector-strong`
- RELRO: full (plus PIE)
- FORTIFY_SOURCE=2

Still disabled for size: firewall (netfilter/iptables).

### Kernel Modules

`CONFIG_MODULES=y` but only the brcmfmac WiFi driver is built as a module. It is loaded at boot by the `S34wifi_module` init script via `modprobe brcmfmac`. This avoids a firmware loading race condition that occurs when brcmfmac is built-in (the firmware files in `/lib/firmware/brcm/` are not yet accessible when the driver initializes early in boot).

All other drivers are either built-in or absent — you cannot load arbitrary kernel modules at runtime.

### Limited Networking

- **WiFi only** (no Ethernet on Pi Zero 2W)
- **IPv4 only** (IPv6 disabled)
- No netfilter/iptables (firewall disabled)

## Device-Specific Information

### Default Credentials
- **User:** root
- **Password:** changeme (CHANGE THIS!)

### Serial Console Access
- **Pins:** GPIO14 (TX), GPIO15 (RX), GND
- **Baudrate:** 115200
- **Device:** `/dev/ttyAMA0`

### WiFi Configuration

**Pre-configured WiFi**: Configure your network credentials before building by copying the example file:

```bash
cp rootfs_overlay/var/lib/iwd/YourNetwork.psk.example \
   rootfs_overlay/var/lib/iwd/<YourSSID>.psk
```

Edit the `.psk` file to set your:
- **Static IP**: device IP address (e.g. `192.168.1.100`)
- **Gateway**: your router's IP (e.g. `192.168.1.1`)
- **DNS**: your DNS servers (e.g. `192.168.1.1 8.8.8.8`)
- **Auto-connect**: Enabled

Also update `rootfs_overlay/etc/resolv.conf` to match your gateway IP.

> `*.psk` files are excluded from git via `.gitignore` — they will never be committed.

To connect via SSH immediately after first boot:
```bash
ssh root@<YOUR_DEVICE_IP>
```

WiFi is managed by **iwd** (not wpa_supplicant). To connect to a different network:
```bash
# On the device
iwctl
[iwd]# station wlan0 scan
[iwd]# station wlan0 get-networks
[iwd]# station wlan0 connect "NetworkName"
```

Configuration stored in: `/var/lib/iwd/NetworkName.psk`

**To modify WiFi or change to a different network at build time:**
Edit `rootfs_overlay/var/lib/iwd/<SSID>.psk` with [IPv4], [Settings], [Security] sections.

**Documentation available:**
- `man iwctl` - Full manual page
- `iwctl --help` - Quick command reference

### Python Environment (uv)

No Python interpreter is baked into the image. uv/uvx (0.12.22) provides everything at runtime:
- `uv python install 3.14` — downloads prebuilt armv7-unknown-linux-gnueabihf CPython (3.10–3.14 available; needs network)
- `uv venv && uv pip install <pkg>` — virtual environments and fast package installs
- `uvx <tool>` — run CLI tools without installing them
- Prebuilt manylinux2014 armv7 wheels work on this system (glibc 2.41)
- Interpreters land in `~/.local/share/uv/python/`; make sure the root partition has been auto-expanded (happens on first boot) before large installs
- SSL certificates are configured system-wide (/etc/ssl/certs/ca-certificates.crt + SSL_CERT_FILE in .profile)

### Storage Management

- Boot partition: 32MB FAT32 at `/dev/mmcblk0p1`, mounted at `/boot`
  - Contains: kernel (zImage), DTB, firmware (start.elf, fixup.dat), config.txt, cmdline.txt
- Root partition: 128MB ext4 at `/dev/mmcblk0p2` (initial size, auto-expands on first boot)
  - Mounted with: defaults,noatime
- Automatic partition expansion process:
  1. First boot: S00resize uses fdisk to expand partition, creates /var/lib/resize_pending, reboots
  2. Second boot: S01resize_fs runs resize2fs, creates /var/lib/resize_done
- tmpfs filesystems:
  - /tmp (32MB)
  - /run (16MB)
  - /dev/shm (defaults)

## Pre-installed Packages

### Core System
- **Init**: BusyBox init with mdev for dynamic device management
- **C Library**: glibc 2.41 (shared + static)
- **Compression**: zlib, bzip2, xz
- **SSL/TLS**: OpenSSL with engines, CA certificates bundle
- **Terminal**: ncurses library (no additional terminfo)
- **Documentation**: BusyBox man applet (CONFIG_MAN=y), less (pager), comprehensive offline help

### Development Tools
- **Languages**:
  - uv/uvx 0.12.22 (custom BR2_EXTERNAL package: `br2-external-pizero2w/package/uv/`; prebuilt armv7 binaries from astral-sh/uv releases, requires glibc; no system Python — interpreters managed at runtime)
- **Version Control**: git (with HTTPS/curl support)
- **Editors**: vi (BusyBox full-featured implementation)

### Network Tools
- **SSH**: Dropbear (small SSH server/client, size-optimized, reverse DNS disabled; note: OpenSSH scp clients require `-O` flag)
- **WiFi**: iwd (modern WiFi daemon, replaces wpa_supplicant)
  - iwctl tool with readline support for interactive WiFi management
  - Configuration: /etc/iwd/main.conf
  - Auto-connect enabled, IPv6 disabled
  - Wireless regulatory database included
- **HTTP clients**: curl (with OpenSSL), wget (via BusyBox), libcurl
- **Firmware**: Raspberry Pi WiFi firmware (brcmfmac for BCM43430)

### Database
- **SQLite3**: Full-featured with FTS3, unlock notify, secure delete (STAT3 compile flag was removed upstream)

### System Utilities
- **BusyBox**: Comprehensive Unix utilities (custom minimal config with verbose help enabled)
- **util-linux**: findmnt, lsblk, and other utilities
- **e2fsprogs**: resize2fs for auto-expanding root partition
- **Hostname**: pizero2w
- **Default PATH**: /bin:/sbin:/usr/bin:/usr/sbin

### Boot Configuration
- **Bootloader**: Raspberry Pi firmware (start.elf, fixup.dat)
- **Kernel**: zImage (32-bit ARM, LZ4 compressed)
- **DTB**: bcm2710-rpi-zero-2-w.dtb
- **Boot config** (config.txt):
  - GPU memory: 16 MB (minimal)
  - UART enabled for serial console
  - Minimal configuration (no overclocking, boot_delay=2, disable_splash=1)
- **Kernel cmdline**: serial console (115200), ext4 root, fsck auto-repair, rootwait, loglevel=4, brcmfmac feature flags

## Troubleshooting

### Build fails with "No rule to make target"
- Check that `BR2_EXTERNAL` is set correctly
- Verify all paths in defconfig use `$(BR2_EXTERNAL_BR2_EXTERNAL_PIZERO2W_PATH)` (note the double naming)
- The external tree name is `BR2_EXTERNAL_PIZERO2W` (from external.desc)

### Build fails with "legacy configuration"
- The defconfig no longer carries symbols removed from this Buildroot
  (`BR2_PACKAGE_RPI_WIFI_FIRMWARE` → `BR2_PACKAGE_BRCMFMAC_SDIO_FIRMWARE_RPI{,_WIFI}`,
  `BR2_PACKAGE_SQLITE_STAT3` dropped — upstream removed the option)
- If it reappears, a defconfig symbol was renamed/removed upstream: run
  `make menuconfig`, set the modern equivalent, and `make savedefconfig` back

### Device doesn't boot
1. Check serial console for kernel panic messages
2. Verify SD card is flashed correctly: `sudo dd if=output/images/sdcard.img of=/dev/sdX bs=4M status=progress`
3. Try with stock kernel config first (remove `kernel-minimal.fragment`)

### Package build fails
```bash
# View build log
cat output/build/<package>-<version>/.stamp_built

# Clean and retry
make <package>-dirclean
make <package>
```

### Out of space during build
- Buildroot needs ~50GB for a full build
- Use `make clean` to remove build artifacts
- Use ccache to speed up rebuilds (configured by default)

### WiFi firmware not loading
- Check `dmesg | grep brcmfmac`
- Verify `BR2_PACKAGE_BRCMFMAC_SDIO_FIRMWARE_RPI=y` and `BR2_PACKAGE_BRCMFMAC_SDIO_FIRMWARE_RPI_WIFI=y` in defconfig
- Ensure firmware files exist in `/lib/firmware/brcm/`

## Environment and Toolchain Details

### Build Environment
- **ccache**: Enabled with 5GB cache at `~/.buildroot-ccache`
- **Shared/Static libs**: Both enabled (`BR2_SHARED_STATIC_LIBS=y`)
- **Toolchain vendor**: pizero2w
- **Kernel headers**: 6.12
- **C++ support**: Enabled

### Compiler Optimizations
- **Optimization level**: `-Os` (optimize for size)
- **Target flags**: `-march=armv8-a+crc -mtune=cortex-a53 -mfpu=neon-vfpv4 -ffunction-sections -fdata-sections -fno-unwind-tables -fno-asynchronous-unwind-tables`
- **Linker flags**: `-Wl,--gc-sections -Wl,--as-needed -Wl,-O1 -Wl,--hash-style=gnu`
- **GCC features**: LTO enabled, Graphite loop optimizations enabled
- **Security**: SSP, RELRO, FORTIFY_SOURCE all disabled (for size)

### Architecture
- **CPU**: ARM Cortex-A53 (ARMv8-A 64-bit capable, running in 32-bit mode)
- **FPU**: NEON-VFPv4
- **Instruction set**: Thumb-2

## Shell Environment

Pre-configured in /root/.profile:
- **PS1**: Colorized prompt (green user@host, blue directory)
- **EDITOR**: vi
- **SSL**: SSL_CERT_FILE, REQUESTS_CA_BUNDLE
- **Locale**: LANG/LC_ALL=en_US.UTF-8 (generated via BR2_GENERATE_LOCALE; C.UTF-8 also built in)

### Man Pages
Complete manual pages for all installed packages:
```bash
man git                    # Git manual
# uv: no man page shipped — use 'uv --help' or https://docs.astral.sh/uv/
man iwctl                  # WiFi management
man sqlite3                # SQLite manual
man -k <keyword>           # Search man pages
```

### Built-in Help
- **BusyBox commands**: `<command> --help` provides detailed usage (verbose help enabled)
- **Shell built-ins**: `help` lists all built-ins, `help <builtin>` for specific help
- **Programs**: Most programs support `--help` flag

### Login Banners
- **Pre-login** (/etc/issue): Shows documentation notice before login

## References

- User-facing documentation: `README.md`
- Buildroot manual: https://buildroot.org/docs.html
- BR2_EXTERNAL docs: https://buildroot.org/downloads/manual/manual.html#outside-br-custom
