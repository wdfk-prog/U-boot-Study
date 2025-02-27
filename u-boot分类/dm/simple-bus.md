[TOC]

# simple-bus

# 驱动信息 在重定向之前调用
```c
UCLASS_DRIVER(simple_bus) = {
	.id		= UCLASS_SIMPLE_BUS,
	.name		= "simple_bus",
	.post_bind	= simple_bus_post_bind,
	.per_device_plat_auto	= sizeof(struct simple_bus_plat),
};

#if CONFIG_IS_ENABLED(OF_REAL)
static const struct udevice_id generic_simple_bus_ids[] = {
	{ .compatible = "simple-bus" },
	{ .compatible = "simple-mfd" },
	{ }
};
#endif

U_BOOT_DRIVER(simple_bus) = {
	.name	= "simple_bus",
	.id	= UCLASS_SIMPLE_BUS,
	.of_match = of_match_ptr(generic_simple_bus_ids),
	.flags	= DM_FLAG_PRE_RELOC,
};
```

# simple_bus_post_bind
```c
static int simple_bus_post_bind(struct udevice *dev)
{
#if CONFIG_IS_ENABLED(OF_PLATDATA)
	return 0;
#else
	struct simple_bus_plat *plat = dev_get_uclass_plat(dev);
	int ret;

	if (CONFIG_IS_ENABLED(SIMPLE_BUS_CORRECT_RANGE)) {
		uint64_t caddr, paddr, len;

		/* only read range index 0 */
		ret = fdt_read_range((void *)gd->fdt_blob, dev_of_offset(dev),
				     0, &caddr, &paddr, &len);
		if (!ret) {
			plat->base = caddr;
			plat->target = paddr;
			plat->size = len;
		}
	} else {
		u32 cell[3];

		ret = dev_read_u32_array(dev, "ranges", cell,
					 ARRAY_SIZE(cell));
		if (!ret) {
			plat->base = cell[0];
			plat->target = cell[1];
			plat->size = cell[2];
		}
	}

	return dm_scan_fdt_dev(dev);
#endif
}
```
- 可以发现执行`dm_scan_fdt_dev`,扫描当前节点下的子节点绑定到当前设备上

```c
	//设备树内容如下
	soc {
		#address-cells = <0x01>;
		#size-cells = <0x01>;
		compatible = "simple-bus";
		interrupt-parent = <0x01>;
		ranges;
		bootph-all;
	}
```
