[TOC]

# reset-uclass.c

## reset_get_by_index
```c
int reset_get_by_index(struct udevice *dev, int index,
		       struct reset_ctl *reset_ctl)
{
	struct ofnode_phandle_args args;
	int ret;
    //寻找当前节点的`resets`的phandle索引,内容为`#reset-cells`的设备节点
	ret = dev_read_phandle_with_args(dev, "resets", "#reset-cells", 0,
					 index, &args);

	return reset_get_by_index_tail(ret, dev_ofnode(dev), &args, "resets",
				       index > 0, reset_ctl);
}
```

## reset_get_by_index_tail

```c
static int reset_get_by_index_tail(int ret, ofnode node,
				   struct ofnode_phandle_args *args,
				   const char *list_name, int index,
				   struct reset_ctl *reset_ctl)
{
	struct udevice *dev_reset;
	struct reset_ops *ops;

	assert(reset_ctl);
	reset_ctl->dev = NULL;
	if (ret)
		return ret;
    //获取`resets`的设备节点,并执行probe
	ret = uclass_get_device_by_ofnode(UCLASS_RESET, args->node,
					  &dev_reset);
	if (ret) {
		debug("%s: uclass_get_device_by_ofnode() failed: %d\n",
		      __func__, ret);
		debug("%s %d\n", ofnode_get_name(args->node), args->args[0]);
		return ret;
	}
	ops = reset_dev_ops(dev_reset);

	reset_ctl->dev = dev_reset;
	if (ops->of_xlate)          //转换客户端的设备树说明符。
		ret = ops->of_xlate(reset_ctl, args);
	else
		ret = reset_of_xlate_default(reset_ctl, args);  //reset_ctl->id = args->args[0];
	if (ret) {
		debug("of_xlate() failed: %d\n", ret);
		return ret;
	}

	ret = ops->request ? ops->request(reset_ctl) : 0;
	if (ret) {
		debug("ops->request() failed: %d\n", ret);
		return ret;
	}

	return 0;
}
```

## reset_assert && reset_deassert
- reset_assert: 置位复位信号
- reset_deassert: 清除复位信号

# stm32-reset.c
## 驱动信息
```c
U_BOOT_DRIVER(stm32_rcc_reset) = {
	.name			= "stm32_rcc_reset",
	.id			= UCLASS_RESET,
	.probe			= stm32_reset_probe,
	.priv_auto	= sizeof(struct stm32_reset_priv),
	.ops			= &stm32_reset_ops,
};
```

## stm32_reset_probe 获取寄存器地址
```c
static int stm32_reset_probe(struct udevice *dev)
{
	struct stm32_reset_priv *priv = dev_get_priv(dev);

	priv->base = dev_read_addr(dev);
	if (priv->base == FDT_ADDR_T_NONE) {
		/* for MFD, get address of parent */
		priv->base = dev_read_addr(dev->parent);
		if (priv->base == FDT_ADDR_T_NONE)
			return -EINVAL;
	}

	return 0;
}
```

## stm32_reset_assert && stm32_reset_deassert
```c
static int stm32_reset_assert(struct reset_ctl *reset_ctl)
{
	struct stm32_reset_priv *priv = dev_get_priv(reset_ctl->dev);
	int bank = (reset_ctl->id / (sizeof(u32) * BITS_PER_BYTE)) * 4;
	int offset = reset_ctl->id % (sizeof(u32) * BITS_PER_BYTE);

	dev_dbg(reset_ctl->dev, "reset id = %ld bank = %d offset = %d)\n",
		reset_ctl->id, bank, offset);

	if (dev_get_driver_data(reset_ctl->dev) == STM32MP1)
		if (bank != RCC_MP_GCR_OFFSET)
			/* reset assert is done in rcc set register */
			writel(BIT(offset), priv->base + bank);
		else
			clrbits_le32(priv->base + bank, BIT(offset));
	else
		setbits_le32(priv->base + bank, BIT(offset));

	return 0;
}

static int stm32_reset_deassert(struct reset_ctl *reset_ctl)
{
	struct stm32_reset_priv *priv = dev_get_priv(reset_ctl->dev);
	int bank = (reset_ctl->id / (sizeof(u32) * BITS_PER_BYTE)) * 4;
	int offset = reset_ctl->id % (sizeof(u32) * BITS_PER_BYTE);

	dev_dbg(reset_ctl->dev, "reset id = %ld bank = %d offset = %d)\n",
		reset_ctl->id, bank, offset);

	if (dev_get_driver_data(reset_ctl->dev) == STM32MP1)
		if (bank != RCC_MP_GCR_OFFSET)
			/* reset deassert is done in rcc clr register */
			writel(BIT(offset), priv->base + bank + RCC_CL);
		else
			setbits_le32(priv->base + bank, BIT(offset));
	else
		clrbits_le32(priv->base + bank, BIT(offset));

	return 0;
}
```