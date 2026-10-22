#!/bin/bash
set -euo pipefail
VERSION=6.12.113
XRADIO_COMMIT=3ce657ae533e2213f6fda2297da1598fa11d7a03
WORK=${WORK:-/work}
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$WORK/linux-$VERSION
OUT=$WORK/kernel-build
DEST=${DEST:-/workspace/build/artifacts}
export ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
mkdir -p "$OUT" "$DEST"
if [ ! -f "$SRC/.mizy-patched" ]; then
    mkdir -p "$SRC/drivers/net/wireless/xradio"
    cp "$WORK/xradio-$XRADIO_COMMIT/"*.{c,h} "$SRC/drivers/net/wireless/xradio/"
    cp "$WORK/xradio-$XRADIO_COMMIT/Makefile" "$WORK/xradio-$XRADIO_COMMIT/Kconfig" "$SRC/drivers/net/wireless/xradio/"
    sed -i 's/---help---/help/g' "$SRC/drivers/net/wireless/xradio/Kconfig"
    printf '\nobj-$(CONFIG_XRADIO) += xradio/\n' >> "$SRC/drivers/net/wireless/Makefile"
    printf '\nsource "drivers/net/wireless/xradio/Kconfig"\n' >> "$SRC/drivers/net/wireless/Kconfig"
    patch -d "$SRC" -p1 < "$HERE/patches/0001-xradio-dts.patch"
    cat "$HERE/board-spi.dtsi" >> "$SRC/arch/arm/boot/dts/allwinner/sun8i-h2-plus-orangepi-zero.dts"
    touch "$SRC/.mizy-patched"
fi
# Experiments remain opt-in and can be reversed in a reused source directory.
XRADIO_FIXES=${XRADIO_FIXES:-0}
XRADIO_IRQ_EXPERIMENT=${XRADIO_IRQ_EXPERIMENT:-0}
XRADIO_HT_RX_FIX=${XRADIO_HT_RX_FIX:-$XRADIO_FIXES}
XRADIO_IRQ_DIAGNOSTICS=${XRADIO_IRQ_DIAGNOSTICS:-$XRADIO_IRQ_EXPERIMENT}
XRADIO_LOAD_DIAGNOSTICS=${XRADIO_LOAD_DIAGNOSTICS:-0}
XRADIO_RETRY_EXPERIMENT=${XRADIO_RETRY_EXPERIMENT:-0}
for value in "$XRADIO_FIXES" "$XRADIO_IRQ_EXPERIMENT" "$XRADIO_HT_RX_FIX" "$XRADIO_IRQ_DIAGNOSTICS" "$XRADIO_LOAD_DIAGNOSTICS" "$XRADIO_RETRY_EXPERIMENT"; do
    case "$value" in 0|1) ;; *) echo 'XRADIO experiment flags must be 0 or 1' >&2; exit 1;; esac
done
set_driver_patch() {
    local fix=$1 enabled=$2 driver_dir="$SRC/drivers/net/wireless/xradio"
    if patch --dry-run -s -d "$driver_dir" -p1 -N < "$HERE/patches/$fix" >/dev/null 2>&1; then
        [ "$enabled" = 0 ] || patch -s -d "$driver_dir" -p1 < "$HERE/patches/$fix"
    elif patch --dry-run -s -d "$driver_dir" -p1 -R < "$HERE/patches/$fix" >/dev/null 2>&1; then
        [ "$enabled" = 1 ] || patch -s -d "$driver_dir" -p1 -R < "$HERE/patches/$fix"
    else
        echo "Cannot identify driver patch state: $fix" >&2
        exit 1
    fi
}
set_driver_patch 0031-xradio-preserve-data-cipher.patch "$XRADIO_FIXES"
set_driver_patch 0034-xradio-ht-rx-encoding.patch "$XRADIO_HT_RX_FIX"
set_driver_patch 0040-xradio-irq-diagnostics.patch "$XRADIO_IRQ_DIAGNOSTICS"
set_driver_patch 0041-xradio-native-sdio-irq.patch "$XRADIO_IRQ_EXPERIMENT"
set_driver_patch 0042-xradio-optional-disable-ht.patch "$XRADIO_IRQ_EXPERIMENT"
set_driver_patch 0043-xradio-load-diagnostics.patch "$XRADIO_LOAD_DIAGNOSTICS"
set_driver_patch 0044-xradio-experiment-retry-budget.patch "$XRADIO_RETRY_EXPERIMENT"
make -C "$SRC" O="$OUT" sunxi_defconfig
CFG="$SRC/scripts/config --file $OUT/.config"
for name in DRM FB MEDIA_SUPPORT SOUND SND CAN ATA IIO RC_CORE STAGING INPUT_TOUCHSCREEN INPUT_MISC SERIO PERF_EVENTS DEBUG_INFO CORESIGHT HW_RANDOM MTD_SPI_NOR_USE_4K_SECTORS; do
    $CFG --disable "$name"
done
for name in BLK_DEV_LOOP BLK_DEV_RAM BLK_DEV_INITRD SQUASHFS SQUASHFS_XZ SQUASHFS_ZLIB SQUASHFS_LZO OVERLAY_FS TMPFS TMPFS_XATTR DEVTMPFS DEVTMPFS_MOUNT MTD MTD_SPI_NOR MTD_BLOCK MTD_CMDLINE_PARTS MTD_OF_PARTS JFFS2_FS JFFS2_FS_WRITEBUFFER JFFS2_COMPRESSION_OPTIONS JFFS2_LZO PROC_FS SYSFS DEBUG_FS UNIX98_PTYS DEVPTS_MULTIPLE_INSTANCES INOTIFY_USER EPOLL SIGNALFD TIMERFD EVENTFD NETFILTER NETFILTER_XTABLES NETFILTER_XT_MATCH_STATE NETFILTER_XT_MATCH_CONNTRACK NETFILTER_XT_MATCH_TCPUDP NETFILTER_XT_TARGET_MASQUERADE NF_CONNTRACK NF_NAT NF_DEFRAG_IPV4 IP_NF_IPTABLES IP_NF_FILTER IP_NF_NAT NETFILTER_XT_TARGET_REJECT NETFILTER_XT_MATCH_COMMENT WIRELESS WLAN CFG80211_WEXT WEXT_CORE WEXT_PROC WEXT_PRIV CGROUPS CGROUP_CPUACCT CGROUP_FREEZER CGROUP_SCHED CPUSETS MEMCG VETH BRIDGE NETFILTER_XT_MATCH_PHYSDEV STMMAC_ETH STMMAC_PLATFORM DWMAC_SUN8I MMC MMC_SUNXI MMC_PWRSEQ_SIMPLE REGULATOR_FIXED_VOLTAGE TUN IKCONFIG IKCONFIG_PROC ARM_PSCI CPU_IDLE ARM_CPUIDLE; do
    $CFG --enable "$name"
done
for name in CFG80211 MAC80211 XRADIO USB_ETH; do $CFG --module "$name"; done
$CFG --set-val BLK_DEV_RAM_SIZE 16384 --set-val NR_CPUS 4
$CFG --set-str LOCALVERSION '-mizy-h2plus' --disable LOCALVERSION_AUTO
$CFG --set-str MODPROBE_PATH '/usr/sbin/modprobe'
$CFG --enable KERNEL_LZMA --disable KERNEL_GZIP
make -C "$SRC" O="$OUT" olddefconfig
make -C "$SRC" O="$OUT" -j6 Image zImage modules allwinner/sun8i-h2-plus-orangepi-zero.dtb > "$DEST/kernel-build.log" 2>&1
make -C "$SRC" O="$OUT" INSTALL_MOD_PATH="$WORK/modules" INSTALL_MOD_STRIP=1 modules_install >> "$DEST/kernel-build.log" 2>&1
cp "$OUT/.config" "$DEST/kernel.config"
cp "$OUT/arch/arm/boot/Image" "$OUT/arch/arm/boot/zImage" "$DEST/"
cp "$OUT/arch/arm/boot/dts/allwinner/sun8i-h2-plus-orangepi-zero.dtb" "$DEST/board.dtb"
xz --format=lzma -9 -c "$DEST/Image" > "$DEST/Image.lzma"
mkimage -A arm -O linux -T kernel -C lzma -a 0x40008000 -e 0x40008000 -n "Linux-$VERSION-mizy-h2plus" -d "$DEST/Image.lzma" "$DEST/uImage"
stat -c '%n %s bytes' "$DEST/uImage" "$DEST/board.dtb"

[ "$(stat -c%s "$DEST/uImage")" -le 4194304 ] || { echo "Kernel exceeds proposed 4 MiB slot" >&2; exit 1; }
[ "$(stat -c%s "$DEST/board.dtb")" -le 65536 ] || { echo "DTB exceeds slot" >&2; exit 1; }
