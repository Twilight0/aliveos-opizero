#!/usr/bin/env bash
#
# Build script for minimal AliveOS (Orange Pi Zero / Allwinner H2+) Arch Linux ARM image
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Check root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root (or with sudo)." >&2
  exit 1
fi

IMAGE_SIZE_MB="${IMAGE_SIZE_MB:-2048}"
BUILD_DATE="$(date +%Y%m%d)"
OUTPUT_NAME="${OUTPUT_NAME:-aliveos-orangepi-zero-${BUILD_DATE}}"
RAW_IMG="${ROOT_DIR}/${OUTPUT_NAME}.img"
ARCH_ROOTFS_URL="${ARCH_ROOTFS_URL:-http://os.archlinuxarm.org/os/ArchLinuxARM-armv7-latest.tar.gz}"
CACHE_DIR="${ROOT_DIR}/cache"
ROOTFS_TAR="${CACHE_DIR}/ArchLinuxARM-armv7-latest.tar.gz"

MNT_DIR=""
LOOP_DEV=""

cleanup() {
  echo "==> Cleaning up mountpoints and devices..."
  set +e
  if [ -n "${MNT_DIR}" ] && [ -d "${MNT_DIR}" ]; then
    for fs in dev/pts dev proc sys run; do
      if mountpoint -q "${MNT_DIR}/${fs}"; then
        umount -l "${MNT_DIR}/${fs}" 2>/dev/null || true
      fi
    done
    if mountpoint -q "${MNT_DIR}"; then
      umount -l "${MNT_DIR}" 2>/dev/null || true
    fi
    rm -rf "${MNT_DIR}"
  fi

  if [ -n "${LOOP_DEV}" ]; then
    losetup -d "${LOOP_DEV}" 2>/dev/null || true
  fi
}
trap cleanup EXIT ERR

# Check prerequisites
for cmd in parted mkfs.ext4 losetup bsdtar mkimage zstd wget; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: Required command '$cmd' not found." >&2
    exit 1
  fi
done

# Ensure qemu-arm-static is available for chroot
QEMU_BIN="$(command -v qemu-arm-static 2>/dev/null || true)"
if [ -z "$QEMU_BIN" ] && [ -f /usr/bin/qemu-arm-static ]; then
  QEMU_BIN="/usr/bin/qemu-arm-static"
fi
if [ -z "$QEMU_BIN" ]; then
  echo "Error: qemu-arm-static not found. Install qemu-user-static." >&2
  exit 1
fi

mkdir -p "${CACHE_DIR}"

# 1. Download official rootfs if not cached
if [ ! -f "${ROOTFS_TAR}" ]; then
  echo "==> Downloading Arch Linux ARM armv7 rootfs..."
  wget -c "${ARCH_ROOTFS_URL}" -O "${ROOTFS_TAR}"
else
  echo "==> Using cached Arch Linux ARM rootfs: ${ROOTFS_TAR}"
fi

# 2. Create raw disk image
echo "==> Creating raw disk image (${IMAGE_SIZE_MB} MiB)..."
rm -f "${RAW_IMG}"
dd if=/dev/zero of="${RAW_IMG}" bs=1M count=0 seek="${IMAGE_SIZE_MB}" status=none

# 3. Partition table (MBR)
# First partition starts at 4MiB (sector 8192), leaving sectors 16-8191 for U-Boot SPL
echo "==> Partitioning raw image..."
parted -s "${RAW_IMG}" mklabel msdos
parted -s "${RAW_IMG}" mkpart primary ext4 4MiB 100%

# 4. Flash rock-solid U-Boot SPL (Armbian 2021.10 / H2+)
echo "==> Writing U-Boot SPL to sector 16 (8 KiB offset)..."
dd if="${ROOT_DIR}/bootloader/u-boot-sunxi-with-spl.bin" of="${RAW_IMG}" bs=1k seek=8 conv=notrunc status=none

# 5. Attach loop device
echo "==> Attaching loop device..."
LOOP_DEV="$(losetup -Pf --show "${RAW_IMG}")"
PART_DEV="${LOOP_DEV}p1"

# Wait for kernel partition scan
sleep 1

# 6. Format filesystem
echo "==> Formatting ext4 filesystem on ${PART_DEV}..."
mkfs.ext4 -F -L OPIZERO "${PART_DEV}"

# 7. Mount partition
MNT_DIR="$(mktemp -d /tmp/opizero_mnt.XXXXXX)"
echo "==> Mounting partition at ${MNT_DIR}..."
mount "${PART_DEV}" "${MNT_DIR}"

# 8. Extract Arch Linux ARM rootfs
echo "==> Extracting rootfs (this may take a couple of minutes)..."
bsdtar -xpf "${ROOTFS_TAR}" -C "${MNT_DIR}"

# 9. Inject configs
echo "==> Injecting custom configs and tweaks..."

# Boot script
cp "${ROOT_DIR}/configs/boot.cmd" "${MNT_DIR}/boot/boot.cmd"
mkimage -A arm -O linux -T script -C none -d "${ROOT_DIR}/configs/boot.cmd" "${MNT_DIR}/boot/boot.scr"

# Fstab
cp "${ROOT_DIR}/configs/fstab" "${MNT_DIR}/etc/fstab"

# ZRAM
cp "${ROOT_DIR}/configs/zram-generator.conf" "${MNT_DIR}/etc/systemd/zram-generator.conf"
mkdir -p "${MNT_DIR}/etc/sysctl.d"
cp "${ROOT_DIR}/configs/99-zram.conf" "${MNT_DIR}/etc/sysctl.d/99-zram.conf"

# CPU Frequency & Power Safety governor
cp "${ROOT_DIR}/configs/cpufreq-governor.service" "${MNT_DIR}/etc/systemd/system/cpufreq-governor.service"

# Networking
mkdir -p "${MNT_DIR}/etc/systemd/network"
cp "${ROOT_DIR}/configs/network/10-wlan.link" "${MNT_DIR}/etc/systemd/network/"
cp "${ROOT_DIR}/configs/network/20-wired.network" "${MNT_DIR}/etc/systemd/network/"
cp "${ROOT_DIR}/configs/network/25-wireless.network" "${MNT_DIR}/etc/systemd/network/"

# Kernel modules & firmware
mkdir -p "${MNT_DIR}/etc/modules-load.d"
cp "${ROOT_DIR}/configs/xradio.conf" "${MNT_DIR}/etc/modules-load.d/"

mkdir -p "${MNT_DIR}/usr/lib/firmware/xr819"
cp "${ROOT_DIR}"/configs/firmware/xr819/* "${MNT_DIR}/usr/lib/firmware/xr819/"

# SSH root permit
mkdir -p "${MNT_DIR}/etc/ssh/sshd_config.d"
cp "${ROOT_DIR}/configs/permit-root.conf" "${MNT_DIR}/etc/ssh/sshd_config.d/"

# First-boot rootfs auto-expansion
mkdir -p "${MNT_DIR}/usr/local/bin"
cp "${ROOT_DIR}/configs/orangepi-resize-rootfs" "${MNT_DIR}/usr/local/bin/orangepi-resize-rootfs"
chmod +x "${MNT_DIR}/usr/local/bin/orangepi-resize-rootfs"
cp "${ROOT_DIR}/configs/orangepi-resize-rootfs.service" "${MNT_DIR}/etc/systemd/system/orangepi-resize-rootfs.service"

# Login Welcome MOTD banner
mkdir -p "${MNT_DIR}/etc/profile.d"
cp "${ROOT_DIR}/configs/99-orangepi-motd.sh" "${MNT_DIR}/etc/profile.d/99-orangepi-motd.sh"
chmod +x "${MNT_DIR}/etc/profile.d/99-orangepi-motd.sh"

# Fastfetch AliveOS ASCII logo & config
mkdir -p "${MNT_DIR}/etc/fastfetch" "${MNT_DIR}/etc/xdg/fastfetch"
cp "${ROOT_DIR}/configs/fastfetch/aliveos.txt" "${MNT_DIR}/etc/fastfetch/aliveos.txt"
cp "${ROOT_DIR}/configs/fastfetch/config.jsonc" "${MNT_DIR}/etc/xdg/fastfetch/config.jsonc"

# 10. Chroot configuration
echo "==> Entering chroot via QEMU..."
cp "$QEMU_BIN" "${MNT_DIR}/usr/bin/qemu-arm-static"
cp "${ROOT_DIR}/scripts/chroot-setup.sh" "${MNT_DIR}/root/chroot-setup.sh"
chmod +x "${MNT_DIR}/root/chroot-setup.sh"

# Bind mounts
for fs in dev dev/pts proc sys run; do
  mount --bind "/${fs}" "${MNT_DIR}/${fs}"
done

# Run setup
chroot "${MNT_DIR}" /bin/bash /root/chroot-setup.sh

# Unmount pseudo-filesystems
for fs in run sys proc dev/pts dev; do
  umount -l "${MNT_DIR}/${fs}" 2>/dev/null || true
done

# Cleanup chroot artifacts
rm -f "${MNT_DIR}/usr/bin/qemu-arm-static"
rm -f "${MNT_DIR}/root/chroot-setup.sh"

# 11. Zero out free space for maximum compression
echo "==> Zeroing free space for compression..."
dd if=/dev/zero of="${MNT_DIR}/zero.fill" bs=1M status=none 2>/dev/null || true
sync
rm -f "${MNT_DIR}/zero.fill"
sync

# 12. Unmount and detach loop
echo "==> Unmounting..."
umount "${MNT_DIR}"
MNT_DIR=""

echo "==> Detaching loop device..."
losetup -d "${LOOP_DEV}"
LOOP_DEV=""

# 13. Compress with zstd
echo "==> Compressing image with zstd (level 19)..."
zstd -19 --rm "${RAW_IMG}" -o "${ROOT_DIR}/${OUTPUT_NAME}.img.zst"

# 14. Checksum
echo "==> Generating SHA256 checksum..."
cd "${ROOT_DIR}"
sha256sum "${OUTPUT_NAME}.img.zst" > "${OUTPUT_NAME}.img.zst.sha256"

echo "==> Build complete!"
echo "Image: ${ROOT_DIR}/${OUTPUT_NAME}.img.zst"
echo "SHA256: $(cat "${ROOT_DIR}/${OUTPUT_NAME}.img.zst.sha256")"
