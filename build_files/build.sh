#!/bin/bash
set -ouex pipefail

CTX="/ctx"
BUILD_DIR="/tmp/mt7927-build"
OUTPUT_DIR="/output"

### Kernel version detection
KVER=$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' | tail -1)
echo "Building MT7927 modules for kernel: ${KVER}"

KVER_BASE=${KVER%%-*}
KVER_MAJOR=${KVER_BASE%%.*}
KVER_REST=${KVER_BASE#*.}
KVER_MINOR=${KVER_REST%%.*}

### Upstream detection guards
# Probe what the base image's in-tree modules already claim, so we never shadow
# a kernel that has caught up with the out-of-tree patches. The two drivers
# reached mainline at different times, so they are guarded independently.
BUILD_WIFI=1
BUILD_BT=1

# Bluetooth: native MT6639 support in 7.1+
if (( KVER_MAJOR > 7 || (KVER_MAJOR == 7 && KVER_MINOR >= 1) )); then
    BUILD_BT=0
else
    BUILD_BT=1
fi

# Wi-Fi: native MT7927 support in 7.2+
if (( KVER_MAJOR > 7 || (KVER_MAJOR == 7 && KVER_MINOR >= 2) )); then
    BUILD_WIFI=0
else
    BUILD_WIFI=1
fi

echo "Kernel: ${KVER}"
echo "BUILD_BT=${BUILD_BT}"
echo "BUILD_WIFI=${BUILD_WIFI}"

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
# _request_firmware() asks the filesystem for the bare name before it tries any
# .zst/.xz at the same path, so a blob staged here shadows whatever
# linux-firmware ships rather than supplementing it. Only fill real gaps.
#
# That distinction matters in both directions. mt7xxx-firmware currently carries
# a *newer* WiFi build than the vendor ZIP does (20260414 against 20250606), so
# staging ours unconditionally pinned WiFi firmware ten months behind on every
# base that already had it. Meanwhile bazzite-deck:stable is still on Fedora 43
# and has no mediatek/mt7927 directory at all, so it genuinely needs ours.
FW_DIR="/usr/lib/firmware/mediatek/mt7927"

stage_firmware() {
    local blob="$1"
    if compgen -G "${FW_DIR}/${blob}*" > /dev/null; then
        echo "Base image already provides ${blob}, skipping."
        return
    fi
    install -Dm644 "${SRCDIR}/firmware/${blob}" "${OUTPUT_DIR}${FW_DIR}/${blob}"
}

# No MT6639 Bluetooth blob exists in linux-firmware at any version yet, so this
# still installs everywhere. The guard is here so it stops on its own the day
# one lands, which is also the signal that these images have nothing left to add.
stage_firmware BT_RAM_CODE_MT6639_2_1_hdr.bin
stage_firmware WIFI_MT6639_PATCH_MCU_2_1_hdr.bin
stage_firmware WIFI_RAM_CODE_MT6639_2_1.bin

### Stage config files
install -Dm644 "${CTX}/config/depmod-mt7927.conf" "${OUTPUT_DIR}/etc/depmod.d/mt7927.conf"
mkdir -p "${OUTPUT_DIR}/etc/modules-load.d"
echo "mt7925e" > "${OUTPUT_DIR}/etc/modules-load.d/mt7925e.conf"

echo "MT7927 driver build complete."
