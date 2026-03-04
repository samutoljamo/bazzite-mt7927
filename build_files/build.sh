#!/bin/bash
# Build patched MediaTek MT7927 (WiFi 7 + Bluetooth) kernel modules.
#
# Downloads mt76 + btusb from a Linux kernel tarball, applies patches from the
# mediatek-mt7927-dkms submodule, compiles against the image's kernel headers,
# and stages output into /output for the multi-stage container build.

set -ouex pipefail

### Configuration ---------------------------------------------------------------

MT76_KVER="6.19.4"
DRIVER_FILENAME="DRV_WiFi_MTK_MT7925_MT7927_TP_W11_64_V5603998_20250709R.zip"
DRIVER_SHA256="b377fffa28208bb1671a0eb219c84c62fba4cd6f92161b74e4b0909476307cc8"

CTX="/ctx"
SUBMODULE_DIR="${CTX}/mediatek-mt7927-dkms"
BUILD_DIR="/tmp/mt7927-build"
OUTPUT_DIR="/output"

### Kernel version detection ----------------------------------------------------

KVER=$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' | tail -1)
echo "Building MT7927 modules for kernel: ${KVER}"

### Upstream detection guard ----------------------------------------------------
# Skip build if the base kernel already ships MT7927 support.

if modinfo -k "${KVER}" -F alias mt7925e 2>/dev/null | grep -q '7927'; then
    echo "MT7927 support already present in kernel ${KVER}, skipping patched build."
    mkdir -p "${OUTPUT_DIR}"
    exit 0
fi

### Install build dependencies --------------------------------------------------

dnf5 install -y --skip-unavailable \
    gcc make "kernel-devel-${KVER}" kernel-headers python3 curl patch xz

### Download and extract kernel source ------------------------------------------

mkdir -p "${BUILD_DIR}"

TARBALL="${BUILD_DIR}/linux-${MT76_KVER}.tar.xz"
curl -L --fail --retry 3 \
    "https://cdn.kernel.org/pub/linux/kernel/v${MT76_KVER%%.*}.x/linux-${MT76_KVER}.tar.xz" \
    -o "${TARBALL}"

mkdir -p "${BUILD_DIR}/mt76"
tar -xf "${TARBALL}" --strip-components=6 -C "${BUILD_DIR}/mt76" \
    "linux-${MT76_KVER}/drivers/net/wireless/mediatek/mt76"

mkdir -p "${BUILD_DIR}/bluetooth"
tar -xf "${TARBALL}" --strip-components=3 -C "${BUILD_DIR}/bluetooth" \
    "linux-${MT76_KVER}/drivers/bluetooth"

rm -f "${TARBALL}"

### Apply patches ---------------------------------------------------------------

patch -d "${BUILD_DIR}/mt76"      -p1 < "${SUBMODULE_DIR}/mt7902-wifi-6.19.patch"
patch -d "${BUILD_DIR}/mt76"      -p1 < "${SUBMODULE_DIR}/mt6639-wifi-init.patch"
patch -d "${BUILD_DIR}/mt76"      -p1 < "${SUBMODULE_DIR}/mt6639-wifi-dma.patch"
patch -d "${BUILD_DIR}/bluetooth" -p3 < "${SUBMODULE_DIR}/mt6639-bt-6.19.patch"

### Kernel compat fixes ---------------------------------------------------------

# Inject airoha_offload.h stub if the kernel headers don't ship it (pre-6.19)
AIROHA_DEST="/usr/src/kernels/${KVER}/include/linux/soc/airoha/airoha_offload.h"
if [[ ! -f "${AIROHA_DEST}" ]]; then
    mkdir -p "$(dirname "${AIROHA_DEST}")"
    cp "${CTX}/compat/airoha_offload.h" "${AIROHA_DEST}"
fi

# Replace kzalloc_flex() with kzalloc(struct_size()) if not defined (pre-6.19)
if ! grep -q 'kzalloc_flex' "/usr/src/kernels/${KVER}/include/linux/slab.h" 2>/dev/null; then
    sed -i \
        's/kzalloc_flex(\*tid, reorder_buf, size)/kzalloc(struct_size(tid, reorder_buf, size), GFP_ATOMIC)/g' \
        "${BUILD_DIR}/mt76/agg-rx.c"
fi

### Install Kbuild files --------------------------------------------------------

cp "${CTX}/kbuild/Kbuild"         "${BUILD_DIR}/mt76/"
cp "${CTX}/kbuild/mt7921/Kbuild"  "${BUILD_DIR}/mt76/mt7921/"
cp "${CTX}/kbuild/mt7925/Kbuild"  "${BUILD_DIR}/mt76/mt7925/"

### Compile ---------------------------------------------------------------------

KSRC="/lib/modules/${KVER}/build"
make -C "${KSRC}" M="${BUILD_DIR}/bluetooth" -j"$(nproc)" modules
make -C "${KSRC}" M="${BUILD_DIR}/mt76"      -j"$(nproc)" modules

### Stage kernel modules --------------------------------------------------------

INSTALL_DIR="${OUTPUT_DIR}/usr/lib/modules/${KVER}/extra/mt7927"
mkdir -p "${INSTALL_DIR}"

install -m644 "${BUILD_DIR}"/bluetooth/{btusb,btmtk}.ko                          "${INSTALL_DIR}/"
install -m644 "${BUILD_DIR}"/mt76/{mt76,mt76-connac-lib,mt792x-lib}.ko           "${INSTALL_DIR}/"
install -m644 "${BUILD_DIR}"/mt76/mt7921/{mt7921-common,mt7921e}.ko              "${INSTALL_DIR}/"
install -m644 "${BUILD_DIR}"/mt76/mt7925/{mt7925-common,mt7925e}.ko              "${INSTALL_DIR}/"
xz --check=crc32 -f "${INSTALL_DIR}"/*.ko

### Download and stage firmware -------------------------------------------------

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
curl -L --fail --retry 3 \
    "https://dlcdnta.asus.com/pub/ASUS/mb/08WIRELESS/${DRIVER_FILENAME}?model=ROG%20CROSSHAIR%20X870E%20HERO&Signature=${SIGNATURE}&Expires=${EXPIRES}&Key-Pair-Id=${KEY_PAIR_ID}" \
    -o "${DRIVER_ZIP}"

echo "${DRIVER_SHA256}  ${DRIVER_ZIP}" | sha256sum -c -

python3 -c "import zipfile, sys; zipfile.ZipFile(sys.argv[1]).extract('mtkwlan.dat', sys.argv[2])" \
    "${DRIVER_ZIP}" "${BUILD_DIR}"
python3 "${SUBMODULE_DIR}/extract_firmware.py" \
    "${BUILD_DIR}/mtkwlan.dat" "${BUILD_DIR}/firmware"

install -Dm644 "${BUILD_DIR}/firmware/BT_RAM_CODE_MT6639_2_1_hdr.bin" \
    "${OUTPUT_DIR}/usr/lib/firmware/mediatek/mt6639/BT_RAM_CODE_MT6639_2_1_hdr.bin"
install -Dm644 "${BUILD_DIR}/firmware/WIFI_MT6639_PATCH_MCU_2_1_hdr.bin" \
    "${OUTPUT_DIR}/usr/lib/firmware/mediatek/mt7927/WIFI_MT6639_PATCH_MCU_2_1_hdr.bin"
install -Dm644 "${BUILD_DIR}/firmware/WIFI_RAM_CODE_MT6639_2_1.bin" \
    "${OUTPUT_DIR}/usr/lib/firmware/mediatek/mt7927/WIFI_RAM_CODE_MT6639_2_1.bin"

### Stage config files ----------------------------------------------------------

install -Dm644 "${CTX}/config/depmod-mt7927.conf"   "${OUTPUT_DIR}/etc/depmod.d/mt7927.conf"
mkdir -p "${OUTPUT_DIR}/etc/modules-load.d"
echo "mt7925e" > "${OUTPUT_DIR}/etc/modules-load.d/mt7925e.conf"

echo "MT7927 driver build complete."
