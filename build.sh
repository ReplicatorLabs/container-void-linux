#!/bin/bash

# https://docs.voidlinux.org/installation/guides/chroot.html
# https://docs.voidlinux.org/xbps/troubleshooting/static.html

TOP=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

##
# Settings
##

# buildah image
IMAGE="void-linux"

# Void Linux
VOID_LINUX_REPOSITORY="https://repo-default.voidlinux.org/current"
VOID_LINUX_PACKAGES=(
    "base-files"
    "ncurses"
    "coreutils"
    "libgcc"
    "dash"
    "bash"
    "grep"
    "gzip"
    "sed"
    "less"
    "which"
    "tar"
    "shadow"
    "procps-ng"
    "iana-etc"
    "iproute2"
    "iputils"
    "xbps"
    "nvi"
    "void-artwork"
    "runit-void"
    "removed-packages"
    "util-linux"

    # user tools
    # "findutils"
    # "diffutils"
    # "sudo"
    # "openssh"
    # "gawk"
    # "file"

    # data
    # "tzdata"
    # "glibc-locales"

    # documentation
    # "man-pages"
    # "mdocml"

    # filesystem tools
    # "e2fsprogs"
    # "btrfs-progs"
    # "xfsprogs"
    # "f2fs-tools"
    # "dosfstools"

    # wireless tools
    # "iw"
    # "wpa_supplicant"
    # "wifi-firmware"

    # network tools
    # "ethtool"
    # "dhcpcd"
    # "traceroute"

    # hardware tools
    # "pciutils"
    # "usbutils"

    # system tools
    # "acpid"
    # "eudev"
    # "kbd"

    # kernel
    # "kmod",
    # "linux"
)

# xbps
XBPS_STATIC_MIRROR="https://repo-default.voidlinux.org/static"
XBPS_STATIC_VERSION="latest.x86_64-musl"

##
# Build Steps
##

# verify required binaries are available
for BINARY in buildah wget tar; do
    if ! hash "$BINARY" 2> /dev/null; then
        echo "Required binary not found: $BINARY"
        exit 1
    fi
done

# quit on any errors
set -e

# create scratch folder
SCRATCH_FOLDER=$(mktemp -d -t "container-void-XXXXXX")
echo "Scratch folder: ${SCRATCH_FOLDER}"

# download, extract, and prepare xbps tools
XBPS_STATIC_ARCHIVE="xbps-static-${XBPS_STATIC_VERSION}.tar.xz"
wget "${XBPS_STATIC_MIRROR}/${XBPS_STATIC_ARCHIVE}" \
    -O "${SCRATCH_FOLDER}/${XBPS_STATIC_ARCHIVE}"

XBPS_STATIC_ROOT="${SCRATCH_FOLDER}/xbps"
mkdir -p "$XBPS_STATIC_ROOT"
tar -xJf "${SCRATCH_FOLDER}/${XBPS_STATIC_ARCHIVE}" -C "$XBPS_STATIC_ROOT"

# create container
CONTAINER=$(buildah from scratch)

# XXX
# XXX: run this under "buildah unshare"
CONTAINER_MOUNT=$(buildah mount "$CONTAINER")

# install XBPS package keys
cp -r "${XBPS_STATIC_ROOT}/var" "${CONTAINER_MOUNT}"

# install initial packages
XBPS_ARCH=x86_64 "${XBPS_STATIC_ROOT}/usr/bin/xbps-install" \
    --rootdir "${CONTAINER_MOUNT}" \
    --repository "${VOID_LINUX_REPOSITORY}" \
    --sync --yes \
    "${VOID_LINUX_PACKAGES[@]}"

# XXX
buildah unmount "$CONTAINER"

# configure entrypoint to run default runit service directory
# XXX: mount tmpfs at /tmp while running instead?
# buildah run "$CONTAINER" -- chmod 0777 /tmp
buildah add --chmod 0755 --chown root:root "$CONTAINER" "${TOP}/entrypoint.sh" /entrypoint.sh
buildah config --entrypoint '/entrypoint.sh' "$CONTAINER"

# disable unnecessary system services
buildah run "$CONTAINER" -- rm -rf /etc/runit/runsvdir/default/agetty*

# create image and remove container
buildah commit "$CONTAINER" "$IMAGE"
buildah rm "$CONTAINER"

# remove scratch folder
rm -rf "$SCRATCH_FOLDER"
