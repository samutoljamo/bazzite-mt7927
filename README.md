# bazzite-mt7927

Bazzite OCI images with MT7927 WiFi and Bluetooth support.

## Status

WiFi and Bluetooth work. See the [upstream driver status](https://github.com/jetm/mediatek-mt7927-dkms#status) for details.

## What this is

The kernel module patches come from [jetm/mediatek-mt7927-dkms](https://github.com/jetm/mediatek-mt7927-dkms) (included as a git submodule). This repo packages them into Bazzite OCI images for multiple variants.

## Available images

All images are published to `ghcr.io/samutoljamo/` with `stable` and `testing` tags.

### Desktop

| Image | Base | Desktop | GPU |
|---|---|---|---|
| `bazzite-mt7927` | bazzite | KDE | AMD/Intel |
| `bazzite-nvidia-open-mt7927` | bazzite-nvidia-open | KDE | NVIDIA (open) |
| `bazzite-nvidia-mt7927` | bazzite-nvidia | KDE | NVIDIA (proprietary) |
| `bazzite-gnome-mt7927` | bazzite-gnome | GNOME | AMD/Intel |
| `bazzite-gnome-nvidia-open-mt7927` | bazzite-gnome-nvidia-open | GNOME | NVIDIA (open) |

### Deck

| Image | Base | Desktop | GPU |
|---|---|---|---|
| `bazzite-deck-mt7927` | bazzite-deck | KDE | AMD/Intel |
| `bazzite-deck-gnome-mt7927` | bazzite-deck-gnome | GNOME | AMD/Intel |
| `bazzite-deck-nvidia-mt7927` | bazzite-deck-nvidia | KDE | NVIDIA |
| `bazzite-deck-nvidia-gnome-mt7927` | bazzite-deck-nvidia-gnome | GNOME | NVIDIA |

## Installation

Pick the image that matches your hardware and desktop preference:

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
