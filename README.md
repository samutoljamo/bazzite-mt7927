# bazzite-mt7927 / bluefin-mt7927
Bazzite and Bluefin OCI images with MT7927 WiFi and Bluetooth support. Updated daily.

## Status

WiFi and Bluetooth work in these images on every published channel (`stable`, `testing`, `gts`).

Mainline caught up in two stages: the Bluetooth driver (`btmtk`) landed in kernel 7.1, the WiFi driver (`mt7925e`) in 7.2. Firmware did not follow: `linux-firmware` ships the MT7927 WiFi blobs, but no Bluetooth blob.

What that means for the **official** images (kernel versions as of 2026-08-20):

| Official image | Kernel | WiFi | Bluetooth |
|---|---|---|---|
| `bazzite:testing` | 7.2.0 | works, in-tree driver | no firmware |
| `bazzite:stable` | 7.1.5 | no driver | no firmware |
| `bluefin:stable`, `bluefin:gts` | 7.1.4 | no driver | no firmware |

Bluetooth works on no official image until `linux-firmware` ships `BT_RAM_CODE_MT6639_2_1_hdr.bin`.

These images fill both gaps: the out-of-tree WiFi driver wherever the kernel is still 7.1, and the Bluetooth firmware everywhere.

For driver-level detail, see the [upstream driver status](https://github.com/jetm/mediatek-mt7927-dkms#status).

## Is this still maintained?
**Yes — the images rebuild daily, even when this repo shows no recent commits.** This repo is just packaging: it takes the upstream Bazzite/Bluefin images and adds the out-of-tree MT7927 driver and Bluetooth firmware, so there's little to change here — mostly dependency bumps and [jetm/mediatek-mt7927-dkms](https://github.com/jetm/mediatek-mt7927-dkms) submodule updates. You can verify freshness yourself: image tags are dated (`stable.YYYYMMDD`).

These images will keep updating until the official images cover MT7927 on their own. That needs `linux-firmware` to ship the Bluetooth blob, not just the kernel drivers that have already landed. When it happens, you'll be given time to switch over.

## What this is

The kernel module patches come from [jetm/mediatek-mt7927-dkms](https://github.com/jetm/mediatek-mt7927-dkms) (included as a git submodule). This repo packages them into Bazzite and Bluefin OCI images for multiple variants.

## Available images

All images are published to `ghcr.io/samutoljamo/`.

### Bazzite

Available with `stable` and `testing` tags (Dev images: `stable` only).

#### Desktop

| Image | Base | Desktop | GPU |
|---|---|---|---|
| `bazzite-mt7927` | bazzite | KDE | AMD/Intel |
| `bazzite-nvidia-open-mt7927` | bazzite-nvidia-open | KDE | NVIDIA (open) |
| `bazzite-nvidia-mt7927` | bazzite-nvidia | KDE | NVIDIA (proprietary) |
| `bazzite-gnome-mt7927` | bazzite-gnome | GNOME | AMD/Intel |
| `bazzite-gnome-nvidia-open-mt7927` | bazzite-gnome-nvidia-open | GNOME | NVIDIA (open) |

#### Dev

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
| `bluefin-nvidia-open-mt7927` | bluefin-nvidia-open | GNOME | NVIDIA (open) |
| `bluefin-dx-mt7927` | bluefin-dx | GNOME + Dev | AMD/Intel |
| `bluefin-dx-nvidia-open-mt7927` | bluefin-dx-nvidia-open | GNOME + Dev | NVIDIA (open) |

The proprietary `bluefin-nvidia` and `bluefin-dx-nvidia` variants were dropped in April 2026 because upstream froze them on kernel 6.16. If you switched to `bluefin-nvidia-mt7927` or `bluefin-dx-nvidia-mt7927` before then, your image no longer receives updates — switch to the corresponding `-nvidia-open` variant (requires a Turing or newer NVIDIA GPU).

## Installation

Pick an image from the tables above, then switch to it. For example:

```bash
# Bazzite - KDE + AMD/Intel GPU
sudo bootc switch ghcr.io/samutoljamo/bazzite-mt7927:stable

# Bluefin - GNOME + AMD/Intel GPU
sudo bootc switch ghcr.io/samutoljamo/bluefin-mt7927:stable
```

Swap in any image name from the tables. Use `:testing` instead of `:stable` for the Bazzite testing channel (not available for Dev images), or `:gts` for Bluefin GTS.

Reboot after switching.

## Verifying images

All images are signed with cosign. Verify with the [public key](cosign.pub) in this repo:

```bash
cosign verify --key https://raw.githubusercontent.com/samutoljamo/bazzite-mt7927/main/cosign.pub \
  ghcr.io/samutoljamo/bazzite-mt7927:stable
```

## Building / Testing locally

```bash
# Build the default: bazzite-mt7927:latest from the bazzite-nvidia-open:stable base
# (not the same as the published bazzite-mt7927, which uses the plain bazzite base)
just build

# Build a specific variant: just build <image-name> <tag> <base-image>
just build bazzite-gnome-mt7927 latest ghcr.io/ublue-os/bazzite-gnome:stable

# Test the built image
just test
just test bazzite-gnome-mt7927 latest
```
