# bazzite-mt7927

Bazzite OCI images with MT7927 WiFi support.

## Status

WiFi works. Bluetooth does not.

## What this is

The kernel module patches come from [jetm/mediatek-mt7927-dkms](https://github.com/jetm/mediatek-mt7927-dkms) (included as a git submodule). This repo packages them into Bazzite OCI images for multiple variants.

## Available images

All images are published to `ghcr.io/samutoljamo/` with `stable` and `testing` tags.

| Image | Base | Desktop | GPU |
|---|---|---|---|
| `bazzite-mt7927` | bazzite | KDE | AMD/Intel |
| `bazzite-nvidia-open-mt7927` | bazzite-nvidia-open | KDE | NVIDIA (open) |
| `bazzite-nvidia-mt7927` | bazzite-nvidia | KDE | NVIDIA (proprietary) |
| `bazzite-gnome-mt7927` | bazzite-gnome | GNOME | AMD/Intel |
| `bazzite-gnome-nvidia-open-mt7927` | bazzite-gnome-nvidia-open | GNOME | NVIDIA (open) |

## Installation

Pick the image that matches your hardware and desktop preference:

```bash
# KDE + AMD/Intel GPU
sudo bootc switch ghcr.io/samutoljamo/bazzite-mt7927:stable

# KDE + NVIDIA (open drivers)
sudo bootc switch ghcr.io/samutoljamo/bazzite-nvidia-open-mt7927:stable

# KDE + NVIDIA (proprietary drivers)
sudo bootc switch ghcr.io/samutoljamo/bazzite-nvidia-mt7927:stable

# GNOME + AMD/Intel GPU
sudo bootc switch ghcr.io/samutoljamo/bazzite-gnome-mt7927:stable

# GNOME + NVIDIA (open drivers)
sudo bootc switch ghcr.io/samutoljamo/bazzite-gnome-nvidia-open-mt7927:stable
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
