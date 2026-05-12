#!/bin/bash
set -e

BOARD_DIR="$(dirname $0)"
GENIMAGE_CFG="${BOARD_DIR}/genimage.cfg"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"

# Clean up
rm -rf "${GENIMAGE_TMP}"

# Generate the image
genimage \
    --rootpath "${TARGET_DIR}" \
    --tmppath "${GENIMAGE_TMP}" \
    --inputpath "${BINARIES_DIR}" \
    --outputpath "${BINARIES_DIR}" \
    --config "${GENIMAGE_CFG}"

echo "SD card image created: ${BINARIES_DIR}/sdcard.img"
echo "To flash: sudo dd if=${BINARIES_DIR}/sdcard.img of=/dev/sdX bs=4M status=progress"
