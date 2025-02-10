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

