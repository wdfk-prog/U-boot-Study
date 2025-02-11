[TOC]
# i2c-uclass.c
## i2c_post_bind 扫描并绑定子节点
```c
static int i2c_post_bind(struct udevice *dev)
{
	int ret = 0;

	debug("%s: %s, seq=%d\n", __func__, dev->name, dev_seq(dev));

#if CONFIG_IS_ENABLED(OF_REAL)
	ret = dm_scan_fdt_dev(dev);
#endif
	return ret;
}
```

## i2c_pre_probe 读取u-boot,i2c-transaction-bytes的值
```c
static int i2c_pre_probe(struct udevice *dev)
{
#if CONFIG_IS_ENABLED(OF_REAL)
	struct dm_i2c_bus *i2c = dev_get_uclass_priv(dev);
	unsigned int max = 0;
	ofnode node;
	int ret;

	i2c->max_transaction_bytes = 0;
	dev_for_each_subnode(node, dev) {
		ret = ofnode_read_u32(node,
				      "u-boot,i2c-transaction-bytes",
				      &max);
		if (!ret && max > i2c->max_transaction_bytes)
			i2c->max_transaction_bytes = max;
	}

	debug("%s: I2C bus: %s max transaction bytes: %d\n", __func__,
	      dev->name, i2c->max_transaction_bytes);
#endif
	return 0;
}
```

## i2c_post_probe 读取i2c的速率
```c
static int i2c_post_probe(struct udevice *dev)
{
#if CONFIG_IS_ENABLED(OF_REAL)
	struct dm_i2c_bus *i2c = dev_get_uclass_priv(dev);

	i2c->speed_hz = dev_read_u32_default(dev, "clock-frequency",
					     I2C_SPEED_STANDARD_RATE);

	return dm_i2c_set_bus_speed(dev, i2c->speed_hz);
#else
	return 0;
#endif
}
```

## i2c_child_post_bind 
## i2c_chip_of_to_plat 设置i2c的地址与偏移
```c
int i2c_chip_of_to_plat(struct udevice *dev, struct dm_i2c_chip *chip)
{
	int addr;

	chip->offset_len = dev_read_u32_default(dev, "u-boot,i2c-offset-len",
						1);
	chip->flags = 0;
	addr = dev_read_u32_default(dev, "reg", -1);
	if (addr == -1) {
		debug("%s: I2C Node '%s' has no 'reg' property %s\n", __func__,
		      dev_read_name(dev), dev->name);
		return log_ret(-EINVAL);
	}
	chip->chip_addr = addr;

	return 0;
}
```

## dm_i2c_set_bus_speed 设置i2c的速率

# stm32f7_i2c.c
## 驱动信息
```c

static const struct stm32_i2c_data stm32f7_data = {
	.fmp_clr_offset = 0x00,
};

static const struct stm32_i2c_data stm32mp15_data = {
	.fmp_clr_offset = 0x40,
};

static const struct stm32_i2c_data stm32mp13_data = {
	.fmp_clr_offset = 0x4,
};

static const struct udevice_id stm32_i2c_of_match[] = {
	{ .compatible = "st,stm32f7-i2c", .data = (ulong)&stm32f7_data },
	{ .compatible = "st,stm32mp15-i2c", .data = (ulong)&stm32mp15_data },
	{ .compatible = "st,stm32mp13-i2c", .data = (ulong)&stm32mp13_data },
	{}
};

U_BOOT_DRIVER(stm32f7_i2c) = {
	.name = "stm32f7-i2c",
	.id = UCLASS_I2C,
	.of_match = stm32_i2c_of_match,
	.of_to_plat = stm32_of_to_plat,
	.probe = stm32_i2c_probe,
	.priv_auto	= sizeof(struct stm32_i2c_priv),
	.ops = &stm32_i2c_ops,
};
```

## stm32_of_to_plat 设置i2c的参数
```c
#define STM32_I2C_RISE_TIME_DEFAULT		25	/* ns */
#define STM32_I2C_FALL_TIME_DEFAULT		10	/* ns */

static int stm32_of_to_plat(struct udevice *dev)
{
	const struct stm32_i2c_data *data;
	struct stm32_i2c_priv *i2c_priv = dev_get_priv(dev);
	int ret;

	data = (const struct stm32_i2c_data *)dev_get_driver_data(dev);
	if (!data)
		return -EINVAL;

	i2c_priv->setup.rise_time = dev_read_u32_default(dev,
							 "i2c-scl-rising-time-ns",
							 STM32_I2C_RISE_TIME_DEFAULT);

	i2c_priv->setup.fall_time = dev_read_u32_default(dev,
							 "i2c-scl-falling-time-ns",
							 STM32_I2C_FALL_TIME_DEFAULT);

	i2c_priv->dnf_dt = dev_read_u32_default(dev, "i2c-digital-filter-width-ns", 0);
	if (!dev_read_bool(dev, "i2c-digital-filter"))
		i2c_priv->dnf_dt = 0;

	i2c_priv->setup.analog_filter = dev_read_bool(dev, "i2c-analog-filter");

	/* Optional */
	i2c_priv->regmap = syscon_regmap_lookup_by_phandle(dev,
							   "st,syscfg-fmp");
	if (!IS_ERR(i2c_priv->regmap)) {
		u32 fmp[3];

		ret = dev_read_u32_array(dev, "st,syscfg-fmp", fmp, 3);
		if (ret)
			return ret;

		i2c_priv->regmap_sreg = fmp[1];
		i2c_priv->regmap_creg = fmp[1] + data->fmp_clr_offset;
		i2c_priv->regmap_mask = fmp[2];
	}

	return 0;
}
```

## stm32_i2c_probe 使能时钟,复位i2c
```c
static int stm32_i2c_probe(struct udevice *dev)
{
	struct stm32_i2c_priv *i2c_priv = dev_get_priv(dev);
	struct reset_ctl reset_ctl;
	fdt_addr_t addr;
	int ret;

	addr = dev_read_addr(dev);
	if (addr == FDT_ADDR_T_NONE)
		return -EINVAL;

	i2c_priv->regs = (struct stm32_i2c_regs *)addr;

	ret = clk_get_by_index(dev, 0, &i2c_priv->clk);
	if (ret)
		return ret;

	ret = clk_enable(&i2c_priv->clk);
	if (ret)
		return ret;

	ret = reset_get_by_index(dev, 0, &reset_ctl);
	if (ret)
		goto clk_disable;

	reset_assert(&reset_ctl);
	udelay(2);
	reset_deassert(&reset_ctl);

	return 0;

clk_disable:
	clk_disable(&i2c_priv->clk);

	return ret;
}
```

## stm32_i2c_set_bus_speed 设置i2c的速率
```c
static int stm32_i2c_set_bus_speed(struct udevice *dev, unsigned int speed)
{
	struct stm32_i2c_priv *i2c_priv = dev_get_priv(dev);

	if (speed > I2C_SPEED_FAST_PLUS_RATE) {
		dev_dbg(dev, "Speed %d not supported\n", speed);
		return -EINVAL;
	}

	i2c_priv->speed = speed;

	return stm32_i2c_hw_config(i2c_priv);
}
```

## stm32_i2c_hw_config 配置i2c的时序
```c
static int stm32_i2c_hw_config(struct stm32_i2c_priv *i2c_priv)
{
	struct stm32_i2c_regs *regs = i2c_priv->regs;
	struct stm32_i2c_timings t;
	int ret;
	u32 timing = 0;

	ret = stm32_i2c_setup_timing(i2c_priv, &t);
	if (ret)
		return ret;

	/* Disable I2C */
	clrbits_le32(&regs->cr1, STM32_I2C_CR1_PE);

	/* Setup Fast mode plus if necessary */
	ret = stm32_i2c_write_fm_plus_bits(i2c_priv);
	if (ret)
		return ret;

	/* Timing settings */
	timing |= STM32_I2C_TIMINGR_PRESC(t.presc);
	timing |= STM32_I2C_TIMINGR_SCLDEL(t.scldel);
	timing |= STM32_I2C_TIMINGR_SDADEL(t.sdadel);
	timing |= STM32_I2C_TIMINGR_SCLH(t.sclh);
	timing |= STM32_I2C_TIMINGR_SCLL(t.scll);
	writel(timing, &regs->timingr);

	/* Enable I2C */
	if (i2c_priv->setup.analog_filter)
		clrbits_le32(&regs->cr1, STM32_I2C_CR1_ANFOFF);
	else
		setbits_le32(&regs->cr1, STM32_I2C_CR1_ANFOFF);

	/* Program the Digital Filter */
	clrsetbits_le32(&regs->cr1, STM32_I2C_CR1_DNF_MASK,
			STM32_I2C_CR1_DNF(i2c_priv->setup.dnf));

	setbits_le32(&regs->cr1, STM32_I2C_CR1_PE);

	return 0;
}
```