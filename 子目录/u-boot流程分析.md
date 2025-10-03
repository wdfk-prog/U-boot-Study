---
title: u-boot流程分析
date: 2025-10-03 09:44:27
categories:
  - uboot
  - 子目录
tags:
  - uboot
  - 子目录
---
[toc]

# U-Boot 启动流程

# lds链接脚本
- 从链接脚本中定义了ENTRY(_start),即开始入口为_start

# _start函数
- arch/arm/lib/vectors_m.S 编译的时候设置中断向量表
- 顺序执行下去,执行了reset函数

# reset函数
- arch/arm/cpu/armv7m/start.S 定义了reset函数,跳转到_main

# _main函数
- arch/arm/lib/crt0.S 定义了_main函数

# 初始化堆栈指针sp为CONFIG_SYS_INIT_SP_ADDR
```asm
/* 设置初始 C 运行环境并调用 board_init_f（0）*/
#if defined(CONFIG_TPL_BUILD) && defined(CONFIG_TPL_NEEDS_SEPARATE_STACK)
	ldr	r0, =(CONFIG_TPL_STACK)
#elif defined(CONFIG_XPL_BUILD) && defined(CONFIG_SPL_STACK)
	ldr	r0, =(CONFIG_SPL_STACK)
#else
	ldr	r0, =(SYS_INIT_SP_ADDR)	//没有定义则使用系统初始化的堆栈指针地址
#endif
```

# board_init_f_alloc_reserve 板级初始化第一次分配保留空间
- 保留gd_t结构体大小的空间
```c
// top:栈顶地址,即堆栈指针地址sp传入
ulong board_init_f_alloc_reserve(ulong top)
{
	/* LAST ： 保留 GD （四舍五入为 16 字节的倍数） */
	top = rounddown(top-sizeof(struct global_data), 16);
	return top;
}
```

# board_init_f_init_reserve 板级初始化第一次始化保留
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

# board_init_f 执行一系列的初始化函数
- 调用板级初始化,执行一系列的初始化函数;初始化失败则死循环

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

# relocate_code 重新定位代码
- relocate_code 函数,用于重新定位代码
- 在 U-Boot 启动过程中，重定位是一个关键步骤，它将 U-Boot 从加载地址移动到运行地址，并修正所有相关的地址引用。

# relocate_vectors 重新定位向量表

# c_runtime_cpu_setup 设置最终 （完整） 环境

# board_init_r 板级初始化重定向后的板级初始化

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

# run_main_loop 运行主循环

## cli_init 命令行初始化

## bootdelay_process 获取启动延迟
- 获取`bootdelay`的值,如果没有配置,则使用`CONFIG_BOOTDELAY`的值
- 一般为3秒

## cli_process_fdt 从fdt中获取命令行
- 获取`bootcmd`和`bootsecure`参数
- configs/stm32h750-art-pi_defconfig
	```c
	CONFIG_BOOTCOMMAND="bootm 90080000"
	```
- include/env_default.h
	```c
	#ifdef	CONFIG_BOOTCOMMAND
		"bootcmd="	CONFIG_BOOTCOMMAND		"\0"
	#endif
	```
- 这里获取到的`bootcmd`为`bootm 90080000`

# autoboot_command 处理自动启动命令

# 没有自动启动命令或者执行按键中断,则进入命令行循环
## cli_loop 命令行循环

# 否则执行自动启动命令
## run_command_list 将自启动命令解析并执行
- 解析`bootcmd`命令,并执行

# do_bootm 执行bootm命令

## bootm_run_states 执行bootm命令
- bootm_find_os
- bootm_find_other
- bootm_disable_interrupts
- bootm_load_os

## bootm_find_os 找到操作系统

### boot_get_kernel 获取内核镜像头、起始地址和长度
- 解析 FIT 说明符,获取内核地址
```c
static int boot_get_kernel(const char *addr_fit, struct bootm_headers *images,
			   ulong *os_data, ulong *os_len, const void **kernp)
{
	//解析 FIT 说明符,获取内核地址
	img_addr = genimg_get_kernel_addr_fit(addr_fit, //字符串"90080000"
							&fit_uname_config,	//返回配置单元名称
					      	&fit_uname_kernel);	//返回子镜像名称
	bootstage_mark(BOOTSTAGE_ID_CHECK_MAGIC);

	/* 检查图像类型，对于 FIT 图像，获取 FIT 内核节点 */
	*os_data = *os_len = 0;
	buf = map_sysmem(img_addr, 0);
	switch (genimg_get_format(buf)) {
	case IMAGE_FORMAT_FIT:
		os_noffset = fit_image_load(images, img_addr,
				&fit_uname_kernel, &fit_uname_config,
				IH_ARCH_DEFAULT, IH_TYPE_KERNEL,
				BOOTSTAGE_ID_FIT_KERNEL_START,
				FIT_LOAD_IGNORED, os_data, os_len);
		if (os_noffset < 0)
			return -ENOENT;

		images->fit_hdr_os = map_sysmem(img_addr, 0);
		images->fit_uname_os = fit_uname_kernel;
		images->fit_uname_cfg = fit_uname_config;
		images->fit_noffset_os = os_noffset;
		break;
	}
}
```

### genimg_get_format 获取镜像格式
```c
static int bootm_find_os(const char *cmd_name, const char *addr_fit)
{
	/* get kernel image header, start address and length */
	ret = boot_get_kernel(addr_fit, &images, &images.os.image_start,
			      &images.os.image_len, &os_hdr);
	if (ret) {
		if (ret == -EPROTOTYPE)
			printf("Wrong Image Type for %s command\n", cmd_name);

		printf("ERROR %dE: can't get kernel image!\n", ret);
		return 1;
	}
}
```

### fit_image_load 加载 FIT 镜像
```c
IH_TYPE_KERNEL,			/* OS Kernel Image		*/
```

### fit_conf_get_node 获取 FIT 配置节点
- 查找/configurations节点中的配置节点,默认为default的配置

### fit_image_select 打印 FIT 镜像信息

## bootm_find_other 找到其他镜像 ramdisk、fdt
- 从镜像或者命令行中查找 ramdisk 和 fdt

## bootm_disable_interrupts 禁用中断

## bootm_load_os 加载操作系统

### image_decomp 从镜像中解压

## boot_ramdisk_high 加载 ramdisk 到顶部地址

# do_bootm_linux 执行bootm命令 linux

## boot_prep_linux 执行linux启动前的准备工作

### image_setup_linux 从镜像中设置linux
- 设置FDT内存保留区域 boot_fdt_add_mem_rsv_regions
- 将FDT从内核镜像中拷贝到指定地址 boot_relocate_fdt
- 将FDT转换为动态设备树 image_setup_libfdt