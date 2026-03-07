#!/bin/bash
set -ouex pipefail

CTX="/ctx"
BUILD_DIR="/tmp/mt7927-build"
OUTPUT_DIR="/output"

### Kernel version detection
KVER=$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' | tail -1)
echo "Building MT7927 modules for kernel: ${KVER}"

### Upstream detection guard
if modinfo -k "${KVER}" -F alias mt7925e 2>/dev/null | grep -q '7927'; then
    echo "MT7927 support already present in kernel ${KVER}, skipping."
    mkdir -p "${OUTPUT_DIR}"
    exit 0
fi

### Install build dependencies
dnf5 install -y --skip-unavailable \
    gcc make "kernel-devel-${KVER}" kernel-headers python3 curl patch xz unzip

### Prepare sources using submodule Makefile
mkdir -p "${BUILD_DIR}"
DKMS="${BUILD_DIR}/dkms"
cp -r "${CTX}/mediatek-mt7927-dkms" "${DKMS}"
make -C "${DKMS}" download
make -C "${DKMS}" sources

SRCDIR="${DKMS}/_build"

### Compile
KSRC="/lib/modules/${KVER}/build"
"${DKMS}/apply-compat.sh" "${KSRC}" "${SRCDIR}/mt76"
make -C "${KSRC}" M="${SRCDIR}/bluetooth" -j"$(nproc)" modules
make -C "${KSRC}" M="${SRCDIR}/mt76"      -j"$(nproc)" modules

### Stage kernel modules
INSTALL_DIR="${OUTPUT_DIR}/usr/lib/modules/${KVER}/extra/mt7927"
mkdir -p "${INSTALL_DIR}"
install -m644 "${SRCDIR}"/bluetooth/{btusb,btmtk}.ko                          "${INSTALL_DIR}/"
install -m644 "${SRCDIR}"/mt76/{mt76,mt76-connac-lib,mt792x-lib}.ko           "${INSTALL_DIR}/"
install -m644 "${SRCDIR}"/mt76/mt7921/{mt7921-common,mt7921e}.ko              "${INSTALL_DIR}/"
install -m644 "${SRCDIR}"/mt76/mt7925/{mt7925-common,mt7925e}.ko              "${INSTALL_DIR}/"
xz --check=crc32 -f "${INSTALL_DIR}"/*.ko

### Stage firmware
install -Dm644 "${SRCDIR}/firmware/BT_RAM_CODE_MT6639_2_1_hdr.bin" \
    "${OUTPUT_DIR}/usr/lib/firmware/mediatek/mt6639/BT_RAM_CODE_MT6639_2_1_hdr.bin"
install -Dm644 "${SRCDIR}/firmware/WIFI_MT6639_PATCH_MCU_2_1_hdr.bin" \
    "${OUTPUT_DIR}/usr/lib/firmware/mediatek/mt7927/WIFI_MT6639_PATCH_MCU_2_1_hdr.bin"
install -Dm644 "${SRCDIR}/firmware/WIFI_RAM_CODE_MT6639_2_1.bin" \
    "${OUTPUT_DIR}/usr/lib/firmware/mediatek/mt7927/WIFI_RAM_CODE_MT6639_2_1.bin"

### Stage config files
install -Dm644 "${CTX}/config/depmod-mt7927.conf" "${OUTPUT_DIR}/etc/depmod.d/mt7927.conf"
mkdir -p "${OUTPUT_DIR}/etc/modules-load.d"
echo "mt7925e" > "${OUTPUT_DIR}/etc/modules-load.d/mt7925e.conf"

echo "MT7927 driver build complete."
