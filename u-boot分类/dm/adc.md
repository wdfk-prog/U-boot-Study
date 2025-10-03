---
title: adc
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

# stm32-adc-core.c
## 驱动信息
```c
static const struct udevice_id stm32_adc_core_ids[] = {
	{ .compatible = "st,stm32h7-adc-core" },
	{ .compatible = "st,stm32mp1-adc-core" },
	{}
};

U_BOOT_DRIVER(stm32_adc_core) = {
	.name  = "stm32-adc-core",
	.id = UCLASS_SIMPLE_BUS,
	.of_match = stm32_adc_core_ids,
	.probe = stm32_adc_core_probe,
	.priv_auto	= sizeof(struct stm32_adc_common),
};
```

## stm32_adc_core_probe
1. 获取  `base` 地址
2. 获取 `vref-supply` 电压
3. 获取 `adc` 时钟
4. 获取 `bus` 时钟(不存在则跳过)
5. 选择时钟源
6. 使能时钟
```c
static int stm32_adc_core_probe(struct udevice *dev)
{
	struct stm32_adc_common *common = dev_get_priv(dev);
	int ret;

	common->base = dev_read_addr_ptr(dev);
	if (!common->base) {
		dev_err(dev, "can't get address\n");
		return -ENOENT;
	}

	ret = device_get_supply_regulator(dev, "vref-supply", &common->vref);
	if (ret) {
		dev_err(dev, "can't get vref-supply: %d\n", ret);
		return ret;
	}

	ret = regulator_get_value(common->vref);
	if (ret < 0) {
		dev_err(dev, "can't get vref-supply value: %d\n", ret);
		return ret;
	}
	common->vref_uv = ret;

	ret = clk_get_by_name(dev, "adc", &common->aclk);
	if (!ret) {
		ret = clk_enable(&common->aclk);
		if (ret) {
			dev_err(dev, "Can't enable aclk: %d\n", ret);
			return ret;
		}
	}

	ret = clk_get_by_name(dev, "bus", &common->bclk);
	if (!ret) {
		ret = clk_enable(&common->bclk);
		if (ret) {
			dev_err(dev, "Can't enable bclk: %d\n", ret);
			goto err_aclk_disable;
		}
	}

	ret = stm32h7_adc_clk_sel(dev, common);
	if (ret)
		goto err_bclk_disable;

	return ret;

err_bclk_disable:
	if (clk_valid(&common->bclk))
		clk_disable(&common->bclk);

err_aclk_disable:
	if (clk_valid(&common->aclk))
		clk_disable(&common->aclk);

	return ret;
}
```

# stm32-adc.c
- adc_core 下的子节点通过`UCLASS_SIMPLE_BUS`类的`simple_bus_post_bind`执行了扫描绑定到父节点
```c
static const struct udevice_id stm32_adc_ids[] = {
	{ .compatible = "st,stm32h7-adc",
	  .data = (ulong)&stm32h7_adc_cfg },
	{ .compatible = "st,stm32mp1-adc",
	  .data = (ulong)&stm32mp1_adc_cfg },
	{}
};

U_BOOT_DRIVER(stm32_adc) = {
	.name  = "stm32-adc",
	.id = UCLASS_ADC,
	.of_match = stm32_adc_ids,
	.probe = stm32_adc_probe,
	.ops = &stm32_adc_ops,
	.priv_auto	= sizeof(struct stm32_adc),
};
```

## stm32_adc_probe
1. 设置ADC通道
2. 退出电源休眠
3. 自校准
```c
static int stm32_adc_probe(struct udevice *dev)
{
	struct adc_uclass_plat *uc_pdata = dev_get_uclass_plat(dev);
	struct stm32_adc_common *common = dev_get_priv(dev_get_parent(dev));
	struct stm32_adc *adc = dev_get_priv(dev);
	int offset, ret;

	offset = dev_read_u32_default(dev, "reg", -ENODATA);
	if (offset < 0) {
		dev_err(dev, "Can't read reg property\n");
		return offset;
	}
	adc->regs = common->base + offset;
	adc->cfg = (const struct stm32_adc_cfg *)dev_get_driver_data(dev);

	/* VDD supplied by common vref pin */
	uc_pdata->vdd_supply = common->vref;
	uc_pdata->vdd_microvolts = common->vref_uv;
	uc_pdata->vss_microvolts = 0;

	ret = stm32_adc_chan_of_init(dev);
	if (ret < 0)
		return ret;

	ret = stm32_adc_exit_pwr_down(dev);
	if (ret < 0)
		return ret;

	ret = stm32_adc_selfcalib(dev);
	if (ret)
		stm32_adc_enter_pwr_down(dev);

	return ret;
}
```

# drivers/adc/adc-uclass.c
```c
UCLASS_DRIVER(adc) = {
	.id	= UCLASS_ADC,
	.name	= "adc",
	.pre_probe =  adc_pre_probe,
	.per_device_plat_auto	= ADC_UCLASS_PLATDATA_SIZE,
};
```

## adc_pre_probe 设置 VDD VSS
```c
static int adc_pre_probe(struct udevice *dev)
{
	int ret;

	/* 设置 ADC VDD 平台：极性、uV、稳压器 （phandle）. */
	ret = adc_vdd_plat_set(dev);
	if (ret)
		pr_err("%s: Can't update Vdd. Error: %d", dev->name, ret);

	/* /* 设置 ADC VSS 平台：极性、uV、稳压器 （phandle）。 */ */
	ret = adc_vss_plat_set(dev);
	if (ret)
		pr_err("%s: Can't update Vss. Error: %d", dev->name, ret);

	return 0;
}
```

## adc_vdd_plat_set adc_vss_plat_set
```c
static int adc_vdd_plat_set(struct udevice *dev)
{
	struct adc_uclass_plat *uc_pdata = dev_get_uclass_plat(dev);
	int ret;
	char *prop;

	prop = "vdd-polarity-negative";
	uc_pdata->vdd_polarity_negative = dev_read_bool(dev, prop);

	/* Optionally get regulators */
	ret = device_get_supply_regulator(dev, "vdd-supply",
					  &uc_pdata->vdd_supply);
	if (!ret)
		return adc_vdd_plat_update(dev);

	if (ret != -ENOSYS && ret != -ENOENT)
		return ret;

	/* No vdd-supply phandle. */
	prop  = "vdd-microvolts";
	uc_pdata->vdd_microvolts = dev_read_u32_default(dev, prop, -ENODATA);

	return 0;
}

static int adc_vss_plat_set(struct udevice *dev)
{
	struct adc_uclass_plat *uc_pdata = dev_get_uclass_plat(dev);
	int ret;
	char *prop;

	prop = "vss-polarity-negative";
	uc_pdata->vss_polarity_negative = dev_read_bool(dev, prop);

	ret = device_get_supply_regulator(dev, "vss-supply",
					  &uc_pdata->vss_supply);
	if (!ret)
		return adc_vss_plat_update(dev);

	if (ret != -ENOSYS && ret != -ENOENT)
		return ret;

	/* No vss-supply phandle. */
	prop = "vss-microvolts";
	uc_pdata->vss_microvolts = dev_read_u32_default(dev, prop, -ENODATA);

	return 0;
}
```