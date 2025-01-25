# initf_dm
```c
static int initf_dm(void)
{
	int ret;

	if (!CONFIG_IS_ENABLED(SYS_MALLOC_F))
		return 0;

	ret = dm_init_and_scan(true);
	if (ret)
		return ret;

	ret = dm_autoprobe();
	if (ret)
		return ret;

	if (IS_ENABLED(CONFIG_TIMER_EARLY)) {
		ret = dm_timer_init();
		if (ret)
			return ret;
	}

	return 0;
}
```

# root.c
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
```
## dm_init
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
			dev_set_ofnode(DM_ROOT_NON_CONST, ofnode_root());
		ret = device_probe(DM_ROOT_NON_CONST);
		if (ret)
			return ret;
	}
}
```

# core/device.c
```c
/**
 * struct driver - 功能或外围设备的驱动程序
 *
 * 此字段包含设置新设备和删除新设备的方法。
 * 设备需要信息来设置自身 - 这提供了
 * 按 Plat 或 Device Tree 节点（我们通过查找找到
 * 将兼容的字符串与 of_match） 匹配。
 *
 * 驱动程序都属于一个 uclass，代表
 * 相同类型。驱动程序的公共元素可以在 uclass 中实现，
 * 或 uclass 可以为
 *它。
 *
 * @name：设备名称
 * @id：标识我们所属的 uclass
 * @of_match：要匹配的兼容字符串列表以及任何标识数据
 * 对于每个。
 * @bind：调用以将设备绑定到其驱动程序
 * @probe：调用以探测设备，即激活它
 * @remove：调用以删除设备，即停用设备
 * @unbind：调用以取消设备与其驱动程序的绑定
 * @of_to_plat：在 probe 之前调用以解码设备树数据
 * @child_post_bind：在绑定新子项后调用
 * @child_pre_probe：在探测子设备之前调用。该设备具有
 * 内存已分配，但尚未探测。
 * @child_post_remove：删除子设备后调用。设备
 * 已分配内存，但其 device_remove（） 方法已被调用。
 * @priv_auto：如果非零，则为私有数据的大小
 * 在设备的 ->priv 指针中分配。如果为零，则驱动程序
 * 负责分配所需的任何数据。
 * @plat_auto：如果非零，则为
 * 在设备的 ->plat 指针中分配的平台数据。
 * 这通常仅对设备树感知驱动程序（具有
 * of_match），因为使用 Plat 的驱动程序将拥有数据
 * 在 U_BOOT_DRVINFO（） 实例中提供。
 * @per_child_auto：每台设备都可以保存
 * 其父级。如果需要，如果
 * 值为非零。
 * @per_child_plat_auto：公交车喜欢存储以下信息
 * 它的子项。如果非零，则这是要分配的此数据的大小
 * 在子指针的 parent_plat 中。
 * @ops：特定于驱动程序的操作。这通常是一个函数列表
 * 由驱动程序定义的指针，以实现所需的驱动程序功能
 * UCLASS.
 * @flags：驾驶员标志 - 请参阅“DM_FLAG_...”
 * @acpi_ops：高级配置和电源接口 （ACPI） 操作，
 * 允许设备将内容添加到传递给 Linux 的 ACPI 表中
 */
struct driver {
	char *name;
	enum uclass_id id;
	const struct udevice_id *of_match;
	int (*bind)(struct udevice *dev);
	int (*probe)(struct udevice *dev);
	int (*remove)(struct udevice *dev);
	int (*unbind)(struct udevice *dev);
	int (*of_to_plat)(struct udevice *dev);
	int (*child_post_bind)(struct udevice *dev);
	int (*child_pre_probe)(struct udevice *dev);
	int (*child_post_remove)(struct udevice *dev);
	int priv_auto;
	int plat_auto;
	int per_child_auto;
	int per_child_plat_auto;
	const void *ops;	/* driver-specific operations */
	uint32_t flags;
#if CONFIG_IS_ENABLED(ACPIGEN)
	struct acpi_ops *acpi_ops;
#endif
};
```

## device_bind_by_name
```c
/**
 * device_bind_by_name：创建设备并将其绑定到驱动程序
 *
 * 这是一个辅助函数，用于绑定不使用设备的设备
 *树。
 *
 * @parent：指向设备父级的指针
 * @pre_reloc_only：如果为 true，则仅在驱动程序的 DM_FLAG_PRE_RELOC 标志时绑定驱动程序
 * 已设置。如果为 false，则始终绑定驱动程序。
 * @info：此设备的名称和平台
 * @devp：如果为非 NULL，则返回指向绑定设备的指针
 * 返回：OK 时为 0，出错时为 -ve
 */
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

## device_bind_common
```c
- 进行一系列初始化与绑定操作
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

	if (CONFIG_IS_ENABLED(OF_PLATDATA_NO_BIND))
		return -ENOSYS;

	if (devp)
		*devp = NULL;
	if (!name)
		return -EINVAL;

	ret = uclass_get(drv->id, &uc);
	if (ret) {
		dm_warn("Missing uclass for driver %s\n", drv->name);
		return ret;
	}

	dev = calloc(1, sizeof(struct udevice));
	if (!dev)
		return -ENOMEM;

	INIT_LIST_HEAD(&dev->sibling_node);
	INIT_LIST_HEAD(&dev->child_head);
	INIT_LIST_HEAD(&dev->uclass_node);
#if CONFIG_IS_ENABLED(DEVRES)
	INIT_LIST_HEAD(&dev->devres_head);
#endif
}
```

# uclass.c
## uclass
```c
/**
 * struct uclass - 一个 U-Boot 驱动类，收集了类似的驱动程序
 *
 * uclass 为特定函数提供接口，该函数是
 * 由一个或多个驱动程序实现。每个驱动程序都属于一个 uclass
 * 如果它是该 uclass 中的唯一驱动程序。一个例子 uclass 是 GPIO，它
 * 提供更改读取输入、设置和清除输出等功能。
 * 可能有用于片上 SoC GPIO 组、I2C GPIO 扩展器和
 * PMIC IO 线路，全部通过 uclass 以统一方式提供。
 *
 * @priv_：此 uclass 的私有数据（不访问驱动程序模型外部）
 * @uc_drv：uclass 本身的驱动程序，不要与
 * 'struct driver'
 * @dev_head：此 uclass 中的设备列表（设备连接到其
 * uclass 调用其 bind 方法时）
 * @sibling_node：uclasses 链表中的下一个 uclass
 */
struct uclass {
	void *priv_;
	struct uclass_driver *uc_drv;
	struct list_head dev_head;
	struct list_head sibling_node;
};
```

## uclass_driver
```c
/**
 * struct uclass_driver - uclass 的驱动程序
 *
 * uclass_driver为一组相关的
 *司机。
 *
 * @name：uclass 驱动程序的名称
 * @id：此 uclass 的 ID 号
 * @post_bind：在新设备绑定到此 uclass 后调用
 * @pre_unbind：在设备与此 uclass 解绑之前调用
 * @pre_probe：在探测新设备之前调用
 * @post_probe：探测新设备后调用
 * @pre_remove：在移除设备之前调用
 * @child_post_bind：在子级绑定到此 uclass 中的设备后调用
 * @child_pre_probe：在探测此 uclass 中的子对象之前调用
 * @child_post_probe：探测此 uclass 中的子对象后调用
 * @init：调用以设置 uclass
 * @destroy：调用以销毁 uclass
 * @priv_auto：如果非零，则为私有数据的大小
 * 在 uclass 的 ->priv 指针中分配。如果为零，则 uclass
 * 驱动程序负责分配所需的任何数据。
 * @per_device_auto：每台设备都可以保存拥有的私有数据
 * 由 uclass.如果需要，如果
 * 值为非零。
 * @per_device_plat_auto：每个设备都可以保存平台数据
 * 由 uclass 拥有，为 'dev->uclass_plat'。如果该值为非零，则
 * 则此 ID 将自动分配。
 * @per_child_auto：每个子设备（此
 * uclass） 可以保存 device/uclass 的父数据。此值仅为
 * 如果此成员在驱动程序中为 0，则用作回退。
 * @per_child_plat_auto：公交车喜欢存储以下信息
 * 它的子项。如果非零，则这是要分配的此数据的大小
 * 在子设备的 parent_plat 指针中。此值仅用作
 * 如果此成员在驱动程序中为 0，则为回退。
 * @flags： 此 uclass 的标志 ''（DM_UC_...）``
 */
struct uclass_driver {
	const char *name;
	enum uclass_id id;
	int (*post_bind)(struct udevice *dev);
	int (*pre_unbind)(struct udevice *dev);
	int (*pre_probe)(struct udevice *dev);
	int (*post_probe)(struct udevice *dev);
	int (*pre_remove)(struct udevice *dev);
	int (*child_post_bind)(struct udevice *dev);
	int (*child_pre_probe)(struct udevice *dev);
	int (*child_post_probe)(struct udevice *dev);
	int (*init)(struct uclass *class);
	int (*destroy)(struct uclass *class);
	int priv_auto;
	int per_device_auto;
	int per_device_plat_auto;
	int per_child_auto;
	int per_child_plat_auto;
	uint32_t flags;
};
```

### uclass_get
```c
int uclass_get(enum uclass_id id, struct uclass **ucp)
{
	struct uclass *uc;

	/* Immediately fail if driver model is not set up */
	if (!gd->uclass_root)
		return -EDEADLK;
	*ucp = NULL;
	uc = uclass_find(id);	//遍历段中的uc->uc_drv->id
	if (!uc) {
		if (CONFIG_IS_ENABLED(OF_PLATDATA_INST))
			return -ENOENT;
		return uclass_add(id, ucp);	//没有找到则添加
	}
	*ucp = uc;

	return 0;
}
```

## uclass_add

```c
static int uclass_add(enum uclass_id id, struct uclass **ucp)
{
	struct uclass_driver *uc_drv;
	struct uclass *uc;
	int ret;

	*ucp = NULL;
	uc_drv = lists_uclass_lookup(id);	//从段中查找uc_drv
	if (!uc_drv) {
		return -EPFNOSUPPORT;
	}
	uc = calloc(1, sizeof(*uc));
	if (!uc)
		return -ENOMEM;
	if (uc_drv->priv_auto) {	//驱动分配私有数据
		void *ptr;

		ptr = calloc(1, uc_drv->priv_auto);
		if (!ptr) {
			ret = -ENOMEM;
			goto fail_mem;
		}
		uclass_set_priv(uc, ptr);
	}
	uc->uc_drv = uc_drv;
	INIT_LIST_HEAD(&uc->sibling_node);
	INIT_LIST_HEAD(&uc->dev_head);
	list_add(&uc->sibling_node, DM_UCLASS_ROOT_NON_CONST);

	if (uc_drv->init) {	//驱动程序初始化
		ret = uc_drv->init(uc);
		if (ret)
			goto fail;
	}

	*ucp = uc;

	return 0;
fail:
	if (uc_drv->priv_auto) {
		free(uclass_get_priv(uc));
		uclass_set_priv(uc, NULL);
	}
	list_del(&uc->sibling_node);
fail_mem:
	free(uc);

	return ret;
}
```
