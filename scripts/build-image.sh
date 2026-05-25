#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-25.12-SNAPSHOT}"
TARGET="${TARGET:-x86/64}"
PROFILE="${PROFILE:-generic}"
IMAGEBUILDER_URL="${IMAGEBUILDER_URL:-https://downloads.immortalwrt.org/releases/25.12-SNAPSHOT/targets/x86/64/immortalwrt-imagebuilder-25.12-SNAPSHOT-x86-64.Linux-x86_64.tar.zst}"
EXTRA_IMAGE_NAME="${EXTRA_IMAGE_NAME:-daed-deps}"
OUT_DIR="${OUT_DIR:-$PWD/out}"
PREFLIGHT="${PREFLIGHT:-1}"
ROOTFS_PARTSIZE="${ROOTFS_PARTSIZE:-1024}"

EXTRA_PACKAGES="${EXTRA_PACKAGES:-luci kmod-sched-core kmod-sched-bpf kmod-veth kmod-xdp-sockets-diag curl nano}"

WORK_DIR="${WORK_DIR:-$PWD/work}"
IB_ARCHIVE="$WORK_DIR/imagebuilder.tar.zst"

mkdir -p "$WORK_DIR" "$OUT_DIR"

if [ ! -s "$IB_ARCHIVE" ]; then
  curl -L --retry 8 --retry-delay 5 --connect-timeout 30 \
    -o "$IB_ARCHIVE" "$IMAGEBUILDER_URL"
fi

rm -rf "$WORK_DIR/imagebuilder"
mkdir -p "$WORK_DIR/imagebuilder"
tar --use-compress-program=unzstd -xf "$IB_ARCHIVE" -C "$WORK_DIR/imagebuilder" --strip-components=1

cp -a files "$WORK_DIR/imagebuilder/files"

cd "$WORK_DIR/imagebuilder"

echo "Version: $VERSION"
echo "Target: $TARGET"
echo "Profile: $PROFILE"
echo "Rootfs part size: ${ROOTFS_PARTSIZE}MB"
echo "Extra packages: $EXTRA_PACKAGES"
mkdir -p "$OUT_DIR"
echo "extra_packages=$EXTRA_PACKAGES" > "$OUT_DIR/.extra_packages"

diagnose_failure() {
  cat >&2 <<'EOF'

ImageBuilder failed.

Common causes for this daed test image:
- The selected ImmortalWrt snapshot ImageBuilder and package feeds are out of sync.
  Example: base packages require a newer libubox/libblobmsg-json than the public feed provides.
- vmlinux-btf is not published for the selected target/feed. ImageBuilder can only install
  packages that already exist in the feed; it cannot build vmlinux-btf by itself.

Next choices:
- Retry later with the same 25.12-SNAPSHOT URL after ImmortalWrt feeds finish syncing.
- Use a release/rc ImageBuilder URL and build dae/daed APKs against the same release/rc.
- Rebuild dae/daed with BPF_DEPENDS instead of vmlinux-btf if that target does not publish vmlinux-btf.
EOF
}

if [ "$PREFLIGHT" = "1" ] || [ "$PREFLIGHT" = "true" ]; then
  echo "Running package manifest preflight..."
  if ! make manifest PROFILE="$PROFILE" PACKAGES="$EXTRA_PACKAGES"; then
    diagnose_failure
    exit 1
  fi
fi

if ! make image \
    PROFILE="$PROFILE" \
    PACKAGES="$EXTRA_PACKAGES" \
    FILES=files \
    BIN_DIR="$OUT_DIR" \
    EXTRA_IMAGE_NAME="$EXTRA_IMAGE_NAME" \
    ROOTFS_PARTSIZE="$ROOTFS_PARTSIZE"; then
  diagnose_failure
  exit 1
fi

find "$OUT_DIR" -maxdepth 1 -type f -print
