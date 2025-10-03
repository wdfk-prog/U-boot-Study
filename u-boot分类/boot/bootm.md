---
title: bootm
date: 2025-10-03 09:44:27
categories:
  - uboot
  - u-boot分类
  - boot
tags:
  - uboot
  - u-boot分类
  - boot
---
# cmd/bootm.c 从内存中的映像引导应用程序映像
## do_bootm
```c
//bootm 90080000
//cmdtp:命令表,flag:标志位,argc:参数个数,argv:参数列表
int do_bootm(struct cmd_tbl *cmdtp, int flag, int argc, char *const argv[])
{
	struct bootm_info bmi;
	int ret;

	//执行子命令

	//默认命令执行默认参数初始化
	bootm_init(&bmi);
	if (argc)
		bmi.addr_img = argv[0];	//设置镜像地址 字符串"90080000"
	if (argc > 1)
		bmi.conf_ramdisk = argv[1];
	if (argc > 2)
		bmi.conf_fdt = argv[2];

	/* set up argc and argv[] since some OSes use them */
	bmi.argc = argc;
	bmi.argv = argv;

	ret = bootm_run(&bmi);

	return ret ? CMD_RET_FAILURE : 0;
}
```

# boot/bootm.c
## bootm_init 初始化bootm_info结构体
```c
void bootm_init(struct bootm_info *bmi)
{
	memset(bmi, '\0', sizeof(struct bootm_info));
	bmi->boot_progress = true;
	if (IS_ENABLED(CONFIG_CMD_BOOTM))
		bmi->images = &images;
}
```

## bootm_run
```c
int bootm_run(struct bootm_info *bmi)
{
	return boot_run(bmi, "bootm", BOOTM_STATE_START | BOOTM_STATE_FINDOS |
			BOOTM_STATE_PRE_LOAD | BOOTM_STATE_FINDOTHER |
			BOOTM_STATE_LOADOS);
}
```

## boot_run
```c
int boot_run(struct bootm_info *bmi, const char *cmd, int extra_states)
{
	int states;

	bmi->cmd_name = cmd;
	states = BOOTM_STATE_MEASURE | BOOTM_STATE_OS_PREP |
		BOOTM_STATE_OS_FAKE_GO | BOOTM_STATE_OS_GO;
	if (IS_ENABLED(CONFIG_SYS_BOOT_RAMDISK_HIGH))
		states |= BOOTM_STATE_RAMDISK;
	states |= extra_states;

	return bootm_run_states(bmi, states);
}
```

## bootm_run_states
```c
int bootm_run_states(struct bootm_info *bmi, int states)
{
	struct bootm_headers *images = bmi->images;
	boot_os_fn *boot_fn;
	ulong iflag = 0;
	int ret = 0, need_boot_fn;

	images->state |= states;

	if (states & BOOTM_STATE_START)
		ret = bootm_start();

	if (!ret && (states & BOOTM_STATE_PRE_LOAD))
		ret = bootm_pre_load(bmi->addr_img);

	if (!ret && (states & BOOTM_STATE_FINDOS))
		ret = bootm_find_os(bmi->cmd_name, bmi->addr_img);//字符串"90080000"

	if (!ret && (states & BOOTM_STATE_FINDOTHER)) {
		ulong img_addr;

		img_addr = bmi->addr_img ? hextoul(bmi->addr_img, NULL)
			: image_load_addr;
		//可以通过设置环境变量bootargs来设置ramdisk和fdt,也可以在fit中获取
		ret = bootm_find_other(img_addr, bmi->conf_ramdisk,	//do_bootm bmi.conf_ramdisk = argv[1];
				       bmi->conf_fdt);	//do_bootm bmi.conf_fdt = argv[2];
	}

	/* Load the OS */
	if (!ret && (states & BOOTM_STATE_LOADOS)) {
		iflag = bootm_disable_interrupts();
		ret = bootm_load_os(images, 0);
		if (ret && ret != BOOTM_ERR_OVERLAP)
			goto err;
		else if (ret == BOOTM_ERR_OVERLAP)
			ret = 0;
	}

	/* Relocate the ramdisk */
	//将ramdisk移动到高地址,避免与内核重叠
#ifdef CONFIG_SYS_BOOT_RAMDISK_HIGH
	if (!ret && (states & BOOTM_STATE_RAMDISK)) {
		ulong rd_len = images->rd_end - images->rd_start;

		ret = boot_ramdisk_high(images->rd_start, rd_len,
					&images->initrd_start,
					&images->initrd_end);
		if (!ret) {
			env_set_hex("initrd_start", images->initrd_start);
			env_set_hex("initrd_end", images->initrd_end);
		}
	}
#endif

	/* 从现在开始，我们需要操作系统启动功能 */
	if (ret)
		return ret;
	boot_fn = bootm_os_get_boot_func(images->os.os);
	need_boot_fn = states & (BOOTM_STATE_OS_CMDLINE |
			BOOTM_STATE_OS_BD_T | BOOTM_STATE_OS_PREP |
			BOOTM_STATE_OS_FAKE_GO | BOOTM_STATE_OS_GO);
	if (boot_fn == NULL && need_boot_fn) {
		if (iflag)
			enable_interrupts();
		printf("ERROR: booting os '%s' (%d) is not supported\n",
		       genimg_get_os_name(images->os.os), images->os.os);
		bootstage_error(BOOTSTAGE_ID_CHECK_BOOT_OS);
		return 1;
	}

	/* Call various other states that are not generally used */
	if (!ret && (states & BOOTM_STATE_OS_CMDLINE))
		ret = boot_fn(BOOTM_STATE_OS_CMDLINE, bmi);
	if (!ret && (states & BOOTM_STATE_OS_BD_T))
		ret = boot_fn(BOOTM_STATE_OS_BD_T, bmi);
	if (!ret && (states & BOOTM_STATE_OS_PREP)) {	//准备启动操作系统
		int flags = 0;
		/* 对于 Linux 操作系统，请在控制台处理时执行所有替换 */
		if (images->os.os == IH_OS_LINUX)
			flags = BOOTM_CL_ALL;
		//将bootarg进行替换为静默模式
		ret = bootm_process_cmdline_env(flags);
		if (ret) {
			printf("Cmdline setup failed (err=%d)\n", ret);
			ret = CMD_RET_FAILURE;
			goto err;
		}
		ret = boot_fn(BOOTM_STATE_OS_PREP, bmi);
	}

	/* Check for unsupported subcommand. */
	if (ret) {
		printf("subcommand failed (err=%d)\n", ret);
		return ret;
	}

	/* 现在运行操作系统！我们希望这种情况不会再次出现 */
	if (!ret && (states & BOOTM_STATE_OS_GO))
		ret = boot_selected_os(BOOTM_STATE_OS_GO, bmi, boot_fn);

	/* 处理任何后果 */
err:
	if (iflag)
		enable_interrupts();

	if (ret == BOOTM_ERR_UNIMPLEMENTED) {
		bootstage_error(BOOTSTAGE_ID_DECOMP_UNIMPL);
	} else if (ret == BOOTM_ERR_RESET) {
		printf("Resetting the board...\n");
		reset_cpu();
	}

	return ret;
}
```

## bootm_find_os
```c
/**
 * bootm_find_os（）：找到要启动的操作系统
 *
 * @cmd_name：启动此启动的命令名称，例如 “bootm”
 * @addr_fit：地址和/或 FIT 说明符（bootm 命令的第一个参数）
 * 返回：成功时为 0，错误时为 -ve
 */
static int bootm_find_os(const char *cmd_name, const char *addr_fit)
{
	/* 获取内核镜像头、起始地址和长度 */
	ret = boot_get_kernel(addr_fit, 		//字符串"90080000"
					&images, &images.os.image_start,
			      	&images.os.image_len, &os_hdr);
	if (ret) {
		if (ret == -EPROTOTYPE)
			printf("Wrong Image Type for %s command\n", cmd_name);

		printf("ERROR %dE: can't get kernel image!\n", ret);
		return 1;
	}

	//进行镜像检查

	/* 获取内核入口点 */
	if (images.os.arch == IH_ARCH_I386 ||
	    images.os.arch == IH_ARCH_X86_64) {
	} else if (images.legacy_hdr_valid) {

#if CONFIG_IS_ENABLED(FIT)
	} else if (images.fit_uname_os) {
		int ret;
		//获取内核入口点的地址
		ret = fit_image_get_entry(images.fit_hdr_os,
					  images.fit_noffset_os, &images.ep);
		if (ret) {
			puts("Can't get entry point property!\n");
			return 1;
		}
#endif
	} else if (!ep_found) {
		puts("Could not find kernel entry point!\n");
		return 1;
	}

	images.os.start = map_to_sysmem(os_hdr);

	return 0;
}
```

## boot_get_kernel
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
	switch (genimg_get_format(buf)) {	//获取镜像格式
#if CONFIG_IS_ENABLED(LEGACY_IMAGE_FORMAT)
	case IMAGE_FORMAT_LEGACY:
		break;
#endif
#if CONFIG_IS_ENABLED(FIT)
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
#endif
	default:
		bootstage_error(BOOTSTAGE_ID_CHECK_IMAGETYPE);
		return -EPROTOTYPE;
	}

	debug("   kernel data at 0x%08lx, len = 0x%08lx (%ld)\n",
	      *os_data, *os_len, *os_len);
	*kernp = buf;

	return 0;
}
```

## bootm_find_other
- ramdisk（RAM Disk）是一种将文件系统加载到内存中的技术。它通常用于在系统启动时提供一个临时的根文件系统，以便操作系统内核能够访问必要的文件和驱动程序，直到真正的根文件系统被挂载。
- 临时根文件系统: 在系统启动的早期阶段，内核可能还没有访问永久存储设备（如硬盘、闪存等）的能力。RAM Disk 提供了一个临时的根文件系统，使内核能够加载必要的驱动程序和启动脚本。
- 快速访问: 由于 RAM Disk 存储在内存中，访问速度非常快。这对于启动过程中的性能提升非常有帮助。
```c
//满足os类型和os的操作系统类型寻找ramdisk和fdt
static int bootm_find_other(ulong img_addr, const char *conf_ramdisk,
			    const char *conf_fdt)
{
	if ((images.os.type == IH_TYPE_KERNEL ||
	     images.os.type == IH_TYPE_KERNEL_NOLOAD ||
	     images.os.type == IH_TYPE_MULTI) &&
	    (images.os.os == IH_OS_LINUX || images.os.os == IH_OS_VXWORKS ||
	     images.os.os == IH_OS_EFI || images.os.os == IH_OS_TEE)) {
		return bootm_find_images(img_addr, conf_ramdisk, conf_fdt, 0,
					 0);
	}

	return 0;
}
```

## bootm_find_images
- 从镜像中查找 ramdisk 和 fdt
```c
int bootm_find_images(ulong img_addr, const char *conf_ramdisk,
		      const char *conf_fdt, ulong start, ulong size)
{
	const char *select = conf_ramdisk;
	char addr_str[17];
	void *buf;
	int ret;

	/* find ramdisk */
	ret = boot_get_ramdisk(select, &images, IH_INITRD_ARCH,
			       &images.rd_start, &images.rd_end);
	if (ret) {
		puts("Ramdisk image is corrupt or invalid\n");
		return 1;
	}
	/* 检查 ramdisk 是否与操作系统映像重叠 */
	if (check_overlap("RD", images.rd_start, images.rd_end, start, size))
		return 1;

	if (CONFIG_IS_ENABLED(OF_LIBFDT)) {
		buf = map_sysmem(img_addr, 0);

		/* find flattened device tree */
		//一样的逻辑,获取fdt地址与长度
		ret = boot_get_fdt(buf, conf_fdt, IH_ARCH_DEFAULT, 	//arm
					&images,
				   &images.ft_addr, &images.ft_len);
		if (ret) {
			puts("Could not find a valid device tree\n");
			return 1;
		}

		/* 检查 FDT 是否与 OS 映像重叠 */
		if (check_overlap("FDT", map_to_sysmem(images.ft_addr),
				  images.ft_len, start, size))
			return 1;

		if (IS_ENABLED(CONFIG_CMD_FDT))
			//fdtaddr: 镜像中fdt的地址
			set_working_fdt_addr(map_to_sysmem(images.ft_addr));	//在环境变量中设置fdt地址
	}
}
```

## bootm_disable_interrupts
```c
/**
 * bootm_disable_interrupts（） - 禁用中断以准备加载/启动
 *
 * 返回：中断标志（如果中断被禁用，则为 0，如果中断被禁用，则为非零
 * 已启用）
 */
ulong bootm_disable_interrupts(void)
{
	ulong iflag;

	/*
	 * 我们已经到了不归路：我们要
	 * 覆盖所有异常向量代码，所以我们不能轻易
	 * 不再从任何故障中恢复...
	 */
	iflag = disable_interrupts();
#ifdef CONFIG_NETCONSOLE
	/* 如果 NetConsole 可以保留以太网堆栈，请停止它 */
	eth_halt();
#endif

	return iflag;
}
```

## bootm_load_os
```c
static int bootm_load_os(struct bootm_headers *images, int boot_progress)
{
	load_buf = map_sysmem(load, 0);
	image_buf = map_sysmem(os.image_start, image_len);
	//image_decomp解压缩镜像,没压缩且是XIP,直接返回
	err = image_decomp(os.comp, load, os.image_start, os.type,
			   load_buf, image_buf, image_len,
			   CONFIG_SYS_BOOTM_LEN, &load_end);
	if (err) {
		err = handle_decomp_error(os.comp, load_end - load,
					  CONFIG_SYS_BOOTM_LEN, err);
		bootstage_error(BOOTSTAGE_ID_DECOMP_IMAGE);
		return err;
	}
	/* We need the decompressed image size in the next steps */
	images->os.image_len = load_end - load;

	flush_cache(flush_start, ALIGN(load_end, ARCH_DMA_MINALIGN) - flush_start);

	debug("   kernel loaded at 0x%08lx, end = 0x%08lx\n", load, load_end);
	bootstage_mark(BOOTSTAGE_ID_KERNEL_LOADED);
	//检查内存是否重叠
	no_overlap = (os.comp == IH_COMP_NONE && load == image_start);

	if (!no_overlap && load < blob_end && load_end > blob_start) {
		debug("images.os.start = 0x%lX, images.os.end = 0x%lx\n",
		      blob_start, blob_end);
		debug("images.os.load = 0x%lx, load_end = 0x%lx\n", load,
		      load_end);

		/* Check what type of image this is. */
		if (images->legacy_hdr_valid) {
			if (image_get_type(&images->legacy_hdr_os_copy)
					== IH_TYPE_MULTI)
				puts("WARNING: legacy format multi component image overwritten\n");
			return BOOTM_ERR_OVERLAP;
		} else {
			puts("ERROR: new format image overwritten - must RESET the board to recover\n");
			bootstage_error(BOOTSTAGE_ID_OVERWRITTEN);
			return BOOTM_ERR_RESET;
		}
	}
	//设置lmbd(内存块描述符)的保留区域,保护内核区域
	if (CONFIG_IS_ENABLED(LMB))
		lmb_reserve(images->os.load, (load_end - images->os.load),
			    LMB_NONE);}

	return 0;
}
```

# boot/bootm_os.c
## bootm_os_get_boot_func
```c
boot_os_fn *bootm_os_get_boot_func(int os)
{
	return boot_os[os];
}
```

## boot_selected_os

# arch/arm/lib/bootm.c
## do_bootm_linux
```c
/* Main Entry point for arm bootm implementation
 *
 * Modeled after the powerpc implementation
 * DIFFERENCE: Instead of calling prep and go at the end
 * they are called if subcommand is equal 0.
 */
int do_bootm_linux(int flag, struct bootm_info *bmi)
{
	struct bootm_headers *images = bmi->images;

	/* No need for those on ARM */
	if (flag & BOOTM_STATE_OS_BD_T || flag & BOOTM_STATE_OS_CMDLINE)
		return -1;

	if (flag & BOOTM_STATE_OS_PREP) {
		boot_prep_linux(images);	//准备启动linux
		return 0;
	}

	if (flag & (BOOTM_STATE_OS_GO | BOOTM_STATE_OS_FAKE_GO)) {
		boot_jump_linux(images, flag);//启动linux
		return 0;
	}

	boot_prep_linux(images);
	boot_jump_linux(images, flag);
	return 0;
}
```

## boot_prep_linux 准备启动linux
```c
static void boot_prep_linux(struct bootm_headers *images)
{
	//"bootargs=" "console=ttySTM0,2000000 root=/dev/ram loglevel=8"
	char *commandline = env_get("bootargs");

	if (CONFIG_IS_ENABLED(OF_LIBFDT) && IS_ENABLED(CONFIG_LMB) 
		&& images->ft_len	//bootm_find_images -> boot_get_fdt 获取fdt_len
		) {
		debug("using: FDT\n");
		if (image_setup_linux(images)) {	//fdt中设置参数,并将fdt移动到内存中,转换为动态设备树
			panic("FDT creation failed!");
		}
	} else if (BOOTM_ENABLE_TAGS) {

	} else {
		panic("FDT and ATAGS support not compiled in\n");
	}

	board_prep_linux(images);
}
```

## boot_jump_linux  启动linux
```c
static void boot_jump_linux(struct bootm_headers *images, int flag)
{
	unsigned long machid = gd->bd->bi_arch_number;
	char *s;
	void (*kernel_entry)(int zero, int arch, uint params);
	unsigned long r2;
	int fake = (flag & BOOTM_STATE_OS_FAKE_GO);
	//bootm_find_os -> fit_image_get_entry 获取内核入口点
	//通过在fdt中查找"entry"的属性值来获取内核入口点
	kernel_entry = (void (*)(int, int, uint))images->ep;
#ifdef CONFIG_CPU_V7M
	//将内核入口点的最低位设置为1,表示Thumb模式
	ulong addr = (ulong)kernel_entry | 1;
	kernel_entry = (void *)addr;
#endif
	s = env_get("machid");
	if (s) {
		if (strict_strtoul(s, 16, &machid) < 0) {
			debug("strict_strtoul failed!\n");
			return;
		}
		printf("Using machid 0x%lx from environment\n", machid);
	}

	debug("## Transferring control to Linux (at address %08lx)" \
		"...\n", (ulong) kernel_entry);
	bootstage_mark(BOOTSTAGE_ID_RUN_OS);
	announce_and_cleanup(fake);
	//传入参数为fdt的地址或者命令行参数
	if (CONFIG_IS_ENABLED(OF_LIBFDT) && images->ft_len)
		r2 = (unsigned long)images->ft_addr;
	else
		r2 = gd->bd->bi_boot_params;

	if (!fake) {
		/*
		具体来说，kernel_entry 是一个函数指针，指向内核的入口点。引导加载程序在完成必要的初始化和设置后，会调用这个入口点来启动操作系统内核。

		传递的三个参数分别是：

		0：这是传递给内核的第一个参数，通常表示没有传递额外的参数。
		machid：这是传递给内核的机器 ID，用于标识当前硬件平台。内核可以根据这个 ID 来加载特定于硬件的平台代码。
		r2：这是传递给内核的第三个参数，通常用于传递设备树（Device Tree）或其他硬件配置信息。设备树是一种数据结构，用于描述硬件的布局和配置，内核可以使用它来初始化和配置硬件。
		在 ARM 架构中，函数调用约定规定了如何传递参数和返回值。通常，前四个参数通过寄存器 r0 到 r3 传递。在这个例子中，0 被传递到 r0，machid 被传递到 r1，r2 被传递到 r2。

		通过调用 kernel_entry 函数，引导加载程序将控制权交给操作系统内核，内核将开始执行其初始化代码，并最终启动操作系统。这是引导加载过程中的最后一步，也是最关键的一步，因为它标志着从引导加载程序到操作系统内核的过渡。
		*/
		kernel_entry(0, machid, r2);	//启动内核
	}
}
```

## announce_and_cleanup 打印消息并准备内核启动
```c
static void announce_and_cleanup(int fake)
{
	bootstage_mark_name(BOOTSTAGE_ID_BOOTM_HANDOFF, "start_kernel");

	board_quiesce_devices();

	printf("\nStarting kernel ...%s\n\n", fake ?
		"(fake run for tracing)" : "");
	/*
	 * 调用所有设置了移除标志的设备的移除功能。
	 * 这可能对最后阶段的操作（如取消
	 * 的 DMA 操作或释放器件内部缓冲区。
	 * dm_remove_devices_active（） 确保在
	 * 第二轮。
	 */
	 //移除所有活动设备
	dm_remove_devices_active();
	//最后的清理
	cleanup_before_linux();
}
```