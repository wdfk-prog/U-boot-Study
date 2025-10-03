---
title: timer
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

# timer-uclass.c
## dm_timer_init
- 注意到这个函数在多个地方都可以被调;
	- DM扫描识别之后
	- `get_tick`和`get_tbclk`时没有`gd->timer`的时候
- 但是只有在`gd->timer`为空的时候才会执行

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
		node = ofnode_get_chosen_node("tick-timer");	//优先使用tick-timer节点

		if (ofnode_valid(node) &&	//节点有效
		    uclass_get_device_by_ofnode(UCLASS_TIMER, node, &dev)) {	//通过节点偏移量获取设备,并执行设备的probe函数,错误返回1
			//如果找到设备,则绑定设备
			if (!lists_bind_fdt(dm_root(), node, &dev, NULL, false)) {
				ret = device_probe(dev);	//执行设备的probe函数
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

## timer_pre_probe 获取设备的时钟频率
```c
static int timer_pre_probe(struct udevice *dev)
{
	if (CONFIG_IS_ENABLED(OF_REAL)) {
		struct timer_dev_priv *uc_priv = dev_get_uclass_priv(dev);
		struct clk timer_clk;
		int err;
		ulong ret;

		err = clk_get_by_index(dev, 0, &timer_clk);	//获取该节点时钟信息
		if (!err) {
			ret = clk_get_rate(&timer_clk);	//获取时钟频率
			if (!IS_ERR_VALUE(ret)) {
				uc_priv->clock_rate = ret;
				return 0;
			}
		}
		//如果获取时钟频率失败,则从节点中获取时钟频率
		uc_priv->clock_rate = dev_read_u32_default(dev, "clock-frequency", 0);
	}

	return 0;
}
```

## timer_post_probe 检查时钟频率为0,该设备初始化失败
```c
static int timer_post_probe(struct udevice *dev)
{
	struct timer_dev_priv *uc_priv = dev_get_uclass_priv(dev);

	if (!uc_priv->clock_rate)
		return -EINVAL;

	return 0;
}
```

# armv7m/systick-timer.c
- `timer_init`初始化定时器,在init_f时调用
- 提供`get_ticks`和`get_timer`函数,获取当前时间和定时器时间
- stm32系列没有使用这个定时器

# stm32_timer.c

## stm32_timer_probe 识别设备,并初始化为CFG_SYS_HZ_CLOCK的定时器
```c
static int stm32_timer_probe(struct udevice *dev)
{
	struct timer_dev_priv *uc_priv = dev_get_uclass_priv(dev);
	struct stm32_timer_priv *priv = dev_get_priv(dev);
	struct stm32_timer_regs *regs;
	struct clk clk;
	fdt_addr_t addr;
	int ret;
	u32 rate, psc;

	addr = dev_read_addr(dev);
	if (addr == FDT_ADDR_T_NONE)
		return -EINVAL;

	priv->base = (struct stm32_timer_regs *)addr;
	//获取rcc设备
	ret = clk_get_by_index(dev, 0, &clk);
	if (ret < 0)
		return ret;

	ret = clk_enable(&clk);	//根据of_xlate函数,转换说明符,使能TIM5_CK时钟
	if (ret) {
		dev_err(dev, "failed to enable clock\n");
		return ret;
	}

	regs = priv->base;

	/* Stop the timer */
	clrbits_le32(&regs->cr1, CR1_CEN);

	/* get timer clock */
	rate = clk_get_rate(&clk);

	/* we set timer prescaler to obtain a 1MHz timer counter frequency */
	psc = (rate / CFG_SYS_HZ_CLOCK) - 1;
	writel(psc, &regs->psc);

	/* Set timer frequency to 1MHz */
	uc_priv->clock_rate = CFG_SYS_HZ_CLOCK;

	/* Configure timer for auto-reload */
	setbits_le32(&regs->cr1, CR1_ARPE);

	/* load value for auto reload */
	writel(GPT_FREE_RUNNING, &regs->arr);

	/* start timer */
	setbits_le32(&regs->cr1, CR1_CEN);

	/* Update generation */
	setbits_le32(&regs->egr, EGR_UG);

	return 0;
}
```