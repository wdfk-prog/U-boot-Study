---
title: '[U-BOOT][STM32]SD卡导入导出环境变量'
date: 2025-10-03 10:57:24
categories:
  - uboot
  - other
tags:
  - uboot
  - other
---
@[toc]
![在这里插入图片描述](https://i-blog.csdnimg.cn/direct/463f491c61da4078bfa19e2da2302bce.png)

> https://github.com/wdfk-prog/u-boot/tree/art-pi-debug

# 前提
1. u-boot的环境变量十分重要,可以说有了环境变量.u-boot的配置和灵活性得到了提高.
2. 只有u-boot编译了相关程序,使用环境变量执行命令,可扩展性将会大大增加.

# 操作步骤
1. 结合之前的内容
2. Kconfig需要启用如下配置
3. 用于导入导出env变量,编辑env变量
4. `CONFIG_ENV_IS_IN_FAT`这个是用于从fat中加载env变量环境到内存中.没有设置将从默认的编译程序中加载,这种就不可改变了.但是存在fat文件系统中的env环境变量,是可以一直保存与修改的,掉电后还可生效.
```c
// configs/stm32h750-art-pi_defconfig
#
# Command line interface -> Environment commands
#
CONFIG_CMD_EXPORTENV=y
CONFIG_CMD_IMPORTENV=y
CONFIG_CMD_EDITENV=y
CONFIG_CMD_SAVEENV=y
CONFIG_CMD_ENV_EXISTS=y
CONFIG_ENV_IS_IN_FAT=y
CONFIG_ENV_FAT_DEVICE_AND_PART=":"
```

# 保存ENV到文件系统中
```shell
U-Boot > saveenv 
Saving Environment to FAT... OK
U-Boot > fatls mmc 0
            System Volume Information/
  3535837   APT_Pi_Krl.itb.bin
  1419728   zImage
    16890   stm32h750i-art-pi.dtb
  2097152   rootfs.ext2
     1488   APT_Pi_Krl.its
     8192   uboot.env

6 file(s), 1 dir(s)

```

# 现象
```log
Loading Environment from FAT...OK
```

# 注意
1.请不要手动从SD卡中修改ENV变量内容,有需要修改请在CLI环境下读取修改保存
2.因为ENV环境进行了CRC校验,而且ENV文件大小是默认0X2000,修改了或裁剪了文件大小会导致CRC校验失败
```c
Loading Environment from FAT... dev_and_part 0:
*** Warning - bad CRC, using default environment
```

# 后记
1.不知道有没有直接PC上编辑env的软件或程序.直接PC上编辑完成传到SD卡中就好了