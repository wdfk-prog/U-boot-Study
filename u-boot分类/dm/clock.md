[TOC]
# clk-uclass.c
## clk_get_by_index
## clk_get_by_index_nodev 通过phandle索引到clocks设备节点,并转换客户端的设备树 （OF） 时钟说明符。
```c
int clk_get_by_index_nodev(ofnode node, int index, struct clk *clk)
{
	struct ofnode_phandle_args args;
	int ret;
	//从节点的phandle索引到clocks设备节点
	ret = ofnode_parse_phandle_with_args(node, "clocks", "#clock-cells", 0,
					     index, &args);
	//转换客户端的设备树 （OF） 时钟说明符。
	return clk_get_by_index_tail(ret, node, &args, "clocks",
				     index, clk);
}
```

## clk_get_by_index_tail 转换客户端的设备树 （OF） 时钟说明符。
```c
static int clk_get_by_index_tail(int ret, ofnode node,
				 struct ofnode_phandle_args *args,
				 const char *list_name, int index,
				 struct clk *clk)
{
	struct udevice *dev_clk;
	const struct clk_ops *ops;

	assert(clk);
	clk->dev = NULL;
	if (ret)
		goto err;
	//通过uclass id 查找与节点匹配的设备
	//这个时候已经绑定完所有可以操作的设备
	ret = uclass_get_device_by_ofnode(UCLASS_CLK, args->node, &dev_clk);

	clk->dev = dev_clk;

	ops = clk_dev_ops(dev_clk);

	if (ops->of_xlate)
		ret = ops->of_xlate(clk, args);	//转换客户端的设备树 （OF） 时钟说明符。
	else
		ret = clk_of_xlate_default(clk, args);
	if (ret) {
		debug("of_xlate() failed: %d\n", ret);
		return log_msg_ret("xlate", ret);
	}

	return clk_request(dev_clk, clk);
}
```

## clk_uclass_post_probe
```c
int clk_uclass_post_probe(struct udevice *dev)
{
	/*
	 * when a clock provider is probed. Call clk_set_defaults()
	 * also after the device is probed. This takes care of cases
	 * where the DT is used to setup default parents and rates
	 * using assigned-clocks
	 */
	clk_set_defaults(dev, CLK_DEFAULTS_POST);

	return 0;
}

UCLASS_DRIVER(clk) = {
	.id		= UCLASS_CLK,
	.name		= "clk",
	.post_probe	= clk_uclass_post_probe,
};
```

## clk_set_defaults
- CLK_DEFAULTS_PRE probe之前调用
- CLK_DEFAULTS_POST probe之后调用
- CLK_DEFAULTS_POST_FORCE 重定向后的probe之后调用
```c
enum clk_defaults_stage {
	CLK_DEFAULTS_PRE = 0,
	CLK_DEFAULTS_POST = 1,
	CLK_DEFAULTS_POST_FORCE,
};
```
- device_probe函数中调用
```c
	/* Only handle devices that have a valid ofnode */
	if (dev_has_ofnode(dev)) {
		/*
		 * Process 'assigned-{clocks/clock-parents/clock-rates}'
		 * properties
		 */
		ret = clk_set_defaults(dev, CLK_DEFAULTS_PRE);
		if (ret)
			goto fail;
	}
```

```c
int clk_set_defaults(struct udevice *dev, enum clk_defaults_stage stage)
{
	int ret;
	//如果不是reloc阶段,则不处理
	if (!(IS_ENABLED(CONFIG_XPL_BUILD) || (gd->flags & GD_FLG_RELOC)))
		if (stage != CLK_DEFAULTS_POST_FORCE)
			return 0;
	ret = clk_set_default_parents(dev, stage);

	ret = clk_set_default_rates(dev, stage);
	return 0;
}
```

## clk_set_default_parents 具备assigned-clock-parents属性才可以设置

## clk_set_default_rates 具备assigned-clock-rates属性才可以设置

## clk_request 一般不在使用ops->request,但是这里将clk绑定了dev
```c
int clk_request(struct udevice *dev, struct clk *clk)
{
	const struct clk_ops *ops;

	debug("%s(dev=%p, clk=%p)\n", __func__, dev, clk);
	if (!clk)
		return 0;
	ops = clk_dev_ops(dev);
	//注意这里将clk绑定了dev
	clk->dev = dev;

	if (!ops->request)
		return 0;

	return ops->request(clk);
}
```

## clk_get_rate 获取时钟频率

# stm32
## misc/stm32_rcc.c
- 根据设备树的compatible属性匹配对应的clk设备,并绑定到rcc设备上

### U_BOOT_DRIVER 定义
```c
static const struct udevice_id stm32_rcc_ids[] = {
	{.compatible = "st,stm32f42xx-rcc", .data = (ulong)&stm32_rcc_clk_f42x },
	{.compatible = "st,stm32f469-rcc", .data = (ulong)&stm32_rcc_clk_f469 },
	{.compatible = "st,stm32f746-rcc", .data = (ulong)&stm32_rcc_clk_f7 },
	{.compatible = "st,stm32h743-rcc", .data = (ulong)&stm32_rcc_clk_h7 },
	{.compatible = "st,stm32mp1-rcc", .data = (ulong)&stm32_rcc_clk_mp1 },
	{.compatible = "st,stm32mp1-rcc-secure", .data = (ulong)&stm32_rcc_clk_mp1 },
	{.compatible = "st,stm32mp13-rcc", .data = (ulong)&stm32_rcc_clk_mp13 },
	{ }
};

U_BOOT_DRIVER(stm32_rcc) = {
	.name		= "stm32-rcc",
	.id			= UCLASS_NOP,
	.of_match	= stm32_rcc_ids,
	.bind		= stm32_rcc_bind,
};
```

### stm32_rcc_bind
```c
static int stm32_rcc_bind(struct udevice *dev)
{
	struct udevice *child;
	struct driver *drv;
	struct stm32_rcc_clk *rcc_clk =
		(struct stm32_rcc_clk *)dev_get_driver_data(dev);	//匹配的of_match.data
	int ret;

	drv = lists_driver_lookup_name(rcc_clk->drv_name);		//查找对应的clk设备
	//写入driver data,并绑定drv的parent设备为rcc,fdt的偏移量节点,传入child当成该设备的节点
	ret = device_bind_with_driver_data(dev, drv, dev->name,
					   rcc_clk->soc,
					   dev_ofnode(dev), &child);

	drv = lists_driver_lookup_name("stm32_rcc_reset");		//查找对应的stm32_rcc_reset设备

	return device_bind_with_driver_data(dev, drv, dev->name,
					    rcc_clk->soc,
					    dev_ofnode(dev), &child);
}
```

## clk-stm32h7.c
- 由于没有of_match属性,所以不会在FDT中匹配到clk设备
- 通过`stm32_rcc.c`的compatible属性匹配到`stm32h7-rcc`设备,并设备绑定到rcc设备上
- 在根节点遍历probe时,通过rcc的child节点执行`stm32_clk_probe`函数

```c
U_BOOT_DRIVER(stm32h7_clk) = {
	.name			= "stm32h7_rcc_clock",
	.id			= UCLASS_CLK,
	.ops			= &stm32_clk_ops,
	.probe			= stm32_clk_probe,
	.priv_auto	= sizeof(struct stm32_clk),
	.flags			= DM_FLAG_PRE_RELOC,	//在reloc之前初始化
};
```

### stm32_clk_probe
```c
reset-clock-controller@58024400 {
	compatible = "st,stm32h743-rcc\0st,stm32-rcc";
	reg = <0x58024400 0x400>;
	#clock-cells = <0x01>;
	#reset-cells = <0x01>;
	clocks = <0x18 0x19 0x1a>;
	st,syscfg = <0x17>;
	bootph-all;
	phandle = <0x02>;
};

static int stm32_clk_probe(struct udevice *dev)
{
	struct stm32_clk *priv = dev_get_priv(dev);
	struct udevice *syscon;
	fdt_addr_t addr;
	int err;

	addr = dev_read_addr(dev);	//由rcc设备传入的node节点,获取的是rcc的地址
	if (addr == FDT_ADDR_T_NONE)
		return -EINVAL;

	priv->rcc_base = (struct stm32_rcc_regs *)addr;

	//获取rcc设备下的"st,syscfg"属性的phandle,通过phandle索引到syscon设备,并执行设备的probe函数
	err = uclass_get_device_by_phandle(UCLASS_SYSCON, dev,
					   "st,syscfg", &syscon);
	//获取syscon设备的regmap
	priv->pwr_regmap = syscon_get_regmap(syscon);
	configure_clocks(dev);
	return 0;
}
```

### configure_clocks
1. 使能HSI
2. 设置电压为1.15-1.26V
3. 锁定电源配置更新
4. 配置HSE:25 MHz
5. 配置PLL:pll1_p = 250MHz / pll1_q = 250MHz pll1_r = 250Mhz
6. 配置AHB: 125MHz
7. 配置APB: 125MHz
8. 配置SDRAM时钟: 125MHz

```c
/*
 * OSC_HSE = 25 MHz
 * VCO = 500MHz
 * pll1_p = 250MHz / pll1_q = 250MHz pll1_r = 250Mhz
 */
struct pll_psc sys_pll_psc = {
	.divm = 4,
	.divn = 80,
	.divp = 2,
	.divq = 2,
	.divr = 2,
};

int configure_clocks(struct udevice *dev)
{
	struct stm32_clk *priv = dev_get_priv(dev);
	struct stm32_rcc_regs *regs = priv->rcc_base;
	uint8_t *pwr_base = (uint8_t *)regmap_get_range(priv->pwr_regmap, 0);
	uint32_t pllckselr = 0;
	uint32_t pll1divr = 0;
	uint32_t pllcfgr = 0;

	/* Switch on HSI */
	setbits_le32(&regs->cr, RCC_CR_HSION);
	while (!(readl(&regs->cr) & RCC_CR_HSIRDY))
		;

	/* Reset CFGR, now HSI is the default system clock */
	writel(0, &regs->cfgr);

	/* Set all kernel domain clock registers to reset value*/
	writel(x0, &regs->d1ccipr);
	writel(0x0, &regs->d2ccip1r);
	writel(0x0, &regs->d2ccip2r);

	/* Set voltage scaling at scale 1 (1,15 - 1,26 Volts) */
	clrsetbits_le32(pwr_base + PWR_D3CR, PWR_D3CR_VOS_MASK,
			VOS_SCALE_1 << PWR_D3CR_VOS_SHIFT);
	/* Lock supply configuration update */
	clrbits_le32(pwr_base + PWR_CR3, PWR_CR3_SCUEN);
	while (!(readl(pwr_base + PWR_D3CR) & PWR_D3CR_VOSREADY))
		;

	/* disable HSE to configure it  */
	clrbits_le32(&regs->cr, RCC_CR_HSEON);
	while ((readl(&regs->cr) & RCC_CR_HSERDY))
		;

	/* clear HSE bypass and set it ON */
	clrbits_le32(&regs->cr, RCC_CR_HSEBYP);
	/* Switch on HSE */
	setbits_le32(&regs->cr, RCC_CR_HSEON);
	while (!(readl(&regs->cr) & RCC_CR_HSERDY))
		;

	/* pll setup, disable it */
	clrbits_le32(&regs->cr, RCC_CR_PLL1ON);
	while ((readl(&regs->cr) & RCC_CR_PLL1RDY))
		;

	/* Select HSE as PLL clock source */
	pllckselr |= RCC_PLLCKSELR_PLLSRC_HSE;
	pllckselr |= sys_pll_psc.divm << RCC_PLLCKSELR_DIVM1_SHIFT;
	writel(pllckselr, &regs->pllckselr);

	pll1divr |= (sys_pll_psc.divr - 1) << RCC_PLL1DIVR_DIVR1_SHIFT;
	pll1divr |= (sys_pll_psc.divq - 1) << RCC_PLL1DIVR_DIVQ1_SHIFT;
	pll1divr |= (sys_pll_psc.divp - 1) << RCC_PLL1DIVR_DIVP1_SHIFT;
	pll1divr |= (sys_pll_psc.divn - 1);
	writel(pll1divr, &regs->pll1divr);

	pllcfgr |= PLL1RGE_4_8_MHZ << RCC_PLLCFGR_PLL1RGE_SHIFT;
	pllcfgr |= RCC_PLLCFGR_DIVP1EN;
	pllcfgr |= RCC_PLLCFGR_DIVQ1EN;
	pllcfgr |= RCC_PLLCFGR_DIVR1EN;
	writel(pllcfgr, &regs->pllcfgr);

	/* pll setup, enable it */
	setbits_le32(&regs->cr, RCC_CR_PLL1ON);

	/* set HPRE (/2) DI clk --> 125MHz */
	clrsetbits_le32(&regs->d1cfgr, RCC_D1CFGR_HPRE_MASK,
			RCC_D1CFGR_HPRE_DIV2);

	/*  select PLL1 as system clock source (sys_ck)*/
	clrsetbits_le32(&regs->cfgr, RCC_CFGR_SW_MASK, RCC_CFGR_SW_PLL1);
	while ((readl(&regs->cfgr) & RCC_CFGR_SW_MASK) != RCC_CFGR_SW_PLL1)
		;

	/* sdram: use pll1_q as fmc_k clk */
	clrsetbits_le32(&regs->d1ccipr, RCC_D1CCIPR_FMCSRC_MASK,
			FMCSRC_PLL1_Q_CK);

	return 0;
}
```

### stm32_clk_of_xlate 转换客户端的设备树 （OF） 时钟说明符。
```c
static int stm32_clk_of_xlate(struct clk *clk,
			struct ofnode_phandle_args *args)
{
	//设备节点下的clocks属性内容只能有一个
	/*
		timer5: timer@40000c00 {
			compatible = "st,stm32-timer";
			reg = <0x40000c00 0x400>;
			interrupts = <50>;
			clocks = <&rcc TIM5_CK>;
		};
	*/
	if (args->args_count != 1) {
		dev_dbg(clk->dev, "Invalid args_count: %d\n", args->args_count);
		return -EINVAL;
	}

	if (args->args_count) {
		clk->id = args->args[0];
		if (clk->id >= KERN_BANK) {
			clk->id -= KERN_BANK;
			clk->id += LAST_PERIF_BANK - PERIF_BANK + 1;
		} else {
			clk->id -= PERIF_BANK;
		}
	} else {
		clk->id = 0;
	}

	dev_dbg(clk->dev, "clk->id %ld\n", clk->id);

	return 0;
}
```

### stm32_clk_get_rate 获取时钟频率
```c
static const struct clk_cfg clk_map[] = {};	//时钟配置表
static ulong stm32_clk_get_rate(struct clk *clk)
{
	struct stm32_clk *priv = dev_get_priv(clk->dev);
	struct stm32_rcc_regs *regs = priv->rcc_base;
	ulong sysclk = 0;
	u32 gate_offset;
	u32 d1cfgr, d3cfgr;
	/* prescaler table lookups for clock computation */
	u16 prescaler_table[8] = {2, 4, 8, 16, 64, 128, 256, 512};
	u8 source, idx;

	/*
	 * get system clock (sys_ck) source
	 * can be HSI_CK, CSI_CK, HSE_CK or pll1_p_ck
	 */
	source = readl(&regs->cfgr) & RCC_CFGR_SW_MASK;
	switch (source) {
	case RCC_CFGR_SW_PLL1:
		sysclk = stm32_get_PLL1_rate(regs, PLL1_P_CK);
		break;
	case RCC_CFGR_SW_HSE:
		sysclk = stm32_get_rate(regs, HSE);
		break;

	case RCC_CFGR_SW_CSI:
		sysclk = stm32_get_rate(regs, CSI);
		break;

	case RCC_CFGR_SW_HSI:
		sysclk = stm32_get_rate(regs, HSI);
		break;
	}

	/* sysclk = 0 ? no need to go ahead */
	if (!sysclk)
		return sysclk;

	dev_dbg(clk->dev, "system clock: source = %d freq = %ld\n",
		source, sysclk);

	d1cfgr = readl(&regs->d1cfgr);

	if (d1cfgr & RCC_D1CFGR_D1CPRE_DIVIDED) {
		/* get D1 domain Core prescaler */
		idx = (d1cfgr & RCC_D1CFGR_D1CPRE_DIVIDER) >>
		      RCC_D1CFGR_D1CPRE_SHIFT;
		sysclk = sysclk / prescaler_table[idx];
	}

	if (d1cfgr & RCC_D1CFGR_HPRE_DIVIDED) {
		/* get D1 domain AHB prescaler */
		idx = d1cfgr & RCC_D1CFGR_HPRE_DIVIDER;
		sysclk = sysclk / prescaler_table[idx];
	}

	gate_offset = clk_map[clk->id].gate_offset;

	dev_dbg(clk->dev, "clk->id=%ld gate_offset=0x%x sysclk=%ld\n",
		clk->id, gate_offset, sysclk);

	switch (gate_offset) {
	case RCC_AHB3ENR:
	case RCC_AHB1ENR:
	case RCC_AHB2ENR:
	case RCC_AHB4ENR:
		return sysclk;
		break;

	case RCC_APB3ENR:
		if (d1cfgr & RCC_D1CFGR_D1PPRE_DIVIDED) {
			/* get D1 domain APB3 prescaler */
			idx = (d1cfgr & RCC_D1CFGR_D1PPRE_DIVIDER) >>
			      RCC_D1CFGR_D1PPRE_SHIFT;
			sysclk = sysclk / prescaler_table[idx];
		}

		dev_dbg(clk->dev, "system clock: freq after APB3 prescaler = %ld\n",
			sysclk);

		return sysclk;
		break;

	case RCC_APB4ENR:
		d3cfgr = readl(&regs->d3cfgr);
		if (d3cfgr & RCC_D3CFGR_D3PPRE_DIVIDED) {
			/* get D3 domain APB4 prescaler */
			idx = (d3cfgr & RCC_D3CFGR_D3PPRE_DIVIDER) >>
			      RCC_D3CFGR_D3PPRE_SHIFT;
			sysclk = sysclk / prescaler_table[idx];
		}

		dev_dbg(clk->dev,
			"system clock: freq after APB4 prescaler = %ld\n",
			sysclk);

		return sysclk;
		break;

	case RCC_APB1LENR:
	case RCC_APB1HENR:
		/* special case for GPT timers */
		switch (clk->id) {
		case TIM14_CK:
		case TIM13_CK:
		case TIM12_CK:
		case TIM7_CK:
		case TIM6_CK:
		case TIM5_CK:
		case TIM4_CK:
		case TIM3_CK:
		case TIM2_CK:
			return stm32_get_timer_rate(priv, sysclk, APB1);
		}

		dev_dbg(clk->dev,
			"system clock: freq after APB1 prescaler = %ld\n",
			sysclk);

		return (sysclk / stm32_get_apb_psc(regs, APB1));
		break;

	case RCC_APB2ENR:
		/* special case for timers */
		switch (clk->id) {
		case TIM17_CK:
		case TIM16_CK:
		case TIM15_CK:
		case TIM8_CK:
		case TIM1_CK:
			return stm32_get_timer_rate(priv, sysclk, APB2);
		}

		dev_dbg(clk->dev,
			"system clock: freq after APB2 prescaler = %ld\n",
			sysclk);

		return (sysclk / stm32_get_apb_psc(regs, APB2));

		break;

	default:
		dev_err(clk->dev, "unexpected gate_offset value (0x%x)\n",
			gate_offset);
		return -EINVAL;
		break;
	}
}
```

### stm32_get_rate 获取时钟源频率
```c
static const char * const pllsrc_name[PLLSRC_NB] = {
	[HSE] = "clk-hse",
	[LSE] = "clk-lse",
	[HSI] = "clk-hsi",
	[CSI] = "clk-csi",
	[I2S] = "clk-i2s",
	[TIMER] = "timer-clk"
};

static ulong stm32_get_rate(struct stm32_rcc_regs *regs, enum pllsrc pllsrc)
{
	struct clk clk;
	struct udevice *fixed_clock_dev = NULL;
	u32 divider;
	int ret;
	const char *name = pllsrc_name[pllsrc];

	log_debug("pllsrc name %s\n", name);

	clk.id = 0;
	//通过名字匹配fixed-clock设备,并进行probe
	ret = uclass_get_device_by_name(UCLASS_CLK, name, &fixed_clock_dev);
	if (ret) {
		log_err("Can't find clk %s (%d)", name, ret);
		return 0;
	}

	ret = clk_request(fixed_clock_dev, &clk);
	if (ret) {
		log_err("Can't request %s clk (%d)", name, ret);
		return 0;
	}

	divider = 0;
	if (pllsrc == HSI)
		divider = stm32_get_HSI_divider(regs);
	//获取compatible = "fixed-clock"的节点下的clock-frequency属性值
	log_debug("divider %d rate %ld\n", divider, clk_get_rate(&clk));

	return clk_get_rate(&clk) >> divider;
};
```

### stm32_clk_enable 使能时钟
- 根据`of_xlate`的转换结果,获取对应的gate_offset和gate_bit_index
- 进而使能对应的时钟
```c
static int stm32_clk_enable(struct clk *clk)
{
	struct stm32_clk *priv = dev_get_priv(clk->dev);
	struct stm32_rcc_regs *regs = priv->rcc_base;
	u32 gate_offset;
	u32 gate_bit_index;
	unsigned long clk_id = clk->id;

	gate_offset = clk_map[clk_id].gate_offset;
	gate_bit_index = clk_map[clk_id].gate_bit_idx;

	dev_dbg(clk->dev, "clkid=%ld gate offset=0x%x bit_index=%d name=%s\n",
		clk->id, gate_offset, gate_bit_index,
		clk_map[clk_id].name);

	setbits_le32(&regs->cr + (gate_offset / 4), BIT(gate_bit_index));

	return 0;
}
```

# clk_fixed_rate.c 匹配fixed-clock设备
```c
static const struct udevice_id clk_fixed_rate_match[] = {
	{
		.compatible = "fixed-clock",
	},
	{ /* sentinel */ }
};

U_BOOT_DRIVER(fixed_clock) = {
	.name = "fixed_clock",
	.id = UCLASS_CLK,
	.of_match = clk_fixed_rate_match,
	.of_to_plat = clk_fixed_rate_of_to_plat,
	.plat_auto	= sizeof(struct clk_fixed_rate),
	.ops = &clk_fixed_rate_ops,
	.flags = DM_FLAG_PRE_RELOC,
};
```

## clk_fixed_rate_of_to_plat
- 获取设备树中的clock-frequency属性
- 将设备的CLK设备绑定到fixed-clock设备上,并设置fixed_rate和enable_count
```c
void clk_fixed_rate_ofdata_to_plat_(struct udevice *dev,
				    struct clk_fixed_rate *plat)
{
	struct clk *clk = &plat->clk;
	if (CONFIG_IS_ENABLED(OF_REAL))
		plat->fixed_rate = dev_read_u32_default(dev, "clock-frequency",
							0);

	/* Make fixed rate clock accessible from higher level struct clk */
	/* FIXME: This is not allowed */
	dev_set_uclass_priv(dev, clk);

	clk->dev = dev;
	clk->enable_count = 0;
}
```

## clk_fixed_rate_get_rate 获取固定的时钟频率,值是"clock-frequency"属性值

## stm32
```c
	clocks {
		bootph-all;
		clk_hse: clk-hse {
			#clock-cells = <0>;
			compatible = "fixed-clock";
			clock-frequency = <0>;
			bootph-all;
			phandle = <0x18>;
		};

		clk_lse: clk-lse {
			#clock-cells = <0>;
			compatible = "fixed-clock";
			clock-frequency = <32768>;
			bootph-all;
			phandle = <0x19>;
		};

		clk_i2s: i2s_ckin {
			#clock-cells = <0>;
			compatible = "fixed-clock";
			clock-frequency = <0>;
			bootph-all;
			phandle = <0x1a>;
		};
	};
```

# log
```log
//clk_get_by_index->clk_get_by_index_nodev
uclass_get_device_by_ofnode() Looking for reset-clock-controller@58024400
uclass_find_device_by_ofnode() Looking for reset-clock-controller@58024400
uclass_find_device_by_ofnode()       - checking reset-clock-controller@58024400
uclass_find_device_by_ofnode()    - result for reset-clock-controller@58024400: reset-clock-controller@58024400 
uclass_get_device_by_ofnode()    - result for reset-clock-controller@58024400: reset-clock-controller@58024400 (ret=0)
device_probe() probing reset-clock-controller@58024400 flag 0x1041
stm32_clk_of_xlate() stm32h7_rcc_clock reset-clock-controller@58024400: clk->id 33
stm32_clk_enable() stm32h7_rcc_clock reset-clock-controller@58024400: clkid=33 gate offset=0xe0 
gpio_stm32 gpio@58020c00: clock enabled
alloc_simple() size=40, ptr=b2c, limit=2000: 2403eaec
alloc_simple() size=4, ptr=b30, limit=2000: 2403eb2c
alloc_simple() size=6, ptr=b36, limit=2000: 2403eb30
stm32_pinctrl_config() rv = 0
```