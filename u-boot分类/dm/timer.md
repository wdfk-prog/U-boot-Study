[TOC]

# UCLASS_TIMER
```c
UCLASS_DRIVER(timer) = {
	.id		= UCLASS_TIMER,
	.name		= "timer",
	.pre_probe	= timer_pre_probe,
	.flags		= DM_UC_FLAG_SEQ_ALIAS,
	.post_probe	= timer_post_probe,
	.per_device_auto	= sizeof(struct timer_dev_priv),
};
```


## timer_pre_probe
- device_probe -> uclass_pre_probe_device -> pre_probe -> timer_pre_probe
- dev_get_uclass_priv -> uclass_priv_
- device_probe -> device_of_to_plat -> device_alloc_priv -> dev_set_uclass_priv -> uclass_priv_
```c
static int timer_pre_probe(struct udevice *dev)
{
	if (CONFIG_IS_ENABLED(OF_REAL)) {
		struct timer_dev_priv *uc_priv = dev_get_uclass_priv(dev);
		struct clk timer_clk;
		int err;
		ulong ret;

		/*
		 * It is possible that a timer device has a null ofnode
		 */
		if (!dev_has_ofnode(dev))
			return 0;
		// "clocks", "#clock-cells"
		err = clk_get_by_index(dev, 0, &timer_clk);	//通过FDT的获取设备的时钟
		if (!err) {
			ret = clk_get_rate(&timer_clk);	//成功获取时钟设备的频率
			if (!IS_ERR_VALUE(ret)) {
				uc_priv->clock_rate = ret;
				return 0;
			}
		}
		//如果没有获取到时钟,则从直接从FDT中获取时钟频率
		/*
		&clk_hse {
			clock-frequency = <25000000>;
		};
		*/
		uc_priv->clock_rate = dev_read_u32_default(dev, "clock-frequency", 0);
	}

	return 0;
}
```

# dm_timer_init
```c
int dm_timer_init(void)
{
	struct udevice *dev = NULL;
	__maybe_unused ofnode node;
	int ret;

	if (gd->timer)
		return 0;

	if (gd->dm_root == NULL)
		return -EAGAIN;

	if (CONFIG_IS_ENABLED(OF_REAL)) {
		/* Check for a chosen timer to be used for tick */
		node = ofnode_get_chosen_node("tick-timer");

		if (ofnode_valid(node) &&	//节点有效
		    uclass_get_device_by_ofnode(UCLASS_TIMER, node, &dev)) {	//通过节点偏移量获取设备,并执行设备的probe函数,错误返回1
			//如果没有找到设备,则绑定设备
			if (!lists_bind_fdt(dm_root(), node, &dev, NULL, false)) {
				ret = device_probe(dev);
				if (ret)
					return ret;
			}
		}
	}

	if (!dev) {
		/*回退到第一个可用时间,并执行device_probe*/
		ret = uclass_first_device_err(UCLASS_TIMER, &dev);
		if (ret)
			return ret;
	}

	if (dev) {
		gd->timer = dev;
		return 0;
	}

	return -ENODEV;
}
```

# stm32_timer.c
- 使用`U_BOOT_DRIVER`既可以注册一个驱动,并可以探测设备获取设置的寄存器地址
- 后续根据寄存器地址,可以进行读写操作

## 驱动信息
```c
static const struct timer_ops stm32_timer_ops = {
	.get_count = stm32_timer_get_count,
};

static const struct udevice_id stm32_timer_ids[] = {
	{ .compatible = "st,stm32-timer" },
	{}
};

U_BOOT_DRIVER(stm32_timer) = {
	.name = "stm32_timer",
	.id = UCLASS_TIMER,
	.of_match = stm32_timer_ids,
	.priv_auto	= sizeof(struct stm32_timer_priv),
	.probe = stm32_timer_probe,
	.ops = &stm32_timer_ops,
};
```
## stm32_timer_probe 探测
