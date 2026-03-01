# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Stage 1: Build patched MT7927 kernel modules
FROM ghcr.io/ublue-os/bazzite-nvidia-open:stable AS builder

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    /ctx/build.sh

# Stage 2: Install only the compiled artifacts into a clean base
FROM ghcr.io/ublue-os/bazzite-nvidia-open:stable

COPY --from=builder /output/ /

RUN depmod -a "$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' | tail -1)"

RUN bootc container lint
