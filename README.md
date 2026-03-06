# bazzite-mt7927 / bluefin-mt7927
Bazzite and Bluefin OCI images with MT7927 WiFi and Bluetooth support. Updated daily.

## Status

WiFi and Bluetooth work. See the [upstream driver status](https://github.com/jetm/mediatek-mt7927-dkms#status) for details.

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
