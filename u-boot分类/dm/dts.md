---
title: dts
date: 2025-10-03 09:44:27
categories:
  - uboot
  - u-boot分类
  - dm
tags:
  - uboot
  - u-boot分类
  - dm
---
[TOC]

# 驱动代码编写
## UCLASS_DRIVER 驱动类定义
- 一个驱动的大类的注册定义;例如serial驱动类,包括多个不同平台的串口设备驱动
```c
struct uclass_driver {
	const char *name;//debug查看用
	enum uclass_id id;//所以相同驱动类设备的ID都一样
	int (*post_bind)(struct udevice *dev);	//设备绑定后的回调(device_bind_common调用)
	int (*pre_unbind)(struct udevice *dev);	//设备绑定前的回调(device_bind_common调用)
	int (*pre_probe)(struct udevice *dev);	//设备探测后的回调函数(device_probe函数中调用)
	int (*post_probe)(struct udevice *dev);	//设备探测前的回调函数(device_probe函数中调用)
	int (*pre_remove)(struct udevice *dev);	//设备删除前的回调函数
	int (*child_post_bind)(struct udevice *dev);
	int (*child_pre_probe)(struct udevice *dev);
	int (*child_post_probe)(struct udevice *dev);
	int (*init)(struct uclass *class);
	int (*destroy)(struct uclass *class);
	int priv_auto;
	int per_device_auto;
	int per_device_plat_auto;
	int per_child_auto;
	int per_child_plat_auto;
	uint32_t flags;	//这个类的成员用别名对自己进行排序;没有别名的uclass成员没有序列号;
};

UCLASS_DRIVER(serial) = {
	.id		= UCLASS_SERIAL,
	.name		= "serial",
	.flags		= DM_UC_FLAG_SEQ_ALIAS,
	.post_probe	= serial_post_probe,
	.pre_remove	= serial_pre_remove,
	.per_device_auto	= sizeof(struct serial_dev_priv),
};
```

## U_BOOT_DEVICE 驱动设备定义
```c
struct driver {
	char *name;
	enum uclass_id id;
	const struct udevice_id *of_match;	//compatible兼容的设备及其数据内容
	int (*bind)(struct udevice *dev);
	int (*probe)(struct udevice *dev);
	int (*remove)(struct udevice *dev);
	int (*unbind)(struct udevice *dev);
	int (*of_to_plat)(struct udevice *dev);	//平台数据绑定到设备中,例如stm32的寄存器地址给入设备的私有数据中
	int (*child_post_bind)(struct udevice *dev);
	int (*child_pre_probe)(struct udevice *dev);
	int (*child_post_remove)(struct udevice *dev);
	int priv_auto;
	int plat_auto;	//dev_get_plat获取,bind时分配
	int per_child_auto;
	int per_child_plat_auto;
	const void *ops;			//设备驱动函数
	uint32_t flags;
#if CONFIG_IS_ENABLED(ACPIGEN)
	struct acpi_ops *acpi_ops;
#endif
};
//数据使用dev_get_driver_data函数返回,lists_bind_fdt时设置
static const struct udevice_id stm32_serial_id[] = {
	{ .compatible = "st,stm32-uart", .data = (ulong)&stm32f4_info},
	{ .compatible = "st,stm32f7-uart", .data = (ulong)&stm32f7_info},
	{ .compatible = "st,stm32h7-uart", .data = (ulong)&stm32h7_info},
	{}
};

U_BOOT_DRIVER(serial_stm32) = {
	.name = "serial_stm32",
	.id = UCLASS_SERIAL,
	.of_match = of_match_ptr(stm32_serial_id),
	.of_to_plat = of_match_ptr(stm32_serial_of_to_plat),
	.plat_auto	= sizeof(struct stm32x7_serial_plat),	//dev_get_plat获取
	.ops = &stm32_serial_ops,
	.probe = stm32_serial_probe,
#if !CONFIG_IS_ENABLED(OF_CONTROL)
	.flags = DM_FLAG_PRE_RELOC,
#endif
};
```

## compatible 兼容性
1. 字符串需要完全匹配,其中`_`和`-`是不同的;可以中间用`,`隔开

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

## phandle && label 创建引用
1. 引用其他节点：phandle 允许一个节点引用另一个节点。例如，一个设备节点可以引用其电源供应节点、时钟节点或中断控制器节点。
2. 参数传递：通过 phandle，可以传递参数给被引用的节点。例如，指定中断号、时钟频率等。
3. phandle 的工作机制
	1. 定义 phandle：在设备树中，每个节点可以通过 phandle 属性定义一个唯一的 phandle 值。例如：
	```c
	node1: node1 {
    phandle = <1>;
		// 其他属性
	};
	```
	2. 引用 phandle：在其他节点中，通过引用 phandle 值，将一个节点引用到另一个节点。例如：
	```c
	node2: node2 {
		clocks = <&node1>;
		// 其他属性
	};
	```
4. phandle=不推荐手动设置,可以使用label属性
5. label 使用方法
	```c
	node1: node1 {
		// 其他属性
	};
	node2: node2 {
		clocks = <&node1>;
		// 其他属性
	};
	```
## #address-cells和#size-cells
- 在设备树（Device Tree）中，#address-cells和#size-cells是两个重要的属性，用于描述节点地址和大小的编码方式。
1. #address-cells：
该属性定义了地址字段的单元数（cells）。每个单元通常是一个32位的值。
在这个例子中，#address-cells = <0x01>;表示地址字段由一个单元组成，即每个地址占用32位。
这意味着在设备树中描述设备地址时，将使用一个32位的值来表示地址。
2. #size-cells：
该属性定义了大小字段的单元数（cells）。每个单元通常是一个32位的值。
在这个例子中，#size-cells = <0x01>;表示大小字段由一个单元组成，即每个大小占用32位。
这意味着在设备树中描述设备大小时，将使用一个32位的值来表示大小。
- 这两个属性通常在描述内存映射或总线地址空间时使用。它们告诉解析设备树的代码如何解释地址和大小字段。例如，在描述一个设备的寄存器地址范围时，#address-cells和#size-cells的值将决定如何解析该范围的起始地址和长度

# DTSI
- .dts 文件是设备树源文件（Device Tree Source），用于描述具体硬件平台或板子的配置。它包含了特定硬件设备的节点和属性，定义了设备的布局和配置。
- .dtsi 文件是设备树源包含文件（Device Tree Source Include），用于定义特定处理器、SoC（系统级芯片）或硬件平台的通用配置。.dtsi 文件通常包含一些通用的硬件配置，可以被多个 .dts 文件引用和复用
- .dtso 文件是设备树源覆盖文件（Device Tree Source Overlay），用于覆盖或修改现有设备树的配置。.dtso 文件通常包含一些特定的硬件配置，可以被一个或多个 .dts 文件引用和复用
- .dtb 文件是设备树二进制文件（Device Tree Blob），是设备树源文件编译后生成的二进制文件。它包含了设备树的编译结果，可以被 Linux 内核加载并解析，用于配置硬件设备
- u-boot.dtsi文件是u-boot的设备树源包含文件，用于定义u-boot的通用配置。u-boot.dtsi文件通常包含一些通用的硬件配置，可以被多个u-boot.dts文件引用和复用

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

# UCLASS
- 具体驱动的抽象,在识别到具体的设备后,会调用抽象的功能函数,执行公共的功能,所以有pre_probe,post_probe等函数
- `pre_probe`: 设备探测前的回调函数
- `post_probe`: 设备探测后的回调函数,注意这个回调函数一般是用于检测设备初始化是否成功;获取必须的设备信息是否存在和合法

# U_BOOT_DRIVER
- 需要注意flag的属性,例如DM_FLAG_PRE_RELOC可以在reloc之前初始化设备;且FDT节点的属性需要具有`bootph-all`等允许重定向之前绑定的属性
	-	一般在dtsi中体现,例如`arch/arm/dts/stm32h7-u-boot.dtsi`
- 之前没有的设备,需要在reloc之前初始化
- 顺序是按照FDT节点的顺序来的
- 节点中`status`不等于`ok`的属性,不会被启动
- 重定向之前的设备初始化流程
1. soc `simple-bus`设备,该设备绑定时,会调用`simple_bus_bind`函数,绑定其下的设备
2. timer5 `timer`设备,获取时钟频率,并初始化时钟
	- 注意是因为重定向之前没有定时器设备,所以需要在reloc之前初始化
	- 后面会提交patch,把systick的初始化放在这里,而不是使用timer5来初始化系统定时器
	- 这里去获取了rcc设备,并执行了probe探测;
	- 并且获取了当前系统时钟的基准时钟的设备,并进行初始化
	- 初始化rcc设备,需要获取`syscon`设备,并进行初始化
3. syscon `syscon`设备, 获取soc的`#address-cells` 和`#size-cells`判定地址是32位还是64位;然后获取节点下的`reg`属性,获取地址和大小
	- 执行regmap函数进行分配地址与大小对的映射
4. rcc reset-clock-controller `clock`设备
	- 执行`stm32_clk_probe`进行`configure_clocks`
5. clk_hse clk_lse `fixed-clock`设备,获取固定的时钟频率
6. power-config `syscon`设备
	- 执行regmap函数进行分配地址与大小对的映射
7. pinctrl `pinctrl`设备
- 重定向之后的设备初始化流程
1. spi2 `spi`设备,由于status不等于ok,所以不会被启动
2. spi3 `spi`设备,由于status不等于ok,所以不会被启动
