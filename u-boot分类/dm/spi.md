[TOC]

# stm32_spi.c
## 驱动信息
```c
static const struct udevice_id stm32_spi_ids[] = {
	{ .compatible = "st,stm32h7-spi", },
	{ }
};

U_BOOT_DRIVER(stm32_spi) = {
	.name			= "stm32_spi",
	.id			= UCLASS_SPI,
	.of_match		= stm32_spi_ids,
	.ops			= &stm32_spi_ops,
	.of_to_plat		= stm32_spi_of_to_plat,
	.plat_auto		= sizeof(struct stm32_spi_plat),
	.priv_auto		= sizeof(struct stm32_spi_priv),
	.probe			= stm32_spi_probe,
	.remove			= stm32_spi_remove,
};
```

## stm32_spi_of_to_plat 获取寄存器地址, 时钟, 复位控制器, cs-gpios
```c
static int stm32_spi_of_to_plat(struct udevice *dev)
{
	struct stm32_spi_plat *plat = dev_get_plat(dev);
	int ret;

	plat->base = dev_read_addr_ptr(dev);
	if (!plat->base) {
		dev_err(dev, "can't get registers base address\n");
		return -ENOENT;
	}

	ret = clk_get_by_index(dev, 0, &plat->clk);
	if (ret < 0)
		return ret;

	ret = reset_get_by_index(dev, 0, &plat->rst_ctl);
	if (ret < 0)
		return ret;

	ret = gpio_request_list_by_name(dev, "cs-gpios", plat->cs_gpios,
					ARRAY_SIZE(plat->cs_gpios), 0);
	if (ret < 0) {
		dev_err(dev, "Can't get %s cs gpios: %d", dev->name, ret);
		return -ENOENT;
	}

	return 0;
}
```