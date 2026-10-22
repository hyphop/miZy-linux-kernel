#!/bin/bash
set -euo pipefail
WORK=${WORK:-/work}
VERSION=6.12.113
DRIVER=3ce657ae533e2213f6fda2297da1598fa11d7a03
mkdir -p "$WORK/downloads"
cd "$WORK/downloads"
[ -s linux-$VERSION.tar.xz ] || curl -fL --retry 3 "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$VERSION.tar.xz" -o linux-$VERSION.tar.xz
[ -s xradio.tar.gz ] || curl -fL --retry 3 "https://codeload.github.com/fifteenhex/xradio/tar.gz/$DRIVER" -o xradio.tar.gz
printf '%s\n' \
 'e09b6727e5c521253f0d41694900b9c38fb7604db7d35238a8197aa9f7de2428  linux-6.12.113.tar.xz' \
 '107ad93e861c426eb6a5e0a40fce12f4a4f8d1712e02fcc15b29a3396989acc6  xradio.tar.gz' | sha256sum -c -
[ -d "$WORK/linux-$VERSION" ] || tar -xf linux-$VERSION.tar.xz -C "$WORK"
[ -d "$WORK/xradio-$DRIVER" ] || tar -xf xradio.tar.gz -C "$WORK"
