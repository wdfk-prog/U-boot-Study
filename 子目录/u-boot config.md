# last
## 设置编译引导加载程序
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

## 设置系统栈指针地址与长度
```c
CONFIG_HAS_CUSTOM_SYS_INIT_SP_ADDR=y
CONFIG_CUSTOM_SYS_INIT_SP_ADDR=0x24040000
CONFIG_ENV_SIZE=0x2000

#define CONFIG_SYS_MALLOC_F 1
#define CONFIG_SYS_MALLOC_F_LEN 0x2000
#define CONFIG_CUSTOM_SYS_INIT_SP_ADDR 0x24040000
```

## 事件功能 CONFIG_EVENT
### EVENT_DEBUG
### EVENT_DYNAMIC

## printf功能
```c
CONFIG_SYS_PBSIZE=282

#define CONFIG_PRINTF 1
#define CONFIG_SYS_PBSIZE 282
```

## 日志功能
```c
CONFIG_LOG=y
CONFIG_LOG_ERROR_RETURN=y
```

## 设备树
```c
CONFIG_OF_CONTROL=y
```
### OFNODE_MULTI_TREE 多设备树

### CONFIG_BLOBLIST 二进制设备树

### CONFIG_OF_LIVE 动态设备树

### CONFIG_OF_REAL 设备树

### CONFIG_OF_PLATDATA_INST 

### OF_PLATDATA_DRIVER_RT 

### OF_PLATDATA_RT 

### DM_SEQ_ALIAS  设备别名

## LIBCOMMON_SUPPORT 通用库支持

## CONFIG_TRACE_EARLY 提前跟踪

## CONFIG_DM_EVENT 驱动事件支持

## CONFIG_SYSINFO 系统信息

## CONFIG_MACH_TYPE
- 机器类型是一个唯一的标识符，用于区分不同的硬件平台。每个硬件平台都有一个唯一的机器类型编号，这个编号在 U-Boot 和 Linux 内核中用于识别和初始化特定的硬件平台。

## CONFIG_SYS_XTRACE
- 启用详细的跟踪信息输出

## CONFIG_CMD_BOOTD
- 当这个宏被定义时，表示在编译 U-Boot 时将包含 bootd 命令的实现。如果这个宏未被定义，则 bootd 命令的相关代码将不会被编译，从而减小 U-Boot 的体积。
- bootd 命令在 U-Boot 中用于启动默认的引导过程。它通常会从环境变量中读取引导配置，并根据这些配置启动操作系统或其他引导目标。以下是一个典型的 bootd 命令的使用示例：

# arch/Kconfig
- [arch](../u-boot分类/arch/arch.md)

# General setup
## BROKEN 标记不稳定的功能
- 当某个功能或模块被认为是不稳定或有问题时，可以将其依赖于 BROKEN 选项。这意味着在配置过程中，如果某个功能依赖于 BROKEN，那么该功能也将无法启用。这是一种确保不稳定或有问题的代码不会被包含在最终构建中的方法。

## DEPRECATED 标记过时的功能
- 当某个功能或模块被认为是过时的时候，可以将其依赖于 DEPRECATED 选项。这意味着在配置过程中，如果某个功能依赖于 DEPRECATED，那么该功能也将无法启用。这是一种确保过时的代码不会被包含在最终构建中的方法。

## 本地版本
### localversion文件创建
- 在U-Boot源码根目录下创建一个名为localversion的文件，文件内容为自定义的版本号字符串，例如：localversion-2020.10
### LOCALVERSION 本地版本自行定义
- 在menuconfig中配置时填写字符串
### LOCALVERSION_AUTO 自动添加版本号
- 这将尝试通过查找属于当前版本树顶部的Git标签来自动确定当前树是否是发布树。
- 如果找到了基于git的树，则将-gxxxxxxxx格式的字符串添加到localversion。由此生成的字符串将附加在任何匹配的localversion*文件之后，以及CONFIG_LOCALVERSION中设置的值之后。(这里实际使用的字符串是运行以下命令产生的前8个字符： $ git rev-parse --verify HEAD 这是在脚本“scripts/setlocalversion”中完成的。)
### 版本信息
- U-Boot 版本按年份和补丁级别命名，例如 2020.10 表示2020 年 10 月发布的版本。每隔一段时间标记一次候选版本
几周，因为项目将进入下一个版本。所以 2020.10-rc1 是第一个候选版本 （RC），在 2020.07 发布后不久标记。
- 一些变量最终位于include/generated/version_autogenerated.h 中，可以通过 C 源代码访问包括 <version.h>
- UBOOTRELEASE （生成文件）: 完整发布版本作为字符串。如果这不是标记的发行版，则它还包括自上一个标签以来的提交数量以及 Git hash。 如果有未提交的更改，则还会添加 '-dirty' 后缀。
- 这是由 scripts/setlocalversion（由 Linux 维护）写入的include/config/uboot.release 并最终出现在 UBOOTRELEASE Makefile 中变量。

## 编译器及编译器版本
```makefile
config CC_IS_GCC
	def_bool $(success,$(CC) --version | head -n 1 | grep -q gcc)

config GCC_VERSION
	int
	default $(shell,$(srctree)/scripts/gcc-version.sh -p $(CC) | sed 's/^0*//') if CC_IS_GCC
	default 0

config CC_IS_CLANG
	def_bool $(success,$(CC) --version | head -n 1 | grep -q clang)

config CLANG_VERSION
	int
	default $(shell,$(srctree)/scripts/clang-version.sh $(CC))

config CC_HAS_ASM_INLINE
    def_bool $(success,$(CC) -c -x assembler - -o /dev/null - < /dev/null)
```

## 优化选项
### Optimization level 优化级别
```makefile
# 顶层Makefile
ifdef CONFIG_CC_OPTIMIZE_FOR_SIZE
KBUILD_CFLAGS	+= -Os
endif

ifdef CONFIG_CC_OPTIMIZE_FOR_SPEED
KBUILD_CFLAGS	+= -O2
endif

ifdef CONFIG_CC_OPTIMIZE_FOR_DEBUG
KBUILD_CFLAGS	+= -Og
# Avoid false positives -Wmaybe-uninitialized
# https://gcc.gnu.org/bugzilla/show_bug.cgi?id=78394
KBUILD_CFLAGS	+= -Wno-maybe-uninitialized
endif
```

#### CC_OPTIMIZE_FOR_SIZE 尺寸优先
- -Os
#### CC_OPTIMIZE_FOR_SPEED 速度优先
- -O2
#### CC_OPTIMIZE_FOR_DEBUG 调试优先
- -Og
### TOOLS_DEBUG
- 加入-g选项
- 如果主要目的是调试代码并需要详细的调试信息，可以使用 -g。如果希望在调试过程中仍然保持一定的性能，可以使用 -Og。
### REMAKE_ELF 重新生成ELF文件
```makefile
quiet_cmd_u-boot-elf ?= LD      $@
	cmd_u-boot-elf ?= $(LD) u-boot-elf.o -o $@ \
	$(if $(CONFIG_SYS_BIG_ENDIAN),-EB,-EL) \
	-T u-boot-elf.lds --defsym=$(CONFIG_PLATFORM_ELFENTRY)=$(CONFIG_TEXT_BASE) \
	-Ttext=$(CONFIG_TEXT_BASE)
INPUTS-$(CONFIG_REMAKE_ELF) += u-boot.elf
```

### OPTIMIZE_INLINING 取消内联优化

### LTO(链接时优化)选项
- LTO（Link Time Optimization）是 GCC 的一个功能，它允许在链接时对整个程序进行优化。这种优化可以提高程序的性能，但会增加编译时间和链接时间。在 U-Boot 中，可以通过配置 CONFIG_LTO 选项来启用 LTO 功能。
- LTO 是一种优化技术，它在链接阶段对整个程序进行全局优化，而不仅仅是在编译单个源文件时进行优化。LTO 可以带来更好的优化效果，例如更好的内联、消除冗余代码和更有效的代码布局，从而提高程序的运行性能。
- 启用 LTO 后，编译器在编译单个源文件时不会进行最终的优化，而是将优化信息保留到链接阶段。这可能会使单个源文件的编译速度稍微加快，因为编译器在编译阶段做的工作较少。但是，在链接阶段，链接器需要对整个程序进行全局优化，这会增加链接时间。链接器需要处理所有的优化信息，并对整个程序进行优化，这通常比普通的链接过程要耗时得多。

## ENV_VARS_UBOOT_CONFIG 保存环境变量
- 将 arch、board、vendor 和 soc 变量添加到默认环境
```c
//include/env_default.h
#ifdef	CONFIG_ENV_VARS_UBOOT_CONFIG
	"arch="		CONFIG_SYS_ARCH			"\0"
#ifdef CONFIG_SYS_CPU
	"cpu="		CONFIG_SYS_CPU			"\0"
#endif
#ifdef CONFIG_SYS_BOARD
	"board="	CONFIG_SYS_BOARD		"\0"
	"board_name="	CONFIG_SYS_BOARD		"\0"
#endif
#ifdef CONFIG_SYS_VENDOR
	"vendor="	CONFIG_SYS_VENDOR		"\0"
#endif
#ifdef CONFIG_SYS_SOC
	"soc="		CONFIG_SYS_SOC			"\0"
#endif
#ifdef CONFIG_USB_HOST
	"usb_ignorelist="
#ifdef CONFIG_USB_KEYBOARD
	/* Ignore Yubico devices. Currently only a single USB keyboard device is
	 * supported and the emulated HID keyboard Yubikeys present is useless
	 * as keyboard.
	 */
	"0x1050:*,"
#endif
	"\0"
#endif
#ifdef CONFIG_ENV_IMPORT_FDT
	"env_fdt_path="	CONFIG_ENV_FDT_PATH		"\0"
#endif
#endif
```

## 启用内核命令行设置
### SYS_BOOT_GET_CMDLINE  获取内核命令行
- 允许在间隙中分配和保存内核cmdline;“bootm_low”~“bootm_low”+ BOOTMAPSZ

### SYS_BARGSIZE 内核命令行长度

## SYS_BOOT_GET_KBD 保存kernel bd_info
- 允许在间隙中分配和保存内核bd_info;“bootm_low”~“bootm_low”+ BOOTMAPSZ

## HAS_CUSTOM_SYS_INIT_SP_ADDR 自定义系统栈指针地址
- 允许自定义系统栈指针地址
- 例如stm32h7的系统栈指针地址为0x24040000

## malloc功能
### SYS_MALLOC_F_LEN    第一次内存分配长度
### SYS_MALLOC_LEN      重定向之后的内存分配长度
### VALGRIND            内存分配调试
- arm32 不支持
### SYS_MALLOC_CLEAR_ON_INIT 初始化时清除内存 设置为0
### SYS_MALLOC_DEFAULT_TO_INIT 内存分配默认需要初始化
- 从一个内存移动到另一种内存时,需要初始化才可使用

## BINMAN 二进制文件管理
- 固件通常由几个必须包装在一起的组件。例如，我们可能有SPL，U-Boot，Devicetree和一个将环境区域分组在一起并放置在MMC闪存中。当系统启动时，它必须能够找到这些零件。
- 构建固件应与包装不同。现代固件构建系统的许多复杂性来自尝试一次做。使用Binman，您可以使用任何需要各种项目和构建系统来构建所有需要的部分，然后使用Binman将所有内容缝合在一起。
- Binman读取您的板子的Devicetree，并找到一个描述所需镜像布局的节点。它使用它来弄清楚该放置的位置。
- Binman提供了一种构建图像的机制，从简单的SPL + U-Boot组合到与许多部分的更复杂的布置。它还允许用户检查其中的图像，提取和替换其中的二进制文件，并在需要时重新包装。
- Fit是U-Boot的官方图像格式。它支持具有负载 /执行地址的多个二进制文件，即压缩。它还通过哈希和RSA签名来支持验证。
- FIT最初设计为支持启动Linux内核（带有可选的Ramdisk），并从拟合中的各种选项中选择Devicetree。现在，U-Boot支持通过Devicetree的配置，可以使用SPL选择的Devicetree从拟合中加载U-Boot。

## BUILD_TARGET 生成目标
- 某些 SoC 需要特殊的映像类型（例如 U-Boot 二进制文件 替换为特殊标头）作为构建目标。通过定义  CONFIG_BUILD_TARGET SoC / 板头中，此特殊镜像将在调用make / buildman 的 build 中。
```c
	default "u-boot-elf.srec" if RCAR_64
	default "u-boot-with-spl.bin" if ARCH_AT91 && SPL_NAND_SUPPORT
	default "u-boot-with-spl.bin" if MPC85xx && !E500MC && !E5500 && !E6500 && SPL
	default "u-boot-with-spl.imx" if ARCH_MX6 && SPL
	default "u-boot-with-spl.kwb" if ARMADA_32BIT && SPL
	default "u-boot-with-spl.sfp" if TARGET_SOCFPGA_ARRIA10
	default "u-boot-with-spl.sfp" if TARGET_SOCFPGA_GEN5
	default "u-boot.itb" if !BINMAN && SPL_LOAD_FIT && (ARCH_ROCKCHIP || \
				RISCV || ARCH_ZYNQMP)
	default "u-boot.kwb" if (ARCH_KIRKWOOD || ARMADA_32BIT) && !SPL
```

## SYS_CUSTOM_LDSCRIPT 自定义链接脚本路径

## SYS_LOAD_ADDR 内存使用的加载地址

## PLATFORM_ELFENTRY 平台ELF入口地址
- 最开始的代码的地址