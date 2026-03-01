#!/bin/bash
# Build and install MediaTek MT7927 (WiFi 7 + Bluetooth) kernel modules.
#
# Sources mt76 + btusb from the Linux 6.19.4 kernel tarball, applies patches
# from the bundled mediatek-mt7927-dkms submodule, compiles against the
# kernel headers present in the image, and installs the resulting .ko files
# plus firmware blobs extracted from the ASUS CDN driver ZIP.
#
# Compat fix applied for kernel < 6.19:
#   kzalloc_flex() (introduced in 6.19) is replaced with kzalloc(struct_size())
#   in agg-rx.c before compilation.

set -ouex pipefail

### --------------------------------------------------------------------------
### Configuration
### --------------------------------------------------------------------------

# Linux kernel version the mt76 source and patches target
MT76_KVER="6.19.4"

# ASUS driver ZIP (contains mtkwlan.dat with firmware blobs).
# If the CDN token API breaks, replace this with a direct URL or pre-cached copy.
DRIVER_FILENAME="DRV_WiFi_MTK_MT7925_MT7927_TP_W11_64_V5603998_20250709R.zip"
DRIVER_SHA256="b377fffa28208bb1671a0eb219c84c62fba4cd6f92161b74e4b0909476307cc8"

SUBMODULE_DIR="/ctx/mediatek-mt7927-dkms"
BUILD_DIR="/tmp/mt7927-build"

### --------------------------------------------------------------------------
### Kernel version detection
### --------------------------------------------------------------------------

KVER=$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' | tail -1)
echo "Building MT7927 modules for kernel: ${KVER}"

### --------------------------------------------------------------------------
### Install build-time dependencies
### --------------------------------------------------------------------------

dnf5 install -y --skip-unavailable \
    gcc \
    make \
    "kernel-devel-${KVER}" \
    kernel-headers \
    python3 \
    curl \
    libarchive \
    patch \
    xz

### --------------------------------------------------------------------------
### Download and extract kernel source (mt76 + btusb subtrees only)
### --------------------------------------------------------------------------

mkdir -p "${BUILD_DIR}"

TARBALL="${BUILD_DIR}/linux-${MT76_KVER}.tar.xz"
echo "Downloading Linux ${MT76_KVER} kernel tarball..."
curl -L --fail --retry 3 \
    "https://cdn.kernel.org/pub/linux/kernel/v${MT76_KVER%%.*}.x/linux-${MT76_KVER}.tar.xz" \
    -o "${TARBALL}"

echo "Extracting mt76 WiFi source..."
mkdir -p "${BUILD_DIR}/mt76"
tar -xf "${TARBALL}" \
    --strip-components=6 \
    -C "${BUILD_DIR}/mt76" \
    "linux-${MT76_KVER}/drivers/net/wireless/mediatek/mt76"

echo "Extracting bluetooth source..."
mkdir -p "${BUILD_DIR}/bluetooth"
tar -xf "${TARBALL}" \
    --strip-components=3 \
    -C "${BUILD_DIR}/bluetooth" \
    "linux-${MT76_KVER}/drivers/bluetooth"

rm -f "${TARBALL}"

### --------------------------------------------------------------------------
### Apply patches from the submodule
### --------------------------------------------------------------------------

echo "Applying MT7902 WiFi patch..."
patch -d "${BUILD_DIR}/mt76" -p1 < "${SUBMODULE_DIR}/mt7902-wifi-6.19.patch"

echo "Applying MT6639 WiFi init patch..."
patch -d "${BUILD_DIR}/mt76" -p1 < "${SUBMODULE_DIR}/mt6639-wifi-init.patch"

echo "Applying MT6639 WiFi DMA patch..."
patch -d "${BUILD_DIR}/mt76" -p1 < "${SUBMODULE_DIR}/mt6639-wifi-dma.patch"

echo "Applying MT6639 Bluetooth patch..."
patch -d "${BUILD_DIR}/bluetooth" -p1 < "${SUBMODULE_DIR}/mt6639-bt-6.19.patch"

### --------------------------------------------------------------------------
### Kernel compat fixes (6.19 source on 6.17 headers)
### --------------------------------------------------------------------------

# kzalloc_flex() was introduced in kernel 6.19; replace with the equivalent
# kzalloc(struct_size()) call that works on 6.17 and earlier.
RUNNING_KVER_MAJOR=$(echo "${KVER}" | cut -d. -f1)
RUNNING_KVER_MINOR=$(echo "${KVER}" | cut -d. -f2)

if [[ "${RUNNING_KVER_MAJOR}" -lt 6 ]] || \
   { [[ "${RUNNING_KVER_MAJOR}" -eq 6 ]] && [[ "${RUNNING_KVER_MINOR}" -lt 19 ]]; }; then
    echo "Applying kzalloc_flex compat fix for kernel ${KVER}..."
    sed -i \
        's/kzalloc_flex(\*tid, reorder_buf, size)/kzalloc(struct_size(tid, reorder_buf, size), GFP_ATOMIC)/g' \
        "${BUILD_DIR}/mt76/agg-rx.c"
fi

### --------------------------------------------------------------------------
### Create Kbuild files for out-of-tree build
### --------------------------------------------------------------------------

cat > "${BUILD_DIR}/mt76/Kbuild" <<'EOF'
obj-m += mt76.o
obj-m += mt76-connac-lib.o
obj-m += mt792x-lib.o
obj-m += mt7921/
obj-m += mt7925/

mt76-y := \
	mmio.o util.o trace.o dma.o mac80211.o debugfs.o eeprom.o \
	tx.o agg-rx.o mcu.o wed.o scan.o channel.o pci.o

mt76-connac-lib-y := mt76_connac_mcu.o mt76_connac_mac.o mt76_connac3_mac.o

mt792x-lib-y := mt792x_core.o mt792x_mac.o mt792x_trace.o \
		mt792x_debugfs.o mt792x_dma.o mt792x_acpi_sar.o

CFLAGS_trace.o := -I$(src)
CFLAGS_mt792x_trace.o := -I$(src)
EOF

cat > "${BUILD_DIR}/mt76/mt7921/Kbuild" <<'EOF'
obj-m += mt7921-common.o
obj-m += mt7921e.o

mt7921-common-y := mac.o mcu.o main.o init.o debugfs.o
mt7921e-y := pci.o pci_mac.o pci_mcu.o
EOF

cat > "${BUILD_DIR}/mt76/mt7925/Kbuild" <<'EOF'
obj-m += mt7925-common.o
obj-m += mt7925e.o

mt7925-common-y := mac.o mcu.o regd.o main.o init.o debugfs.o
mt7925e-y := pci.o pci_mac.o pci_mcu.o
EOF

### --------------------------------------------------------------------------
### Compile modules
### --------------------------------------------------------------------------

KSRC="/lib/modules/${KVER}/build"

echo "Compiling Bluetooth modules..."
make -C "${KSRC}" M="${BUILD_DIR}/bluetooth" modules

echo "Compiling WiFi modules..."
make -C "${KSRC}" M="${BUILD_DIR}/mt76" modules

### --------------------------------------------------------------------------
### Install .ko files
### --------------------------------------------------------------------------

INSTALL_DIR="/usr/lib/modules/${KVER}/extra/mt7927"
mkdir -p "${INSTALL_DIR}"

echo "Installing kernel modules to ${INSTALL_DIR}..."

# Bluetooth
install -m644 "${BUILD_DIR}/bluetooth/btusb.ko"  "${INSTALL_DIR}/"
install -m644 "${BUILD_DIR}/bluetooth/btmtk.ko"  "${INSTALL_DIR}/"

# WiFi core
install -m644 "${BUILD_DIR}/mt76/mt76.ko"                   "${INSTALL_DIR}/"
install -m644 "${BUILD_DIR}/mt76/mt76-connac-lib.ko"        "${INSTALL_DIR}/"
install -m644 "${BUILD_DIR}/mt76/mt792x-lib.ko"             "${INSTALL_DIR}/"

# MT7921 (MT7902 support)
install -m644 "${BUILD_DIR}/mt76/mt7921/mt7921-common.ko"   "${INSTALL_DIR}/"
install -m644 "${BUILD_DIR}/mt76/mt7921/mt7921e.ko"         "${INSTALL_DIR}/"

# MT7925 / MT7927
install -m644 "${BUILD_DIR}/mt76/mt7925/mt7925-common.ko"   "${INSTALL_DIR}/"
install -m644 "${BUILD_DIR}/mt76/mt7925/mt7925e.ko"         "${INSTALL_DIR}/"

# Compress all installed modules
xz -f "${INSTALL_DIR}"/*.ko

### --------------------------------------------------------------------------
### Download ASUS driver ZIP and extract firmware
### --------------------------------------------------------------------------

echo "Fetching ASUS CDN download token..."
TOKEN_URL="https://cdnta.asus.com/api/v1/TokenHQ?filePath=https:%2F%2Fdlcdnta.asus.com%2Fpub%2FASUS%2Fmb%2F08WIRELESS%2F${DRIVER_FILENAME}%3Fmodel%3DROG%2520CROSSHAIR%2520X870E%2520HERO&systemCode=rog"

JSON=$(curl -sf "${TOKEN_URL}" -X POST -H 'Origin: https://rog.asus.com')
if [[ -z "${JSON}" ]]; then
    echo "ERROR: Failed to retrieve ASUS CDN token" >&2
    exit 1
fi

EXPIRES=${JSON#*\"expires\":\"}; EXPIRES=${EXPIRES%%\"*}
SIGNATURE=${JSON#*\"signature\":\"}; SIGNATURE=${SIGNATURE%%\"*}
KEY_PAIR_ID=${JSON#*\"keyPairId\":\"}; KEY_PAIR_ID=${KEY_PAIR_ID%%\"*}

DRIVER_ZIP="${BUILD_DIR}/${DRIVER_FILENAME}"
DOWNLOAD_URL="https://dlcdnta.asus.com/pub/ASUS/mb/08WIRELESS/${DRIVER_FILENAME}?model=ROG%20CROSSHAIR%20X870E%20HERO&Signature=${SIGNATURE}&Expires=${EXPIRES}&Key-Pair-Id=${KEY_PAIR_ID}"

echo "Downloading ASUS driver ZIP..."
curl -L --fail --retry 3 "${DOWNLOAD_URL}" -o "${DRIVER_ZIP}"

echo "Verifying driver ZIP checksum..."
echo "${DRIVER_SHA256}  ${DRIVER_ZIP}" | sha256sum -c -

echo "Extracting mtkwlan.dat from ZIP..."
bsdtar -xf "${DRIVER_ZIP}" -C "${BUILD_DIR}" mtkwlan.dat

echo "Extracting firmware blobs..."
python3 "${SUBMODULE_DIR}/extract_firmware.py" \
    "${BUILD_DIR}/mtkwlan.dat" \
    "${BUILD_DIR}/firmware"

### --------------------------------------------------------------------------
### Install firmware blobs
### --------------------------------------------------------------------------

echo "Installing firmware..."

install -Dm644 \
    "${BUILD_DIR}/firmware/BT_RAM_CODE_MT6639_2_1_hdr.bin" \
    "/usr/lib/firmware/mediatek/mt6639/BT_RAM_CODE_MT6639_2_1_hdr.bin"

install -Dm644 \
    "${BUILD_DIR}/firmware/WIFI_MT6639_PATCH_MCU_2_1_hdr.bin" \
    "/usr/lib/firmware/mediatek/mt7927/WIFI_MT6639_PATCH_MCU_2_1_hdr.bin"

install -Dm644 \
    "${BUILD_DIR}/firmware/WIFI_RAM_CODE_MT6639_2_1.bin" \
    "/usr/lib/firmware/mediatek/mt7927/WIFI_RAM_CODE_MT6639_2_1.bin"

### --------------------------------------------------------------------------
### Update module dependency map and rebuild initramfs
### --------------------------------------------------------------------------

echo "Running depmod..."
depmod -a "${KVER}"

echo "Rebuilding initramfs..."
dracut --force --kver "${KVER}"

### --------------------------------------------------------------------------
### Auto-load configuration
### --------------------------------------------------------------------------

echo "mt7925e" > /etc/modules-load.d/mt7925e.conf

### --------------------------------------------------------------------------
### Cleanup
### --------------------------------------------------------------------------

echo "Cleaning up build artifacts..."
rm -rf "${BUILD_DIR}"

dnf5 remove -y \
    "kernel-devel-${KVER}" \
    kernel-headers \
    libarchive \
    patch || true   # non-fatal: some may be pulled in by other image deps

echo "MT7927 driver build complete."
