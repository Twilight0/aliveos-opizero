# Orange Pi Zero Minimal Arch Linux ARM Image Builder & Weekly CI

[![Build AliveOS Orange Pi Zero Image](https://github.com/Twilight0/aliveos-opizero/actions/workflows/build.yml/badge.svg)](https://github.com/Twilight0/aliveos-opizero/actions/workflows/build.yml)
[![Latest Release](https://img.shields.io/github/v/release/Twilight0/aliveos-opizero?include_prereleases&color=orange)](https://github.com/Twilight0/aliveos-opizero/releases/latest)

An ultra-lean, rock-solid **Arch Linux ARM** system image for the **Orange Pi Zero (Allwinner H2+)**, built and released weekly via GitHub Actions.

Designed from the ground up for maximum power stability, zero OOM crashes on the **256 MB RAM** variant, full interface daughterboard expansion (extra USB ports, 3.5mm audio, IR), and instant headless onboarding.

---

## ⚡ Highlights & Key Features

1. **Battle-Tested Bootloader & SPL**
   - Proven U-Boot SPL written to sector 16 (`8 KiB` offset) with stable DRAM calibration.
   - Boot script directly loads `sun8i-h2-plus-orangepi-zero-interface-board.dtb`, cleanly enabling both auxiliary USB ports, audio output, and IR.

2. **Power Sag & Brownout Protection**
   - The Orange Pi Zero lacks a dedicated PMIC and is prone to brownout resets under quad-core load on standard 5V chargers.
   - Built-in `cpufreq-governor.service` dynamically sets the `ondemand` governor and caps maximum frequency to `1.008 GHz`, preventing voltage drop crashes while preserving snappy performance.

3. **256 MB & 512 MB Dynamic RAM Support (Zero OOM)**
   - Automatic DRAM geometry auto-detection in U-Boot SPL (supports both 256 MB and 512 MB models out-of-the-box).
   - Pre-configured `zram-generator` with dynamic scaling (`min(ram * 1.5, 512)`): 384 MB ZRAM for 256 MB boards, 512 MB ZRAM for 512 MB boards.
   - Tuned kernel VM swappiness (`vm.swappiness = 100`, `vm.vfs_cache_pressure = 50`).

4. **First-Boot Auto-Resize**
   - Built-in one-shot `orangepi-resize-rootfs.service` automatically expands the root partition to 100% of your MicroSD card and resizes the ext4 filesystem online.

5. **ZeroConf / mDNS Discovery (`orangepi-zero.local`)**
   - Pre-configured `avahi-daemon` and `nss-mdns` allow immediate access without checking router DHCP tables.

6. **Reliable Headless Networking**
   - Out-of-the-box `systemd-networkd` DHCP for Ethernet (`eth0`) and Wi-Fi (`wlan0`).
   - Integrated DNS fallback (`1.1.1.1 8.8.8.8 9.9.9.9`) to prevent pacman domain resolution timeouts when behind strict or misconfigured consumer routers.
   - Pre-installed Allwinner XR819 wireless driver (`xradio-linux-armv7`) and vendor firmware.

---

## 📥 Downloads & Flashing

Download the latest `.img.zst` from [Releases](https://github.com/Twilight0/aliveos-opizero/releases/latest).

### Flashing with `dd` (Linux / macOS)

```bash
# Decompress and flash directly to your MicroSD card
zstd -dc aliveos-orangepi-zero-*.img.zst | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```
*(Replace `/dev/sdX` with your actual MicroSD card device node, e.g. `/dev/sdb` or `/dev/mmcblk0`)*

### Flashing with GUI Tools (Windows / macOS / Linux)
You can decompress `aliveos-orangepi-zero-*.img.zst` using [7-Zip](https://www.7-zip.org/) or `zstd -d` and flash the `.img` using **Raspberry Pi Imager** or **balenaEtcher**.

---

## 🌐 Connecting with Avahi / nss-mdns (`orangepi-zero.local`)

Thanks to pre-installed `avahi-daemon` and `nss-mdns`, the board broadcasts its hostname as **`orangepi-zero.local`** via multicast DNS. You do **not** need to look up the board's IP address in your router.

### 1. SSH Access
Simply connect using the `.local` domain:
```bash
ssh root@orangepi-zero.local
```
*(Or use standard user: `ssh alarm@orangepi-zero.local`)*

### 2. Web Configuration TUI
Open your web browser and navigate to:
```text
http://orangepi-zero.local:46363
```
This opens the browser-accessible terminal session of `orangepi-config`.

### Client Compatibility Notes:
* **Linux:** Ensure `avahi-daemon` or `systemd-resolved` is running on your machine.
* **macOS / iOS:** Works natively out of the box via Bonjour.
* **Windows 10 / 11:** Works natively out of the box with the built-in Windows mDNS resolver.

---

## 🔑 Default Credentials

| User | Password | SSH Access | Sudo Privileges |
| :--- | :--- | :--- | :--- |
| **`root`** | `root` | Yes (`PermitRootLogin yes` enabled) | Full root |
| **`alarm`** | `alarm` | Yes | Member of `wheel` (`ALL=(ALL:ALL) ALL`) |

---

## 📦 Pre-Installed Utilities & Software

The image is intentionally stripped of bloat while providing essential tools for headless SBC administration:

| Utility | Purpose |
| :--- | :--- |
| **`orangepi-config` & `ttyd`** | Full TUI and HTTP Web management UI (`http://orangepi-zero.local:46363`, default `admin:admin`) for Wi-Fi, PIA WireGuard VPN, CPU governors, storage, and software catalog. |
| **`avahi` & `nss-mdns`** | ZeroConf / mDNS discovery on local networks (`orangepi-zero.local`). |
| **`usbutils` (`lsusb`)** | Inspect and verify plugged-in USB storage, webcams, printers, and daughterboard ports. |
| **`htop`** | Interactive real-time process, CPU, temperature, and memory monitor. |
| **`tmux`** | Terminal multiplexer to keep persistent sessions alive across network drops. |
| **`dosfstools` & `exfatprogs`** | Native support for formatting and mounting FAT32 and exFAT USB drives. |
| **`wpa_supplicant` & `iw`** | Command-line tools for Wi-Fi scanning and WPA/WPA2/WPA3 network authentication. |
| **`zram-generator`** | Dynamic LZ4 compressed swap in RAM (prevents OOM on 256MB/512MB RAM). |
| **`wireguard-tools` & `jq`** | Kernel WireGuard VPN support + pre-installed PIA `manual-connections` scripts (`/opt/pia-manual-connections`, configurable via `orangepi-config`). |
| **`haveged`** | High-quality entropy daemon for fast boot and SSH key generation. |
| **`xradio-linux-armv7`** | Out-of-tree kernel driver for the Allwinner XR819 wireless chip. |
| **`xr819` firmware** | Vendor firmware files (`boot_xr819.bin`, `fw_xr819.bin`, `sdd_xr819.bin`) installed in `/usr/lib/firmware/xr819/`. |
| **Welcome MOTD** | Interactive login banner displaying CPU temperature, frequency, RAM, ZRAM, storage, and network IPs. |

---

## 🛠️ Building Locally

You can reproduce the exact image on any Linux host with QEMU ARM user emulation:

```bash
# Install prerequisites (Arch Linux host example)
sudo pacman -S qemu-user-static binfmt-support parted e2fsprogs uboot-tools zstd wget

# Or on Ubuntu/Debian:
# sudo apt install qemu-user-static binfmt-support parted e2fsprogs u-boot-tools zstd libarchive-tools wget

# Clone repository
git clone https://github.com/Twilight0/aliveos-opizero.git
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
│   ├── zram-generator.conf     # Dynamic LZ4 ZRAM swap scaling
│   ├── 99-zram.conf            # VM memory tuning
│   ├── permit-root.conf        # SSH initial root onboarding
│   ├── orangepi-resize-rootfs  # First-boot partition expansion script
│   ├── orangepi-resize-rootfs.service # First-boot auto-resize systemd unit
│   ├── 99-orangepi-motd.sh     # Interactive login banner with live telemetry
│   ├── network/                # systemd-networkd configurations
│   └── firmware/xr819/         # Allwinner XR819 Wi-Fi firmware
└── scripts/
    ├── build-image.sh          # Partitioning, formatting, loopback, extraction, compression
    └── chroot-setup.sh         # QEMU armv7h package installation and configuration
```

---

## 📄 License

GPL-3.0 License. See [LICENSE](file:///home/twilight/Projects/orangepi-zero-alarm/LICENSE) for details.
