[toc]

# lds链接脚本 定义入口函数

- 链接脚步中定义了ENTRY(_start),即开始入口为_start

```lds
OUTPUT_FORMAT("elf32-littlearm", "elf32-littlearm", "elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(_start)
```

# arch/arm/lib/vectors_m.S 设置中断向量表8

- 从这里开始执行,即_start,这段代码定义了中断向量表,并且定义了中断处理函数的入口

```asm
   .section  .vectors
ENTRY(_start)
	.long	SYS_INIT_SP_ADDR		@ 0 - 定义了复位时的堆栈指针地址
	.long	reset				    @ 1 - 复位处理程序的地址
	.long	__invalid_entry			@ 2 - 非屏蔽中断（NMI）的处理程序地址
	.long	__hard_fault_entry		@ 3 - HardFault
	.long	__mm_fault_entry		@ 4 - MemManage
	.long	__bus_fault_entry		@ 5 - BusFault
	.long	__usage_fault_entry		@ 6 - UsageFault
	.long	__invalid_entry			@ 7 - Reserved
	.long	__invalid_entry			@ 8 - Reserved
	.long	__invalid_entry			@ 9 - Reserved
	.long	__invalid_entry			@ 10 - Reserved
	.long	__invalid_entry			@ 11 - SVCall
	.long	__invalid_entry			@ 12 - Debug Monitor
	.long	__invalid_entry			@ 13 - Reserved
	.long	__invalid_entry			@ 14 - PendSV
	.long	__invalid_entry			@ 15 - SysTick
	.rept	255 - 16                @ 用于重复定义从 16 到 255 的外部中断处理程序地址
	.long	__invalid_entry			@ 16..255 - External Interrupts
	.endr
```

- 反汇编显示,其中 `.word	0x24040000`即为 `SYS_INIT_SP_ADDR`,即堆栈指针地址
- 非循环指令一共16条,循环指令255 - 16 = 239条;一共255条,每条占用4字节,共1020字节(0x3fc)

```map
 *(.vectors)
 .vectors       0x0000000090000000      0x3fc arch/arm/lib/vectors_m.o
                0x0000000090000000                _start

Contents of section .vectors:
 0000 00000424 00000000 00000000 00000000  ...$............
    ---
 03f0 00000000 00000000 00000000           ............  

Disassembly of section .vectors:

00000000 <_start>:
   0:	24040000 	.word	0x24040000
	...

```

# arch/arm/cpu/armv7m/start.S 定义了reset函数,跳转到_main

- 使用objdump反汇编如下

```map
 arch/arm/cpu/armv7m/start.o(.text*)
 .text          0x00000000900003fc        0x6 arch/arm/cpu/armv7m/start.o
                0x00000000900003fc                reset
                0x0000000090000400                c_runtime_cpu_setup

Contents of section .text:
 0000 fff7febf f746                        .....F  
Disassembly of section .text:

00000000 <reset>:
   0:	f7ff bffe 	b.w	0 <_main>   //跳转到_main

00000004 <c_runtime_cpu_setup>:
   4:	46f7      	mov	pc, lr  //从程序中返回
```

- .s包含了asm/assembler.h,该头文件包含了asm/unified.h;其中对W(instr)的定义展开为 `instr.w`
- `mov	pc, lr`占用2字节,因为是thumb指令,Thumb 指令集是 ARM 处理器的一种压缩指令集，旨在减少代码大小，同时保持较高的性能。在 Thumb 指令集中，许多常用指令被编码为 16 位（2 字节）宽，而不是标准 ARM 指令集中的 32 位（4 字节）宽。这使得 Thumb 指令集在内存受限的嵌入式系统中非常有用。

# arch/arm/lib/crt0.S 定义了_ma1in函数

- 重新设置堆栈指针,并调用board_init_f_init_reserve初始化保留空间
- ABI（应用二进制接口）是指应用程序与操作系统或其他程序之间的接口标准。ABI 规定了函数调用约定、系统调用约定、数据类型的大小和对齐方式等。遵循 ABI 标准可以确保不同编译器生成的代码能够相互兼容，并且能够正确地与操作系统或其他程序进行交互。
- 在 ARM 架构中，函数调用时第一个参数通常通过寄存器 r0 传递

```asm
ENTRY(_main)
/* 在初始化 C 运行时环境之前调用 arch_very_early_init。*/
#if CONFIG_IS_ENABLED(ARCH_VERY_EARLY_INIT)	//没有定义不执行
	bl	arch_very_early_init
#endif
/* 设置初始 C 运行环境并调用 board_init_f（0）*/
#if defined(CONFIG_TPL_BUILD) && defined(CONFIG_TPL_NEEDS_SEPARATE_STACK)
	ldr	r0, =(CONFIG_TPL_STACK)
#elif defined(CONFIG_XPL_BUILD) && defined(CONFIG_SPL_STACK)
	ldr	r0, =(CONFIG_SPL_STACK)
#else
	ldr	r0, =(SYS_INIT_SP_ADDR)	//没有定义则使用系统初始化的堆栈指针地址
#endif
	bic	r0, r0, #7	/* 符合 ABI 标准的 8 字节对齐 */
	mov	sp, r0      /* 设置堆栈指针 */
	bl	board_init_f_alloc_reserve	//跳转到进入,传入r0参数
	mov	sp, r0		/* 重新设置堆栈指针,上述函数中重新设置了堆栈指针位置 */
	/* 在此处设置 GD，不带任何 C 代码 */
	mov	r9, r0
	bl	board_init_f_init_reserve	/* gd->malloc_base 设置 */

	mov	r0, #0
	bl	board_init_f	/* 调用板级初始化,执行一系列的初始化函数;初始化失败则死循环 */
#if ! defined(CONFIG_XPL_BUILD)

/*
 * 设置中间环境（新的 sp 和 gd）并调用 relocate_code（addr_moni）。这里的诀窍是我们将返回 “这里”但已搬迁。
 */
	ldr	r0, [r9, #GD_START_ADDR_SP]	/* sp = gd->start_addr_sp */
	bic	r0, r0, #7	/* 8-byte alignment for ABI compliance */
	mov	sp, r0
	ldr	r9, [r9, #GD_NEW_GD]		/* r9 <- gd->new_gd */

	adr	lr, here
	ldr	r0, [r9, #GD_RELOC_OFF]		/* r0 = gd->reloc_off */
	add	lr, lr, r0
#if defined(CONFIG_CPU_V7M)
	orr	lr, #1				/* As required by Thumb-only */
#endif
	ldr	r0, [r9, #GD_RELOCADDR]		/* r0 = gd->relocaddr */
	b	relocate_code	/* 跳转到relocate_code,进行对relocaddr进行重新定位 */
here:  
	/*
	* 现在重新定位向量表
	*/
	bl	relocate_vectors	// armv7m上,直接将向量表地址设置为relocaddr;V7M_SCB_VTOR = gd->relocaddr

	/* 设置最终 （完整） 环境 */
	bl	c_runtime_cpu_setup	// mov	pc, lr
	/* 清零BSS段（未初始化数据段） */
	CLEAR_BSS
	/* call board_init_r(gd_t *id, ulong dest_addr) */
	mov     r0, r9                  /* gd_t */
	ldr	r1, [r9, #GD_RELOCADDR]	/* dest_addr */
	/* call board_init_r */
	ldr	pc, =board_init_r	/* this is auto-relocated! */
	/* we should not return here. */
#endif

ENDPROC(_main)
```

# common/init/board_init.c

## board_init_f_alloc_reserve 板级初始化快速分配保留空间

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

## board_init_f_init_reserve 板级初始化快速始化保留

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

# common/board_f.c

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

# arch/arm/lib/relocate.S

- relocate_code 函数,用于重新定位代码
- - 在 U-Boot 启动过程中，重定位是一个关键步骤，它将 U-Boot 从加载地址移动到运行地址，并修正所有相关的地址引用。

```c
	ldr	r0, [r9, #GD_RELOCADDR]		/* r0 = gd->relocaddr */
	b	relocate_code
ENTRY(relocate_code)
relocate_base:
	adr	r3, relocate_base
	/*为什么不用_image_copy_start直接计算呢?
	目的是为了支持位置无关执行（PIE），使得 U-Boot 镜像可以在加载到不同的内存地址时正确运行。
	这对于在不同内存位置加载和执行 U-Boot 镜像的场景非常重要，
	例如在主要存储（如闪存）损坏时，从以太网或 UART 加载镜像进行恢复。*/
	ldr	r1, _image_copy_start_ofs
	add	r1, r3			/* r1 <- Run &__image_copy_start */
	subs	r4, r0, r1		/* r4 <-Run to copy offset  = gd->relocaddr - &__image_copy_start*/
    //r4 = &__image_copy_start - gd->relocaddr; //计算重新定位的偏移量
	beq	relocate_done		/* 如果偏移量为0,跳过拷贝 */
	ldr	r2, _image_copy_end_ofs
	add	r2, r3			/* r2 <- Run &__image_copy_end   */

copy_loop:
	//使用ldmia 和 stmia 地址会自动增加
	ldmia	r1!, {r10-r11}		/* 拷贝源地址 [r1] -> r10-r11 */
	stmia	r0!, {r10-r11}		/* 存储10-r11到目的地址 [r0](gd->relocaddr) */
	cmp	r1, r2			/* 一直循环到&__image_copy_end*/
	//如果 r1 中的值小于 r2 中的值，则继续循环
	blo	copy_loop

	/*
	 * fix .rel.dyn relocations
	 */
	ldr	r1, _rel_dyn_start_ofs
	add	r2, r1, r3		/* r2 <- Run &__rel_dyn_start */
	ldr	r1, _rel_dyn_end_ofs
	add	r3, r1, r3		/* r3 <- Run &__rel_dyn_end */
fixloop:
	ldmia	r2!, {r0-r1}		/* (r0,r1) <- (SRC location,fixup) */
	and	r1, r1, #0xff			//提取重定位类型
	cmp	r1, #R_ARM_RELATIVE		//判断是否是相对重定位
	bne	fixnext					//如果不是R_ARM_RELATIVE类型则进入下一个循环

	/*相对修复：增加偏移量的位置*/
	add	r0, r0, r4	//r0 = gd->relocaddr + Run to copy offset
	ldr	r1, [r0]	//r1 = &r0
	add	r1, r1, r4	//r1 = &r1+ Run to copy offset
	str	r1, [r0]	//将r1的值存储到&gd->relocaddr
fixnext:
	cmp	r2, r3		//循环到&__rel_dyn_end
	blo	fixloop

relocate_done:
	ret	lr  /* 返回到调用函数here + reloc_off处 */
ENDPROC(relocate_code)
```

# common/board_r.c

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

# common/main.c
```c
/* We come here after U-Boot is initialised and ready to process commands */
void main_loop(void)
{
	const char *s;

	bootstage_mark_name(BOOTSTAGE_ID_MAIN_LOOP, "main_loop");

	cli_init();

	s = bootdelay_process();	//获取启动延迟时间 
	//从FDT中获取命令行参数
	if (cli_process_fdt(&s))
		cli_secure_boot_cmd(s);
	//自动启动命令
	autoboot_command(s);
	//命令行循环
	cli_loop();

	panic("No CLI available");
}
```

## common/autoboot.c
### autoboot_command 自动启动命令
```c
void autoboot_command(const char *s)
{
	debug("### main_loop: bootcmd=\"%s\"\n", s ? s : "<UNDEFINED>");

	if (s && (stored_bootdelay == -2 ||
		 (stored_bootdelay != -1 && !abortboot(stored_bootdelay)))) {
		bool lock;
		int prev;

		lock = autoboot_keyed() &&
			!IS_ENABLED(CONFIG_AUTOBOOT_KEYED_CTRLC);
		if (lock)
			prev = disable_ctrlc(1); /* disable Ctrl-C checking */

		run_command_list(s, -1, 0);

		if (lock)
			disable_ctrlc(prev);	/* restore Ctrl-C checking */
	}

	if (IS_ENABLED(CONFIG_AUTOBOOT_USE_MENUKEY) &&
	    menukey == AUTOBOOT_MENUKEY) {
		s = env_get("menucmd");
		if (s)
			run_command_list(s, -1, 0);
	}
}
```

### abortboot 检查是否有按键中断
```c
static int abortboot(int bootdelay)
{
	int abort = 0;

	if (bootdelay >= 0) {
		if (autoboot_keyed())
			abort = abortboot_key_sequence(bootdelay);
		else
			abort = abortboot_single_key(bootdelay);
	}

	if (IS_ENABLED(CONFIG_SILENT_CONSOLE) && abort)
		gd->flags &= ~GD_FLG_SILENT;

	return abort;
}
```

### passwd_abort_key



# fdtdec 扁平设备树解析

- [devicetree](https://docs.u-boot.org/en/latest/develop/devicetree/index.html)

## fdtdec_setup 初始化fdtdec 写入fdt_blob和fdt_src

```c
int fdtdec_setup(void)
{
	int ret = -ENOENT;

	/* 使用bloblist查找设备树 */


	/* 否则，设备树通常会附加到 U-Boot */
	if (ret) {
		//在镜像末尾找到一个 devicetree
		if (IS_ENABLED(CONFIG_OF_SEPARATE)) {
			gd->fdt_blob = fdt_find_separate();
			gd->fdt_src = FDTSRC_SEPARATE;
		} else { //在ELF文件中嵌入dtb
			fdtdec_setup_embed();
		}
	}

	/* 允许板子覆盖 fdt 地址。 */

	/* 允许早期环境覆盖 fdt 地址 */

	/*  从 FIT 中找到正确的 dtb */

	ret = fdtdec_prepare_fdt(gd->fdt_blob);
	if (!ret)
		/* 根据设备数初始化硬件 */
		ret = fdtdec_board_setup(gd->fdt_blob);
	oftree_reset();

	return ret;
}
```

## fdt_find_separate 查找分离的fdt 返回在_end处的fdt,并检查是否正确
```c
//镜像末尾找到一个 devicetree
static void *fdt_find_separate(void)
{
	/* FDT is at end of image */
	fdt_blob = (ulong *)_end;

	if (_DEBUG && //开启调试打印
	!fdtdec_prepare_fdt(fdt_blob)) {	//检查fdt是否正确
		int stack_ptr;
		const void *top = fdt_blob + fdt_totalsize(fdt_blob);

		/*
		 * 对内存布局执行健全性检查。如果此操作失败，表示设备树位于全局数据指针或堆栈指针。这不应该发生。
		 * 如果失败，请检查SYS_INIT_SP_ADDR是否有足够的空间 用于 SYS_MALLOC_F_LEN 和 global_data，以及堆栈，
		 * 而不会覆盖设备树或 U-Boot 本身。 由于设备树位于 _end（BSS 区域），我们需要设备树的顶部位于下方
		 * 由 board_init_f_alloc_reserve（） 分配的任何内存。
		 */
		if (top > (void *)gd 	//gd地址就是SYS_INIT_SP_ADDR
		|| top > (void *)&stack_ptr) {	//当前的栈指针地址
			printf("FDT %p gd %p\n", fdt_blob, gd);
			panic("FDT overlap");
		}
	}
	return fdt_blob;
}
```

## fdtdec_prepare_fdt 检查是否有可用于控制 U-Boot 的有效 fdt

```c
static int fdtdec_prepare_fdt(const void *blob)
{
	if (!blob //空指针
	|| ((uintptr_t)blob & 3) 		//地址对齐
	|| fdt_check_header(blob)) {	//检查fdt头部是否正确
		if (xpl_phase() <= PHASE_SPL) {
			puts("Missing DTB\n");
		} else {
			printf("No valid device tree binary found at %p\n",
			       blob);
			if (_DEBUG && blob) {
				printf("fdt_blob=%p\n", blob);
				print_buffer((ulong)blob, blob, 4, 32, 0);
			}
		}
		return -ENOENT;
	}

	return 0;
}
```

## fdt_check_header 检查fdt头部是否正确

![image-20250116131433785](./assets/image-20250116131433785.png)

## fdtdec_setup_mem_size_base
- 从设备树中读取`memory`节点,并设置`gd->ram_size`和`gd->ram_base`
```c
gd->ram_size = (phys_size_t)(res.end - res.start + 1);
gd->ram_base = (unsigned long)res.start;

memory@c0000000 {
	device_type = "memory";
	reg = <0xc0000000 0x2000000>;
};
```

## scripts/dtc/libfdt/libfdt_internal.h

### FDT_ASSUME_MASK

- 定义了FDT_ASSUME_MASK,用于判断是否进行额外的检查;每个位代表一个检查

```c
/*
 * 定义可以启用的假设。每个假设都可以单独启用。为了最大限度的安全性，不要启用任何假设！
 *
 * 为了最小化代码大小和不安全性，可以自行承担风险使用 FDT_ASSUME_PERFECT。
 * 在使用 libfdt 之前，你应该有其他方法来验证设备树，例如签名或哈希检查。
 *
 * 在安全性不是问题的情况下，可以安全地启用 FDT_ASSUME_FRIENDLY。
 */
enum {
    /*
     * 这实际上不进行任何检查。仅正确处理最新版本的设备树。
     * 设备树中的不一致或错误可能会导致未定义的行为或崩溃。
     *
     * 如果在修改设备树时发生错误，可能会使设备树处于中间（但有效）的状态。
     * 例如，在没有足够空间的情况下添加属性，可能会导致属性名称被添加到字符串表中，
     * 即使属性本身没有被添加到结构部分。
     *
     * 仅在你拥有完全验证的设备树并且支持最新版本时使用此选项，以最小化代码大小。
     */
    FDT_ASSUME_PERFECT = 0xff,

    /*
     * 这假设设备树是合理的。即头部元数据和基本层次结构是正确的。
     *
     * 如果你有一个有效的设备树且没有内部不一致，这些检查将是足够的。
     * 在这种假设下，libfdt 通常不会返回 -FDT_ERR_INTERNAL、-FDT_ERR_BADLAYOUT 等错误。
     */
    FDT_ASSUME_SANE = 1 << 0,

    /*
     * 这禁用了设备树版本的检查，并移除了处理旧版本的所有代码。
     *
     * 仅在你知道你拥有最新版本的设备树时启用此选项。
     */
    FDT_ASSUME_LATEST = 1 << 1,

    /*
     * 这禁用了对参数和设备树的广泛检查，做出各种正确性的假设。
     * 由 libfdt 和编译器生成的正常设备树应该可以安全处理。
     * 恶意设备树和完全垃圾数据可能会导致 libfdt 行为不正常或崩溃。
     */
    FDT_ASSUME_FRIENDLY = 1 << 2,
};
/* fdt_chk_basic() - see if basic checking of params and DT data is enabled */
static inline bool fdt_chk_basic(void)
{
	return !(FDT_ASSUME_MASK & FDT_ASSUME_SANE);
}

/* fdt_chk_version() - see if we need to handle old versions of the DT */
static inline bool fdt_chk_version(void)
{
	return !(FDT_ASSUME_MASK & FDT_ASSUME_LATEST);
}

/* fdt_chk_extra() - see if extra checking is enabled */
static inline bool fdt_chk_extra(void)
{
	return !(FDT_ASSUME_MASK & FDT_ASSUME_FRIENDLY);
}
```

# dm 设备管理 暂不分析***
## initf_dm
```c
static int initf_dm(void)
{
	int ret;

	if (!CONFIG_IS_ENABLED(SYS_MALLOC_F))
		return 0;

	ret = dm_init_and_scan(true);
	if (ret)
		return ret;

	ret = dm_autoprobe();
	if (ret)
		return ret;

	if (IS_ENABLED(CONFIG_TIMER_EARLY)) {
		ret = dm_timer_init();
		if (ret)
			return ret;
	}

	return 0;
}
```

## drivers/core/root.c
### dm_init_and_scan
```c
/**
 * dm_init_and_scan（） - 初始化驱动程序模型结构并扫描设备
 *
 * 此函数初始化驱动程序树和 uclass 树的根，
 * 然后扫描并绑定来自平台数据和 FDT 的可用设备。
 * 这将调用 dm_init（） 来设置驱动程序模型结构。
 *
 * @pre_reloc_only： 如果为 true，则仅绑定具有特殊 devicetree 属性的节点，
 * 或带有 DM_FLAG_PRE_RELOC 标志的驱动程序。如果为 false，则绑定所有驱动程序。
 * 返回：OK 时为 0，出错时为 -ve
 */
```
### dm_init
```c
/**
 * dm_init（） - 初始化驱动模型结构
 *
 * 此函数将初始化驱动程序树和类树的根。
 * 这需要在使用 DM 之前调用
 *
 * @of_live：启用 Live 设备树
 * 返回：OK 时为 0，出错时为 -ve
 */
int dm_init(bool of_live)
{
	int ret;

	if (CONFIG_IS_ENABLED(OF_PLATDATA_INST)) {
		gd->uclass_root = &uclass_head;
	} else {
		//初始化uclass根
		gd->uclass_root = &DM_UCLASS_ROOT_S_NON_CONST;
		INIT_LIST_HEAD(DM_UCLASS_ROOT_NON_CONST);
	}

	if (CONFIG_IS_ENABLED(OF_PLATDATA_INST)) {
		ret = dm_setup_inst();
		if (ret) {
			log_debug("dm_setup_inst() failed: %d\n", ret);
			return ret;
		}
	} else {
		//绑定root_info,并将指向绑定设备的指针返回到DM_ROOT_NON_CONST
		ret = device_bind_by_name(NULL, false, &root_info,
					  &DM_ROOT_NON_CONST);
		if (ret)
			return ret;
		if (CONFIG_IS_ENABLED(OF_CONTROL))
			dev_set_ofnode(DM_ROOT_NON_CONST, ofnode_root());
		ret = device_probe(DM_ROOT_NON_CONST);
		if (ret)
			return ret;
	}
}
```

## drivers/core/device.c
```c
/**
 * struct driver - 功能或外围设备的驱动程序
 *
 * 此字段包含设置新设备和删除新设备的方法。
 * 设备需要信息来设置自身 - 这提供了
 * 按 Plat 或 Device Tree 节点（我们通过查找找到
 * 将兼容的字符串与 of_match） 匹配。
 *
 * 驱动程序都属于一个 uclass，代表
 * 相同类型。驱动程序的公共元素可以在 uclass 中实现，
 * 或 uclass 可以为
 *它。
 *
 * @name：设备名称
 * @id：标识我们所属的 uclass
 * @of_match：要匹配的兼容字符串列表以及任何标识数据
 * 对于每个。
 * @bind：调用以将设备绑定到其驱动程序
 * @probe：调用以探测设备，即激活它
 * @remove：调用以删除设备，即停用设备
 * @unbind：调用以取消设备与其驱动程序的绑定
 * @of_to_plat：在 probe 之前调用以解码设备树数据
 * @child_post_bind：在绑定新子项后调用
 * @child_pre_probe：在探测子设备之前调用。该设备具有
 * 内存已分配，但尚未探测。
 * @child_post_remove：删除子设备后调用。设备
 * 已分配内存，但其 device_remove（） 方法已被调用。
 * @priv_auto：如果非零，则为私有数据的大小
 * 在设备的 ->priv 指针中分配。如果为零，则驱动程序
 * 负责分配所需的任何数据。
 * @plat_auto：如果非零，则为
 * 在设备的 ->plat 指针中分配的平台数据。
 * 这通常仅对设备树感知驱动程序（具有
 * of_match），因为使用 Plat 的驱动程序将拥有数据
 * 在 U_BOOT_DRVINFO（） 实例中提供。
 * @per_child_auto：每台设备都可以保存
 * 其父级。如果需要，如果
 * 值为非零。
 * @per_child_plat_auto：公交车喜欢存储以下信息
 * 它的子项。如果非零，则这是要分配的此数据的大小
 * 在子指针的 parent_plat 中。
 * @ops：特定于驱动程序的操作。这通常是一个函数列表
 * 由驱动程序定义的指针，以实现所需的驱动程序功能
 * UCLASS.
 * @flags：驾驶员标志 - 请参阅“DM_FLAG_...”
 * @acpi_ops：高级配置和电源接口 （ACPI） 操作，
 * 允许设备将内容添加到传递给 Linux 的 ACPI 表中
 */
struct driver {
	char *name;
	enum uclass_id id;
	const struct udevice_id *of_match;
	int (*bind)(struct udevice *dev);
	int (*probe)(struct udevice *dev);
	int (*remove)(struct udevice *dev);
	int (*unbind)(struct udevice *dev);
	int (*of_to_plat)(struct udevice *dev);
	int (*child_post_bind)(struct udevice *dev);
	int (*child_pre_probe)(struct udevice *dev);
	int (*child_post_remove)(struct udevice *dev);
	int priv_auto;
	int plat_auto;
	int per_child_auto;
	int per_child_plat_auto;
	const void *ops;	/* driver-specific operations */
	uint32_t flags;
#if CONFIG_IS_ENABLED(ACPIGEN)
	struct acpi_ops *acpi_ops;
#endif
};
```

### device_bind_by_name
```c
/**
 * device_bind_by_name：创建设备并将其绑定到驱动程序
 *
 * 这是一个辅助函数，用于绑定不使用设备的设备
 *树。
 *
 * @parent：指向设备父级的指针
 * @pre_reloc_only：如果为 true，则仅在驱动程序的 DM_FLAG_PRE_RELOC 标志时绑定驱动程序
 * 已设置。如果为 false，则始终绑定驱动程序。
 * @info：此设备的名称和平台
 * @devp：如果为非 NULL，则返回指向绑定设备的指针
 * 返回：OK 时为 0，出错时为 -ve
 */
int device_bind_by_name(struct udevice *parent, bool pre_reloc_only,
			const struct driver_info *info, struct udevice **devp)
{
	struct driver *drv;
	uint plat_size = 0;
	int ret;
	//根据名字在段里面查找驱动
	drv = lists_driver_lookup_name(info->name);
	if (!drv)
		return -ENOENT;
	if (pre_reloc_only && !(drv->flags & DM_FLAG_PRE_RELOC))
		return -EPERM;

#if CONFIG_IS_ENABLED(OF_PLATDATA)
	plat_size = info->plat_size;
#endif
	ret = device_bind_common(parent, drv, info->name, (void *)info->plat, 0,
				 ofnode_null(), plat_size, devp);
	if (ret)
		return ret;

	return ret;
}
```

### device_bind_common
```c
- 进行一系列初始化与绑定操作
static int device_bind_common(struct udevice *parent, const struct driver *drv,
			      const char *name, void *plat,
			      ulong driver_data, ofnode node,
			      uint of_plat_size, struct udevice **devp)
{
	struct udevice *dev;
	struct uclass *uc;
	int size, ret = 0;
	bool auto_seq = true;
	void *ptr;

	if (CONFIG_IS_ENABLED(OF_PLATDATA_NO_BIND))
		return -ENOSYS;

	if (devp)
		*devp = NULL;
	if (!name)
		return -EINVAL;

	ret = uclass_get(drv->id, &uc);
	if (ret) {
		dm_warn("Missing uclass for driver %s\n", drv->name);
		return ret;
	}

	dev = calloc(1, sizeof(struct udevice));
	if (!dev)
		return -ENOMEM;

	INIT_LIST_HEAD(&dev->sibling_node);
	INIT_LIST_HEAD(&dev->child_head);
	INIT_LIST_HEAD(&dev->uclass_node);
#if CONFIG_IS_ENABLED(DEVRES)
	INIT_LIST_HEAD(&dev->devres_head);
#endif
}
```

## drivers/core/uclass.c
### uclass
```c
/**
 * struct uclass - 一个 U-Boot 驱动类，收集了类似的驱动程序
 *
 * uclass 为特定函数提供接口，该函数是
 * 由一个或多个驱动程序实现。每个驱动程序都属于一个 uclass
 * 如果它是该 uclass 中的唯一驱动程序。一个例子 uclass 是 GPIO，它
 * 提供更改读取输入、设置和清除输出等功能。
 * 可能有用于片上 SoC GPIO 组、I2C GPIO 扩展器和
 * PMIC IO 线路，全部通过 uclass 以统一方式提供。
 *
 * @priv_：此 uclass 的私有数据（不访问驱动程序模型外部）
 * @uc_drv：uclass 本身的驱动程序，不要与
 * 'struct driver'
 * @dev_head：此 uclass 中的设备列表（设备连接到其
 * uclass 调用其 bind 方法时）
 * @sibling_node：uclasses 链表中的下一个 uclass
 */
struct uclass {
	void *priv_;
	struct uclass_driver *uc_drv;
	struct list_head dev_head;
	struct list_head sibling_node;
};
```

### uclass_driver
```c
/**
 * struct uclass_driver - uclass 的驱动程序
 *
 * uclass_driver为一组相关的
 *司机。
 *
 * @name：uclass 驱动程序的名称
 * @id：此 uclass 的 ID 号
 * @post_bind：在新设备绑定到此 uclass 后调用
 * @pre_unbind：在设备与此 uclass 解绑之前调用
 * @pre_probe：在探测新设备之前调用
 * @post_probe：探测新设备后调用
 * @pre_remove：在移除设备之前调用
 * @child_post_bind：在子级绑定到此 uclass 中的设备后调用
 * @child_pre_probe：在探测此 uclass 中的子对象之前调用
 * @child_post_probe：探测此 uclass 中的子对象后调用
 * @init：调用以设置 uclass
 * @destroy：调用以销毁 uclass
 * @priv_auto：如果非零，则为私有数据的大小
 * 在 uclass 的 ->priv 指针中分配。如果为零，则 uclass
 * 驱动程序负责分配所需的任何数据。
 * @per_device_auto：每台设备都可以保存拥有的私有数据
 * 由 uclass.如果需要，如果
 * 值为非零。
 * @per_device_plat_auto：每个设备都可以保存平台数据
 * 由 uclass 拥有，为 'dev->uclass_plat'。如果该值为非零，则
 * 则此 ID 将自动分配。
 * @per_child_auto：每个子设备（此
 * uclass） 可以保存 device/uclass 的父数据。此值仅为
 * 如果此成员在驱动程序中为 0，则用作回退。
 * @per_child_plat_auto：公交车喜欢存储以下信息
 * 它的子项。如果非零，则这是要分配的此数据的大小
 * 在子设备的 parent_plat 指针中。此值仅用作
 * 如果此成员在驱动程序中为 0，则为回退。
 * @flags： 此 uclass 的标志 ''（DM_UC_...）``
 */
struct uclass_driver {
	const char *name;
	enum uclass_id id;
	int (*post_bind)(struct udevice *dev);
	int (*pre_unbind)(struct udevice *dev);
	int (*pre_probe)(struct udevice *dev);
	int (*post_probe)(struct udevice *dev);
	int (*pre_remove)(struct udevice *dev);
	int (*child_post_bind)(struct udevice *dev);
	int (*child_pre_probe)(struct udevice *dev);
	int (*child_post_probe)(struct udevice *dev);
	int (*init)(struct uclass *class);
	int (*destroy)(struct uclass *class);
	int priv_auto;
	int per_device_auto;
	int per_device_plat_auto;
	int per_child_auto;
	int per_child_plat_auto;
	uint32_t flags;
};
```

### uclass_get
```c
int uclass_get(enum uclass_id id, struct uclass **ucp)
{
	struct uclass *uc;

	/* Immediately fail if driver model is not set up */
	if (!gd->uclass_root)
		return -EDEADLK;
	*ucp = NULL;
	uc = uclass_find(id);	//遍历段中的uc->uc_drv->id
	if (!uc) {
		if (CONFIG_IS_ENABLED(OF_PLATDATA_INST))
			return -ENOENT;
		return uclass_add(id, ucp);	//没有找到则添加
	}
	*ucp = uc;

	return 0;
}
```

### uclass_add

```c
static int uclass_add(enum uclass_id id, struct uclass **ucp)
{
	struct uclass_driver *uc_drv;
	struct uclass *uc;
	int ret;

	*ucp = NULL;
	uc_drv = lists_uclass_lookup(id);	//从段中查找uc_drv
	if (!uc_drv) {
		return -EPFNOSUPPORT;
	}
	uc = calloc(1, sizeof(*uc));
	if (!uc)
		return -ENOMEM;
	if (uc_drv->priv_auto) {	//驱动分配私有数据
		void *ptr;

		ptr = calloc(1, uc_drv->priv_auto);
		if (!ptr) {
			ret = -ENOMEM;
			goto fail_mem;
		}
		uclass_set_priv(uc, ptr);
	}
	uc->uc_drv = uc_drv;
	INIT_LIST_HEAD(&uc->sibling_node);
	INIT_LIST_HEAD(&uc->dev_head);
	list_add(&uc->sibling_node, DM_UCLASS_ROOT_NON_CONST);

	if (uc_drv->init) {	//驱动程序初始化
		ret = uc_drv->init(uc);
		if (ret)
			goto fail;
	}

	*ucp = uc;

	return 0;
fail:
	if (uc_drv->priv_auto) {
		free(uclass_get_priv(uc));
		uclass_set_priv(uc, NULL);
	}
	list_del(&uc->sibling_node);
fail_mem:
	free(uc);

	return ret;
}
```

# lib
## lib/initcall.c

### initcall_run_list 初始化调用列表

```c
int initcall_run_list(const init_fnc_t init_sequence[])
{
	ulong reloc_ofs;
	const init_fnc_t *ptr;
	enum event_t type;
	init_fnc_t func;
	int ret = 0;

	for (ptr = init_sequence; func = *ptr, func; ptr++) {
		reloc_ofs = calc_reloc_ofs();	//计算偏移
		type = initcall_is_event(func);	//判断是否是事件
		//执行函数 是事件执行事件通知函数,否则执行函数
		ret = type ? event_notify_null(type) : func();
		if (ret)
			break;
	}

	if (ret) {
		if (CONFIG_IS_ENABLED(EVENT)) {
			char buf[60];

			/* don't worry about buf size as we are dying here */
			if (type) {
				sprintf(buf, "event %d/%s", type,
					event_type_name(type));
			} else {
				sprintf(buf, "call %p",
					(char *)func - reloc_ofs);
			}

			printf("initcall failed at %s (err=%dE)\n", buf, ret);
		} else {
			printf("initcall failed at call %p (err=%d)\n",
			       (char *)func - reloc_ofs, ret);
		}

		return ret;
	}

	return 0;
}
```

### 事件声明

- 从.map中搜索 ` __u_boot_list_2_evspy_info`从 `_1`到 `_3`的段,并执行 `notify_static`函数

#### boot/vbe_request.c

#### boot/vbe_simple_os.c

### initcall_is_event 判断是否是事件

```c
#define INITCALL_IS_EVENT	GENMASK(BITS_PER_LONG - 1, 8)	//生成掩码从8到31都是1
#define INITCALL_EVENT_TYPE	GENMASK(7, 0)	//生成掩码从0到7都是1
//是事件返回事件类型,否则返回0
static int initcall_is_event(init_fnc_t func)
{
	ulong val = (ulong)func;

	if ((val & INITCALL_IS_EVENT) == INITCALL_IS_EVENT)
		return val & INITCALL_EVENT_TYPE;

	return 0;
}
```

## lib/vsprintf.c

- vsnprintf_internal函数,用于格式化字符串
- 该文件内部自行实现了printf函数,并进行了对于u-boot的适配

### vprintf

- 需要配置CONFIG_PRINTF 和 CONFIG_SYS_PBSIZE

```c
#if CONFIG_IS_ENABLED(PRINTF)
int vprintf(const char *fmt, va_list args)
{
	uint i;
	char printbuffer[CONFIG_SYS_PBSIZE];

	/*
	 * For this to work, printbuffer must be larger than
	 * anything we ever want to print.
	 */
	i = vscnprintf(printbuffer, sizeof(printbuffer), fmt, args);

	/* Handle error */
	if (i <= 0)
		return i;
	/* Print the string */
	puts(printbuffer);
	return i;
}
#endif
```

## lib/hang.c

```c
void hang(void)
{
#if !defined(CONFIG_XPL_BUILD) || \
		(CONFIG_IS_ENABLED(LIBCOMMON_SUPPORT) && \
		 CONFIG_IS_ENABLED(SERIAL))
	puts("### ERROR ### Please RESET the board ###\n");
#endif
	bootstage_error(BOOTSTAGE_ID_NEED_RESET);	//记录错误
	if (IS_ENABLED(CONFIG_SANDBOX))
		os_exit(1);
	for (;;)	//死循环
		;
}
```

## lib/trace.c
```c
int notrace trace_early_init(void)
{
	int func_count = get_func_count();
	size_t buff_size = CONFIG_TRACE_EARLY_SIZE;
	size_t needed;

	if (func_count < 0)
		return func_count;
	/* We can ignore additional calls to this function */
	if (trace_enabled)
		return 0;

	hdr = map_sysmem(CONFIG_TRACE_EARLY_ADDR, CONFIG_TRACE_EARLY_SIZE);
	needed = sizeof(*hdr) + func_count * sizeof(uintptr_t);
	if (needed > buff_size) {
		printf("trace: buffer size is %zx bytes, at least %zx needed\n",
		       buff_size, needed);
		return -ENOSPC;
	}

	memset(hdr, '\0', needed);
	hdr->call_accum = (uintptr_t *)(hdr + 1);
	hdr->func_count = func_count;
	hdr->min_depth = INT_MAX;

	/* Use any remaining space for the timed function trace */
	hdr->ftrace = (struct trace_call *)((char *)hdr + needed);
	hdr->ftrace_size = (buff_size - needed) / sizeof(*hdr->ftrace);
	hdr->depth_limit = CONFIG_TRACE_EARLY_CALL_DEPTH_LIMIT;
	printf("trace: early enable at %08x\n", CONFIG_TRACE_EARLY_ADDR);

	trace_enabled = 1;

	return 0;
}
```

# common

## common/event.c

- [event](https://docs.u-boot.org/en/latest/api/event.html)

### 声明事件类型

```c
//复杂事件声明
#define EVENT_SPY_FULL(_type, _func) \
	__used ll_entry_declare(struct evspy_info, _type ## _3_ ## _func, \
		evspy_info) = _ESPY_REC(_type, _func)

//简单事件声明
#define EVENT_SPY_SIMPLE(_type, _func) \
	__used ll_entry_declare(struct evspy_info_simple, \
		_type ## _3_ ## _func, \
		evspy_info) = _ESPY_REC_SIMPLE(_type, _func)
```

### notify_static 以静态方式通知事件

```c
static int notify_static(struct event *ev)
{
	struct evspy_info *start = ll_entry_start(struct evspy_info, evspy_info);	//定义开始的段的位置
	const int n_ents = ll_entry_count(struct evspy_info, evspy_info);			//获取段的数量
	struct evspy_info *spy;
	//匹配则执行
	for (spy = start; spy != start + n_ents; spy++) {
		if (spy->type == ev->type) {
			int ret;

			log_debug("Sending event %x/%s to spy '%s'\n", ev->type,
				  event_type_name(ev->type), event_spy_id(spy));
			if (spy->flags & EVSPYF_SIMPLE) {
				const struct evspy_info_simple *simple;

				simple = (struct evspy_info_simple *)spy;
				ret = simple->func();
			} else {
				ret = spy->func(NULL, ev);
			}

			/*
			 * TODO: Handle various return codes to
			 *
			 * - claim an event (no others will see it)
			 * - return an error from the event
			 */
			if (ret)
				return log_msg_ret("spy", ret);
		}
	}

	return 0;
}
```

### notify_dynamic 以动态方式通知事件

- 需要配置EVENT_DYNAMIC
- 进行初始化与注册和释放

## common/console.c

### puts 输出字符串 暂不分析***

## common/log.c 暂不分析***

## common/dlmalloc.c
dlmalloc 是 Doug Lea 实现的一种动态内存分配器，广泛用于嵌入式系统和操作系统中。它以其高效和灵活的内存管理机制而著称。以下是 dlmalloc 的工作原理和关键概念：

1. 内存池（Memory Pool）
dlmalloc 使用一个或多个内存池来管理内存。内存池是由操作系统分配的一大块连续内存区域，dlmalloc 在这个区域内进行内存分配和释放操作。

2. 空闲块和已分配块（Free and Allocated Blocks）
内存池被分割成多个块，每个块可以是空闲的或已分配的。每个块都有一个头部（header），包含块的大小和状态（空闲或已分配）。

3. 双向链表（Doubly Linked List）
空闲块通过双向链表链接在一起。每个空闲块的头部包含指向前一个和后一个空闲块的指针。这使得 dlmalloc 可以高效地插入和删除空闲块。

4. 分割和合并（Splitting and Coalescing）
分割：当请求的内存大小小于某个空闲块的大小时，dlmalloc 会将这个空闲块分割成两个块，一个满足请求大小，另一个继续作为空闲块。
合并：当释放一个块时，dlmalloc 会检查相邻的块是否也是空闲的。如果是，它们会被合并成一个更大的空闲块。这减少了内存碎片，提高了内存利用率。
5. 最佳适配（Best Fit）和首次适配（First Fit）
dlmalloc 使用最佳适配或首次适配策略来找到合适的空闲块：

最佳适配：在所有空闲块中找到最小的、但足够大的块来满足请求。这减少了内存碎片，但可能需要更多的时间来搜索。
首次适配：从头开始搜索，找到第一个足够大的块。这速度较快，但可能会增加内存碎片。
6. 扩展和收缩（Expansion and Contraction）
当内存池中的空闲块不足以满足请求时，dlmalloc 可以向操作系统请求更多的内存（扩展）。当内存使用减少时，它也可以将未使用的内存归还给操作系统（收缩）。

7. 内存对齐（Memory Alignment）
dlmalloc 确保分配的内存块是对齐的，以满足特定硬件或数据结构的要求。这通常通过调整块的起始地址来实现。

### mem_malloc_init
```c
ulong mem_malloc_start = 0;
ulong mem_malloc_end = 0;
ulong mem_malloc_brk = 0;

void mem_malloc_init(ulong start, ulong size)
{
	mem_malloc_start = (ulong)map_sysmem(start, size);
	mem_malloc_end = mem_malloc_start + size;
	mem_malloc_brk = mem_malloc_start;

#ifdef CONFIG_SYS_MALLOC_DEFAULT_TO_INIT
	malloc_init();
#endif

	debug("using memory %#lx-%#lx for malloc()\n", mem_malloc_start,
	      mem_malloc_end);
#if CONFIG_IS_ENABLED(SYS_MALLOC_CLEAR_ON_INIT)
	memset((void *)mem_malloc_start, 0x0, size);
#endif
}
```

## common/exports.c
### jumptable_init
- malloc分配jt_funcs结构体,并将函数指针赋值给jt_funcs结构体
- jt_funcs结构体中的函数指针是在_exports.h中定义的
- 这些函数在u-boot中是代码段中的函数,在u-boot中是通过函数指针调用的
- jt跳转表包含指向导出函数的指针。指向跳转表将传递给独立应用程序。
```c
EXPORT_FUNC(get_version, unsigned long, get_version, void)
EXPORT_FUNC(getchar, int, getc, void)
EXPORT_FUNC(tstc, int, tstc, void)
EXPORT_FUNC(putc, void, putc, const char)
EXPORT_FUNC(puts, void, puts, const char *)

struct jt_funcs {
#define EXPORT_FUNC(impl, res, func, ...) res(*func)(__VA_ARGS__);
#include <_exports.h>
#undef EXPORT_FUNC
};

#define EXPORT_FUNC(f, a, x, ...)  gd->jt->x = f;

int jumptable_init(void)
{
	gd->jt = malloc(sizeof(struct jt_funcs));
#include <_exports.h>

	return 0;
}
```



## common/cli.c
### cli_init
- u_boot_hush_start();

# include

## arch/arm/include/asm

### asm/assembler.h

- 定义了一些宏,用ret开头,用于返回

```asm
/*
* Use 'bx lr' everywhere except ARMv4 (without 'T') where only 'mov pc, lr'
* works
*/
    .irp	c,,eq,ne,cs,cc,mi,pl,vs,vc,hi,ls,ge,lt,gt,le,hs,lo
    .macro	ret\c, reg

    /* ARMv4- don't know bx lr but the assembler fails to see that */
#ifdef __ARM_ARCH_4__
    mov\c	pc, \reg
#else
    .ifeqs	"\reg", "lr"
    bx\c	\reg
    .else
    mov\c	pc, \reg
    .endif
#endif
    .endm
    .endr
```

- .irp .endr 会展开生成循环中的代码,展开后如下:

```asm
.macro	ret, reg
#ifdef __ARM_ARCH_4__
    mov	pc, \reg
#else
    .ifeqs	"\reg", "lr"
    bx	\reg
    .else
    mov	pc, \reg
    .endif
#endif
.endm

.macro	ret_eq, reg
#ifdef __ARM_ARCH_4__
    moveq	pc, \reg
#else
    .ifeqs	"\reg", "lr"
    bxeq	\reg
    .else
    moveq	pc, \reg
    .endif
#endif
.endm
// 等等不列举
```

### asm/unified.h

- W(instr) 的定义展开为 `instr.w`

```asm
#ifdef CONFIG_THUMB2_KERNEL //在include/generated/autoconf.h中定义
#ifdef __ASSEMBLY__         //在makefile脚本中定义
#define W(instr)	instr.w
#else
#define WASM(instr)	#instr ".w"
#endif
```

## include/system-constants.h 定义系统堆栈指针地址

- 定义了系统初始化的堆栈指针地址
- 其配置在include/generated/autoconf.h,由include/config.h->include/linux/kconfig.h->include/generated/autoconf.h
- include/generated/autoconf.h为自动生成的文件,包含了系统的配置信息,原始配置在configs/stm32h750-art-pi_defconfig

```c
/*
 * The most common case for our initial stack pointer address is to
 * say that we have defined a static intiial ram address location and
 * size and from that we subtract the generated global data size.
 */
#ifdef CONFIG_HAS_CUSTOM_SYS_INIT_SP_ADDR
#define SYS_INIT_SP_ADDR	CONFIG_CUSTOM_SYS_INIT_SP_ADDR
#endif
```

## include/linker_lists.h

- [linker_lists api手册](https://docs.u-boot.org/en/stable/api/linker_lists.html)

```c
// 声明一个链接生成的条目,以__u_boot_list_2_XXX_2_YYY命名
#define ll_entry_declare(_type, _name, _list)				\
	_type _u_boot_list_2_##_list##_2_##_name __aligned(4)		\
			__attribute__((unused))				\
			__section("__u_boot_list_2_"#_list"_2_"#_name)

// 声明一个链接生成的列表,以__u_boot_list_2_XXX_2_YYY命名,但是是一个数组
#define ll_entry_declare_list(_type, _name, _list)			\
	_type _u_boot_list_2_##_list##_2_##_name[] __aligned(4)		\
			__attribute__((unused))				\
			__section("__u_boot_list_2_"#_list"_2_"#_name) 
// 声明一个段的开头,以__u_boot_list_2_XXX_1命名
#define ll_entry_start(_type, _list)					\
({									\
	static char start[0] __aligned(CONFIG_LINKER_LIST_ALIGN)	\
		__attribute__((unused))					\
		__section("__u_boot_list_2_"#_list"_1");			\
	_type * tmp = (_type *)&start;					\
	asm("":"+r"(tmp));						\
	tmp;								\
})
// 声明一个段的结尾,以__u_boot_list_2_XXX_3命名
#define ll_entry_end(_type, _list)					\
({									\
	static char end[0] __aligned(4) __attribute__((unused))		\
		__section("__u_boot_list_2_"#_list"_3");			\
	_type * tmp = (_type *)&end;					\
	asm("":"+r"(tmp));						\
	tmp;								\
})
// 计算段的数量
#define ll_entry_count(_type, _list)					\
	({								\
		_type *start = ll_entry_start(_type, _list);		\
		_type *end = ll_entry_end(_type, _list);		\
		unsigned int _ll_result = end - start;			\
		_ll_result;						\
	})
```

## include/linux/kconfig.h

### __count_args 计算可变参数宏的参数数

```c
/*
 * 计算可变参数宏的参数数。目前只需要
 * 它用于 1、2 或 3 个参数。
 */
#define __arg6(a1, a2, a3, a4, a5, a6, ...) a6
#define __count_args(...) __arg6(dummy, ##__VA_ARGS__, 4, 3, 2, 1, 0)
```

- 传递一个虚拟参数 `dummy`和参数传入,并返回第6个参数;
- 例如传入 `__count_args(a, b, c)`,则展开为 `__arg6(dummy, a, b, c, 4, 3, 2, 1, 0)`,则返回3
- `dummy` 是一个虚拟参数，用于确保宏展开时参数列表的长度一致。在 __count_args 宏中，dummy 被用作第一个参数，以确保即使没有传递任何参数，参数列表的长度也至少为 1。
- `##__VA_ARGS__` 是一个预处理器技巧，用于处理可变参数宏。__VA_ARGS__ 是一个特殊的宏参数，表示传递给宏的所有可变参数。## 是预处理器的连接运算符，用于将两个标识符连接在一起。

### CONFIG_VAL 拼接配置前缀与配置名

- 根据输入的配置名，返回对应的配置值。
- 配置了 `USE_HOSTCC`,则返回 `CONFIG_TOOLS_xxx`
- 配置了 `CONFIG_XPL_BUILD`,则返回 `CONFIG_xxx`
- 配置了 `CONFIG_SPL_BUILD`,则返回 `CONFIG_SPL_xxx`
- 配置了 `CONFIG_TPL_BUILD`,则返回 `CONFIG_TPL_xxx`
- 配置了 `CONFIG_VPL_BUILD`,则返回 `CONFIG_VPL_xxx`

```c
/*
 * U-Boot 附加组件：用于引用不同宏的辅助宏（前缀为
 * CONFIG_、CONFIG_SPL_、CONFIG_TPL_ 或 CONFIG_TOOLS_），具体取决于版本
 *上下文。
 */

#ifdef USE_HOSTCC
#define _CONFIG_PREFIX TOOLS_
#elif defined(CONFIG_TPL_BUILD)
#define _CONFIG_PREFIX TPL_
#elif defined(CONFIG_VPL_BUILD)
#define _CONFIG_PREFIX VPL_
#elif defined(CONFIG_SPL_BUILD)
#define _CONFIG_PREFIX SPL_
#else
#define _CONFIG_PREFIX
#endif

#define   config_val(cfg)       _config_val(_CONFIG_PREFIX, cfg)
#define  _config_val(pfx, cfg) __config_val(pfx, cfg)
#define __config_val(pfx, cfg) CONFIG_ ## pfx ## cfg

/*
 * CONFIG_VAL(FOO) evaluates to the value of
 *  CONFIG_TOOLS_FOO if USE_HOSTCC is defined,
 *  CONFIG_FOO if CONFIG_XPL_BUILD is undefined,
 *  CONFIG_SPL_FOO if CONFIG_SPL_BUILD is defined.
 *  CONFIG_TPL_FOO if CONFIG_TPL_BUILD is defined.
 *  CONFIG_VPL_FOO if CONFIG_VPL_BUILD is defined.
 */
#define CONFIG_VAL(option)  config_val(option)
```

### config_enabled 判断配置是否启用 返回1或0

- 如果我们有 `#define CONFIG_BOOGER 1`,且传入 `config_enabled(BOOGER, 0)`
- `__ARG_PLACEHOLDER_##value`展开为 `__ARG_PLACEHOLDER_1`,即 `0,`
- 所以如果配置为1,传入为 `(0, 1, 0)`;如果配置为0,传入为 `(... 1, 0)`
- 则最后1返回的是第二个参数,所以如果配置为1,返回1;  如果配置为0,返回0,因为第一个参数被忽略

```c
/*
 * 在 C/CPP 表达式中使用 CONFIG_ 选项的辅助宏。请注意，
 * 这些仅适用于 布尔 和 三态 选项。
 */
#define __ARG_PLACEHOLDER_1 0,
#define config_enabled(cfg, def_val) _config_enabled(cfg, def_val)
#define _config_enabled(value, def_val) __config_enabled(__ARG_PLACEHOLDER_##value, def_val)
#define __config_enabled(arg1_or_junk, def_val) ___config_enabled(arg1_or_junk 1, def_val)
#define ___config_enabled(__ignored, val, ...) val
```

### CONFIG_IS_ENABLED 判断配置是否启用并返回TRUE或FALSE

- 传入 `CONFIG_IS_ENABLED(FOO)`,则 `__count_args`计算为1,则展开为 `__CONFIG_IS_ENABLED_1(FOO)`
- `__CONFIG_IS_ENABLED_1(FOO)`展开为 `__CONFIG_IS_ENABLED_3(FOO, (1), (0))`
- `CONFIG_VAL`根据配置,是否拼接前缀,返回对应的配置值
- `config_enabled`根据配置值,返回是否启用,即1或0
- `__concat`拼接 `__unwrap`和 `config_enabled`返回的值,即 `__unwrap1`或 `__unwrap0`
- `__unwrap1`或 `__unwrap0`展开为 `__unwrap 1`或 `__unwrap 0`
- `__unwrap 1`或 `__unwrap 0`展开为 `1`或 `0`
- 所以如果配置为1,返回1;  如果配置为0,返回0

```c
#define __unwrap(...) __VA_ARGS__
#define __unwrap1(case1, case0) __unwrap case1
#define __unwrap0(case1, case0) __unwrap case0

#define __CONFIG_IS_ENABLED_1(option)        __CONFIG_IS_ENABLED_3(option, (1), (0))
#define __CONFIG_IS_ENABLED_2(option, case1) __CONFIG_IS_ENABLED_3(option, case1, ())
#define __CONFIG_IS_ENABLED_3(option, case1, case0) \
	__concat(__unwrap, config_enabled(CONFIG_VAL(option), 0)) (case1, case0)

#define CONFIG_IS_ENABLED(option, ...)					\
	__concat(__CONFIG_IS_ENABLED_, __count_args(option, ##__VA_ARGS__)) (option, ##__VA_ARGS__)
```

## include/bootstage.h

- show_boot_progress:	显示启动进度

```c
// 如果是主机编译,或者没有启用显示启动进度,则不执行
// 否则执行show_boot_progress程序
#if defined(USE_HOSTCC) || !CONFIG_IS_ENABLED(SHOW_BOOT_PROGRESS)
#define show_boot_progress(val) do {} while (0)
#endif

static inline ulong bootstage_error(enum bootstage_id id)
{
	show_boot_progress(-id);
	return 0;
}
```

# arch/arm
## mach-stm32
### arch/arm/mach-stm32/soc.c
- 配置MPU区域
```c
int arch_cpu_init(void)
{
	int i;

	struct mpu_region_config stm32_region_config[] = {
#if defined(CONFIG_STM32F4)
		{ 0x00000000, REGION_0, 
		XN_DIS, 					//启用执行保护
		PRIV_RW_USR_RW,				//特权读写,用户读写
		O_I_WB_RD_WR_ALLOC, 		//外部内部写缓存+读写分配缓存
		REGION_512MB },
#endif
		{ 0x90000000, REGION_1, 
		XN_DIS, 					//启用执行保护
		PRIV_RW_USR_RW,				//特权读写,用户读写
		SHARED_WRITE_BUFFERED, 		//多个处理器共享的内存映射外设
		REGION_256MB },

#if defined(CONFIG_STM32F7) || defined(CONFIG_STM32H7)
		{ 0xC0000000, REGION_0, 
		XN_DIS, 					//启用执行保护
		PRIV_RW_USR_RW,				//特权读写,用户读写
		O_I_WB_RD_WR_ALLOC,			//外部内部写缓存+读写分配缓存
		REGION_512MB },	
#endif
	};

	disable_mpu();
	for (i = 0; i < ARRAY_SIZE(stm32_region_config); i++)
		mpu_config(&stm32_region_config[i]);
	enable_mpu();

	return 0;
}
```

##  armv7m
- 参考[PM0253 Cortex®-M7 编程手册 P221](../学习芯片/ART-PI/PM0253%20Cortex®-M7%20编程手册.pdf)

### arch/arm/cpu/armv7m/mpu.c
```c
#define V7M_MPU_CTRL_ENABLE		BIT(0)			//使能MPU
#define V7M_MPU_CTRL_DISABLE		(0 << 0)
#define V7M_MPU_CTRL_HFNMIENA		BIT(1)		//在硬故障、NMI 和 FAULTMASK 处理程序期间启用 MPU 的操作。 
#define V7M_MPU_CTRL_PRIVDEFENA		BIT(2)		//允许特权软件访问默认内存映射

#define VALID_REGION			BIT(4)	//1：处理器：将 MPU_RNR 的值更新为 REGION 字段的值更新 REGION 字段中指定的区域的基地址。 始终读为零。

void disable_mpu(void)
{
	writel(0, &V7M_MPU->ctrl);
}

void enable_mpu(void)
{
	writel(V7M_MPU_CTRL_ENABLE | V7M_MPU_CTRL_PRIVDEFENA, &V7M_MPU->ctrl);

	/* Make sure new mpu config is effective for next memory access */
	dsb();
	isb();	/* Make sure instruction stream sees it */
}

void mpu_config(struct mpu_region_config *reg_config)
{
	uint32_t attr;

	attr = get_attr_encoding(reg_config->mr_attr);
	//写入配置的区域以及区域保护的内存开始地址
	writel(reg_config->start_addr | VALID_REGION | reg_config->region_no,
	       &V7M_MPU->rbar);
	//写入配置的区域大小以及区域保护的内存属性
	writel(reg_config->xn << XN_SHIFT | reg_config->ap << AP_SHIFT | attr
		| reg_config->reg_size << REGION_SIZE_SHIFT | ENABLE_REGION
	       , &V7M_MPU->rasr);
}
```

### arch/arm/include/asm/armv7_mpu.h
- 内存保护单元 (MPU) 将内存映射划分为多个区域，并定义每个区域的位置、大小、访问权限和内存属性。它支持：
	- 每个区域都有独立的属性设置。 
	- 区域重叠。 
	- 将内存属性导出到系统。
- 内存属性会影响对区域的内存访问行为。
	- Cortex®M7 MPU 定义：
	- 8 个或 16 个单独的内存区域，0-7 或 0-15。
	- 背景区域
- 当内存区域重叠时，内存访问会受到编号最高的区域的属性的影响。例如，区域 7 的属性优先于与区域 7 重叠的任何区域的属性。
- Cortex®-M7 MPU 内存映射是统一的。这意味着指令访问和数据访问具有相同的区域设置。
- 如果程序访问 MPU 禁止的内存位置，处理器将生成 MemManage 故障。这会导致故障异常，并可能导致 OS 环境中的进程终止。在 OS 环境中，内核可以根据要执行的进程动态更新 MPU 区域设置。通常，嵌入式 OS 使用 MPU 进行内存保护。

- WT（Write-Through）Write-Through 是一种缓存策略，当处理器写入数据到缓存时，数据会立即写入到主存（内存）中。这种策略确保缓存和主存中的数据始终保持一致，但会导致较高的写操作延迟，因为每次写操作都需要访问主存。
- WB（Write-Back）Write-Back 是另一种缓存策略，当处理器写入数据到缓存时，数据只会写入到缓存中，而不会立即写入到主存。只有当缓存行被替换或刷新时，数据才会写入到主存。这种策略可以减少写操作的延迟，提高系统性能，但在缓存和主存之间的数据一致性管理上更加复杂。
- alloc 通常指的是缓存分配（allocation）.配置是否分配（allocation）是为了控制在特定情况下是否为数据分配新的缓存行。这对于优化系统性能和管理缓存行为非常重要。
	- 性能优化：
		- 写分配（Write Allocate）：在写操作时，如果数据不在缓存中，处理器会将数据从主存加载到缓存中，并为其分配一个新的缓存行。这种策略可以提高后续对该数据的访问性能。
		- 无写分配（No Write Allocate）：在写操作时，如果数据不在缓存中，处理器不会为其分配新的缓存行，而是直接写入主存。这种策略可以减少缓存的占用，适用于写操作较少的场景。
	- 缓存一致性：
		- 读分配（Read Allocate）：在读操作时，如果数据不在缓存中，处理器会将数据从主存加载到缓存中，并为其分配一个新的缓存行。这种策略可以提高后续对该数据的访问性能。
		- 无读分配（No Read Allocate）：在读操作时，如果数据不在缓存中，处理器不会为其分配新的缓存行，而是直接从主存读取数据。这种策略可以减少缓存的占用，适用于读操作较少的场景。
```c
//访问权限字段
enum ap {
	NO_ACCESS = 0,	//所有访问都会产生权限错误		   特权权限[无]		用户权限[无]
	PRIV_RW_USR_NO,	//仅从特权软件访问				   特权权限[读写]	用户权限[无]
	PRIV_RW_USR_RO,	//非特权软件的写入会产生权限错误	特权权限[读写]	 用户权限[只读]
	PRIV_RW_USR_RW,	//完全访问权限					 特权权限[读写]	 用户权限[读写]
	UNPREDICTABLE,	//不可预测的访问权限
	PRIV_RO_USR_NO,	//仅从特权软件访问				   特权权限[只读]	 用户权限[无]
	PRIV_RO_USR_RO,	//只读，由特权或非特权软件读取		特权权限[只读]	 用户权限[只读]
};
//属性
enum mr_attr {
	STRONG_ORDER = 0,		//对强有序内存的所有访问均按程序顺序进行。所有强有序区域均假定为共享的。
	SHARED_WRITE_BUFFERED,	//多个处理器共享的内存映射外设
	O_I_WT_NO_WR_ALLOC,		//外部和内部直写。无写入分配
	O_I_WB_NO_WR_ALLOC,		//外部和内部写缓存。无写入分配
	O_I_NON_CACHEABLE,		//外部和内部均不可缓存
	O_I_WB_RD_WR_ALLOC,		//外部和内部写缓存。写入和读取分配。
	DEVICE_NON_SHARED,		//非共享设备
};
//指令访问禁止位
enum xn {
	XN_DIS = 0,	//启用指令提取
	XN_EN,		//禁用指令提取
};
```

## arch/arm/cpu/armv7m/cache.c
在 ARM 架构中，PoU（Point of Unification）和 PoC（Point of Coherency）是两个与缓存一致性相关的重要概念。它们用于描述缓存操作的范围和影响。

1. PoU（Point of Unification）
PoU 是指统一点，表示指令和数据缓存的统一点。在这个点上，指令缓存和数据缓存的内容是一致的。通常，PoU 是指缓存层次结构中的某个级别，在这个级别上，指令和数据缓存的内容可以被视为统一的。

- 作用
	- 指令和数据缓存一致性：确保在 PoU 处，指令缓存和数据缓存的内容是一致的。
	- 缓存操作的范围：缓存操作（如清除、无效化）在 PoU 处生效，确保指令和数据缓存的一致性。
2. PoC（Point of Coherency）
PoC 是指一致性点，表示缓存和主存之间的一致性点。在这个点上，所有处理器和 DMA 设备都可以看到一致的内存视图。通常，PoC 是指缓存层次结构中的某个级别，在这个级别上，缓存和主存的内容是一致的。

- 作用
	- 缓存和主存一致性：确保在 PoC 处，缓存和主存的内容是一致的。
	- 缓存操作的范围：缓存操作（如清除、无效化）在 PoC 处生效，确保缓存和主存的一致性。

3. 使能缓存的步骤
	- 清除和无效化缓存： 在使能缓存之前，通常需要清除和无效化缓存，以确保缓存中的数据是一致的。这可以防止缓存中的旧数据影响系统的正常运行。

	- 配置缓存属性： 配置缓存的属性，如缓存策略（写回或直写）、缓存大小、缓存行大小等。这些属性决定了缓存的工作方式和性能。

	- 使能缓存： 最后，通过设置特定的控制寄存器，使能指令缓存和数据缓存。
```c
/* PoU ： 统一点， Poc： 连贯点 */
/*
 * PoU 的缓存维护操作可用于同步 Cortex®-M7 数据和指令缓存之间的数据，例如当软件使用自修改代码时。
 * PoC 的缓存维护操作可用于在 Cortex®-M7 数据缓存和外部代理（如系统 DMA）之间同步数据。
*/
enum cache_action {
	INVALIDATE_POU,			/* 指令缓存使所有到统一点 (PoU) 的指令无效*/
	INVALIDATE_POC,			/* 数据缓存通过地址到一致点（PoC）失效*/
	INVALIDATE_SET_WAY,		/* 数据缓存通过 set/way 失效 */
	FLUSH_POU,				/* 按地址将数据缓存至 PoU*/
	FLUSH_POC,				/* 通过地址清理数据缓存到PoC*/
	FLUSH_SET_WAY,			/* 按设置/方式清理数据缓存 */
	FLUSH_INVAL_POC,		/* 数据缓存清理并按地址失效至 PoC */
	FLUSH_INVAL_SET_WAY,	/* 通过 set/way 清理数据缓存并使之无效 */
};

static u32 *get_action_reg_set_ways(enum cache_action action)
{
	switch (action) {
	case INVALIDATE_SET_WAY:
		return V7M_CACHE_REG_DCISW;
	case FLUSH_SET_WAY:
		return V7M_CACHE_REG_DCCSW;
	case FLUSH_INVAL_SET_WAY:
		return V7M_CACHE_REG_DCCISW;
	default:
		break;
	};

	return NULL;
}

static u32 *get_action_reg_range(enum cache_action action)
{
	switch (action) {
	case INVALIDATE_POU:
		return V7M_CACHE_REG_ICIMVALU;
	case INVALIDATE_POC:
		return V7M_CACHE_REG_DCIMVAC;
	case FLUSH_POU:
		return V7M_CACHE_REG_DCCMVAU;
	case FLUSH_POC:
		return V7M_CACHE_REG_DCCMVAC;
	case FLUSH_INVAL_POC:
		return V7M_CACHE_REG_DCCIMVAC;
	default:
		break;
	}

	return NULL;
}

static void get_cache_ways_sets(struct dcache_config *cache)
{
	//标识当前由CSSELR选择的缓存的配置
	u32 cache_size_id = readl(V7M_PROC_REG_CCSIDR);
	//路径数：（路径数）- 1
	cache->ways = (cache_size_id & MASK_NUM_WAYS) >> NUM_WAYS_SHIFT;
	//表示集合的个数为：(number of sets) - 1。
	cache->sets = (cache_size_id & MASK_NUM_SETS) >> NUM_SETS_SHIFT;
}

static int action_dcache_all(enum cache_action action)
{
	struct dcache_config cache;
	u32 *action_reg;
	int i, j;

	action_reg = get_action_reg_set_ways(action);
	if (!action_reg)
		return -EINVAL;
	//V7M_PROC_REG_CSSELR 缓存大小选择寄存器 
	//SEL_I_OR_D 允许选择指令或数据缓存 0：表示数据缓存 1：表示指令缓存
	clrbits_le32(V7M_PROC_REG_CSSELR, BIT(SEL_I_OR_D));
	/* Make sure cache selection is effective for next memory access */
	dsb();

	get_cache_ways_sets(&cache);	/* Get number of ways & sets */
	debug("cache: ways= %d, sets= %d\n", cache.ways + 1, cache.sets + 1);
	for (i = cache.sets; i >= 0; i--) {
		for (j = cache.ways; j >= 0; j--) {
			writel((j << WAYS_SHIFT) 	//设置操作应用的/索引。缓存中的索引数取决于配置的缓存大小。当该值小于最大值时，使用该字段的LSB。缓存中的集合数量可以通过读取第219页的缓存大小ID寄存器来确定
			| (i << SETS_SHIFT),		//这个操作适用于。对于数据缓存，取值为0、1、2和3。
			       action_reg);
		}
	}

	/* Make sure cache action is effective for next memory access */
	dsb();
	isb();	/* Make sure instruction stream sees it */

	return 0;
}


void enable_caches(void)
{
#if !CONFIG_IS_ENABLED(SYS_ICACHE_OFF)
	icache_enable();
#endif
#if !CONFIG_IS_ENABLED(SYS_DCACHE_OFF)
	dcache_enable();
#endif
}
```

## include/asm
### arch/arm/include/asm/io.h
#### write
1. 定义局部变量：首先，定义了一个局部变量 __v，类型为 u32（无符号 32 位整数），并将传入的值 v 赋值给 __v。这样做的目的是确保值 v 在后续操作中不会被修改。
2. 内存屏障：调用 __iowmb() 函数，这是一个内存屏障函数，用于确保所有之前的内存写操作在执行后续的 I/O 操作之前完成。内存屏障在多核处理器和复杂的内存系统中非常重要，以确保内存操作的顺序性
3. 写入寄存器：调用 __arch_putl(__v, c) 函数，将值 __v 写入到地址 c 所指向的寄存器中。__arch_putl 是一个架构相关的函数，用于执行实际的写操作。

- 在这段代码中，__iowmb() 使用的是 dmb（数据内存屏障）而不是 dsb（数据同步屏障），主要原因是 dmb 足以确保内存访问的顺序性，而不需要 dsb 提供的更严格的同步保证。
	- 原因分析：
	- 内存访问顺序： dmb 确保在其之前的所有内存访问操作在其之后的内存访问操作之前完成。这对于确保写操作的顺序性已经足够。例如，在写入寄存器之前，确保所有之前的内存写操作已经完成。
	- 性能考虑： dsb 是一种更严格的屏障指令，不仅影响内存访问，还会影响所有类型的指令执行顺序。使用 dsb 会导致更大的性能开销，因为它会强制处理器等待所有之前的指令完成，并刷新所有的缓存和写缓冲区。对于大多数内存写操作来说，这种严格的同步保证通常是不必要的。
	- 适用场景： 在大多数情况下，内存写操作只需要确保内存访问的顺序性，而不需要确保所有类型的指令执行顺序。因此，使用 dmb 可以提供足够的保证，同时避免 dsb 带来的性能开销。

- DSB的使用场景
	1. 系统控制寄存器的修改
	2. 关键的同步操作,例如，在实现自旋锁或其他同步原语时。
	3. 缓存和写缓冲区的刷新
	4. 处理器模式切换(如从用户模式切换到内核模式）时，需要确保所有之前的指令和内存操作都已完成。这时需要使用 DSB。
```c
/* Generic virtual read/write. */
#define __arch_getb(a)			(*(volatile unsigned char *)(a))
#define __arch_getw(a)			(*(volatile unsigned short *)(a))
#define __arch_getl(a)			(*(volatile unsigned int *)(a))
#define __arch_getq(a)			(*(volatile unsigned long long *)(a))

#define __arch_putb(v,a)		(*(volatile unsigned char *)(a) = (v))
#define __arch_putw(v,a)		(*(volatile unsigned short *)(a) = (v))
#define __arch_putl(v,a)		(*(volatile unsigned int *)(a) = (v))
#define __arch_putq(v,a)		(*(volatile unsigned long long *)(a) = (v))

#define writeb(v,c)	({ u8  __v = v; __iowmb(); __arch_putb(__v,c); __v; })
#define writew(v,c)	({ u16 __v = v; __iowmb(); __arch_putw(__v,c); __v; })
#define writel(v,c)	({ u32 __v = v; __iowmb(); __arch_putl(__v,c); __v; })
#define writeq(v,c)	({ u64 __v = v; __iowmb(); __arch_putq(__v,c); __v; })
```

#### __iowmb 内存屏障
- DSB（数据同步屏障）和 DMB（数据内存屏障）都是用于控制内存访问顺序的屏障指令，但它们在具体的行为和应用场景上有所不同。
- DSB 是一种更严格的屏障指令，用于确保在其之前的所有内存访问操作（包括读和写）在其之后的内存访问操作之前完成。它不仅影响内存访问，还会影响所有类型的指令执行顺序。DSB 确保所有之前的指令都已完成，并且所有的缓存和写缓冲区都已刷新。
- DMB 是一种较为宽松的屏障指令，用于确保在其之前的所有内存访问操作在其之后的内存访问操作之前完成。与 DSB 不同，DMB 只影响内存访问的顺序，不影响其他类型的指令执行顺序。DMB 确保内存访问的顺序性，但不强制刷新缓存或写缓冲区。

```c
#define ISB	asm volatile ("isb sy" : : : "memory")	//ISB（指令同步屏障）用于确保在其之前的所有指令在其之后的指令执行之前完成。
#define DSB	asm volatile ("dsb sy" : : : "memory")	//DSB（数据同步屏障）用于确保在其之前的所有内存访问操作在其之后的内存访问操作之前完成。
#define DMB	asm volatile ("dmb sy" : : : "memory")	//DMB（数据内存屏障）用于确保在其之前的所有内存访问操作在其之后的内存访问操作之前完成。

// 在修改系统控制寄存器（如 MPU 配置）后，确保所有更改生效。在执行关键的同步操作时，确保所有之前的内存操作都已完成。
#define mb()		dsb()
#define rmb()		dsb()
#define wmb()		dsb()

// 在多核处理器中，确保一个核心的内存写操作在另一个核心的内存读操作之前完成。在共享内存的多线程程序中，确保内存操作的顺序性。
#define __iormb()	dmb()
#define __iowmb()	dmb()
```

# env
## U_BOOT_ENV_LOCATION
- 通过该宏定义环境变量的位置
```c
/*
 * Define a callback that can be associated with variables.
 * when associated through the ".callbacks" environment variable, the callback
 * will be executed any time the variable is inserted, overwritten, or deleted.
 *
 * For SPL these are silently dropped to reduce code size, since environment
 * callbacks are not supported with SPL.
 */
#ifdef CONFIG_XPL_BUILD
#define U_BOOT_ENV_CALLBACK(name, callback) \
	static inline __maybe_unused void _u_boot_env_noop_##name(void) \
	{ \
		(void)callback; \
	}
#else
#define U_BOOT_ENV_CALLBACK(name, callback) \
	ll_entry_declare(struct env_clbk_tbl, name, env_clbk) = \
	{#name, callback}
#endif

```

## default_environment
```c
const char default_environment[] = {
#endif
#ifndef CONFIG_USE_DEFAULT_ENV_FILE
#ifdef	CONFIG_ENV_CALLBACK_LIST_DEFAULT
	ENV_CALLBACK_VAR "=" CONFIG_ENV_CALLBACK_LIST_DEFAULT "\0"
#endif
#ifdef	CONFIG_ENV_FLAGS_LIST_DEFAULT
	ENV_FLAGS_VAR "=" CONFIG_ENV_FLAGS_LIST_DEFAULT "\0"
#endif
#ifdef	CONFIG_USE_BOOTARGS
	"bootargs="	CONFIG_BOOTARGS			"\0"
#endif
#ifdef	CONFIG_BOOTCOMMAND
	"bootcmd="	CONFIG_BOOTCOMMAND		"\0"
#endif
#if defined(CONFIG_BOOTDELAY)
	"bootdelay="	__stringify(CONFIG_BOOTDELAY)	"\0"
#endif
#if !defined(CONFIG_OF_SERIAL_BAUD) && defined(CONFIG_BAUDRATE) && (CONFIG_BAUDRATE >= 0)
	"baudrate="	__stringify(CONFIG_BAUDRATE)	"\0"
#endif
#ifdef	CONFIG_LOADS_ECHO
	"loads_echo="	__stringify(CONFIG_LOADS_ECHO)	"\0"
#endif
#ifdef	CONFIG_ETHPRIME
	"ethprime="	CONFIG_ETHPRIME			"\0"
#endif
#ifdef	CONFIG_USE_IPADDR
	"ipaddr="	CONFIG_IPADDR			"\0"
#endif
#ifdef	CONFIG_USE_SERVERIP
	"serverip="	CONFIG_SERVERIP			"\0"
#endif
#ifdef	CONFIG_SYS_DISABLE_AUTOLOAD
	"autoload=0\0"
#endif
#ifdef	CONFIG_PREBOOT_DEFINED
	"preboot="	CONFIG_PREBOOT			"\0"
#endif
#ifdef	CONFIG_USE_ROOTPATH
	"rootpath="	CONFIG_ROOTPATH			"\0"
#endif
#ifdef	CONFIG_USE_GATEWAYIP
	"gatewayip="	CONFIG_GATEWAYIP		"\0"
#endif
#ifdef	CONFIG_USE_NETMASK
	"netmask="	CONFIG_NETMASK			"\0"
#endif
#ifdef	CONFIG_USE_HOSTNAME
	"hostname="	CONFIG_HOSTNAME			"\0"
#endif
#ifdef CONFIG_USE_BOOTFILE
	"bootfile="	CONFIG_BOOTFILE			"\0"
#endif
#ifdef	CONFIG_SYS_LOAD_ADDR
	"loadaddr="	__stringify(CONFIG_SYS_LOAD_ADDR)"\0"
#endif
#ifdef	CONFIG_ENV_VARS_UBOOT_CONFIG
	"arch="		CONFIG_SYS_ARCH			"\0"
#ifdef CONFIG_SYS_CPU
	"cpu="		CONFIG_SYS_CPU			"\0"
#endif
#ifdef CONFIG_SYS_BOARD
	"board="	CONFIG_SYS_BOARD		"\0"
	"board_name="	CONFIG_SYS_BOARD		"\0"
#endif
#ifdef CONFIG_SYS_VENDOR
	"vendor="	CONFIG_SYS_VENDOR		"\0"
#endif
#ifdef CONFIG_SYS_SOC
	"soc="		CONFIG_SYS_SOC			"\0"
#endif
#ifdef CONFIG_USB_HOST
	"usb_ignorelist="
#ifdef CONFIG_USB_KEYBOARD
	/* Ignore Yubico devices. Currently only a single USB keyboard device is
	 * supported and the emulated HID keyboard Yubikeys present is useless
	 * as keyboard.
	 */
	"0x1050:*,"
#endif
	"\0"
#endif
#ifdef CONFIG_ENV_IMPORT_FDT
	"env_fdt_path="	CONFIG_ENV_FDT_PATH		"\0"
#endif
#endif
#if defined(CONFIG_BOOTCOUNT_BOOTLIMIT) && (CONFIG_BOOTCOUNT_BOOTLIMIT > 0)
	"bootlimit="	__stringify(CONFIG_BOOTCOUNT_BOOTLIMIT)"\0"
#endif
#ifdef CONFIG_MTDIDS_DEFAULT
	 "mtdids="	CONFIG_MTDIDS_DEFAULT		"\0"
#endif
#ifdef CONFIG_MTDPARTS_DEFAULT
	"mtdparts="	CONFIG_MTDPARTS_DEFAULT		"\0"
#endif
#ifdef CONFIG_EXTRA_ENV_TEXT
	/* This is created in the Makefile */
	CONFIG_EXTRA_ENV_TEXT
#endif
#ifdef	CFG_EXTRA_ENV_SETTINGS
	CFG_EXTRA_ENV_SETTINGS
#endif
#ifdef CONFIG_OF_SERIAL_BAUD
	/* Padding for baudrate at the end when environment is writable */
	"\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
#endif
	"\0"
#else /* CONFIG_USE_DEFAULT_ENV_FILE */
#include "generated/defaultenv_autogenerated.h"
#endif
#ifdef DEFAULT_ENV_INSTANCE_EMBEDDED
	}
#endif
};

const char default_environment[] = {
  	"bootargs=console=ttySTM0,2000000 root=/dev/ram "
    "loglevel=8\000bootcmd=bootm "
    "90080000\000bootdelay=3\000baudrate=2000000\000loadaddr="
    "0xc1800000\000arch=arm\000cpu=armv7m\000board=stm32h750-art-pi\000board_"
    "name=stm32h750-art-pi\000vendor=st\000soc=stm32h7\000kernel_addr_r="
    "0xC0008000\000fdtfile=stm32h750i-art-pi.dtb\000fdt_addr_r="
    "0xC0408000\000scriptaddr=0xC0418000\000pxefile_addr_r="
    "0xC0428000\000ramdisk_addr_r=0xC0438000\000mmc_boot=if mmc dev ${devnum}; "
    "then devtype=mmc; run scan_dev_for_boot_part; fi\000boot_prefixes=/ "
    "/boot/\000boot_scripts=boot.scr.uimg "
    "boot.scr\000boot_script_dhcp=boot.scr.uimg\000boot_targets=mmc0 "
    "\000boot_syslinux_conf=extlinux/extlinux.conf\000boot_extlinux=sysboot "
    "${devtype} ${devnum}:${distro_bootpart} any ${scriptaddr} "
    "${prefix}${boot_syslinux_conf}\000scan_dev_for_extlinux=if test -e "
    "${devtype} ${devnum}:${distro_bootpart} ${prefix}${boot_syslinux_conf}; "
    "then echo Found ${prefix}${boot_syslinux_conf}; run boot_extlinux; echo "
    "EXTLINUX FAILED: continuing...; fi\000boot_a_script=load ${devtype} "
    "${devnum}:${distro_bootpart} ${scriptaddr} ${prefix}${script}; source "
    "${scriptaddr}\000scan_dev_for_scripts=for script in ${boot_scripts}; do "
    "if test -e ${devtype} ${devnum}:${distro_bootpart} ${prefix}${script}; "
    "then echo Found U-Boot script ${prefix}${script}; run boot_a_script; echo "
    "SCRIPT FAILED: continuing...; fi; done\000scan_dev_for_boot=echo Scanning "
    "${devtype} ${devnum}:${distro_bootpart}...; for prefix in "
    "${boot_prefixes}; do run scan_dev_for_extlinux; run scan_dev_for_scripts; "
    "done;\000scan_dev_for_boot_part=part list ${devtype} ${devnum} -bootable "
    "devplist; env exists devplist || setenv devplist 1; for distro_bootpart "
    "in ${devplist}; do if fstype ${devtype} ${devnum}:${distro_bootpart} "
    "bootfstype; then part uuid ${devtype} ${devnum}:${distro_bootpart} "
    "distro_bootpart_uuid ; run scan_dev_for_boot; fi; done; setenv "
    "devplist\000bootcmd_mmc0=devnum=0; run mmc_boot\000distro_bootcmd=for "
    "target in ${boot_targets}; do run bootcmd_${target}; done\000\000"}
```

## env_locations
```c
static enum env_location env_locations[] = {
#ifdef CONFIG_ENV_IS_IN_EEPROM
	ENVL_EEPROM,
#endif
#ifdef CONFIG_ENV_IS_IN_EXT4
	ENVL_EXT4,
#endif
#ifdef CONFIG_ENV_IS_IN_FAT
	ENVL_FAT,
#endif
#ifdef CONFIG_ENV_IS_IN_FLASH
	ENVL_FLASH,
#endif
#ifdef CONFIG_ENV_IS_IN_MMC
	ENVL_MMC,
#endif
#ifdef CONFIG_ENV_IS_IN_NAND
	ENVL_NAND,
#endif
#ifdef CONFIG_ENV_IS_IN_NVRAM
	ENVL_NVRAM,
#endif
#ifdef CONFIG_ENV_IS_IN_REMOTE
	ENVL_REMOTE,
#endif
#ifdef CONFIG_ENV_IS_IN_SPI_FLASH
	ENVL_SPI_FLASH,
#endif
#ifdef CONFIG_ENV_IS_IN_UBI
	ENVL_UBI,
#endif
#ifdef CONFIG_ENV_IS_NOWHERE
	ENVL_NOWHERE,
#endif
};
```

## env/env.c
- 从其他存储位置加载环境变量
- 其他地方没有存储则执行默认的环境变量
- 这样可以在使用在其他地方配置好环境变量,然后在u-boot中直接使用

### env_init
```c
int env_init(void)
{
	struct env_driver *drv;
	int ret = -ENOENT;
	int prio;
	// 从优先级0开始查找环境驱动,直到没有环境驱动
	for (prio = 0; (drv = env_driver_lookup(ENVOP_INIT, prio)); prio++) {
		// 如果环境驱动的init函数存在,则调用init函数
		if (!drv->init || !(ret = drv->init())) // 如果初始化成功
			env_set_inited(drv->location);
		if (ret == -ENOENT) // 如果不需要初始化
			env_set_inited(drv->location);	//gd->env_has_init |= BIT(location);

		debug("%s: Environment %s init done (ret=%d)\n", __func__,
		      drv->name, ret);

		if (gd->env_valid == ENV_INVALID)
			ret = -ENOENT;
	}
	// 如果没有找到环境驱动,则返回-ENOENT
	if (!prio)
		return -ENODEV;
	// 找到了环境驱动,但是环境无效,则使用默认环境
	if (ret == -ENOENT) {
		gd->env_addr = (ulong)&default_environment[0];
		gd->env_valid = ENV_VALID;

		return 0;
	}

	return ret;
}
```

### env_driver_lookup
- 根据优先级和操作查找环境驱动并返回
```c
static struct env_driver *env_driver_lookup(enum env_operation op, int prio)
{
	enum env_location loc = env_get_location(op, prio);
	struct env_driver *drv;

	if (loc == ENVL_UNKNOWN)
		return NULL;

	drv = _env_driver_lookup(loc);
	if (!drv) {
		debug("%s: No environment driver for location %d\n", __func__,
		      loc);
		return NULL;
	}

	return drv;
}
```

### arch_env_get_location
- 根据优先级返回环境位置
```c
__weak enum env_location arch_env_get_location(enum env_operation op, int prio)
{
	if (prio >= ARRAY_SIZE(env_locations))
		return ENVL_UNKNOWN;

	return env_locations[prio];
}
```

### _env_driver_lookup
- 在段中查找环境驱动,匹配符合的环境位置
```c
static struct env_driver *_env_driver_lookup(enum env_location loc)
{
	struct env_driver *drv;
	const int n_ents = ll_entry_count(struct env_driver, env_driver);
	struct env_driver *entry;

	drv = ll_entry_start(struct env_driver, env_driver);
	for (entry = drv; entry != drv + n_ents; entry++) {
		if (loc == entry->location)
			return entry;
	}

	/* Not found */
	return NULL;
}
```

## env/common.c
### env_get_from_linear
```c
static int env_get_from_linear(const char *env, const char *name, char *buf,
			       unsigned len)
{
	const char *p, *end;
	size_t name_len;

	if (name == NULL || *name == '\0')
		return -1;

	name_len = strlen(name);

	for (p = env; *p != '\0'; p = end + 1) {
		const char *value;
		unsigned res;
		//识别到数组结束符
		for (end = p; *end != '\0'; ++end)
			if (end - env >= CONFIG_ENV_SIZE)
				return -1;

		if (strncmp(name, p, name_len) || p[name_len] != '=')
			continue;
		//找到name
		value = &p[name_len + 1];

		res = end - value;
		//拷贝环境变量的值
		memcpy(buf, value, min(len, res + 1));

		if (len <= res) {
			buf[len - 1] = '\0';
			printf("env_buf [%u bytes] too small for value of \"%s\"\n",
			       len, name);
		}

		return res;
	}

	return -1;
}
```

## env/nowhere.c 
- 环墫位置为NOWHERE,无处可去的默认位置会执行这里
- 根据env_locations的定义,这里是最低优先级的执行位置

```c
U_BOOT_ENV_LOCATION(nowhere) = {
	.location	= ENVL_NOWHERE,
	.init		= env_nowhere_init,	//gd->env_valid = ENV_INVALID;
	.load		= env_nowhere_load,
	ENV_NAME("nowhere")
};
```

# serial
## drivers/seria
### serial-uclass.c

# DRAM
- board/st/stm32h750-art-pi/stm32h750-art-pi.c
```c
int dram_init(void)
{
	struct udevice *dev;
	int ret;

	ret = uclass_get_device(UCLASS_RAM, 0, &dev);
	if (ret) {
		debug("DRAM init failed: %d\n", ret);
		return ret;
	}

	if (fdtdec_setup_mem_size_base() != 0)
		ret = -EINVAL;

	return ret;
}
```