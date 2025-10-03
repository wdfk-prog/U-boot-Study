---
title: '[U-BOOT][STM32]设置使用SD卡中的linux程序启动'
categories:
  - uboot
  - other
tags:
  - uboot
  - other
abbrlink: 3ea297be
date: 2025-10-03 10:57:44
---
@[toc]
![在这里插入图片描述](https://i-blog.csdnimg.cn/direct/242cd5d9768b4b809ff0f8a01c5ceb44.png)


> https://github.com/wdfk-prog/u-boot/tree/art-pi-debug

# 前提
1. 使用SD卡启动linux,可以方便linux的升级
2. 当然SD卡linux去写入flash替换正在运行的linux程序也是可以的

# 操作步骤
## Kconfig配置
1. 打开fat文件系统支持,这一块根据自己SD卡的格式化文件系统去配置.
2. 这里就使用fat32去举例了.
3. SD卡格式化程序可以使用[格式化程序](https://www.sdcard.org/downloads/formatter/sd-memory-card-formatter-for-windows-download/),这个是SD卡协会推荐的格式化程序,暂时没遇见格式化后无法识别的情况.
```c
CONFIG_CMD_FAT=y
CONFIG_FS_FAT=y
```

## env或cli命令实现
1. 可以编译时存入env变量中,直接从`bootmenu`中选择启动SD卡的linux还是flash中烧录的
```c
//stm32h750-art-pi.env
bootmenu_0=load from SD=mmc dev 0;fatload mmc 0 0xC1000000 APT_Pi_Krl.itb.bin; bootm 0xC1000000;
```
2. 这段代码也可以在CLI命令行环境中手动输入执行哦
```c
load from SD=mmc dev 0;fatload mmc 0 0xC1000000 APT_Pi_Krl.itb.bin; bootm 0xC1000000;
```

## 代码解释
### mmc dev 0
1. 设置选中mmc设备.有些板子mmc类型的设备不仅有SD卡,还有EMMC,那就要去选择哪个作为文件系统的索引对象了.(这条命令应该没什么作用)

### fatload mmc 0 0xC1000000 APT_Pi_Krl.itb.bin
1. 这里使用的是.itb文件,是多个文件整合的一起的格式文件.
2. `fatload mmc 0 0xC1000000 `把mmc 0中的这个文件名的程序加载到指定位置.我这里加载到了`mmc 0 0xC1000000 `上.
3. 从DRAM中加载的位置信息来看,0XC438000之前的已经被使用了,如果加载在这里会造成内存冲突.由于我这个DRAM是32MB大小,所以我选择了加载在一块不会冲突的位置上`0xC1000000`临时保存linux程序
```c
//include/configs/stm32h750-art-pi.h
#define CFG_EXTRA_ENV_SETTINGS				\
			"kernel_addr_r=0xC0008000\0"		\
			"fdtfile=stm32h750i-art-pi.dtb\0"	\
			"fdt_addr_r=0xC0408000\0"		\
			"scriptaddr=0xC0418000\0"		\
			"pxefile_addr_r=0xC0428000\0" \
			"ramdisk_addr_r=0xC0438000\0"		\
```

### bootm 0xC1000000
1.使用bootm命令从指定位置加载程序
2.bootm会识别不同格式文件并进行引导执行
3.否则需要各个文件分开引导,例如ramdisk,fdt,zimage文件分开引导到不同的地址上.

# 日志现象
1. 可以看到我是通过user按键启动了bootmenu命令
2. 选择了`load from SD`执行SD程序加载
3.  Loading kernel (any) from FIT Image at c1000000,搬运到了`0xc0080000`
4. ramdsik同理
5. linux zimage同理
```log
BTN 'User'> bootmenu


  *** U-Boot Boot Menu ***

      load from SD
      fastboot
      update bootloader
      reboot RCM
      reboot
      power off
      Exit


  Press UP/DOWN to move, ENTER to select, ESC to quit
switch to partitions #0, OK
mmc0 is current device
3535837 bytes read in 352 ms (9.6 MiB/s)
## Loading kernel (any) from FIT Image at c1000000 ...
   Using 'conf0' configuration
   Trying 'kernel' kernel subimage
     Description:  Linux kernel for RT-Thread STM32H750i-ART-PI board
     Created:      2022-04-19  12:00:17 UTC
     Type:         Kernel Image
     Compression:  uncompressed
     Data Start:   0xc10000e4
     Data Size:    1419728 Bytes = 1.4 MiB
     Architecture: ARM
     OS:           Linux
     Load Address: 0xc0080000
     Entry Point:  0xc0080000
     Hash algo:    sha1
     Hash value:   b29369a2503a825b65b8bf375ad2b1ad95200bba
   Verifying Hash Integrity ... sha1+ OK
## Loading ramdisk (any) from FIT Image at c1000000 ...
   Using 'conf0' configuration
   Trying 'ramdisk' ramdisk subimage
     Description:  Ramdisk for for RT-Thread STM32H750i-ART-PI board
     Created:      2022-04-19  12:00:17 UTC
     Type:         RAMDisk Image
     Compression:  uncompressed
     Data Start:   0xc115eeb8
     Data Size:    2097152 Bytes = 2 MiB
     Architecture: ARM
     OS:           Linux
     Load Address: unavailable
     Entry Point:  unavailable
     Hash algo:    sha1
     Hash value:   cf0cfc63b905e83fa53905c0bbbbac5e01124b6f
   Verifying Hash Integrity ... sha1+ OK
## Loading fdt (any) from FIT Image at c1000000 ...
   Using 'conf0' configuration
   Trying 'fdt' fdt subimage
     Description:  Flattened Device Tree blob for for RT-Thread STM32H750i-ART-PI board
     Created:      2022-04-19  12:00:17 UTC
     Type:         Flat Device Tree
     Compression:  uncompressed
     Data Start:   0xc115abd0
     Data Size:    16890 Bytes = 16.5 KiB
     Architecture: ARM
     Hash algo:    sha1
     Hash value:   dda088392a3f5253fe483239d683dc0ea0290bce
   Verifying Hash Integrity ... sha1+ OK
   Booting using the fdt blob at 0xc115abd0
   Loading Kernel Image to c0080000
   Loading Ramdisk to c1600000, end c1800000 ... OK
   Loading Device Tree to c15f8000, end c15ff1f9 ... OK

Starting kernel ...
```