# Parameterize the base image so CI matrix / local builds can select any bazzite variant.
# Default keeps backward compatibility with the original single-image build.
ARG BASE_IMAGE=ghcr.io/ublue-os/bazzite-nvidia-open:stable

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Stage 1: Build patched MT7927 kernel modules
FROM ${BASE_IMAGE} AS builder

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    /ctx/build.sh

# Stage 2: Install only the compiled artifacts into a clean base
FROM ${BASE_IMAGE}

COPY --from=builder /output/ /

RUN depmod -a "$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' | tail -1)"

RUN bootc container lint
