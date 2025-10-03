---
title: bootz
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
[TOC]

# bootz
```c
U_BOOT_LONGHELP(bootz,
	"[addr [initrd[:size]] [fdt]]\n"
	"    - boot Linux zImage stored in memory\n"
	"\tThe argument 'initrd' is optional and specifies the address\n"
	"\tof the initrd in memory. The optional argument ':size' allows\n"
	"\tspecifying the size of RAW initrd.\n"
#if defined(CONFIG_OF_LIBFDT)
	"\tWhen booting a Linux kernel which requires a flat device-tree\n"
	"\ta third argument is required which is the address of the\n"
	"\tdevice-tree blob. To boot that kernel without an initrd image,\n"
	"\tuse a '-' for the second argument. If you do not pass a third\n"
	"\ta bd_info struct will be passed instead\n"
#endif
	);

U_BOOT_CMD(
	bootz,	CONFIG_SYS_MAXARGS,	1,	do_bootz,
	"boot Linux zImage image from memory", bootz_help_text
);
```

# do_bootz
1. bootz_start
2. bootz_run    //boot_run(bmi, "bootz", 0);

# bootz_start
1. bootz_setup

# arch/arm/lib/zimage.c
```c
#define	LINUX_ARM_ZIMAGE_MAGIC	0x016f2818
#define	BAREBOX_IMAGE_MAGIC	0x00786f62

struct arm_z_header {
	uint32_t	code[9];
	uint32_t	zi_magic;
	uint32_t	zi_start;
	uint32_t	zi_end;
} __attribute__ ((__packed__));

int bootz_setup(ulong image, ulong *start, ulong *end)
{
	struct arm_z_header *zi = (struct arm_z_header *)image;

	if (zi->zi_magic != LINUX_ARM_ZIMAGE_MAGIC &&
	    zi->zi_magic != BAREBOX_IMAGE_MAGIC) {
		if (!IS_ENABLED(CONFIG_XPL_BUILD))
			puts("zimage: Bad magic!\n");
		return 1;
	}

	*start = zi->zi_start;
	*end = zi->zi_end;
	if (!IS_ENABLED(CONFIG_XPL_BUILD))
		printf("Kernel image @ %#08lx [ %#08lx - %#08lx ]\n",
		       image, *start, *end);

	return 0;
}
```

```shell
# zImage
af f3 00 80 
af f3 00 80 
af f3 00 80 
af f3 00 80
af f3 00 80 
af f3 00 80 
af f3 00 80 
af f3 00 80	
00 f0 0c b8 # code[0] - code[9]
18 28 6f 01 # LINUX_ARM_ZIMAGE_MAGIC
00 00 00 00 # zi_start
d0 a9 15 00 # zi_end 0x000015a9d0 = 1419728 = 1.35M
```