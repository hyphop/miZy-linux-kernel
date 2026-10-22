# Orange Pi Zero H2+ mainline bring-up

This build has been installed on the H2+ device and passed automatic SPI reboot,
XR819 Wi-Fi, DHCP, DNS and HTTPS proxy tests. It keeps miZy's
userspace rather than installing Armbian. See the parent project's status record
for actual hardware test results.

## Inputs

- Linux 6.12.113 LTS, pinned by SHA-256 in `prepare.sh`.
- fifteenhex/xradio commit `3ce657ae533e2213f6fda2297da1598fa11d7a03`, also hash-checked.
- The XR819 interrupt/device-tree adjustment used by Armbian, bundled as a patch.
- Original miZy squashfs extracted locally from a verified SPI backup; it is not
  distributed in this repository and can contain device-specific information.

The tested build environment is Ubuntu 24.04 ARM64 with GCC 13.3's
`arm-linux-gnueabihf` cross compiler. `Containerfile` lists the dependencies. Keep
sources and the build directory on the container's native, case-sensitive Linux
filesystem; use the `/workspace` bind mount only for scripts and output.

## Build

From the parent miZy fork, mount that checkout at `/workspace` in the container.
The following commands are run **inside** the prepared container:

```sh
bash /workspace/kernel/mainline/prepare.sh
bash /workspace/kernel/mainline/build.sh
```

To package the existing miZy rootfs, first supply its squashfs payload at
`/workspace/build/downloads/mizy-original-rootfs.bin`. The SPI `initrd` partition
has a 64-byte uImage header before the squashfs; verify the image length/header
before extracting it. Then run:

```sh
unsquashfs -d /work/mizy-rootfs /workspace/build/downloads/mizy-original-rootfs.bin
bash /workspace/kernel/mainline/package-rootfs.sh
python3 /workspace/kernel/mainline/pack-ram.py /workspace/build/artifacts
```

These build commands do not flash the device. Outputs and local backups belong
under the ignored `build/` directory, never in git.

## Changes needed alongside the kernel

- Add XR819 and matching cfg80211/mac80211 modules; never reuse 3.4 modules.
- Enable SPI NOR, JFFS2, squashfs, RAM disks, TUN and legacy iptables support.
- Replace the old overlayfs mount syntax with modern `overlay` plus a workdir.
- Use device-tree power/interrupt setup instead of legacy Wi-Fi GPIO/register
  writes; keep the saved miZy Wi-Fi credentials and DHCP callback.
- Disable the legacy direct CPU/DRAM register initialization in mainline mode.
- Recompress the preserved miZy userspace with xz rather than lzo.

The first successful build produced a 3.64 MiB uImage and a 7.01 MiB uInitrd.
They fit a proposed 4 MiB kernel slot and the remaining initrd area while keeping
the user partition at its original address. The current `board-spi.dtsi` retains
**the original layout for read-only RAM testing**; it must not be used as the
permanent resized-layout DTB.

## RAM test

`pack-ram.py` combines legacy uImage, uInitrd and DTB at aligned addresses,
recorded in `ram-legacy.json`. The installed U-Boot does not support FIT images.
The bootstrap reads the original squashfs and saved user JFFS2 partition without
modifying SPI. It imports saved settings before mounting OverlayFS, with mainline
files as a separate lower layer. JFFS2 needs LZO compression and 64 KiB SPI erase
blocks to read the existing filesystem. The bootstrap includes its dynamic loader,
libgcc and serial device nodes.

`ymodem-upload.py IMAGE` uploads to U-Boot at RAM address `0x48000000` and runs
`iminfo`. It does not boot or flash the image. It currently targets the macOS
serial path `/dev/cu.usbserial-1110` at 115200 baud. Close other serial clients
before using it.

Do not write SPI until the RAM test has verified boot, Wi-Fi, DHCP, DNS, proxy
requests and the reverse SSH tunnel. Keep the original bootloader and a verified
full SPI backup available for recovery.

## Assemble a private SPI candidate

After the build, `assemble-spi.py BACKUP ARTIFACTS --wifi-mac DEVICE_MAC` creates a resized-layout DTB,
boot script, full candidate and payload files sized for the original MTD slots.
It checks that U-Boot and the saved user partition remain byte-identical to the
backup. The full candidate contains the backup's private configuration and must
remain outside git. Assembly alone is **not** evidence of hardware compatibility.

## Hardware results (2026-10-21)

Linux 6.12.113 booted on all four H2+ cores, entered miZy procd, read the original
saved JFFS2 overlay, and connected XR819 to WPA2 Wi-Fi with DHCP and DNS. An HTTPS
request through the reverse SSH relay returned CONNECT 200 and HTTPS 200.
Disable the old Wi-Fi hotplug restart hook and explicitly load the crypto modules:
the legacy modprobe does not resolve their algorithm aliases. The permanent DTB
provisions the saved MAC before interface registration and removes the ethernet1
alias so old U-Boot cannot overwrite it. A legacy squashfs initrd uses chroot for
its init handoff; only the cpio RAM bootstrap uses switch_root.

The final SPI image also passed unattended software reboot and the same network
and HTTPS relay checks. The boot script must set initrd_high=0xffffffff, and the
legacy root init must use /mnt/user (the squashfs root is read-only). A separate
physical power-cycle test after the final fixes has not been recorded.

## Experimental XR819 fixes

The default remains the pinned upstream driver. To build the two individually
reviewed, unmerged fixes (#31 data-cipher preservation and #34 HT RX metadata),
run `XRADIO_FIXES=1 bash /workspace/kernel/mainline/build.sh`. Setting
`XRADIO_FIXES=0` restores the baseline source state, including when reusing the
same build directory. Patch headers retain upstream author and commit IDs.

For live testing, transfer the matching xradio_wlan.ko to /tmp, keep a baseline
module and UART shell, stop wpa_supplicant/wpa_cli and the wlan0 udhcpc PID, unload
xradio_wlan, load the candidate with insmod, and run /opt/mainline-wifi. Remove
the old DHCP pidfile so the reconnect callback acquires a lease on the recreated
interface. Loading a candidate into RAM does not persist it; reboot loads the
unchanged baseline from SPI. See XR819-STATUS.md for measured results.

## Interrupt diagnostics and firmware

See [XR819-IRQ.md](XR819-IRQ.md) for GPIO/native SDIO/HT/firmware comparisons,
measured limits, and the selected firmware/HT RX/diagnostic build flags.
`XRADIO_HT_RX_FIX=1` selects #34 separately from #31. Set
`XRADIO_IRQ_DIAGNOSTICS=1` for IRQ-vs-watchdog race counters and correct warning
classification; `XRADIO_IRQ_EXPERIMENT=1` additionally builds optional native SDIO
and HT-disable module parameters. All remain off by default.
`XRADIO_FIRMWARE_FILE` supplies the explicitly hash-checked .52.58 firmware to
package-rootfs.sh; omitting it restores the original firmware on a reused root.

## Saturation diagnostics and retry-budget experiment

`XRADIO_LOAD_DIAGNOSTICS=1` adds read-only host-queue and firmware TX timing,
expiry, retry-exhaustion, and other confirmation-status counters. It is
independent of IRQ diagnostics and defaults off.

`XRADIO_RETRY_EXPERIMENT=1` raises the firmware short/long retry ceilings from
the default 7-attempt configuration to 15 attempts. It preserves rate selection
and the rate-policy termination flag: packets may stop earlier when their policy
is exhausted. It defaults off and is an experiment, with a possible latency and
airtime tradeoff. See XR819-LOAD.md for the hardware comparison and limitations.
