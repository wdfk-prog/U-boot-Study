---
title: '[UBOOT][STM32]编写LED支持教程'
date: 2025-10-03 10:58:03
categories:
  - uboot
  - other
tags:
  - uboot
  - other
---
@[toc]
![在这里插入图片描述](https://i-blog.csdnimg.cn/direct/d77ded5a221c4fe4b4a2f79d7e078d47.png)

# 前提
1.目的:uboot启动时没有状态提醒,无法知道当前板子运行到了什么阶段
2.所以需要一个LED来指示当前的U-BOOT状态

# 编写
1. 参考:board/st/stm32f429-discovery/led.c
## 在自己的板级目录下makefile修改.
1. 加入led.c的编译
```makefile
//board/st/stm32h750-art-pi/Makefile
obj-y	+= led.o
```

## 添加led.c文件并编写
1. board/st/stm32h750-art-pi/led.c
2. GPIO编号转换成引脚的宏已经写好了,对应修改成自己的引脚既可
3. `gpio_direction_output(RED_LED, 1);`这个就是配置后输出对应的电平,根据需要修改高低电平既可

```c
#include "acpi/acpi_device.h"
#include <status_led.h>
#include <asm-generic/gpio.h>
#include <stdio.h>

#define BULE_LED	(('I'-'A') * 16 + 8)
#define RED_LED		(('C'-'A') * 16 + 15)

void coloured_LED_init(void)
{
	gpio_request(RED_LED, "led-red");
	gpio_direction_output(RED_LED, 1);
	gpio_request(BULE_LED, "led-bule");
	gpio_direction_output(BULE_LED, 1);
}

void red_led_off(void)
{
	gpio_direction_output(RED_LED, 1);
}

void bule_led_off(void)
{
	gpio_direction_output(BULE_LED, 1);
}

void red_led_on(void)
{
	gpio_direction_output(RED_LED, 0);
}

void bule_led_on(void)
{
	gpio_direction_output(BULE_LED, 0);
}
```

# 后记
1.`#define BULE_LED	(('I'-'A') * 16 + 8)`这个计算出来的编号不仅可以在led.c编写时使用.也可以开启LED驱动支持后,填入LED的gpio编号去使用.自行支持LED闪烁灯功能