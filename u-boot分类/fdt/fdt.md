# fdtdec 扁平设备树解析

- [devicetree](https://docs.u-boot.org/en/latest/develop/devicetree/index.html)

## lib/fdtdec.c

### fdtdec_setup 初始化fdtdec 写入fdt_blob和fdt_src

```c

intfdtdec_setup(void)

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

staticintfdtdec_prepare_fdt(constvoid *blob)

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

### fdt_check_header 检查fdt头部是否正确

![image-20250116131433785](./assets/image-20250116131433785.png)

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

## scripts/dtc/libfdt/libfdt_internal.h

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

## scripts/dtc/libfdt/fdt.c

### fdt_check_header
