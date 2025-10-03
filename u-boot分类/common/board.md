---
title: board
categories:
  - uboot
  - u-boot分类
  - common
tags:
  - uboot
  - u-boot分类
  - common
abbrlink: 58562b47
date: 2025-10-03 09:44:27
---
[TOC]

# init/board_init.c

## board_init_f_alloc_reserve 板级初始化第一次分配保留空间

```c
// 
//Fast alloc
// top:栈顶地址,即堆栈指针地址sp传入
ulong board_init_f_alloc_reserve(ulong top)
{
	/* Reserve early malloc arena */
#ifndef CFG_MALLOC_F_ADDR	//没有定义快速分配地址
#if CONFIG_IS_ENABLED(SYS_MALLOC_F)	//配置系统自动快速分配
	top -= CONFIG_VAL(SYS_MALLOC_F_LEN);
#endif
#endif
	/* LAST ： 保留 GD （四舍五入为 16 字节的倍数） */
	top = rounddown(top-sizeof(struct global_data), 16);

	return top;
}
```

## board_init_f_init_reserve 板级初始化第一次始化保留

- 将传入的地址清零,并初始化全局数据结构;并设置malloc_base为base

```c
void board_init_f_init_reserve(ulong base)
{
	struct global_data *gd_ptr;
	gd_ptr = (struct global_data *)base;
	memset(gd_ptr, '\0', sizeof(*gd));
	/* next alloc will be higher by one GD plus 16-byte alignment */
	base += roundup(sizeof(struct global_data), 16);
#if CONFIG_IS_ENABLED(SYS_MALLOC_F)
	/* go down one 'early malloc arena' */
	gd->malloc_base = base;
#endif
}
```

# board_f.c

## board_init_f 板级初始化

```c
//传入的参数为0
void board_init_f(ulong boot_flags)
{
	struct board_f boardf;

	gd->flags = boot_flags;
	gd->flags &= ~GD_FLG_HAVE_CONSOLE;	//清除控制台标志
	gd->boardf = &boardf;

	if (initcall_run_list(init_sequence_f))
		hang();
}
```

## init_sequence_f 板级初始化调用列表

```c
static const init_fnc_t init_sequence_f[] = {
	setup_mon_len,	//设置监控长度
#ifdef CONFIG_OF_CONTROL
	fdtdec_setup,	//fdtdec初始化
#endif
	initf_malloc,	//初始化malloc
	arch_cpu_init,	/* 基本 Arch CPU 相关设置 */
	initf_dm,		//初始化设备管理
	env_init,		//初始化环境变量
	init_baud_rate,	//初始化波特率设置
	serial_init,
	console_init_f,		/* stage 1 init of console */
	display_options,	/* 打印u-boot版本 */
	display_text_info,	/* 打印段信息 */
#if defined(CONFIG_DISPLAY_BOARDINFO)
	show_board_info,	/* 打印板子信息 */
#endif
	INIT_FUNC_WATCHDOG_INIT
	INITCALL_EVENT(EVT_MISC_INIT_F),	//无效
	INIT_FUNC_WATCHDOG_RESET
	dram_init,		/* 配置可用的 RAM */
	/*
	 * 现在我们已经映射了 DRAM 并正常工作，我们可以
	 * 重新定位代码并继续从 DRAM 运行。
	 *
	 * 在 RAM 末尾保留内存（按此顺序自上而下）：
	 * - U-Boot 和 Linux 不会触及的区域（可选）
	 * - 内核日志缓冲区
	 * - 受保护的 RAM
	 * - LCD 帧缓冲器
	 * - 监控代码
	 * - 板信息结构体
	 */
	setup_dest_addr,		//设置relocaddr,重定向的ram_top地址
	reserve_round_4k,		//保留4k gd->relocaddr &= ~(4096 - 1);
	reserve_uboot,			//sp地址 预留的u-boot的代码数据
	reserve_malloc,			//sp地址 预留的堆空间
	reserve_board,			//sp地址 预留Board Info结构体
	reserve_global_data,	//sp地址 预留全局数据结构体
	reserve_fdt,			//sp地址 预留fdt
	reserve_stacks,			//sp地址 预留栈空间
	dram_init_banksize,		//初始化dram大小
	show_dram_config,		//显示dram配置
	INIT_FUNC_WATCHDOG_RESET
	setup_bdinfo,			//设置板子信息
	display_new_sp,
	INIT_FUNC_WATCHDOG_RESET
#if !defined(CONFIG_OF_BOARD_FIXUP) || !defined(CONFIG_OF_INITIAL_DTB_READONLY)
	reloc_fdt,				//重新定位fdt 将fdt放到relocaddr
#endif
	setup_reloc,			//计算reloc_off和拷贝gd到new_gd
```

### setup_mon_len

- 在lds链接脚本中:__bss_end 为bss段的结束地址, _start为代码段的开始地址(在arch/arm/lib/vectors_m.S中)

```c
static int setup_mon_len(void)
{
	gd->mon_len = (ulong)__bss_end - (ulong)_start;
	return 0;
}
```

### init_baud_rate
```c
static int init_baud_rate(void)
{
	gd->baudrate = env_get_ulong("baudrate", 10, CONFIG_BAUDRATE);
	return 0;
}
```

### show_board_info
- dts/upstream/src/arm/st/stm32h750i-art-pi.dts这里定义了
- model = "RT-Thread STM32H750i-ART-PI board"
```c
int show_board_info(void)
{
	if (IS_ENABLED(CONFIG_OF_CONTROL)) {
		int ret = -ENOSYS;

		if (IS_ENABLED(CONFIG_SYSINFO))	//没有配置.配置了没信息
			ret = try_sysinfo();

		/* Fail back to the main 'model' if available */
		if (ret) {
			const char *model;
			//从设备树中获取model型号
			model = fdt_getprop(gd->fdt_blob, 0, "model", NULL);
			if (model)
				printf("Model: %s\n", model);
		}
	}

	return checkboard();
}
```

### setup_dest_addr 设置relocaddr
```c
static int setup_dest_addr(void)
{
	debug("Monitor len: %08x\n", gd->mon_len);
	/*
	 * Ram is setup, size stored in gd !!
	 */
	debug("Ram size: %08llX\n", (unsigned long long)gd->ram_size);

	gd->ram_top = gd->ram_base + gd->ram_size;
	gd->relocaddr = gd->ram_top;
	debug("Ram top: %08llX\n", (unsigned long long)gd->ram_top);

	return 0;
}
```

### reserve_uboot 预留的u-boot的代码数据
```c
static int reserve_uboot(void)
{
	if (!(gd->flags & GD_FLG_SKIP_RELOC)) {
		/*
		 * 为U-Boot代码、数据和bss预留内存
		 * 向下舍入到下一个 4 kB 限制
		 */
		gd->relocaddr -= gd->mon_len;
		gd->relocaddr &= ~(4096 - 1);

		debug("Reserving %dk for U-Boot at: %08lx\n",
		      gd->mon_len >> 10, gd->relocaddr);
	}

	gd->start_addr_sp = gd->relocaddr;

	return 0;
}
```

### reserve_malloc 预留的堆空间
- 给app预留了0x100000的堆空间,并且给环境变量预留了0x2000的空间
```c
#define CONFIG_SYS_MALLOC_LEN 0x100000
#define CONFIG_ENV_SIZE 0x2000

#define	TOTAL_MALLOC_LEN	(CONFIG_SYS_MALLOC_LEN + CONFIG_ENV_SIZE)
static unsigned long reserve_stack_aligned(size_t size)
{
	return ALIGN_DOWN(gd->start_addr_sp - size, 16);
}
/* reserve memory for malloc() area */
static int reserve_malloc(void)
{
	gd->start_addr_sp = reserve_stack_aligned(TOTAL_MALLOC_LEN);
	debug("Reserving %dk for malloc() at: %08lx\n",
	      TOTAL_MALLOC_LEN >> 10, gd->start_addr_sp);
#ifdef CONFIG_SYS_NONCACHED_MEMORY
	reserve_noncached();
#endif

	return 0;
}
```

### reserve_board 预留Board Info结构体
```c
/* （永久） 分配一个 Board Info 结构体 */
static int reserve_board(void)
{
	if (!gd->bd) {
		gd->start_addr_sp = reserve_stack_aligned(sizeof(struct bd_info));
		gd->bd = (struct bd_info *)map_sysmem(gd->start_addr_sp,
						      sizeof(struct bd_info));
		memset(gd->bd, '\0', sizeof(struct bd_info));
		debug("Reserving %zu Bytes for Board Info at: %08lx\n",
		      sizeof(struct bd_info), gd->start_addr_sp);
	}
	return 0;
}
```

### reserve_global_data
```c
static int reserve_global_data(void)
{
	gd->start_addr_sp = reserve_stack_aligned(sizeof(gd_t));
	gd->new_gd = (gd_t *)map_sysmem(gd->start_addr_sp, sizeof(gd_t));
	debug("Reserving %zu Bytes for Global Data at: %08lx\n",
	      sizeof(gd_t), gd->start_addr_sp);
	return 0;
}
```

### reserve_fdt
```c
static int reserve_fdt(void)
{
	if (!IS_ENABLED(CONFIG_OF_EMBED)) {
		/*
		 * 如果设备树位于映像的正上方
		 * 那么我们必须重新定位它。如果它嵌入到数据中
		 * 部分，则它将与其他数据一起重新定位。
		 */
		if (gd->fdt_blob) {
			gd->boardf->fdt_size =
				ALIGN(fdt_totalsize(gd->fdt_blob), 32);

			gd->start_addr_sp = reserve_stack_aligned(
				gd->boardf->fdt_size);
			gd->boardf->new_fdt = map_sysmem(gd->start_addr_sp,
							 gd->boardf->fdt_size);
			debug("Reserving %lu Bytes for FDT at: %08lx\n",
			      gd->boardf->fdt_size, gd->start_addr_sp);
		}
	}

	return 0;
}
```

### reserve_stacks
```c
//arch/arm/lib/stack.c
int arch_reserve_stacks(void)
{
	/* setup stack pointer for exceptions */
	//irq_sp（中断堆栈指针）设置为 start_addr_sp（堆栈起始地址）。
	//这意味着异常处理将使用当前的堆栈起始地址作为堆栈指针
	gd->irq_sp = gd->start_addr_sp;

# if !defined(CONFIG_ARM64)
	/* 为 abort-stack 保留 3 个字，加上 1 个字用于对齐 */
	gd->start_addr_sp -= 16;
# endif

	return 0;
}

static int reserve_stacks(void)
{
	/* make stack pointer 16-byte aligned */
	gd->start_addr_sp = reserve_stack_aligned(16);

	/*
	 * let the architecture-specific code tailor gd->start_addr_sp and
	 * gd->irq_sp
	 */
	return arch_reserve_stacks();
}
```

### dram_init_banksize
```c
//board/st/stm32h750-art-pi/stm32h750-art-pi.c
int dram_init_banksize(void)
{
	fdtdec_setup_memory_banksize();

	return 0;
}

__weak int dram_init_banksize(void)
{
	gd->bd->bi_dram[0].start = gd->ram_base;
	gd->bd->bi_dram[0].size = get_effective_memsize();

	return 0;
}
```

# board_r.c

- r 通常表示 "relocation"（重定位)
- 在 U-Boot 启动过程中，重定位是一个关键步骤，它将 U-Boot 从加载地址移动到运行地址，并修正所有相关的地址引用。

## board_init_r 重定向后的板级初始化

```c
void board_init_r(gd_t *new_gd, ulong dest_addr)
{
	/*
	 * The pre-relocation drivers may be using memory that has now gone
	 * away. Mark serial as unavailable - this will fall back to the debug
	 * UART if available.
	 *
	 * Do the same with log drivers since the memory may not be available.
	 */
	gd->flags &= ~(GD_FLG_SERIAL_READY | GD_FLG_LOG_READY);

	gd->flags &= ~GD_FLG_LOG_READY;

	if (initcall_run_list(init_sequence_r))
		hang();

	// 应该执行到app中了,如果执行到这里,说明初始化失败
	hang();
}
```

## init_sequence_r 板级初始化调用列表

```c
static init_fnc_t init_sequence_r[] = {
	initr_trace,
	initr_reloc,	//gd->flags |= GD_FLG_RELOC | GD_FLG_FULL_MALLOC_INIT;
	event_init,
#if defined(CONFIG_ARM) || defined(CONFIG_RISCV)
	initr_caches,	//arch/arm/cpu/armv7m/cache.c
#endif
	initr_reloc_global_data,
	initr_malloc,
	log_init,
	initr_bootstage,	/* Needs malloc() but has its own timer */
	initr_of_live,
	initr_dm,
#if defined(CONFIG_ARM) || defined(CONFIG_RISCV) || defined(CONFIG_SANDBOX)
	board_init,	/* Setup chipselects */
#endif
	initr_lmb,	//初始化逻辑内存块
	initr_dm_devices,
	serial_initialize,
	initr_announce,	//打印u-boot重定向地址
	dm_announce,	//打印设备管理版本
#ifdef CONFIG_MMC
	initr_mmc,
#endif
	initr_env,
	stdio_add_devices,
	jumptable_init,
	console_init_r,		/* fully init console as a device */
	interrupt_init,
	run_main_loop,
}
```

### initr_reloc_global_data
```c
static int initr_reloc_global_data(void)
{
#ifdef __ARM__
	//board_f.c 中 gd->mon_len = (ulong)__bss_end - (ulong)_start;
	//差别在与是__bss_end还是__end,一个是bss段的结束地址,一个是代码段的结束地址
	monitor_flash_len = _end - __image_copy_start;
#endif
#ifdef CONFIG_SYS_RELOC_GD_ENV_ADDR
	 //env/env.c gd->env_addr = (ulong)&default_environment[0];
	gd->env_addr += gd->reloc_off;
#endif
}
```

### initr_malloc
- initf_malloc中初始化了malloc,在board_f中malloc将会增加malloc_ptr的值,而早期初始化的malloc大小为SYS_MALLOC_F_LEN,已经预留了
```c
static int initr_malloc(void)
{
	ulong start;

#if CONFIG_IS_ENABLED(SYS_MALLOC_F)
	debug("Pre-reloc malloc() used %#x bytes (%d KB)\n", gd->malloc_ptr,
	      gd->malloc_ptr / 1024);
#endif
	/* The malloc area is immediately below the monitor copy in DRAM */
	/*
	 * This value MUST match the value of gd->start_addr_sp in board_f.c:
	 * reserve_noncached().
	 */
	start = gd->relocaddr - TOTAL_MALLOC_LEN;
	mem_malloc_init(start, TOTAL_MALLOC_LEN);
	return 0;
}
```
