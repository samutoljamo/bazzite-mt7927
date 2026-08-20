#!/bin/bash
set -ouex pipefail

CTX="/ctx"
BUILD_DIR="/tmp/mt7927-build"
OUTPUT_DIR="/output"

### Kernel version detection
KVER=$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' | tail -1)
echo "Building MT7927 modules for kernel: ${KVER}"

### Upstream detection guards
# Probe what the base image's in-tree modules already claim, so we never shadow
# a kernel that has caught up with the out-of-tree patches. The two drivers
# reached mainline at different times, so they are guarded independently.
BUILD_WIFI=1
BUILD_BT=1

if modinfo -k "${KVER}" -F alias mt7925e 2>/dev/null | grep -q '7927'; then
    echo "MT7927 WiFi support already present in kernel ${KVER}, skipping WiFi modules."
    BUILD_WIFI=0
fi

# Native MT6639 Bluetooth landed in kernel 7.1. Those btmtk builds declare the
# MT6639 firmware via MODULE_FIRMWARE; earlier ones know nothing about the chip.
if modinfo -k "${KVER}" -F firmware btmtk 2>/dev/null | grep -q 'MT6639'; then
    echo "MT6639 Bluetooth support already present in kernel ${KVER}, skipping Bluetooth modules."
    BUILD_BT=0
fi

### Install build dependencies
dnf5 install -y --skip-unavailable \
    gcc make "kernel-devel-${KVER}" kernel-headers python3 curl patch xz unzip

### Prepare sources using submodule Makefile
# Always run, even when both module builds are skipped: the firmware blobs are
# extracted from the vendor driver ZIP by the same `sources` target.
mkdir -p "${BUILD_DIR}"
DKMS="${BUILD_DIR}/dkms"
cp -r "${CTX}/mediatek-mt7927-dkms" "${DKMS}"
make -C "${DKMS}" download
make -C "${DKMS}" sources

SRCDIR="${DKMS}/_build"

### Compile
KSRC="/lib/modules/${KVER}/build"
if [[ "${BUILD_BT}" -eq 1 ]]; then
    make -C "${KSRC}" M="${SRCDIR}/bluetooth" -j"$(nproc)" modules
fi
if [[ "${BUILD_WIFI}" -eq 1 ]]; then
    make -C "${KSRC}" M="${SRCDIR}/mt76" -j"$(nproc)" modules
fi

### Stage kernel modules
if [[ "${BUILD_BT}" -eq 1 || "${BUILD_WIFI}" -eq 1 ]]; then
    INSTALL_DIR="${OUTPUT_DIR}/usr/lib/modules/${KVER}/extra/mt7927"
    mkdir -p "${INSTALL_DIR}"

    if [[ "${BUILD_BT}" -eq 1 ]]; then
        install -m644 "${SRCDIR}"/bluetooth/{btusb,btmtk}.ko                      "${INSTALL_DIR}/"
    fi
    if [[ "${BUILD_WIFI}" -eq 1 ]]; then
        install -m644 "${SRCDIR}"/mt76/{mt76,mt76-connac-lib,mt792x-lib}.ko       "${INSTALL_DIR}/"
        install -m644 "${SRCDIR}"/mt76/mt7921/{mt7921-common,mt7921e}.ko          "${INSTALL_DIR}/"
        install -m644 "${SRCDIR}"/mt76/mt7925/{mt7925-common,mt7925e}.ko          "${INSTALL_DIR}/"
    fi

    xz --check=crc32 -f "${INSTALL_DIR}"/*.ko
fi

### Stage firmware
# Staged unconditionally: none of these blobs ship in linux-firmware in the form
# the driver needs. mt7xxx-firmware carries older WiFi blobs at the same paths,
# which the firmware loader only falls back to when the uncompressed ones below
# are absent, and it carries no MT6639 Bluetooth blob at all.
install -Dm644 "${SRCDIR}/firmware/BT_RAM_CODE_MT6639_2_1_hdr.bin" \
    "${OUTPUT_DIR}/usr/lib/firmware/mediatek/mt7927/BT_RAM_CODE_MT6639_2_1_hdr.bin"
install -Dm644 "${SRCDIR}/firmware/WIFI_MT6639_PATCH_MCU_2_1_hdr.bin" \
    "${OUTPUT_DIR}/usr/lib/firmware/mediatek/mt7927/WIFI_MT6639_PATCH_MCU_2_1_hdr.bin"
install -Dm644 "${SRCDIR}/firmware/WIFI_RAM_CODE_MT6639_2_1.bin" \
    "${OUTPUT_DIR}/usr/lib/firmware/mediatek/mt7927/WIFI_RAM_CODE_MT6639_2_1.bin"

### Stage config files
install -Dm644 "${CTX}/config/depmod-mt7927.conf" "${OUTPUT_DIR}/etc/depmod.d/mt7927.conf"
mkdir -p "${OUTPUT_DIR}/etc/modules-load.d"
echo "mt7925e" > "${OUTPUT_DIR}/etc/modules-load.d/mt7925e.conf"

echo "MT7927 driver build complete."
