#!/bin/bash
set -euo pipefail

echo "==> [chroot] Setting up minimal Arch Linux ARM environment for Orange Pi Zero..."

# 1. Initialize Pacman Keyring
echo "==> [chroot] Initializing Pacman keys..."
pacman-key --init
pacman-key --populate archlinuxarm

# Ensure mirrors are populated and accessible
if [ ! -s /etc/pacman.d/mirrorlist ]; then
  echo "Server = http://os.archlinuxarm.org/\$arch/\$repo" > /etc/pacman.d/mirrorlist
fi

# 2. Update database & perform full system upgrade + essentials
echo "==> [chroot] Performing full system upgrade and installing essentials..."
pacman -Syu --noconfirm

# Essential packages for minimal headless SBC operation
ESSENTIAL_PKGS=(
  openssh
  zram-generator
  uboot-tools
  sudo
  curl
  wget
  nano
  wpa_supplicant
  iw
  haveged
  python
  python-urwid
)

pacman -S --noconfirm --needed "${ESSENTIAL_PKGS[@]}"

# 3. Fetch and install AliveOS packages (XR819 WiFi driver + orangepi-config)
echo "==> [chroot] Installing AliveOS prebuilt packages..."
ALIVEOS_RELEASE="https://github.com/Twilight0/aliveos-repo/releases/download/latest"

mkdir -p /tmp/pkgs
if curl -fSL -o /tmp/pkgs/orangepi-config.pkg.tar.zst "${ALIVEOS_RELEASE}/orangepi-config-0.2.0-1-any.pkg.tar.zst" 2>/dev/null; then
  pacman -U --noconfirm --needed /tmp/pkgs/orangepi-config.pkg.tar.zst || echo "Warning: orangepi-config install failed"
fi

if curl -fSL -o /tmp/pkgs/xradio-linux-armv7.pkg.tar.zst "${ALIVEOS_RELEASE}/xradio-linux-armv7-r185.3ce657a-1-armv7h.pkg.tar.zst" 2>/dev/null; then
  pacman -U --noconfirm --needed /tmp/pkgs/xradio-linux-armv7.pkg.tar.zst || echo "Warning: xradio-linux-armv7 install failed"
fi
rm -rf /tmp/pkgs

# 4. Strip unneeded heavy GPU firmwares to minimize disk image and RAM overhead
echo "==> [chroot] Stripping unneeded firmwares..."
pacman -Rdd --noconfirm \
  linux-firmware-intel \
  linux-firmware-amdgpu \
  linux-firmware-amd \
  linux-firmware-radeon \
  linux-firmware-nvidia \
  linux-firmware-cirrus 2>/dev/null || true

# 5. Set hostname
echo "orangepi-zero" > /etc/hostname

# 6. Localization
echo "==> [chroot] Setting up locale and timezone..."
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
if grep -q "#en_US.UTF-8 UTF-8" /etc/locale.gen; then
  sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
else
  echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
fi
locale-gen || true
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# 7. User accounts & passwords (root:root, alarm:alarm)
echo "==> [chroot] Configuring user credentials..."
echo "root:root" | chpasswd

if ! id -u alarm >/dev/null 2>&1; then
  useradd -m -g users -G wheel,video,audio,storage -s /bin/bash alarm
fi
echo "alarm:alarm" | chpasswd

echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# 8. Enable essential system services
echo "==> [chroot] Enabling systemd units..."
systemctl enable systemd-networkd.service
systemctl enable systemd-resolved.service
systemctl enable sshd.service
systemctl enable cpufreq-governor.service
systemctl enable haveged.service 2>/dev/null || true

# Enable orangepi-config web TUI if installed
if systemctl list-unit-files | grep -q orangepi-config-web; then
  systemctl enable orangepi-config-web.service || true
fi

# 9. Configure DNS symlink
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# 10. Clean cache & temporary files
echo "==> [chroot] Cleaning cache..."
pacman -Scc --noconfirm
rm -rf /var/cache/pacman/pkg/* /tmp/* /var/tmp/*

echo "==> [chroot] Setup complete!"
