#!/bin/bash
#
# Post-build script for Raspberry Pi Zero 2W
#
# This script performs dynamic operations that cannot be done via rootfs_overlay:
# - Removing development files from packages
# - Creating symlinks
# - Setting permissions
# - Generating CA certificate bundle
# - Updating shadow file with current date
#
# Static configuration files are in rootfs_overlay/
#
set -e

BOARD_DIR="$(dirname $0)"
TARGET_DIR="${TARGET_DIR}"

echo "=== Post-build script starting ==="

# Remove development files (keep documentation for self-documenting OS)
echo "Removing development files..."
rm -rf ${TARGET_DIR}/usr/include
rm -rf ${TARGET_DIR}/usr/lib/pkgconfig
find ${TARGET_DIR}/lib -name "*.a" -delete 2>/dev/null || true
find ${TARGET_DIR}/usr/lib -name "*.a" -delete 2>/dev/null || true
find ${TARGET_DIR} -name "*.la" -delete 2>/dev/null || true
echo "Preserving documentation (man pages, doc, info)..."

# Remove Python test files and __pycache__ to save space
echo "Cleaning Python cache and test files..."
find ${TARGET_DIR}/usr/lib/python* -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find ${TARGET_DIR}/usr/lib/python* -type d -name "test" -exec rm -rf {} + 2>/dev/null || true
find ${TARGET_DIR}/usr/lib/python* -type d -name "tests" -exec rm -rf {} + 2>/dev/null || true
find ${TARGET_DIR}/usr/lib/python* -name "*.pyc" -delete 2>/dev/null || true

# Create directories that may not exist
echo "Creating required directories..."
mkdir -p ${TARGET_DIR}/root/.ssh
mkdir -p ${TARGET_DIR}/var/lib/iwd
mkdir -p ${TARGET_DIR}/root/.pip
mkdir -p ${TARGET_DIR}/boot
# Note: /etc/dropbear is created by dropbear package as symlink to /var/run/dropbear

# Create symlink from /var/lock to /run/lock (standard practice)
rm -rf ${TARGET_DIR}/var/lock
mkdir -p ${TARGET_DIR}/run/lock
ln -sf /run/lock ${TARGET_DIR}/var/lock
mkdir -p ${TARGET_DIR}/run/lock/subsys

# Set permissions
echo "Setting permissions..."
chmod 700 ${TARGET_DIR}/root
chmod 700 ${TARGET_DIR}/root/.ssh

# Fix shadow file - set lastchanged field to current days since epoch
# Busybox login requires this field to be set, otherwise it rejects the password
echo "Updating shadow file timestamp..."
DAYS_SINCE_EPOCH=$(( $(date +%s) / 86400 ))
sed -i "s/^root:\([^:]*\)::/root:\1:${DAYS_SINCE_EPOCH}:/" ${TARGET_DIR}/etc/shadow

# Configure CA certificates for HTTPS
# This must be done dynamically based on what certificates are installed
echo "Generating CA certificate bundle..."
mkdir -p ${TARGET_DIR}/etc/ssl/certs
if [ -d ${TARGET_DIR}/usr/share/ca-certificates ]; then
    cd ${TARGET_DIR}/usr/share/ca-certificates
    find . -name "*.crt" | while read cert; do
        ln -sf /usr/share/ca-certificates/$cert ${TARGET_DIR}/etc/ssl/certs/
    done
    # Create ca-certificates.crt bundle
    cat ${TARGET_DIR}/usr/share/ca-certificates/*/*.crt > ${TARGET_DIR}/etc/ssl/certs/ca-certificates.crt
fi

# WiFi firmware location
# brcmfmac is built as a module and loaded by S34wifi_module after rootfs mounts
# Firmware files are in /lib/firmware/brcm/ and will be available when module loads
echo "WiFi firmware in /lib/firmware/brcm (module loads after rootfs mount)"

echo "=== Post-build script completed successfully ==="
