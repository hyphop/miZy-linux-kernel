# miZy linux kernel 3.4.113+ mod for Orange Pi Zero and other sunxi boards 

[![Build Status](https://travis-ci.com/hyphop/miZy-linux-kernel.svg?branch=master)](https://travis-ci.com/hyphop/miZy-linux-kernel)

## Features

* Orange Pi Zero optimized kernel
* Orange Pi Zero Plus2 h3 device added
* minimized kernel size, remove unused systems and modules
* MTD + M25P80 build in kernel - onboard SPI-flash linux boot ready
* mmc_spi module simple usage mmc/sd cards via spi 
* h2+ onboard WiFi XR819 - xradio_wlan
* h3+ onboard WiFi AP6212 - dhd
* h3+ onboard MMC ready
* exfat kernel module
* ASIX AX88179_178A USB 3.0/2.0 Gigabit Ethernet Network Adapter kernel module
* one fex/fdt config for both h2+ h3 boards
* hdmi + hdmi_audio as module for h3 board
* build uncompressed kernel + LZMA GZIP LZO NONE compression via mkinitrd packed images
* any LZMA GZIP LZO XZ initrd compression
* some systems builded as modules for more flexibility: i2c, audio, ethernet - sunxi_gmac, ir, other
* easy fast and full automated cross-compilation
* many other improvements


## DEPS

    lzop, gzip, lzma, mkimage 
    
## Get Source Prepare and Build

    mkdir /tmp/zero_builder
    cd /tmp/zero_builder

    git clone https://github.com/hyphop/miZy-linux-kernel.git
    cd miZy-linux-kernel

    ./kernel_prepare
	# ./kernel_config default 
    ./kernel_build_all

## Custom config

    ./kernel_prepare light # arg is config file name => kernel-configs/light
    ./kernel_build_all

## Easy make - by one-line command

    wget http://raw.githubusercontent.com/hyphop/miZy-linux-kernel/master/make_it_easy -O- | sh -

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

## kernel build configs

	# ... prepare
	./kernel_config light
	# or 
	./kernel_config kernel-configs/light
	# ... build

## pack kernel, modules, configs, ... and other files by packages

	kernel_build_packages default 
	# generate packages
	find /tmp/miZy.linux.kernel.default

```
/tmp/miZy.linux.kernel.default
/tmp/miZy.linux.kernel.default/miZy.linux.kernel.default.md5sum
/tmp/miZy.linux.kernel.default/miZy.linux.kernel.default.config.gz
/tmp/miZy.linux.kernel.default/miZy.linux.kernel.default.config
/tmp/miZy.linux.kernel.default/miZy.linux.kernel.default.modules.full.tar.gz
/tmp/miZy.linux.kernel.default/miZy.linux.kernel.default.modules.all.tar.gz
/tmp/miZy.linux.kernel.default/miZy.linux.kernel.default.uImage.none.gz
/tmp/miZy.linux.kernel.default/miZy.linux.kernel.default.uImage.lzo
/tmp/miZy.linux.kernel.default/miZy.linux.kernel.default.uImage.lzma
/tmp/miZy.linux.kernel.default/miZy.linux.kernel.default.uImage.gzip
/tmp/miZy.linux.kernel.default/miZy.linux.kernel.default.Image.gz
/tmp/miZy.linux.kernel.default/miZy.linux.kernel.default.modules.meta.tar.gz
```	

## Example u-boot mkimage packed kernel load script

    ...
    # setenv kernel_file	"/boot/uImage.none"
    # setenv kernel_file	"/boot/uImage.lzo"
    # setenv kernel_file	"/boot/uImage.gzip"
    setenv kernel_file	"/boot/uImage.lzma"
    ...
    load mmc ${mmc_boot_part} ${kernel_addr_r} ${kernel_file}
    ...
    bootm ${kernel_addr_r} ${ramdisk_addr_r}
    ...

## Deps and cross compilation

* toolchain-arm_cortex-a9+neon_gcc-5.3.0_musl-1.1.15_eabi
* squashfs, overlayfs | aufs
* perl, u-boot-tools

its easy and automated by scripts!

## Building in vm

safe compilation in vm, https://github.com/hyphop/miZy-builder

## Download compiled kernel and modules

https://github.com/hyphop/miZy-linux-kernel/releases

examples
	
	# get kernel
	wget https://github.com/hyphop/miZy-linux-kernel/releases/download/light/miZy.linux.kernel.light.uImage.gzip -O uImage.gzip
	
	# get modules
	wget https://github.com/hyphop/miZy-linux-kernel/releases/download/light/miZy.linux.kernel.light.modules.all.tar.gz -O /tmp/modules.tar.gz
	#
	# show modules list
	tar -tf /tmp/modules.tar.gz
	#
	# extract one 
	tar -xf /tmp/modules.tar.gz modules.all/sndspdif.ko -O > sndspdif.ko
	 
	# show config
	# curl -L https://github.com/hyphop/miZy-linux-kernel/releases/download/light/miZy.linux.kernel.light.config
	
## miZy 
 
miZy - open source minimalistic tiny fast embedded Linux system, (for sunxi Orange Pi Zero, another sunxi boards maybe work too )

## LINKS

- [https://github.com/hyphop/miZy-linux-kernel](https://github.com/hyphop/miZy-linux-kernel)
- [https://github.com/hyphop/miZy-builder](https://github.com/hyphop/miZy-builder)
- [https://github.com/hyphop/miZy-uboot](https://github.com/hyphop/miZy-uboot)
- [https://hyphop.github.io/mizy/](https://hyphop.github.io/mizy/) - miZy - Tiny fast embeded linux

## ;)

![miZy](pics/miZy.logo.bw128x64x2.png)
