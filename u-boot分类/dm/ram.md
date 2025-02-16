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
