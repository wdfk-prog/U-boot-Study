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

	if (!ret && (states & BOOTM_STATE_FINDOS))
		ret = bootm_find_os(bmi->cmd_name, bmi->addr_img);//字符串"90080000"
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
	switch (genimg_get_format(buf)) {

	}
}
```
