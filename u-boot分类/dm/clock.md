[TOC]
# clk-uclass.c
## clk_uclass_post_probe
## clk_set_defaults
```c
UCLASS_DRIVER(clk) = {
	.id		= UCLASS_CLK,
	.name		= "clk",
	.post_probe	= clk_uclass_post_probe,
};
```

## clk_set_default_parents
- "assigned-clock-parents", "#clock-cells"获取有几个父节点和`parent_clk`
- assigned-clocks获取时钟频率

## clk_set_default_rates
- assigned-clock-rates获取时钟频率
- `set_rate`调用设置时钟频率

# clk_fixed_rate.c
- 注册固定频率时钟
- compatible =  "fixed-clock";
- get_rate = clk->fixed_rate;

## U_BOOT_DRIVER
```c
U_BOOT_DRIVER(fixed_clock) = {
	.name = "fixed_clock",
	.id = UCLASS_CLK,
	.of_match = clk_fixed_rate_match,
	.of_to_plat = clk_fixed_rate_of_to_plat,
	.plat_auto	= sizeof(struct clk_fixed_rate),
	.ops = &clk_fixed_rate_ops,
	.flags = DM_FLAG_PRE_RELOC,
};

U_BOOT_DRIVER(clk_fixed_rate_raw) = {
	.name = UBOOT_DM_CLK_FIXED_RATE_RAW,
	.id = UCLASS_CLK,
	.ops = &clk_fixed_rate_raw_ops,
	.flags = DM_FLAG_PRE_RELOC,
};
```


# stm32
## clk-stm32h7.c
