# Orange Pi Zero (Allwinner H2+) direct boot script with power-safe governor
setenv bootargs console=ttyS0,115200 root=/dev/mmcblk0p1 rw rootwait cpufreq.default_governor=ondemand fsck.mode=force fsck.repair=yes panic=10

load mmc 0:1 ${kernel_addr_r} /boot/zImage
load mmc 0:1 ${fdt_addr_r} /boot/dtbs/sun8i-h2-plus-orangepi-zero-interface-board.dtb

bootz ${kernel_addr_r} - ${fdt_addr_r}
