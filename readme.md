[toc]

# art-pi构建命令

```sh
make CROSS_COMPILE=arm-none-eabi- ARCH=arm stm32h750-art-pi_defconfig
make CROSS_COMPILE=arm-none-eabi- ARCH=arm menuconfig
	> Boot options        (console=ttySTM0,115200 root=/dev/ram loglevel=8) Boot arguments
	> Device Drivers > Serial drivers        (115200) Default baudrate
u-boot-v2021.07\arch\arm\dts\stm32h750i-art-pi.dts
	chosen {
		bootargs = "root=/dev/ram";
		stdout-path = "serial0:2000000n8";
	};
	chosen {
		bootargs = "root=/dev/ram";
		stdout-path = "serial0:115200n8";
	};
make CROSS_COMPILE=arm-none-eabi- ARCH=arm -j3
```

# Makefile

- 查看[Makefile.md](./子目录/Makefile.md)
- 学习的Makefile如下:[Makefile](./学习芯片/ART-PI/Makefile)

## 功能

### V=1 显示完成命令输出

- `V=1`：告诉 `make` 显示完成的命令输出。这对于调试构建过程非常有用，因为它可以显示构建过程中执行的所有命令。
- 没有设置 `V` 时，`make` 默认不显示命令输出。
- 其中 `Q = @`,`@`用于抑制命令的输出

```makefile
# make V=1 显示完成命令输出
ifeq ("$(origin V)", "command line")	#获取V是否输入
  KBUILD_VERBOSE = $(V)	# KBUILD_VERBOSE = 1
endif
ifndef KBUILD_VERBOSE	# 如果没有输入V,则KBUILD_VERBOSE = 0
  KBUILD_VERBOSE = 0
endif

ifeq ($(KBUILD_VERBOSE),1)	# 如果KBUILD_VERBOSE = 1,则显示完成命令输出
  quiet =
  Q =
else	# 否则不显示完成命令输出
  quiet=quiet_
  Q = @
endif
```

### -s 静默模式

- `-s`：告诉 `make` 进入静默模式。在静默模式下，`make` 不会显示构建过程中执行的命令。
- 设置 `quiet`变量为 `silent_`，这样就可以在构建过程中使用 `$(quiet)`前缀来隐藏命令的输出。

```makefile
ifneq ($(filter 4.%,$(MAKE_VERSION)),)	# make-4
ifneq ($(filter %s ,$(firstword x$(MAKEFLAGS))),)
  quiet=silent_
endif
else					# make-3.8x
ifneq ($(filter s% -s%,$(MAKEFLAGS)),)
  quiet=silent_
endif
endif
```

### O= 输出目录

```sh
make CROSS_COMPILE=arm-none-eabi- ARCH=arm -j3 O=output/
```

- 使用 `KBUILD_SRC`设置输出目录。使用 `O`变量设置输出目录，如果 `O`变量没有设置，则使用 `KBUILD_SRC`变量设置输出目录。

```makefile
ifeq ($(KBUILD_SRC),)
    ifeq ("$(origin O)", "command line")
    KBUILD_OUTPUT := $(O)
endif
```

### C=1 启用静态检查

- 使用 'make C=1' 来启用仅检查重新编译的文件。
- 使用 'make C=2' 来启用对 *所有* 源文件的检查，无论它们是否被重新编译。

### M = 构建的外部模块的目录

- 使用 make M=dir 指定要构建的外部模块的目录
- 旧语法 make ...SUBDIRS=$PWD 仍受支持
- 设置环境变量KBUILD_EXTMOD优先

### cc-option CC编译器选项测试检查

```makefile
# output 目录进行以下测试
# 如果 KBUILD_EXTMOD 被定义，则使用其第一个值作为临时输出目录；否则，TMPOUT 为空。
TMPOUT := $(if $(KBUILD_EXTMOD),$(firstword $(KBUILD_EXTMOD))/)

# try-run
# Usage: option = $(call try-run, $(CC)...-o "$$TMP",option-ok,otherwise)
# 退出代码选择选项。“$$TMP” 可以用作临时文件，并会自动清理。
# 针对 U-Boot 进行了修改：防止 cc-option 留下 .*.su 文件

# set -e 确保在命令失败时立即退出。
# 定义了三个临时文件，分别用于存储编译输出和中间文件。$$$$ 用于生成唯一的文件名。
# 执行编译命令 $(1)，并根据其退出状态选择输出。如果编译成功，输出 $(2)；否则，输出 $(3)。
# 删除临时文件，确保不会留下多余的文件。
try-run = $(shell set -e;		\
    TMP="$(TMPOUT).$$$$.tmp";	\
    TMPO="$(TMPOUT).$$$$.o";	\
    TMPSU="$(TMPOUT).$$$$.su";	\
    if ($(1)) >/dev/null 2>&1;	\
    then echo "$(2)";		\
    else echo "$(3)";		\
    fi;				\
    rm -f "$$TMP" "$$TMPO" "$$TMPSU")

# __cc-option
# Usage: MY_CFLAGS += $(call __cc-option,$(CC),$(MY_CFLAGS),-march=winchip-c6,-march=i586)
# $(1) 表示编译器命令（如 $(CC)）。
# $(2) 表示已有的编译标志。
# $(3) 表示要测试的编译选项。
# $(4) 表示备用选项。
# 宏会尝试编译一个空的 C 文件 null，并将输出重定向到临时文件 $$TMP。如果编译成功，则返回 $(3)，否则返回 $(4)
__cc-option = $(call try-run,\
    $(1) -Werror $(2) $(3) -c -x c /dev/null -o "$$TMP",$(3),$(4))

# cc-option
# Usage: cflags-y += $(call cc-option,-march=winchip-c6,-march=i586)
# 编译器CC 编译条件KBUILD_CPPFLAGS KBUILD_CFLAGS 成功返回$(1) 失败返回$(2)
cc-option = $(call __cc-option, $(CC),\
    $(KBUILD_CPPFLAGS) $(KBUILD_CFLAGS),$(1),$(2))
```

### scripts 用于构建脚本的工具

- 查看[scripts.md](./子目录/scripts.md)

### Kconfig 相关的功能

- `Kconfig` 是一个配置文件，用于定义内核的配置选项。它使用一种类似于 C 语言的语法，包含一系列配置选项和依赖关系。`Kconfig` 文件通常由 `Kconfig` 工具解析，生成配置文件（`.config`）。


```shell
config          - 使用行定向程序更新当前配置
nconfig         - 使用基于 ncurses 菜单的程序更新当前配置
menuconfig      - 使用基于菜单的程序更新当前配置
xconfig         - 使用基于 Qt 前端的程序更新当前配置
gconfig         - 使用基于 GTK+ 前端的程序更新当前配置
oldconfig       - 使用提供的 .config 作为基础更新当前配置
localmodconfig  - 更新当前配置，禁用未加载的模块
localyesconfig  - 更新当前配置，将本地模块转换为核心
defconfig       - 使用 ARCH 提供的默认配置创建新配置
savedefconfig   - 将当前配置保存为 ./defconfig（最小配置）
allnoconfig     - 创建一个所有选项都回答为 no 的新配置
allyesconfig    - 创建一个所有选项都接受为 yes 的新配置
allmodconfig    - 创建一个尽可能选择模块的新配置
alldefconfig    - 创建一个所有符号都设置为默认值的新配置
randconfig      - 创建一个所有选项都随机回答的新配置
listnewconfig   - 列出新选项
olddefconfig    - 与 oldconfig 相同，但将新符号设置为默认值而不提示
testconfig      - 运行 Kconfig 单元测试（需要 python3 和 pytest）
```

- 强制使用需修改Kconfig文件




```makefile
mainmenu "U-Boot $(UBOOTVERSION) Configuration"
srctree := .
CC = $(CROSS_COMPILE)gcc
```

#### config 使用行定向程序更新当前配置



- 通过命令 `./scripts/kconfig/conf --oldaskconfig Kconfig`运行

- 运行的是命令行版本的配置工具，用于解析Kconfig文件并生成配置文件。

```shell
*
* U-Boot  Configuration
*
*
* Compiler: 
*
Architecture select
  1. ARC architecture (ARC)
> 2. ARM architecture (ARM)
  3. M68000 architecture (M68K)
  4. MicroBlaze architecture (MICROBLAZE)
  5. MIPS architecture (MIPS)
  6. Nios II architecture (NIOS2)
  7. PowerPC architecture (PPC)
  8. RISC-V architecture (RISCV)
  9. Sandbox (SANDBOX)
  10. SuperH architecture (SH)
  11. x86 architecture (X86)
  12. Xtensa architecture (XTENSA)
choice[1-12?]: 2
*
* Skipping low level initialization functions
*
Skip calls to certain low level initialization functions (SKIP_LOWLEVEL_INIT) [N/y/?] N
Skip call to lowlevel_init during early boot ONLY (SKIP_LOWLEVEL_INIT_ONLY) [N/y/?] N
*
* ARM architecture
*
ARM GICV2 driver (DRIVER_GICV2) [N/y/?] N
ARM GICV3 ITS (GIC_V3_ITS) [N/y/?] N
ARM GICV3 GIC600 SUPPORT (GICV3_SUPPORT_GIC600) [N/y/?] N
Do not enable icache (SYS_ICACHE_OFF) [N/y/?] N
Do not enable dcache (SYS_DCACHE_OFF) [N/y/?] N
CP15 based cache enabling support (SYS_ARM_CACHE_CP15) [N/y/?] N
MMU-based Paged Memory Management Support (SYS_ARM_MMU) [N/y/?] N
Use the ARM v7 PMSA Compliant MPU (SYS_ARM_MPU) [Y/?] y
Select the ARM data write cache policy
> 1. Write-back (WB) (SYS_ARM_CACHE_WRITEBACK)
  2. Write-through (WT) (SYS_ARM_CACHE_WRITETHROUGH)
  3. Write allocation (WA) (SYS_ARM_CACHE_WRITEALLOC)
choice[1-3?]: 0
Select the ARM data write cache policy
> 1. Write-back (WB) (SYS_ARM_CACHE_WRITEBACK)
  2. Write-through (WT) (SYS_ARM_CACHE_WRITETHROUGH)
  3. Write allocation (WA) (SYS_ARM_CACHE_WRITEALLOC)
choice[1-3?]: 1
Enable ARCH_CPU_INIT (ARCH_CPU_INIT) [N/y/?] n
Build U-Boot using the Thumb instruction set (SYS_THUMB_BUILD) [Y/?] y

ARM PL310 L2 cache controller (SYS_L2_PL310) [N/y/?] n
ARM PL310 L2 cache controller in SPL (SPL_SYS_L2_PL310) [N/y/?] ^C

embedsky@ubuntu:~/share/u-boot$ ./scripts/kconfig/conf --oldaskconfig Kconfig 
```


- 用法

```shell
--listnewconfig         列出新的选项
--oldaskconfig          使用行定向程序开始新的配置
--oldconfig             使用提供的 .config 文件作为基础更新配置
--syncconfig            类似于 oldconfig，但生成的配置文件位于 include/{generated/,config/}
--olddefconfig          与 oldconfig 相同，但将新符号设置为默认值
--defconfig <file>      使用 <file> 中定义的默认值创建新的配置
--savedefconfig <file>  将当前最小配置保存到 <file>
--allnoconfig           创建一个所有选项都回答为 no 的新配置
--allyesconfig          创建一个所有选项都回答为 yes 的新配置
--allmodconfig          创建一个所有选项都回答为 mod 的新配置
--alldefconfig          创建一个所有符号都设置为默认值的新配置
--randconfig            创建一个所有选项都随机回答的新配置
```

- 代码解析

```c
int main(int ac, char **av)
{
    const char *progname = av[0];
    int opt;
    const char *name, *defconfig_file = NULL /* gcc uninit */;
    struct stat tmpstat;
    int no_conf_write = 0;

    tty_stdio = isatty(0) && isatty(1); //判断标准输入输出是否指向终端
  //从命令行获取短选项-s参数或者long_opts结构体的选项
  // 执行对应配置操作
  while ((opt = getopt_long(ac, av, "s", long_opts, NULL)) != -1) {
    //如果存在-s参数,则设置消息输出回调为空,即不输出消息
    if (opt == 's') {
      conf_set_message_callback(NULL);
      continue;
        }
  }
  //如果 ac 等于 optind，则表示没有提供额外的命令行参数，即没有提供配置文件
  if (ac == optind) {
        fprintf(stderr, "%s: Kconfig file missing\n", av[0]);
        conf_usage(progname);
        exit(1);
    }
  //获取配置文件
  name = av[optind];
    //执行配置操作
  //通过scripts/kconfig/zconf.y 使用 bison -d zconf.y 生成 zconf.tab.c
  //这里会需要进行用户配置
  conf _parse(name);
  //执行配置操作


    re turn 0;
}

```
 
#### menuconfig 使用基于菜单的程序更新当前配置


- 通过命令 `./scripts/kconfig/mconf Kconfig `运行
- 运行的是menuconfig的配置工具，使用基于菜单的程序更新当前配置

```shell
embedsky@ubuntu:~/share/u-boot$ ./scripts/kconfig/mconf Kconfig 
.config:37:warning: symbol value '' invalid for ENV_OFFSET
.config:38:warning: symbol value '' invalid for ENV_SECT_SIZE
.config:47:warning: symbol value '' invalid for TPL_STACK
.config:52:warning: symbol value '' invalid for SYS_LOAD_ADDR
.config:57:warning: symbol value '' invalid for PRE_CON_BUF_ADDR
.config:108:warning: symbol value '' invalid for BOARD_SIZE_LIMIT
.config:116:warning: symbol value '' invalid for SYS_MONITOR_BASE
.config:827:warning: symbol value '' invalid for SYS_SATA_MAX_DEVICE

WARNING: unmet direct dependencies detected for NPCM_OTP
  Depends on [n]: ARM [=n] && ARCH_NPCM [=n]
  Selected by [y]:
  - NPCM_AES [=y]
Your display is too small to run Menuconfig!
It m ust be at least 19 lines by 80 columns.
 

WAING: unmet direct dependencies detected for NPCM_OTP
 Dpends on [n]: ARM [=n] && ARCH_NPCM [=n]
 S lected by [y]:
- NP CM_AES [=y]



 configuration changes were NOT saved.

`


建说明



执 make xxx_defconfig`时，会执行conf可执行文件的编译
后执 `./scripts/kconfig/conf --defconfig=generated_defconfig Kconfig`命令，生成配置文件

`ma

kefile
# scripts/kcon fig/Makefile  
  

 %defconfig: $(obj)/conf
    $(Q)$(CPP) -nostdinc -P -I $(srctree) -undef -x assembler-with-cpp $(srctree)/arch/$(SRCARCH)/configs/$@ -o generated_defconfig
    $(Q)$< $(silent) --defconfig=generated_defconfig $(Kconfig)
```


  
  - 展开为   
  



  ```shell
  arm-none-eabi-gcc -E -nostdinc -P -I . -undef -x assembler-with-cpp ./arch/../configs/stm32h750-art-pi_defconfig -o generated_defconfig
  nfig/conf  --defconfig=generated_defconfig Kconfig
  ```



  

## 构建流程

- [make -p 查看变量](./分析文件/make%20all变量.log)
- [流程参考](./子目录/UBOOT编译---%20make%20xxx_deconfig过程详解(一)%20-%20BSP-路人甲%20-%20博客园.mhtml)

### Ubootb编译第一步通常是执行make xxx_config



- 在编译指定顶层目录生成.c onfig文件，这种方式要求厂商 提供一个基础的xxx_config文件(通常来说开发者不会通过执行make menuconfig从零开始配置，这个工作过量太大了)。

- 查看编译流程时,优先查看 `xxx:`这类可执行目标;如果make 没有带目标时,则优先查看第一个目标,因为是执行的这个目标;从头开始查看,需要注意查看 `include`是否引入的 `xxx:`
- 这里的目标是 `xxx_config:`,即 `%config:`



```makefile
# 定义了一个模式规则，匹配所有以 config 结尾的目标
%config: scripts_basic outputmakefile FORCE
	$(Q)$(MAKE) $(build)=scripts/kconfig $@
```


- %config 还会依赖于 `scripts_basic`和 `outputmakefile`，`FORCE`是一个空目标，用于强制执行规则。



#### build变量的定义

- 观察顶层makefile

```makefile
# 我们需要一些通用定义（不要尝试重新制作文件）。
# 里面定义了$(build)
scripts/Kbuild.include: ;
include scripts/Kbuild.include
```

- 在scripts/Kbuild.include 中定义：

```makefile

###

# Shorthand for $(Q)$(MAKE) -f scripts/Makefile.build obj=
# Usage:
# $(Q)$(MAKE) $(build)=dir
build := -f $(srctree)/scripts/Makefile.build obj
```

#### 编译scripts_basic 生成fixep

- [参考](./子目录/scripts.md)

#### outputmakefile 生成Makefile

#### 执行scripts/kconfi
g Makefile


#### 编译生成conf

#### 执行conf --defconfig=generated_defconfig Kconfig

#### include/config/auto.conf、 include/config/auto.conf.cmd、 include/generated/autoconf.h

- [参考](./子目录/UBOOT编译---%20include_config_auto.conf、%20include_config_auto.conf.cmd、%20include_generated_autoconf.h%20(二)%20-%20BSP-路人甲%20-%20博客园.mhtml)

### Ubootb编译 执行make 操作

- [参考](./子目录/UBOOT编译---%20UBOOT编译过程目标依赖分析(八)%20-%20BSP-路人甲%20-%20博客园.mhtml)
- [详细](./子目录/u-boot_make.md)

# shell 命令

- 查看[shell.md](./子目录/shell%20命令.md)

# GNU C

- 查看[GNU C.md](./子目录/GNU_C.md)

# Bison && Flex

- - 查看[son &amp;&amp; Flex.md](./子目录/Bison_Flex.md)

# map分析
- [u-boot.map](./学习芯片/ART-PI/u-boot.map)


# U -BOOT

### VPL（Very Early Program Loader）

* **功能** ：VPL 是 U-Boot 的非常早期引导加载程序，通常用于在极其受限的环境中进行最基本的硬件初始化。
* **位置** ：VPL 通常位于存储设备的固定位置，类似于 SPL 和 TPL。
* **作用** ：VPL 的主要任务是加载并执行 TPL，以便进一步初始化系统并准备加载 SPL。

### SPL（Secondary Program Loader）

* **功能** ：SPL 是 U-Boot 的第二阶段引导加载程序，通常用于初始化基本的硬件资源，如内存控制器、时钟和电源管理等。
* **位置** ：SPL 通常位于存储设备的固定位置，如 NAND、NOR 闪存或 SD 卡的特定扇区。
* **作用** ：SPL 的主要任务是加载并执行 U-Boot 的主引导加载程序（即 U-Boot 本身），以便进一步初始化系统并启动操作系统。

### TPL（Tertiary Program Loader）

* **功能** ：TPL 是 U-Boot 的第三阶段引导加载程序，通常用于在资源受限的环境中进一步初始化硬件资源。
* **位置** ：TPL 通常位于存储设备的固定位置，类似于 SPL。
* **作用** ：TPL 的主要任务是加载并执行 SPL，以便进一步初始化系统并准备加载 U-Boot 主引导加载程序。
