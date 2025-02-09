[TOC]

# syscon - System Controller 系统控制器
-  Kconfig
    ```C
    config REGMAP
	bool "Support register maps"
	depends on DM
	/*help
	  硬件外设往往有一组或多组 registers可以访问它来控制硬件。A 寄存器映射使用简单的读/写接口对此进行建模。
      原则上可以支持任何总线类型（I2C、SPI）、但到目前为止这仅支持直接内存访问。
    */

    config SYSCON
	bool "Support system controllers"
	depends on REGMAP
	/*help
        许多 SoC 有许多系统控制器需要处理.作为一个组。提供了一些常见的功能. 通过这个 uclass，包括通过 regmap 和 每个 Cookie 分配一个唯一的编号。
    */
    ```

# DTS
```c
soc {
    #address-cells = <0x01>;
    #size-cells = <0x01>;
    compatible = "simple-bus";
    interrupt-parent = <0x01>;
    ranges;
    bootph-all;

    syscon@58000400 {
        compatible = "st,stm32-syscfg\0syscon";
        reg = <0x58000400 0x400>;
        phandle = <0x1c>;
    };
}
```

# syscon-uclass.c
## 驱动信息 需要匹配syscon
```c
UCLASS_DRIVER(syscon) = {
	.id		= UCLASS_SYSCON,
	.name		= "syscon",
	.per_device_auto	= sizeof(struct syscon_uc_info),
	.pre_probe = syscon_pre_probe,
};

static const struct udevice_id generic_syscon_ids[] = {
	{ .compatible = "syscon" },
	{ }
};

U_BOOT_DRIVER(generic_syscon) = {
	.name	= "syscon",
	.id	= UCLASS_SYSCON,
#if CONFIG_IS_ENABLED(OF_REAL)
	.bind           = dm_scan_fdt_dev,
#endif
	.of_match = generic_syscon_ids,
};
```

## bind (dm_scan_fdt_dev)
- 绑定FDT当前节点下的所有子节点设备

## syscon_pre_probe
```c
static int syscon_pre_probe(struct udevice *dev)
{
	struct syscon_uc_info *priv = dev_get_uclass_priv(dev);
	return regmap_init_mem(dev_ofnode(dev), &priv->regmap); //初始化寄存器映射
}
```

# regmap.c 寄存器映射
## regmap_init_mem 
```c
int regmap_init_mem(ofnode node, struct regmap **mapp)
{
	ofnode parent;
	struct regmap_range *range;
	struct regmap *map;
	int count;
	int addr_len, size_len, both_len;
	int len;
	int index;
	int ret;

	parent = ofnode_get_parent(node);
    //读取syscon节点的父节点的#address-cells属性值,根据示例dts,这里是soc的#address-cells属性值为1
	addr_len = ofnode_read_simple_addr_cells(parent);
    //读取syscon节点的父节点的#size-cells属性值,根据示例dts,这里是soc的#size-cells属性值为1
	size_len = ofnode_read_simple_size_cells(parent);
	both_len = addr_len + size_len;         //both_len = 2
	len = ofnode_read_size(node, "reg");    //LEN = 0x400
	len /= sizeof(fdt32_t);                 //len = 0x100
	count = len / both_len;                 //计算地址和大小对的数量 = 0x80
	map = regmap_alloc(count);              //分配地址对空间+头部信息空间
    //遍历地址对,初始化地址对信息
	for (range = map->ranges, //range指向map的地址对信息
        index = 0; count > 0;
	     count--, range++, index++) {
		ret = init_range(node, range, addr_len, size_len, index);
		if (ret)
			goto err;
	}

	if (ofnode_read_bool(node, "little-endian"))
		map->endianness = REGMAP_LITTLE_ENDIAN;
	else if (ofnode_read_bool(node, "big-endian"))
		map->endianness = REGMAP_BIG_ENDIAN;
	else if (ofnode_read_bool(node, "native-endian"))
		map->endianness = REGMAP_NATIVE_ENDIAN;
	else /* Default: native endianness */
		map->endianness = REGMAP_NATIVE_ENDIAN;

	*mapp = map;

	return 0;
}
```

## regmap_alloc 分配头部存储空间+地址大小对存储空间
```c
static struct regmap *regmap_alloc(int count)
{
	struct regmap *map;
    //计算头部信息大小与分配的空间大小
	size_t size = sizeof(*map) + sizeof(map->ranges[0]) * count;

	map = calloc(1, size);
	if (!map)
		return NULL;
	map->range_count = count;
	map->width = REGMAP_SIZE_32;

	return map;
}
```

## init_range 初始化地址对信息,设置地址和大小
```c
static int init_range(ofnode node, struct regmap_range *range, int addr_len,
		      int size_len, int index)
{
	fdt_size_t sz;
	struct resource r;

    int offset = ofnode_to_offset(node);
    //根据当前节点的reg的属性值,通过index确定第几个地址对,获取地址和大小
    range->start = fdtdec_get_addr_size_fixed(gd->fdt_blob, 
                            offset,
                            "reg", 
                            index,              //第几个地址对
                            addr_len, size_len, //确定是32位还是64位
                            &sz, true);
    range->size = sz;

	return 0;
}
```