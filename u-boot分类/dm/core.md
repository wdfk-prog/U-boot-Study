[TOC]

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

	ret = dm_autoprobe();	//绑定后探测所有设备
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

## dm_scan_plat 扫描段中的设备
```c
int dm_scan_plat(bool pre_reloc_only)
{
	ret = lists_bind_drivers(DM_ROOT_NON_CONST, pre_reloc_only);
}
```

## dm_autoprobe
## dm_probe_devices 绑定后探测所有设备
```c
//设备具有DM_FLAG_PROBE_AFTER_BIND标志，将在绑定后探测设备
//扫描所有设备进行探测
static int dm_probe_devices(struct udevice *dev)
{
	struct udevice *child;

	if (dev_get_flags(dev) & DM_FLAG_PROBE_AFTER_BIND) {
		int ret;

		ret = device_probe(dev);
		if (ret)
			return ret;
	}

	list_for_each_entry(child, &dev->child_head, sibling_node)
		dm_probe_devices(child);

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

	ret = dm_scan_fdt(pre_reloc_only);	//扫描FDT中的设备并绑定到根节点

	/* 有些节点本身不是设备，但可能包含一些驱动*/
	for (i = 0; i < ARRAY_SIZE(nodes); i++) {
		ret = dm_scan_fdt_ofnode_path(nodes[i], pre_reloc_only);
	}

	return ret;
}
```

## dm_scan_fdt
## dm_scan_fdt_node 扫描FDT中的节点并根据节点属性status=ok绑定设备
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
		//绑定FDT中的设备到父节点
		err = lists_bind_fdt(parent, node, NULL, NULL, pre_reloc_only);

	}
	return ret;
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

	dev_set_plat(dev, plat);
	dev->driver_data = driver_data;
	dev->name = name;
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
	if (ret)
		return ret;

	drv = dev->driver;
	assert(drv);

	ret = device_of_to_plat(dev);				//识别设备并分配与设置平台内部的数据
	ret = ret = uclass_pre_probe_device(dev);	//执行设备驱动的pre_probe
	if (drv->probe) {
		ret = drv->probe(dev);					//执行设备驱动的probe
	}
	ret = uclass_post_probe_device(dev);		//执行设备驱动的post_probe
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

## device_bind_with_driver_data 绑定设备到父节点并传入驱动数据
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

## dev_ofnode 获取设备的ofnode

## uclass_get_device_by_ofnode 根据ofnode获取设备,并执行device_probe
```c
int uclass_get_device_by_ofnode(enum uclass_id id, ofnode node,
				struct udevice **devp)
{
	struct udevice *dev;
	int ret;

	log(LOGC_DM, LOGL_DEBUG, "Looking for %s\n", ofnode_get_name(node));
	*devp = NULL;
	ret = uclass_find_device_by_ofnode(id, node, &dev);
	log(LOGC_DM, LOGL_DEBUG, "   - result for %s: %s (ret=%d)\n",
	    ofnode_get_name(node), dev ? dev->name : "(none)", ret);

	return uclass_get_device_tail(dev, ret, devp);	//执行device_probe
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

## lists_bind_fdt 从FDT中绑定设备
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

		if (pre_reloc_only) {
			if (!ofnode_pre_reloc(node) &&
			    !(entry->flags & DM_FLAG_PRE_RELOC)) {
				log_debug("Skipping device pre-relocation\n");
				return 0;
			}
		}

		if (entry->of_match)
			log_debug("   - found match at driver '%s' for '%s'\n",
				  entry->name, id->compatible);
		//绑定设备到父节点,将匹配的兼容设备id的data传递给设备
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

## driver_check_compatible 检查设备是否与驱动程序兼容
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

## ofnode_first_subnode 获取第一个子节点
- 用于遍历设备树

# fdtaddr.c
## dev_read_addr
## devfdt_get_addr
## devfdt_get_addr_index
## devfdt_get_addr_index_parent
## fdtdec_get_addr_size_auto_parent FDT中获取节点获取reg的地址和大小
- 通过解析提供的父节点的 `#address-cells` 和 `#size-cells` 属性，自动确定用于表示地址和大小的单元格数。
- 解析`reg`确定reg的地址和大小