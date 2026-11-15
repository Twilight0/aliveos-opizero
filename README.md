# Orange Pi Zero Minimal Arch Linux ARM Image Builder & Weekly CI

[![Build Orange Pi Zero Arch Linux ARM Image](https://github.com/Twilight0/orangepi-zero-alarm/actions/workflows/build.yml/badge.svg)](https://github.com/Twilight0/orangepi-zero-alarm/actions/workflows/build.yml)
[![Latest Release](https://img.shields.io/github/v/release/Twilight0/orangepi-zero-alarm?include_prereleases&color=orange)](https://github.com/Twilight0/orangepi-zero-alarm/releases/latest)

An ultra-lean, rock-solid **Arch Linux ARM** system image for the **Orange Pi Zero (Allwinner H2+)**, built and released weekly via GitHub Actions.

Designed from the ground up for maximum power stability, zero OOM crashes on the **256 MB RAM** variant, full interface daughterboard expansion (extra USB ports, 3.5mm audio, IR), and instant headless onboarding.

---

## ⚡ Highlights & Key Optimizations

1. **Battle-Tested Bootloader**
   - Proven U-Boot SPL written to sector 16 (`8 KiB` offset) with stable DRAM calibration.
   - Boot script directly loads `sun8i-h2-plus-orangepi-zero-interface-board.dtb`, cleanly enabling both auxiliary USB ports, audio output, and IR.

2. **Power Sag & Brownout Protection**
   - The Orange Pi Zero lacks a dedicated PMIC and is prone to brownout resets under quad-core load on standard 5V chargers.
   - Built-in `cpufreq-governor.service` dynamically sets the `ondemand` governor and caps maximum frequency to `1.008 GHz`, preventing voltage drop crashes while preserving snappy performance.

3. **256 MB RAM Safeguards (Zero OOM)**
   - Pre-configured `zram-generator` with 384 MB LZ4 compressed swap in RAM.
   - Optimized kernel VM swappiness (`vm.swappiness = 100`, `vm.vfs_cache_pressure = 50`).

4. **Reliable Headless Networking**
   - Out-of-the-box `systemd-networkd` DHCP for Ethernet (`eth0`) and Wi-Fi (`wlan0`).
   - Integrated DNS fallback (`1.1.1.1 8.8.8.8 9.9.9.9`) to prevent pacman domain resolution timeouts when behind strict or misconfigured consumer routers.
   - Pre-installed Allwinner XR819 wireless driver (`xradio-linux-armv7`) and vendor firmware.

5. **Integrated Diagnostics & Setup**
   - Ships with [`orangepi-config`](https://github.com/Twilight0/orangepi-config) for full TUI and Web-based administration (hardware toggles, Wi-Fi configuration, external storage management, torrent/media stack).

---

## 📥 Downloads & Flashing

Download the latest `.img.zst` from [Releases](https://github.com/Twilight0/orangepi-zero-alarm/releases/latest).

### Flashing with `dd` (Linux / macOS)

```bash
# Decompress and flash directly to your MicroSD card
zstd -dc orangepi-zero-alarm-*.img.zst | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```
*(Replace `/dev/sdX` with your actual MicroSD card device node, e.g. `/dev/sdb` or `/dev/mmcblk0`)*

### Flashing with GUI Tools (Windows / macOS / Linux)
You can decompress `orangepi-zero-alarm-*.img.zst` using [7-Zip](https://www.7-zip.org/) or `zstd -d` and flash the `.img` using **Raspberry Pi Imager** or **balenaEtcher**.

---

## 🔑 Default Credentials

| User | Password | SSH Access | Sudo Privileges |
| :--- | :--- | :--- | :--- |
| **`root`** | `root` | Yes (PermitRootLogin enabled) | Full root |
| **`alarm`** | `alarm` | Yes | Member of `wheel` |

---

## 🛠️ Building Locally

You can reproduce the exact image on any Linux host with QEMU ARM user emulation:

```bash
# Install prerequisites (Arch Linux host example)
sudo pacman -S qemu-user-static binfmt-support parted e2fsprogs uboot-tools zstd wget

# Or on Ubuntu/Debian:
# sudo apt install qemu-user-static binfmt-support parted e2fsprogs u-boot-tools zstd libarchive-tools wget

# Clone repository
git clone https://github.com/Twilight0/orangepi-zero-alarm.git
cd orangepi-zero-alarm

# Run builder
sudo ./scripts/build-image.sh
```

---

## 📂 Repository Layout

```text
orangepi-zero-alarm/
├── .github/workflows/
│   └── build.yml               # Weekly automated GitHub Actions CI & Release workflow
├── bootloader/
│   └── u-boot-sunxi-with-spl.bin # Proven stable U-Boot SPL binary
├── configs/
│   ├── boot.cmd                # U-Boot boot script source (DTB & cmdline)
│   ├── fstab                   # Mount by label OPIZERO
│   ├── cpufreq-governor.service # Power stability governor & clock ceiling
│   ├── zram-generator.conf     # 384 MB LZ4 ZRAM swap
│   ├── 99-zram.conf            # VM memory tuning
│   ├── permit-root.conf        # SSH initial root onboarding
│   ├── network/                # systemd-networkd configurations
│   └── firmware/xr819/         # Allwinner XR819 Wi-Fi firmware
└── scripts/
    ├── build-image.sh          # Partitioning, formatting, loopback, extraction, compression
    └── chroot-setup.sh         # QEMU armv7h package installation and configuration
```

---

## 📄 License

GPL-3.0 License. See [LICENSE](file:///home/twilight/Projects/orangepi-zero-alarm/LICENSE) for details.
