[TOC]

# serial-uclass.c
## serial_init
- `board_f.c`中调用`serial_init`
- `board_r.c`中调用`serial_initialize`

```c
/* Called after relocation */
int serial_initialize(void)
{
	/* Scanning uclass to probe devices */
	if (IS_ENABLED(CONFIG_SERIAL_PROBE_ALL)) {
		int ret;
        //探测所有的串口设备
		ret  = uclass_probe_all(UCLASS_SERIAL);
		if (ret)
			return ret;
	}

	return serial_init();
}

static void serial_find_console_or_panic(void)
{
	const void *blob = gd->fdt_blob;
	struct udevice *dev;
#ifdef CONFIG_SERIAL_SEARCH_ALL
	int ret;
#endif

	if (CONFIG_IS_ENABLED(OF_PLATDATA)) {
		uclass_first_device(UCLASS_SERIAL, &dev);
		if (dev) {
			gd->cur_serial_dev = dev;
			return;
		}
	} else if (CONFIG_IS_ENABLED(OF_CONTROL) && blob) {
		/* 分层树支持 stdout */
		if (of_live_active()) {
			struct device_node *np = of_get_stdout();

			if (np && !uclass_get_device_by_ofnode(UCLASS_SERIAL,
					np_to_ofnode(np), &dev)) {
				gd->cur_serial_dev = dev;   //找到stdout设备
				return;
			}
		} else {
			if (!serial_check_stdout(blob, &dev)) {
				gd->cur_serial_dev = dev;
				return;
			}
		}
	}
    //从所有激活的串口设备中找到一个作为当前设备
#ifdef CONFIG_REQUIRE_SERIAL_CONSOLE
	panic_str("No serial driver found");
#endif
	gd->cur_serial_dev = NULL;
}
```

## UCLASS_DRIVER
```c
UCLASS_DRIVER(serial) = {
	.id		= UCLASS_SERIAL,
	.name		= "serial",
	.flags		= DM_UC_FLAG_SEQ_ALIAS,
	.post_probe	= serial_post_probe,
	.pre_remove	= serial_pre_remove,
	.per_device_auto	= sizeof(struct serial_dev_priv),
};
```

## serial_post_probe 串口设备探测
1. 设置波特率
2. 注册串口设备到stdio
3. 调用接口函数注册
```c
static int serial_post_probe(struct udevice *dev)
{
	struct dm_serial_ops *ops = serial_get_ops(dev);
#if CONFIG_IS_ENABLED(DM_STDIO)
	struct serial_dev_priv *upriv = dev_get_uclass_priv(dev);
	struct stdio_dev sdev;
#endif
	int ret;

	/* Set the baud rate */
	if (ops->setbrg) {
		ret = ops->setbrg(dev, gd->baudrate);
		if (ret)
			return ret;
	}

#if CONFIG_IS_ENABLED(DM_STDIO)
	if (!(gd->flags & GD_FLG_RELOC))
		return 0;
	memset(&sdev, '\0', sizeof(sdev));

	strlcpy(sdev.name, dev->name, sizeof(sdev.name));
	sdev.flags = DEV_FLAGS_OUTPUT | DEV_FLAGS_INPUT | DEV_FLAGS_DM;
	sdev.priv = dev;
	sdev.putc = serial_stub_putc;
	sdev.puts = serial_stub_puts;
	STDIO_DEV_ASSIGN_FLUSH(&sdev, serial_stub_flush);
	sdev.getc = serial_stub_getc;
	sdev.tstc = serial_stub_tstc;

	stdio_register_dev(&sdev, &upriv->sdev);
#endif
	return 0;
}
```

## U_BOOT_ENV_CALLBACK
1. 波特率设置更改回调

# serial_stm32.c
## CONFIG_DEBUG_UART_STM32 早期初始化的debug串口
- include/debug_uart.h中有宏定义`DEBUG_UART_FUNCS`,定义了一系列函数
```c
#ifdef CONFIG_DEBUG_UART_STM32
#include <debug_uart.h>
static inline struct stm32_uart_info *_debug_uart_info(void)
{
	struct stm32_uart_info *uart_info;

#if defined(CONFIG_STM32F4)
	uart_info = &stm32f4_info;
#elif defined(CONFIG_STM32F7)
	uart_info = &stm32f7_info;
#else
	uart_info = &stm32h7_info;
#endif
	return uart_info;
}

static inline void _debug_uart_init(void)
{
	void __iomem *base = (void __iomem *)CONFIG_VAL(DEBUG_UART_BASE);
	struct stm32_uart_info *uart_info = _debug_uart_info();

	_stm32_serial_init(base, uart_info);
	_stm32_serial_setbrg(base, uart_info,
			     CONFIG_DEBUG_UART_CLOCK,
			     CONFIG_BAUDRATE);
}

static inline void _debug_uart_putc(int c)
{
	void __iomem *base = (void __iomem *)CONFIG_VAL(DEBUG_UART_BASE);
	struct stm32_uart_info *uart_info = _debug_uart_info();

	while (_stm32_serial_putc(base, uart_info, c) == -EAGAIN)
		;
}

DEBUG_UART_FUNCS	//这个宏用于在debug_uart.h声明的函数
#endif
```

## U_BOOT_DRIVER 驱动信息
```c
struct stm32_uart_info stm32f4_info = {
	.stm32f4 = true,
	.uart_enable_bit = 13,
	.has_fifo = false,
};

struct stm32_uart_info stm32f7_info = {
	.uart_enable_bit = 0,
	.stm32f4 = false,
	.has_fifo = true,
};

struct stm32_uart_info stm32h7_info = {
	.uart_enable_bit = 0,
	.stm32f4 = false,
	.has_fifo = true,
};

//data通过lists_bind_fdt函数中匹配的compatible来确定后,传递给device_bind_with_driver_data绑定device_data
static const struct udevice_id stm32_serial_id[] = {
	{ .compatible = "st,stm32-uart", .data = (ulong)&stm32f4_info},
	{ .compatible = "st,stm32f7-uart", .data = (ulong)&stm32f7_info},
	{ .compatible = "st,stm32h7-uart", .data = (ulong)&stm32h7_info},
	{}
};

static const struct dm_serial_ops stm32_serial_ops = {
	.putc = stm32_serial_putc,
	.pending = stm32_serial_pending,
	.getc = stm32_serial_getc,
	.setbrg = stm32_serial_setbrg,
	.setconfig = stm32_serial_setconfig
};

U_BOOT_DRIVER(serial_stm32) = {
	.name = "serial_stm32",
	.id = UCLASS_SERIAL,
	.of_match = of_match_ptr(stm32_serial_id),
	.of_to_plat = of_match_ptr(stm32_serial_of_to_plat),
	.plat_auto	= sizeof(struct stm32x7_serial_plat),
	.ops = &stm32_serial_ops,
	.probe = stm32_serial_probe,
#if !CONFIG_IS_ENABLED(OF_CONTROL)
	.flags = DM_FLAG_PRE_RELOC,
#endif
};
```

## stm32_serial_of_to_plat 识别设备信息并填充plat
- 在device_probe时通过device_of_to_plat调用执行
- 获取串口设备的寄存器地址给到plat->base

## stm32_serial_probe
```c
static int stm32_serial_probe(struct udevice *dev)
{
	struct stm32x7_serial_plat *plat = dev_get_plat(dev);
	struct clk clk;
	struct reset_ctl reset;
	u32 isr;
	int ret;
	bool stm32f4;
	//由compatible匹配到的data
	plat->uart_info = (struct stm32_uart_info *)dev_get_driver_data(dev);
	stm32f4 = plat->uart_info->stm32f4;

	ret = clk_get_by_index(dev, 0, &clk);
	if (ret < 0)
		return ret;

	ret = clk_enable(&clk);
	if (ret) {
		dev_err(dev, "failed to enable clock\n");
		return ret;
	}

	/*
	 * 在 UART 初始化之前，等待 TC 位 （Transmission Complete）
	 * 如果仍有来自上一个引导阶段的字符要传输
	 */
	ret = read_poll_timeout(readl, isr, isr & USART_ISR_TC, 50,
				16 * ONE_BYTE_B115200_US, plat->base + ISR_OFFSET(stm32f4));
	if (ret)
		dev_dbg(dev, "FIFO not empty, some character can be lost (%d)\n", ret);

	ret = reset_get_by_index(dev, 0, &reset);
	if (!ret) {
		reset_assert(&reset);
		udelay(2);
		reset_deassert(&reset);
	}

	plat->clock_rate = clk_get_rate(&clk);
	if (!plat->clock_rate) {
		clk_disable(&clk);
		return -EINVAL;
	};

	_stm32_serial_init(plat->base, plat->uart_info);

	return 0;
}
```