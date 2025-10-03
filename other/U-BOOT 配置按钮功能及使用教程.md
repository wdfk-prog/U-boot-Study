---
title: U-BOOT 配置按钮功能及使用教程
categories:
  - uboot
  - other
tags:
  - uboot
  - other
abbrlink: ab5465d3
date: 2025-10-03 10:58:18
---
@[toc]
![在这里插入图片描述](https://i-blog.csdnimg.cn/direct/20a09257e30245398974539fb3e88b6f.png)

> https://github.com/wdfk-prog/u-boot/tree/art-pi-debug
# Kconfig配置
1. 添加如下配置,使用按键驱动与按键绑定命令功能与按键命令识别
```c
CONFIG_BUTTON_CMD=y
CONFIG_CMD_BUTTON=y
CONFIG_BUTTON=y
CONFIG_BUTTON_GPIO=y
CONFIG_CMD_BOOTMENU=y
```

# 添加env环境变量
- 路径参考:board/st/stm32h750-art-pi/stm32h750-art-pi.env
- 这里的`button_cmd_0=`后面是需要支持的cmd命令,必须要可以使用的
- 这里使用bootmenu体现
```env
button_cmd_0_name=User
button_cmd_0=bootmenu


bootmenu_0=mount internal storage=usb start && ums 0 mmc 0; bootmenu
bootmenu_1=fastboot=echo Starting Fastboot protocol ...; fastboot usb 0; bootmenu
bootmenu_2=update bootloader=run flash_uboot
bootmenu_3=reboot RCM=enterrcm
bootmenu_4=reboot=reset
bootmenu_5=power off=poweroff
bootmenu_delay=-1
```

# dts中配置
- 需要注意根据自己的GPIO进行适配,第二激活电平需要自行测试设置
```c
#include <dt-bindings/input/input.h>
	gpio-keys {
		compatible = "gpio-keys";
		autorepeat;
		button-0 {
			label = "User";
			linux,code = <KEY_HOME>;
			gpios = <&gpioh 4 GPIO_ACTIVE_LOW>;
		};
	};
```

# 效果
```log
BTN 'User'> bootmenu


  *** U-Boot Boot Menu ***

      mount internal storage
      fastboot
      update bootloader
      reboot RCM
      reboot
      power off
      Exit


  Press UP/DOWN to move, ENTER to select, ESC to quit
Unknown command 'poweroff' - try 'help'
```