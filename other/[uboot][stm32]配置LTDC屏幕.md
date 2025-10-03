---
title: '[uboot][stm32]配置LTDC屏幕'
date: 2025-10-03 10:54:10
categories:
  - uboot
  - other
tags:
  - uboot
  - other
---
@[toc]
![在这里插入图片描述](https://i-blog.csdnimg.cn/direct/2eecbf13625f4a8c9345a5a7a785a9eb.png)

> https://github.com/wdfk-prog/u-boot

# 前提
1. 手上刚好有块屏幕,尝试在uboot中点亮一下
2. 使用前请使用其他手段点亮该屏幕确保屏幕的完好再进行操作.确保配置的参数及引脚是可用的.

# dts设备树修改
1. ltdc状态修改为重定向前绑定,另外进行GPIO的绑定.根据需要自行配置.注意我使用的是H7系列芯片.不同系列芯片AF的内容不一致,需要自行查看修改.
```c
&ltdc {
	pinctrl-0 = <&ltdc_pins>;
	pinctrl-names = "default";
	status = "okay";
	bootph-all;
};

&pinctrl {
	   ltdc_pins: ltdc@0 {
        pins {
            pinmux = <STM32_PINMUX('K', 5, AF14)>,  /* LTDC_B6 */
                    <STM32_PINMUX('I', 7, AF14)>,  /* LTDC_B7 */
                    <STM32_PINMUX('K', 4, AF14)>,  /* LTDC_B5 */
                    <STM32_PINMUX('J', 15, AF14)>, /* LTDC_B3 */
                    <STM32_PINMUX('K', 3, AF14)>,  /* LTDC_B4 */
                    <STM32_PINMUX('K', 7, AF14)>,  /* LTDC_DE */
                    <STM32_PINMUX('I', 12, AF14)>, /* LTDC_HSYNC */
                    <STM32_PINMUX('I', 13, AF14)>, /* LTDC_VSYNC */
                    <STM32_PINMUX('I', 14, AF14)>, /* LTDC_CLK */
                    <STM32_PINMUX('K', 2, AF14)>,  /* LTDC_G7 */
                    <STM32_PINMUX('K', 0, AF14)>,  /* LTDC_G5 */
                    <STM32_PINMUX('K', 1, AF14)>,  /* LTDC_G6 */
                    <STM32_PINMUX('J', 11, AF14)>, /* LTDC_G4 */
                    <STM32_PINMUX('J', 10, AF14)>, /* LTDC_G3 */
                    <STM32_PINMUX('J', 9, AF14)>,  /* LTDC_G2 */
                    <STM32_PINMUX('J', 6, AF14)>,  /* LTDC_R7 */
                    <STM32_PINMUX('J', 5, AF14)>,  /* LTDC_R6 */
                    <STM32_PINMUX('J', 2, AF14)>,  /* LTDC_R3 */
                    <STM32_PINMUX('J', 3, AF14)>,  /* LTDC_R4 */
                    <STM32_PINMUX('J', 4, AF14)>;  /* LTDC_R5 */
            slew-rate = <3>;
        };
    };
};
```

2. 添加屏幕节点及其信息
- 上一步是完善LTDC的驱动引脚及启动
- 这一步描述了屏幕的参数信息,以便于使用
```c
	panel: panel {
		compatible = "simple-panel";
		display-timings {
			native-mode = <&timing0>;
			timing0: timing0 {
				clock-frequency = <33000000>;
				hactive = <800>;
				vactive = <480>;
				hfront-porch = <48>;
				hback-porch = <40>;
				hsync-len = <1>;
				vfront-porch = <13>;
				vback-porch = <32>;
				vsync-len = <1>;
			};
		};
	};
```

# Kconfig
- 修改配置文件,启用ltdc驱动代码程序
```c
CONFIG_VIDEO=y
CONFIG_VIDEO_LOGO=y
CONFIG_BACKLIGHT_GPIO=y
CONFIG_VIDEO_LCD_ORISETECH_OTM8009A=y
CONFIG_VIDEO_STM32=y
CONFIG_VIDEO_STM32_DSI=y
CONFIG_VIDEO_STM32_MAX_XRES=480
CONFIG_VIDEO_STM32_MAX_YRES=800
CONFIG_SPLASH_SCREEN=y
CONFIG_SPLASH_SCREEN_ALIGN=y
CONFIG_BMP_16BPP=y
CONFIG_BMP_24BPP=n
CONFIG_BMP_32BPP=n
CONFIG_CMD_BMP=n
CONFIG_SYS_CONSOLE_IS_IN_ENV=n
CONFIG_VIDEO_BRIDGE=n
# CONFIG_VIDEO_FONT_8X16 is not set
```

# 日志打印
- 可以看到配置的引脚已经被启动初始化了
```log
OK
device_probe: display-controller@50001000
device_probe: soc
device_probe: pinctrl@58020000
device_probe: gpio@58022800
device_probe: pinctrl@58020000
device_probe: pinctrl@58020000
device_probe: reset-clock-controller@58024400
stm32h7_rcc_clock reset-clock-controller@58024400: clk->id 26
stm32h7_rcc_clock reset-clock-controller@58024400: clkid=26 gate offset=0xe0 bit_index=10 name=gpiok
device_probe: gpio@58022000
device_probe: gpio@58022800
device_probe: gpio@58022400
device_probe: pinctrl@58020000
device_probe: pinctrl@58020000
device_probe: reset-clock-controller@58024400
stm32h7_rcc_clock reset-clock-controller@58024400: clk->id 27
stm32h7_rcc_clock reset-clock-controller@58024400: clkid=27 gate offset=0xe0 bit_index=9 name=gpioj
device_probe: gpio@58022800
device_probe: gpio@58022800
device_probe: gpio@58022000
device_probe: gpio@58022000
device_probe: gpio@58022000
device_probe: gpio@58022800
device_probe: gpio@58022800
device_probe: gpio@58022800
device_probe: gpio@58022400
device_probe: gpio@58022400
device_probe: gpio@58022400
device_probe: gpio@58022400
device_probe: gpio@58022400
device_probe: gpio@58022400
device_probe: gpio@58022400
device_probe: gpio@58022400
device_probe: reset-clock-controller@58024400
stm32h7_rcc_clock reset-clock-controller@58024400: clk->id 72
stm32h7_rcc_clock reset-clock-controller@58024400: clkid=72 gate offset=0xe4 bit_index=3 name=ltdc
stm32_ltdc_probe: LTDC hardware 0x10300
device_probe: panel
device_probe: root_driver
device_probe: pinctrl@58020000
stm32_display display-controller@50001000: Set pixel clock req 33000000 hz get -19 hz
device_probe: reset-clock-controller@58024400
stm32_display display-controller@50001000: No video bridge, or no backlight on bridge
stm32_display display-controller@50001000: 800x480 16bpp frame buffer at 0xc1e00000
stm32_display display-controller@50001000: crop 0,0 800x480 bg 0xffffffff alpha 255
video_post_probe 627
device_probe: display-controller@50001000.v
device_probe: display-controller@50001000
video_post_probe 641
In:    serial@40004c00
Out:   serial@40004c00
Err:   serial@40004c00
device_probe: button-0
device_probe: gpio-keys
device_probe: root_driver
device_probe: pinctrl@58020000
device_probe: pinctrl@58020000
device_probe: gpio@58021c00
device_probe: pinctrl@58020000
device_probe: pinctrl@58020000
device_probe: reset-clock-controller@58024400
stm32h7_rcc_clock reset-clock-controller@58024400: clk->id 29
stm32h7_rcc_clock reset-clock-controller@58024400: clkid=29 gate offset=0xe0 bit_index=7 name=gpioh
```

# 后记
1. 这个步骤并不完善.STM32的LTDC驱动有问题.直接卡死在系统内部.无法排查.
2. 这个操作仅供参考