#!/usr/bin/env python3
"""Assemble local upgrade files; this program never connects to or flashes a device."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('backup', type=Path, help='Verified 16 MiB current SPI backup (private)')
p.add_argument('artifacts', type=Path)
p.add_argument('--wifi-mac', required=True, help='Saved device Wi-Fi MAC, provisioned only in local DTB')
a = p.parse_args()
os.umask(0o077)
out = a.artifacts
original = a.backup.read_bytes()
assert len(original) == 0x1000000, 'Expected complete 16 MiB SPI dump'
kernel = (out / 'uImage').read_bytes()
root = (out / 'uInitrd').read_bytes()
assert kernel[:4] == bytes.fromhex('27051956') and len(kernel) <= 0x400000
assert root[:4] == bytes.fromhex('27051956') and len(root) <= 0x9e0000
for data in (kernel, root):
    assert struct.unpack_from('>I', data, 12)[0] + 64 == len(data)

# Keep partition order and the user's original 0xe80000 address unchanged.
board = out / 'board-4m.dtb'
board.write_bytes((out / 'board.dtb').read_bytes())
mac = bytes.fromhex(a.wifi_mac.replace(':', ''))
assert len(mac) == 6 and not mac[0] & 1 and any(mac), 'Invalid Wi-Fi MAC'
subprocess.run(['fdtput', '-t', 'bx', str(board), '/soc/mmc@1c10000/wifi@1',
                'local-mac-address', *[f'{b:02x}' for b in mac]], check=True)
# Prevent old U-Boot from replacing the provisioned MAC with eth1addr.
subprocess.run(['fdtput', '-d', str(board), '/aliases', 'ethernet1'], check=True)

base = '/soc/spi@1c68000/flash@0/partitions'
subprocess.run(['fdtput', '-t', 'x', str(board), base + '/partition@a0000', 'reg', 'a0000', '400000'], check=True)
subprocess.run(['fdtput', '-t', 'x', str(board), base + '/partition@3a0000', 'reg', '4a0000', '9e0000'], check=True)
dts = out / 'board-4m.dts'
subprocess.run(['dtc', '-q', '-I', 'dtb', '-O', 'dts', '-o', str(dts), str(board)], check=True)
dts.write_text(dts.read_text().replace('partition@3a0000 {', 'partition@4a0000 {'))
subprocess.run(['dtc', '-q', '-I', 'dts', '-O', 'dtb', '-o', str(board), str(dts)], check=True)
assert board.stat().st_size <= 0x10000

cmd = out / 'boot-mainline.cmd'
cmd.write_text(f'''echo miZy Linux 6.12.113 mainline boot
setenv bootm_boot_mode nonsec
# Keep the 7 MiB legacy initrd at its safe load address, above the kernel.
setenv initrd_high 0xffffffff
setenv bootargs 'itype=openwrt root=/dev/ram0 rootfstype=squashfs rw ramdisk_size=16384 ip=off console=ttyS0,115200 earlycon=uart8250,mmio32,0x01c28000 loglevel=5 panic=10 bootfrom=spi loadfrom=spi'
spiread.hd 0x43000000 90000 {board.stat().st_size}
spiread.hd 0x42000000 a0000 {len(kernel)}
spiread.hd 0x44000000 4a0000 {len(root)}
bootm 0x42000000 0x44000000 0x43000000
''')
script = out / 'boot-mainline.scr'
subprocess.run(['mkimage', '-A', 'arm', '-O', 'linux', '-T', 'script', '-C', 'none', '-n', 'miZy mainline SPI boot', '-d', str(cmd), str(script)], check=True)
assert script.stat().st_size <= 8192
image = bytearray(original)
image[0x80000:0xe80000] = b'\xff' * 0xe00000
for offset, data in [(0x80000, script.read_bytes()), (0x90000, board.read_bytes()), (0xa0000, kernel), (0x4a0000, root)]:
    image[offset:offset+len(data)] = data
assert image[:0x80000] == original[:0x80000]
assert image[0xe80000:] == original[0xe80000:]
files = {
    'spi-mainline-candidate.bin': bytes(image),
    'kernel-old-slot.bin': bytes(image[0xa0000:0x3a0000]),
    'initrd-old-slot.bin': bytes(image[0x3a0000:0x4a0000+len(root)]),
}
manifest = {
    'kernel': '6.12.113-mizy-h2plus',
    'hardware_verified': False,
    'bootloader_preserved': True,
    'user_partition_preserved': True,
    'backup_sha256': hashlib.sha256(original).hexdigest(),
    'files': {},
}
for name, data in files.items():
    (out / name).write_bytes(data)
    manifest['files'][name] = {'size': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
(out / 'spi-candidate-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(json.dumps(manifest, indent=2))
