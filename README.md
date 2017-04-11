# miZy linux kernel 3.4.113+ mod for Orange Pi Zero and other sunxi boards 

## Features

* optimized for Orange Pi Zero board
* easy fast and full automated cross-compile buiding system
* minimized size, remove unused systems and modules
* MTD + M25P80 buildin kernel - enable onboard SPI flash boot ready
* onboard WiFi xr819 - xradio_wlan
* build uncompressed kernel + LZMA GZIP LZO NONE compression via mkinitrd packed images
* any LZMA GZIP LZO XZ initrd compression
* some systems builded as modules for more flexibility: i2c, audio, ethernet - sunxi_gmac, ir, other
    
## Get Source Prepare and Build & Clear

    mkdir /tmp/zero_builder
    cd /tmp/zero_builder

    git clone https://github.com/hyphop/miZy-linux-kernel.git
    cd miZy-linux-kernel

    ./kernel_prepare
    ./kernel_build_all

## output kernel

    ./bin
        Image           - unpacked kernel 
        uImage.gzip     - uboot gzip kernel image
        uImage.lzma     - uboot lzma kernel image, max compression, slow unpack time
        uImage.lzo      - uboot lzo  kernel image, fastest unpack time 
        uImage.none     - uboot none kernel image

## output modules

    ./bin
        modules         - full 
        modules.all     - all in one dir
        modules.links   - all in one dir symlinks

## Clear

    ./kernel_clear_all

## Deps and cross compilation

* squashfs, overlayfs | aufs
* toolchain-arm_cortex-a9+neon_gcc-5.3.0_musl-1.1.15_eabi

its easy and automated by scripts!

## Building in vm

safe compilation in vm, https://github.com/hyphop/miZy-builder

## miZy 
 
miZy - open source minimalistic tiny fast embedded Linux system, (for sunxi Orange Pi Zero, another sunxi boards maybe work too )

## LINKS

- [https://github.com/hyphop/miZy-linux-kernel](https://github.com/hyphop/miZy-linux-kernel)
- [https://github.com/hyphop/miZy-builder](https://github.com/hyphop/miZy-builder)
- [https://github.com/hyphop/miZy-uboot](https://github.com/hyphop/miZy-uboot)
- [https://hyphop.github.io/mizy/](https://hyphop.github.io/mizy/)

## ;)

![miZy](pics/miZy.logo.bw128x64x2.png)
