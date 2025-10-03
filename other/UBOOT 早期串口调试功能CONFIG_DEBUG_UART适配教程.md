---
title: UBOOT 早期串口调试功能CONFIG_DEBUG_UART适配教程
date: 2025-10-03 10:58:37
categories:
  - uboot
  - other
tags:
  - uboot
  - other
---
@[toc]

>https://github.com/wdfk-prog/u-boot/tree/art-pi-debug
# 前提条件
1. 该思路使用与STM32系列,其他芯片系列仅做参考

# Kconfi配置
1. 开启如下配置
2. 其中`CONFIG_DEBUG_UART_BASE`是串口的寄存器地址.地址看手册就行,找不到也基本不用看了.
3. `CONFIG_DEBUG_UART_CLOCK`是串口所在时钟的频率.
	- 需要注意该频率是没有初始化时钟源,默认采用`HSI`,分频与倍频都是1时的时钟频率
	- 可以使用`CUBEMX`辅助计算
![在这里插入图片描述](https://i-blog.csdnimg.cn/direct/9317e5af2fe54a45a37f2ad6f9391833.png)
```c
CONFIG_DEBUG_UART_BOARD_INIT=y
CONFIG_DEBUG_UART=y
CONFIG_DEBUG_UART_BASE=0x40004c00
CONFIG_DEBUG_UART_CLOCK=64000000
```

# 编写makefile
0. 参考`board/st/stm32mp1/debug_uart.c`和`makefile`的实现编写
1. 找到所在的板子的路径
	- 我这里使用的是`board/st/stm32h750-art-pi`
2. 添加makefile,把debug_uart.c加入编译
	```makefile
	obj-$(CONFIG_DEBUG_UART_BOARD_INIT) += debug_uart.o
	```
# 编写debug_uart.c
1. 仅供参考
2. 编写时确定需要debug输出的串口,一般是输入输出设备串口.这里我是serial0,即uart4
```c
	chosen {
		bootargs = "root=/dev/ram";
		stdout-path = "serial0:2000000n8";
	};
	aliases {
		serial0 = &uart4;
	};
```
3. 查找串口的寄存器地址`0x40004c00`
4. 时钟RCC寄存器地址`0x58024400`
5. 串口所在的时钟源的偏移地址` 0x00E8`
![在这里插入图片描述](https://i-blog.csdnimg.cn/direct/9dd4b3238a4e4bd8ae751f87a5e4e0e8.png)
6. 串口TX所在GPIO时钟的寄存器地址`0x00E0`
![在这里插入图片描述](https://i-blog.csdnimg.cn/direct/fa274d913a82464aa08ffcf13aac9ac4.png)
7. GPIO的寄存器地址`0x58020000 `
8. 找到所有需要的寄存器地址后开始设置
9.  使能串口时钟,根据寄存器的bit位按需使能既可
10. GPIO时钟同理
11. TX GPIO模式恢复为默认值,复位为UART-TX模式
	- 这里的默认值查看手册
![在这里插入图片描述](https://i-blog.csdnimg.cn/direct/e071bfe435c44c81a46806c46ed3935b.png)
 	- 复用设置查看dts文件的内容更方便,根据`uart4_pins`搜索pinmux既可.这里可知我使用AF8模式复用为UART TX模式
		```c
		//dts/upstream/src/arm/st/stm32h750i-art-pi.dts
		&uart4 {
		pinctrl-0 = <&uart4_pins>;
		pinctrl-names = "default";
		status = "okay";
		};
		//dts/upstream/src/arm/st/stm32h7-pinctrl.dtsi
		uart4_pins: uart4-0 {
			pins1 {
				pinmux = <STM32_PINMUX('A', 0, AF8)>; /* UART4_TX */
				bias-disable;
				drive-push-pull;
				slew-rate = <0>;
			};
			pins2 {
				pinmux = <STM32_PINMUX('I', 9, AF8)>; /* UART4_RX */
				bias-disable;
			};
		};
		```
# 完整源码
```c
 #include <config.h>
 #include <debug_uart.h>
 #include <asm/io.h>
 #include <asm/arch/stm32.h>
 #include <linux/bitops.h>
 
 #define STM32_UART4_BASE 0x40004c00
 #define STM32_RCC_BASE  0x58024400
 #define RCC_APB1LENR (STM32_RCC_BASE + 0x00E8)
 #define RCC_AHB4ENR (STM32_RCC_BASE + 0x00E0)
 #define GPIOA_BASE 0x58020000 
 
 void board_debug_uart_init(void)
 {
	 if (CONFIG_DEBUG_UART_BASE == STM32_UART4_BASE) {
		 /* UART4 clock enable */
		 setbits_le32(RCC_APB1LENR, BIT(19));
 
		 /* GPIOG clock enable */
		 writel(BIT(0), RCC_AHB4ENR);
		 /* GPIO configuration for boards: Uart4 TX = A0 */
		 writel(0xABFFFFFF, GPIOA_BASE + 0x00);
		 writel(0x00000008, GPIOA_BASE + 0x20);
	 }
 }
 ```
# 效果日志
1. 注意我这里日志等级和debug等级设置为9全开.没有在`log.h`强制设置`_DEBUG`宏
```log
[2025/2/20 21:14:29 544] Ђ¢*䤴
[2025/2/20 21:14:29 552] common/malloc_simple.c:26-        alloc_simple() size=8, ptr=a00, limit=2000: 2403e9f8
[2025/2/20 21:14:29 557] drivers/pinctrl/pinctrl_stm32.c:404-stm32_pinctrl_config() rv = 0
[2025/2/20 21:14:29 557] 
[2025/2/20 21:14:29 567] drivers/core/ofnode.c:540-    ofnode_read_prop() ofnode_read_prop: pinmux: No of pinmux entries= 1
[2025/2/20 21:14:29 577] drivers/core/ofnode.c:639-ofnode_read_u32_array() ofnode_read_u32_array: pinmux: pinmux = 8909
[2025/2/20 21:14:29 583] drivers/pinctrl/pinctrl_stm32.c:318-       prep_gpio_dsc() GPIO:port= 8, pin= 9
[2025/2/20 21:14:29 591] drivers/core/ofnode.c:417-ofnode_read_u32_index() ofnode_read_u32_index: slew-rate: (not found)
[2025/2/20 21:14:29 600] drivers/core/ofnode.c:525-    ofnode_read_bool() ofnode_read_bool: drive-open-drain: false
[2025/2/20 21:14:29 608] drivers/core/ofnode.c:525-    ofnode_read_bool() ofnode_read_bool: bias-pull-up: false
[2025/2/20 21:14:29 614] drivers/core/ofnode.c:525-    ofnode_read_bool() ofnode_read_bool: bias-pull-down: false
[2025/2/20 21:14:29 626] drivers/pinctrl/pinctrl_stm32.c:359-       prep_gpio_ctl() gpio fn= 9, slew-rate= 0, op type= 0, pull-upd is = 0
[2025/2/20 21:14:29 633] drivers/core/uclass.c:348-uclass_find_device_by_seq() 8
[2025/2/20 21:14:29 637] drivers/core/uclass.c:356-uclass_find_device_by_seq()    - 0 'gpio@58020000'
[2025/2/20 21:14:29 644] drivers/core/uclass.c:356-uclass_find_device_by_seq()    - 1 'gpio@58020400'
[2025/2/20 21:14:29 651] drivers/core/uclass.c:356-uclass_find_device_by_seq()    - 2 'gpio@58020800'
[2025/2/20 21:14:29 661] drivers/core/uclass.c:356-uclass_find_device_by_seq()    - 3 'gpio@58020c00'
[2025/2/20 21:14:29 665] drivers/core/uclass.c:356-uclass_find_device_by_seq()    - 4 'gpio@58021000'
[2025/2/20 21:14:29 673] drivers/core/uclass.c:356-uclass_find_device_by_seq()    - 5 'gpio@58021400'
[2025/2/20 21:14:29 679] drivers/core/uclass.c:356-uclass_find_device_by_seq()    - 6 'gpio@58021800'
[2025/2/20 21:14:29 685] drivers/core/uclass.c:356-uclass_find_device_by_seq()    - 7 'gpio@58021c00'
[2025/2/20 21:14:29 692] drivers/core/uclass.c:356-uclass_find_device_by_seq()    - 8 'gpio@58022000'
[2025/2/20 21:14:29 698] drivers/core/uclass.c:359-uclass_find_device_by_seq()    - found
[2025/2/20 21:14:29 708] common/malloc_simple.c:26-        alloc_simple() size=8, ptr=a08, limit=2000: 2403ea00
[2025/2/20 21:14:29 715] common/malloc_simple.c:26-        alloc_simple() size=14, ptr=a1c, limit=2000: 2403ea08
[2025/2/20 21:14:29 720] drivers/core/uclass.c:348-uclass_find_device_by_seq() 0
[2025/2/20 21:14:29 726] drivers/core/uclass.c:356-uclass_find_device_by_seq()    - 0 'pinctrl@58020000'
[2025/2/20 21:14:29 732] drivers/core/uclass.c:359-uclass_find_device_by_seq()    - found
[2025/2/20 21:14:29 744] drivers/core/device.c:547-        device_probe() Device 'gpio@58022000' failed to configure default pinctrl: -22 ()
[2025/2/20 21:14:30 066] drivers/core/ofnode.c:540-    ofnode_read_prop() ofnode_read_prop: st,bank-name: GPIOI
[2025/2/20 21:14:30 307] drivers/gpio/stm32_gpio.c:292-    gpio_stm32_probe() gpio_stm32 gpio@58022000: addr = 0x58022000 bank_name = GPIOI gpio_count = 16 gpio_range = 0xffff
[2025/2/20 21:14:30 518] drivers/core/uclass.c:548-uclass_get_device_by_ofnode() Looking for reset-clock-controller@58024400
[2025/2/20 21:14:30 528] drivers/core/uclass.c:399-uclass_find_device_by_ofnode() Looking for reset-clock-controller@58024400
[2025/2/20 21:14:30 538] drivers/core/uclass.c:408-uclass_find_device_by_ofnode()       - checking reset-clock-controller@58024400
[2025/2/20 21:14:30 553] drivers/core/uclass.c:418-uclass_find_device_by_ofnode()    - result for reset-clock-controller@58024400: reset-clock-controller@58024400 (ret=0)
[2025/2/20 21:14:30 572] drivers/core/uclass.c:551-uclass_get_device_by_ofnode()    - result for reset-clock-controller@58024400: reset-clock-controller@58024400 (ret=0)
[2025/2/20 21:14:30 576] drivers/clk/stm32/clk-stm32h7.c:863-  stm32_clk_of_xlate() stm32h7_rcc_clock reset-clock-controller@58024400: clk->id 28
[2025/2/20 21:14:30 592] drivers/clk/stm32/clk-stm32h7.c:794-    stm32_clk_enable() stm32h7_rcc_clock reset-clock-controller@58024400: clkid=28 gate offset=0xe0 bit_index=8 name=gpioi
[2025/2/20 21:14:30 600] drivers/gpio/stm32_gpio.c:306-    gpio_stm32_probe() gpio_stm32 gpio@58022000: clock enabled
[2025/2/20 21:14:30 604] common/malloc_simple.c:26-        alloc_simple() size=40, ptr=a5c, limit=2000: 2403ea1c
[2025/2/20 21:14:30 614] common/malloc_simple.c:26-        alloc_simple() size=4, ptr=a60, limit=2000: 2403ea5c
[2025/2/20 21:14:30 620] common/malloc_simple.c:26-        alloc_simple() size=8, ptr=a68, limit=2000: 2403ea60
[2025/2/20 21:14:30 627] drivers/pinctrl/pinctrl_stm32.c:404-stm32_pinctrl_config() rv = 0
[2025/2/20 21:14:30 628] 
[2025/2/20 21:14:30 838] drivers/core/uclass.c:548-uclass_get_device_by_ofnode() Looking for reset-clock-controller@58024400
[2025/2/20 21:14:30 849] drivers/core/uclass.c:399-uclass_find_device_by_ofnode() Looking for reset-clock-controller@58024400
[2025/2/20 21:14:30 857] drivers/core/uclass.c:408-uclass_find_device_by_ofnode()       - checking reset-clock-controller@58024400
[2025/2/20 21:14:30 873] drivers/core/uclass.c:418-uclass_find_device_by_ofnode()    - result for reset-clock-controller@58024400: reset-clock-controller@58024400 (ret=0)
[2025/2/20 21:14:30 886] drivers/core/uclass.c:551-uclass_get_device_by_ofnode()    - result for reset-clock-controller@58024400: reset-clock-controller@58024400 (ret=0)
[2025/2/20 21:14:30 899] drivers/clk/stm32/clk-stm32h7.c:863-  stm32_clk_of_xlate() stm32h7_rcc_clock reset-clock-controller@58024400: clk->id 80
[2025/2/20 21:14:30 911] drivers/clk/stm32/clk-stm32h7.c:794-    stm32_clk_enable() stm32h7_rcc_clock reset-clock-controller@58024400: clkid=80 gate offset=0xe8 bit_index=19 name=uart4
[2025/2/20 21:14:30 994] drivers/core/ofnode.c:540-    ofnode_read_prop() ofnode_read_prop: tick-timer: <not found>
[2025/2/20 21:14:31 002] common/malloc_simple.c:26-        alloc_simple() size=4, ptr=a6c, limit=2000: 2403ea68
[2025/2/20 21:14:31 010] common/malloc_simple.c:26-        alloc_simple() size=4, ptr=a70, limit=2000: 2403ea6c
[2025/2/20 21:14:31 017] drivers/core/uclass.c:348-uclass_find_device_by_seq() 0
[2025/2/20 21:14:31 021] drivers/core/uclass.c:356-uclass_find_device_by_seq()    - 0 'pinctrl@58020000'
[2025/2/20 21:14:31 029] drivers/core/uclass.c:359-uclass_find_device_by_seq()    - found
[2025/2/20 21:14:31 038] drivers/core/device.c:547-        device_probe() Device 'timer@40000c00' failed to configure default pinctrl: -22 ()
[2025/2/20 21:14:31 250] drivers/core/uclass.c:548-uclass_get_device_by_ofnode() Looking for reset-clock-controller@58024400
[2025/2/20 21:14:31 259] drivers/core/uclass.c:399-uclass_find_device_by_ofnode() Looking for reset-clock-controller@58024400
[2025/2/20 21:14:31 269] drivers/core/uclass.c:408-uclass_find_device_by_ofnode()       - checking reset-clock-controller@58024400
[2025/2/20 21:14:31 282] drivers/core/uclass.c:418-uclass_find_device_by_ofnode()    - result for reset-clock-controller@58024400: reset-clock-controller@58024400 (ret=0)
[2025/2/20 21:14:31 298] drivers/core/uclass.c:551-uclass_get_device_by_ofnode()    - result for reset-clock-controller@58024400: reset-clock-controller@58024400 (ret=0)
[2025/2/20 21:14:31 307] drivers/clk/stm32/clk-stm32h7.c:863-  stm32_clk_of_xlate() stm32h7_rcc_clock reset-clock-controller@58024400: clk->id 45
[2025/2/20 21:14:31 315] drivers/clk/stm32/clk-stm32h7.c:473-      stm32_get_rate() pllsrc name clk-hse
[2025/2/20 21:14:31 322] drivers/core/ofnode.c:417-ofnode_read_u32_index() ofnode_read_u32_index: clock-frequency: 0x17d7840 (25000000)
[2025/2/20 21:14:31 328] drivers/core/uclass.c:348-uclass_find_device_by_seq() 0
[2025/2/20 21:14:31 335] drivers/core/uclass.c:356-uclass_find_device_by_seq()    - 0 'pinctrl@58020000'
[2025/2/20 21:14:31 342] drivers/core/uclass.c:359-uclass_find_device_by_seq()    - found
[2025/2/20 21:14:31 351] drivers/core/device.c:547-        device_probe() Device 'clk-hse' failed to configure default pinctrl: -22 ()
[2025/2/20 21:14:31 359] drivers/clk/stm32/clk-stm32h7.c:492-      stm32_get_rate() divider 0 rate 25000000
[2025/2/20 21:14:31 376] drivers/clk/stm32/clk-stm32h7.c:553- stm32_get_PLL1_rate() divm1 = 4 divn1 = 80 divp1 = 2 divq1 = 2 divr1 = 2
[2025/2/20 21:14:31 380] drivers/clk/stm32/clk-stm32h7.c:555- stm32_get_PLL1_rate() fracn1 = 0 vco = 500000000 rate = 0
[2025/2/20 21:14:31 393] drivers/clk/stm32/clk-stm32h7.c:672-  stm32_clk_get_rate() stm32h7_rcc_clock reset-clock-controller@58024400: system clock: source = 3 freq = 250000000
[2025/2/20 21:14:31 406] drivers/clk/stm32/clk-stm32h7.c:692-  stm32_clk_get_rate() stm32h7_rcc_clock reset-clock-controller@58024400: clk->id=45 gate_offset=0xe8 sysclk=125000000
[2025/2/20 21:14:31 420] drivers/clk/stm32/clk-stm32h7.c:749-  stm32_clk_get_rate() stm32h7_rcc_clock reset-clock-controller@58024400: system clock: freq after APB1 prescaler = 125000000
[2025/2/20 21:14:31 648] drivers/core/uclass.c:548-uclass_get_device_by_ofnode() Looking for reset-clock-controller@58024400
[2025/2/20 21:14:31 657] drivers/core/uclass.c:399-uclass_find_device_by_ofnode() Looking for reset-clock-controller@58024400
[2025/2/20 21:14:31 669] drivers/core/uclass.c:408-uclass_find_device_by_ofnode()       - checking reset-clock-controller@58024400
[2025/2/20 21:14:31 682] drivers/core/uclass.c:418-uclass_find_device_by_ofnode()    - result for reset-clock-controller@58024400: reset-clock-controller@58024400 (ret=0)
[2025/2/20 21:14:31 694] drivers/core/uclass.c:551-uclass_get_device_by_ofnode()    - result for reset-clock-controller@58024400: reset-clock-controller@58024400 (ret=0)
[2025/2/20 21:14:31 706] drivers/clk/stm32/clk-stm32h7.c:863-  stm32_clk_of_xlate() stm32h7_rcc_clock reset-clock-controller@58024400: clk->id 45
[2025/2/20 21:14:31 725] drivers/clk/stm32/clk-stm32h7.c:794-    stm32_clk_enable() stm32h7_rcc_clock reset-clock-controller@58024400: clkid=45 gate offset=0xe8 bit_index=3 name=tim5
[2025/2/20 21:14:31 732] drivers/clk/stm32/clk-stm32h7.c:473-      stm32_get_rate() pllsrc name clk-hse
[2025/2/20 21:14:31 738] drivers/clk/stm32/clk-stm32h7.c:492-      stm32_get_rate() divider 0 rate 25000000
[2025/2/20 21:14:31 746] drivers/clk/stm32/clk-stm32h7.c:553- stm32_get_PLL1_rate() divm1 = 4 divn1 = 80 divp1 = 2 divq1 = 2 divr1 = 2
[2025/2/20 21:14:31 753] drivers/clk/stm32/clk-stm32h7.c:555- stm32_get_PLL1_rate() fracn1 = 0 vco = 500000000 rate = 0
[2025/2/20 21:14:31 772] drivers/clk/stm32/clk-stm32h7.c:672-  stm32_clk_get_rate() stm32h7_rcc_clock reset-clock-controller@58024400: system clock: source = 3 freq = 250000000
[2025/2/20 21:14:31 780] drivers/clk/stm32/clk-stm32h7.c:692-  stm32_clk_get_rate() stm32h7_rcc_clock reset-clock-controller@58024400: clk->id=45 gate_offset=0xe8 sysclk=125000000
[2025/2/20 21:14:31 800] drivers/clk/stm32/clk-stm32h7.c:749-  stm32_clk_get_rate() stm32h7_rcc_clock reset-clock-controller@58024400: system clock: freq after APB1 prescaler = 125000000
[2025/2/20 21:14:31 807] drivers/serial/serial_stm32.c:222-  stm32_serial_probe() serial_stm32 serial@40004c00: FIFO not empty, some character can be lost (-110)
[2025/2/20 21:14:31 816] drivers/clk/stm32/clk-stm32h7.c:473-      stm32_get_rate() pllsrc name clk-hse
[2025/2/20 21:14:31 823] drivers/clk/stm32/clk-stm32h7.c:492-      stm32_get_rate() divider 0 rate 25000000
[2025/2/20 21:14:31 835] drivers/clk/stm32/clk-stm32h7.c:553- stm32_get_PLL1_rate() divm1 = 4 divn1 = 80 divp1 = 2 divq1 = 2 divr1 = 2
[2025/2/20 21:14:31 842] drivers/clk/stm32/clk-stm32h7.c:555- stm32_get_PLL1_rate() fracn1 = 0 vco = 500000000 rate = 0
[2025/2/20 21:14:31 860] drivers/clk/stm32/clk-stm32h7.c:672-  stm32_clk_get_rate() stm32h7_rcc_clock reset-clock-controller@58024400: system clock: source = 3 freq = 250000000
[2025/2/20 21:14:31 882] drivers/clk/stm32/clk-stm32h7.c:692-  stm32_clk_get_rate() stm32h7_rcc_clock reset-clock-controller@58024400: clk->id=80 gate_offset=0xe8 sysclk=125000000
[2025/2/20 21:14:31 882] drivers/clk/stm32/clk-stm32h7.c:749-  stm32_clk_get_rate() stm32h7_rcc_clock reset-clock-controller@58024400: system clock: freq after APB1 presca
[2025/2/20 21:14:31 882] 
[2025/2/20 21:14:31 890] U-Boot 2025.04-rc2-00038-g6d38b330a1c8-dirty (Feb 20 2025 - 21:12:51 +0800)
[2025/2/20 21:14:31 890] 
```