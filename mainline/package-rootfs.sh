#!/bin/bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=${WORK:-/work}
ART=/workspace/build/artifacts
KREL=6.12.113-mizy-h2plus
PATCH=$WORK/mainline-overlay
BOOT=$WORK/bootstrap
ROOT=$WORK/mizy-mainline-rootfs
mkdir -p "$PATCH/opt" "$PATCH/etc" "$PATCH/lib/modules/$KREL" "$BOOT/bin" "$BOOT/lib" "$BOOT/dev" "$BOOT/proc" "$BOOT/sys"
# Optional, pinned public firmware update. Never commit binary images or provisioned roots.
if [ -n "${XRADIO_FIRMWARE_FILE:-}" ]; then
    expected_fw=fb81436ad7cc0876614a2a9c2a54c5a93a75315aee164e3a3afe3db80842a9e1
    [ "$(sha256sum "$XRADIO_FIRMWARE_FILE" | cut -d' ' -f1)" = "$expected_fw" ] || {
        echo 'Unexpected XR819 firmware SHA-256' >&2; exit 1;
    }
    mkdir -p "$PATCH/lib/firmware/xr819"
    cp "$XRADIO_FIRMWARE_FILE" "$PATCH/lib/firmware/xr819/fw_xr819.bin"
else
    rm -f "$PATCH/lib/firmware/xr819/fw_xr819.bin"
fi
cp "$HERE/rootfs/mainline-wifi" "$HERE/rootfs/mainline-prepare" "$PATCH/opt/"
cp "$HERE/rootfs/preinit.mizy" "$PATCH/etc/"
find "$WORK/modules/lib/modules/$KREL" -name '*.ko' -exec cp '{}' "$PATCH/lib/modules/$KREL/" \;
chmod 755 "$PATCH/opt/"* "$PATCH/etc/preinit.mizy"
[ -c "$BOOT/dev/console" ] || mknod -m 600 "$BOOT/dev/console" c 5 1
[ -c "$BOOT/dev/null" ] || mknod -m 666 "$BOOT/dev/null" c 1 3
cp "$WORK/mizy-rootfs/bin/busybox" "$BOOT/bin/"
cp "$WORK/mizy-rootfs/lib/libc.so" "$WORK/mizy-rootfs/lib/libgcc_s.so.1" "$BOOT/lib/"
ln -sf libc.so "$BOOT/lib/ld-musl-armhf.so.1"
for cmd in sh mount mkdir cp sleep switch_root; do ln -sf busybox "$BOOT/bin/$cmd"; done
cp "$HERE/bootstrap-init" "$BOOT/init"
chmod 755 "$BOOT/init"
mkdir -p "$BOOT/mizy-overlay"
cp -a "$PATCH/." "$BOOT/mizy-overlay/"
(cd "$BOOT"; find . -print0 | cpio --null -o -H newc --owner=0:0 2>/dev/null | gzip -9) > "$ART/bootstrap.cpio.gz"
mkimage -A arm -O linux -T ramdisk -C gzip -n 'miZy mainline RAM bootstrap' -d "$ART/bootstrap.cpio.gz" "$ART/bootstrap.uInitrd"
mkdir -p "$ROOT"
cp -a "$WORK/mizy-rootfs/." "$ROOT/"
# Old kernel modules cannot run on the new kernel. All userspace is retained.
find "$ROOT/lib/modules" -mindepth 1 -maxdepth 1 -exec rm -rf '{}' \;
cp -a "$PATCH/." "$ROOT/"
cp "$HERE/rootfs/init" "$ROOT/init"
chmod 755 "$ROOT/init"
mksquashfs "$ROOT" "$ART/rootfs.squashfs" -noappend -comp xz -b 262144 -processors 4 > "$ART/rootfs-build.log"
mkimage -A arm -O linux -T ramdisk -C none -a 0x44000000 -e 0x44000000 -n 'miZy mainline rootfs' -d "$ART/rootfs.squashfs" "$ART/uInitrd"
stat -c '%n %s bytes' "$ART/bootstrap.uInitrd" "$ART/uInitrd"

[ "$(stat -c%s "$ART/uInitrd")" -le 10354688 ] || { echo "Rootfs exceeds proposed initrd slot" >&2; exit 1; }
