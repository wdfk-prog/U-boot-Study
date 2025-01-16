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

## init_sequence_f 板级初始化调用列表	暂缓分析**

```c
static const init_fnc_t init_sequence_f[] = {
	setup_mon_len,	//设置监控长度
#ifdef CONFIG_OF_CONTROL	//配置设备树控制
	fdtdec_setup,	//fdtdec初始化
#endif
#ifdef CONFIG_TRACE_EARLY	//配置早期跟踪
	trace_early_init,
#endif
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

# common/board_r.c	暂缓分析**

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

	/*
	 * Set up the new global data pointer. So far only x86 does this
	 * here.
	 * TODO(sjg@chromium.org): Consider doing this for all archs, or
	 * dropping the new_gd parameter.
	 */
	if (CONFIG_IS_ENABLED(X86_64) && !IS_ENABLED(CONFIG_EFI_APP))
		arch_setup_gd(new_gd);

#if !defined(CONFIG_X86) && !defined(CONFIG_ARM) && !defined(CONFIG_ARM64)
	gd = new_gd;
#endif
	gd->flags &= ~GD_FLG_LOG_READY;

	if (initcall_run_list(init_sequence_r))
		hang();

	/* NOTREACHED - run_main_loop() does not return */
	hang();
}
```

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
/** fdt_chk_basic() - see if basic checking of params and DT data is enabled */
static inline bool fdt_chk_basic(void)
{
	return !(FDT_ASSUME_MASK & FDT_ASSUME_SANE);
}

/** fdt_chk_version() - see if we need to handle old versions of the DT */
static inline bool fdt_chk_version(void)
{
	return !(FDT_ASSUME_MASK & FDT_ASSUME_LATEST);
}

/** fdt_chk_extra() - see if extra checking is enabled */
static inline bool fdt_chk_extra(void)
{
	return !(FDT_ASSUME_MASK & FDT_ASSUME_FRIENDLY);
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
