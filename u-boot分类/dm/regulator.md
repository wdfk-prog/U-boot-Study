---
title: regulator
categories:
  - uboot
  - u-boot分类
  - dm
tags:
  - uboot
  - u-boot分类
  - dm
abbrlink: '656712e5'
date: 2025-10-03 09:44:27
---
[TOC]

# regulator-uclass.c
## 类信息
```c
UCLASS_DRIVER(regulator) = {
	.id		= UCLASS_REGULATOR,
	.name		= "regulator",
	.post_bind	= regulator_post_bind,
	.pre_probe	= regulator_pre_probe,
	.post_probe	= regulator_post_probe,
	.per_device_plat_auto	= sizeof(struct dm_regulator_uclass_plat),
};
```

## regulator_post_bind 读取设备属性用于设置设备属性,并检查设备是否是DM设备中唯一的
```c
static int regulator_post_bind(struct udevice *dev)
{
	struct dm_regulator_uclass_plat *uc_pdata;
	const char *property = "regulator-name";

	uc_pdata = dev_get_uclass_plat(dev);
	uc_pdata->always_on = dev_read_bool(dev, "regulator-always-on");
	uc_pdata->boot_on = dev_read_bool(dev, "regulator-boot-on");

	/* Regulator's mandatory constraint */
	uc_pdata->name = dev_read_string(dev, property);
	if (!uc_pdata->name) {
		dev_dbg(dev, "has no property '%s'\n", property);
		uc_pdata->name = dev_read_name(dev);
		if (!uc_pdata->name)
			return -EINVAL;
	}
    // 检查设备是否是DM设备中唯一的
	if (!regulator_name_is_unique(dev, uc_pdata->name)) {
		dev_err(dev, "'%s' has nonunique value: '%s\n",
			property, uc_pdata->name);
		return -EINVAL;
	}

	/*
	 * 如果调节器具有调节器始终开启或
	 * regulator-boot-on DT 属性，触发 probe（） 到
	 * 在启动期间配置其默认状态。
	 */
	if (uc_pdata->always_on || uc_pdata->boot_on)
		dev_or_flags(dev, DM_FLAG_PROBE_AFTER_BIND);

	return 0;
}
```

## regulator_name_is_unique 检查设备是否是DM设备中唯一的
```c
static bool regulator_name_is_unique(struct udevice *check_dev,
				     const char *check_name)
{
	struct dm_regulator_uclass_plat *uc_pdata;
	struct udevice *dev;
	int check_len = strlen(check_name);
	int ret;
	int len;

	for (ret = uclass_find_first_device(UCLASS_REGULATOR, &dev); dev;
	     ret = uclass_find_next_device(&dev)) {
		if (ret || dev == check_dev)
			continue;

		uc_pdata = dev_get_uclass_plat(dev);
		len = strlen(uc_pdata->name);
		if (len != check_len)
			continue;

		if (!strcmp(uc_pdata->name, check_name))
			return false;
	}

	return true;
}
```

## regulator_pre_probe 读取设备属性用于设置设备属性
```c
static int regulator_pre_probe(struct udevice *dev)
{
	struct dm_regulator_uclass_plat *uc_pdata;
	ofnode node;

	uc_pdata = dev_get_uclass_plat(dev);
	if (!uc_pdata)
		return -ENXIO;

	/* 调节器的可选约束*/
	uc_pdata->min_uV = dev_read_u32_default(dev, "regulator-min-microvolt",
						-ENODATA);
	uc_pdata->max_uV = dev_read_u32_default(dev, "regulator-max-microvolt",
						-ENODATA);
	uc_pdata->init_uV = dev_read_u32_default(dev, "regulator-init-microvolt",
						 -ENODATA);
	uc_pdata->min_uA = dev_read_u32_default(dev, "regulator-min-microamp",
						-ENODATA);
	uc_pdata->max_uA = dev_read_u32_default(dev, "regulator-max-microamp",
						-ENODATA);
	uc_pdata->ramp_delay = dev_read_u32_default(dev, "regulator-ramp-delay",
						    0);
	uc_pdata->force_off = dev_read_bool(dev, "regulator-force-boot-off");

	node = dev_read_subnode(dev, "regulator-state-mem");
	if (ofnode_valid(node)) {
		uc_pdata->suspend_on = !ofnode_read_bool(node, "regulator-off-in-suspend");
		if (ofnode_read_u32(node, "regulator-suspend-microvolt", &uc_pdata->suspend_uV))
			uc_pdata->suspend_uV = uc_pdata->max_uV;
	} else {
		uc_pdata->suspend_on = true;
		uc_pdata->suspend_uV = uc_pdata->max_uV;
	}

	/*这些值是可选的（如果未设置，则为 -ENODATA）*/
	if ((uc_pdata->min_uV != -ENODATA) &&
	    (uc_pdata->max_uV != -ENODATA) &&
	    (uc_pdata->min_uV == uc_pdata->max_uV))
		uc_pdata->flags |= REGULATOR_FLAG_AUTOSET_UV;

	/*这些值是可选的（如果未设置，则为 -ENODATA） */
	if ((uc_pdata->min_uA != -ENODATA) &&
	    (uc_pdata->max_uA != -ENODATA) &&
	    (uc_pdata->min_uA == uc_pdata->max_uA))
		uc_pdata->flags |= REGULATOR_FLAG_AUTOSET_UA;

	return 0;
}
```

## regulator_get_enable 获取启用状态
## regulator_set_enable 设置启用状态
```c
int regulator_set_enable(struct udevice *dev, bool enable)
{
	const struct dm_regulator_ops *ops = dev_get_driver_ops(dev);
	struct dm_regulator_uclass_plat *uc_pdata;
	int ret, old_enable = 0;

	if (!ops || !ops->set_enable)
		return -ENOSYS;

	uc_pdata = dev_get_uclass_plat(dev);
	if (!enable && uc_pdata->always_on) // 如果调节器始终开启 不需要设置
		return -EACCES;

	if (uc_pdata->ramp_delay)   //电压变化后的稳定时间（单位：uV/us）
		old_enable = regulator_get_enable(dev);

	ret = ops->set_enable(dev, enable);
	if (!ret) {
		if (uc_pdata->ramp_delay && !old_enable && enable) {
			int uV = regulator_get_value(dev);  //获取电压值

			if (uV > 0) {
                //根据当前电压值设置电压变化后的稳定时间所需的延时时间
				regulator_set_value_ramp_delay(dev, 0, uV,
							       uc_pdata->ramp_delay);
			}
		}
	}

	return ret;
}
```

## regulator_get_value 获取电压值

## regulator_post_probe 
```c
static int regulator_post_probe(struct udevice *dev)
{
	int ret;

	ret = regulator_autoset(dev);   //进行自动设置
	if (ret && ret != -EMEDIUMTYPE && ret != -EALREADY && ret != ENOSYS)
		return ret;

	if (_DEBUG)
		regulator_show(dev, ret);   //打印

	return 0;
}
```

# fixed.c
## 驱动信息
```c
static const struct udevice_id fixed_regulator_ids[] = {
	{ .compatible = "regulator-fixed" },
	{ },
};

U_BOOT_DRIVER(regulator_fixed) = {
	.name = "regulator_fixed",
	.id = UCLASS_REGULATOR,
	.ops = &fixed_regulator_ops,
	.of_match = fixed_regulator_ids,
	.of_to_plat = fixed_regulator_of_to_plat,
	.plat_auto = sizeof(struct regulator_common_plat),
};
```

## fixed_regulator_of_to_plat
```c
static int fixed_regulator_of_to_plat(struct udevice *dev)
{
	struct dm_regulator_uclass_plat *uc_pdata;
	struct regulator_common_plat *plat;
	bool gpios;

	plat = dev_get_plat(dev);
	uc_pdata = dev_get_uclass_plat(dev);
	if (!uc_pdata)
		return -ENXIO;

	uc_pdata->type = REGULATOR_TYPE_FIXED;

	gpios = dev_read_bool(dev, "gpios");
    //获取并绑定一些数据
	return regulator_common_of_to_plat(dev, plat, gpios ? "gpios" : "gpio");
}
```

# regulator_common.c
## regulator_common_of_to_plat
```c
int regulator_common_of_to_plat(struct udevice *dev,
				struct regulator_common_plat *plat,
				const char *enable_gpio_name)
{
	struct gpio_desc *gpio;
	int flags = GPIOD_IS_OUT;
	int ret;

	if (!dev_read_bool(dev, "enable-active-high"))
		flags |= GPIOD_ACTIVE_LOW;
	if (dev_read_bool(dev, "regulator-boot-on"))
		flags |= GPIOD_IS_OUT_ACTIVE;

	/* Get optional enable GPIO desc */
	gpio = &plat->gpio;
    //查找设备是否具有GPIO
	ret = gpio_request_by_name(dev, enable_gpio_name, 0, gpio, flags);
	if (ret) {
		debug("Regulator '%s' optional enable GPIO - not found! Error: %d\n",
		      dev->name, ret);
		if (ret != -ENOENT) //没找到也继续执行
			return ret;
	}

	/* Get optional ramp up delay */
	plat->startup_delay_us = dev_read_u32_default(dev,
						      "startup-delay-us", 0);
	plat->off_on_delay_us = dev_read_u32_default(dev, "off-on-delay-us", 0);
	if (!plat->off_on_delay_us) {
		plat->off_on_delay_us =
			dev_read_u32_default(dev, "u-boot,off-on-delay-us", 0);
	}

	return 0;
}
```

## regulator_common_get_enable && regulator_common_set_enable
- 通过GPIO控制

```c
int regulator_common_get_enable(const struct udevice *dev,
	struct regulator_common_plat *plat)
{
	/* Enable GPIO is optional */
	if (!plat->gpio.dev)
		return true;

	return dm_gpio_get_value(&plat->gpio);
}

int regulator_common_set_enable(const struct udevice *dev,
	struct regulator_common_plat *plat, bool enable)
{
	int ret;

	debug("%s: dev='%s', enable=%d, delay=%d, has_gpio=%d\n", __func__,
	      dev->name, enable, plat->startup_delay_us,
	      dm_gpio_is_valid(&plat->gpio));
	/* Enable GPIO is optional */
	if (!dm_gpio_is_valid(&plat->gpio)) {
		if (!enable)
			return -ENOSYS;
		return 0;
	}

	/* If previously enabled, increase count */
	if (enable && plat->enable_count > 0) {
		plat->enable_count++;
		return -EALREADY;
	}

	if (!enable) {
		if (plat->enable_count > 1) {
			/* If enabled multiple times, decrease count */
			plat->enable_count--;
			return -EBUSY;
		} else if (!plat->enable_count) {
			/* If already disabled, do nothing */
			return -EALREADY;
		}
	}

	ret = dm_gpio_set_value(&plat->gpio, enable);
	if (ret) {
		pr_err("Can't set regulator : %s gpio to: %d\n", dev->name,
		      enable);
		return ret;
	}

	if (enable && plat->startup_delay_us)
		udelay(plat->startup_delay_us);
	debug("%s: done\n", __func__);

	if (!enable && plat->off_on_delay_us)
		udelay(plat->off_on_delay_us);

	if (enable)
		plat->enable_count++;
	else
		plat->enable_count--;

	return 0;
}
```

# stm32-vrefbuf.c
## 驱动信息
```c
static const struct udevice_id stm32_vrefbuf_ids[] = {
	{ .compatible = "st,stm32-vrefbuf" },
	{ }
};

U_BOOT_DRIVER(stm32_vrefbuf) = {
	.name  = "stm32-vrefbuf",
	.id = UCLASS_REGULATOR,
	.of_match = stm32_vrefbuf_ids,
	.probe = stm32_vrefbuf_probe,
	.ops = &stm32_vrefbuf_ops,
	.priv_auto	= sizeof(struct stm32_vrefbuf),
};
```

## stm32_vrefbuf_probe
```c
static int stm32_vrefbuf_probe(struct udevice *dev)
{
	struct stm32_vrefbuf *priv = dev_get_priv(dev);
	int ret;

	priv->base = dev_read_addr_ptr(dev);

	ret = clk_get_by_index(dev, 0, &priv->clk);
	if (ret) {
		dev_err(dev, "Can't get clock: %d\n", ret);
		return ret;
	}

	ret = clk_enable(&priv->clk);
	if (ret) {
		dev_err(dev, "Can't enable clock: %d\n", ret);
		return ret;
	}
    // 获取vdda-supply设备
	ret = device_get_supply_regulator(dev, "vdda-supply",
					  &priv->vdda_supply);
	if (ret) {
		dev_dbg(dev, "No vdda-supply: %d\n", ret);
		return 0;
	}
    // 使能vdda-supply
	ret = regulator_set_enable(priv->vdda_supply, true);
	if (ret) {
		dev_err(dev, "Can't enable vdda-supply: %d\n", ret);
		clk_disable(&priv->clk);
	}

	return ret;
}
```