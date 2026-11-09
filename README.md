# bazzite-mt7927 / bluefin-mt7927
Bazzite and Bluefin OCI images with MT7927 WiFi and Bluetooth support, rebuilt daily.

The kernel module patches come from [jetm/mediatek-mt7927-dkms](https://github.com/jetm/mediatek-mt7927-dkms) (included as a git submodule). This repo packages them, plus the Bluetooth firmware, into the upstream Bazzite and Bluefin images for multiple variants.

## Status

WiFi and Bluetooth work in these images on every published channel (`stable`, `testing`, `gts`).

Upstream has mostly caught up: the Bluetooth driver (`btmtk`) landed in kernel 7.1, the WiFi driver (`mt7925e`) in 7.2, and `linux-firmware` ships the MT7927 WiFi blobs. Official images on a 7.2+ kernel — currently all main Bazzite and Bluefin variants — have working MT7927 WiFi out of the box.

What still doesn't work in the **official** images (as of 2026-11-09):

- **Bluetooth, everywhere.** `linux-firmware` still doesn't ship `BT_RAM_CODE_MT6639_2_1_hdr.bin`, so no official image can bring up the chip. These images add the firmware.
- **WiFi on Bazzite's NVIDIA LTS (proprietary) variants.** They run a 6.18 LTS kernel with no in-tree MT7927 driver. These images add the out-of-tree driver there; on 7.2+ kernels the in-tree driver is left untouched.

For driver-level detail, see the [upstream driver status](https://github.com/jetm/mediatek-mt7927-dkms#status).

## Is this still maintained?
**Yes — the images rebuild daily, even when this repo shows no recent commits.** This repo is just packaging, so there's little to change here — mostly dependency bumps and submodule updates. You can verify freshness yourself: image tags are dated (`stable.YYYYMMDD`).

These images will keep updating until the official images cover MT7927 on their own — see Status above for what's still missing. When that happens, you'll be given time to switch over.

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
