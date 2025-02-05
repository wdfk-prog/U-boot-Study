[TOC]

# DTS文件格式
```c
/dts-v1/;   // 设备树版本 确保编译器可以识别
#include的内容也会被编译器识别
#include "stm32h750.dtsi"   // 包含芯片相关的dtsi文件
#include "stm32h7-pinctrl.dtsi"
#include <dt-bindings/interrupt-controller/irq.h>
#include <dt-bindings/gpio/gpio.h>

/ { // 设备树根节点的属性
	model = "RT-Thread STM32H750i-ART-PI board";   //型号
	compatible = "st,stm32h750i-art-pi", "st,stm32h750";//兼容性
    // 指定系统启动参数的作用
	chosen {
		bootargs = "root=/dev/ram";         //启动参数
		stdout-path = "serial0:2000000n8";  //标准输出路径
	};
    //内存节点
	memory@c0000000 {
		device_type = "memory";
		reg = <0xc0000000 0x2000000>;   //内存地址和大小
	};
    // 保留内存节点
	reserved-memory {
		#address-cells = <1>;   //地址单元数
		#size-cells = <1>;      //大小单元数
		ranges;                //范围

		linux,cma {           //名称：linux cma（连续内存分配）
			compatible = "shared-dma-pool"; //兼容性
			no-map;             //不映射
			size = <0x100000>;  //大小
			linux,dma-default;  //默认dma
		};
	};
    // 别名节点 用于总线设备的别名
	aliases {
		serial0 = &uart4;
		serial1 = &usart3;
	};

	leds {
		compatible = "gpio-leds";
		led-red {
			gpios = <&gpioi 8 0>;   //索引gpioi 8 0
		};
		led-green {
			gpios = <&gpioc 15 0>;
			linux,default-trigger = "heartbeat";
		};
	};
};

&clk_hse {
	clock-frequency = <25000000>;
};
//设备节点
&dma1 {
	status = "okay";    //必须的属性,表示设备节点的启用与否
};
```

# DTSI
- .dts 文件是设备树源文件（Device Tree Source），用于描述具体硬件平台或板子的配置。它包含了特定硬件设备的节点和属性，定义了设备的布局和配置。
- .dtsi 文件是设备树源包含文件（Device Tree Source Include），用于定义特定处理器、SoC（系统级芯片）或硬件平台的通用配置。.dtsi 文件通常包含一些通用的硬件配置，可以被多个 .dts 文件引用和复用

# DTB反编译
1. 安装设备树编译器（DTC
```shell
sudo apt-get install device-tree-compiler
```

2. 反编译
```shell
dtc -I dtb -O dts -o xxx.dts xxx.dtb
```

## 反编译文件
- [反编译文件](../../学习芯片/ART-PI/art-pi.dts)
```dts
#include "stm32h750.dtsi" //#include "stm32h743.dtsi"
//stm32h743.dtsi -> #include "armv7-m.dtsi"
```

# chosen节点
- 所选节点不代表真实设备，但用作一个位置用于传递数据，例如使用哪个串行设备打印日志等

## stdout-path 属性
- 设备树可以指定要用于启动控制台输出的设备.
- 在 /chosen 下具有 stdout-path 属性。
```c
/ {
	chosen {
		stdout-path = "/serial@f00:115200";
	};

	serial@f00 {
		compatible = "vendor,some-uart";
		reg = <0xf00 0x10>;
	};
};
```
- of_stdout: stdout-path;调用of_get_stdout()获取
- serial_init -> serial_find_console_or_panic -> 调用of_get_stdout
```c
int of_alias_scan(void)
{
	if (of_chosen) {
		const char *name;

		name = of_get_property(of_chosen, "stdout-path", NULL);
		if (name)
			of_stdout = of_find_node_opts_by_path(NULL, name,
							&of_stdout_options);
	}
}
```

## tick-timer 系统计时器
- 在系统中有多个计时器，请指定要使用的计时器作为 tick-timer。以前它在 timer 驱动程序中被硬编码
因为 Device Tree 具有所有计时器节点。现在可以在 Device Tree 中指定要使用的计时器
```c
/ {
	chosen {
		tick-timer = "/timer2@f00";
	};

	timer2@f00 {
		compatible = "vendor,some-timer";
		reg = <0xf00 0x10>;
	};
};
```

# 中断控制器
```c
//doc/device-tree-bindings/interrupt-controller/interrupts.txt
//dts/upstream/Bindings/interrupt-controller/arm,nvic.txt
interrupt-controller@e000e100 {
    compatible = "arm,armv7m-nvic";
    interrupt-controller;
    #interrupt-cells = <0x01>;
    reg = <0xe000e100 0xc00>;
    phandle = <0x01>;
};

```