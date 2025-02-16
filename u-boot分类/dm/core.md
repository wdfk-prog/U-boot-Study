[TOC]
# 驱动初始化及绑定与探测流程
1. 存储在段中的驱动设备信息
2. 初始化驱动模型结构,初始化根节点
3. 从FDT中扫描设备并绑定到根节点
4. 绑定后分配设备私有数据大小,与注册设备数据`driver_data`
5. 绑定设备到父设备与uclass上
6. 绑定后探测根节点下的子设备和子设备的子设备
- 总结如下:
	- 扫描FDT的设备并与driver的compatible匹配后,进行绑定与挂载到父设备与根节点上
	- 使用malloc分配设备使用的私有数据,并设置设备的driver_data
	- 绑定后执行设备识别`device_probe`函数,顺序根据注册的顺序执行,注册顺序为FDT节点的顺序;1
- 设备绑定分为重定向之前绑定和重定向之后绑定,
	1. 重定向之前需要绑定的设备FDT节点中需要具有`bootph-all`或`bootph-some-ram`,`bootph-pre-ram`,`bootph-pre-sram`属性,且设备驱动信息flag中需要有`DM_FLAG_PRE_RELOC`标志
	2. 否则都是重定向之后绑定

## dm_init_and_scan
### dm_init 初始化驱动模型结构,初始化根节点
### dm_scan 设备扫描并绑定到根节点
#### dm_scan_plat 绑定段中的driver_info
```c
U_BOOT_DRVINFOS(lpc32xx_uarts) = {
	{ "ns16550_serial", &lpc32xx_uart[0], },
	{ "ns16550_serial", &lpc32xx_uart[1], },
	{ "ns16550_serial", &lpc32xx_uart[2], },
	{ "ns16550_serial", &lpc32xx_uart[3], },
};
U_BOOT_DRVINFO(button_kbd) = {
	.name = "button_kbd"
};
```
#### dm_extended_scan 从FDT中扫描设备并绑定到根节点
##### dm_scan_fdt 从FDT的每个节点获取compatible信息并与段中的driver结构体的of_match信息匹配,进而绑定设备
- 调用`lists_bind_fdt`,进行绑定
- 扫描FDT中的节点并根据节点属性; 注意节点若具有`satus`属性,则值为`ok`,则才会绑定设备
- 匹配FDT中的`compatible`字符串和段中的`of_match`信息
	```c
	//dts 匹配完全"st,stm32h743-rcc"
	static const struct udevice_id stm32_rcc_ids[] = {
		{.compatible = "st,stm32f42xx-rcc", .data = (ulong)&stm32_rcc_clk_f42x },
		{.compatible = "st,stm32f469-rcc", .data = (ulong)&stm32_rcc_clk_f469 },
		{.compatible = "st,stm32f746-rcc", .data = (ulong)&stm32_rcc_clk_f7 },
		{.compatible = "st,stm32h743-rcc", .data = (ulong)&stm32_rcc_clk_h7 },
		{.compatible = "st,stm32mp1-rcc", .data = (ulong)&stm32_rcc_clk_mp1 },
		{.compatible = "st,stm32mp1-rcc-secure", .data = (ulong)&stm32_rcc_clk_mp1 },
		{.compatible = "st,stm32mp13-rcc", .data = (ulong)&stm32_rcc_clk_mp13 },
		{ }
	};

	reset-clock-controller@58024400 {
		compatible = "st,stm32h743-rcc\0st,stm32-rcc";
		reg = <0x58024400 0x400>;
		#clock-cells = <0x01>;
		#reset-cells = <0x01>;
		clocks = <0x18 0x19 0x1a>;
		st,syscfg = <0x17>;
		bootph-all;
		phandle = <0x02>;
	};
	```
- 与段中的driver结构体的of_match信息匹配,进而绑定设备
- `device_bind_with_driver_data`绑定设备到父节点并传入驱动数据`driver_data`,分配设备私有数据的空间大小,绑定fdt的node信息
- 并且与uclass,与父设备进行绑定
- 将初始化的name替换为FDT中的name

##### dm_scan_fdt_ofnode_path 扫描`chosen`、`clocks`、`firmware`、`reserved-memory`节点并绑定设备到根节点
#### dm_scan_other boot/bootstd-uclass.c ,用于bootmethod
## dm_autoprobe 绑定后探测根节点下的子设备和子设备的子设备

## device flag 说明
```c
// probe 后设置,表示设备已经激活
#define DM_FLAG_ACTIVATED		(1 << 0)

// 表示是 malloc 分配的设备私有数据,需要在设备移除时释放
#define DM_FLAG_ALLOC_PDATA		(1 << 1)

// 表示设备在重定位之前绑定,没有这个标志的设备在重定位之后绑定
#define DM_FLAG_PRE_RELOC		(1 << 2)

// DM 负责分配和释放父设备的平台数据
#define DM_FLAG_ALLOC_PARENT_PDATA	(1 << 3)

// DM 负责分配和释放 uclass 的平台数据
#define DM_FLAG_ALLOC_UCLASS_PDATA	(1 << 4)

// 分配私有 DMA 数据
#define DM_FLAG_ALLOC_PRIV_DMA		(1 << 5)

// 设备已经绑定
#define DM_FLAG_BOUND			(1 << 6)

// 设备名字是通过 malloc 分配的
#define DM_FLAG_NAME_ALLOCED		(1 << 7)

/* 设备具有由 of-platdata 提供的平台数据*/
#define DM_FLAG_OF_PLATDATA		(1 << 8)

// 设备具有活动 DMA
#define DM_FLAG_ACTIVE_DMA		(1 << 9)

/** 调用驱动 remove 函数做一些最后的配置，之前
 * U-Boot 退出并启动作系统
 */
#define DM_FLAG_OS_PREPARE		(1 << 10)

/* DM 不会启用/禁用与此设备对应的电源域 */
#define DM_FLAG_DEFAULT_PD_CTRL_OFF	(1 << 11)

/* Driver plat 有效。移除设备时清除 */
#define DM_FLAG_PLATDATA_VALID		(1 << 12)

/*
 * 设备被移除，但未关闭其电源域。这可能会
 * 是必需的，即用于引导作系统时的串行控制台 （debug） 输出。
 */
#define DM_FLAG_LEAVE_PD_ON		(1 << 13)

/*
 * 设备对其他设备的运行至关重要。可以删除
 * 在移除所有常规设备后删除此设备。这很有用
 * 例如，对于 clock，它需要在设备删除阶段处于活动状态。
 */
#define DM_FLAG_VITAL			(1 << 14)

/* 设备绑定后必须探测 */
#define DM_FLAG_PROBE_AFTER_BIND	(1 << 15)

/*
 * 这些标志中的一个或多个被传递给 device_remove（），以便
 * 由 remove-stage 指定的选择性设备删除，并且
 * 可以进行驱动程序标记。
 *
 * 不要在驱动程序的 @flags 值中使用这些标志...
 * 使用上述DM_FLAG_...值
 */
enum {
	/* 正常删除、删除所有设备*/
	DM_REMOVE_NORMAL	= 1 << 0,

	/* 删除具有活动 DMA 的设备*/
	DM_REMOVE_ACTIVE_DMA	= DM_FLAG_ACTIVE_DMA,

	/* 删除需要一些最终 OS 准备步骤的设备*/
	DM_REMOVE_OS_PREPARE	= DM_FLAG_OS_PREPARE,

	/* 仅删除未标记为 Vital 的设备 */
	DM_REMOVE_NON_VITAL	= DM_FLAG_VITAL,

	/* Remove devices with any active flag */
	DM_REMOVE_ACTIVE_ALL	= DM_REMOVE_ACTIVE_DMA | DM_REMOVE_OS_PREPARE,

	/*不要关闭任何连接的电源域*/
	DM_REMOVE_NO_PD		= 1 << 1,
};
```

# 驱动卸载流程
## bootm时跳转前执行
- arch/arm/lib/bootm.c -> announce_and_cleanup() -> dm_remove_devices_active
## dm_remove_devices_active 移除所有激活的设备
## device_remove

# initf_dm
```c
static int initf_dm(void)
{
	int ret;

	if (!CONFIG_IS_ENABLED(SYS_MALLOC_F))
		return 0;
	//初始化根节点设备并扫描设备绑定到根节点
	ret = dm_init_and_scan(true);
	if (ret)
		return ret;

	ret = dm_autoprobe();	//绑定后探测根节点下的子设备
	if (ret)
		return ret;

	if (IS_ENABLED(CONFIG_TIMER_EARLY)) {
		ret = dm_timer_init();	//初始化定时器
		if (ret)
			return ret;
	}

	return 0;
}
```

# root.c
## root_driver & root
```c
/* This is the root driver - all drivers are children of this */
U_BOOT_DRIVER(root_driver) = {
	.name	= "root_driver",
	.id	= UCLASS_ROOT,
	ACPI_OPS_PTR(&root_acpi_ops)
};

/* This is the root uclass */
UCLASS_DRIVER(root) = {
	.name	= "root",
	.id	= UCLASS_ROOT,
};
```

## dm_init_and_scan
```c
/**
 * dm_init_and_scan（） - 初始化驱动程序模型结构并扫描设备
 *
 * 此函数初始化驱动程序树和 uclass 树的根，
 * 然后扫描并绑定来自平台数据和 FDT 的可用设备。
 * 这将调用 dm_init（） 来设置驱动程序模型结构。
 *
 * @pre_reloc_only： 如果为 true，则仅绑定具有特殊 devicetree 属性的节点，
 * 或带有 DM_FLAG_PRE_RELOC 标志的驱动程序。如果为 false，则绑定所有驱动程序。
 * 返回：OK 时为 0，出错时为 -ve
 */
int dm_init_and_scan(bool pre_reloc_only)
{
	int ret;

	ret = dm_init(CONFIG_IS_ENABLED(OF_LIVE));	//初始化驱动模型结构,初始化根节点
	if (!CONFIG_IS_ENABLED(OF_PLATDATA_INST)) {
		ret = dm_scan(pre_reloc_only);			//扫描设备并绑定到根节点
	}
	if (CONFIG_IS_ENABLED(DM_EVENT)) {
		ret = event_notify_null(gd->flags & GD_FLG_RELOC ?
					EVT_DM_POST_INIT_R :
					EVT_DM_POST_INIT_F);
		if (ret)
			return log_msg_ret("ev", ret);
	}

	return 0;
}
```

## dm_init 初始化驱动模型结构
```c
/**
 * dm_init（） - 初始化驱动模型结构
 *
 * 此函数将初始化驱动程序树和类树的根。
 * 这需要在使用 DM 之前调用
 *
 * @of_live：启用 Live 设备树
 * 返回：OK 时为 0，出错时为 -ve
 */
int dm_init(bool of_live)
{
	int ret;

	if (CONFIG_IS_ENABLED(OF_PLATDATA_INST)) {
		gd->uclass_root = &uclass_head;
	} else {
		//初始化uclass根
		gd->uclass_root = &DM_UCLASS_ROOT_S_NON_CONST;
		INIT_LIST_HEAD(DM_UCLASS_ROOT_NON_CONST);
	}

	if (CONFIG_IS_ENABLED(OF_PLATDATA_INST)) {
		ret = dm_setup_inst();
		if (ret) {
			log_debug("dm_setup_inst() failed: %d\n", ret);
			return ret;
		}
	} else {
		//绑定root_info,并将指向绑定设备的指针返回到DM_ROOT_NON_CONST
		ret = device_bind_by_name(NULL, false, &root_info,
					  &DM_ROOT_NON_CONST);
		if (ret)
			return ret;
		if (CONFIG_IS_ENABLED(OF_CONTROL))
			dev_set_ofnode(DM_ROOT_NON_CONST, ofnode_root());	//设置根节点
		ret = device_probe(DM_ROOT_NON_CONST);	//探测设备
		if (ret)
			return ret;
	}
}
```

## dm_scan 设备扫描
```c
static int dm_scan(bool pre_reloc_only)
{
	int ret;

	ret = dm_scan_plat(pre_reloc_only);	//绑定段中的driver_info
	if (CONFIG_IS_ENABLED(OF_REAL)) {
		ret = dm_extended_scan(pre_reloc_only);	//从FDT中扫描设备并绑定到根节点
	}
	//boot/bootstd-uclass.c ,用于bootmethod
	ret = dm_scan_other(pre_reloc_only); //弱定义函数，扫描其他设备

	return 0;
}
```

## dm_scan_plat 扫描段中的设备,绑定driver_info
```c
int dm_scan_plat(bool pre_reloc_only)
{
	ret = lists_bind_drivers(DM_ROOT_NON_CONST, pre_reloc_only);
}
```

## dm_autoprobe	绑定后探测根节点下的子设备和子设备的子设备
## dm_probe_devices 绑定后探测节点下的子设备和子设备的子设备
```c
static int dm_probe_devices(struct udevice *dev)
{
	struct udevice *child;

	if (dev_get_flags(dev) & DM_FLAG_PROBE_AFTER_BIND) {	//设备具有DM_FLAG_PROBE_AFTER_BIND标志，将在绑定后探测设备
		int ret;

		ret = device_probe(dev);
		if (ret)
			return ret;
	}

	//扫描所有设备进行探测
	list_for_each_entry(child, &dev->child_head, sibling_node)
		dm_probe_devices(child);	//再次调用探测设备,递归探测执行所有子节点

	return 0;
}
```

## dm_extended_scan 从FDT中扫描设备并绑定到根节点
```c
int dm_extended_scan(bool pre_reloc_only)
{
	int ret, i;
	const char * const nodes[] = {
		"/chosen",
		"/clocks",
		"/firmware",
		"/reserved-memory",
	};
	//扫描FDT中的节点并根据节点属性compatible信息匹配,绑定设备; 注意节点若具有`satus`属性,则值为`ok`,则才会绑定设备
	ret = dm_scan_fdt(pre_reloc_only);	//扫描FDT中的设备并绑定到根节点

	/* 有些节点本身不是设备，但可能包含一些驱动*/
	for (i = 0; i < ARRAY_SIZE(nodes); i++) {
		ret = dm_scan_fdt_ofnode_path(nodes[i], pre_reloc_only);
	}

	return ret;
}
```

## dm_scan_fdt 扫描FDT中的设备并绑定到根节点
## dm_scan_fdt_node 扫描FDT中的节点并根据节点compatible信息匹配,绑定设备
- 注意节点若具有`satus`属性,则值为`ok`,则才会绑定设备
```c
static int dm_scan_fdt_node(struct udevice *parent, ofnode parent_node,
			    bool pre_reloc_only)
{
	int ret = 0, err = 0;
	ofnode node;

	for (node = ofnode_first_subnode(parent_node);	//获取第一个子节点
	     ofnode_valid(node);						//判断节点是否有效
	     node = ofnode_next_subnode(node)) {		//获取下一个子节点
		const char *node_name = ofnode_get_name(node);

		if (!ofnode_is_enabled(node)) {				//设备树中节点属性status=ok
			pr_debug("   - ignoring disabled device\n");
			continue;
		}
		//从FDT的每个节点获取compatible信息并与段中的driver结构体的of_match信息匹配,进而绑定设备
		err = lists_bind_fdt(parent, node, NULL, NULL, pre_reloc_only);

	}
	return ret;
}
```

## ## dm_remove_devices_active 移除所有激活的设备
```c
void dm_remove_devices_active(void)
{
	/* Remove non-vital devices first */
	device_remove(dm_root(), DM_REMOVE_ACTIVE_ALL | DM_REMOVE_NON_VITAL);
	device_remove(dm_root(), DM_REMOVE_ACTIVE_ALL);
}
```

# device.c

## udevice 驱动程序实例
- 函数包含有关设备的信息，该设备是绑定到特定端口或外围设备（本质上是一个驱动程序实例）
- 包含节点,序列号

## driver 功能或外围设备的驱动程序
- 此字段包含设置新设备和删除新设备的方法。设备需要信息来设置自身 
- 驱动程序都属于一个 uclass，代表相同类型。

## device_bind_by_name 通过名字绑定设备
```c
int device_bind_by_name(struct udevice *parent, bool pre_reloc_only,
			const struct driver_info *info, struct udevice **devp)
{
	struct driver *drv;
	uint plat_size = 0;
	int ret;
	//根据名字在段里面查找驱动
	drv = lists_driver_lookup_name(info->name);
	if (!drv)
		return -ENOENT;
	if (pre_reloc_only && !(drv->flags & DM_FLAG_PRE_RELOC))
		return -EPERM;

#if CONFIG_IS_ENABLED(OF_PLATDATA)
	plat_size = info->plat_size;
#endif
	ret = device_bind_common(parent, drv, info->name, (void *)info->plat, 0,
				 ofnode_null(), plat_size, devp);
	if (ret)
		return ret;

	return ret;
}
```

## device_bind_common 绑定设备
```c
static int device_bind_common(struct udevice *parent, const struct driver *drv,
			      const char *name, void *plat,
			      ulong driver_data, ofnode node,
			      uint of_plat_size, struct udevice **devp)
{
	struct udevice *dev;
	struct uclass *uc;
	int size, ret = 0;
	bool auto_seq = true;
	void *ptr;

	//根据drv->id在段中找到对应的uclass
	ret = uclass_get(drv->id, &uc);
	dev = calloc(1, sizeof(struct udevice));

	INIT_LIST_HEAD(&dev->sibling_node);
	INIT_LIST_HEAD(&dev->child_head);
	INIT_LIST_HEAD(&dev->uclass_node);
#if CONFIG_IS_ENABLED(DEVRES)
	INIT_LIST_HEAD(&dev->devres_head);
#endif
	//绑定driver_info到plat中,一般不要使用,而是使用下方的这个函数调用
	dev_set_plat(dev, plat);
	dev->driver_data = driver_data;
	dev->name = name;		//注意这里将初始化定义的驱动名称替换为FDT中的名称
	dev_set_ofnode(dev, node);
	dev->parent = parent;
	dev->driver = drv;
	dev->uclass = uc;

	dev->seq_ = -1;
	//根据配置文件中的配置，设置seq_
	if (CONFIG_IS_ENABLED(DM_SEQ_ALIAS) &&
	    (uc->uc_drv->flags & DM_UC_FLAG_SEQ_ALIAS)) {
		/*某些设备，例如 SPI 总线、I2C 总线和串行端口使用别名进行编号。*/
		if (CONFIG_IS_ENABLED(OF_CONTROL) &&	//如果开启了设备树控制
		    !CONFIG_IS_ENABLED(OF_PLATDATA)) {	//并且没有开启设备树平台数据
			if (uc->uc_drv->name && ofnode_valid(node)) {
				if (!dev_read_alias_seq(dev, &dev->seq_)) {
					//如果读取别名后缀数字成功，设置auto_seq为false,seq_为读取到的数字
					auto_seq = false;
					log_debug("   - seq=%d\n", dev->seq_);
					}
			}
		}
	}
	//没有在FDT中读取到别名后缀数字
	if (auto_seq && !(uc->uc_drv->flags & DM_UC_FLAG_NO_AUTO_SEQ))
		dev->seq_ = uclass_find_next_free_seq(uc);	//由程序自动设置seq_
	//有父节点设备
	if (parent) {
		/*将 dev 放入父级的 successor list */
		list_add_tail(&dev->sibling_node, &parent->child_head);
	}

	ret = uclass_bind_device(dev);	//将设备绑定到uclass

	if (drv->bind) {
		ret = drv->bind(dev);
	}

	if (parent && parent->driver->child_post_bind) {
		ret = parent->driver->child_post_bind(dev);
	}
	if (uc->uc_drv->post_bind) {
		ret = uc->uc_drv->post_bind(dev);
	}

	if (parent)
		pr_debug("Bound device %s to %s\n", dev->name, parent->name);
	if (devp)
		*devp = dev;

	dev_or_flags(dev, DM_FLAG_BOUND);

	return 0;
}
```

## device_probe 探测设备
```c
int device_probe(struct udevice *dev)
{
	const struct driver *drv;
	int ret;

	if (!dev)
		return -EINVAL;

	if (dev_get_flags(dev) & DM_FLAG_ACTIVATED)
		return 0;

	ret = device_notify(dev, EVT_DM_PRE_PROBE);
	drv = dev->driver;

	ret = device_of_to_plat(dev);						//识别设备并分配与设置平台内部的数据

	//在父设备上调用 probe
	if (dev->parent) {
		ret = device_probe(dev->parent);
		if (dev_get_flags(dev) & DM_FLAG_ACTIVATED)
			return 0;
	}

	dev_or_flags(dev, DM_FLAG_ACTIVATED);				//设置设备激活标志

	ret = dev_power_domain_on(dev);						//打开电源域
	ret = pinctrl_select_state(dev, "default");			//选择默认状态
	ret = dev_iommu_enable(dev);						//启用IOMMU
	ret = device_get_dma_constraints(dev);				//获取DMA约束

	ret = uclass_pre_probe_device(dev);					//uclass预探测设备

	ret = dev->parent->driver->child_pre_probe(dev);	//父设备的child_pre_probe

	ret = clk_set_defaults(dev, CLK_DEFAULTS_PRE);		//设置默认时钟

	ret = drv->probe(dev);								//调用驱动的probe函数
	ret = uclass_post_probe_device(dev);				//uclass后探测设备
	ret = pinctrl_select_state(dev, "default");			//选择默认状态

	return ret;
}
```


## device_of_to_plat 识别设备并分配与设置平台内部的数据
```c
int device_of_to_plat(struct udevice *dev)
{
	const struct driver *drv;
	int ret;
	/* Ensure all parents have ofdata */
	if (dev->parent) {
		ret = device_of_to_plat(dev->parent);
	}

	ret = device_alloc_priv(dev);	//分配设备私有数据
	drv = dev->driver;
	ret = drv->of_to_plat(dev);		//驱动平台内部的数据进行识别设置
	dev_or_flags(dev, DM_FLAG_PLATDATA_VALID);

	return 0;
}
```

## device_alloc_priv 分配设备私有数据
```c
static int device_alloc_priv(struct udevice *dev)
{
	/* Allocate private data if requested and not reentered */
	size = dev->uclass->uc_drv->per_device_auto;
	if (size && !dev_get_uclass_priv(dev)) {
		ptr = alloc_priv(size, dev->uclass->uc_drv->flags);	//分配私有数据
		if (!ptr)
			return -ENOMEM;
		dev_set_uclass_priv(dev, ptr);	//设置设备私有数据
	}
}
```

## device_bind_with_driver_data 绑定设备到父节点并传入驱动数据,与fdt的node信息
```c
int device_bind_with_driver_data(struct udevice *parent,
				 const struct driver *drv, const char *name,
				 ulong driver_data, ofnode node,
				 struct udevice **devp)
{
	return device_bind_common(parent, drv, name, NULL, driver_data, node,
				  0, devp);
}
```

# uclass.c
## uclass_get
## uclass_find 根据key查找uclass
```c
struct uclass *uclass_find(enum uclass_id key)
{
	struct uclass *uc;

	if (!gd->dm_root)
		return NULL;
	//遍历uclass链表，根据key找到对应的uclass
	list_for_each_entry(uc, gd->uclass_root, sibling_node) {
		if (uc->uc_drv->id == key)
			return uc;
	}

	return NULL;
}
```

## uclass_find_device_by_ofnode 根据ofnode查找设备
```c
int uclass_find_device_by_ofnode(enum uclass_id id, ofnode node,
				 struct udevice **devp)
{
	struct uclass *uc;
	struct udevice *dev;
	int ret;

	log(LOGC_DM, LOGL_DEBUG, "Looking for %s\n", ofnode_get_name(node));
	*devp = NULL;
	ret = uclass_get(id, &uc);	//根据id获取uclass
	if (ret)
		return ret;
	//遍历uclass链表，根据ofnode找到对应的设备
	uclass_foreach_dev(dev, uc) {
		log(LOGC_DM, LOGL_DEBUG_CONTENT, "      - checking %s\n",
		    dev->name);
		//比较ofnode的偏移量是否一致
		//dev是扫描FDT所有节点时获取的偏移量，node是直接从fdt中读取的偏移量
		if (ofnode_equal(dev_ofnode(dev), node)) {
			*devp = dev;
			goto done;
		}
	}
	ret = -ENODEV;

done:
	log(LOGC_DM, LOGL_DEBUG, "   - result for %s: %s (ret=%d)\n",
	    ofnode_get_name(node), *devp ? (*devp)->name : "(none)", ret);
	return ret;
}
```

## dev_set_uclass_priv 设置设备私有数据
- 在device_alloc_priv时调用
- device_probe -> device_of_to_plat -> device_alloc_priv -> dev_set_uclass_priv -> uclass_priv_

## dev_get_uclass_priv 获取设备私有数据
- dev_get_uclass_priv -> uclass_priv_

## dev_set_ofnode 设置设备的ofnode
- device_bind_common-> dev_set_ofnode;//dev_set_ofnode(dev, node);

## uclass_get_device_by_phandle 通过 phandle 获取 uclass 设备并执行探测
- 这将在 uclass 中搜索具有给定 phandle 的设备。探测设备以将其激活以供使用。

## uclass_get_device_tail device_probe 该设备

## uclass_find_device_by_phandle 通过 phandle 查找 uclass 设备
- 在当前FDT节点中根据name返回器phandle,并通过phandle id查找设备
```c
int uclass_find_device_by_phandle(enum uclass_id id, struct udevice *parent,
				  const char *name, struct udevice **devp)
{
	int find_phandle;

	*devp = NULL;
	find_phandle = dev_read_u32_default(parent, name, -1);
	if (find_phandle <= 0)
		return -ENOENT;

	return uclass_find_device_by_phandle_id(id, find_phandle, devp);
}
```

## uclass_find_device_by_phandle_id 通过 phandle id 查找 uclass 设备
```c
static int uclass_find_device_by_phandle_id(enum uclass_id id,
					    uint find_phandle,
					    struct udevice **devp)
{
	struct udevice *dev;
	struct uclass *uc;
	int ret;

	ret = uclass_get(id, &uc);	//根据id获取uclass
	if (ret)
		return ret;
	//遍历uclass链表，根据phandle找到对应的设备
	uclass_foreach_dev(dev, uc) {
		uint phandle;

		phandle = dev_read_phandle(dev);
		//比较phandle是否一致
		if (phandle == find_phandle) {
			*devp = dev;
			return 0;
		}
	}

	return -ENODEV;
}
```

## uclass_get_device_by_seq 通过seq查找设备并执行探测
```c
int uclass_get_device_by_seq(enum uclass_id id, int seq, struct udevice **devp)
{
	struct udevice *dev;
	int ret;

	*devp = NULL;
	ret = uclass_find_device_by_seq(id, seq, &dev);

	return uclass_get_device_tail(dev, ret, devp);
}
```

## uclass_find_device_by_seq 通过seq查找设备
1. 遍历uclass链表，根据seq找到对应的设备
```c
int uclass_find_device_by_seq(enum uclass_id id, int seq, struct udevice **devp)
{
	struct uclass *uc;
	struct udevice *dev;
	int ret;

	*devp = NULL;
	log_debug("%d\n", seq);
	if (seq == -1)
		return -ENODEV;
	ret = uclass_get(id, &uc);
	if (ret)
		return ret;

	uclass_foreach_dev(dev, uc) {
		log_debug("   - %d '%s'\n", dev->seq_, dev->name);
		if (dev->seq_ == seq) {
			*devp = dev;
			log_debug("   - found\n");
			return 0;
		}
	}
	log_debug("   - not found\n");

	return -ENODEV;
}
```

# lists.c
## lists_bind_drivers 绑定段中的driver_info
- 由于设备之间可能存在依赖关系，因此可能需要多次绑定设备
- 必须先绑定父设备，然后再绑定子设备
- 所以尝试绑定设备10次，如果绑定失败，返回-EAGAIN
```c
int lists_bind_drivers(struct udevice *parent, bool pre_reloc_only)
{
	int result = 0;
	int pass;

	/*
	 * 10 次传递是 DeviceTree 中的 10 个级别，这已经足够了。如果
	 * OF_PLATDATA_PARENT未启用，则 bind_drivers_pass（） 将
	 * 总是在第一次传递时成功。
	 */
	for (pass = 0; pass < 10; pass++) {
		int ret;

		ret = bind_drivers_pass(parent, pre_reloc_only);
		if (!result || result == -EAGAIN)
			result = ret;
		if (ret != -EAGAIN)
			break;
	}

	return result;
}
```

## bind_drivers_pass 遍历段中的driver_info
```c
static int bind_drivers_pass(struct udevice *parent, bool pre_reloc_only)
{
	//遍历段中的driver_info
	struct driver_info *info =
		ll_entry_start(struct driver_info, driver_info);
	const int n_ents = ll_entry_count(struct driver_info, driver_info);
	bool missing_parent = false;
	int result = 0;
	int idx;

	/*
	 * 对 driver_info 记录执行一次迭代。对于 of-platdata，
	 * 仅绑定父设备已绑定的设备。如果我们发现任何
	 * device 无法绑定，将 missing_parent 设置为 true，这会导致
	 * 此函数将再次调用。
	 */
	for (idx = 0; idx < n_ents; idx++) {
		struct udevice *par = parent;
		const struct driver_info *entry = info + idx;
		struct driver_rt *drt = gd_dm_driver_rt() + idx;
		struct udevice *dev;
		int ret;

		ret = device_bind_by_name(par, pre_reloc_only, entry, &dev);
		if (!ret) {
			if (CONFIG_IS_ENABLED(OF_PLATDATA))
				drt->dev = dev;
		} else if (ret != -EPERM) {
			dm_warn("No match for driver '%s'\n", entry->name);
			if (!result || ret != -ENOENT)
				result = ret;
		}
	}

	return result ? result : missing_parent ? -EAGAIN : 0;
}
```

## lists_bind_fdt 从FDT的每个节点获取compatible信息并与段中的driver结构体的of_match信息匹配,进而绑定设备
```c
int lists_bind_fdt(struct udevice *parent, ofnode node, struct udevice **devp,
		   struct driver *drv, bool pre_reloc_only)
{
	struct driver *driver = ll_entry_start(struct driver, driver);
	const int n_ents = ll_entry_count(struct driver, driver);
	const struct udevice_id *id;
	struct driver *entry;
	struct udevice *dev;
	bool found = false;
	const char *name, *compat_list, *compat;
	int compat_length, i;
	int result = 0;
	int ret = 0;

	if (devp)
		*devp = NULL;
	name = ofnode_get_name(node);
	log_debug("bind node %s\n", name);

	compat_list = ofnode_get_property(node, "compatible", &compat_length);
	if (!compat_list) {
		if (compat_length == -FDT_ERR_NOTFOUND) {
			log_debug("Device '%s' has no compatible string\n",
				  name);
			return 0;
		}

		dm_warn("Device tree error at node '%s'\n", name);
		return compat_length;
	}

	/*
	 * 遍历兼容的字符串列表，尝试匹配每个字符串
	 * compatible 字符串，以便我们按优先级顺序匹配
	 * 从第一个字符串到最后一个字符串。
	 */
	for (i = 0; i < compat_length; i += strlen(compat) + 1) {
		compat = compat_list + i;
		log_debug("   - attempt to match compatible string '%s'\n",
			  compat);

		id = NULL;
		//遍历段中的driver
		for (entry = driver; entry != driver + n_ents; entry++) {
			if (drv) {	//如果drv不为空，只绑定drv
				if (drv != entry)
					continue;
				if (!entry->of_match)
					break;
			}
			//设备的of_match与FDT的compatible字符串匹配,返回匹配的驱动id和驱动数据
			ret = driver_check_compatible(entry->of_match, &id,
						      compat);
			if (!ret)	//匹配成功
				break;
		}
		if (entry == driver + n_ents)	//没有匹配成功,继续下一个兼容字符串
			continue;

		if (pre_reloc_only) {//重定向之前必需满足的条件
			if (!ofnode_pre_reloc(node) &&					//判断节点是否需要在重定位之前绑定
			    !(entry->flags & DM_FLAG_PRE_RELOC)) {		//如果设备没有DM_FLAG_PRE_RELOC标志，跳过设备
				log_debug("Skipping device pre-relocation\n");
				return 0;
			}
		}

		if (entry->of_match)
			log_debug("   - found match at driver '%s' for '%s'\n",
				  entry->name, id->compatible);
		//绑定设备到父节点,将匹配的兼容设备id的data传递给设备,node是FDT中的节点进行传入绑定
		ret = device_bind_with_driver_data(parent, entry, name,
						   id ? id->data : 0, node,
						   &dev);
		found = true;
		if (devp)
			*devp = dev;
		break;
	}
	return result;
}
```

## driver_check_compatible 检查设备是否与驱动程序兼容,每个字符串需要完全匹配
- 驱动有一个of_match数组，用于检查设备是否与驱动兼容
- 通过比较设备的compatible字符串，判断设备是否与驱动兼容
- 可以多个compatible字符串，只要有一个匹配即可
- of_idp返回匹配的驱动id和驱动数据
- 返回0表示匹配

```c
static int driver_check_compatible(const struct udevice_id *of_match,
				   const struct udevice_id **of_idp,
				   const char *compat)
{
	if (!of_match)
		return -ENOENT;

	while (of_match->compatible) {
		if (!strcmp(of_match->compatible, compat)) {
			*of_idp = of_match;
			return 0;
		}
		of_match++;
	}

	return -ENOENT;
}
```

# ofnode.c
- 配置了OF_LIVE，表示设备树是动态的，可以在运行时修改
- 否则直接从FDT中读取设备树

## ofnode_first_subnode 获取第一个1子节点
- 用于遍历设备树

## ofnode_parse_phandle_with_args 解析node的list索引到的phandle的args返回
```c
struct ofnode_phandle_args {
	ofnode node;
	int args_count;
	uint32_t args[OF_MAX_PHANDLE_ARGS];
};
ofnode_parse_phandle_with_args()
{
		struct fdtdec_phandle_args args;
		int ret;
		/*
		* Example:
		*
		* phandle1: node1 {
		*	#list-cells = <2>;
		* }
		*
		* phandle2: node2 {
		*	#list-cells = <1>;
		* }
		*
		* node3 {
		*	list = <&phandle1 1 2 &phandle2 3>;
		* }
		*
		*/
		//解析node的list_name索引到的phandle
		ret = fdtdec_parse_phandle_with_args(ofnode_to_fdt(node),
						     ofnode_to_offset(node),
						     list_name, cells_name,
						     cell_count, index, &args);
		//解析phandle的args
		ofnode_from_fdtdec_phandle_args(node, &args, out_args);
}
```


## ofnode_pre_reloc 判断节点是否需要在重定位之前绑定
- 具有`bootph-all`或`bootph-pre-sram`

```c
bool ofnode_pre_reloc(ofnode node)
{
#if defined(CONFIG_XPL_BUILD) || defined(CONFIG_TPL_BUILD)
	/* for SPL and TPL the remaining nodes after the fdtgrep 1st pass
	 * had property bootph-all or bootph-pre-sram/bootph-pre-ram.
	 * They are removed in final dtb (fdtgrep 2nd pass)
	 */
	return true;
#else
	if (ofnode_read_bool(node, "bootph-all"))
		return true;
	if (ofnode_read_bool(node, "bootph-some-ram"))
		return true;

	/*
	 * In regular builds individual spl and tpl handling both
	 * count as handled pre-relocation for later second init.
	 */
	if (ofnode_read_bool(node, "bootph-pre-ram") ||
	    ofnode_read_bool(node, "bootph-pre-sram"))
		return gd->flags & GD_FLG_RELOC;

	if (IS_ENABLED(CONFIG_OF_TAG_MIGRATE)) {
		/* detect and handle old tags */
		if (ofnode_read_bool(node, "u-boot,dm-pre-reloc") ||
		    ofnode_read_bool(node, "u-boot,dm-pre-proper") ||
		    ofnode_read_bool(node, "u-boot,dm-spl") ||
		    ofnode_read_bool(node, "u-boot,dm-tpl") ||
		    ofnode_read_bool(node, "u-boot,dm-vpl")) {
			gd->flags |= GD_FLG_OF_TAG_MIGRATE;
			return true;
		}
	}

	return false;
#endif
}
```

## uclass_get_device_by_ofnode 根据ofnode获取uclass设备,并执行探测

# fdtaddr.c
## dev_read_addr
## devfdt_get_addr
## devfdt_get_addr_index
## devfdt_get_addr_index_parent
## fdtdec_get_addr_size_auto_parent FDT中获取节点获取reg的地址和大小
- 通过解析提供的父节点的 `#address-cells` 和 `#size-cells` 属性，自动确定用于表示地址和大小的单元格数。
- 解析`reg`确定reg的地址和大小

# device-remove.c
## device_remove 移除设备
```c
int device_remove(struct udevice *dev, uint flags)
{
	const struct driver *drv;
	int ret;

	if (!dev)
		return -EINVAL;

	if (!(dev_get_flags(dev) & DM_FLAG_ACTIVATED))	//没激活的设备不需要移除
		return 0;

	ret = device_notify(dev, EVT_DM_PRE_REMOVE);
	if (ret)
		return ret;

	/*
	 * 如果子项返回 EKEYREJECTED，请继续。它只是意味着它
	 * 不匹配标志。
	 */
	ret = device_chld_remove(dev, NULL, flags);
	if (ret && ret != -EKEYREJECTED)
		return ret;

	/*
	 * 如果在设置了 “normal” remove 标志的情况下调用设备，则删除设备，
	 * 或者如果 remove 标志与任何驱动程序 remove 标志匹配
	 */
	drv = dev->driver;
	assert(drv);
	ret = flags_remove(flags, drv->flags);	//判断设备属性是否允许移除
	if (ret) {
		log_debug("%s: When removing: flags=%x, drv->flags=%x, err=%d\n",
			  dev->name, flags, drv->flags, ret);
		return ret;
	}

	ret = uclass_pre_remove_device(dev);
	if (ret)
		return ret;

	if (drv->remove) {
		ret = drv->remove(dev);
		if (ret)
			goto err_remove;
	}

	if (dev->parent && dev->parent->driver->child_post_remove) {
		ret = dev->parent->driver->child_post_remove(dev);
		if (ret) {
			dm_warn("%s: Device '%s' failed child_post_remove()",
				__func__, dev->name);
		}
	}

	if (!(flags & DM_REMOVE_NO_PD) &&
	    !(drv->flags &
	      (DM_FLAG_DEFAULT_PD_CTRL_OFF | DM_FLAG_LEAVE_PD_ON)) &&
	    dev != gd->cur_serial_dev)
		dev_power_domain_off(dev);

	device_free(dev);

	dev_bic_flags(dev, DM_FLAG_ACTIVATED);

	ret = device_notify(dev, EVT_DM_POST_REMOVE);
	if (ret)
		goto err_remove;

	return 0;

err_remove:
	/* We can't put the children back */
	dm_warn("%s: Device '%s' failed to remove, but children are gone\n",
		__func__, dev->name);

	return ret;
}
```

## device_chld_remove 移除设备下的子设备
```c
int device_chld_remove(struct udevice *dev, struct driver *drv,
		       uint flags)
{
	struct udevice *pos, *n;
	int result = 0;

	assert(dev);

	device_foreach_child_safe(pos, n, dev) {
		int ret;

		if (drv && (pos->driver != drv))
			continue;

		ret = device_remove(pos, flags);
		if (ret == -EPROBE_DEFER)
			result = ret;
		else if (ret && ret != -EKEYREJECTED)
			return ret;
	}

	return result;
}
```

## flags_remove 判断设备属性是否允许移除
- 具有`DM_REMOVE_NORMAL`标志的正常设备,允许进行卸载
- 具有活动 DMA 的设备(`DM_REMOVE_ACTIVE_DMA	= DM_FLAG_ACTIVE_DMA`) 和跳转APP所需要的活动设备(`DM_REMOVE_OS_PREPARE	= DM_FLAG_OS_PREPARE`)，不允许卸载;返回`-EKEYREJECTED`
- 具有标记为 Vital 的设备(`DM_REMOVE_NON_VITAL	= DM_FLAG_VITAL,`),不允许卸载;返回`-EPROBE_DEFER`

```c
static int flags_remove(uint flags, uint drv_flags)
{
	if (!(flags & DM_REMOVE_NORMAL)) {
		bool vital_match;
		bool active_match;

		active_match = !(flags & DM_REMOVE_ACTIVE_ALL) ||
			(drv_flags & flags);
		vital_match = !(flags & DM_REMOVE_NON_VITAL) ||
			!(drv_flags & DM_FLAG_VITAL);
		if (!vital_match)
			return -EPROBE_DEFER;
		if (!active_match)
			return -EKEYREJECTED;
	}

	return 0;
}
```