---
title: spi
categories:
  - uboot
  - u-boot分类
  - dm
tags:
  - uboot
  - u-boot分类
  - dm
abbrlink: b2a7af11
date: 2025-10-03 09:44:27
---
[TOC]
# spi-uclass.c
## .post_bind dm_scan_fdt_dev
## spi_child_post_bind 子节点绑定到总线
```c
static int spi_child_post_bind(struct udevice *dev)
{
	struct dm_spi_slave_plat *plat = dev_get_parent_plat(dev);

	if (!dev_has_ofnode(dev))
		return 0;

	return spi_slave_of_to_plat(dev, plat);
}
```

## spi_slave_of_to_plat 获取spi设备的属性
```c
int spi_slave_of_to_plat(struct udevice *dev, struct dm_spi_slave_plat *plat)
{
	int mode = 0;
	int value;

#if CONFIG_IS_ENABLED(SPI_STACKED_PARALLEL)
	int ret;

	ret = dev_read_u32_array(dev, "reg", plat->cs, SPI_CS_CNT_MAX);

	if (ret == -EOVERFLOW || ret == -FDT_ERR_BADLAYOUT) {
		dev_read_u32(dev, "reg", &plat->cs[0]);
	} else {
		dev_err(dev, "has no valid 'reg' property (%d)\n", ret);
		return ret;
	}
#else
	plat->cs[0] = dev_read_u32_default(dev, "reg", -1);
#endif

	plat->max_hz = dev_read_u32_default(dev, "spi-max-frequency",
					    SPI_DEFAULT_SPEED_HZ);
	if (dev_read_bool(dev, "spi-cpol"))
		mode |= SPI_CPOL;
	if (dev_read_bool(dev, "spi-cpha"))
		mode |= SPI_CPHA;
	if (dev_read_bool(dev, "spi-cs-high"))
		mode |= SPI_CS_HIGH;
	if (dev_read_bool(dev, "spi-3wire"))
		mode |= SPI_3WIRE;
	if (dev_read_bool(dev, "spi-half-duplex"))
		mode |= SPI_PREAMBLE;

	/* Device DUAL/QUAD mode */
	value = dev_read_u32_default(dev, "spi-tx-bus-width", 1);
	switch (value) {
	case 1:
		break;
	case 2:
		mode |= SPI_TX_DUAL;
		break;
	case 4:
		mode |= SPI_TX_QUAD;
		break;
	case 8:
		mode |= SPI_TX_OCTAL;
		break;
	default:
		warn_non_xpl("spi-tx-bus-width %d not supported\n", value);
		break;
	}

	value = dev_read_u32_default(dev, "spi-rx-bus-width", 1);
	switch (value) {
	case 1:
		break;
	case 2:
		mode |= SPI_RX_DUAL;
		break;
	case 4:
		mode |= SPI_RX_QUAD;
		break;
	case 8:
		mode |= SPI_RX_OCTAL;
		break;
	default:
		warn_non_xpl("spi-rx-bus-width %d not supported\n", value);
		break;
	}

	plat->mode = mode;

	return 0;
}
```

## spi_post_probe 获取spi_max_hz
```c
static int spi_post_probe(struct udevice *bus)
{
	if (CONFIG_IS_ENABLED(OF_REAL)) {
		struct dm_spi_bus *spi = dev_get_uclass_priv(bus);

		spi->max_hz = dev_read_u32_default(bus, "spi-max-frequency", 0);
	}

	return 0;
}
```

## spi_child_pre_probe 子设备预配置,将总线的属性传递给子设备
```c
static int spi_child_pre_probe(struct udevice *dev)
{
	struct dm_spi_slave_plat *plat = dev_get_parent_plat(dev);
	struct spi_slave *slave = dev_get_parent_priv(dev);

	/*
	 * 这是必需的，因为我们在这个地方传递 struct spi_slave
	 * 代替 slave->dev （一个结构体 udevice）。所以我们必须有一些
	 * 访问从属 udevice 的方式给定 struct spi_slave。一旦我们
	 * 将 SPI API 改为 udevice 而不是 spi_slave，我们可以
	 * 删除这个。
	 */
	slave->dev = dev;
	slave->max_hz = plat->max_hz;
	slave->mode = plat->mode;
	slave->wordlen = SPI_DEFAULT_WORDLEN;

	return 0;
}
```

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
	// 获取cs-gpios并设置GPIO的电平与方向
	ret = gpio_request_list_by_name(dev, "cs-gpios", plat->cs_gpios,
					ARRAY_SIZE(plat->cs_gpios), 0);
	if (ret < 0) {
		dev_err(dev, "Can't get %s cs gpios: %d", dev->name, ret);
		return -ENOENT;
	}

	return 0;
}
```

## stm32_spi_probe 初始化spi控制器
- 使能时钟
- 获取时钟频率
- 执行复位
- 获取spi的fifo
- 设置spi的模式
- 设置CS使能引脚

```c
static int stm32_spi_probe(struct udevice *dev)
{
	struct stm32_spi_plat *plat = dev_get_plat(dev);
	struct stm32_spi_priv *priv = dev_get_priv(dev);
	void __iomem *base = plat->base;
	unsigned long clk_rate;
	int ret;
	unsigned int i;

	/* enable clock */
	ret = clk_enable(&plat->clk);
	if (ret < 0)
		return ret;

	clk_rate = clk_get_rate(&plat->clk);
	if (!clk_rate) {
		ret = -EINVAL;
		goto clk_err;
	}

	priv->bus_clk_rate = clk_rate;

	/* perform reset */
	reset_assert(&plat->rst_ctl);
	udelay(2);
	reset_deassert(&plat->rst_ctl);

	priv->fifo_size = stm32_spi_get_fifo_size(dev);
	priv->cur_mode = SPI_FULL_DUPLEX;
	priv->cur_xferlen = 0;
	priv->cur_bpw = SPI_DEFAULT_WORDLEN;
	clrsetbits_le32(base + STM32_SPI_CFG1, SPI_CFG1_DSIZE,
			priv->cur_bpw - 1);
	//设置SPI总线挂载的设备的CS使能引脚进行配置
	for (i = 0; i < ARRAY_SIZE(plat->cs_gpios); i++) {
		if (!dm_gpio_is_valid(&plat->cs_gpios[i]))
			continue;

		dm_gpio_set_dir_flags(&plat->cs_gpios[i],
				      GPIOD_IS_OUT | GPIOD_IS_OUT_ACTIVE);
	}

	/*确保 I2SMOD 位保持清零状态 */
	clrbits_le32(base + STM32_SPI_I2SCFGR, SPI_I2SCFGR_I2SMOD);

	/*
	 * - SS 输入值高
	 * - 发射器半双工方向
	 * - 当 RX-Fifo 满时自动暂停通信
	 */
	setbits_le32(base + STM32_SPI_CR1,
		     SPI_CR1_SSI | SPI_CR1_HDDIR | SPI_CR1_MASRX);

	/*
	 * - 设置主模式（默认 Motorola 模式）
	 * - 考虑 1 个主/n 个从站配置，并且SS 输入值由 SSI 位决定
	 * - 保持对所有相关 GPIO 的控制
	 */
	setbits_le32(base + STM32_SPI_CFG2,
		     SPI_CFG2_MASTER | SPI_CFG2_SSM | SPI_CFG2_AFCNTR);

	return 0;

clk_err:
	clk_disable(&plat->clk);

	return ret;
};
```

## stm32_spi_get_fifo_size 获取spi的fifo大小
- 写入数据到TXDR, 直到TXP为0, 以此来获取fifo的大小
```c
static int stm32_spi_get_fifo_size(struct udevice *dev)
{
	struct stm32_spi_plat *plat = dev_get_plat(dev);
	void __iomem *base = plat->base;
	u32 count = 0;

	stm32_spi_enable(base);

	while (readl(base + STM32_SPI_SR) & SPI_SR_TXP)
		writeb(++count, base + STM32_SPI_TXDR);

	stm32_spi_disable(base);

	dev_dbg(dev, "%d x 8-bit fifo size\n", count);

	return count;
}
```

## stm32_spi_remove 卸载spi设备
```c
static int stm32_spi_remove(struct udevice *dev)
{
	struct stm32_spi_plat *plat = dev_get_plat(dev);
	void __iomem *base = plat->base;
	int ret;

	stm32_spi_stopxfer(dev);
	stm32_spi_disable(base);

	ret = reset_assert(&plat->rst_ctl);
	if (ret < 0)
		return ret;

	reset_free(&plat->rst_ctl);

	return clk_disable(&plat->clk);
};
```

## stm32_spi_set_speed 设置spi的速度
## stm32_spi_set_mode 设置spi的模式
## stm32_spi_claim_bus 使能spi
```c
static int stm32_spi_claim_bus(struct udevice *slave)
{
	struct udevice *bus = dev_get_parent(slave);
	struct stm32_spi_plat *plat = dev_get_plat(bus);
	void __iomem *base = plat->base;

	dev_dbg(slave, "\n");

	/* Enable the SPI hardware */
	return stm32_spi_enable(base);
}
```

# sf_probe.c
1. spi_child_post_bind 子节点绑定到总线时,获取了spi设备的属性
- 如`spi-max-frequency`, `spi-cpol`, `spi-cpha`, `spi-cs-high`, `spi-3wire`, `spi-half-duplex`, `spi-tx-bus-width`, `spi-rx-bus-width`
- cs-gpios地址

## 驱动信息
```c
static const struct udevice_id spi_flash_std_ids[] = {
	{ .compatible = "jedec,spi-nor" },
	{ }
};

U_BOOT_DRIVER(jedec_spi_nor) = {
	.name		= "jedec_spi_nor",
	.id		= UCLASS_SPI_FLASH,
	.of_match	= spi_flash_std_ids,
	.probe		= spi_flash_std_probe,
	.remove		= spi_flash_std_remove,
	.priv_auto	= sizeof(struct spi_nor),
	.ops		= &spi_flash_std_ops,
	.flags		= DM_FLAG_OS_PREPARE,
};
```

## spi_flash_std_probe 绑定spi设备到spi总线
```c
int spi_flash_std_probe(struct udevice *dev)
{
	struct spi_slave *slave = dev_get_parent_priv(dev);
	struct spi_flash *flash;

	flash = dev_get_uclass_priv(dev);
	flash->dev = dev;
	flash->spi = slave;
	return spi_flash_probe_slave(flash);
}
```

## spi_flash_probe_slave 初始化SPI设备,并执行SFDP协议通信初始化SPI FLASH
```c
static int spi_flash_probe_slave(struct spi_flash *flash)
{
	struct spi_slave *spi = flash->spi;
	int ret;

	/* Setup spi_slave */
	if (!spi) {
		printf("SF: Failed to set up slave\n");
		return -ENODEV;
	}

	/* 获取spi bus, 并设置spi的速度与模式 */
	ret = spi_claim_bus(spi);
	if (ret) {
		debug("SF: Failed to claim SPI bus: %d\n", ret);
		return ret;
	}
	/*
		读取spi设备的id
		调用 spi_nor_init_params 解析串行闪存可发现参数表（SFDP）
		根据 info 的标志设置 nor 的标志，并根据 params 设置 nor 的页面大小和 mtd 的写缓冲区大小
		调用 spi_nor_setup 配置 SPI 闪存设备，包括选择操作码、设置虚拟周期和 SPI 协议等
		根据闪存设备的地址宽度和大小设置 nor 的地址宽度
		调用 spi_nor_init 发送所有必要的 SPI 闪存命令以初始化设备
	*/
	ret = spi_nor_scan(flash);	
	if (ret)
		goto err_read_id;

	if (CONFIG_IS_ENABLED(SPI_DIRMAP)) {
		ret = spi_nor_create_read_dirmap(flash);
		if (ret)
			return ret;

		ret = spi_nor_create_write_dirmap(flash);
		if (ret)
			return ret;
	}

	if (CONFIG_IS_ENABLED(SPI_FLASH_MTD))
		ret = spi_flash_mtd_register(flash);

err_read_id:
	spi_release_bus(spi);
	return ret;
}
```

## spi_claim_bus 获取spi总线,并设置spi的速度与模式
```c
int spi_claim_bus(struct spi_slave *slave)
{
	//在执行spi_child_pre_probe时,将spi_slave的dev指向了spi设备
	return log_ret(dm_spi_claim_bus(slave->dev));
}
```
## dm_spi_claim_bus 获取spi总线,并设置spi的速度与模式
- 总线与设备的速度与模式不一致时,设置总线的速度与模式
```c
int dm_spi_claim_bus(struct udevice *dev)
{
	struct udevice *bus = dev->parent;
	struct dm_spi_ops *ops = spi_get_ops(bus);
	struct dm_spi_bus *spi = dev_get_uclass_priv(bus);
	struct spi_slave *slave = dev_get_parent_priv(dev);
	uint speed, mode;

	speed = slave->max_hz;
	mode = slave->mode;

	if (spi->max_hz) {
		if (speed)
			speed = min(speed, spi->max_hz);
		else
			speed = spi->max_hz;
	}
	if (!speed)
		speed = SPI_DEFAULT_SPEED_HZ;

	if (speed != spi->speed || mode != spi->mode) {
		int ret = spi_set_speed_mode(bus, speed, slave->mode);

		if (ret)
			return log_ret(ret);

		spi->speed = speed;
		spi->mode = mode;
	}

	return log_ret(ops->claim_bus ? ops->claim_bus(dev) : 0);
}
```

## mtd/spi/spi-nor-core.c (过于细节,不做分析)