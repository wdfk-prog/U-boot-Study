---
title: arch
date: 2025-10-03 09:44:27
categories:
  - uboot
  - u-boot分类
  - arch
tags:
  - uboot
  - u-boot分类
  - arch
---
[TOC]

# arch 架构介绍

## ARC （Argonaut RISC Core）
- ARC 是一种基于 RISC（精简指令集计算机）原理的处理器架构，广泛应用于嵌入式系统中。
- ARC 处理器由 Synopsys 公司开发和推广，广泛应用于嵌入式系统中，因其高性能和低功耗特性而受到欢迎。

## ARM
- [ARM](./arm.md)

## M68K
- M68K，也称为 68K 或 Motorola 68000，是一种由摩托罗拉公司（Motorola）开发的16/32位微处理器架构。M68K 系列处理器在20世纪80年代和90年代广泛应用于计算机、嵌入式系统和游戏机中。

## MICROBLAZE
- MicroBlaze 是由 Xilinx 公司开发的一种软处理器核心，专门用于其 FPGA（现场可编程门阵列）产品。MicroBlaze 处理器可以通过硬件描述语言（如 VHDL 或 Verilog）在 FPGA 中实现，并根据具体应用需求进行定制。

## MIPS
- MIPS（Microprocessor without Interlocked Pipeline Stages）是一种由 MIPS Technologies 开发的基于 RISC 原理的处理器架构，广泛应用于计算机、嵌入式系统和网络设备中。

## NIOS2
- NIOS2 是由 Altera（现为英特尔公司的一部分）开发的一种软处理器核心，专门用于其 FPGA 产品。NIOS2 处理器可以通过硬件描述语言在 FPGA 中实现，并根据具体应用需求进行定制。

## PPC
- PPC（PowerPC）是一种由 IBM、摩托罗拉和苹果公司联合开发的处理器架构，广泛应用于计算机、嵌入式系统和游戏机中。

## RISCV
- RISCV 是一种开源的 RISC 指令集架构，由加州大学伯克利分校开发，旨在提供一个简单、可扩展和开放的指令集架构，适用于各种计算设备。

## SANDBOX
- SANDBOX 是一种虚拟的处理器架构，通常用于软件开发和测试环境中，提供一个隔离的运行环境，用于模拟和测试软件的行为。

## SH
- SH（SuperH）是一种由日立公司（现为瑞萨电子的一部分）开发的处理器架构，广泛应用于嵌入式系统中。

## X86
- X86 是一种由英特尔公司开发的处理器架构，广泛应用于个人计算机、服务器和嵌入式系统中。

# Kconfig 配置
## ARCH_MAP_SYSMEM 将虚拟地址映射到物理地址
- 通常使用U-Boot（特别是md命令）有效的地址。因此，没有必要考虑U-Boot地址作为需要翻译的虚拟地址
到物理地址。然而，沙盒需要这样做，因为它维护自己的小内存缓冲区，其中包含所有的内存可寻址内存。这个选项会导致一些内存访问通过map_sysmem() / unmap_sysmem（）进行映射。

## CREATE_ARCH_SYMLINK 创建架构相关的符号链接
- 如果设置为y，则将创建一个指向arch / $ (ARCH)的符号链接，其中$（ARCH）是当前的架构。这对于一些脚本很有用，因为它们可以使用相同的路径来引用不同的架构。
- 用于控制项目构建过程中是否创建架构相关的符号链接（symlink）
```makefile
# scripts/Makefile.autoconf
# 符号链接
# 如果 arch/$（ARCH）/mach-$（SOC）/include/mach 存在，则创建指向该目录的符号链接。
# 否则，请创建一个指向 arch/$（ARCH）/include/asm/arch-$（SOC） 的符号链接。
PHONY += create_symlink
create_symlink:
ifdef CONFIG_CREATE_ARCH_SYMLINK
	$(Q)if [ -d arch/$(ARCH)/mach-$(SOC)/include/mach ]; then	\
		dest=../../mach-$(SOC)/include/mach;			\
	else								\
		dest=arch-$(if $(SOC),$(SOC),$(CPU));			\
	fi;								\
	ln -fsn $$dest arch/$(ARCH)/include/asm/arch
endif
```

## HAVE_ARCH_IOREMAP 定义架构是否支持ioremap
- 定义系统是否支持 ioremap 功能
- ioremap 是一种内存映射函数，常用于将物理内存地址映射到虚拟地址空间，从而允许内核访问设备的寄存器或内存区域。

- 对于U-Boot中的大多数体系结构，虚拟地址是直接的映射到物理地址。因此，使用generic是有意义的ioremap及其相关元素的定义在<linux/io.h>中。它们都是空的，会在编译时消失，但是它们将有助于实现与之对应的驱动程序Linux的。MIPS已经有它自己的实现，所以添加了一个配置符号CONFIG_HAVE_ARCH_IOREMAP的MIPS(和可能)可以选择。

## HAVE_SETJMP 定义架构是否支持setjmp longjmp
- 这个配置选项用于指示当前架构是否支持 setjmp 和 longjmp 函数。这两个函数是 C 标准库的一部分，用于实现非本地跳转（non-local jump），即在一个函数中保存当前的执行环境，并在另一个函数中恢复这个环境，从而跳转回原来的位置。

## SYS_BIG_ENDIAN 定义架构是否为大端序
- SUPPORT_BIG_ENDIAN 定义架构是否支持大端序
	- ARC,M68K,MICROBLAZE,PPC,SANDBOX为大端序
- SUPPORT_LITTLE_ENDIAN 定义架构是否支持小端序
	- ARM,MIPS,NIOS2,RISCV,SH,X86为小端序

## SYS_CACHELINE_SIZE 定义架构的缓存大小
```C
config SYS_CACHELINE_SIZE
	int
	default 128 if SYS_CACHE_SHIFT_7
	default 64 if SYS_CACHE_SHIFT_6
	default 32 if SYS_CACHE_SHIFT_5
	default 16 if SYS_CACHE_SHIFT_4
	# Fall-back for MIPS and RISC-V
	default 64 if RISCV
	default 32 if MIPS
```

## LINKER_LIST_ALIGN 定义架构的链接器对齐方式
- 强制每个链接器列表对齐到此边界。这如果使用ll_entry_get()，则是必需的，否则链接器可能会在表格中添加填充物，从而破坏它。

## SYS_ARCH  定义架构类型
- 此选项应包含用于构建适当的 arch/<CONFIG_SYS_ARCH> 目录。 所有架构都应该正确指定此选项。

## SYS_CPU  定义CPU类型
- 此选项应包含 CPU 名称以构建正确的arch/<CONFIG_SYS_ARCH>/cpu/<CONFIG_SYS_CPU> 目录下。
- 这是可选的。 对于没有 CPU 目录的目标， 将此选项留空。

## SYS_SOC  定义SoC类型
- 此选项应包含用于构建目录的 SoC 名称arch/<CONFIG_SYS_ARCH>/cpu/<CONFIG_SYS_CPU>/ <CONFIG_SYS_SOC>的目录。
- 这是可选的。 对于没有 SoC 目录的目标， 将此选项留空。

## SYS_VENDOR 定义供应商
- 此选项应包含目标板的供应商名称。如果已设置并board/<CONFIG_SYS_VENDOR>/common/Makefile 存在，则供应商通用目录。如果还设置了 CONFIG_SYS_BOARD，则board/<CONFIG_SYS_VENDOR>/<CONFIG_SYS_BOARD> 目录下。
- 这是可选的。 对于没有 vendor 目录的目标， 将此选项留空。

## SYS_BOARD 定义板子类型
- 此选项应包含目标板的名称。
	  如果已设置，则板/<CONFIG_SYS_VENDOR>/<CONFIG_SYS_BOARD>或 board/<CONFIG_SYS_BOARD> 目录的编译取决于无论 CONFIG_SYS_VENDOR 是否已设置。
- 这是可选的。 对于没有 board 目录的目标，将此选项留空。

## SYS_CONFIG_NAME 定义配置名称
- 	此选项应包含板头文件的基本名称。头文件 include/configs/<CONFIG_SYS_CONFIG_NAME>.h应该包含在 include/config.h 中。

## Skipping low level initialization functions 跳过低级初始化函数

