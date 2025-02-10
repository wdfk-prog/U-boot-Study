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
### gpio_post_bind 配置了GPIO_HOG属性的节点绑定gpio_hog驱动
- GPIO hogging是一种机制，允许在GPIO控制器的驱动程序探测（probe）函数中自动请求和配置GPIO。这种机制的主要目的是简化GPIO的初始化过程，确保在驱动程序加载时，GPIO能够自动配置为所需的状态。

### gpio_post_probe 为每个GPIO控制器分配name和claimed数组
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

### gpio_renumber 为每个GPIO控制器分配gpio_base
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

### gpio_request_list_by_name
### gpio_request_list_by_name_nodev 
### _gpio_request_by_name_nodev
### gpio_request_tail 通过node获取gpio_dev,并设置GPIO已经被占用,设置GPIO名字,设置GPIO方向
```c
static int gpio_request_tail(int ret, const char *nodename,
			     struct ofnode_phandle_args *args,
			     const char *list_name, int index,
			     struct gpio_desc *desc, int flags,
			     bool add_index, struct udevice *gpio_dev)
{
	/*
	desc->dev = dev;
	desc->offset = offset;
	desc->flags = 0;
	*/
	gpio_desc_init(desc, gpio_dev, 0);
	if (ret)
		goto err;

	if (!desc->dev) {	//如果没有找到gpio_dev,则根据node获取
		//从GPIO类中获取args->node节点的设备,并赋值给desc->dev
		ret = uclass_get_device_by_ofnode(UCLASS_GPIO, args->node,
						  &desc->dev);
		if (ret) {
			debug("%s: uclass_get_device_by_ofnode failed\n",
			      __func__);
			goto err;
		}
	}
	ret = gpio_find_and_xlate(desc, args);	//将phandle_args转换为gpio_desc
	if (ret) {
		debug("%s: gpio_find_and_xlate failed\n", __func__);
		goto err;
	}
	//设置GPIO已经被占用,设置GPIO名字
	ret = dm_gpio_requestf(desc, add_index ? "%s.%s%d" : "%s.%s",
			       nodename, list_name, index);
	if (ret) {
		debug("%s: dm_gpio_requestf failed\n", __func__);
		goto err;
	}

	/* 保留 devicetree 提供的任何方向标志 */
	ret = dm_gpio_set_dir_flags(desc,
				    flags | (desc->flags & GPIOD_MASK_DIR));
	if (ret) {
		debug("%s: dm_gpio_set_dir failed\n", __func__);
		goto err;
	}

	return 0;
err:
	debug("%s: Node '%s', property '%s', failed to request GPIO index %d: %d\n",
	      __func__, nodename, list_name, index, ret);
	return ret;
}
```

### gpio_find_and_xlate 将phandle_args转换为gpio_desc
```c
static int gpio_find_and_xlate(struct gpio_desc *desc,
			       struct ofnode_phandle_args *args)
{
	const struct dm_gpio_ops *ops = gpio_get_ops(desc->dev);

	if (ops->xlate)	//驱动自定义说明符识别
		return ops->xlate(desc->dev, desc, args);
	else	//默认说明符识别
		return gpio_xlate_offs_flags(desc->dev, desc, args);
}
```

### gpio_xlate_offs_flags 将phandle的arg[0]作为offset, arg[1]作为flags
```c
int gpio_xlate_offs_flags(struct udevice *dev, struct gpio_desc *desc,
			  struct ofnode_phandle_args *args)
{
	struct gpio_dev_priv *uc_priv = dev_get_uclass_priv(dev);

	if (args->args_count < 1)
		return -EINVAL;

	desc->offset = args->args[0];
	if (desc->offset >= uc_priv->gpio_count)
		return -EINVAL;

	if (args->args_count < 2)
		return 0;

	desc->flags = gpio_flags_xlate(args->args[1]);

	return 0;
}
```

### gpio_flags_xlate 转换FDT说明符为GPIO flags
```c
unsigned long gpio_flags_xlate(uint32_t arg)
{
	unsigned long flags = 0;

	if (arg & GPIO_ACTIVE_LOW)
		flags |= GPIOD_ACTIVE_LOW;

	/*
	 * need to test 2 bits for gpio output binding:
	 * OPEN_DRAIN (0x6) = SINGLE_ENDED (0x2) | LINE_OPEN_DRAIN (0x4)
	 * OPEN_SOURCE (0x2) = SINGLE_ENDED (0x2) | LINE_OPEN_SOURCE (0x0)
	 */
	if (arg & GPIO_SINGLE_ENDED) {
		if (arg & GPIO_LINE_OPEN_DRAIN)
			flags |= GPIOD_OPEN_DRAIN;
		else
			flags |= GPIOD_OPEN_SOURCE;
	}

	if (arg & GPIO_PULL_UP)
		flags |= GPIOD_PULL_UP;

	if (arg & GPIO_PULL_DOWN)
		flags |= GPIOD_PULL_DOWN;

	return flags;
}
```

### dts/upstream/include/dt-bindings/gpio/gpio.h GPIO flag 说明
```c
* Bit 0 express polarity */
#define GPIO_ACTIVE_HIGH 0
#define GPIO_ACTIVE_LOW 1

/* Bit 1 express single-endedness */
#define GPIO_PUSH_PULL 0
#define GPIO_SINGLE_ENDED 2

/* Bit 2 express Open drain or open source */
#define GPIO_LINE_OPEN_SOURCE 0
#define GPIO_LINE_OPEN_DRAIN 4

/*
 * Open Drain/Collector is the combination of single-ended open drain interface.
 * Open Source/Emitter is the combination of single-ended open source interface.
 */
#define GPIO_OPEN_DRAIN (GPIO_SINGLE_ENDED | GPIO_LINE_OPEN_DRAIN)
#define GPIO_OPEN_SOURCE (GPIO_SINGLE_ENDED | GPIO_LINE_OPEN_SOURCE)

/* Bit 3 express GPIO suspend/resume and reset persistence */
#define GPIO_PERSISTENT 0
#define GPIO_TRANSITORY 8

/* Bit 4 express pull up */
#define GPIO_PULL_UP 16

/* Bit 5 express pull down */
#define GPIO_PULL_DOWN 32

/* Bit 6 express pull disable */
#define GPIO_PULL_DISABLE 64
```

### dm_gpio_requestf 通过字符串请求GPIO,并设置GPIO已经被占用,设置GPIO名字
```c
// ret = dm_gpio_requestf(desc, add_index ? "%s.%s%d" : "%s.%s", nodename, list_name, index); 传入spi2.cs0
static int dm_gpio_requestf(struct gpio_desc *desc, const char *fmt, ...)
{
#if !defined(CONFIG_XPL_BUILD) || !CONFIG_IS_ENABLED(USE_TINY_PRINTF)
	va_list args;
	char buf[40];

	va_start(args, fmt);
	vscnprintf(buf, sizeof(buf), fmt, args);
	va_end(args);
	return dm_gpio_request(desc, buf);
#else
	return dm_gpio_request(desc, fmt);
#endif
}
```

### dm_gpio_request 通过字符串请求GPIO,并设置GPIO已经被占用,设置GPIO名字
```c
int dm_gpio_request(struct gpio_desc *desc, const char *label)
{
	const struct dm_gpio_ops *ops = gpio_get_ops(desc->dev);
	struct udevice *dev = desc->dev;
	struct gpio_dev_priv *uc_priv;
	char *str;
	int ret;

	uc_priv = dev_get_uclass_priv(dev);
	if (gpio_is_claimed(uc_priv, desc->offset))	//GPIO是否已经被占用
		return -EBUSY;
	str = strdup(label);
	if (!str)
		return -ENOMEM;
	if (ops->request) {
		ret = ops->request(dev, desc->offset, label);
		if (ret) {
			free(str);
			return ret;
		}
	}

	gpio_set_claim(uc_priv, desc->offset);	//设置GPIO已经被占用
	uc_priv->name[desc->offset] = str;		//设置GPIO名字

	return 0;
}
```

### dm_gpio_set_dir_flags 设置GPIO方向
```c
int dm_gpio_set_dir_flags(struct gpio_desc *desc, ulong flags)
{
	/* combine the requested flags (for IN/OUT) and the descriptor flags */
	return dm_gpio_clrset_flags(desc, GPIOD_MASK_DIR, flags);
}
```

### dm_gpio_clrset_flags 清除并设置GPIO flags
```c
int dm_gpio_clrset_flags(struct gpio_desc *desc, ulong clr, ulong set)
{
	ulong flags;
	int ret;

	ret = check_reserved(desc, "set_dir_flags");	//检查GPIO是否被占用,字符串用于debug输出是什么函数调用的
	if (ret)
		return ret;

	flags = (desc->flags & ~clr) | set;

	ret = _dm_gpio_set_flags(desc, flags);
	if (ret)
		return ret;

	/* save the flags also in descriptor */
	desc->flags = flags;

	return 0;
}
```

### _dm_gpio_set_flags 设置GPIO flags
```c
static int _dm_gpio_set_flags(struct gpio_desc *desc, ulong flags)
{
	struct udevice *dev = desc->dev;
	const struct dm_gpio_ops *ops = gpio_get_ops(dev);
	struct gpio_dev_priv *uc_priv = dev_get_uclass_priv(dev);
	int ret = 0;

	ret = check_dir_flags(flags);	//检查flag是否设置合法

	/* 如果低电平有效，则反转输出状态 */
	if ((flags & (GPIOD_IS_OUT | GPIOD_ACTIVE_LOW)) ==
		(GPIOD_IS_OUT | GPIOD_ACTIVE_LOW))
		flags ^= GPIOD_IS_OUT_ACTIVE;

	/* GPIOD_由驱动直接管理 set_flags */
	if (ops->set_flags) {
		ret = ops->set_flags(dev, desc->offset, flags);
	} else {
		if (flags & GPIOD_MASK_PULL)
			return -EINVAL;

		if (flags & GPIOD_IS_OUT) {
			bool value = flags & GPIOD_IS_OUT_ACTIVE;

			ret = ops->direction_output(dev, desc->offset, value);
		} else if (flags & GPIOD_IS_IN) {
			ret = ops->direction_input(dev, desc->offset);
		}
	}

	return ret;
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

### stm32_gpio_set_flags 设置GPIO flags
```c
static int stm32_gpio_set_flags(struct udevice *dev, unsigned int offset,
				ulong flags)
{
	struct stm32_gpio_priv *priv = dev_get_priv(dev);
	struct stm32_gpio_regs *regs = priv->regs;

	if (!stm32_gpio_is_mapped(dev, offset))
		return -ENXIO;

	if (flags & GPIOD_IS_OUT) {
		bool value = flags & GPIOD_IS_OUT_ACTIVE;

		if (flags & GPIOD_OPEN_DRAIN)
			stm32_gpio_set_otype(regs, offset, STM32_GPIO_OTYPE_OD);
		else
			stm32_gpio_set_otype(regs, offset, STM32_GPIO_OTYPE_PP);

		stm32_gpio_set_moder(regs, offset, STM32_GPIO_MODE_OUT);
		writel(BSRR_BIT(offset, value), &regs->bsrr);

	} else if (flags & GPIOD_IS_IN) {
		stm32_gpio_set_moder(regs, offset, STM32_GPIO_MODE_IN);
	}
	if (flags & GPIOD_PULL_UP)
		stm32_gpio_set_pupd(regs, offset, STM32_GPIO_PUPD_UP);
	else if (flags & GPIOD_PULL_DOWN)
		stm32_gpio_set_pupd(regs, offset, STM32_GPIO_PUPD_DOWN);

	return 0;
}
```