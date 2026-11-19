#!/bin/bash
#
# Interactive Welcome MOTD for AliveOS (Orange Pi Zero)
#
[ -t 1 ] || return 0

# Colors
C_BOLD="\033[1m"
C_ORANGE="\033[38;5;208m"
C_CYAN="\033[36m"
C_BCYAN="\033[96m"
C_GREEN="\033[32m"
C_RESET="\033[0m"

# Thermal & CPU
TEMP_RAW=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0)
TEMP_C=$((TEMP_RAW / 1000))
FREQ_RAW=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo 0)
FREQ_MHZ=$((FREQ_RAW / 1000))
GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")

# Memory
MEM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
MEM_USED=$(free -m | awk '/^Mem:/{print $3}')
ZRAM_TOTAL=$(free -m | awk '/^Swap:/{print $2}')
ZRAM_USED=$(free -m | awk '/^Swap:/{print $3}')

# Disk
DISK_FREE=$(df -h / | awk 'NR==2{print $4}')
DISK_TOTAL=$(df -h / | awk 'NR==2{print $2}')

# Network IPs
IP_ETH=$(ip -4 addr show eth0 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 || echo "disconnected")
IP_WLAN=$(ip -4 addr show wlan0 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 || echo "disconnected")

echo -e "${C_BOLD}"
echo -e "    ${C_ORANGE}___    ___             ${C_BCYAN}____  _____"
echo -e "   ${C_ORANGE}/   |  / (_)   _____   ${C_BCYAN}/ __ \\/ ___/"
echo -e "  ${C_ORANGE}/ /| | / / / | / / _ \\ ${C_BCYAN}/ / / /\\__ \\ "
echo -e " ${C_ORANGE}/ ___ |/ / /| |/ /  __/${C_BCYAN}/ /_/ /___/ / "
echo -e "${C_ORANGE}/_/  |_/_/_/ |___/\\___/ ${C_BCYAN}\\____//____/  ${C_RESET}"
echo -e ""
echo -e " ${C_BOLD}OS:${C_RESET}       AliveOS Linux (Orange Pi Zero)"
echo -e " ${C_BOLD}Hardware:${C_RESET} Xunlong Orange Pi Zero (Allwinner H2+ Cortex-A7 quad-core)"
echo -e " ${C_BOLD}CPU:${C_RESET}      ${TEMP_C}°C @ ${FREQ_MHZ} MHz (${GOV})"
echo -e " ${C_BOLD}Memory:${C_RESET}   ${MEM_USED}M / ${MEM_TOTAL}M RAM | ${ZRAM_USED}M / ${ZRAM_TOTAL}M ZRAM Swap (LZ4)"
echo -e " ${C_BOLD}Storage:${C_RESET}  ${DISK_FREE} free of ${DISK_TOTAL} rootfs"
echo -e " ${C_BOLD}Network:${C_RESET}  eth0: ${C_GREEN}${IP_ETH}${C_RESET} | wlan0: ${C_GREEN}${IP_WLAN}${C_RESET} | mDNS: ${C_CYAN}aliveos-opizero.local${C_RESET}"
echo -e ""
echo -e " ${C_BOLD}Config:${C_RESET}   Run '${C_BOLD}orangepi-config${C_RESET}' or browse to ${C_CYAN}http://aliveos-opizero.local:46363${C_RESET}"
echo -e ""
