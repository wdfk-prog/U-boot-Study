---
title: arm
categories:
  - uboot
  - u-boot分类
  - arch
  - arm
tags:
  - uboot
  - u-boot分类
  - arch
  - arm
abbrlink: 985e7e94
date: 2025-10-03 09:44:27
---
[TOC]

# Kconfig

## 中断控制器

### GIC (Generic Interrupt Controller) 通用中断控制器
- GIC 是 ARM 处理器的一种通用中断控制器，用于管理和分发中断信号。GIC 支持多种中断类型，包括外部中断、定时器中断、软件中断等。GIC 通过中断控制器和中断分配器组件实现中断的管理和分发。
#### GICv2
- GICV2是 ARM 提供的第二版通用中断控制器，广泛应用于 ARMv7 和部分 ARMv8 架构的处理器中。
- 中断管理：支持多达 1020 个中断源，包括外部中断和内部中断。提供中断优先级管理和中断屏蔽功能。
- 分布式架构：包括一个分配器（Distributor）和多个 CPU 接口（CPU Interface），分配器负责中断的分发，CPU 接口负责中断的处理。
- 中断路由：支持将中断路由到特定的 CPU 或多个 CPU，提供灵活的中断处理机制。
- 软件生成中断：支持软件生成中断（SGI），允许处理器之间通过中断进行通信。

#### GICv3
- GICV3 是 ARM 提供的第三版通用中断控制器，广泛应用于 ARMv8 架构的处理器中。
- 扩展的中断管理：支持多达 1020 个 SPI（共享外部中断）和 960 个 LPI（本地中断），提供更大的中断容量。
提供更细粒度的中断优先级管理和中断屏蔽功能。
- 增强的分布式架构：包括一个分配器（Distributor）、多个 Redistributor 和 CPU 接口，Redistributor 负责将中断分发到特定的 CPU 接口。
- 中断路由和重定向：支持更灵活的中断路由和重定向机制，允许中断在不同的 CPU 之间动态分配。
- 中断翻译服务（ITS）：支持中断翻译服务（Interrupt Translation Service, ITS），用于管理和配置 LPI，提供更高效的中断处理。
- 电源管理：支持更高级的电源管理功能，允许在低功耗模式下更高效地管理中断。

### NVIC (Nested Vectored Interrupt Controller) 嵌套向量中断控制器
- ARMv7-M 架构的处理器（如 Cortex-M 系列）使用的是嵌入式中断控制器（Nested Vectored Interrupt Controller, NVIC），而不是通用中断控制器（GIC）。NVIC 是专门为嵌入式系统设计的中断控制器，集成在 Cortex-M 处理器内核中，提供了高效的中断管理和处理能力。
- 嵌入式设计：NVIC 集成在 Cortex-M 处理器内核中，专为嵌入式系统设计，提供低延迟的中断响应。
- 中断优先级管理：NVIC 支持多级中断优先级管理，允许开发者为每个中断源设置优先级，从而实现灵活的中断处理。
- 向量表：NVIC 使用向量表来存储中断处理程序的入口地址。向量表通常位于内存的固定位置，处理器在接收到中断时会根据向量表跳转到相应的中断处理程序。
- 中断屏蔽和使能：NVIC 提供中断屏蔽和使能功能，允许开发者在需要时屏蔽或使能特定的中断源。
- 快速中断响应：NVIC 设计为低延迟的中断响应，适用于实时嵌入式系统。

## Select the ARM data write cache policy 写入缓存策略
### Write-back (WB) 写回
- 特点:
	- 写操作：写操作只更新缓存，并将缓存行标记为脏（dirty）。
	- 内存更新：外部内存只有在缓存行被驱逐（evicted）或显式清除（cleaned）时才会更新。
- 使用场景:
	- 高性能计算：适用于需要高写性能的应用，因为写操作只更新缓存，减少了对外部内存的访问。
	- 数据局部性强的应用：适用于数据局部性强的应用，缓存命中率高，减少了内存访问延迟。
- 优点：
	- 高写性能：写操作只更新缓存，减少了对外部内存的访问，提高了写性能。
	- 减少内存带宽占用：减少了对外部内存的写操作，降低了内存带宽的占用。
- 缺点：
	- 数据一致性问题：需要额外的机制来确保缓存和内存之间的数据一致性，可能导致复杂的缓存管理。
	- 延迟更新：外部内存的更新可能会延迟，导致数据一致性问题。

### Write-through (WT) 写透
- 特点
	- 写操作：写操作同时更新缓存和外部内存。
	- 内存更新：每次写操作都会更新外部内存，不会将缓存行标记为脏。
- 使用场景
	- 数据一致性要求高的应用：适用于需要确保缓存和内存之间数据一致性的应用，如实时系统和数据库。
	- 读操作频繁的应用：适用于读操作频繁的应用，因为写操作不会影响读操作的性能。
- 优点
	- 数据一致性：每次写操作都会更新外部内存，确保缓存和内存之间的数据一致性。
	- 简单的缓存管理：不需要额外的机制来管理缓存和内存之间的数据一致性。
- 缺点
	- 写性能较低：每次写操作都会更新外部内存，增加了写操作的延迟。
	- 内存带宽占用高：每次写操作都会更新外部内存，增加了内存带宽的占用。。

### WWrite allocation (WA) 写分配
- 特点
	- 写缺失：在写缺失（write miss）时分配缓存行。
	- 缓存行填充：在执行写操作之前，会进行突发读取（burst read）以获取缓存行的数据。
- 使用场景
	- 写操作频繁的应用：适用于写操作频繁的应用，因为在写缺失时分配缓存行，提高了写操作的效率。
	- 数据局部性较差的应用：适用于数据局部性较差的应用，因为在写缺失时分配缓存行，提高了缓存命中率。
- 优点
	- 提高写操作效率：在写缺失时分配缓存行，提高了写操作的效率。
	- 提高缓存命中率：在写缺失时分配缓存行，提高了缓存命中率。
- 缺点
	- 突发读取开销：在写缺失时需要进行突发读取，增加了读取的开销。
	- 复杂的缓存管理：需要额外的机制来管理缓存行的分配和填充。

## instruction 指令
### SYS_THUMB_BUILD
- Thumb 指令集是 ARM 处理器的一种压缩指令集，旨在减少代码大小，同时保持较高的性能。在 Thumb 指令集中，许多常用指令被编码为 16 位（2 字节）宽，而不是标准 ARM 指令集中的 32 位（4 字节）宽。这使得 Thumb 指令集在内存受限的嵌入式系统中非常有用。

- 使用此标志可使用 Thumb 指令集构建 U-Boot ARM 架构。Thumb 指令集提供更好的代码密度。对于支持 Thumb2 的 ARM 体系结构，此标志将导致 GCC 生成的 Thumb2 代码。

## USE_ARCH_MEMCPY MEMMOVE MEMSET 使用体系结构优化的内存操作函数
- 内存操作函数（如 memcpy、memmove、memset）是常用的 C 标准库函数，用于对内存进行复制、移动和设置操作。这些函数通常由编译器提供，但也可以通过使用体系结构优化的内存操作函数来提高性能。

## Target select 选择目标芯片
### ARCH_STM32
```c
config ARCH_STM32
	bool "Support STMicroelectronics STM32 MCU with cortex M"
	select CPU_V7M
	select DM
	select DM_SERIAL
	imply CMD_DM
```

## SUPPORT_PASSING_ATAGS
- 支持使用 ATAG 而不是传递一个 devicetree。 这个选项很少使用，并且语义在https://www.kernel.org/doc/Documentation/arm/Booting 第 4a 节。
- ATAG（ARM Tag）是ARM架构中用于传递系统启动信息的一种数据结构。它通常在嵌入式系统中使用，特别是在系统启动时，ATAG会传递给操作系统内核，以便内核能够获取必要的启动参数和硬件信息。
- ATAG由一系列标签（tag）组成，每个标签包含一个标识符和相关的数据。常见的标签类型包括内存大小和位置、命令行参数、初始化RAM磁盘等。每个标签都有一个标准的格式，通常以一个标识符开始，后跟数据长度和具体的数据内容。
- 在系统启动时，启动加载程序（bootloader）会创建并填充ATAG数据结构，然后将其传递给内核。内核解析这些标签，获取系统启动所需的信息，从而正确地初始化系统。
- ATAG在嵌入式系统中非常重要，因为它提供了一种灵活且标准化的方式来传递启动信息，确保操作系统能够适应不同的硬件配置和启动参数。

# lds链接脚本 定义入口函数

- 链接脚本定义了ENTRY(_start),即开始入口为_start

```lds
OUTPUT_FORMAT("elf32-littlearm", "elf32-littlearm", "elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(_start)
```

# include/asm

## assembler.h

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

## unified.h

- W(instr) 的定义展开为 `instr.w`

```asm
#ifdef CONFIG_THUMB2_KERNEL //在include/generated/autoconf.h中定义
#ifdef __ASSEMBLY__         //在makefile脚本中定义
#define W(instr)	instr.w
#else
#define WASM(instr)	#instr ".w"
#endif
```

## io.h
### write
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

### __iowmb 内存屏障
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

# lib

## vectors_m.S 设置中断向量表

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

## crt0.S 定义了_main函数

- crt0 是 "C runtime zero" 的缩写，通常指的是 C 程序的启动代码。它是一个汇编语言文件，负责在操作系统加载程序后进行一些初始化工作，然后调用程序的 main 函数。crt0 是 C 运行时库的一部分，通常由编译器或链接器自动包含在最终生成的可执行文件中。

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

## relocate.S

- relocate_code 函数,用于重新定位代码
- 在 U-Boot 启动过程中，重定位是一个关键步骤，它将 U-Boot 从加载地址移动到运行地址，并修正所有相关的地址引用。

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

## interrupts_m.c
```c
/*
 * 异常进入时 ARMv7-M 处理器会自动保存堆栈
 * 包含一些寄存器的帧。为简单起见，初始
 * implementation 仅使用此自动保存的堆栈帧。
 * 这不包括完整的寄存器集转储、
 * 仅保存 R0-R3、R12、LR、PC 和 xPSR。
 */
struct autosave_regs {
	long uregs[8];
};

#define ARM_XPSR	uregs[7]
#define ARM_PC		uregs[6]
#define ARM_LR		uregs[5]
#define ARM_R12		uregs[4]
#define ARM_R3		uregs[3]
#define ARM_R2		uregs[2]
#define ARM_R1		uregs[1]
#define ARM_R0		uregs[0]

int interrupt_init(void)
{
	enable_interrupts();

	return 0;
}

void enable_interrupts(void)
{
	return;
}

int disable_interrupts(void)
{
	return 0;
}
//打印系统寄存器,便于排查问题
void dump_regs(struct autosave_regs *regs)
{
	printf("pc : %08lx    lr : %08lx    xPSR : %08lx\n",
	       regs->ARM_PC, regs->ARM_LR, regs->ARM_XPSR);
	printf("r12 : %08lx   r3 : %08lx    r2 : %08lx\n"
		"r1 : %08lx    r0 : %08lx\n",
		regs->ARM_R12, regs->ARM_R3, regs->ARM_R2,
		regs->ARM_R1, regs->ARM_R0);
}

void bad_mode(void)
{
	panic("Resetting CPU ...\n");
	reset_cpu();
}
// 错误处理函数
void do_hard_fault(struct autosave_regs *autosave_regs)
{
	printf("Hard fault\n");
	dump_regs(autosave_regs);
	bad_mode();
}

void do_mm_fault(struct autosave_regs *autosave_regs)
{
	printf("Memory management fault\n");
	dump_regs(autosave_regs);
	bad_mode();
}

void do_bus_fault(struct autosave_regs *autosave_regs)
{
	printf("Bus fault\n");
	dump_regs(autosave_regs);
	bad_mode();
}

void do_usage_fault(struct autosave_regs *autosave_regs)
{
	printf("Usage fault\n");
	dump_regs(autosave_regs);
	bad_mode();
}

void do_invalid_entry(struct autosave_regs *autosave_regs)
{
	printf("Exception\n");
	dump_regs(autosave_regs);
	bad_mode();
}
```

## setjmp.S 保存和恢复执行环境
```asm
// 将接下来的代码放入 .text.setjmp 段，并设置段属性为可执行和可分配。
.pushsection .text.setjmp, "ax"
//setjmp : 用于保存当前的执行环境
ENTRY(setjmp)
	/*
	 * 子程序必须保留 registers 的内容
	 * r4-r8、r10、r11（v1-v5、v7 和 v8）和 SP（以及 PCS 中的 r9
	 * 将 R9 指定为 v6 的变体）。
	 */
	mov  ip, sp
	stm  a1, {v1-v8, ip, lr}	//a1的内存位置存储系统寄存器数据
	mov  a1, #0	//返回值为0
	ret  lr	//返回到调用函数
ENDPROC(setjmp)
.popsection

.pushsection .text.longjmp, "ax"
ENTRY(longjmp)	//longjmp : 用于恢复之前保存的执行环境
	ldm  a1, {v1-v8, ip, lr}	//从a1的内存位置读取系统寄存器数据
	mov  sp, ip					//恢复堆栈指针
	mov  a1, a2					//设置返回值
	/* 如果传递的返回值为 0，则返回 1 */
	cmp  a1, #0	
	bne  1f
	mov  a1, #1
1:	
	ret  lr	 					//返回到调用函数
ENDPROC(longjmp)
.popsection
```

## arch/arm/lib/memcpy.S
- 比C库中的memcpy函数更高效的memcpy函数,因为使用了ldmia和stmia指令,可以一次性加载多个寄存器的值,然后一次性存储多个寄存器的值,提高了内存拷贝的效率
- 且处理了不同的对齐情况,提高了内存拷贝的效率
```c
#define LDR1W_SHIFT	0
#define STR1W_SHIFT	0

	//加载ptr指针的值到reg寄存器中
	.macro ldr8w ptr reg1 reg2 reg3 reg4 reg5 reg6 reg7 reg8 abort
	ldmia \ptr!, {\reg1, \reg2, \reg3, \reg4, \reg5, \reg6, \reg7, \reg8}
	.endm
	//加载ptr指针的值到reg寄存器中
	.macro ldr1b ptr reg cond=al abort
	ldrb\cond\() \reg, [\ptr], #1
	.endm
	//将r0,reg1,reg2寄存器的值保存到栈中
	.macro enter reg1 reg2
	stmdb sp!, {r0, \reg1, \reg2}
	.endm
	//将栈中的值加载到r0,reg1,reg2寄存器中
	.macro exit reg1 reg2
	ldmfd sp!, {r0, \reg1, \reg2}
	.endm
/* Prototype: void *memcpy(void *dest, const void *src, size_t n); */
	.syntax unified	//使用统一语法
#if CONFIG_IS_ENABLED(SYS_THUMB_BUILD) && !defined(MEMCPY_NO_THUMB_BUILD)
	.thumb	//使用thumb指令集
	.thumb_func	//声明函数为thumb函数
#endif
ENTRY(memcpy)
		//if(dest == src) return dest
		cmp	r0, r1
		reteq	lr	
		//将r0, r4, lr的值保存到栈中
		enter	r4, lr	
		//n = n - 4; if(n < 0) goto 8f
		subs	r2, r2, #4
		blt	8f	//进行n在1~3的拷贝操作
		//ip = &dest & 3;判定是否4字节对齐
		ands	ip, r0, #3
		//预取数据,减少后续内存访问的延迟，提高内存复制操作的性能
PLD(	pld	[r1, #0]		)
		bne	9f	//如果不是字节对齐,则跳转到9,进行未4字节对齐的拷贝操作
		//ip = &src & 3;判定是否4字节对齐
		ands	ip, r1, #3
		bne	10f //如果不是字节对齐,则跳转到10

		//dest和src都是4字节对齐的,直接进行拷贝操作
		//如果n大于等于32,执行32字节的拷贝操作
1:		subs	r2, r2, #(28)	//n = n - 28;因为上面已经减去了4,所以这里减去28
		stmfd	sp!, {r5 - r8}	//将r5-r8的值保存到栈中,因为这些寄存器在后续的拷贝操作中会用到
		blt	5f					//if(n < 0) goto 5;字节对齐,但是n < 32

	CALGN(	ands	ip, r0, #31		)
	CALGN(	rsb	r3, ip, #32		)
	CALGN(	sbcsne	r4, r3, r2		)  @ C is always set here
	CALGN(	bcs	2f			)
	CALGN(	adr	r4, 6f			)
	CALGN(	subs	r2, r2, r3		)  @ C gets set
	CALGN(	add	pc, r4, ip		)

		//进行n在4字节对齐的拷贝操作
3:	PLD(	pld	[r1, #124]		)
4:		ldr8w	r1, r3, r4, r5, r6, r7, r8, ip, lr, abort=20f	//把*src++取出8*4字节
		subs	r2, r2, #32										//n = n - 32
		str8w	r0, r3, r4, r5, r6, r7, r8, ip, lr, abort=20f	//*dest = *src 8*4字节
		bge	3b	//if(n >= 32) goto 3b
	PLD(	cmn	r2, #96			)
	PLD(	bge	4b			)

		//4字节对齐,但是n < 32
5:		ands	ip, r2, #28	//n = n & 28;
		rsb	ip, ip, #32		//n = 32 - n
#if LDR1W_SHIFT > 0
		lsl	ip, ip, #LDR1W_SHIFT
#endif
		//这里只有当n是4的倍数时才会执行;0,4,8,12,16,20,24,28
		//if(n != 0) pc += n;即跳过几条指令
		addne	pc, pc, ip		@ C is always clear here
		b	7f	//否则进行剩余的拷贝操作,并退出

6:		//用于加载单个字（4字节）的数据。
        .rept	(1 << LDR1W_SHIFT)
        W(nop)
        .endr
        ldr1w	r1, r3, abort=20f
        ldr1w	r1, r4, abort=20f
        ldr1w	r1, r5, abort=20f
        ldr1w	r1, r6, abort=20f
        ldr1w	r1, r7, abort=20f
        ldr1w	r1, r8, abort=20f
        ldr1w	r1, lr, abort=20f

		//恢复上下文,准备退出
7:		ldmfd	sp!, {r5 - r8}	//将栈中的值加载到r5-r8寄存器中
		//进行n在1~3的拷贝操作
		//其他n=2的情况不做判定,直接进行拷贝操作;比进行判定再拷贝效率更高
8:		movs	r2, r2, lsl #31			//判定n是否为0,更新条件码
		ldr1b	r1, r3, ne, abort=21f	//if(n != 0) r3 = *src++
		ldr1b	r1, r4, cs, abort=21f	//if(n > 1) r4 = *src++
		ldr1b	r1, ip, cs, abort=21f	//if(n > 1) ip = *src++
		str1b	r0, r3, ne, abort=21f	//if(n != 0) *dest++ = r3
		str1b	r0, r4, cs, abort=21f	//if(n > 1) *dest++ = r4
		str1b	r0, ip, cs, abort=21f	//if(n > 1) *dest++ = ip

		exit	r4, lr	//将栈中的值加载到r0, r4, lr寄存器中
		ret	lr			//返回到调用函数

		//进行未4字节对齐的拷贝操作
9:		rsb	ip, ip, #4	//dest_offest = 4 - &dest & 3
		//dest地址没有4字节对齐,判定dest地址对于4字节对齐的偏移量
		cmp	ip, #2		//判定(dest_offest == 2),更新条件码
		//偏移3,拷贝1次;以此类推
		ldr1b	r1, r3, gt, abort=21f	//if(dest_offest == 3) r3 = *src++
		ldr1b	r1, r4, ge, abort=21f	//if(dest_offest >= 2) r4 = *src++
		ldr1b	r1, lr, abort=21f		//if(dest_offest >= 1) lr = *src++
		str1b	r0, r3, gt, abort=21f	//if(dest_offest == 3) *dest++ = r3
		str1b	r0, r4, ge, abort=21f	//if(dest_offest >= 2) *dest++ = r4
		subs	r2, r2, ip				//n = n - offest;
		str1b	r0, lr, abort=21f		//if(dest_offest >= 1) *dest++ = lr
		blt	8b							//if(n < 0) goto 8b 没有需要额外拷贝的数据了
		ands	ip, r1, #3				//src_offset = &src & 3
		//src是4字节对齐的,直接进行拷贝操作
		beq	1b							//if(src_offset == 0) goto 1b

		//src地址没有4字节对齐的处理
10:		bic	r1, r1, #3	//清除src地址的低2位
		cmp	ip, #2		//判定(src_offset == 2),更新条件码
		ldr1w	r1, lr, abort=21f	//if(src_offset >= 1) lr = *src++
		beq	17f			//if(src_offset == 0) goto 17
		bgt	18f			//if(src_offset > 2) goto 18

		//将数据向前移动指定的字节数 pull:存储的字节数 push:移动的字节数
		.macro	forward_copy_shift pull push

		subs	r2, r2, #28	//n = n - 28;之前已经减去了4,所以这里减去28
		blt	14f				//if(n < 0) goto 14

	CALGN(	ands	ip, r0, #31		)
	CALGN(	rsb	ip, ip, #32		)
	CALGN(	sbcsne	r4, ip, r2		)  @ C is always set here
	CALGN(	subcc	r2, r2, ip		)
	CALGN(	bcc	15f			)

11:		stmfd	sp!, {r5 - r9}	//将r5-r9的值保存到栈中
	PLD(	pld	[r1, #0]		)
	PLD(	subs	r2, r2, #96		)
	PLD(	pld	[r1, #28]		)
	PLD(	blt	13f			)
	PLD(	pld	[r1, #60]		)
	PLD(	pld	[r1, #92]		)

12:	PLD(	pld	[r1, #124]		)
		// 加载和存储多个字（4字节）的数据。
13:		ldr4w	r1, r4, r5, r6, r7, abort=19f	//把*src++取出4*4字节
		mov	r3, lr, lspull #\pull				//r3 = lr >> pull
		subs	r2, r2, #32						//n = n - 32
		ldr4w	r1, r8, r9, ip, lr, abort=19f	//把*src++取出4*4字节
		orr	r3, r3, r4, lspush #\push			//r3 = r3 | r4 << push
		mov	r4, r4, lspull #\pull				//r4 = r4 >> pull
		orr	r4, r4, r5, lspush #\push			//r4 = r4 | r5 << push
		mov	r5, r5, lspull #\pull
		orr	r5, r5, r6, lspush #\push
		mov	r6, r6, lspull #\pull
		orr	r6, r6, r7, lspush #\push
		mov	r7, r7, lspull #\pull
		orr	r7, r7, r8, lspush #\push
		mov	r8, r8, lspull #\pull
		orr	r8, r8, r9, lspush #\push
		mov	r9, r9, lspull #\pull
		orr	r9, r9, ip, lspush #\push
		mov	ip, ip, lspull #\pull
		orr	ip, ip, lr, lspush #\push
		str8w	r0, r3, r4, r5, r6, r7, r8, r9, ip, abort=19f
		bge	12b
	PLD(	cmn	r2, #96			)
	PLD(	bge	13b			)

		ldmfd	sp!, {r5 - r9}
		//处理剩余的拷贝操作
14:		ands	ip, r2, #28	//n = n & 28;
		//这里只有当n是4的倍数时才会执行;0,4,8,12,16,20,24,28
		beq	16f				//if(n == 0) goto 16
		//存储单个字（4字节）的数据。
15:		mov	r3, lr, lspull #\pull	
		ldr1w	r1, lr, abort=21f
		subs	ip, ip, #4
		orr	r3, r3, lr, lspush #\push
		str1w	r0, r3, abort=21f
		bgt	15b				//if(n > 0) goto 15
	CALGN(	cmp	r2, #0			)
	CALGN(	bge	11b			)
		//调整源地址
16:		sub	r1, r1, #(\push / 8)	//r1 = r1 - push / 8
		b	8b						//跳转到8b,进行剩余的拷贝操作,并退出

		.endm

17:		forward_copy_shift	pull=16	push=16

18:		forward_copy_shift	pull=24	push=8
/*
 * Abort preamble and completion macros.
 * If a fixup handler is required then those macros must surround it.
 * It is assumed that the fixup code will handle the private part of
 * the exit macro.
 */

	.macro	copy_abort_preamble
19:	ldmfd	sp!, {r5 - r9}
	b	21f
20:	ldmfd	sp!, {r5 - r8}
21:
	.endm
	// 错误处理逻辑
	// 恢复寄存器状态并返回错误
	.macro	copy_abort_end
	ldmfd	sp!, {r4, lr}	//将栈中的值加载到r0, r4, lr寄存器中
	ret	lr					//返回到调用函数
	.endm
ENDPROC(memcpy)
```

## arch/arm/lib/memset.S
- 同理

# cpu
## armv7m
- 参考[PM0253 Cortex®-M7 编程手册 P221](../学习芯片/ART-PI/PM0253%20Cortex®-M7%20编程手册.pdf)

### start.S 定义了reset函数,跳转到_main

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

### mpu.c
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

### armv7_mpu.h
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

### cache.c
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
```

#### enable_caches
```c
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

#### flush_dcache_range
```c
void flush_dcache_range(unsigned long start, unsigned long stop)
{
	if (action_cache_range(FLUSH_POC, start, stop - start)) {
		printf("ERR: D-cache not flushed\n");
		return;
	}
}
```

### cpu.c
#### reset_cpu
```c
/*
 * Perform the low-level reset.
 */
void reset_cpu(void)
{
	/*
	 * Perform reset but keep priority group unchanged.
	 */
	writel((V7M_AIRCR_VECTKEY << V7M_AIRCR_VECTKEY_SHIFT)
		| (V7M_SCB->aircr & V7M_AIRCR_PRIGROUP_MSK)
		| V7M_AIRCR_SYSRESET, &V7M_SCB->aircr);
}
```

#### cleanup_before_linux
```c
/*
 * This is called right before passing control to
 * the Linux kernel point.
 */
int cleanup_before_linux(void)
{
	/*
	 * this function is called just before we call linux
	 * it prepares the processor for linux
	 *
	 * disable interrupt and turn off caches etc ...
	 */
	disable_interrupts();
	/*
	 * turn off D-cache
	 * dcache_disable() in turn flushes the d-cache
	 * MPU is still enabled & can't be disabled as the u-boot
	 * code might be running in sdram which by default is not
	 * executable area.
	 */
	dcache_disable();
	/* invalidate to make sure no cache line gets dirty between
	 * dcache flushing and disabling dcache */
	invalidate_dcache_all();

	icache_disable();
	invalidate_icache_all();

	return 0;
}
```

# borad
## mach-stm32
### soc.c
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

### stm32h750-art-pi
#### stm32h750-art-pi.c
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

#### include/configs/stm32h750-art-pi.h
```c
//SDRAM 32MB 分配了24MB给内存 预留了8MB
//其中2MB用于RAMDISK
#define CFG_SYS_BOOTMAPSZ		(SZ_16M + SZ_8M)

#define CFG_SYS_FLASH_BASE		0x90000000

#define CFG_SYS_HZ_CLOCK		1000000

#define BOOT_TARGET_DEVICES(func) \
	func(MMC, mmc, 0)

#include <config_distro_bootcmd.h>
#define CFG_EXTRA_ENV_SETTINGS				\
			"kernel_addr_r=0xC0008000\0"		\
			"fdtfile=stm32h750i-art-pi.dtb\0"	\
			"fdt_addr_r=0xC0408000\0"		\
			"scriptaddr=0xC0418000\0"		\
			"pxefile_addr_r=0xC0428000\0" \
			"ramdisk_addr_r=0xC0438000\0"		\
			BOOTENV
```