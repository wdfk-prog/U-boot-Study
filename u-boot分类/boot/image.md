---
title: image
categories:
  - uboot
  - u-boot分类
  - boot
tags:
  - uboot
  - u-boot分类
  - boot
abbrlink: c53d045f
date: 2025-10-03 09:44:27
---
# image-board.c
## genimg_get_kernel_addr_fit
```c
/**
 * genimg_get_kernel_addr_fit（） - 解析 FIT 说明符
 *
 * 从通常为第一个的字符串中获取真正的内核起始地址 bootm/bootz 的 argv
 * 这些情况根据 @img_addr 的值进行处理：

 * NULL：返回 image_load_addr，不设置最后两个参数
 * “<addr>”：返回地址

 * 对于 FIT：
 * “[<addr>]#<conf>”：返回地址（或image_load_addr）、
 * 将 fit_uname_config 设置为 Config Name
 * “[<addr>]：<subimage>”：返回地址（或 image_load_addr）并设置
 * fit_uname_kernel子图像名称
 *
 * @img_addr：字符串可能包含真实图像地址（或 NULL）
 * @fit_uname_config：返回配置单元名称
 * @fit_uname_kernel：返回子图像名称
 *
 * 返回： kernel start address
 */
ulong genimg_get_kernel_addr_fit(const char *const img_addr,
				 const char **fit_uname_config,
				 const char **fit_uname_kernel)
{
	ulong kernel_addr;

	//没有指定地址,则使用默认地址
	if (!img_addr) {
		kernel_addr = image_load_addr;
		debug("*  kernel: default image load address = 0x%08lx\n",
		      image_load_addr);
	} else if (CONFIG_IS_ENABLED(FIT) &&	//使用了FIT
		//从img_addr传入的字符串中根据分隔符"#解析出配置,则返回1,否则返回0
		   fit_parse_conf(img_addr, image_load_addr, &kernel_addr,
				  fit_uname_config)) {
		debug("*  kernel: config '%s' from image at 0x%08lx\n",
		      *fit_uname_config, kernel_addr);
	} else if (CONFIG_IS_ENABLED(FIT) &&
		//从img_addr传入的字符串中根据分隔符":"解析出子图像,则返回1,否则返回0
		   fit_parse_subimage(img_addr, image_load_addr, &kernel_addr,
				      fit_uname_kernel)) {
		debug("*  kernel: subimage '%s' from image at 0x%08lx\n",
		      *fit_uname_kernel, kernel_addr);
	} else {
		//将img_addr字符串转换为地址
		kernel_addr = hextoul(img_addr, NULL);
		debug("*  kernel: cmdline image address = 0x%08lx\n",
		      kernel_addr);
	}

	return kernel_addr;
}
```

## genimg_get_format
```c
/**
 * genimg_get_format - 获取图像格式类型
 * @img_addr：镜像起始地址
 *
 * genimg_get_format（） 检查提供的地址是否指向有效的旧版或 FIT 图像。
 *
 * 新的 uImage 格式和 FDT blob 基于 libfdt。FDT blob可以直接传递或嵌入到 FIT 图像中。
 * 在这两种情况下genimg_get_format（） 必须能够识别 libfdt 头文件。
 *
 *返回：图像格式类型或IMAGE_FORMAT_INVALID如果不存在图像
 */
#define IMAGE_FORMAT_INVALID	0x00
#define IMAGE_FORMAT_LEGACY	0x01	/* legacy image_header based format */
#define IMAGE_FORMAT_FIT	0x02	/* new, libfdt based format */
#define IMAGE_FORMAT_ANDROID	0x03	/* Android boot image */
int genimg_get_format(const void *img_addr)
{
	//检查传统的 uImage 头
	if (CONFIG_IS_ENABLED(LEGACY_IMAGE_FORMAT)) {
		const struct legacy_img_hdr *hdr;

		hdr = (const struct legacy_img_hdr *)img_addr;
		if (image_check_magic(hdr))
			return IMAGE_FORMAT_LEGACY;
	}
	//检查 FIT 头
	if (CONFIG_IS_ENABLED(FIT) || CONFIG_IS_ENABLED(OF_LIBFDT)) {
		if (!fdt_check_header(img_addr))
			return IMAGE_FORMAT_FIT;
	}
	if (IS_ENABLED(CONFIG_ANDROID_BOOT_IMAGE) &&
	    is_android_boot_image_header(img_addr))
		return IMAGE_FORMAT_ANDROID;

	return IMAGE_FORMAT_INVALID;
}
```

## boot_get_ramdisk
```c
int boot_get_ramdisk(char const *select, struct bootm_headers *images,
		     uint arch, ulong *rd_start, ulong *rd_end)
{	
	//从命令中解析出ramdisk的地址
	if (select && strcmp(select, "-") ==  0) {
		debug("## Skipping init Ramdisk\n");
		rd_len = 0;
		rd_data = 0;
	} else if (select || genimg_has_config(images)) {	//从fit中解析出ramdisk的地址
		int ret;
		//从fit中解析出ramdisk的地址与长度
		ret = select_ramdisk(images, select, arch, &rd_data, &rd_len);
		if (ret == -ENOPKG)
			return 0;
		else if (ret)
			return ret;
	} else {
		/*
		 * no initrd image
		 */
		bootstage_mark(BOOTSTAGE_ID_NO_RAMDISK);
		rd_len = 0;
		rd_data = 0;
	}

	if (!rd_data) {
		debug("## No init Ramdisk\n");
	} else {
		*rd_start = rd_data;
		*rd_end = rd_data + rd_len;
	}
	debug("   ramdisk start = 0x%08lx, ramdisk end = 0x%08lx\n",
	      *rd_start, *rd_end);

	return 0;
}
```

## select_ramdisk
- 从fit中解析出ramdisk的地址
```c
static int select_ramdisk(struct bootm_headers *images, const char *select, u8 arch,
			  ulong *rd_datap, ulong *rd_lenp)
{
	const char *fit_uname_config;
	const char *fit_uname_ramdisk;
	bool done_select = !select;
	bool done = false;
	int rd_noffset;
	ulong rd_addr = 0;
	char *buf;

	if (CONFIG_IS_ENABLED(FIT)) {	//从镜像的fit中解析出ramdisk的地址
		fit_uname_config = images->fit_uname_cfg;
		fit_uname_ramdisk = NULL;

		if (select) {
		}
	}
	//从镜像的fit中获取ramdisk的地址
	if (CONFIG_IS_ENABLED(FIT) && !select) {
		rd_addr = map_to_sysmem(images->fit_hdr_os);
		rd_noffset = fit_get_node_from_config(images, FIT_RAMDISK_PROP,
						      rd_addr);
		if (rd_noffset == -ENOENT)
			return -ENOPKG;
		else if (rd_noffset < 0)
			return rd_noffset;
	}

	buf = map_sysmem(rd_addr, 0);
	switch (genimg_get_format(buf)) {
	case IMAGE_FORMAT_LEGACY:
		break;
	case IMAGE_FORMAT_FIT:
		if (CONFIG_IS_ENABLED(FIT)) {
			//从fit中解析出ramdisk的地址与长度,名称
			rd_noffset = fit_image_load(images, rd_addr,
						    &fit_uname_ramdisk,
						    &fit_uname_config,
						    arch, IH_TYPE_RAMDISK,
						    BOOTSTAGE_ID_FIT_RD_START,
						    FIT_LOAD_OPTIONAL_NON_ZERO,
						    rd_datap, rd_lenp);
			if (rd_noffset < 0)
				return rd_noffset;

			images->fit_hdr_rd = map_sysmem(rd_addr, 0);
			images->fit_uname_rd = fit_uname_ramdisk;
			images->fit_noffset_rd = rd_noffset;
			done = true;
		}
		break;
	case IMAGE_FORMAT_ANDROID:
		break;
	}
	return 0;
}
```

## boot_ramdisk_high
```c
int boot_ramdisk_high(ulong rd_data, ulong rd_len, ulong *initrd_start,
		      ulong *initrd_end)
{
	char	*s;
	phys_addr_t initrd_high;
	int	initrd_copy_to_ram = 1;

	s = env_get("initrd_high");
	if (s) {	//从环境变量中获取initrd_high的地址
		/* a value of "no" or a similar string will act like 0,
		 * turning the "load high" feature off. This is intentional.
		 */
		initrd_high = hextoul(s, NULL);
		if (initrd_high == ~0)	//-1(未定义或无效值),则不拷贝到高地址
			initrd_copy_to_ram = 0;
	} else {
		//计算initrd_high的地址 = 内核内存映射大小 + RAM的基础地址
		initrd_high = env_get_bootm_mapsize() + env_get_bootm_low();
	}

	if (rd_data) {
		//0拷贝到高地址
		if (!initrd_copy_to_ram) {	/* zero-copy ramdisk support */
			debug("   in-place initrd\n");
			*initrd_start = rd_data;
			*initrd_end = rd_data + rd_len;
			lmb_reserve(rd_data, rd_len, LMB_NONE);
		} else {
			//拷贝到高地址
			if (initrd_high)
				*initrd_start =
					//分配一个高于initrd_high的地址,按0x1000对齐
					(ulong)lmb_alloc_base(rd_len,
								    0x1000,
								    initrd_high,
								    LMB_NONE);
			else
				//在当前地址分配内存
				*initrd_start = (ulong)lmb_alloc(rd_len,
								 0x1000);

			if (*initrd_start == 0) {
				puts("ramdisk - allocation error\n");
				goto error;
			}
			bootstage_mark(BOOTSTAGE_ID_COPY_RAMDISK);

			*initrd_end = *initrd_start + rd_len;
			printf("   Loading Ramdisk to %08lx, end %08lx ... ",
			       *initrd_start, *initrd_end);

			memmove_wd((void *)*initrd_start,
				   (void *)rd_data, rd_len, CHUNKSZ);

			/*
			 * Ensure the image is flushed to memory to handle
			 * AMP boot scenarios in which we might not be
			 * HW cache coherent
			 */
			if (IS_ENABLED(CONFIG_MP)) {
				flush_cache((unsigned long)*initrd_start,
					    ALIGN(rd_len, ARCH_DMA_MINALIGN));
			}
			puts("OK\n");
		}
	} else {
		*initrd_start = 0;
		*initrd_end = 0;
	}
	debug("   ramdisk load start = 0x%08lx, ramdisk load end = 0x%08lx\n",
	      *initrd_start, *initrd_end);

	return 0;

error:
	return -1;
}
```

## memmove_wd 内存拷贝 并喂狗

## env_get_bootm_mapsize 获取RAM的映射大小
```c
phys_size_t env_get_bootm_mapsize(void)
{
	char *s = env_get("bootm_mapsize");

	if (s)
		return simple_strtoull(s, NULL, 16);

#if defined(CFG_SYS_BOOTMAPSZ)
	return CFG_SYS_BOOTMAPSZ;
#else
	return env_get_bootm_size();
#endif
}
```

## env_get_bootm_low 获取RAM的基础地址
```c
phys_addr_t env_get_bootm_low(void)
{
	char *s = env_get("bootm_low");

	if (s)
		return simple_strtoull(s, NULL, 16);

#if defined(CFG_SYS_SDRAM_BASE)
	return CFG_SYS_SDRAM_BASE;
#elif defined(CONFIG_ARM) || defined(CONFIG_MICROBLAZE) || defined(CONFIG_RISCV)
	/*
		common/board_f.c dram_init_banksize中定义为
		gd->bd->bi_dram[0].start = gd->ram_base;
		gd->bd->bi_dram[0].size = get_effective_memsize();

		dram_init -> fdtdec_setup_mem_size_base()中定义为
		gd->ram_size = (phys_size_t)(res.end - res.start + 1);
		gd->ram_base = (unsigned long)res.start;
		debug("%s: Initial DRAM size %llx\n", __func__,
			(unsigned long long)gd->ram_size);

		memory@c0000000 {
			device_type = "memory";
			reg = <0xc0000000 0x2000000>;
	};
	*/
	return gd->bd->bi_dram[0].start;
#else
	return 0;
#endif
}
```

## image_setup_linux
```c

int image_setup_linux(struct bootm_headers *images)
{
	ulong of_size = images->ft_len;
	char **of_flat_tree = &images->ft_addr;
	int ret;

	/* This function cannot be called without lmb support */
	if (!CONFIG_IS_ENABLED(LMB))
		return -EFAULT;
	if (CONFIG_IS_ENABLED(OF_LIBFDT))
		boot_fdt_add_mem_rsv_regions(*of_flat_tree);	//设置fdt保留的内存区域和fdt中指定的保留内存区域

	if (IS_ENABLED(CONFIG_SYS_BOOT_GET_CMDLINE)) {
		ret = boot_get_cmdline(&images->cmdline_start,
				       &images->cmdline_end);
		if (ret) {
			puts("ERROR with allocation of cmdline\n");
			return ret;
		}
	}

	if (CONFIG_IS_ENABLED(OF_LIBFDT)) {
		ret = boot_relocate_fdt(of_flat_tree, &of_size);	//将fdt数据移动到RAM中
		if (ret)
			return ret;
	}

	if (CONFIG_IS_ENABLED(OF_LIBFDT) && of_size) {
		ret = image_setup_libfdt(images, *of_flat_tree, true);	//将fdt转换为动态设备树
		if (ret)
			return ret;
	}

	return 0;
}
```

# image-fit.c
- FIT（Flattened Image Tree）是一种用于嵌入式系统的镜像格式，主要用于 U-Boot 引导加载程序中。FIT 镜像可以包含多个不同类型的镜像文件（如内核、设备树、RAM 磁盘等），并且可以通过配置节点来定义这些镜像文件的加载和启动方式。

- 功能
	- 多镜像支持:FIT 镜像可以包含多个不同类型的镜像文件，如内核、设备树、RAM 磁盘、固件等。
	- 配置管理:通过配置节点，可以定义不同的启动配置，选择不同的镜像文件进行加载和启动。
	- 镜像验证:支持镜像的完整性验证，通过哈希算法（如 SHA1）验证镜像文件的完整性，确保镜像文件未被篡改。
	- 灵活性:可以动态选择和加载不同的镜像文件，适应不同的启动需求。

## fit_parse_conf
## fit_parse_spec
```c
/**
 * fit_parse_conf - 解析 FIT 配置规范
 * @spec：输入字符串，包含配置规范
 * @add_curr：当前镜像地址（没有找到则使用这个地址）
 * @addr：指向 ulong 变量的指针，将保存给定的 FIT 图像地址配置
 * @conf_name指向 char 的双指针，将保存指向配置的指针单位名称
 * fit_parse_conf（） 期望 []# 形式的配置规范<addr><conf>，
 * 其中 <addr> 是包含配置的 FIT 镜像地址
 * 替换为<conf>单位名称。
 *
 * 地址部分是可选的，如果省略默认add_curr替换为 * 。
 * 返回值:成功解析到分隔符的位置返回1,否则返回0
 */
 int fit_parse_conf(const char *spec, ulong addr_curr,
		ulong *addr, const char **conf_name)
{
	return fit_parse_spec(spec,	//字符串"90080000"
							'#', addr_curr, addr, conf_name);
}
```

## fit_parse_spec 将字符串根据分隔符解析为地址和名称
```c
/* spec:需要解析的字符串
 * sepc:分隔符
 * addr_curr:当前地址
 * addr:返回的地址
 * name:返回的名称
 * 返回值:成功解析到分隔符的位置返回1,否则返回0
 */
static int fit_parse_spec(const char *spec, char sepc, ulong addr_curr,
		ulong *addr, const char **name)
```

## fit_image_load 从 FIT 加载镜像
```c
// ph_type = IH_TYPE_KERNEL
int fit_image_load(struct bootm_headers *images, ulong addr,
		   const char **fit_unamep, const char **fit_uname_configp,
		   int arch, int ph_type, int bootstage_id,
		   enum fit_load_op load_op, ulong *datap, ulong *lenp)
{
	fit = map_sysmem(addr, 0);
	fit_uname = fit_unamep ? *fit_unamep : NULL;	//请求的映像名称
	fit_uname_config = fit_uname_configp ? *fit_uname_configp : NULL;	//请求的配置名称
	fit_base_uname_config = NULL;	//基本配置名称
	//例如"kernel"
	prop_name = fit_get_image_type_property(image_type);	//获取镜像类型的属性名称
	bootstage_mark(bootstage_id + BOOTSTAGE_SUB_FORMAT);
	ret = fit_check_format(fit, IMAGE_SIZE_INVAL);			//检查 FIT 格式
	if (fit_uname) {	//如果请求的映像名称不为空
		bootstage_mark(bootstage_id + BOOTSTAGE_SUB_UNIT_NAME);
		noffset = fit_image_get_node(fit, fit_uname);
	} else {
		/*
		 * 没有镜像节点单元名称，尝试获取配置
		 * node 优先。如果配置单元节点名称为 NULL
		 * fit_conf_get_node（） 将尝试查找默认配置节点
		 */
		bootstage_mark(bootstage_id + BOOTSTAGE_SUB_NO_UNIT_NAME);
		if (ret < 0 && ret != -EINVAL)
			ret = fit_conf_get_node(fit, fit_uname_config);	//查找/configurations节点中的配置节点,默认为default的配置
		if (ret < 0) {
			puts("Could not find configuration node\n");
			bootstage_error(bootstage_id +
					BOOTSTAGE_SUB_NO_UNIT_NAME);
			return -ENOENT;
		}
		cfg_noffset = ret;

		fit_base_uname_config = fdt_get_name(fit, cfg_noffset, NULL);
		printf("   Using '%s' configuration\n", fit_base_uname_config);
		/* Remember this config */
		if (image_type == IH_TYPE_KERNEL)
			images->fit_uname_cfg = fit_base_uname_config;

		if (FIT_IMAGE_ENABLE_VERIFY && images->verify) {
			puts("   Verifying Hash Integrity ... ");
			if (fit_config_verify(fit, cfg_noffset)) {
				puts("Bad Data Hash\n");
				bootstage_error(bootstage_id +
					BOOTSTAGE_SUB_HASH);
				return -EACCES;
			}
			puts("OK\n");
		}
		bootstage_mark(BOOTSTAGE_ID_FIT_CONFIG);
		//获取镜像类型节点的偏移量	kernel:"kernel"
		noffset = fit_conf_get_prop_node(fit, cfg_noffset, prop_name,
						 image_ph_phase(ph_type));
		//获取镜像类型节点的名称
		fit_uname = fit_get_name(fit, noffset, NULL);
	}
	if (noffset < 0) {
		printf("Could not find subimage node type '%s'\n", prop_name);
		bootstage_error(bootstage_id + BOOTSTAGE_SUB_SUBNODE);
		return -ENOENT;
	}
	printf("   Trying '%s' %s subimage\n", fit_uname, prop_name);
	//bootm_start中 images.verify = env_get_yesno("verify");
	ret = fit_image_select(fit, noffset, images->verify);	//打印镜像信息,并进行完整性检查

#ifndef USE_HOSTCC
	{
	uint8_t os_arch;

	fit_image_get_arch(fit, noffset, &os_arch);
	images->os.arch = os_arch;
	}
#endif
	//检查镜像是否具有获取到的类型
	bootstage_mark(bootstage_id + BOOTSTAGE_SUB_CHECK_ALL);
	type_ok = fit_image_check_type(fit, noffset, image_type) ||
		  fit_image_check_type(fit, noffset, IH_TYPE_FIRMWARE) ||
		  fit_image_check_type(fit, noffset, IH_TYPE_TEE) ||
		  (image_type == IH_TYPE_KERNEL &&
		   fit_image_check_type(fit, noffset, IH_TYPE_KERNEL_NOLOAD));
	//os类型为linux,uboot,tee,openrtos,efi,vxworks,elf
	os_ok = image_type == IH_TYPE_FLATDT ||
		image_type == IH_TYPE_FPGA ||
		fit_image_check_os(fit, noffset, IH_OS_LINUX) ||
		fit_image_check_os(fit, noffset, IH_OS_U_BOOT) ||
		fit_image_check_os(fit, noffset, IH_OS_TEE) ||
		fit_image_check_os(fit, noffset, IH_OS_OPENRTOS) ||
		fit_image_check_os(fit, noffset, IH_OS_EFI) ||
		fit_image_check_os(fit, noffset, IH_OS_VXWORKS) ||
		fit_image_check_os(fit, noffset, IH_OS_ELF);

	bootstage_mark(bootstage_id + BOOTSTAGE_SUB_LOAD);
	*datap = load;
	*lenp = len;
	if (fit_unamep)
		*fit_unamep = (char *)fit_uname;
	if (fit_uname_configp)
		*fit_uname_configp = (char *)(fit_uname_config ? :
					      fit_base_uname_config);

	return noffset;
}
```

## fit_check_format
- 检查设备树头部
- 检查完整性
- 检查描述
- 检查时间戳
- 检查镜像节点

## fit_conf_get_node	查找配置节点
```c
/*
    configurations {
        default = "conf0";
        conf0 {
            description = "Boot Linux kernel with FDT blob";
            kernel = "kernel";
            fdt = "fdt";
            ramdisk = "ramdisk";
        };
    };
*/
int fit_conf_get_node(const void *fit, const char *conf_uname)
{
	int noffset, confs_noffset;
	int len;
	const char *s;
	char *conf_uname_copy = NULL;
	//查找/configurations节点的偏移量
	confs_noffset = fdt_path_offset(fit, FIT_CONFS_PATH);
	if (confs_noffset < 0) {
		debug("Can't find configurations parent node '%s' (%s)\n",
		      FIT_CONFS_PATH, fdt_strerror(confs_noffset));
		return confs_noffset;
	}

	if (conf_uname == NULL) {
		/* 从 default 属性获取配置单元名称 */
		debug("No configuration specified, trying default...\n");
		if (!tools_build() && IS_ENABLED(CONFIG_MULTI_DTB_FIT)) {	//多个设备树查找配置节点
			noffset = fit_find_config_node(fit);
			if (noffset < 0)
				return noffset;
			conf_uname = fdt_get_name(fit, noffset, NULL);
		} else {	//单个设备树查找配置节点
			//查找"default"属性的值
			conf_uname = (char *)fdt_getprop(fit, confs_noffset,
							 FIT_DEFAULT_PROP, &len);
			if (conf_uname == NULL) {
				fit_get_debug(fit, confs_noffset, FIT_DEFAULT_PROP,
					      len);
				return len;
			}
		}
		debug("Found default configuration: '%s'\n", conf_uname);
	}
	//处理"#"后的注释部分
	s = strchr(conf_uname, '#');
	if (s) {
		len = s - conf_uname;
		conf_uname_copy = malloc(len + 1);
		if (!conf_uname_copy) {
			debug("Can't allocate uname copy: '%s'\n",
					conf_uname);
			return -ENOMEM;
		}
		memcpy(conf_uname_copy, conf_uname, len);
		conf_uname_copy[len] = '\0';
		conf_uname = conf_uname_copy;
	}
	//查找配置单元名称的节点偏移量
	noffset = fdt_subnode_offset(fit, confs_noffset, conf_uname);
	if (noffset < 0) {
		debug("Can't get node offset for configuration unit name: '%s' (%s)\n",
		      conf_uname, fdt_strerror(noffset));
	}

	free(conf_uname_copy);

	return noffset;
}
```

## fit_image_select
- 打印镜像信息
- verify = 1,进行完整性检查
```c
//fit:FIT头指针,rd_noffset:镜像节点偏移量,verify:是否进行完整性检查
static int fit_image_select(const void *fit, int rd_noffset, int verify)
{
	fit_image_print(fit, rd_noffset, "   ");

	if (verify) {
		puts("   Verifying Hash Integrity ... ");
		if (!fit_image_verify(fit, rd_noffset)) {
			puts("Bad Data Hash\n");
			return -EACCES;
		}
		puts("OK\n");
	}

	return 0;
}
```

## fit_image_print 打印镜像信息
```c
        kernel {
            description = "Linux kernel for RT-Thread STM32H750i-ART-PI board";
            data = /incbin/("./zImage");
            type = "kernel";
            arch = "arm";
            os = "linux";
            compression = "none";
            load = <0xC0080000>;
            entry = <0xC0080000>;
            hash {
                algo = "sha1";
            };
        };
```

## fit_image_get_entry 获取镜像入口地址
## fit_image_get_address 获取镜像地址
```c
static int fit_image_get_address(const void *fit, int noffset, char *name,
			  ulong *load)
{
	int len, cell_len;
	const fdt32_t *cell;
	uint64_t load64 = 0;
	//获取长度和返回属性的指针
	cell = fdt_getprop(fit, noffset, name, &len);
	if (cell == NULL) {
		fit_get_debug(fit, noffset, name, len);
		return -1;
	}

	cell_len = len >> 2;
	//将属性值转换为地址
	while (cell_len--) {
		load64 = (load64 << 32) | uimage_to_cpu(*cell);
		cell++;
	}

	if (len > sizeof(ulong) && (uint32_t)(load64 >> 32)) {
		printf("Unsupported %s address size\n", name);
		return -1;
	}

	*load = (ulong)load64;

	return 0;
}
```

# image.c
## image_decomp 解压缩
```c
int image_decomp(int comp, ulong load, ulong image_start, int type,
		 void *load_buf, void *image_buf, ulong image_len,
		 uint unc_len, ulong *load_end)
{
	int ret = -ENOSYS;

	*load_end = load;
	//bootm_find_os images.os.load = images.os.image_start;
	//所以打印XIP
	print_decomp_msg(comp, type, load == image_start, load);

	/*
	 * 将图像加载到正确的位置，如果需要，请解压缩。后
	 * this，image_len 将设置为未压缩字节数
	 * loaded，则 ret 在出错时将为非零。
	 */
	switch (comp) {
	case IH_COMP_NONE:
		ret = 0;
		if (load == image_start)
			break;
		if (image_len <= unc_len)
			memmove_wd(load_buf, image_buf, image_len, CHUNKSZ);
		else
			ret = -ENOSPC;
		break;
	}
}
```

## print_decomp_msg
```c
/**
 * print_decomp_msg() - Print a suitable decompression/loading message
 *
 * @type:	OS type (IH_OS_...)
 * @comp_type:	Compression type being used (IH_COMP_...)
 * @is_xip:	true if the load address matches the image start
 * @load:	Load address for printing
 */
static void print_decomp_msg(int comp_type, int type, bool is_xip,
			     ulong load)
{
	const char *name = genimg_get_type_name(type);

	/* Shows "Loading Kernel Image" for example */
	if (comp_type == IH_COMP_NONE)
		printf("   %s %s", is_xip ? "XIP" : "Loading", name);
	else
		printf("   Uncompressing %s", name);

	printf(" to %lx\n", load);
}
```

# image-fdt.c
- 设备树是一种描述硬件的数据结构，它描述了硬件的组织结构、属性和连接关系。设备树通常用于嵌入式系统中，用于描述系统中的各种硬件设备，如 CPU、内存、外设等。设备树通常以 .dts（Device Tree Source）文件的形式存在，通过编译器编译成 .dtb（Device Tree Blob）文件，然后由引导加载程序加载到内存中。

## boot_fdt_add_mem_rsv_regions 设置fdt保留的内存区域和fdt中指定的保留内存区域
```c
void boot_fdt_add_mem_rsv_regions(void *fdt_blob)
{
	uint64_t addr, size;
	int i, total, ret;
	int nodeoffset, subnode;
	struct fdt_resource res;
	u32 flags;

	if (fdt_check_header(fdt_blob) != 0)
		return;

	//获取保留的内存数量
	total = fdt_num_mem_rsv(fdt_blob);
	for (i = 0; i < total; i++) {
		//获取保留的内存地址和大小
		if (fdt_get_mem_rsv(fdt_blob, i, &addr, &size) != 0)
			continue;
		//添加保留的内存区域
		boot_fdt_reserve_region(addr, size, LMB_NOOVERWRITE);
	}
	/* process reserved-memory */
	/*
		reserved-memory {
		#address-cells = <1>;
		#size-cells = <1>;
		ranges;

		linux,cma {
			compatible = "shared-dma-pool";
			no-map;
			size = <0x100000>;
			linux,dma-default;
		};
	};
	*/
	nodeoffset = fdt_subnode_offset(fdt_blob, 0, "reserved-memory");
	if (nodeoffset >= 0) {
		subnode = fdt_first_subnode(fdt_blob, nodeoffset);
		while (subnode >= 0) {
			/* check if this subnode has a reg property */
			ret = fdt_get_resource(fdt_blob, subnode, "reg", 0,
					       &res);
			if (!ret && fdtdec_get_is_enabled(fdt_blob, subnode)) {
				flags = LMB_NOOVERWRITE;
				if (fdtdec_get_bool(fdt_blob, subnode,
						    "no-map"))
					flags = LMB_NOMAP;
				addr = res.start;
				size = res.end - res.start + 1;
				boot_fdt_reserve_region(addr, size, flags);
			}

			subnode = fdt_next_subnode(fdt_blob, subnode);
		}
	}
}
```

## boot_relocate_fdt	将fdt数据移动到RAM中
```c
int boot_relocate_fdt(char **of_flat_tree, ulong *of_size)
{
	u64	start, size, usable, addr, low, mapsize;
	void	*fdt_blob = *of_flat_tree;
	void	*of_start = NULL;
	char	*fdt_high;
	ulong	of_len = 0;
	int	bank;
	int	err;
	int	disable_relocation = 0;

	/* nothing to do */
	if (*of_size == 0)
		return 0;

	if (fdt_check_header(fdt_blob) != 0) {
		fdt_error("image is not a fdt");
		goto error;
	}

	/* position on a 4K boundary before the alloc_current */
	/* Pad the FDT by a specified amount */
	/* 
		CONFIG_SYS_FDT_PAD 可能用于指定设备树在内存中预留的填充空间（padding）。
		填充空间的作用是为设备树的动态修改预留额外的内存，
		以便在运行时可以添加或修改设备树节点和属性，
		而不需要重新分配内存或移动设备树的位置。
	*/
	of_len = *of_size + CONFIG_SYS_FDT_PAD;


	/* If fdt_high is set use it to select the relocation address */
	fdt_high = env_get("fdt_high");
	if (fdt_high) {	//尝试使用env的fdt_high

	} else {	//通过fdt的内存映射大小和基础地址计算fdt的地址
		mapsize = env_get_bootm_mapsize();
		low = env_get_bootm_low();
		of_start = NULL;

		for (bank = 0; bank < CONFIG_NR_DRAM_BANKS; bank++) {
			start = gd->bd->bi_dram[bank].start;
			size = gd->bd->bi_dram[bank].size;

			/* DRAM bank addresses are too low, skip it. */
			if (start + size < low)
				continue;

			//计算已用空间;是当前分配掉的空间更小,使用当前分配掉的空间继续分配
			//否则使用当前DRAM的空间
			//如果当前 DRAM 银行的结束地址大于或等于 low，则至少有一部分地址范围在 low 以上。在这种情况下，代码计算可用的地址范围 usable，并尝试从这个范围中分配内存块。
			usable = min(start + size, low + mapsize);
			addr = lmb_alloc_base(of_len, 0x1000, usable, LMB_NONE);
			of_start = map_sysmem(addr, of_len);
			/* Allocation succeeded, use this block. */
			if (of_start != NULL)
				break;

			//如果当前DRAM的空间不够,则继续分配下一个DRAM的空间
			mapsize -= usable - max(start, low);
			if (!mapsize)
				break;
		}
	}

	if (disable_relocation) {

	} else {
		debug("## device tree at %p ... %p (len=%ld [0x%lX])\n",
		      fdt_blob, fdt_blob + *of_size - 1, of_len, of_len);

		printf("   Loading Device Tree to %p, end %p ... ",
		       of_start, of_start + of_len - 1);

		err = fdt_open_into(fdt_blob, of_start, of_len);	//将fdt_blob移动到of_start
		if (err != 0) {
			fdt_error("fdt move failed");
			goto error;
		}
		puts("OK\n");
	}

	*of_flat_tree = of_start;
	*of_size = of_len;

	if (IS_ENABLED(CONFIG_CMD_FDT))
		//设置fdt的地址
		set_working_fdt_addr(map_to_sysmem(*of_flat_tree));
	return 0;

error:
	return 1;
}
```

## fdt_root 检测fdt头部,将环境变量中serial#设置到fdt中
```c
int fdt_root(void *fdt)
{
	char *serial;
	int err;

	err = fdt_check_header(fdt);
	if (err < 0) {
		printf("fdt_root: %s\n", fdt_strerror(err));
		return err;
	}

	serial = env_get("serial#");	//获取环境变量serial#的值
	if (serial) {
		//获取serial成功后设置设备树属性
		err = fdt_setprop(fdt, 0, "serial-number", serial,
				  strlen(serial) + 1);

		if (err < 0) {
			printf("WARNING: could not set serial-number %s.\n",
			       fdt_strerror(err));
			return err;
		}
	}

	return 0;
}
```

## fdt_chosen 创建/chosen节点,添加bootargs属性和rng-seed属性,u-boot版本号,bootargs属性
```c
/**
 * board_fdt_chosen_bootargs - 板子可以覆盖此函数以使用替代内核命令行参数
 * 默认将env的bootargs设置到fdt中
 */
__weak const char *board_fdt_chosen_bootargs(const struct fdt_property *fdt_ba)
{
	return env_get("bootargs");
}

int fdt_chosen(void *fdt)
{
	struct abuf buf = {};
	int   nodeoffset;
	int   err;
	const char *str;		/* used to set string properties */

	err = fdt_check_header(fdt);
	if (err < 0) {
		printf("fdt_chosen: %s\n", fdt_strerror(err));
		return err;
	}

	/* 查找或创建 “/Chosen” 节点。 */
	nodeoffset = fdt_find_or_add_subnode(fdt, 0, "chosen");
	if (nodeoffset < 0)
		return nodeoffset;

	//设置rng-seed属性
	if (IS_ENABLED(CONFIG_BOARD_RNG_SEED) && !board_rng_seed(&buf)) {
		err = fdt_setprop(fdt, nodeoffset, "rng-seed",
				  abuf_data(&buf), abuf_size(&buf));
		abuf_uninit(&buf);
		if (err < 0) {
			printf("WARNING: could not set rng-seed %s.\n",
			       fdt_strerror(err));
			return err;
		}
	}

	//设置bootargs属性 将env的bootargs设置到fdt中
	str = board_fdt_chosen_bootargs(fdt_get_property(fdt, nodeoffset,
							 "bootargs", NULL));

	if (str) {
		err = fdt_setprop(fdt, nodeoffset, "bootargs", str,
				  strlen(str) + 1);
		if (err < 0) {
			printf("WARNING: could not set bootargs %s.\n",
			       fdt_strerror(err));
			return err;
		}
	}

	/* 添加 u-boot 版本 */
	err = fdt_setprop(fdt, nodeoffset, "u-boot,version", PLAIN_VERSION,
			  strlen(PLAIN_VERSION) + 1);
	if (err < 0) {
		printf("WARNING: could not set u-boot,version %s.\n",
		       fdt_strerror(err));
		return err;
	}

	return fdt_fixup_stdout(fdt, nodeoffset);
}
```

## image_setup_libfdt 将fdt转换为动态设备树,并设置相关属性到fdt中
```c
int image_setup_libfdt(struct bootm_headers *images, void *blob, bool lmb)
{
	ret = -EPERM;
	//检测fdt头部,设置serial#属性
	if (fdt_root(blob) < 0) {	
		printf("ERROR: root node setup failed\n");
		goto err;
	}
	// 创建/chosen节点,添加bootargs属性和rng-seed属性,u-boot版本号,bootargs属性
	if (fdt_chosen(blob) < 0) {
		printf("ERROR: /chosen node create failed\n");
		goto err;
	}
	if (arch_fixup_fdt(blob) < 0) {
		printf("ERROR: arch-specific fdt fixup failed\n");
		goto err;
	}

	fdt_ret = optee_copy_fdt_nodes(blob);
	if (fdt_ret) {
		printf("ERROR: transfer of optee nodes to new fdt failed: %s\n",
		       fdt_strerror(fdt_ret));
		goto err;
	}

	/* 将配置节点的名称存储为 u-boot，bootconf 在 /chosen 节点中 */
	if (images->fit_uname_cfg)
		fdt_find_and_setprop(blob, "/chosen", "u-boot,bootconf",
					images->fit_uname_cfg,
					strlen(images->fit_uname_cfg) + 1, 1);
	//在 /chosen 节点中设置ramdisk的开始和结束地址
	if (fdt_initrd(blob, *initrd_start, *initrd_end))
		goto err;

	// 转换FDT为动台设备树
	if (!of_live_active() && CONFIG_IS_ENABLED(EVENT)) {
		struct event_ft_fixup fixup;

		fixup.tree = oftree_from_fdt(blob);
		fixup.images = images;
		if (oftree_valid(fixup.tree)) {
			ret = event_notify(EVT_FT_FIXUP, &fixup, sizeof(fixup));
			if (ret) {
				printf("ERROR: fdt fixup event failed: %d\n",
				       ret);
				goto err;
			}
		}
	}

	/* Delete the old LMB reservation */
	if (CONFIG_IS_ENABLED(LMB) && lmb)
		lmb_free(map_to_sysmem(blob), fdt_totalsize(blob));

	ret = fdt_shrink_to_minimum(blob, 0);	//fdt转换为空的fdt
	if (ret < 0)
		goto err;
	of_size = ret;

	/* Create a new LMB reservation */
	if (CONFIG_IS_ENABLED(LMB) && lmb)	//将新的fdt空间设置为保留
		lmb_reserve(map_to_sysmem(blob), of_size, LMB_NONE);

	return 0;
err:
	printf(" - must RESET the board to recover.\n\n");

	return ret;
}
```
