---
title: fdt
date: 2025-10-03 09:44:27
categories:
  - uboot
  - u-boot分类
  - fdt
tags:
  - uboot
  - u-boot分类
  - fdt
---
# fdtdec 扁平设备树解析

- [devicetree](https://docs.u-boot.org/en/latest/develop/devicetree/index.html)
- [devicetree-specification](https://github.com/devicetree-org/devicetree-specification)
- [devicetree-specification.pdf](../../子目录/devicetree-specification-v0.4.pdf)

# 设备树BLLOB结构

![1737803328902](image/fdt/1737803328902.png)

```c
struct fdt_header {
	fdt32_t magic;			 /* magic word FDT_MAGIC */
	fdt32_t totalsize;		 /* total size of DT block */
	fdt32_t off_dt_struct;		 /* offset to structure */
	fdt32_t off_dt_strings;		 /* offset to strings */
	fdt32_t off_mem_rsvmap;		 /* offset to memory reserve map */
	fdt32_t version;		 /* format version */
	fdt32_t last_comp_version;	 /* last compatible version */

	/* version 2 fields below */
	fdt32_t boot_cpuid_phys;	 /* Which physical CPU id we're
					    booting on */
	/* version 3 fields below */
	fdt32_t size_dt_strings;	 /* size of the strings block */

	/* version 17 fields below */
	fdt32_t size_dt_struct;		 /* size of the structure block */
};
```

- magic: 该字段的值为0xd00dfeed(大端位)
- total size: 该字段应包含设备树数据结构的总大小（以字节为单位）。
  - 这个大小应该包括结构的所有部分：头，内存保留块，结构块和字符串块，以及块之间或最后块之后的任何空闲空间间隙。
  - 0x0035f3dd = 3535837 = 3452kb = 3.37MB
- off_dt_struct:这个字段应该包含从报头开始的结构块的字节偏移量
  - 0x00000038 = 56
- off_dt_strings:这个字段应该包含从报头开始的字符串块（参见第5.5节）的字节偏移量
  - 0x0035eff8 = 3452kb + 0x00000038 = 56 + 3452kb
- off_mem_rsvmap:这个字段应该包含从报头开始的内存保留块（参见5.3节）的字节偏移量
  - 0x00000028 = 40
- version:该字段应包含设备树数据结构的版本。
  - 如果使用本文档中定义的结构，则版本为17。
  - DTSpec引导程序可以提供更高版本的设备树，在这种情况下，该字段应包含在提供该版本详细信息的后续文档中定义的版本号。
  - 0x00000011 = 17
- last_comp_version:该字段应包含与所使用的版本向后兼容的设备树数据结构的最低版本。
  - 因此，对于本文档（版本17）中定义的结构，该字段应包含16个17向后兼容版本16，但不兼容更早的版本。按照5.1节的规定，DTSpec引导程序应该以向后兼容版本16的格式提供设备树，因此该字段应始终包含16。
  - 0x00000010 = 16
- boot_cpuid_phys:该字段应该包含系统启动CPU的物理ID。它应该与设备树中CPU节点的reg属性中给出的物理ID相同。
  - 0x00000000 = 0
- size_dt_strings:该字段应包含devicetree blob的字符串块部分的字节长度
  - 0x00000065 = 101
- size_dt_struct:该字段应包含devicetree blob的结构块部分的字节长度。
  - 0x0035efc0 = 3534784 = 3451kb = 3.37MB
- free space: 不存在,该区域应该是空的
- memory reservation block:
    ```c
    struct fdt_reserve_entry {
    uint64_t address;
    uint64_t size;
    };
    ```
    - address:  保留的内存地址 0x0000000000000000
    - size:     保留的内存大小 0x0000000000000000
- structure block: 结构块由一系列片段组成，每个片段以一个令牌开头，即一个大端位32位整数。一些令牌后面跟着额外的数据，其格式由令牌值决定。所有令牌都应在32位边界上对齐，这可能需要在前一个令牌的数据之后插入填充字节（值为0x0）
    - FDT_BEGIN_NODE (0x00000001) FDT_BEGIN_NODE标记一个节点表示的开始。
        - 后面应该加上节点的单位名称作为额外的数据。
        - 名称存储为一个以空结束的字符串，如果有的话，应该包括单元地址（见第2.2.1节）。
        - 节点名后面跟着零填充字节（如果对齐需要的话），然后是下一个令牌，可以是除FDT_END以外的任何令牌。
    - FDT_END_NODE (0x00000002) FDT_END_NODE标记一个节点表示的结束。这个令牌没有额外的数据；所以它后面紧跟着下一个令牌，这个令牌可以是除FDT_PROP以外的任何令牌
    - FDT_PROP (0x00000003):  FDT_PROP标志着设备树中一个属性表示的开始。其后应附有描述该属性的额外数据。该数据首先由属性的长度和名称组成，表示为以下C结构：
        ```c
        struct {
        uint32_t len;
        uint32_t nameoff;
        }
        ```
        - len以字节为单位给出属性值的长度（可以为零，表示属性为空，参见第2.2.4节）。
            - 0x00000004 = 4
        - nameoff在字符串块中给出一个偏移量（参见第5.5节），属性的名称存储在该块中，作为一个以空结束的字符串。
            - 0x00000055 = 85
            - 0x0035eff8 + 0x00000055 = 0x0035f04d
            - 字符串中查找为:0x74696d657374616d700 = "timestamp "
        - 属性的值:在此结构之后，该属性的值作为长度为len的字节串给出。该值后面是零填充字节（如果有必要），以对齐下一个32位边界，然后是下一个令牌，可以是除FDT_END之外的任何令牌。
            - value: 0x625ea451: 2022-04-13 09:57:37
    - 根节点: 空字符串（表示根节点）
        - 属性: timestamp: 2022-04-13 09:57:37
        - 属性: description: "RT-Thread STM32H750i-ART-PI board"
        - 节点:images: 
            - 节点:kernel:
                - 属性:description: "Linux kernel for RT-Thread STM32H750i-ART-PI board"
                - 属性:data: 长度:15A9D0= 1416KB = 1.38MB
                - 属性:type: kernel
                - 属性arch:arm
    - 完整解析如下
    ```c
        / {
        description = "RT-Thread STM32H750i-ART-PI board";

        images {
            
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

            fdt {
                description = "Flattened Device Tree blob for for RT-Thread STM32H750i-ART-PI board";
                data = /incbin/("./stm32h750i-art-pi.dtb");
                type = "flat_dt";
                arch = "arm";
                os = "linux";
                compression = "none";
                hash {
                    algo = "sha1";
                };
            };

            ramdisk {
                description = "Ramdisk for for RT-Thread STM32H750i-ART-PI board";
                data = /incbin/("./rootfs.ext2");
                type = "ramdisk";
                arch = "arm";
                os = "linux";
                compression = "none";
                hash {
                    algo = "sha1";
                };
            };
        };

        configurations {
            default = "conf0";
            conf0 {
                description = "Boot Linux kernel with FDT blob";
                kernel = "kernel";
                fdt = "fdt";
                ramdisk = "ramdisk";
            };
        };
    };
    ```
```log
magic:                      d0 0d fe ed 
total size:                 00 35 f3 dd 
off_dt_struct:              00 00 00 38 
off_dt_strings:             00 35 ef f8
off_mem_rsvmap:             00 00 00 28
version:                    00 00 00 11
last_comp_version:          00 00 00 10
boot_cpuid_phys:            00 00 00 00
size_dt_strings:            00 00 00 65
size_dt_struct:             00 35 ef c0
free space:
memory reservation block:
    address:                00 00 00 00 00 00 00 00 
    size:                   00 00 00 00 00 00 00 00 
structure block:
    令牌: DT_BEGIN_NODE:    00 00 00 01 00 00 00 00
    节点名称: 空字符串（表示根节点）
    令牌: FDT_PROP:         00 00 00 03 00 00 00 00
        属性长度:            00 00 00 04
        属性名称偏移:        00 00 00 55
        属性值:             62 5e a4 51
```

# lib
## fdtdec.c

### fdtdec_setup 初始化fdtdec 写入fdt_blob和fdt_src

```c
int fdtdec_setup(void)
{

    int ret = -ENOENT;


    /* 使用bloblist查找设备树 */



    /* 否则，设备树通常会附加到 U-Boot */

    if (ret) {

        //在镜像末尾找到一个 devicetree

        if (IS_ENABLED(CONFIG_OF_SEPARATE)) {

            gd->fdt_blob = fdt_find_separate();

            gd->fdt_src = FDTSRC_SEPARATE;

        } else { //在ELF文件中嵌入dtb

            fdtdec_setup_embed();

        }

    }


    /* 允许板子覆盖 fdt 地址。 */


    /* 允许早期环境覆盖 fdt 地址 */


    /*  从 FIT 中找到正确的 dtb */


    ret = fdtdec_prepare_fdt(gd->fdt_blob);

    if (!ret)

        /* 根据设备数初始化硬件 */

        ret = fdtdec_board_setup(gd->fdt_blob);

    oftree_reset();


    return ret;

}

```

### fdt_find_separate 查找分离的fdt 返回在_end处的fdt,并检查是否正确

```c

//镜像末尾找到一个 devicetree

staticvoid *fdt_find_separate(void)

{

    /* FDT is at end of image */

    fdt_blob = (ulong *)_end;


    if (_DEBUG && //开启调试打印

    !fdtdec_prepare_fdt(fdt_blob)) {    //检查fdt是否正确

        int stack_ptr;

        constvoid *top = fdt_blob + fdt_totalsize(fdt_blob);


        /*

         * 对内存布局执行健全性检查。如果此操作失败，表示设备树位于全局数据指针或堆栈指针。这不应该发生。

         * 如果失败，请检查SYS_INIT_SP_ADDR是否有足够的空间 用于 SYS_MALLOC_F_LEN 和 global_data，以及堆栈，

         * 而不会覆盖设备树或 U-Boot 本身。 由于设备树位于 _end（BSS 区域），我们需要设备树的顶部位于下方

         * 由 board_init_f_alloc_reserve（） 分配的任何内存。

         */

        if (top > (void *)gd    //gd地址就是SYS_INIT_SP_ADDR

        || top > (void *)&stack_ptr) {  //当前的栈指针地址

            printf("FDT %p gd %p\n", fdt_blob, gd);

            panic("FDT overlap");

        }

    }

    return fdt_blob;

}

```

### fdtdec_prepare_fdt 检查是否有可用于控制 U-Boot 的有效 fdt

```c

static int fdtdec_prepare_fdt(constvoid *blob)

{

    if (!blob //空指针

    || ((uintptr_t)blob & 3)        //地址对齐

    || fdt_check_header(blob)) {    //检查fdt头部是否正确

        if (xpl_phase() <= PHASE_SPL) {

            puts("Missing DTB\n");

        } else {

            printf("No valid device tree binary found at %p\n",

                   blob);

            if (_DEBUG && blob) {

                printf("fdt_blob=%p\n", blob);

                print_buffer((ulong)blob, blob, 4, 32, 0);

            }

        }

        return -ENOENT;

    }


    return0;

}

```

### fdtdec_setup_mem_size_base

- 从设备树中读取 `memory`节点,并设置 `gd->ram_size`和 `gd->ram_base`

```c

gd->ram_size = (phys_size_t)(res.end - res.start + 1);

gd->ram_base = (unsignedlong)res.start;


memory@c0000000 {

    device_type = "memory";

    reg = <0xc00000000x2000000>;

};

```

## fdtdec_parse_phandle_with_args 解析phandle和参数
- struct fdtdec_phandle_args *out_args: 输出参数
- out_args.node:list_name的phandle索引到的节点
- out_args.args_count:list_name的phandle索引到的节点下的cells_name属性的值
- out_args.uint32_t args[MAX_PHANDLE_ARGS]:src_node的list_name属性的值
```c
int fdtdec_parse_phandle_with_args(const void *blob, int src_node,
				   const char *list_name,
				   const char *cells_name,
				   int cell_count, int index,
				   struct fdtdec_phandle_args *out_args)
```

# libfdt
## fdt.c

### fdt_check_header 检查fdt头部是否正确
![image-20250116131433785](./assets/image-20250116131433785.png)

### fdt_next_node 根据规则查找下一个节点
```c
int fdt_next_node(const void *fdt, int offset, int *depth)
{
	int nextoffset = 0;
	uint32_t tag;

	if (offset >= 0)
		if ((nextoffset = fdt_check_node_offset_(fdt, offset)) < 0)
			return nextoffset;

	do {
		offset = nextoffset;
		tag = fdt_next_tag(fdt, offset, &nextoffset);

		switch (tag) {
		case FDT_PROP:
		case FDT_NOP:
			break;

		case FDT_BEGIN_NODE:    //开始节点,深度加1
			if (depth)
				(*depth)++;
			break;

		case FDT_END_NODE:    //结束节点,深度减1
			if (depth && ((--(*depth)) < 0))
				return nextoffset;
			break;

		case FDT_END:   //FDT结束
			if ((nextoffset >= 0)
			    || ((nextoffset == -FDT_ERR_TRUNCATED) && !depth))
				return -FDT_ERR_NOTFOUND;
			else
				return nextoffset;
		}
	} while (tag != FDT_BEGIN_NODE);

	return offset;
}
```

### fdt_next_tag 查找下一个标签

## fdt_strerror.c
```c
#define FDT_ERRTABENT(val) \
	[(val)] = { .str = #val, }

static struct fdt_errtabent fdt_errtable[] = {
	FDT_ERRTABENT(FDT_ERR_NOTFOUND),
};

const char *fdt_strerror(int errval)
{
	if (errval > 0)
		return "<valid offset/length>";
	else if (errval == 0)
		return "<no error>";
	else if (-errval < FDT_ERRTABSIZE) {
		const char *s = fdt_errtable[-errval].str;

		if (s)
			return s;
	}

	return "<unknown error>";
}
```

## fdt_ro.c
### fdt_path_offset_namelen 查找路径的偏移量
```c
int fdt_path_offset_namelen(const void *fdt, const char *path, int namelen)
{
	const char *end = path + namelen;
	const char *p = path;
	int offset = 0;

	FDT_RO_PROBE(fdt);

	//检查是否有别名
	if (*path != '/') {
		const char *q = memchr(path, '/', end - p);

		if (!q)
			q = end;
		//查找别名对应的实际路径
		p = fdt_get_alias_namelen(fdt, p, q - p);   // fdt_path_offset(fdt, "/aliases");
		if (!p)
			return -FDT_ERR_BADPATH;
		offset = fdt_path_offset(fdt, p);

		p = q;
	}
	//遍历路径
	while (p < end) {
		const char *q;
		//处理路径中的斜杠
		while (*p == '/') {
			p++;
			if (p == end)
				return offset;
		}
		//查找下一个斜杠
		q = memchr(p, '/', end - p);
		if (! q)	//没有找到斜杠
			q = end;	//则指向路径末尾
		//查找路径节点的偏移量
		offset = fdt_subnode_offset_namelen(fdt, offset, p, q-p);
		if (offset < 0)
			return offset;

		p = q;
	}

	return offset;
}
```

### fdt_subnode_offset_namelen 查找子节点的偏移量
```c
/* fdt:设备树指针
 * offset:父节点的偏移量
 * name:子节点的名称
 * namelen:子节点名称的长度
 */
int fdt_subnode_offset_namelen(const void *fdt, int offset,
			       const char *name, int namelen)
{
	int depth;

	FDT_RO_PROBE(fdt);

	for (depth = 0;
	     (offset >= 0) && (depth >= 0);
	     offset = fdt_next_node(fdt, offset, &depth))   //查找下一个节点
		if ((depth == 1)    //深度为1,达到子节点
		    && fdt_nodename_eq_(fdt, offset, name, namelen))    //比较节点名称正确
			return offset;  //返回子节点的偏移量

	if (depth < 0)
		return -FDT_ERR_NOTFOUND;
	return offset; /* error */
}
```

### fdt_getprop_namelen 查找属性的值

### fdt_num_mem_rsv 查找保留的内存块数量

### fdt_get_mem_rsv 查找保留的内存块的地址和大小

## fdt_rw.c
### fdt_open_into
```c
int fdt_open_into(const void *fdt, void *buf, int bufsize)
{
    //检查设备树的内存块是否需要重新排列
	if (!fdt_blocks_misordered_(fdt, mem_rsv_size, struct_size)) {
        //如果不需要重新排列，函数直接将设备树移动到目标缓冲区，并设置相关的元数据。
		/* no further work necessary */
		err = fdt_move(fdt, buf, bufsize);
		if (err)
			return err;
		fdt_set_version(buf, 17);
		fdt_set_size_dt_struct(buf, struct_size);
		fdt_set_totalsize(buf, bufsize);
		return 0;
	}

	/* Need to reorder */
	newsize = FDT_ALIGN(sizeof(struct fdt_header), 8) + mem_rsv_size
		+ struct_size + fdt_size_dt_strings(fdt);
    //如果需要重新排列，函数计算新的设备树大小 newsize，并检查目标缓冲区是否足够大。如果缓冲区太小，函数返回 -FDT_ERR_NOSPACE 错误码。
	if (bufsize < newsize)
		return -FDT_ERR_NOSPACE;

	/* First attempt to build converted tree at beginning of buffer */
	tmp = buf;
	/* But if that overlaps with the old tree... */
    //函数尝试在目标缓冲区的起始位置构建新的设备树。如果新设备树与旧设备树重叠，函数尝试在旧设备树之后构建新的设备树。
	if (((tmp + newsize) > fdtstart) && (tmp < fdtend)) {
		/* Try right after the old tree instead */
		tmp = (char *)(uintptr_t)fdtend;
		if ((tmp + newsize) > ((char *)buf + bufsize))
			return -FDT_ERR_NOSPACE;
	}
    //函数调用 fdt_packblocks_ 函数重新排列设备树的内存块，并将其移动到目标缓冲区。
	fdt_packblocks_(fdt, tmp, mem_rsv_size, struct_size);
	memmove(buf, tmp, newsize); //将新的设备树移动到目标缓冲区
    //函数设置设备树的元数据
	fdt_set_magic(buf, FDT_MAGIC);
	fdt_set_totalsize(buf, bufsize);
	fdt_set_version(buf, 17);
	fdt_set_last_comp_version(buf, 16);
	fdt_set_boot_cpuid_phys(buf, fdt_boot_cpuid_phys(fdt));

	return 0;
}

```

## libfdt_internal.h

### FDT_ASSUME_MASK

- 定义了FDT_ASSUME_MASK,用于判断是否进行额外的检查;每个位代表一个检查

```c

/*

 * 定义可以启用的假设。每个假设都可以单独启用。为了最大限度的安全性，不要启用任何假设！

 *

 * 为了最小化代码大小和不安全性，可以自行承担风险使用 FDT_ASSUME_PERFECT。

 * 在使用 libfdt 之前，你应该有其他方法来验证设备树，例如签名或哈希检查。

 *

 * 在安全性不是问题的情况下，可以安全地启用 FDT_ASSUME_FRIENDLY。

 */

enum {

    /*

     * 这实际上不进行任何检查。仅正确处理最新版本的设备树。

     * 设备树中的不一致或错误可能会导致未定义的行为或崩溃。

     *

     * 如果在修改设备树时发生错误，可能会使设备树处于中间（但有效）的状态。

     * 例如，在没有足够空间的情况下添加属性，可能会导致属性名称被添加到字符串表中，

     * 即使属性本身没有被添加到结构部分。

     *

     * 仅在你拥有完全验证的设备树并且支持最新版本时使用此选项，以最小化代码大小。

     */

    FDT_ASSUME_PERFECT = 0xff,


    /*

     * 这假设设备树是合理的。即头部元数据和基本层次结构是正确的。

     *

     * 如果你有一个有效的设备树且没有内部不一致，这些检查将是足够的。

     * 在这种假设下，libfdt 通常不会返回 -FDT_ERR_INTERNAL、-FDT_ERR_BADLAYOUT 等错误。

     */

    FDT_ASSUME_SANE = 1 << 0,


    /*

     * 这禁用了设备树版本的检查，并移除了处理旧版本的所有代码。

     *

     * 仅在你知道你拥有最新版本的设备树时启用此选项。

     */

    FDT_ASSUME_LATEST = 1 << 1,


    /*

     * 这禁用了对参数和设备树的广泛检查，做出各种正确性的假设。

     * 由 libfdt 和编译器生成的正常设备树应该可以安全处理。

     * 恶意设备树和完全垃圾数据可能会导致 libfdt 行为不正常或崩溃。

     */

    FDT_ASSUME_FRIENDLY = 1 << 2,

};

/* fdt_chk_basic() - see if basic checking of params and DT data is enabled */

staticinlineboolfdt_chk_basic(void)

{

    return !(FDT_ASSUME_MASK & FDT_ASSUME_SANE);

}


/* fdt_chk_version() - see if we need to handle old versions of the DT */

staticinlineboolfdt_chk_version(void)

{

    return !(FDT_ASSUME_MASK & FDT_ASSUME_LATEST);

}


/* fdt_chk_extra() - see if extra checking is enabled */

staticinlineboolfdt_chk_extra(void)

{

    return !(FDT_ASSUME_MASK & FDT_ASSUME_FRIENDLY);

}

```

# cmd
## fdt.c
### set_working_fdt_addr
```c
/*
 * The working_fdt points to our working flattened device tree.
 */
struct fdt_header *working_fdt;

static void set_working_fdt_addr_quiet(ulong addr)
{
	void *buf;

	buf = map_sysmem(addr, 0);
	working_fdt = buf;
	env_set_hex("fdtaddr", addr);
}

void set_working_fdt_addr(ulong addr)
{
	printf("Working FDT set to %lx\n", addr);
	set_working_fdt_addr_quiet(addr);
}
```

# boot
## boot/fdt_support.c
### fdt_initrd  在FDT中设置initrd的开始和结束地址
```c
int fdt_initrd(void *fdt, ulong initrd_start, ulong initrd_end)
{
	int   nodeoffset;
	int   err, j, total;
	int is_u64;
	uint64_t addr, size;

	/* just return if the size of initrd is zero */
	if (initrd_start == initrd_end)
		return 0;

	/* find or create "/chosen" node. */
	nodeoffset = fdt_find_or_add_subnode(fdt, 0, "chosen");
	if (nodeoffset < 0)
		return nodeoffset;

	total = fdt_num_mem_rsv(fdt);

	//在FDT的内存保留块中查找initrd的地址,则删除该内存保留块,以便用于ramdisk
	for (j = 0; j < total; j++) {
		err = fdt_get_mem_rsv(fdt, j, &addr, &size);
		if (addr == initrd_start) {
			fdt_del_mem_rsv(fdt, j);
			break;
		}
	}
    //将initrd的地址和大小添加到内存保留块中
	err = fdt_add_mem_rsv(fdt, initrd_start, initrd_end - initrd_start);
	if (err < 0) {
		printf("fdt_initrd: %s\n", fdt_strerror(err));
		return err;
	}
    //获取根节点开始的第一个`#address-cells`属性的值,如果是2则表示是64位
    //该节点应是`reserved-memory`节点
	is_u64 = (fdt_address_cells(fdt, 0) == 2);
    //在/chosen中设置属性linux,initrd-start: initrd_start
	err = fdt_setprop_uxx(fdt, nodeoffset, "linux,initrd-start",
			      (uint64_t)initrd_start, is_u64);

	if (err < 0) {
		printf("WARNING: could not set linux,initrd-start %s.\n",
		       fdt_strerror(err));
		return err;
	}
    //在/chosen这种设置属性linux,initrd-end: initrd_end
	err = fdt_setprop_uxx(fdt, nodeoffset, "linux,initrd-end",
			      (uint64_t)initrd_end, is_u64);

	if (err < 0) {
		printf("WARNING: could not set linux,initrd-end %s.\n",
		       fdt_strerror(err));

		return err;
	}

	return 0;
}
```

### fdt_shrink_to_minimum 将给定的 blob 转换成空的 FDT,大小保存不变
- 将给定的 blob 缩小到“最小”大小 。 新大小足以容纳现有内容加上。 加上 5 个内存预留。
- 此外，FDT 的末尾与 4KB 边界对齐，因此它最终可能会比需要大 4KB。 
- 如果 FDT 中存在 @blob 的现有内存预留，则会将其更新为新大小。
- 最终的FDT是一个完整的FDT，大小与之前的FDT相同，但是都被分配为内存预留。

# fdt
## fdt_first_subnode 
- 给出下一个节点的偏移量
```c
int fdt_first_subnode(const void *fdt, int offset)
{
	int depth = 0;

	offset = fdt_next_node(fdt, offset, &depth);
	if (offset < 0 || depth != 1)
		return -FDT_ERR_NOTFOUND;

	return offset;
}
```