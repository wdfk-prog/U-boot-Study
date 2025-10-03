---
title: ram
categories:
  - uboot
  - u-boot分类
  - dm
tags:
  - uboot
  - u-boot分类
  - dm
abbrlink: e7d1222f
date: 2025-10-03 09:44:27
---
[TOC]

# ram-uclass.c
## 类信息
```c
UCLASS_DRIVER(ram) = {
	.id		= UCLASS_RAM,
	.name		= "ram",
};
```

# stm32_sdram.c
## 驱动信息
```c
U_BOOT_DRIVER(stm32_fmc) = {
	.name = "stm32_fmc",
	.id = UCLASS_RAM,
	.of_match = stm32_fmc_ids,
	.ops = &stm32_fmc_ops,
	.of_to_plat = stm32_fmc_of_to_plat,
	.probe = stm32_fmc_probe,
	.plat_auto	= sizeof(struct stm32_sdram_params),
};
``` 

## dts
```c
	fmc@52004000 {
		compatible = "st,stm32h7-fmc";
		reg = <0x52004000 0x1000>;
		clocks = <0x02 0x7a>;
		pinctrl-0 = <0x20>;
		pinctrl-names = "default";
		status = "okay";
		bootph-all;
		phandle = <0x53>;

		bank@0 {
			st,sdram-control = <0x1020101 0x2030100>;
			st,sdram-timing = [01 05 05 05 01 01 01];
			st,sdram-refcount = <0x2a5>;
			phandle = <0x54>;
		};
	};
```

## log
```log
DRAM:  drivers/core/device.c:498-        device_probe() probing driver stm32_fmc for fmc@52004000 uclass ram
stm32_fmc fmc@52004000: can't find syscon device (-2)
drivers/ram/stm32_sdram.c:322-stm32_fmc_of_to_plat() Find bank 0 0
drivers/core/ofnode.c:417-ofnode_read_u32_index() ofnode_read_u32_index: st,sdram-refcount: 0x2a5 (677)
stm32_fmc fmc@52004000: no of banks = 1
drivers/core/device.c:506-        device_probe() probing parent soc for fmc@52004000
drivers/core/device.c:549-        device_probe() probing pinctrl for fmc@52004000
```
1. `DRAM:` 在`board_f.c`中`announce_dram_init()`函数中打印
2. `stm32_fmc fmc@52004000: can't find syscon device (-2)` 说明`syscon`节点没有找到,dts中没有`st,syscfg`节点
3. `ofnode_read_u32_index: st,sdram-refcount: 0x2a5 (677)` 说明读取到了`st,sdram-refcount`属性

## stm32_fmc_of_to_plat
```c
static int stm32_fmc_of_to_plat(struct udevice *dev)
{
	struct stm32_sdram_params *params = dev_get_plat(dev);
	struct bank_params *bank_params;
	struct ofnode_phandle_args args;
	u32 *syscfg_base;
	u32 mem_remap;
	u32 swp_fmc;
	ofnode bank_node;
	char *bank_name;
	char _bank_name[128] = {0};
	u8 bank = 0;
	int ret;

	ret = dev_read_phandle_with_args(dev, "st,syscfg", NULL, 0, 0,
						 &args);
	if (ret) {
		dev_dbg(dev, "can't find syscon device (%d)\n", ret);
	}

	dev_for_each_subnode(bank_node, dev) {
		/* extract the bank index from DT */
		bank_name = (char *)ofnode_get_name(bank_node);
		strlcpy(_bank_name, bank_name, sizeof(_bank_name));	//获取子节点的名字
		bank_name = (char *)_bank_name;
		strsep(&bank_name, "@");	//获取子节点的值
		if (!bank_name) {
			pr_err("missing sdram bank index");
			return -EINVAL;
		}

		bank_params = &params->bank_params[bank];
		strict_strtoul(bank_name, 10,
			       (long unsigned int *)&bank_params->target_bank);	//将子节点的值转换为整数

		if (bank_params->target_bank >= MAX_SDRAM_BANK) {
			pr_err("Found bank %d , but only bank 0 and 1 are supported",
			      bank_params->target_bank);
			return -EINVAL;
		}

		debug("Find bank %s %u\n", bank_name, bank_params->target_bank);

		params->bank_params[bank].sdram_control =
			(struct stm32_sdram_control *)
			 ofnode_read_u8_array_ptr(bank_node,
						  "st,sdram-control",
						  sizeof(struct stm32_sdram_control));

		if (!params->bank_params[bank].sdram_control) {
			pr_err("st,sdram-control not found for %s",
			      ofnode_get_name(bank_node));
			return -EINVAL;
		}

		params->bank_params[bank].sdram_timing =
			(struct stm32_sdram_timing *)
			 ofnode_read_u8_array_ptr(bank_node,
						  "st,sdram-timing",
						  sizeof(struct stm32_sdram_timing));

		if (!params->bank_params[bank].sdram_timing) {
			pr_err("st,sdram-timing not found for %s",
			      ofnode_get_name(bank_node));
			return -EINVAL;
		}

		bank_params->sdram_ref_count = ofnode_read_u32_default(bank_node,
						"st,sdram-refcount", 8196);
		bank++;
	}

	params->no_sdram_banks = bank;
	dev_dbg(dev, "no of banks = %d\n", params->no_sdram_banks);

	return 0;
}
```

## stm32_fmc_probe 
1. 使能时钟
2. 初始化sdram
```c
static int stm32_fmc_probe(struct udevice *dev)
{
	struct stm32_sdram_params *params = dev_get_plat(dev);
	int ret;
	fdt_addr_t addr;

	addr = dev_read_addr(dev);
	if (addr == FDT_ADDR_T_NONE)
		return -EINVAL;

	params->base = (struct stm32_fmc_regs *)addr;
	params->family = dev_get_driver_data(dev);

#ifdef CONFIG_CLK
	struct clk clk;

	ret = clk_get_by_index(dev, 0, &clk);
	if (ret < 0)
		return ret;

	ret = clk_enable(&clk);

	if (ret) {
		dev_err(dev, "failed to enable clock\n");
		return ret;
	}
#endif
	ret = stm32_sdram_init(dev);
	if (ret)
		return ret;

	return 0;
}
```

##  pinctrl_select_state(dev, "default")
```c
//pinctrl_select_state_simple(dev, "default");
```


# log
```log
//-----------------fmc device_probe---------------------
DRAM: device_probe() probing fmc@52004000 flag 0x42
device_probe() probing driver stm32_fmc for fmc@52004000 uclass ram
stm32_fmc fmc@52004000: can't find syscon device (-2)
//-----------------stm32_fmc_of_to_plat---------------------
stm32_fmc_of_to_plat() Find bank 0 0
//-----------------stm32_sdram_init---------------------
ofnode_read_u32_index() ofnode_read_u32_index: st,sdram-refcount: 0x2a5 (677)
stm32_fmc fmc@52004000: no of banks = 1
device_probe() probing parent soc for fmc@52004000
device_probe() probing soc flag 0x1051
//-----------------fmc pinctrl_select_state---------------------
device_probe() probing pinctrl for fmc@52004000
uclass_find_device_by_seq() 0
uclass_find_device_by_seq()    - 0 'pinctrl@58020000'
uclass_find_device_by_seq()    - found
device_probe() probing pinctrl@58020000 flag 0x1041
pinctrl_stm32 pinctrl@58020000: periph->name = fmc@52004000
ofnode_read_prop() ofnode_read_prop: pinmux: No of pinmux entries= 39
ofnode_read_u32_array() ofnode_read_u32_array: pinmux: pinmux = 300d
drivers/pinctrl/pinctrl_stm32.c:318-       prep_gpio_dsc() GPIO:port= 3, pin= 0
ofnode_read_u32_index() ofnode_read_u32_index: slew-rate: 0x3 (3)
ofnode_read_bool() ofnode_read_bool: drive-open-drain: false
ofnode_read_bool() ofnode_read_bool: bias-pull-up: false
ofnode_read_bool() ofnode_read_bool: bias-pull-down: false
prep_gpio_ctl() gpio fn= 13, slew-rate= 3, op type= 0, pull-upd is = 0
uclass_find_device_by_seq() 3
uclass_find_device_by_seq()    - 0 'gpio@58020000'
uclass_find_device_by_seq()    - 1 'gpio@58020400'
uclass_find_device_by_seq()    - 2 'gpio@58020800'
uclass_find_device_by_seq()    - 3 'gpio@58020c00'
uclass_find_device_by_seq()    - found
device_probe() probing gpio@58020c00 flag 0x40
device_probe() probing driver gpio_stm32 for gpio@58020c00 uclass gpio
alloc_simple() size=8, ptr=ad8, limit=2000: 2403ead0
alloc_simple() size=14, ptr=aec, limit=2000: 2403ead8
device_probe() probing parent pinctrl@58020000 for gpio@58020c00
device_probe() probing pinctrl@58020000 flag 0x1041
device_probe() probing pinctrl for gpio@58020c00
uclass_find_device_by_seq() 0
uclass_find_device_by_seq()    - 0 'pinctrl@58020000'
uclass_find_device_by_seq()    - found
device_probe() probing pinctrl@58020000 flag 0x1041
device_probe() Device 'gpio@58020c00' failed to configure default pinctrl: -22 ()
//-----------------GPIO D段 控制-----------------------------
ofnode_read_prop() ofnode_read_prop: st,bank-name: GPIOD
gpio_stm32 gpio@58020c00: addr = 0x58020c00 bank_name = GPIOD gpio_count = 16 gpio_range = 0xffff
uclass_get_device_by_ofnode() Looking for reset-clock-controller@58024400
uclass_find_device_by_ofnode() Looking for reset-clock-controller@58024400
uclass_find_device_by_ofnode()       - checking reset-clock-controller@58024400
uclass_find_device_by_ofnode()    - result for reset-clock-controller@58024400: reset-clock-controller@58024400 (ret=0)
drivers/core/uclass.c:551-uclass_get_device_by_ofnode()    - result for reset-clock-controller@58024400: reset-clock-controller@58024400 (ret=0)
device_probe() probing reset-clock-controller@58024400 flag 0x1041
stm32_clk_of_xlate() stm32h7_rcc_clock reset-clock-controller@58024400: clk->id 33
stm32_clk_enable() stm32h7_rcc_clock reset-clock-controller@58024400: clkid=33 gate offset=0xe0 bit_index=3 name=gpiod
gpio_stm32 gpio@58020c00: clock enabled
alloc_simple() size=40, ptr=b2c, limit=2000: 2403eaec
alloc_simple() size=4, ptr=b30, limit=2000: 2403eb2c
alloc_simple() size=6, ptr=b36, limit=2000: 2403eb30
stm32_pinctrl_config() rv = 0
//-----------------fmc 的 pin 控制-----------------------------
stm32_pinctrl_config() pinmux = 310d
prep_gpio_dsc() GPIO:port= 3, pin= 1
ofnode_read_u32_index() ofnode_read_u32_index: slew-rate: 0x3 (3)
ofnode_read_bool() ofnode_read_bool: drive-open-drain: false
ofnode_read_bool() ofnode_read_bool: bias-pull-up: false
ofnode_read_bool() ofnode_read_bool: bias-pull-down: false
prep_gpio_ctl() gpio fn= 13, slew-rate= 3, op type= 0, pull-upd is = 0
uclass_find_device_by_seq() 3
uclass_find_device_by_seq()    - 0 'gpio@58020000'
uclass_find_device_by_seq()    - 1 'gpio@58020400'
uclass_find_device_by_seq()    - 2 'gpio@58020800'
uclass_find_device_by_seq()    - 3 'gpio@58020c00'
uclass_find_device_by_seq()    - found
device_probe() probing gpio@58020c00 flag 0x1041
alloc_simple() size=6, ptr=b3e, limit=2000: 2403eb38
stm32_pinctrl_config() rv = 0
//-------------------------stm32_fmc_probe-----------------------------
stm32_fmc fmc@52004000: base = 52004000
uclass_get_device_by_ofnode() Looking for reset-clock-controller@58024400
uclass_find_device_by_ofnode() Looking for reset-clock-controller@58024400
uclass_find_device_by_ofnode()       - checking reset-clock-controller@58024400
uclass_find_device_by_ofnode()    - result for reset-clock-controller@58024400: reset-clock-controller@58024400 (ret=0)
uclass_get_device_by_ofnode()    - result for reset-clock-controller@58024400: reset-clock-controller@58024400 (ret=0)
device_probe() probing reset-clock-controller@58024400 flag 0x1041
stm32_clk_of_xlate() stm32h7_rcc_clock reset-clock-controller@58024400: clk->id 64
stm32_clk_enable() stm32h7_rcc_clock reset-clock-controller@58024400: clkid=64 gate offset=0xd4 bit_index=12 name=fmc
```