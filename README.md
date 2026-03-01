# bazzite-mt7927

Custom [Bazzite](https://bazzite.gg/) OCI image with patched kernel modules for **MediaTek MT7927 / MT6639** WiFi 7 and Bluetooth support.

These chips ship on boards like the ASUS ROG Crosshair X870E Hero and other recent AM5/LGA1851 motherboards. Mainline Linux does not yet include MT7927/MT6639 support — this image patches the mt76 WiFi driver and btusb Bluetooth driver from a newer kernel source tree and compiles them against the Bazzite base image kernel.

## Hardware supported

| Chip | Function | PCI ID |
|------|----------|--------|
| MT7927 | WiFi 7 (802.11be) | `14c3:7927` |
| MT6639 | Bluetooth 5.4 | (USB, loaded via btusb/btmtk) |
| MT7902 | WiFi 6E (via same mt76 patches) | `14c3:7902` |

## Installation

From an existing Bazzite (or any bootc-compatible) system:

```bash
sudo bootc switch ghcr.io/samutoljamo/bazzite-mt7927:latest
```

Then reboot. The patched modules and firmware will be active on next boot.

## Verification

After rebooting, confirm the patched modules are loaded:

```bash
# WiFi module
lsmod | grep mt79

# Bluetooth module
lsmod | grep btusb

# Check WiFi interface
ip link show | grep wl

# Run the test script (from the submodule)
sudo bash /path/to/test-driver.sh
```

Expected output from `lsmod` should include `mt7925e`, `mt7925_common`, `mt76`, and `btusb`/`btmtk`.

## What this image contains

On top of the standard Bazzite NVIDIA Open image (`ghcr.io/ublue-os/bazzite-nvidia-open:stable`):

- **9 patched kernel modules** in `/usr/lib/modules/<kver>/extra/mt7927/`:
  `mt76.ko.xz`, `mt76-connac-lib.ko.xz`, `mt792x-lib.ko.xz`, `mt7921-common.ko.xz`, `mt7921e.ko.xz`, `mt7925-common.ko.xz`, `mt7925e.ko.xz`, `btusb.ko.xz`, `btmtk.ko.xz`
- **3 firmware blobs** in `/usr/lib/firmware/mediatek/`:
  `mt6639/BT_RAM_CODE_MT6639_2_1_hdr.bin`, `mt7927/WIFI_MT6639_PATCH_MCU_2_1_hdr.bin`, `mt7927/WIFI_RAM_CODE_MT6639_2_1.bin`
- **Config files**: `/etc/modprobe.d/mt7927-override.conf`, `/etc/depmod.d/mt7927.conf`, `/etc/modules-load.d/mt7925e.conf`

## Known issues

- **5 GHz / 6 GHz WPA**: Connection may require multiple retries on WPA3-secured networks in these bands.
- **TX retransmission rates**: Higher than typical; this is a firmware-side behavior.
- **No AP mode**: The MT7927 firmware does not support Access Point mode.
- **Bluetooth coexistence**: Occasional pairing delays when WiFi is under heavy load.

## Building locally

```bash
just build
```

This runs a multi-stage Podman build: the first stage compiles the patched modules (downloading ~130MB kernel tarball, installing gcc/make/kernel-devel), and the second stage copies only the ~2MB of output artifacts into a clean base image.

## Upstream status

MT7927/MT6639 support is being upstreamed to the Linux kernel. Once the patches land in mainline and ship in Fedora's kernel packages, this image will automatically become a no-op (the build script detects existing MT7927 support and skips compilation).

Tracking:
- [mediatek-mt7927-dkms](https://github.com/samutoljamo/mediatek-mt7927-dkms) — patch submodule used by this build
