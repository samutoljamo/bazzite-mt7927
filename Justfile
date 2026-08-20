export image_name := env("IMAGE_NAME", "bazzite-mt7927") # output image name, usually same as repo name, change as needed
export default_tag := env("DEFAULT_TAG", "latest")
export bib_image := env("BIB_IMAGE", "quay.io/centos-bootc/bootc-image-builder:latest")

alias build-vm := build-qcow2
alias rebuild-vm := rebuild-qcow2
alias run-vm := run-vm-qcow2

[private]
default:
    @just --list

# Check Just Syntax
[group('Just')]
check:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt --check -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt --check -f Justfile

# Fix Just Syntax
[group('Just')]
fix:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt -f Justfile || { exit 1; }

# Clean Repo
[group('Utility')]
clean:
    #!/usr/bin/bash
    set -eoux pipefail
    touch _build
    find *_build* -exec rm -rf {} \;
    rm -f previous.manifest.json
    rm -f changelog.md
    rm -f output.env
    rm -f output/

# Sudo Clean Repo
[group('Utility')]
[private]
sudo-clean:
    just sudoif just clean

# sudoif bash function
[group('Utility')]
[private]
sudoif command *args:
    #!/usr/bin/bash
    function sudoif(){
        if [[ "${UID}" -eq 0 ]]; then
            "$@"
        elif [[ "$(command -v sudo)" && -n "${SSH_ASKPASS:-}" ]] && [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
            /usr/bin/sudo --askpass "$@" || exit 1
        elif [[ "$(command -v sudo)" ]]; then
            /usr/bin/sudo "$@" || exit 1
        else
            exit 1
        fi
    }
    sudoif {{ command }} {{ args }}

# This Justfile recipe builds a container image using Podman.
#
# Arguments:
#   $target_image - The tag you want to apply to the image (default: $image_name).
#   $tag - The tag for the image (default: $default_tag).
#
# The script constructs the version string using the tag and the current date.
# If the git working directory is clean, it also includes the short SHA of the current HEAD.
#
# just build $target_image $tag
#
# Example usage:
#   just build aurora lts
#
# This will build an image 'aurora:lts' with DX and GDX enabled.
#

# Build the image using the specified parameters
# Pass base_image to override the upstream bazzite variant (e.g. ghcr.io/ublue-os/bazzite-gnome:stable)
build $target_image=image_name $tag=default_tag $base_image="":
    #!/usr/bin/env bash

    BUILD_ARGS=()
    if [[ -z "$(git status -s)" ]]; then
        BUILD_ARGS+=("--build-arg" "SHA_HEAD_SHORT=$(git rev-parse --short HEAD)")
    fi
    if [[ -n "${base_image}" ]]; then
        BUILD_ARGS+=("--build-arg" "BASE_IMAGE=${base_image}")
    fi

    podman build \
        "${BUILD_ARGS[@]}" \
        --pull=newer \
        --tag "${target_image}:${tag}" \
        .

# Verify the built image contains the expected modules, firmware, and config
[group('Utility')]
test $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set -euo pipefail
    IMAGE="${target_image}:${tag}"
    FAIL=0

    echo "Testing ${IMAGE}..."

    KVER=$(podman run --rm "${IMAGE}" rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')

    # build.sh stages each driver only while the base kernel lacks native support
    # for it, and the two landed in mainline separately: MT6639 Bluetooth in 7.1,
    # MT7927 WiFi in 7.2. Probe the in-tree modules by path rather than through
    # modinfo's name lookup, which depmod.d/mt7927.conf would resolve to extra/ —
    # we need the base kernel's own capability here.
    BASE_BTMTK=$(podman run --rm "${IMAGE}" sh -c "find /usr/lib/modules/${KVER}/kernel -name 'btmtk.ko*' | head -1")
    BT_EXPECTED=1
    if [[ -n "${BASE_BTMTK}" ]] && podman run --rm "${IMAGE}" sh -c "modinfo -F firmware '${BASE_BTMTK}' 2>/dev/null | grep -q MT6639"; then
        BT_EXPECTED=0
        echo "Kernel ${KVER} has native MT6639 Bluetooth — expecting in-tree btusb/btmtk"
    else
        echo "Kernel ${KVER} has no native MT6639 Bluetooth — expecting out-of-tree btusb/btmtk"
    fi

    BASE_MT7925E=$(podman run --rm "${IMAGE}" sh -c "find /usr/lib/modules/${KVER}/kernel -name 'mt7925e.ko*' | head -1")
    WIFI_EXPECTED=1
    if [[ -n "${BASE_MT7925E}" ]] && podman run --rm "${IMAGE}" sh -c "modinfo -F alias '${BASE_MT7925E}' 2>/dev/null | grep -q 7927"; then
        WIFI_EXPECTED=0
        echo "Kernel ${KVER} has native MT7927 WiFi — expecting in-tree mt76/mt7925"
    else
        echo "Kernel ${KVER} has no native MT7927 WiFi — expecting out-of-tree mt76/mt7925"
    fi

    # 7 WiFi modules and 2 Bluetooth modules, each set staged only while the
    # kernel still needs it. Both drop to zero once the kernel carries the
    # complete series and the image ships firmware and config alone.
    EXPECTED_COUNT=$(( WIFI_EXPECTED * 7 + BT_EXPECTED * 2 ))

    # A module we know is staged, for the checks that need to sample one.
    SAMPLE_MOD=""
    if [[ "${WIFI_EXPECTED}" -eq 1 ]]; then
        SAMPLE_MOD="mt7925e"
    elif [[ "${BT_EXPECTED}" -eq 1 ]]; then
        SAMPLE_MOD="btusb"
    fi

    # Check kernel modules
    MODULES=$(podman run --rm "${IMAGE}" find /usr/lib/modules -path '*/extra/mt7927/*.ko.xz' | sort)
    ACTUAL_COUNT=$(printf '%s' "${MODULES}" | grep -c . || true)
    if [[ "${ACTUAL_COUNT}" -eq "${EXPECTED_COUNT}" ]]; then
        echo "PASS: ${ACTUAL_COUNT} kernel modules found"
    else
        echo "FAIL: expected ${EXPECTED_COUNT} modules, found ${ACTUAL_COUNT}"
        FAIL=1
    fi

    # Check vermagic of each module matches the installed kernel
    for mod in $(podman run --rm "${IMAGE}" find /usr/lib/modules -path '*/extra/mt7927/*.ko.xz'); do
        VERMAGIC=$(podman run --rm "${IMAGE}" modinfo -F vermagic "${mod}")
        if [[ "${VERMAGIC}" == "${KVER} "* ]]; then
            echo "PASS: $(basename "${mod}") vermagic matches ${KVER}"
        else
            echo "FAIL: $(basename "${mod}") vermagic '${VERMAGIC}' does not match kernel ${KVER}"
            FAIL=1
        fi
    done

    # Check xz compression uses CRC32 (kernel decompressor doesn't support CRC64)
    if [[ -n "${SAMPLE_MOD}" ]]; then
        XZ_CHECK=$(podman run --rm "${IMAGE}" sh -c "xz --robot --list /usr/lib/modules/${KVER}/extra/mt7927/${SAMPLE_MOD}.ko.xz" | grep -oP 'CRC\d+' | head -1 || true)
        if [[ "${XZ_CHECK}" == "CRC32" ]]; then
            echo "PASS: module xz compression uses CRC32"
        else
            echo "FAIL: module xz compression uses ${XZ_CHECK:-unknown} (kernel requires CRC32)"
            FAIL=1
        fi
    else
        echo "SKIP: no out-of-tree modules staged, no xz compression to check"
    fi

    # Check firmware blobs. A blob satisfies the driver whether we staged it
    # plain or linux-firmware shipped it compressed, since the loader falls back
    # to .xz/.zst when the bare name is absent. Having both at once is the
    # failure worth catching: that is us shadowing the distro's copy, which is
    # how WiFi firmware silently regressed to the vendor ZIP's older build.
    FW_DIR=/usr/lib/firmware/mediatek/mt7927
    FW_LIST=$(podman run --rm "${IMAGE}" sh -c "ls -1 ${FW_DIR} 2>/dev/null" || true)
    for blob in \
        BT_RAM_CODE_MT6639_2_1_hdr.bin \
        WIFI_MT6639_PATCH_MCU_2_1_hdr.bin \
        WIFI_RAM_CODE_MT6639_2_1.bin; do
        HAVE_PLAIN=0
        HAVE_COMP=0
        grep -Fqx "${blob}"      <<< "${FW_LIST}" && HAVE_PLAIN=1 || true
        grep -Fqx "${blob}.xz"   <<< "${FW_LIST}" && HAVE_COMP=1  || true
        grep -Fqx "${blob}.zst"  <<< "${FW_LIST}" && HAVE_COMP=1  || true
        if [[ "${HAVE_PLAIN}" -eq 1 && "${HAVE_COMP}" -eq 1 ]]; then
            echo "FAIL: ${blob} staged on top of linux-firmware's compressed copy"
            FAIL=1
        elif [[ "${HAVE_PLAIN}" -eq 1 ]]; then
            echo "PASS: ${blob} (staged by this image)"
        elif [[ "${HAVE_COMP}" -eq 1 ]]; then
            echo "PASS: ${blob} (provided by linux-firmware)"
        else
            echo "FAIL: ${blob} absent — the driver has no firmware to load"
            FAIL=1
        fi
    done

    # Check config files
    for cfg in \
        /etc/depmod.d/mt7927.conf \
        /etc/modules-load.d/mt7925e.conf; do
        if podman run --rm "${IMAGE}" test -f "${cfg}"; then
            echo "PASS: ${cfg}"
        else
            echo "FAIL: missing ${cfg}"
            FAIL=1
        fi
    done

    # Check depmod ran (modules.dep should reference our modules)
    if [[ "${EXPECTED_COUNT}" -gt 0 ]]; then
        if podman run --rm "${IMAGE}" sh -c "grep -q 'extra/mt7927' /usr/lib/modules/*/modules.dep"; then
            echo "PASS: modules.dep references extra/mt7927"
        else
            echo "FAIL: modules.dep missing mt7927 entries (depmod may not have run)"
            FAIL=1
        fi
    else
        echo "SKIP: no out-of-tree modules staged, modules.dep has nothing to reference"
    fi

    # Check module resolution points to our patched modules (not stock)
    RESOLVE_MODS=()
    if [[ "${WIFI_EXPECTED}" -eq 1 ]]; then
        RESOLVE_MODS+=(mt7925e)
    fi
    if [[ "${BT_EXPECTED}" -eq 1 ]]; then
        RESOLVE_MODS+=(btusb)
    fi
    for mod in "${RESOLVE_MODS[@]}"; do
        MODPATH=$(podman run --rm "${IMAGE}" modinfo -k "${KVER}" -F filename "${mod}" 2>&1 || true)
        if echo "${MODPATH}" | grep -q 'extra/mt7927'; then
            echo "PASS: ${mod} resolves to extra/mt7927"
        else
            echo "FAIL: ${mod} does not resolve to extra/mt7927"
            echo "  got: ${MODPATH}"
            FAIL=1
        fi
    done

    # The mirror image: once the kernel has caught up we must NOT shadow its own
    # modules, or we would silently downgrade them to the older tarball build.
    SHADOW_MODS=()
    if [[ "${WIFI_EXPECTED}" -eq 0 ]]; then
        SHADOW_MODS+=(mt7925e)
    fi
    if [[ "${BT_EXPECTED}" -eq 0 ]]; then
        SHADOW_MODS+=(btusb)
    fi
    for mod in "${SHADOW_MODS[@]}"; do
        MODPATH=$(podman run --rm "${IMAGE}" modinfo -k "${KVER}" -F filename "${mod}" 2>&1 || true)
        if echo "${MODPATH}" | grep -q 'extra/mt7927'; then
            echo "FAIL: ${mod} is shadowed by extra/mt7927 despite native kernel support"
            echo "  got: ${MODPATH}"
            FAIL=1
        else
            echo "PASS: ${mod} resolves to the in-tree module"
        fi
    done

    # Whichever driver wins, it must ask for the firmware we stage, or the
    # hardware stays dead however the modules resolved.
    BTMTK_FW=$(podman run --rm "${IMAGE}" modinfo -k "${KVER}" -F firmware btmtk 2>&1 || true)
    if echo "${BTMTK_FW}" | grep -q 'MT6639'; then
        echo "PASS: resolved btmtk declares MT6639 firmware"
    else
        echo "FAIL: resolved btmtk declares no MT6639 firmware — Bluetooth will not work"
        echo "  got: ${BTMTK_FW:-<empty>}"
        FAIL=1
    fi

    MT7925E_FW=$(podman run --rm "${IMAGE}" modinfo -k "${KVER}" -F firmware mt7925e 2>&1 || true)
    if echo "${MT7925E_FW}" | grep -q 'mt7927/WIFI_RAM_CODE_MT6639_2_1.bin'; then
        echo "PASS: resolved mt7925e declares MT7927 firmware"
    else
        echo "FAIL: resolved mt7925e declares no MT7927 firmware — WiFi will not work"
        echo "  got: ${MT7925E_FW:-<empty>}"
        FAIL=1
    fi

    # Check modules.alias maps MT7927 PCI ID to our patched mt7925e
    # This is the critical check: even if modules are on disk, the kernel
    # auto-loads drivers via modules.alias when it detects PCI hardware.
    # Without the 7927 device ID in the alias table, the hardware goes unclaimed.
    ALIAS_ENTRY=$(podman run --rm "${IMAGE}" sh -c "grep -i '7927' /usr/lib/modules/${KVER}/modules.alias" || true)
    if echo "${ALIAS_ENTRY}" | grep -qi 'mt7925e'; then
        echo "PASS: modules.alias maps PCI ID 7927 to mt7925e"
    else
        echo "FAIL: modules.alias does not map PCI ID 7927 to mt7925e"
        echo "  The patched module's device table may not include the MT7927 PCI ID."
        echo "  got: ${ALIAS_ENTRY:-<empty>}"
        FAIL=1
    fi

    # Check if kernel enforces module signatures (Secure Boot)
    # If CONFIG_MODULE_SIG_FORCE=y, unsigned out-of-tree modules will be
    # silently rejected at load time — even though they're on disk and
    # depmod resolves them correctly.
    KCONFIG="/usr/lib/modules/${KVER}/config"
    SIG_FORCE=$(podman run --rm "${IMAGE}" sh -c "grep -s '^CONFIG_MODULE_SIG_FORCE=' ${KCONFIG}" || true)
    if [[ "${SIG_FORCE}" == *"=y" ]]; then
        echo "WARN: kernel has CONFIG_MODULE_SIG_FORCE=y — unsigned modules will be rejected with Secure Boot"
        # Check if our modules are signed
        if [[ -n "${SAMPLE_MOD}" ]]; then
            SIG_ID=$(podman run --rm "${IMAGE}" modinfo -F sig_id "/usr/lib/modules/${KVER}/extra/mt7927/${SAMPLE_MOD}.ko.xz" 2>/dev/null || true)
            if [[ -n "${SIG_ID}" ]]; then
                echo "PASS: ${SAMPLE_MOD} is signed (${SIG_ID})"
            else
                echo "FAIL: ${SAMPLE_MOD} is unsigned — will not load with Secure Boot enabled"
                FAIL=1
            fi
        else
            echo "PASS: no out-of-tree modules staged, nothing needs signing"
        fi
    else
        echo "PASS: kernel does not force module signatures"
    fi

    # Check modprobe dependency chain resolves entirely to our patched modules
    # If any dependency falls back to stock kernel/, module loading could fail
    # or load a mix of patched + stock modules with incompatible symbols.
    DEPS=$(podman run --rm "${IMAGE}" modprobe --show-depends --set-version "${KVER}" mt7925e 2>&1 || true)
    if echo "${DEPS}" | grep -q '^insmod '; then
        # Only flag stock modules that we still patch on this kernel. Stock deps
        # like cfg80211, mac80211 and rfkill are expected, and so is the whole
        # mt76 family once the kernel carries the MT7927 series itself.
        PATCHED_NAMES=""
        if [[ "${WIFI_EXPECTED}" -eq 1 ]]; then
            PATCHED_NAMES="mt76|mt792x|mt7921|mt7925"
        fi
        if [[ "${BT_EXPECTED}" -eq 1 ]]; then
            PATCHED_NAMES="${PATCHED_NAMES:+${PATCHED_NAMES}|}btusb|btmtk"
        fi
        STOCK_CONFLICT=""
        if [[ -n "${PATCHED_NAMES}" ]]; then
            STOCK_CONFLICT=$(echo "${DEPS}" | grep '/kernel/' | grep -E "${PATCHED_NAMES}" || true)
        fi
        if [[ -z "${STOCK_CONFLICT}" ]]; then
            echo "PASS: no patched module falls back to the stock kernel"
        else
            echo "FAIL: patched modules falling back to stock kernel:"
            echo "${STOCK_CONFLICT}" | while IFS= read -r line; do echo "  ${line}"; done
            FAIL=1
        fi
        echo "  Full chain:"
        echo "${DEPS}" | while IFS= read -r line; do echo "    ${line}"; done
    else
        echo "FAIL: modprobe --show-depends mt7925e returned no modules"
        echo "  got: ${DEPS:-<empty>}"
        FAIL=1
    fi

    if [[ "${FAIL}" -eq 0 ]]; then
        echo "All checks passed."
    else
        echo "Some checks failed."
        exit 1
    fi

# Command: _rootful_load_image
# Description: This script checks if the current user is root or running under sudo. If not, it attempts to resolve the image tag using podman inspect.
#              If the image is found, it loads it into rootful podman. If the image is not found, it pulls it from the repository.
#
# Parameters:
#   $target_image - The name of the target image to be loaded or pulled.
#   $tag - The tag of the target image to be loaded or pulled. Default is 'default_tag'.
#
# Example usage:
#   _rootful_load_image my_image latest
#
# Steps:
# 1. Check if the script is already running as root or under sudo.
# 2. Check if target image is in the non-root podman container storage)
# 3. If the image is found, load it into rootful podman using podman scp.
# 4. If the image is not found, pull it from the remote repository into reootful podman.

_rootful_load_image $target_image=image_name $tag=default_tag:
    #!/usr/bin/bash
    set -eoux pipefail

    # Check if already running as root or under sudo
    if [[ -n "${SUDO_USER:-}" || "${UID}" -eq "0" ]]; then
        echo "Already root or running under sudo, no need to load image from user podman."
        exit 0
    fi

    # Try to resolve the image tag using podman inspect
    set +e
    resolved_tag=$(podman inspect -t image "${target_image}:${tag}" | jq -r '.[].RepoTags.[0]')
    return_code=$?
    set -e

    USER_IMG_ID=$(podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")

    if [[ $return_code -eq 0 ]]; then
        # If the image is found, load it into rootful podman
        ID=$(just sudoif podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")
        if [[ "$ID" != "$USER_IMG_ID" ]]; then
            # If the image ID is not found or different from user, copy the image from user podman to root podman
            COPYTMP=$(mktemp -p "${PWD}" -d -t _build_podman_scp.XXXXXXXXXX)
            just sudoif TMPDIR=${COPYTMP} podman image scp ${UID}@localhost::"${target_image}:${tag}" root@localhost::"${target_image}:${tag}"
            rm -rf "${COPYTMP}"
        fi
    else
        # If the image is not found, pull it from the repository
        just sudoif podman pull "${target_image}:${tag}"
    fi

# Build a bootc bootable image using Bootc Image Builder (BIB)
# Converts a container image to a bootable image
# Parameters:
#   target_image: The name of the image to build (ex. localhost/fedora)
#   tag: The tag of the image to build (ex. latest)
#   type: The type of image to build (ex. qcow2, raw, iso)
#   config: The configuration file to use for the build (default: disk_config/disk.toml)

# Example: just _rebuild-bib localhost/fedora latest qcow2 disk_config/disk.toml
_build-bib $target_image $tag $type $config: (_rootful_load_image target_image tag)
    #!/usr/bin/env bash
    set -euo pipefail

    args="--type ${type} "
    args+="--use-librepo=True "
    args+="--rootfs=btrfs"

    BUILDTMP=$(mktemp -p "${PWD}" -d -t _build-bib.XXXXXXXXXX)

    sudo podman run \
      --rm \
      -it \
      --privileged \
      --pull=newer \
      --net=host \
      --security-opt label=type:unconfined_t \
      -v $(pwd)/${config}:/config.toml:ro \
      -v $BUILDTMP:/output \
      -v /var/lib/containers/storage:/var/lib/containers/storage \
      "${bib_image}" \
      ${args} \
      "${target_image}:${tag}"

    mkdir -p output
    sudo mv -f $BUILDTMP/* output/
    sudo rmdir $BUILDTMP
    sudo chown -R $USER:$USER output/

# Podman builds the image from the Containerfile and creates a bootable image
# Parameters:
#   target_image: The name of the image to build (ex. localhost/fedora)
#   tag: The tag of the image to build (ex. latest)
#   type: The type of image to build (ex. qcow2, raw, iso)
#   config: The configuration file to use for the build (deafult: disk_config/disk.toml)

# Example: just _rebuild-bib localhost/fedora latest qcow2 disk_config/disk.toml
_rebuild-bib $target_image $tag $type $config: (build target_image tag) && (_build-bib target_image tag type config)

# Build a QCOW2 virtual machine image
[group('Build Virtal Machine Image')]
build-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "qcow2" "disk_config/disk.toml")

# Build a RAW virtual machine image
[group('Build Virtal Machine Image')]
build-raw $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "raw" "disk_config/disk.toml")

# Build an ISO virtual machine image
[group('Build Virtal Machine Image')]
build-iso $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "iso" "disk_config/iso.toml")

# Rebuild a QCOW2 virtual machine image
[group('Build Virtal Machine Image')]
rebuild-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "qcow2" "disk_config/disk.toml")

# Rebuild a RAW virtual machine image
[group('Build Virtal Machine Image')]
rebuild-raw $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "raw" "disk_config/disk.toml")

# Rebuild an ISO virtual machine image
[group('Build Virtal Machine Image')]
rebuild-iso $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "iso" "disk_config/iso.toml")

# Run a virtual machine with the specified image type and configuration
_run-vm $target_image $tag $type $config:
    #!/usr/bin/bash
    set -eoux pipefail

    # Determine the image file based on the type
    image_file="output/${type}/disk.${type}"
    if [[ $type == iso ]]; then
        image_file="output/bootiso/install.iso"
    fi

    # Build the image if it does not exist
    if [[ ! -f "${image_file}" ]]; then
        just "build-${type}" "$target_image" "$tag"
    fi

    # Determine an available port to use
    port=8006
    while grep -q :${port} <<< $(ss -tunalp); do
        port=$(( port + 1 ))
    done
    echo "Using Port: ${port}"
    echo "Connect to http://localhost:${port}"

    # Set up the arguments for running the VM
    run_args=()
    run_args+=(--rm --privileged)
    run_args+=(--pull=newer)
    run_args+=(--publish "127.0.0.1:${port}:8006")
    run_args+=(--env "CPU_CORES=4")
    run_args+=(--env "RAM_SIZE=8G")
    run_args+=(--env "DISK_SIZE=64G")
    run_args+=(--env "TPM=Y")
    run_args+=(--env "GPU=Y")
    run_args+=(--device=/dev/kvm)
    run_args+=(--volume "${PWD}/${image_file}":"/boot.${type}")
    run_args+=(docker.io/qemux/qemu)

    # Run the VM and open the browser to connect
    (sleep 30 && xdg-open http://localhost:"$port") &
    podman run "${run_args[@]}"

# Run a virtual machine from a QCOW2 image
[group('Run Virtal Machine')]
run-vm-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "qcow2" "disk_config/disk.toml")

# Run a virtual machine from a RAW image
[group('Run Virtal Machine')]
run-vm-raw $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "raw" "disk_config/disk.toml")

# Run a virtual machine from an ISO
[group('Run Virtal Machine')]
run-vm-iso $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "iso" "disk_config/iso.toml")

# Run a virtual machine using systemd-vmspawn
[group('Run Virtal Machine')]
spawn-vm rebuild="0" type="qcow2" ram="6G":
    #!/usr/bin/env bash

    set -euo pipefail

    [ "{{ rebuild }}" -eq 1 ] && echo "Rebuilding the ISO" && just build-vm {{ rebuild }} {{ type }}

    systemd-vmspawn \
      -M "bootc-image" \
      --console=gui \
      --cpus=2 \
      --ram=$(echo {{ ram }}| /usr/bin/numfmt --from=iec) \
      --network-user-mode \
      --vsock=false --pass-ssh-key=false \
      -i ./output/**/*.{{ type }}


# Runs shell check on all Bash scripts
lint:
    #!/usr/bin/env bash
    set -eoux pipefail
    # Check if shellcheck is installed
    if ! command -v shellcheck &> /dev/null; then
        echo "shellcheck could not be found. Please install it."
        exit 1
    fi
    # Run shellcheck on all Bash scripts
    /usr/bin/find . -iname "*.sh" -type f -exec shellcheck "{}" ';'

# Runs shfmt on all Bash scripts
format:
    #!/usr/bin/env bash
    set -eoux pipefail
    # Check if shfmt is installed
    if ! command -v shfmt &> /dev/null; then
        echo "shellcheck could not be found. Please install it."
        exit 1
    fi
    # Run shfmt on all Bash scripts
    /usr/bin/find . -iname "*.sh" -type f -exec shfmt --write "{}" ';'
