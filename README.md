# bazzite-mt7927 / bluefin-mt7927
Bazzite and Bluefin OCI images with MT7927 WiFi and Bluetooth support. Updated daily.

## Status

WiFi and Bluetooth both work in these images, on every channel.

Mainline caught up in two stages: the Bluetooth driver (`btmtk`) landed in kernel 7.1, the WiFi driver (`mt7925e`) in 7.2. Firmware did not follow. `linux-firmware` ships the MT7927 WiFi blobs, but contains no Bluetooth blob at all.

What that means for the **official** images (kernel versions as of 2026-08-20):

| Official image | Kernel | WiFi | Bluetooth |
|---|---|---|---|
| `bazzite:testing` | 7.2.0 | works, in-tree driver | no firmware |
| `bazzite:stable` | 7.1.5 | no driver | no firmware |
| `bluefin:stable`, `bluefin:gts` | 7.1.4 | no driver | no firmware |

Official Bazzite `testing` already has working MT7927 WiFi. Bluetooth works on no official image, and will not until `linux-firmware` ships `BT_RAM_CODE_MT6639_2_1_hdr.bin` — the driver has been there since 7.1, but it cannot bring up the chip without that blob.

These images fill both gaps: the out-of-tree WiFi driver wherever the kernel is still 7.1, and the Bluetooth firmware everywhere.

For driver-level detail, see the [upstream driver status](https://github.com/jetm/mediatek-mt7927-dkms#status).

## Is this still maintained?
**Yes — the images update daily, even when this repo shows no recent commits.** This repo is just packaging: it takes the upstream Bazzite/Bluefin images and adds the out-of-tree MT7927 driver. Commits are rare because there's little to change here — mostly dependency bumps and [jetm/mediatek-mt7927-dkms](https://github.com/jetm/mediatek-mt7927-dkms) submodule updates when new releases come.

You can verify freshness yourself: image tags are dated (`stable.YYYYMMDD`) and rebuild daily. These images will keep updating until the official images cover MT7927 on their own. That needs `linux-firmware` to ship the Bluetooth blob, not just the kernel drivers that have already landed. When it happens, you'll be given time to switch over.

## What this is

The kernel module patches come from [jetm/mediatek-mt7927-dkms](https://github.com/jetm/mediatek-mt7927-dkms) (included as a git submodule). This repo packages them into Bazzite and Bluefin OCI images for multiple variants.

## Available images

All images are published to `ghcr.io/samutoljamo/`.

### Bazzite

Available with `stable` and `testing` tags.

#### Desktop

| Image | Base | Desktop | GPU |
|---|---|---|---|
| `bazzite-mt7927` | bazzite | KDE | AMD/Intel |
| `bazzite-nvidia-open-mt7927` | bazzite-nvidia-open | KDE | NVIDIA (open) |
| `bazzite-nvidia-mt7927` | bazzite-nvidia | KDE | NVIDIA (proprietary) |
| `bazzite-gnome-mt7927` | bazzite-gnome | GNOME | AMD/Intel |
| `bazzite-gnome-nvidia-open-mt7927` | bazzite-gnome-nvidia-open | GNOME | NVIDIA (open) |

#### Dev

Only `stable` tag is published upstream for these.

| Image | Base | Desktop | GPU |
|---|---|---|---|
| `bazzite-dx-mt7927` | bazzite-dx | KDE + Dev | AMD/Intel |
| `bazzite-dx-nvidia-mt7927` | bazzite-dx-nvidia | KDE + Dev | NVIDIA (proprietary) |
| `bazzite-dx-gnome-mt7927` | bazzite-dx-gnome | GNOME + Dev | AMD/Intel |

#### Deck

| Image | Base | Desktop | GPU |
|---|---|---|---|
| `bazzite-deck-mt7927` | bazzite-deck | KDE | AMD/Intel |
| `bazzite-deck-gnome-mt7927` | bazzite-deck-gnome | GNOME | AMD/Intel |
| `bazzite-deck-nvidia-mt7927` | bazzite-deck-nvidia | KDE | NVIDIA |
| `bazzite-deck-nvidia-gnome-mt7927` | bazzite-deck-nvidia-gnome | GNOME | NVIDIA |

### Bluefin

Available with `stable` and `gts` tags.

| Image | Base | Desktop | GPU |
|---|---|---|---|
| `bluefin-mt7927` | bluefin | GNOME | AMD/Intel |
| `bluefin-nvidia-mt7927` | bluefin-nvidia | GNOME | NVIDIA (proprietary) |
| `bluefin-nvidia-open-mt7927` | bluefin-nvidia-open | GNOME | NVIDIA (open) |
| `bluefin-dx-mt7927` | bluefin-dx | GNOME + Dev | AMD/Intel |
| `bluefin-dx-nvidia-mt7927` | bluefin-dx-nvidia | GNOME + Dev | NVIDIA (proprietary) |
| `bluefin-dx-nvidia-open-mt7927` | bluefin-dx-nvidia-open | GNOME + Dev | NVIDIA (open) |

## Installation

Pick the image that matches your hardware and desktop preference.

### Bazzite

```bash
# Desktop - KDE + AMD/Intel GPU
sudo bootc switch ghcr.io/samutoljamo/bazzite-mt7927:stable

# Desktop - KDE + NVIDIA (open drivers)
sudo bootc switch ghcr.io/samutoljamo/bazzite-nvidia-open-mt7927:stable

# Desktop - KDE + NVIDIA (proprietary drivers)
sudo bootc switch ghcr.io/samutoljamo/bazzite-nvidia-mt7927:stable

# Desktop - GNOME + AMD/Intel GPU
sudo bootc switch ghcr.io/samutoljamo/bazzite-gnome-mt7927:stable

# Desktop - GNOME + NVIDIA (open drivers)
sudo bootc switch ghcr.io/samutoljamo/bazzite-gnome-nvidia-open-mt7927:stable

# Dev - KDE + AMD/Intel
sudo bootc switch ghcr.io/samutoljamo/bazzite-dx-mt7927:stable

# Dev - KDE + NVIDIA (proprietary drivers)
sudo bootc switch ghcr.io/samutoljamo/bazzite-dx-nvidia-mt7927:stable

# Dev - GNOME + AMD/Intel
sudo bootc switch ghcr.io/samutoljamo/bazzite-dx-gnome-mt7927:stable

# Deck - KDE + AMD/Intel
sudo bootc switch ghcr.io/samutoljamo/bazzite-deck-mt7927:stable

# Deck - GNOME + AMD/Intel
sudo bootc switch ghcr.io/samutoljamo/bazzite-deck-gnome-mt7927:stable

# Deck - KDE + NVIDIA
sudo bootc switch ghcr.io/samutoljamo/bazzite-deck-nvidia-mt7927:stable

# Deck - GNOME + NVIDIA
sudo bootc switch ghcr.io/samutoljamo/bazzite-deck-nvidia-gnome-mt7927:stable
```

Replace `:stable` with `:testing` if you want the testing channel.

### Bluefin

```bash
# GNOME + AMD/Intel GPU
sudo bootc switch ghcr.io/samutoljamo/bluefin-mt7927:stable

# GNOME + NVIDIA (proprietary drivers)
sudo bootc switch ghcr.io/samutoljamo/bluefin-nvidia-mt7927:stable

# GNOME + NVIDIA (open drivers)
sudo bootc switch ghcr.io/samutoljamo/bluefin-nvidia-open-mt7927:stable

# GNOME + Dev + AMD/Intel GPU
sudo bootc switch ghcr.io/samutoljamo/bluefin-dx-mt7927:stable

# GNOME + Dev + NVIDIA (proprietary drivers)
sudo bootc switch ghcr.io/samutoljamo/bluefin-dx-nvidia-mt7927:stable

# GNOME + Dev + NVIDIA (open drivers)
sudo bootc switch ghcr.io/samutoljamo/bluefin-dx-nvidia-open-mt7927:stable
```

Replace `:stable` with `:gts` for the GTS channel.

Reboot after switching.

## Building / Testing locally

```bash
# Build the default variant (bazzite-nvidia-open)
just build

# Build a specific variant
just build bazzite-gnome-mt7927 latest ghcr.io/ublue-os/bazzite-gnome:stable

# Test the built image
just test
just test bazzite-gnome-mt7927 latest
```
