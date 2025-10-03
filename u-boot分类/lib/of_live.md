---
title: of_live
categories:
  - uboot
  - u-boot分类
  - lib
tags:
  - uboot
  - u-boot分类
  - lib
abbrlink: f637a49c
date: 2025-10-03 09:44:27
---
[TOC]
# of_live
- 将平面设备树转换为分层设备树,将原来紧凑的二进制设备树转换为分层的设备树,以结构体的形式存储,便于查找和操作

# of_live_build
1. unflatten_device_tree, 创建活动设备树
2. of_alias_scan, 扫描设备树中的别名

# struct device_node
```c
/**
 * struct device_node：设备树节点
 *
 * 此树的顶部通常是 gd->of_root，它指向根节点。
 *
 * 根节点（和任何其他节点）的子节点列表的头部为
 * 在 @child 中，@sibling 提供指向下一个子项的链接。
 *
 * 每个子项都有一个指向其父项的指针 @parent。
 *
 * 节点可能具有属性，在这种情况下，属性列表的头部
 * @properties指向第一个的指针，其中 struct property->@next 指向
 * 到下一个。
 *
 * @name：节点名称，根节点的 “”
 * @type：节点类型（device_type 属性的值）或 “<NULL>”（如果没有）
 * @phandle：此 none 的 Phandle 值，如果没有，则为 0
 * @full_name：节点的完整路径，例如 “/bus@1/spi@1100” （“/” 表示根节点）
 * @properties：指向属性列表 head 的指针，如果没有，则为 NULL
 * @parent：指向父节点的指针，如果这是根节点，则为 NULL
 * @child：指向子节点列表头部的指针，如果没有子节点，则为 NULL
 * @sibling：指向下一个同级节点的指针，如果这是最后一个节点，则为 NULL
 */
struct device_node {
	const char *name;
	const char *type;
	phandle phandle;
	const char *full_name;

	struct property *properties;
	struct device_node *parent;
	struct device_node *child;
	struct device_node *sibling;
};
```

# unflatten_device_tree 创建活动设备树
```c
//传入平面树blob，返回活动设备树mynodes
int unflatten_device_tree(const void *blob, struct device_node **mynodes)
{
	unsigned long size;
	int start;
	void *mem;

    // 检查设备树格式
	if (fdt_check_header(blob)) {
		debug("Invalid device tree blob header\n");
		return -EINVAL;
	}

	/* 首次扫描,获取大小 */
	start = 0;
	size = (unsigned long)unflatten_dt_node(blob, NULL, &start, NULL, NULL,
						0, true);

	/* 为扩展的设备树分配内存 */
	mem = memalign(__alignof__(struct device_node), size + 4);
	memset(mem, '\0', size);

	/* Set up value for dm_test_livetree_align() */
	*(u32 *)mem = BAD_OF_ROOT;

	*(__be32 *)(mem + size) = cpu_to_be32(0xdeadbeef);

	debug("  unflattening %p...\n", mem);

	/* Second pass, do actual unflattening */
	start = 0;
    //从平面树分配并填充device_node结构
	unflatten_dt_node(blob, mem, &start, NULL, mynodes, 0, false);
	if (be32_to_cpup(mem + size) != 0xdeadbeef) {
		debug("End of tree marker overwritten: %08x\n",
		      be32_to_cpup(mem + size));
		return -ENOSPC;
	}

	debug(" <- unflatten_device_tree()\n");

	return 0;
}
```

# of_alias_scan 扫描设备树中的别名
1. of_alias_add,添加到链表中,提供查找
```c
/* list of struct alias_prop aliases */
static LIST_HEAD(aliases_lookup);

/* "/aliaes" node */
static struct device_node *of_aliases;

/* "/chosen" node */
static struct device_node *of_chosen;

/* node pointed to by the stdout-path alias */
static struct device_node *of_stdout;

/* pointer to options given after the alias (separated by :) or NULL if none */
static const char *of_stdout_options;
```