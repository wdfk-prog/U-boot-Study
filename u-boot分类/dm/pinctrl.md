[TOC]

# pinctrl-uclass.c
## pinctrl_post_bind 以递归方式将其子项绑定为 pinconfig属性的 设备

# pinctrl_stm32.c
## 驱动信息
```c
static const struct udevice_id stm32_pinctrl_ids[] = {
	{ .compatible = "st,stm32f429-pinctrl" },
	{ .compatible = "st,stm32f469-pinctrl" },
	{ .compatible = "st,stm32f746-pinctrl" },
	{ .compatible = "st,stm32f769-pinctrl" },
	{ .compatible = "st,stm32h743-pinctrl" },
	{ .compatible = "st,stm32mp157-pinctrl" },
	{ .compatible = "st,stm32mp157-z-pinctrl" },
	{ .compatible = "st,stm32mp135-pinctrl" },
	{ .compatible = "st,stm32mp257-pinctrl" },
	{ .compatible = "st,stm32mp257-z-pinctrl" },
	{ }
};

U_BOOT_DRIVER(pinctrl_stm32) = {
	.name			= "pinctrl_stm32",
	.id			= UCLASS_PINCTRL,
	.of_match		= stm32_pinctrl_ids,
	.ops			= &stm32_pinctrl_ops,
	.bind			= stm32_pinctrl_bind,
	.probe			= stm32_pinctrl_probe,
	.priv_auto	= sizeof(struct stm32_pinctrl_priv),
};
```

## stm32_pinctrl_bind 遍历具有gpio-controller的子节点绑定gpio_stm32驱动
- 绑定并probe GPIOA~GPIOK
```c
static int stm32_pinctrl_bind(struct udevice *dev)
{
	ofnode node;
	const char *name;
	int ret;
    //遍历当前设备节点的子节点
	dev_for_each_subnode(node, dev) {
		dev_dbg(dev, "bind %s\n", ofnode_get_name(node));

		if (!ofnode_is_enabled(node))
			continue;
        //需要具有gpio-controller属性
		ofnode_get_property(node, "gpio-controller", &ret);
		if (ret < 0)
			continue;
		/* Get the name of each gpio node */
		name = ofnode_get_name(node);
		if (!name)
			return -EINVAL;

		//绑定gpio_stm32驱动,并probe
		ret = device_bind_driver_to_node(dev, "gpio_stm32",
						 name, node, NULL);
		if (ret)
			return ret;

		dev_dbg(dev, "bind %s\n", name);
	}

	return 0;
}
```

## stm32_pinctrl_probe 初始化链表,绑定hwspinlock
```c
static int stm32_pinctrl_probe(struct udevice *dev)
{
	struct stm32_pinctrl_priv *priv = dev_get_priv(dev);
	int ret;

	INIT_LIST_HEAD(&priv->gpio_dev);	//初始化链表

	//有硬件自旋锁的话,绑定并probe
	ret = hwspinlock_get_by_index(dev, 0, &priv->hws);
	if (ret)
		dev_dbg(dev, "hwspinlock_get_by_index may have failed (%d)\n",
			ret);

	return 0;
}
```

# gpio
## gpio-uclass.c
## gpio_post_bind 配置了GPIO_HOG属性的节点绑定gpio_hog驱动
- GPIO hogging是一种机制，允许在GPIO控制器的驱动程序探测（probe）函数中自动请求和配置GPIO。这种机制的主要目的是简化GPIO的初始化过程，确保在驱动程序加载时，GPIO能够自动配置为所需的状态。

## gpio_post_probe 为每个GPIO控制器分配name和claimed数组
```c
static int gpio_post_probe(struct udevice *dev)
{
	struct gpio_dev_priv *uc_priv = dev_get_uclass_priv(dev);

	uc_priv->name = calloc(uc_priv->gpio_count, sizeof(char *));
	if (!uc_priv->name)
		return -ENOMEM;

	uc_priv->claimed = calloc(DIV_ROUND_UP(uc_priv->gpio_count,
					       GPIO_ALLOC_BITS),
				  GPIO_ALLOC_BITS / 8);
	if (!uc_priv->claimed) {
		free(uc_priv->name);
		return -ENOMEM;
	}

	return gpio_renumber(NULL);
}
```

## gpio_renumber 为每个GPIO控制器分配gpio_base
```c
static int gpio_renumber(struct udevice *removed_dev)
{
	struct gpio_dev_priv *uc_priv;
	struct udevice *dev;
	struct uclass *uc;
	unsigned base;
	int ret;

	ret = uclass_get(UCLASS_GPIO, &uc);
	if (ret)
		return ret;

	/* Ensure that we have a base for each bank */
	base = 0;
	uclass_foreach_dev(dev, uc) {
		if (device_active(dev) && dev != removed_dev) {
			uc_priv = dev_get_uclass_priv(dev);
			uc_priv->gpio_base = base;
			base += uc_priv->gpio_count;
		}
	}

	return 0;
}
```

## stm32_gpio.c
```c
    gpioa: gpio@58020000 {
        gpio-controller;
        #gpio-cells = <2>;
        reg = <0x0 0x400>;          //寄存器地址
        clocks = <&rcc GPIOA_CK>;
        st,bank-name = "GPIOA";     //段名
        interrupt-controller;
        #interrupt-cells = <2>;
        ngpios = <16>;
        gpio-ranges = <&pinctrl 
        0       //引脚起始
        0 
        16>;    //引脚数量
    };
```
### 驱动信息 由pinctrl_stm32.c绑定并probe
```c
U_BOOT_DRIVER(gpio_stm32) = {
	.name	= "gpio_stm32",
	.id	= UCLASS_GPIO,
	.probe	= gpio_stm32_probe,
	.ops	= &gpio_stm32_ops,
	.flags	= DM_UC_FLAG_SEQ_ALIAS, //支持序列别名
	.priv_auto	= sizeof(struct stm32_gpio_priv),
};
```

### gpio_stm32_probe 识别节点具有`st,bank-name`属性,设置gpio_count和gpio_range,并使能时钟
```c
static int gpio_stm32_probe(struct udevice *dev)
{
	struct stm32_gpio_priv *priv = dev_get_priv(dev);
	struct gpio_dev_priv *uc_priv = dev_get_uclass_priv(dev);
	struct ofnode_phandle_args args;
	const char *name;
	struct clk clk;
	fdt_addr_t addr;
	int ret, i;

	addr = dev_read_addr(dev);
	if (addr == FDT_ADDR_T_NONE)
		return -EINVAL;

	priv->regs = (struct stm32_gpio_regs *)addr;

	name = dev_read_string(dev, "st,bank-name");
	if (!name)
		return -EINVAL;
	uc_priv->bank_name = name;

	i = 0;
	ret = dev_read_phandle_with_args(dev, "gpio-ranges",
					 NULL, 3, i, &args);

	if (!ret && args.args_count < 3)
		return -EINVAL;

	uc_priv->gpio_count = STM32_GPIOS_PER_BANK; //16.GPIO一般一个段有16个引脚,但是有些会更少
	if (ret == -ENOENT) //没找到gpio-ranges属性,则默认16个引脚
		priv->gpio_range = GENMASK(STM32_GPIOS_PER_BANK - 1, 0);
    /*
    该属性可以有多个值,每个值代表一个引脚范围
    gpio-ranges =			<&pinctrl1 0 20 10>,
                            <&pinctrl2 10 0 0>,
                            <&pinctrl1 15 0 10>,
                            <&pinctrl2 25 0 0>;
    */
	while (ret != -ENOENT) {
        //设置gpio_range引脚范围
		priv->gpio_range |= GENMASK(args.args[2] + args.args[0] - 1,
				    args.args[0]);

		ret = dev_read_phandle_with_args(dev, "gpio-ranges", NULL, 3,
						 ++i, &args);
		if (!ret && args.args_count < 3)
			return -EINVAL;
	}

	dev_dbg(dev, "addr = 0x%p bank_name = %s gpio_count = %d gpio_range = 0x%x\n",
		(u32 *)priv->regs, uc_priv->bank_name, uc_priv->gpio_count,
		priv->gpio_range);
    //获取引脚时钟GPIOX_CK
	ret = clk_get_by_index(dev, 0, &clk);
	if (ret < 0)
		return ret;

	ret = clk_enable(&clk);

	if (ret) {
		dev_err(dev, "failed to enable clock\n");
		return ret;
	}
	dev_dbg(dev, "clock enabled\n");

	return 0;
}
```