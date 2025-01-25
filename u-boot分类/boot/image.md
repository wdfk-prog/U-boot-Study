# boot/image-board.c
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

# boot/image-fit.c
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
