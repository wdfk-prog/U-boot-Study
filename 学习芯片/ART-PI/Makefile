# 学习的构建命令如下
# make CROSS_COMPILE=arm-none-eabi- ARCH=arm stm32h750-art-pi_defconfig
# make CROSS_COMPILE=arm-none-eabi- ARCH=arm menuconfig

# 比如当前的 uboot 2025.01。EXTRAVERSION 是附加版本信息，NAME 是和名字有关的，一般不使用这两个。
VERSION = 2025		#VERSION 是主版本号
PATCHLEVEL = 01		#PATCHLEVEL 是补丁版本号
SUBLEVEL =			#SUBLEVEL 是次版本号
EXTRAVERSION = -rc6
NAME =

# *文档*
# 要查看典型目标的列表，请执行 “make help”
# 更多信息可以在 ./README 中找到
# 此文件中的注释仅针对开发人员，不要指望学习如何构建读取此文件的内核。


# 不要使用 make 的内置规则和变量（这提高了性能并避免了难以调试的行为）
# `-r`：告诉 `make` 不要使用内置的隐含规则。这可以加快构建过程，因为 `make` 不会尝试使用默认的规则来构建目标。
# `-R`：告诉 `make` 不要使用内置的变量。这可以防止内置变量干扰你的 Makefile 中定义的变量。
MAKEFLAGS += -rR # 将 -rR 选项添加到 make 命令的默认选项中。

# 确定 Sandbox 的目标体系结构
include include/host_arch.h
# 获取需要编译的的体系结构
ifeq ("", "$(CROSS_COMPILE)")	# 如果 CROSS_COMPILE(交叉编译器) 为空执行
  MK_ARCH="${shell uname -m}"	# 获取主机的体系结构
else							# 匹配输入的CROSS_COMPILE值
  MK_ARCH="${shell echo $(CROSS_COMPILE) | sed -n 's/^\(.*ccache\)\{0,1\}[[:space:]]*\([^\/]*\/\)*\([^-]*\)-[^[:space:]]*/\3/p'}"
endif

# MK_ARCH = arm-none-eabi-
unexport HOST_ARCH
# 获取需要编译的体系结构
ifeq ("x86_64", $(MK_ARCH))
  export HOST_ARCH=$(HOST_ARCH_X86_64)
else ifneq (,$(findstring $(MK_ARCH), "i386" "i486" "i586" "i686"))
  export HOST_ARCH=$(HOST_ARCH_X86)
else ifneq (,$(findstring $(MK_ARCH), "aarch64" "armv8l"))
  export HOST_ARCH=$(HOST_ARCH_AARCH64)
else ifneq (,$(findstring $(MK_ARCH), "arm" "armv7" "armv7a" "armv7l"))
# 在MK_ARCH中寻找匹配后面参数的字符串，如果找到则返回该字符串，否则返回空字符串
# 非空字符串则执行
  export HOST_ARCH=$(HOST_ARCH_ARM)
else ifeq ("riscv32", $(MK_ARCH))
  export HOST_ARCH=$(HOST_ARCH_RISCV32)
else ifeq ("riscv64", $(MK_ARCH))
  export HOST_ARCH=$(HOST_ARCH_RISCV64)
endif
# HOST_ARCH = HOST_ARCH_ARM
undefine MK_ARCH

# 避免有趣的字符集依赖项,使用ASCII字符集排序
unexport LC_ALL
LC_COLLATE=C
LC_NUMERIC=C
export LC_COLLATE LC_NUMERIC

# 避免干扰 shell 环境设置
unexport GREP_OPTIONS

# 我们使用的是递归构建，因此我们需要做一些思考来获得正确的排序。
# 最重要的是：子 Makefile 应该只修改它们自己目录中的文件。
# 如果在某个目录中，我们依赖于另一个目录中的文件（这种情况并不经常发生，
# 但在链接最终变成 vmlinux 的 built-in.o 目标时通常是不可避免的），
# 我们将在另一个目录中调用一个 sub make，然后我们确保该另一个目录中的所有内容现在都是最新的。
# 因此，我们需要修改具有全局效果的文件的唯一情况是分开的，并在递归降序开始之前完成。
# 现在，它们被显式列为 prepare 规则。

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

# If the user is running make -s (silent mode), suppress echoing of
# commands

ifneq ($(filter 4.%,$(MAKE_VERSION)),)	# make-4
ifneq ($(filter %s ,$(firstword x$(MAKEFLAGS))),)
  quiet=silent_
endif
else					# make-3.8x
ifneq ($(filter s% -s%,$(MAKEFLAGS)),)
  quiet=silent_
endif
endif

export quiet Q KBUILD_VERBOSE

# KBuit 支持将输出文件保存在单独的目录中。
# 要在单独的目录中查找输出文件，支持两种语法。
# 在这两种情况下，工作目录都必须是内核 src 的根目录。
# 1） O= 使用“make O=dir/to/store/output/files/”
#
# 2） 设置 KBUILD_OUTPUT
# 将环境变量 KBUILD_OUTPUT 设置为指向应放置输出文件的目录。
# 导出 KBUILD_OUTPUT=dir/to/store/output/files/
# 做# O= 赋值优先于 KBUILD_OUTPUT 环境变量。


# KBUILD_SRC 在 OBJ 目录中调用 make 时设置
# KBUILD_SRC 目前不适合普通用户使用
ifeq ($(KBUILD_SRC),)

# 使用O命令选项指定输出目录
ifeq ("$(origin O)", "command line")
  KBUILD_OUTPUT := $(O)
endif

# 这是我们的默认目标，当命令行上没有给出
PHONY := _all
_all:

# 取消 top Makefile 上的隐式规则
$(CURDIR)/Makefile Makefile: ;

ifneq ($(KBUILD_OUTPUT),)
# 在输出目录中调用第二个 make，传递相关变量检查输出目录是否实际存在
saved-output := $(KBUILD_OUTPUT)
# 不存在目录则创建目录,获取目录的绝对路径并赋给变量KBUILD_OUTPUT
KBUILD_OUTPUT := $(shell mkdir -p $(KBUILD_OUTPUT) && cd $(KBUILD_OUTPUT) \
								&& /bin/pwd)
#判定路径存在不输出提示,判定路径不存在输出提示
$(if $(KBUILD_OUTPUT),, \
     $(error failed to create output directory "$(saved-output)"))

# 查找相对于内核 src 根目录的 make include 文件
# 这不会立即生效，因为 MAKEFLAGS 在读取 Makefile 后会重新解析一次。 这是可以的，因为我们要调用
# 'sub-make' 的

MAKEFLAGS += --include-dir=$(CURDIR)

PHONY += $(MAKECMDGOALS) sub-make
# 从 MAKECMDGOALS 中过滤掉 _all sub-make $(CURDIR)/Makefile,确保这些目标不会被重复执行。
$(filter-out _all sub-make $(CURDIR)/Makefile, $(MAKECMDGOALS)) 
_all: sub-make	# 确保先执行 sub-make再执行_all @:是空命令
	@:

# 执行在KBUILD_OUTPUT目录下的子 make
sub-make: FORCE #FORCE 确保每次都执行
# $(Q) 用于控制是否显示命令 在上面定义
# MAKE等同于make,使用 `$(MAKE)` 而不是直接调用 `make` 的好处是，它会继承当前 `make` 的所有参数和选项。
# -C 表示切换到指定目录执行 make 命令,然后在该目录中执行后续的命令。这意味着所有的相对路径和文件操作都会基于这个新目录，而不是原始的工作目录。
# -f 指定要使用的 Makefile 文件
# 在指定的目录中重新过滤 MAKECMDGOALS，确保不会重复执行 _all sub-make $(CURDIR)/Makefile
	$(Q)$(MAKE) -C $(KBUILD_OUTPUT) KBUILD_SRC=$(CURDIR) \
	-f $(CURDIR)/Makefile $(filter-out _all sub-make,$(MAKECMDGOALS))

# 将处理留给上述 make 调用
skip-makefile := 1
endif # ifneq ($(KBUILD_OUTPUT),)
endif # ifeq ($(KBUILD_SRC),)

# 如果这是 make 的最终调用，我们将处理 Makefile 的其余部分
ifeq ($(skip-makefile),)

# 不要打印 “正在输入目录...”，但是我们想在进入 output 目录时显示它以便 IDE/编辑器能够理解相对文件名。
MAKEFLAGS += --no-print-directory

# 调用源代码检查器（默认为 “sparse”）作为 C 编译。
# 使用 'make C=1' 来启用仅检查重新编译的文件。
# 使用 'make C=2' 来启用对 *所有* 源文件的检查，无论它们是否被重新编译。
# 有关更多详细信息，请参阅文件 “doc/sparse.txt”，包括从何处获取 “sparse” 实用程序。


ifeq ("$(origin C)", "command line")
  KBUILD_CHECKSRC = $(C)
endif
ifndef KBUILD_CHECKSRC
  KBUILD_CHECKSRC = 0
endif

# 使用 make M=dir 指定要构建的外部模块的目录
# 旧语法 make ...SUBDIRS=$PWD 仍受支持
# 设置环境变量KBUILD_EXTMOD优先

ifdef SUBDIRS
  KBUILD_EXTMOD ?= $(SUBDIRS)
endif

ifeq ("$(origin M)", "command line")
  KBUILD_EXTMOD := $(M)
endif

# 如果构建外部模块，我们不关心 all：rule
# 而是_all依赖于模块

PHONY += all
ifeq ($(KBUILD_EXTMOD),)	# 如果KBUILD_EXTMOD为空,先执行all
_all: all
else
_all: modules				# 如果KBUILD_EXTMOD不为空,先执行modules
endif

ifeq ($(KBUILD_SRC),)	# 如果KBUILD_SRC为空
        # 在源代码树中构建
        srctree := .
else
        ifeq ($(KBUILD_SRC)/,$(dir $(CURDIR))) # 如果 KBUILD_SRC 是当前目录的父目录
                # 在源代码树的子目录中构建
                srctree := ..
        else
                srctree := $(KBUILD_SRC)
        endif
endif
objtree		:= .
src		:= $(srctree)
obj		:= $(objtree)

VPATH		:= $(srctree)$(if $(KBUILD_EXTMOD),:$(KBUILD_EXTMOD)) #KBUILD_EXTMOD为空则VPATH=src,否则VPATH=src:KBUILD_EXTMOD

export srctree objtree VPATH

# 确保 CDPATH 设置不会干扰
unexport CDPATH

#########################################################################
#获取主机的体系结构
HOSTARCH := $(shell uname -m | \
	sed -e s/i.86/x86/ \
	    -e s/sun4u/sparc64/ \
	    -e s/arm.*/arm/ \
	    -e s/sa110/arm/ \
	    -e s/ppc64/powerpc/ \
	    -e s/ppc/powerpc/ \
	    -e s/macppc/powerpc/\
	    -e s/sh.*/sh/)
# 获取主机的操作系统
HOSTOS := $(shell uname -s | tr '[:upper:]' '[:lower:]' | \
	    sed -e 's/\(cygwin\).*/cygwin/')

export	HOSTARCH HOSTOS

#########################################################################

# 将本机构建的 default 设置为 nothing
ifeq ($(HOSTARCH),$(ARCH))	#如果主机体系结构等于目标体系结构CROSS_COMPILE交叉编译器为空
CROSS_COMPILE ?=
endif

KCONFIG_CONFIG	?= .config
export KCONFIG_CONFIG

# SHELL used by kbuild
#首先检查环境变量 BASH 指向的 shell 是否存在且可执行。如果是，则输出 $$BASH 的值;这里输出位/bin/bash
#检查 /bin/bash 是否存在且可执行。如果是，则输出 /bin/bash
#则默认输出 sh，表示使用系统默认的 sh shell
CONFIG_SHELL := $(shell if [ -x "$$BASH" ]; then echo $$BASH; \
	  else if [ -x /bin/bash ]; then echo /bin/bash; \
	  else echo sh; fi ; fi)
#用于大文件支持的编译器选项
HOST_LFS_CFLAGS := $(shell getconf LFS_CFLAGS 2>/dev/null)	#获取LFS_CFLAGS 并丢弃错误信息
HOST_LFS_LDFLAGS := $(shell getconf LFS_LDFLAGS 2>/dev/null)
HOST_LFS_LIBS := $(shell getconf LFS_LIBS 2>/dev/null)

HOSTCC       = cc	#使用默认的cc编译器
HOSTCXX      = c++	#使用默认的c++编译器
#设置编译选项
KBUILD_HOSTCFLAGS   := -Wall -Wstrict-prototypes -O2 -fomit-frame-pointer \
		$(HOST_LFS_CFLAGS) $(HOSTCFLAGS)
KBUILD_HOSTCXXFLAGS := -O2 $(HOST_LFS_CFLAGS) $(HOSTCXXFLAGS)
KBUILD_HOSTLDFLAGS  := $(HOST_LFS_LDFLAGS) $(HOSTLDFLAGS)
KBUILD_HOSTLDLIBS   := $(HOST_LFS_LIBS) $(HOSTLDLIBS)

# 随着迁移到 GCC 6，我们已经隐式地将我们的语言标准升级到 GNU11（参见 https://gcc.gnu.org/gcc-5/porting_to.html）。
# 一些 Linux 发行版（包括 RHEL7、SLES13、Debian 8）仍然将较旧的编译器作为默认编译器，
# 因此我们明确指出我们的主机工具是 GNU11（即带有 GNU 扩展的 C11）。

CSTD_FLAG := -std=gnu11
KBUILD_HOSTCFLAGS += $(CSTD_FLAG)

# Cygwin 是一个在 Windows 上运行的类 Unix 环境，提供了许多 Unix 工具和功能。
# 。-ansi 标志用于启用 ANSI C 标准（C89），并禁用所有 GNU 扩展。这在某些情况下可以提高代码的可移植性和兼容性，特别是在需要严格遵循 ANSI C 标准的环境中
ifeq ($(HOSTOS),cygwin)
KBUILD_HOSTCFLAGS	+= -ansi
endif

# Mac OS X / Darwin 的 C 预处理器是 Apple 特有的。 它会生成许多错误和警告。 
# 我们想绕过它并使用 GNU C 的 cpp。	为此，我们将 -traditional-cpp 选项传递给编译器。 
# 请注意，-traditional-cpp 标志
# 与 GNU C 的标志没有相同的语义，它所做的只是以 ANSI/ISO C 的方式调用 GNU 预处理器。
# Apple 的链接器也类似，由于新的 2 阶段链接多个符号定义被视为错误，因此
# -multiply_defined suppress 选项可关闭此错误。

ifeq ($(HOSTOS),darwin)
# get major and minor product version (e.g. '10' and '6' for Snow Leopard)
DARWIN_MAJOR_VERSION	:= $(shell sw_vers -productVersion | cut -f 1 -d '.')
DARWIN_MINOR_VERSION	:= $(shell sw_vers -productVersion | cut -f 2 -d '.')

os_x_before	= $(shell if [ $(DARWIN_MAJOR_VERSION) -le $(1) -a \
	$(DARWIN_MINOR_VERSION) -le $(2) ] ; then echo "$(3)"; else echo "$(4)"; fi ;)

os_x_after = $(shell if [ $(DARWIN_MAJOR_VERSION) -ge $(1) -a \
	$(DARWIN_MINOR_VERSION) -ge $(2) ] ; then echo "$(3)"; else echo "$(4)"; fi ;)

# Snow Leopards build environment has no longer restrictions as described above
HOSTCC       = $(call os_x_before, 10, 5, "cc", "gcc")
KBUILD_HOSTCFLAGS  += $(call os_x_before, 10, 4, "-traditional-cpp")
KBUILD_HOSTLDFLAGS += $(call os_x_before, 10, 5, "-multiply_defined suppress")

# macOS Mojave (10.14.X)
# Undefined symbols for architecture x86_64: "_PyArg_ParseTuple"
KBUILD_HOSTLDFLAGS += $(call os_x_after, 10, 14, "-lpython -dynamclib", "")
endif

# 决定是构建内置、模块化还是两者兼而有之。
# 通常，只做 built-in。

KBUILD_MODULES :=
KBUILD_BUILTIN := 1

# 如果我们只有 “make modules”，就不要编译内置对象。
# 当我们使用 modversions 构建模块时，我们还需要在 descend 期间考虑内置对象，
# 以确保校验和在我们记录它们之前是最新的。

ifeq ($(MAKECMDGOALS),modules)
  KBUILD_BUILTIN := $(if $(CONFIG_MODVERSIONS),1)
endif

# 如果我们有 “make <whatever> modules”，那么除了我们所做的任何事情之外，还要编译 modules。
# 只需 “make” 或 “make all” 也可以构建模块


# U-Boot does not need modules
#ifneq ($(filter all _all modules,$(MAKECMDGOALS)),)
#  KBUILD_MODULES := 1
#endif

#ifeq ($(MAKECMDGOALS),)
#  KBUILD_MODULES := 1
#endif

# 检查二进制文件的大小：
# 参数：
#   $1：要检查的文件
#   #2：大小限制（以字节为单位）（十进制或 0xhex）

define size_check
	actual=$$( wc -c $1 | awk '{print $$1}'); \
	limit=$$( printf "%d" $2 ); \
	if test $$actual -gt $$limit; then \
		echo "$1 exceeds file size limit:" >&2; \
		echo "  limit:  $$(printf %#x $$limit) bytes" >&2; \
		echo "  actual: $$(printf %#x $$actual) bytes" >&2; \
		echo "  excess: $$(printf %#x $$((actual - limit))) bytes" >&2;\
		exit 1; \
	fi
endef
export size_check

export KBUILD_MODULES KBUILD_BUILTIN
export KBUILD_CHECKSRC KBUILD_SRC KBUILD_EXTMOD

# 我们需要一些通用定义（不要尝试重新制作文件）。
# 里面定义了$(build)
scripts/Kbuild.include: ;
include scripts/Kbuild.include

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

# Make variables (CC, etc...)

AS		= $(CROSS_COMPILE)as
# 总是使用 GNU ld
ifneq ($(shell $(CROSS_COMPILE)ld.bfd -v 2> /dev/null),)
LD		= $(CROSS_COMPILE)ld.bfd
else
LD		= $(CROSS_COMPILE)ld
endif
CC		= $(CROSS_COMPILE)gcc
CPP		= $(CC) -E
AR		= $(CROSS_COMPILE)ar
NM		= $(CROSS_COMPILE)nm
LDR		= $(CROSS_COMPILE)ldr
STRIP		= $(CROSS_COMPILE)strip
OBJCOPY		= $(CROSS_COMPILE)objcopy
OBJDUMP		= $(CROSS_COMPILE)objdump
LEX		= flex
YACC		= bison
AWK		= awk
PERL		= perl
PYTHON		?= python
PYTHON2		= python2
PYTHON3		?= python3

# 除非提供设备树编译器(DTC)，否则 devicetree 编译器和 pylibfdt 会自动构建。如果提供了 DTC，则假定 pylibfdt 也可用。
DTC_INTREE	:= $(objtree)/scripts/dtc/dtc
DTC		?= $(DTC_INTREE)
DTC_MIN_VERSION	:= 010406

CHECK		= sparse

CHECKFLAGS     := -D__linux__ -Dlinux -D__STDC__ -Dunix -D__unix__ \
		  -Wbitwise -Wno-return-void -Wno-unknown-attribute \
		  -D__CHECK_ENDIAN__ $(CF)

KBUILD_CPPFLAGS := -D__KERNEL__ -D__UBOOT__

KBUILD_CFLAGS   := -Wall -Wstrict-prototypes \
		   -Wno-format-security \
		   -fno-builtin -ffreestanding $(CSTD_FLAG)
KBUILD_CFLAGS	+= -fshort-wchar -fno-strict-aliasing
KBUILD_AFLAGS   := -D__ASSEMBLY__
KBUILD_LDFLAGS  :=

ifeq ($(cc-name),clang)
ifneq ($(CROSS_COMPILE),)
CLANG_TARGET	:= --target=$(notdir $(CROSS_COMPILE:%-=%))
LDPPFLAGS	+= $(CLANG_TARGET)
GCC_TOOLCHAIN_DIR := $(dir $(shell which $(LD)))
CLANG_PREFIX	:= --prefix=$(GCC_TOOLCHAIN_DIR)
GCC_TOOLCHAIN	:= $(realpath $(GCC_TOOLCHAIN_DIR)/..)
endif
ifneq ($(GCC_TOOLCHAIN),)
CLANG_GCC_TC	:= --gcc-toolchain=$(GCC_TOOLCHAIN)
endif
KBUILD_CFLAGS += $(CLANG_TARGET) $(CLANG_GCC_TC) $(CLANG_PREFIX)
KBUILD_AFLAGS += $(CLANG_TARGET) $(CLANG_GCC_TC) $(CLANG_PREFIX)
KBUILD_CFLAGS += $(call cc-option, -no-integrated-as)	
KBUILD_AFLAGS += $(call cc-option, -no-integrated-as)
endif

# 不生成与位置无关的代码
# 尝试编译 -fno-PIE 选项，如果成功则添加到编译选项中;失败则不添加
KBUILD_CFLAGS	+= $(call cc-option,-fno-PIE)
KBUILD_AFLAGS	+= $(call cc-option,-fno-PIE)

# 从 include/config/uboot.release 读取 UBOOTRELEASE（如果存在）
UBOOTRELEASE = $(shell cat include/config/uboot.release 2> /dev/null)
UBOOTVERSION = $(VERSION)$(if $(PATCHLEVEL),.$(PATCHLEVEL)$(if $(SUBLEVEL),.$(SUBLEVEL)))$(EXTRAVERSION)

export VERSION PATCHLEVEL SUBLEVEL UBOOTRELEASE UBOOTVERSION
export ARCH CPU BOARD VENDOR SOC CPUDIR BOARDDIR
export CONFIG_SHELL HOSTCC:= $(shell $(CC) --version | head -n 1)
 KBUILD_HOSTCFLAGS CROSS_COMPILE AS LD CC
export CPP AR NM LDR STRIP OBJCOPY OBJDUMP KBUILD_HOSTLDFLAGS KBUILD_HOSTLDLIBS
export MAKE LEX YACC AWK PERL PYTHON PYTHON2 PYTHON3
export HOSTCXX KBUILD_HOSTCXXFLAGS CHECK CHECKFLAGS DTC DTC_FLAGS

export KBUILD_CPPFLAGS NOSTDINC_FLAGS UBOOTINCLUDE OBJCOPYFLAGS KBUILD_LDFLAGS
export KBUILD_CFLAGS KBUILD_AFLAGS

export CC_VERSION_TEXT 
# 编译树外模块时，请将 MODVERDIR 放在模块树中，而不是内核树中。内核树甚至可能是只读的。
export MODVERDIR := $(if $(KBUILD_EXTMOD),$(firstword $(KBUILD_EXTMOD))/).tmp_versions

# 要在 find ... 中忽略的文件语句

export RCS_FIND_IGNORE := \( -name SCCS -o -name BitKeeper -o -name .svn -o    \
			  -name CVS -o -name .pc -o -name .hg -o -name .git \) \
			  -prune -o
export RCS_TAR_IGNORE := --exclude SCCS --exclude BitKeeper --exclude .svn \
			 --exclude CVS --exclude .pc --exclude .hg --exclude .git

export PYTHON_ENABLE

# 如果 U-Boot 不应该构建任何 Python 工具或库，则为 y。通常，
# 如果这些工具/库（通常是 binman 和 pylibfdt）无法由您的环境构建并且单独提供，则需要设置此项。

ifeq ($(NO_PYTHON),)
PYTHON_ENABLE=y
endif

# ===========================================================================
# 在 *config 目标和构建目标之间共享的规则

# 脚本中内置的基本帮助程序/
PHONY += scripts_basic
#编译 scripts_basic,具体请查看scripts/Makefile

hostprogs-y	:= fixdep
always		:= $(hostprogs-y)

# 需要 fixdep 来编译其他主机程序
#并使用 filter-out 函数从 always 变量中排除 fixdep 程序。这生成了一个列表，包含所有需要编译的主机程序（除了 fixdep）。
#并且使得在构建这些目标之前，必须先构建 fixdep
$(addprefix $(obj)/,$(filter-out fixdep,$(always))): $(obj)/fixdep

#这会编译fixdep.c 生成fiddep可执行文件,在后续编译中会用到并生成.fixdep.cmd
# fixdep 是一个用于处理依赖关系的工具，通常在构建系统中使用。它解析依赖文件（depfile），生成目标文件（target）的依赖关系，并输出相应的命令行（cmdline）

scripts_basic:
	$(Q)$(MAKE) $(build)=scripts/basic
	$(Q)rm -f .tmp_quiet_recordmcount

# 为避免任何隐式规则生效，请定义一个空命令。
scripts/basic/%: scripts_basic ;

PHONY += outputmakefile
# outputmakefile 会在输出目录中生成一个 Makefile，如果使用单独的输出目录。这允许在output 目录中。
outputmakefile:
ifneq ($(KBUILD_SRC),)
# 在输出目录创建源目录的快捷方式
	$(Q)ln -fsn $(srctree) source
# 在输出目录调用源目录的/scripts/mkmakefile脚本
	$(Q)$(CONFIG_SHELL) $(srctree)/scripts/mkmakefile $(srctree)

# bin2c 用于将二进制文件转换为 C 代码。这是一个主机程序，因此我们将其添加到 hostprogs-y 变量中。
hostprogs-$(CONFIG_BUILD_BIN2C)		+= bin2c

always		:= $(hostprogs-y)

# 让 clean 下降到 subdirs 中
subdir-	+= basic kconfig dtc
endif

# 为了确保我们没有为任何 *config 目标包含 .config，请尽早捕获它们，并将它们交给 scripts/kconfig/Makefile
# 允许在调用 make 时指定更多的 target，包括混合 *config 目标和 build target。
# 例如，'make oldconfig all'。
# 在指定了混合目标时进行检测，并再次调用 make，以便在这种情况下也不包含 .config（对于 *config）。

version_h := include/generated/version_autogenerated.h
timestamp_h := include/generated/timestamp_autogenerated.h
defaultenv_h := include/generated/defaultenv_autogenerated.h
dt_h := include/generated/dt.h
env_h := include/generated/environment.h
# 包含了一组构建目标，这些目标不需要处理 .config 文件
# 这些目标包括清理目标（如 clean、distclean）、帮助目标（如 help）、
# 文档目标（如 %docs）、检查目标（如 check、coccicheck）以及其他特定目标
no-dot-config-targets := clean clobber mrproper distclean \
			 help %docs check% coccicheck \
			 ubootversion backup tests check pcheck qcheck tcheck \
			 pylint pylint_err _pip pip pip_test pip_release
# 表示是否有配置目标
config-targets := 0
# 表示是否有混合目标
mixed-targets  := 0
# 表示是否需要处理.config 文件
dot-config     := 1
# 检查 MAKECMDGOALS 是否包含 no-dot-config-targets 中的目标。
ifneq ($(filter $(no-dot-config-targets), $(MAKECMDGOALS)),)
# 果 MAKECMDGOALS 中包含 no-dot-config-targets 中的目标，并且不包含其他目标，
# 则将 dot-config 设置为 0，表示不需要处理 .config 文件。
	ifeq ($(filter-out $(no-dot-config-targets), $(MAKECMDGOALS)),)
		dot-config := 0
	endif
endif
# KBUILD_EXTMOD 为空执行
ifeq ($(KBUILD_EXTMOD),)
# 检查 MAKECMDGOALS 中是否包含 config 或 %config 目标
        ifneq ($(filter config %config,$(MAKECMDGOALS)),)
# 如果包含配置目标，则将 config-targets 设置为 1,例如输入stm32h750-art-pi_defconfig
                config-targets := 1
# 如果 MAKECMDGOALS 中包含多个目标，则将 mixed-targets 设置为 1，表示有混合目标。
# 例如输入 stm32h750-art-pi_defconfig scripts_basic
                ifneq ($(words $(MAKECMDGOALS)),1)
                        mixed-targets := 1
                endif
        endif
endif

ifeq ($(mixed-targets),1)
# ===========================================================================
# 我们被调用为混合目标（*config 和 build 目标）。
# 逐一处理。

PHONY += $(MAKECMDGOALS) __build_one_by_one
# 表示所有的 MAKECMDGOALS（除了 __build_one_by_one）都依赖于 __build_one_by_one 目标
# 过滤掉 MAKECMDGOALS 中的 __build_one_by_one，只保留其他目标
$(filter-out __build_one_by_one, $(MAKECMDGOALS)): __build_one_by_one
	@:
# 逐个构建MAKECMDGOALS 中的目标
__build_one_by_one:
	set -e; \
	for i in $(MAKECMDGOALS); do \
		$(MAKE) -f $(srctree)/Makefile $$i; \
	done

else
ifeq ($(config-targets),1)
# ===========================================================================
# *config target only - 确保先决条件已更新，并在 scripts/kconfig 中下降以使 make *config 目标
# sandbox_defconfig 在configs/sandbox_defconfig
KBUILD_DEFCONFIG := sandbox_defconfig
export KBUILD_DEFCONFIG KBUILD_KCONFIG


# 编译scripts/kconfig/Makefile中的 config 目标为如下
config: $(obj)/conf
	$< $(silent) --oldaskconfig $(Kconfig)

# 	依赖于 scripts_basic outputmakefile,所以先执行这两个
#	调用 make 命令，并指定构建目录为 kconfig，目标为 config。
#	然后运行 ./scripts/kconfig/conf --oldaskconfig Kconfig 
config: scripts_basic outputmakefile FORCE
	$(Q)$(MAKE) $(build)=scripts/kconfig $@

# 定义了一个模式规则，匹配所有以 config 结尾的目标
%config: scripts_basic outputmakefile FORCE
	$(Q)$(MAKE) $(build)=scripts/kconfig $@

else
# ===========================================================================
# 仅构建目标 - 这包括 vmlinux、arch 特定目标、clean 目标等。通常，除 *config 目标之外的所有目标。

# 脚本中内置的其他帮助程序/
# 仔细列出依赖项，这样我们就不会尝试并行构建脚本两次

PHONY += scripts
# 等同于 make scripts;但是会先执行scripts_basic 和 include/config/auto.conf (include/config/%.conf:)
scripts: scripts_basic scripts_dtc include/config/auto.conf
	$(Q)$(MAKE) $(build)=$(@)

ifeq ($(dot-config),1)
# 读入配置
-include include/config/auto.conf

# 读入所有 Kconfig* 文件的依赖项，确保在检测到更改时运行 oldconfig。
-include include/config/auto.conf.cmd

# 为避免任何隐式规则生效，请定义一个空命令
$(KCONFIG_CONFIG) include/config/auto.conf.cmd: ;

# 如果 .config 比 include/config/auto.conf 新，则有人修改了它，忘记运行 make oldconfig。
# 如果缺少 auto.conf.cmd 则我们可能位于已清理的树中，因此我们执行 config 步骤以确保捕获更新的 Kconfig 文件

include/config/%.conf: $(KCONFIG_CONFIG) include/config/auto.conf.cmd
	$(Q)$(MAKE) -f $(srctree)/Makefile syncconfig
# 如果以下部分失败，则应删除 include/config/auto.conf，以便 “make silentoldconfig” 将在下一个构建中重新运行。
	$(Q)$(MAKE) -f $(srctree)/scripts/Makefile.autoconf || \
		{ rm -f include/config/auto.conf; false; }
# include/config.h 在 “make silentoldconfig” 之后更新。
# 我们需要触摸 include/config/auto.conf，这样它就会比 include/config.h 更新。
# 否则，'make silentoldconfig' 将被调用两次。
	$(Q)touch include/config/auto.conf

# /scripts/Makefile.autoconf 内容如下
# 依赖之后,调用filechk函数检查auto.conf文件是否存在,如果不存在则创建
include/config.h: scripts/Makefile.autoconf create_symlink FORCE
	$(call filechk,config_h)

u-boot.cfg spl/u-boot.cfg tpl/u-boot.cfg vpl/u-boot.cfg:
	$(Q)$(MAKE) -f $(srctree)/scripts/Makefile.autoconf $(@)

-include include/autoconf.mk
-include include/autoconf.mk.dep

# 我们只希望在 include/config/auto.conf 是最新的时才包含 arch/$（ARCH）/config.mk。
# 当我们切换到不同的板子配置时，旧的 CONFIG 宏仍然保留在 include/config/auto.conf 中。
#如果没有以下噱头，错误 config.mk 将包含在导致令人讨厌的警告/错误。
ifneq ($(wildcard $(KCONFIG_CONFIG)),)
ifneq ($(wildcard include/config/auto.conf),)
autoconf_is_old := $(shell find . -path ./$(KCONFIG_CONFIG) -newer \
						include/config/auto.conf)
ifeq ($(autoconf_is_old),)
include config.mk
include arch/$(ARCH)/Makefile
endif
endif
endif

# These are set by the arch-specific config.mk. Make sure they are exported
# so they can be used when building an EFI application.
export EFI_LDS		# Filename of EFI link script in arch/$(ARCH)/lib
export EFI_CRT0		# Filename of EFI CRT0 in arch/$(ARCH)/lib
export EFI_RELOC	# Filename of EFU relocation code in arch/$(ARCH)/lib
export CFLAGS_EFI	# Compiler flags to add when building EFI app
export CFLAGS_NON_EFI	# Compiler flags to remove when building EFI app
export EFI_TARGET	# binutils target if EFI is natively supported

export LTO_ENABLE

# This is y if LTO is enabled for this build. See NO_LTO=1 to disable LTO
ifeq ($(NO_LTO),)
LTO_ENABLE=$(if $(CONFIG_LTO),y)
endif

# If board code explicitly specified LDSCRIPT or CONFIG_SYS_LDSCRIPT, use
# that (or fail if absent).  Otherwise, search for a linker script in a
# standard location.

ifndef LDSCRIPT
	#LDSCRIPT := $(srctree)/board/$(BOARDDIR)/u-boot.lds.debug
	ifdef CONFIG_SYS_LDSCRIPT
		# need to strip off double quotes
		LDSCRIPT := $(srctree)/$(CONFIG_SYS_LDSCRIPT:"%"=%)
	endif
endif

# If there is no specified link script, we look in a number of places for it
ifndef LDSCRIPT
	ifeq ($(wildcard $(LDSCRIPT)),)
		LDSCRIPT := $(srctree)/board/$(BOARDDIR)/u-boot.lds
	endif
	ifeq ($(wildcard $(LDSCRIPT)),)
		LDSCRIPT := $(srctree)/$(CPUDIR)/u-boot.lds
	endif
	ifeq ($(wildcard $(LDSCRIPT)),)
		LDSCRIPT := $(srctree)/arch/$(ARCH)/cpu/u-boot.lds
	endif
endif

else
# Dummy target needed, because used as prerequisite
include/config/auto.conf: ;
endif # $(dot-config)

ifdef CONFIG_CC_OPTIMIZE_FOR_DEBUG
KBUILD_HOSTCFLAGS   := -Wall -Wstrict-prototypes -Og -g -fomit-frame-pointer \
		$(HOST_LFS_CFLAGS) $(HOSTCFLAGS)
# Avoid false positives -Wmaybe-uninitialized
# https://gcc.gnu.org/bugzilla/show_bug.cgi?id=78394
KBUILD_HOSTCFLAGS   += -Wno-maybe-uninitialized
KBUILD_HOSTCXXFLAGS := -Og -g $(HOST_LFS_CFLAGS) $(HOSTCXXFLAGS)
endif

#
# Xtensa linker script cannot be preprocessed with -ansi because of
# preprocessor operations on strings that don't make C identifiers.
#
ifeq ($(CONFIG_XTENSA),)
LDPPFLAGS	+= -ansi
endif

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

LTO_CFLAGS :=
LTO_FINAL_LDFLAGS :=
export LTO_CFLAGS LTO_FINAL_LDFLAGS
ifeq ($(LTO_ENABLE),y)
	ifeq ($(cc-name),clang)
		LTO_CFLAGS		+= -DLTO_ENABLE -flto
		LTO_FINAL_LDFLAGS	+= -flto

		AR			= $(shell $(CC) -print-prog-name=llvm-ar)
		NM			= $(shell $(CC) -print-prog-name=llvm-nm)
	else
		NPROC			:= $(shell nproc 2>/dev/null || echo 1)
		LTO_CFLAGS		+= -DLTO_ENABLE -flto=$(NPROC)
		LTO_FINAL_LDFLAGS	+= -fuse-linker-plugin -flto=$(NPROC)

		# use plugin aware tools
		AR			= $(CROSS_COMPILE)gcc-ar
		NM			= $(CROSS_COMPILE)gcc-nm
	endif

	CFLAGS_NON_EFI			+= $(LTO_CFLAGS)

	KBUILD_CFLAGS			+= $(LTO_CFLAGS)
endif

ifeq ($(CONFIG_STACKPROTECTOR),y)
KBUILD_CFLAGS += $(call cc-option,-fstack-protector-strong)
KBUILD_CFLAGS += $(call cc-option,-mstack-protector-guard=global)
CFLAGS_EFI += $(call cc-option,-fno-stack-protector)
else
KBUILD_CFLAGS += $(call cc-option,-fno-stack-protector)
endif
KBUILD_CFLAGS += $(call cc-option,-fno-delete-null-pointer-checks)

# disable pointer signed / unsigned warnings in gcc 4.0
KBUILD_CFLAGS += -Wno-pointer-sign

# disable stringop warnings in gcc 8+
KBUILD_CFLAGS += $(call cc-disable-warning, stringop-truncation)

KBUILD_CFLAGS += $(call cc-disable-warning, zero-length-bounds)
KBUILD_CFLAGS += $(call cc-disable-warning, array-bounds)
KBUILD_CFLAGS += $(call cc-disable-warning, stringop-overflow)

# Enabled with W=2, disabled by default as noisy
KBUILD_CFLAGS += $(call cc-disable-warning, maybe-uninitialized)

# change __FILE__ to the relative path from the srctree
KBUILD_CFLAGS	+= $(call cc-option,-fmacro-prefix-map=$(srctree)/=)

KBUILD_CFLAGS	+= -gdwarf-4
# $(KBUILD_AFLAGS) sets -g, which causes gcc to pass a suitable -g<format>
# option to the assembler.
KBUILD_AFLAGS	+= -gdwarf-4

# Report stack usage if supported
# ARC tools based on GCC 7.1 has an issue with stack usage
# with naked functions, see commit message for more details
ifndef CONFIG_ARC
ifeq ($(shell $(CONFIG_SHELL) $(srctree)/scripts/gcc-stack-usage.sh $(CC)),y)
	KBUILD_CFLAGS += -fstack-usage
endif
endif

KBUILD_CFLAGS += $(call cc-option,-Wno-format-nonliteral)
KBUILD_CFLAGS += $(call cc-disable-warning, address-of-packed-member)

ifdef CONFIG_CC_IS_CLANG
KBUILD_CPPFLAGS += $(call cc-option,-Qunused-arguments,)
KBUILD_CFLAGS += $(call cc-disable-warning, format-invalid-specifier)
KBUILD_CFLAGS += $(call cc-disable-warning, gnu)
KBUILD_CFLAGS += $(call cc-disable-warning, address-of-packed-member)
# Quiet clang warning: comparison of unsigned expression < 0 is always false
KBUILD_CFLAGS += $(call cc-disable-warning, tautological-compare)
# CLANG uses a _MergedGlobals as optimization, but this breaks modpost, as the
# source of a reference will be _MergedGlobals and not on of the whitelisted names.
# See modpost pattern 2
KBUILD_CFLAGS += $(call cc-option, -mno-global-merge,)
KBUILD_CFLAGS += $(call cc-option, -fcatch-undefined-behavior)
KBUILD_CFLAGS += $(call cc-disable-warning, deprecated-non-prototype)
endif

# These warnings generated too much noise in a regular build.
# Use make W=1 to enable them (see scripts/Makefile.extrawarn)
KBUILD_CFLAGS += $(call cc-disable-warning, unused-but-set-variable)

# Prohibit date/time macros, which would make the build non-deterministic
KBUILD_CFLAGS   += $(call cc-option,-Werror=date-time)

include scripts/Makefile.extrawarn

# Add user supplied CPPFLAGS, AFLAGS and CFLAGS as the last assignments
KBUILD_CPPFLAGS += $(KCPPFLAGS)
KBUILD_AFLAGS += $(KAFLAGS)
KBUILD_CFLAGS += $(KCFLAGS)

KBUILD_LDFLAGS  += -z noexecstack
KBUILD_LDFLAGS  += $(call ld-option,--no-warn-rwx-segments)

KBUILD_HOSTCFLAGS += $(if $(CONFIG_TOOLS_DEBUG),-g)

# Use UBOOTINCLUDE when you must reference the include/ directory.
# Needed to be compatible with the O= option
UBOOTINCLUDE    := \
	-Iinclude \
	$(if $(KBUILD_SRC), -I$(srctree)/include) \
	$(if $(CONFIG_MBEDTLS_LIB), \
		"-DMBEDTLS_CONFIG_FILE=\"mbedtls_def_config.h\"" \
		-I$(srctree)/lib/mbedtls \
		-I$(srctree)/lib/mbedtls/port \
		-I$(srctree)/lib/mbedtls/external/mbedtls \
		-I$(srctree)/lib/mbedtls/external/mbedtls/include) \
	$(if $(CONFIG_$(XPL_)SYS_THUMB_BUILD), \
		$(if $(CONFIG_HAS_THUMB2), \
			$(if $(CONFIG_CPU_V7M), \
				-I$(srctree)/arch/arm/thumb1/include), \
			-I$(srctree)/arch/arm/thumb1/include)) \
	-I$(srctree)/arch/$(ARCH)/include \
	-include $(srctree)/include/linux/kconfig.h \
	-I$(srctree)/dts/upstream/include \
	$(if $(CONFIG_NET_LWIP), -I$(srctree)/lib/lwip/lwip/src/include \
		-I$(srctree)/lib/lwip/u-boot)

NOSTDINC_FLAGS += -nostdinc -isystem $(shell $(CC) -print-file-name=include)

# FIX ME
cpp_flags := $(KBUILD_CPPFLAGS) $(PLATFORM_CPPFLAGS) $(UBOOTINCLUDE) \
							$(NOSTDINC_FLAGS)
c_flags := $(KBUILD_CFLAGS) $(cpp_flags)

#########################################################################
# U-Boot objects....order is important (i.e. start must be first)

HAVE_VENDOR_COMMON_LIB = $(if $(wildcard $(srctree)/board/$(VENDOR)/common/Makefile),y,n)

libs-$(CONFIG_API) += api/
libs-$(HAVE_VENDOR_COMMON_LIB) += board/$(VENDOR)/common/
libs-y += boot/
libs-$(CONFIG_CMDLINE) += cmd/
libs-y += common/
libs-$(CONFIG_OF_EMBED) += dts/
libs-y += env/
libs-y += lib/
libs-y += fs/
libs-$(filter y,$(CONFIG_NET) $(CONFIG_NET_LWIP)) += net/
libs-y += disk/
libs-y += drivers/
libs-$(CONFIG_SYS_FSL_DDR) += drivers/ddr/fsl/
libs-$(CONFIG_SYS_FSL_MMDC) += drivers/ddr/fsl/
libs-$(CONFIG_$(XPL_)ALTERA_SDRAM) += drivers/ddr/altera/
libs-y += drivers/usb/cdns3/
libs-y += drivers/usb/dwc3/
libs-y += drivers/usb/common/
libs-y += drivers/usb/emul/
libs-y += drivers/usb/eth/
libs-$(CONFIG_USB_DEVICE) += drivers/usb/gadget/
libs-$(CONFIG_USB_GADGET) += drivers/usb/gadget/
libs-$(CONFIG_USB_GADGET) += drivers/usb/gadget/udc/
libs-y += drivers/usb/host/
libs-y += drivers/usb/mtu3/
libs-y += drivers/usb/musb/
libs-y += drivers/usb/musb-new/
libs-y += drivers/usb/isp1760/
libs-y += drivers/usb/phy/
libs-y += drivers/usb/tcpm/
libs-y += drivers/usb/ulpi/
ifdef CONFIG_POST
libs-y += post/
endif
libs-$(CONFIG_$(PHASE_)UNIT_TEST) += test/
libs-$(CONFIG_UT_ENV) += test/env/
libs-$(CONFIG_UT_OPTEE) += test/optee/
libs-$(CONFIG_UT_OVERLAY) += test/overlay/

libs-y += $(if $(wildcard $(srctree)/board/$(BOARDDIR)/Makefile),board/$(BOARDDIR)/)

libs-y := $(sort $(libs-y))

u-boot-dirs	:= $(patsubst %/,%,$(filter %/, $(libs-y))) tools examples

u-boot-alldirs	:= $(sort $(u-boot-dirs) $(patsubst %/,%,$(filter %/, $(libs-))))

libs-y		:= $(patsubst %/, %/built-in.o, $(libs-y))

u-boot-init := $(head-y)
u-boot-main := $(libs-y)


# Add GCC lib
ifeq ($(CONFIG_USE_PRIVATE_LIBGCC),y)
PLATFORM_LIBGCC = arch/$(ARCH)/lib/lib.a
else
ifndef CONFIG_CC_IS_CLANG
PLATFORM_LIBGCC := -L $(shell dirname `$(CC) $(c_flags) -print-libgcc-file-name`) -lgcc
endif
endif
PLATFORM_LIBS += $(PLATFORM_LIBGCC)

ifdef CONFIG_CC_COVERAGE
KBUILD_CFLAGS += --coverage
PLATFORM_LIBGCC += -lgcov
endif

export PLATFORM_LIBS
export PLATFORM_LIBGCC

# Special flags for CPP when processing the linker script.
# Pass the version down so we can handle backwards compatibility
# on the fly.
LDPPFLAGS += \
	-include $(srctree)/include/u-boot/u-boot.lds.h \
	-DCPUDIR=$(CPUDIR) \
	$(shell $(LD) --version | \
	  sed -ne 's/GNU ld version \([0-9][0-9]*\)\.\([0-9][0-9]*\).*/-DLD_MAJOR=\1 -DLD_MINOR=\2/p')

#########################################################################
#########################################################################

ifneq ($(CONFIG_BOARD_SIZE_LIMIT),)
BOARD_SIZE_CHECK= @ $(call size_check,$@,$(CONFIG_BOARD_SIZE_LIMIT))
else
BOARD_SIZE_CHECK =
endif

ifneq ($(CONFIG_SPL_SIZE_LIMIT),0x0)
SPL_SIZE_CHECK = @$(call size_check,$@,$$(tools/spl_size_limit))
else
SPL_SIZE_CHECK =
endif

ifneq ($(CONFIG_TPL_SIZE_LIMIT),0x0)
TPL_SIZE_CHECK = @$(call size_check,$@,$(CONFIG_TPL_SIZE_LIMIT))
else
TPL_SIZE_CHECK =
endif

ifneq ($(CONFIG_VPL_SIZE_LIMIT),0x0)
VPL_SIZE_CHECK = @$(call size_check,$@,$(CONFIG_VPL_SIZE_LIMIT))
else
VPL_SIZE_CHECK =
endif

# Statically apply RELA-style relocations (currently arm64 only)
# This is useful for arm64 where static relocation needs to be performed on
# the raw binary, but certain simulators only accept an ELF file (but don't
# do the relocation).
ifneq ($(CONFIG_STATIC_RELA),)
# $(2) is u-boot ELF, $(3) is u-boot bin, $(4) is text base
quiet_cmd_static_rela = RELOC   $@
cmd_static_rela = \
	tools/relocate-rela $(3) $(2)
else
quiet_cmd_static_rela =
cmd_static_rela =
endif

# Always append INPUTS so that arch config.mk's can add custom ones
INPUTS-y += u-boot.srec u-boot.bin u-boot.sym System.map binary_size_check

ifeq ($(CONFIG_SPL_FSL_PBL),y)
INPUTS-$(CONFIG_RAMBOOT_PBL) += u-boot-with-spl-pbl.bin
else
ifneq ($(CONFIG_NXP_ESBC), y)
# For Secure Boot The Image needs to be signed and Header must also
# be included. So The image has to be built explicitly
INPUTS-$(CONFIG_RAMBOOT_PBL) += u-boot.pbl
endif
endif
INPUTS-$(CONFIG_SPL) += spl/u-boot-spl.bin
ifeq ($(CONFIG_MX6)$(CONFIG_IMX_HAB), yy)
INPUTS-$(CONFIG_SPL_FRAMEWORK) += u-boot-ivt.img
else
ifeq ($(CONFIG_MX7)$(CONFIG_IMX_HAB), yy)
INPUTS-$(CONFIG_SPL_FRAMEWORK) += u-boot-ivt.img
else
INPUTS-$(CONFIG_SPL_FRAMEWORK) += u-boot.img
endif
endif
INPUTS-$(CONFIG_TPL) += tpl/u-boot-tpl.bin
INPUTS-$(CONFIG_VPL) += vpl/u-boot-vpl.bin

# Allow omitting the .dtb output if it is not normally used
INPUTS-$(CONFIG_OF_SEPARATE) += $(if $(CONFIG_OF_OMIT_DTB),dts/dt.dtb,u-boot.dtb)
ifeq ($(CONFIG_SPL_FRAMEWORK),y)
INPUTS-$(CONFIG_OF_SEPARATE) += u-boot-dtb.img
endif
INPUTS-$(CONFIG_SANDBOX) += u-boot.dtb
ifneq ($(CONFIG_SPL_TARGET),)
INPUTS-$(CONFIG_SPL) += $(CONFIG_SPL_TARGET:"%"=%)
endif
INPUTS-$(CONFIG_REMAKE_ELF) += u-boot.elf
INPUTS-$(CONFIG_EFI_APP) += u-boot-app.efi
INPUTS-$(CONFIG_EFI_STUB) += u-boot-payload.efi

# Generate this input file for binman
ifeq ($(CONFIG_SPL),)
INPUTS-$(CONFIG_ARCH_MEDIATEK) += u-boot-mtk.bin
endif

# Add optional build target if defined in board/cpu/soc headers
ifneq ($(CONFIG_BUILD_TARGET),)
INPUTS-y += $(CONFIG_BUILD_TARGET:"%"=%)
endif

ifeq ($(CONFIG_INIT_SP_RELATIVE)$(CONFIG_OF_SEPARATE),yy)
INPUTS-y += init_sp_bss_offset_check
endif

ifeq ($(CONFIG_ARCH_ROCKCHIP)_$(CONFIG_SPL_FRAMEWORK),y_)
INPUTS-y += u-boot.img
endif

INPUTS-$(CONFIG_X86) += u-boot-x86-start16.bin u-boot-x86-reset16.bin \
	$(if $(CONFIG_SPL_X86_16BIT_INIT),spl/u-boot-spl.bin) \
	$(if $(CONFIG_TPL_X86_16BIT_INIT),tpl/u-boot-tpl.bin)

LDFLAGS_u-boot += $(LDFLAGS_FINAL)

# Avoid 'Not enough room for program headers' error on binutils 2.28 onwards.
LDFLAGS_u-boot += $(call ld-option, --no-dynamic-linker)

# ld.lld support
LDFLAGS_u-boot += -z notext $(call ld-option,--apply-dynamic-relocs)

LDFLAGS_u-boot += --build-id=none

ifeq ($(CONFIG_ARC)$(CONFIG_NIOS2)$(CONFIG_X86)$(CONFIG_XTENSA),)
LDFLAGS_u-boot += -Ttext $(CONFIG_TEXT_BASE)
endif

# make the checker run with the right architecture
CHECKFLAGS += --arch=$(ARCH)

# insure the checker run with the right endianness
CHECKFLAGS += $(if $(CONFIG_SYS_BIG_ENDIAN),-mbig-endian,-mlittle-endian)

# the checker needs the correct machine size
CHECKFLAGS += $(if $(CONFIG_64BIT),-m64,-m32)

# Normally we fill empty space with 0xff
quiet_cmd_objcopy = OBJCOPY $@
cmd_objcopy = $(OBJCOPY) --gap-fill=0xff $(OBJCOPYFLAGS) \
	$(OBJCOPYFLAGS_$(@F)) $< $@

# Provide a version which does not do this, for use by EFI
quiet_cmd_zobjcopy = OBJCOPY $@
cmd_zobjcopy = $(OBJCOPY) $(OBJCOPYFLAGS) $(OBJCOPYFLAGS_$(@F)) $< $@

quiet_cmd_efipayload = OBJCOPY $@
cmd_efipayload = $(OBJCOPY) -I binary -O $(EFIPAYLOAD_BFDTARGET) -B $(EFIPAYLOAD_BFDARCH) $< $@

MKIMAGEOUTPUT ?= /dev/null

quiet_cmd_mkimage = MKIMAGE $@
cmd_mkimage = $(objtree)/tools/mkimage $(MKIMAGEFLAGS_$(@F)) -d $< $@ \
	>$(MKIMAGEOUTPUT) $(if $(KBUILD_VERBOSE:0=), && cat $(MKIMAGEOUTPUT))

quiet_cmd_mkfitimage = MKIMAGE $@
cmd_mkfitimage = $(objtree)/tools/mkimage $(MKIMAGEFLAGS_$(@F)) \
	-f $(U_BOOT_ITS) -p $(CONFIG_FIT_EXTERNAL_OFFSET) $@ \
	>$(MKIMAGEOUTPUT) $(if $(KBUILD_VERBOSE:0=), && cat $(MKIMAGEOUTPUT))

quiet_cmd_cat = CAT     $@
cmd_cat = cat $(filter-out $(PHONY), $^) > $@

append = cat $(filter-out $< $(PHONY), $^) >> $@

quiet_cmd_pad_cat = CAT     $@
cmd_pad_cat = $(cmd_objcopy) && $(append) || { rm -f $@; false; }

quiet_cmd_lzma = LZMA    $@
cmd_lzma = lzma -c -z -k -9 $< > $@

cfg: u-boot.cfg

quiet_cmd_ofcheck = OFCHK   $2
cmd_ofcheck = $(srctree)/scripts/check-of.sh $2 \
		$(srctree)/scripts/of_allowlist.txt

# Concat the value of all the CONFIGs (result is 'y' or 'yy', etc. )
got = $(foreach cfg,$(1),$($(cfg)))

# expected value 'y for each one
expect = $(foreach cfg,$(1),y)

# Show a deprecation message
# Args:
# 1: List of options to migrate to (e.g. "CONFIG_DM_MMC CONFIG_BLK")
# 2: Name of component (e.g . "Ethernet drivers")
# 3: Release deadline (e.g. "v202.07")
# 4: Condition to require before checking (e.g. "$(CONFIG_NET)")
# Note: Script avoids bash construct, hence the strange double 'if'
# (patches welcome!)
define deprecated
	@if [ -n "$(strip $(4))" ]; then if [ "$(got)" != "$(expect)" ]; then \
		echo >&2 "===================== WARNING ======================"; \
		echo >&2 "This board does not use $(firstword $(1)) (Driver Model"; \
		echo >&2 "for $(2)). Please update the board to use"; \
		echo >&2 "$(firstword $(1)) before the $(3) release. Failure to"; \
		echo >&2 "update by the deadline may result in board removal."; \
		echo >&2 "See doc/develop/driver-model/migration.rst for more info."; \
		echo >&2 "===================================================="; \
	fi; fi

endef

# Timestamp file to make sure that binman always runs
.binman_stamp: $(INPUTS-y) FORCE
ifeq ($(CONFIG_BINMAN),y)
	$(call if_changed,binman)
endif
	@touch $@

all: .binman_stamp

ifeq ($(CONFIG_DEPRECATED),y)
	$(warning "You have deprecated configuration options enabled in your .config! Please check your configuration.")
endif
ifeq ($(CONFIG_OF_EMBED)$(CONFIG_EFI_APP),y)
	@echo >&2 "===================== WARNING ======================"
	@echo >&2 "CONFIG_OF_EMBED is enabled. This option should only"
	@echo >&2 "be used for debugging purposes. Please use"
	@echo >&2 "CONFIG_OF_SEPARATE for boards in mainline."
	@echo >&2 "See doc/develop/devicetree/control.rst for more info."
	@echo >&2 "===================================================="
endif
ifneq ($(CONFIG_SPL_FIT_GENERATOR),)
	@echo >&2 "===================== WARNING ======================"
	@echo >&2 "This board uses CONFIG_SPL_FIT_GENERATOR. Please migrate"
	@echo >&2 "to binman instead, to avoid the proliferation of"
	@echo >&2 "arch-specific scripts with no tests."
	@echo >&2 "===================================================="
endif
	$(call deprecated,CONFIG_WDT,DM watchdog,v2019.10,\
		$(CONFIG_WATCHDOG)$(CONFIG_HW_WATCHDOG))
	$(call deprecated,CONFIG_DM_I2C,I2C drivers,v2022.04,$(CONFIG_SYS_I2C_LEGACY))
	@# CFG_SYS_TIMER_RATE has brackets in it for some boards which
	@# confuses this rule. Use if() to send just a single character which
	@# is enable to tell 'deprecated' that one of these symbols exists
	$(call deprecated,CONFIG_TIMER,Timer drivers,v2023.01,$(if $(strip $(CFG_SYS_TIMER_RATE)$(CFG_SYS_TIMER_COUNTER)),x))
	$(call deprecated,CONFIG_DM_SERIAL,Serial drivers,v2023.04,$(CONFIG_SERIAL))
	@# Check that this build does not override OF_HAS_PRIOR_STAGE by
	@# disabling OF_BOARD.
	$(call cmd,ofcheck,$(KCONFIG_CONFIG))

PHONY += dtbs dtbs_check
dtbs: dts/dt.dtb
	@:
dts/dt.dtb: dtbs_prepare u-boot
	$(Q)$(MAKE) $(build)=dts dtbs

dtbs_prepare: prepare3

ifneq ($(filter dtbs_check, $(MAKECMDGOALS)),)
export CHECK_DTBS=y
endif

ifneq ($(CHECK_DTBS),)
dtbs_prepare: dt_binding_check
endif

dtbs_check: dt_binding_check dtbs

DT_BINDING_DIR := dts/upstream/Bindings
dt_binding_check: scripts_dtc
	$(Q)$(MAKE) $(build)=$(DT_BINDING_DIR) $(DT_BINDING_DIR)/processed-schema.json

quiet_cmd_copy = COPY    $@
      cmd_copy = cp $< $@

ifeq ($(CONFIG_OF_UPSTREAM),y)
ifeq ($(CONFIG_ARM64),y)
dt_dir := dts/upstream/src/arm64
else
dt_dir := dts/upstream/src/$(ARCH)
endif
else
dt_dir := arch/$(ARCH)/dts
endif

ifeq ($(CONFIG_MULTI_DTB_FIT),y)

ifeq ($(CONFIG_MULTI_DTB_FIT_LZO),y)
FINAL_DTB_CONTAINER = fit-dtb.blob.lzo
else ifeq ($(CONFIG_MULTI_DTB_FIT_GZIP),y)
FINAL_DTB_CONTAINER = fit-dtb.blob.gz
else
FINAL_DTB_CONTAINER = fit-dtb.blob
endif

fit-dtb.blob.gz: fit-dtb.blob
	@gzip -kf9 $< > $@

fit-dtb.blob.lzo: fit-dtb.blob
	@lzop -f9 $< > $@

fit-dtb.blob: dts/dt.dtb FORCE
	$(call if_changed,mkimage)
ifneq ($(SOURCE_DATE_EPOCH),)
	touch -d @$(SOURCE_DATE_EPOCH) fit-dtb.blob
	chmod 0600 fit-dtb.blob
endif

MKIMAGEFLAGS_fit-dtb.blob = -f auto -A $(ARCH) -T firmware -C none -O u-boot \
	-a 0 -e 0 -E \
	$(patsubst %,-b $(dt_dir)/%.dtb,$(subst ",,$(CONFIG_OF_LIST))) -d /dev/null

MKIMAGEFLAGS_fit-dtb.blob += -B 0x8

ifneq ($(EXT_DTB),)
u-boot-fit-dtb.bin: u-boot-nodtb.bin $(EXT_DTB)
		$(call if_changed,cat)
else
u-boot-fit-dtb.bin: u-boot-nodtb.bin $(FINAL_DTB_CONTAINER)
	$(call if_changed,cat)
endif

u-boot.bin: u-boot-fit-dtb.bin FORCE
	$(call if_changed,copy)

ifneq ($(CONFIG_MPC85XX_HAVE_RESET_VECTOR)$(CONFIG_OF_SEPARATE),yy)
u-boot-dtb.bin: u-boot-nodtb.bin dts/dt.dtb FORCE
	$(call if_changed,cat)
endif

else ifeq ($(CONFIG_OF_SEPARATE).$(CONFIG_OF_OMIT_DTB),y.)

ifneq ($(CONFIG_MPC85XX_HAVE_RESET_VECTOR)$(CONFIG_OF_SEPARATE),yy)
u-boot-dtb.bin: u-boot-nodtb.bin dts/dt.dtb FORCE
	$(call if_changed,cat)
endif

u-boot.bin: u-boot-dtb.bin FORCE
	$(call if_changed,copy)

else
u-boot.bin: u-boot-nodtb.bin FORCE
	$(call if_changed,copy)
endif

# we call Makefile in arch/arm/mach-imx which
# has targets which are dependent on targets defined
# here. make could not resolve them and we must ensure
# that they are finished before calling imx targets
ifeq ($(CONFIG_MULTI_DTB_FIT),y)
IMX_DEPS = u-boot-fit-dtb.bin
endif

%.imx: $(IMX_DEPS) %.bin
	$(Q)$(MAKE) $(build)=arch/arm/mach-imx $@
	$(BOARD_SIZE_CHECK)

%.vyb: %.imx
	$(Q)$(MAKE) $(build)=arch/arm/cpu/armv7/vf610 $@

quiet_cmd_copy = COPY    $@
      cmd_copy = cp $< $@

u-boot.dtb: dts/dt.dtb
	$(call cmd,copy)

OBJCOPYFLAGS_u-boot.hex := -O ihex

OBJCOPYFLAGS_u-boot.srec := -O srec

u-boot.hex u-boot.srec: u-boot FORCE
	$(call if_changed,objcopy)

OBJCOPYFLAGS_u-boot-elf.srec := $(OBJCOPYFLAGS_u-boot.srec)

u-boot-elf.srec: u-boot.elf FORCE
	$(call if_changed,objcopy)

OBJCOPYFLAGS_u-boot-spl.srec = $(OBJCOPYFLAGS_u-boot.srec)

spl/u-boot-spl.srec: spl/u-boot-spl FORCE
	$(call if_changed,objcopy)

%.scif: %.srec
	$(Q)$(MAKE) $(build)=arch/arm/mach-renesas $@

OBJCOPYFLAGS_u-boot-nodtb.bin := -O binary \
		$(if $(CONFIG_X86_16BIT_INIT),-R .start16 -R .resetvec) \
		$(if $(CONFIG_MPC85XX_HAVE_RESET_VECTOR),$(if $(CONFIG_OF_SEPARATE),-R .bootpg -R .resetvec))

binary_size_check: u-boot-nodtb.bin FORCE
	@file_size=$(shell wc -c u-boot-nodtb.bin | awk '{ print $$1 }') ; \
	map_size=$(shell cat u-boot.map | \
		awk ' \
			/_image_copy_start/ { start = $$1 } \
			/_image_binary_end/ { end = $$1 } \
			END { \
				if (start != "" && end != "") \
					print end " " start; \
			}' \
		| sh -c 'read end start && echo $$((end - start))'); \
	if [ -n "$$map_size" ]; then \
		if test $$map_size -ne $$file_size; then \
			echo "u-boot.map shows a binary size of $$map_size" >&2 ; \
			echo "  but u-boot-nodtb.bin shows $$file_size" >&2 ; \
			exit 1; \
		fi; \
	fi

ifeq ($(CONFIG_INIT_SP_RELATIVE)$(CONFIG_OF_SEPARATE),yy)
ifneq ($(CONFIG_SYS_MALLOC_F),)
subtract_sys_malloc_f_len = space=$$(($${space} - $(CONFIG_SYS_MALLOC_F_LEN)))
else
subtract_sys_malloc_f_len = true
endif
# The 1/4 margin below is somewhat arbitrary. The likely initial SP usage is
# so low that the DTB could probably use 90%+ of the available space, for
# current values of CONFIG_SYS_INIT_SP_BSS_OFFSET at least. However, let's be
# safe for now and tweak this later if space becomes tight.
# A rejected alternative would be to check that some absolute minimum stack
# space was available. However, since CONFIG_SYS_INIT_SP_BSS_OFFSET is
# deliberately build-specific, to take account of build-to-build stack usage
# differences due to different feature sets, there is no common absolute value
# to check against.
init_sp_bss_offset_check: u-boot.dtb FORCE
	@dtb_size=$(shell wc -c u-boot.dtb | awk '{print $$1}') ; \
	space=$(CONFIG_SYS_INIT_SP_BSS_OFFSET) ; \
	$(subtract_sys_malloc_f_len) ; \
	quarter_space=$$(($${space} / 4)) ; \
	if [ $${dtb_size} -gt $${quarter_space} ]; then \
		echo "u-boot.dtb is larger than 1 quarter of " >&2 ; \
		echo "(CONFIG_SYS_INIT_SP_BSS_OFFSET - CONFIG_SYS_MALLOC_F_LEN)" >&2 ; \
		exit 1 ; \
	fi
endif

shell_cmd = { $(call echo-cmd,$(1)) $(cmd_$(1)); }

quiet_cmd_objcopy_uboot = OBJCOPY $@
ifdef cmd_static_rela
cmd_objcopy_uboot = $(cmd_objcopy) && $(call shell_cmd,static_rela,$<,$@,$(CONFIG_TEXT_BASE)) || { rm -f $@; false; }
else
cmd_objcopy_uboot = $(cmd_objcopy)
endif

u-boot-nodtb.bin: u-boot FORCE
	$(call if_changed,objcopy_uboot)
	$(BOARD_SIZE_CHECK)

u-boot.ldr:	u-boot
		$(CREATE_LDR_ENV)
		$(LDR) -T $(CONFIG_LDR_CPU) -c $@ $< $(LDR_FLAGS)
		$(BOARD_SIZE_CHECK)

# binman
# ---------------------------------------------------------------------------
# Use 'make BINMAN_DEBUG=1' to enable debugging
# Use 'make BINMAN_VERBOSE=3' to set vebosity level

ifneq ($(EXT_DTB),)
ext_dtb_list := $(basename $(notdir $(EXT_DTB)))
default_dt := $(firstword $(ext_dtb_list))
of_list := "$(ext_dtb_list)"
of_list_dirs := $(dir $(EXT_DTB))
else
of_list := $(CONFIG_OF_LIST)
ifneq ($(CONFIG_OF_UPSTREAM_INCLUDE_LOCAL_FALLBACK_DTBOS),)
of_list_dirs := $(dt_dir) arch/$(ARCH)/dts
else
of_list_dirs := $(dt_dir)
endif
default_dt := $(if $(DEVICE_TREE),$(DEVICE_TREE),$(CONFIG_DEFAULT_DEVICE_TREE))
endif

quiet_cmd_binman = BINMAN  $@
cmd_binman = $(srctree)/tools/binman/binman $(if $(BINMAN_DEBUG),-D) \
		$(foreach f,$(BINMAN_TOOLPATHS),--toolpath $(f)) \
                --toolpath $(objtree)/tools \
		$(if $(BINMAN_VERBOSE),-v$(BINMAN_VERBOSE)) \
		build -u -d u-boot.dtb -O . -m \
		--allow-missing --fake-ext-blobs \
		$(if $(BINMAN_ALLOW_MISSING),--ignore-missing) \
		-I . -I $(srctree) -I $(srctree)/board/$(BOARDDIR) \
		$(foreach f,$(of_list_dirs),-I $(f)) -a of-list=$(of_list) \
		$(foreach f,$(BINMAN_INDIRS),-I $(f)) \
		-a atf-bl31-path=${BL31} \
		-a tee-os-path=${TEE} \
		-a ti-dm-path=${TI_DM} \
		-a opensbi-path=${OPENSBI} \
		-a default-dt=$(default_dt) \
		-a scp-path=$(SCP) \
		-a rockchip-tpl-path=$(ROCKCHIP_TPL) \
		-a spl-bss-pad=$(if $(CONFIG_SPL_SEPARATE_BSS),,1) \
		-a tpl-bss-pad=$(if $(CONFIG_TPL_SEPARATE_BSS),,1) \
		-a vpl-bss-pad=$(if $(CONFIG_VPL_SEPARATE_BSS),,1) \
		-a spl-dtb=$(CONFIG_SPL_OF_REAL) \
		-a tpl-dtb=$(CONFIG_TPL_OF_REAL) \
		-a vpl-dtb=$(CONFIG_VPL_OF_REAL) \
		-a pre-load-key-path=${PRE_LOAD_KEY_PATH} \
		-a of-spl-remove-props=$(CONFIG_OF_SPL_REMOVE_PROPS) \
		$(BINMAN_$(@F))

OBJCOPYFLAGS_u-boot.ldr.hex := -I binary -O ihex

OBJCOPYFLAGS_u-boot.ldr.srec := -I binary -O srec

u-boot.ldr.hex u-boot.ldr.srec: u-boot.ldr FORCE
	$(call if_changed,objcopy)

# Boards with more complex image requirements can provide an .its source file
# or a generator script
# NOTE: Please do not use this. We are migrating away from Makefile rules to use
# binman instead.
ifneq ($(CONFIG_USE_SPL_FIT_GENERATOR),)
U_BOOT_ITS := u-boot.its
$(U_BOOT_ITS): $(U_BOOT_ITS_DEPS) FORCE
	$(srctree)/$(CONFIG_SPL_FIT_GENERATOR) \
	$(patsubst %,$(dt_dir)/%.dtb,$(subst ",,$(CONFIG_OF_LIST))) > $@
endif

ifdef CONFIG_SPL_LOAD_FIT
MKIMAGEFLAGS_u-boot.img = -f auto -A $(ARCH) -T firmware -C none -O u-boot \
	-a $(CONFIG_TEXT_BASE) -e $(CONFIG_SYS_UBOOT_START) \
	-p $(CONFIG_FIT_EXTERNAL_OFFSET) \
	-n "U-Boot $(UBOOTRELEASE) for $(BOARD) board" -E \
	$(patsubst %,-b $(dt_dir)/%.dtb,$(subst ",,$(DEVICE_TREE))) \
	$(patsubst %,-b $(dt_dir)/%.dtb,$(subst ",,$(CONFIG_OF_LIST))) \
	$(patsubst %,-b $(dt_dir)/%.dtbo,$(subst ",,$(CONFIG_OF_OVERLAY_LIST)))
else
MKIMAGEFLAGS_u-boot.img = -A $(ARCH) -T firmware -C none -O u-boot \
	-a $(CONFIG_TEXT_BASE) -e $(CONFIG_SYS_UBOOT_START) \
	-n "U-Boot $(UBOOTRELEASE) for $(BOARD) board"
MKIMAGEFLAGS_u-boot-ivt.img = -A $(ARCH) -T firmware_ivt -C none -O u-boot \
	-a $(CONFIG_TEXT_BASE) -e $(CONFIG_SYS_UBOOT_START) \
	-n "U-Boot $(UBOOTRELEASE) for $(BOARD) board"
u-boot-ivt.img: MKIMAGEOUTPUT = u-boot-ivt.img.log
endif

MKIMAGEFLAGS_u-boot-dtb.img = $(MKIMAGEFLAGS_u-boot.img)

# Some boards have the kwbimage.cfg file written in advance, while some
# other boards generate it on the fly during the build in the build tree.
# Let's check if the file exists in the build tree first, otherwise we
# fall back to use the one in the source tree.
KWD_CONFIG_FILE = $(shell \
	if [ -f $(objtree)/$(CONFIG_SYS_KWD_CONFIG:"%"=%) ]; then \
		echo -n $(objtree)/$(CONFIG_SYS_KWD_CONFIG:"%"=%); \
	else \
		echo -n $(srctree)/$(CONFIG_SYS_KWD_CONFIG:"%"=%); \
	fi)

MKIMAGEFLAGS_u-boot.kwb = -n $(KWD_CONFIG_FILE) \
	-T kwbimage -a $(CONFIG_TEXT_BASE) -e $(CONFIG_TEXT_BASE)

MKIMAGEFLAGS_u-boot-with-spl.kwb = -n $(KWD_CONFIG_FILE) \
	-T kwbimage -a $(CONFIG_TEXT_BASE) -e $(CONFIG_TEXT_BASE) \
	$(if $(KEYDIR),-k $(KEYDIR))

MKIMAGEFLAGS_u-boot.pbl = -n $(srctree)/$(CONFIG_SYS_FSL_PBL_RCW:"%"=%) \
		-R $(srctree)/$(CONFIG_SYS_FSL_PBL_PBI:"%"=%) -A $(ARCH) -T pblimage

UBOOT_BIN := u-boot.bin

MKIMAGEFLAGS_u-boot-lzma.img = -A $(ARCH) -T standalone -C lzma -O u-boot \
	-a $(CONFIG_TEXT_BASE) -e $(CONFIG_SYS_UBOOT_START) \
	-n "U-Boot $(UBOOTRELEASE) for $(BOARD) board"

u-boot.bin.lzma: u-boot.bin FORCE
	$(call if_changed,lzma)

u-boot-lzma.img: u-boot.bin.lzma FORCE
	$(call if_changed,mkimage)

fit_image := $(if $(CONFIG_SANDBOX_VPL),u-boot,u-boot-nodtb.bin)

u-boot-dtb.img u-boot.img u-boot.kwb u-boot.pbl u-boot-ivt.img: \
		$(if $(CONFIG_SPL_LOAD_FIT),$(fit_image) \
			$(if $(CONFIG_OF_SEPARATE)$(CONFIG_OF_EMBED)$(CONFIG_SANDBOX),dts/dt.dtb) \
		,$(UBOOT_BIN)) FORCE
	$(call if_changed,mkimage)
	$(BOARD_SIZE_CHECK)

ifeq ($(CONFIG_SPL_LOAD_FIT_FULL),y)
MKIMAGEFLAGS_u-boot.itb =
else
MKIMAGEFLAGS_u-boot.itb = -E
endif
MKIMAGEFLAGS_u-boot.itb += -B 0x8

ifdef U_BOOT_ITS
u-boot.itb: u-boot-nodtb.bin \
		$(if $(CONFIG_OF_SEPARATE)$(CONFIG_OF_EMBED)$(CONFIG_SANDBOX),dts/dt.dtb) \
		$(if $(CONFIG_MULTI_DTB_FIT),$(FINAL_DTB_CONTAINER)) \
		$(U_BOOT_ITS) FORCE
	$(call if_changed,mkfitimage)
	$(BOARD_SIZE_CHECK)
endif

u-boot-with-spl.kwb: u-boot.bin spl/u-boot-spl.bin FORCE
	$(call if_changed,mkimage)
	$(BOARD_SIZE_CHECK)

u-boot.dis:	u-boot
		$(OBJDUMP) -d $< > $@

ifneq ($(CONFIG_SPL_PAYLOAD),)
SPL_PAYLOAD := $(CONFIG_SPL_PAYLOAD:"%"=%)
else
SPL_PAYLOAD := u-boot.bin
endif

SPL_IMAGE := $(CONFIG_SPL_IMAGE:"%"=%)

OBJCOPYFLAGS_u-boot-with-spl.bin = -I binary -O binary \
				   --pad-to=$(CONFIG_SPL_PAD_TO)
u-boot-with-spl.bin: $(SPL_IMAGE) $(SPL_PAYLOAD) FORCE
	$(call if_changed,pad_cat)

ifeq ($(CONFIG_ARCH_LPC32XX)$(CONFIG_SPL),yy)
MKIMAGEFLAGS_lpc32xx-spl.img = -T lpc32xximage -a $(CONFIG_SPL_TEXT_BASE)

lpc32xx-spl.img: spl/u-boot-spl.bin FORCE
	$(call if_changed,mkimage)

OBJCOPYFLAGS_lpc32xx-boot-0.bin = -I binary -O binary --pad-to=$(CONFIG_SPL_PAD_TO)

lpc32xx-boot-0.bin: lpc32xx-spl.img FORCE
	$(call if_changed,objcopy)

OBJCOPYFLAGS_lpc32xx-boot-1.bin = -I binary -O binary --pad-to=$(CONFIG_SPL_PAD_TO)

lpc32xx-boot-1.bin: lpc32xx-spl.img FORCE
	$(call if_changed,objcopy)

lpc32xx-full.bin: lpc32xx-boot-0.bin lpc32xx-boot-1.bin u-boot.img FORCE
	$(call if_changed,cat)

endif

OBJCOPYFLAGS_u-boot-with-tpl.bin = -I binary -O binary \
				   --pad-to=$(CONFIG_TPL_PAD_TO)
tpl/u-boot-with-tpl.bin: tpl/u-boot-tpl.bin u-boot.bin FORCE
	$(call if_changed,pad_cat)

SPL: spl/u-boot-spl.bin FORCE
	$(Q)$(MAKE) $(build)=arch/arm/mach-imx $@

#ifeq ($(CONFIG_ARCH_IMX8M)$(CONFIG_ARCH_IMX8), y)
ifeq ($(CONFIG_SPL_LOAD_IMX_CONTAINER), y)
u-boot.cnt: u-boot.bin FORCE
	$(Q)$(MAKE) $(build)=arch/arm/mach-imx $@

flash.bin: spl/u-boot-spl.bin u-boot.cnt FORCE
	$(Q)$(MAKE) $(build)=arch/arm/mach-imx $@
else
ifeq ($(CONFIG_BINMAN),y)
flash.bin: spl/u-boot-spl.bin $(INPUTS-y) FORCE
	$(call if_changed,binman)
else
flash.bin: spl/u-boot-spl.bin u-boot.itb FORCE
	$(Q)$(MAKE) $(build)=arch/arm/mach-imx $@
endif
endif
#endif

u-boot.uim: u-boot.bin FORCE
	$(Q)$(MAKE) $(build)=arch/arm/mach-imx $@

u-boot-nand.imx: u-boot.imx FORCE
	$(Q)$(MAKE) $(build)=arch/arm/mach-imx $@

u-boot-with-spl.imx u-boot-with-nand-spl.imx: SPL $(if $(CONFIG_OF_SEPARATE),u-boot.img,u-boot.uim) FORCE
	$(Q)$(MAKE) $(build)=arch/arm/mach-imx $@

MKIMAGEFLAGS_u-boot.ubl = -n $(UBL_CONFIG) -T ublimage -e $(CONFIG_TEXT_BASE)

u-boot.ubl: u-boot-with-spl.bin FORCE
	$(call if_changed,mkimage)

MKIMAGEFLAGS_u-boot-spl.ais = -s -n "/dev/null" \
	-T aisimage -e $(CONFIG_SPL_TEXT_BASE)
spl/u-boot-spl.ais: spl/u-boot-spl.bin FORCE
	$(call if_changed,mkimage)

OBJCOPYFLAGS_u-boot.ais = -I binary -O binary --pad-to=$(CONFIG_SPL_PAD_TO)
u-boot.ais: spl/u-boot-spl.ais u-boot.img FORCE
	$(call if_changed,pad_cat)

u-boot-signed.sb: u-boot.bin spl/u-boot-spl.bin
	$(Q)$(MAKE) $(build)=arch/arm/cpu/arm926ejs/mxs u-boot-signed.sb
u-boot.sb: u-boot.bin spl/u-boot-spl.bin
	$(Q)$(MAKE) $(build)=arch/arm/cpu/arm926ejs/mxs u-boot.sb

MKIMAGEFLAGS_u-boot-spl.img = -A $(ARCH) -T firmware -C none \
	-a $(CONFIG_SPL_TEXT_BASE) -e $(CONFIG_SPL_TEXT_BASE) -n XLOADER
spl/u-boot-spl.img: spl/u-boot-spl.bin FORCE
	$(call if_changed,mkimage)

ifneq ($(CONFIG_ARCH_SOCFPGA),)
quiet_cmd_gensplx4 = GENSPLX4 $@
cmd_gensplx4 = $(OBJCOPY) -I binary -O binary --gap-fill=0x0		\
			--pad-to=$(CONFIG_SPL_PAD_TO)			\
			spl/u-boot-spl.sfp spl/u-boot-spl.sfp &&        \
		cat	spl/u-boot-spl.sfp spl/u-boot-spl.sfp		\
			spl/u-boot-spl.sfp spl/u-boot-spl.sfp > $@ || { rm -f $@; false; }
spl/u-boot-splx4.sfp: spl/u-boot-spl.sfp FORCE
	$(call if_changed,gensplx4)

quiet_cmd_socboot = SOCBOOT $@
cmd_socboot = cat	spl/u-boot-splx4.sfp u-boot.img > $@ || { rm -f $@; false; }
u-boot-with-spl.sfp: spl/u-boot-splx4.sfp u-boot.img FORCE
	$(call if_changed,socboot)

quiet_cmd_gensplpadx4 = GENSPLPADX4 $@
cmd_gensplpadx4 =  dd if=/dev/zero of=spl/u-boot-spl.pad bs=64 count=1024 ; \
		   cat	spl/u-boot-spl.sfp spl/u-boot-spl.pad \
			spl/u-boot-spl.sfp spl/u-boot-spl.pad \
			spl/u-boot-spl.sfp spl/u-boot-spl.pad \
			spl/u-boot-spl.sfp spl/u-boot-spl.pad > $@ || \
			{ rm -f $@ spl/u-boot-spl.pad; false; }
u-boot-spl-padx4.sfp: spl/u-boot-spl.sfp FORCE
	$(call if_changed,gensplpadx4)

quiet_cmd_socnandboot = SOCNANDBOOT $@
cmd_socnandboot = cat	u-boot-spl-padx4.sfp u-boot.img > $@ || { rm -f $@; false; }
u-boot-with-nand-spl.sfp: u-boot-spl-padx4.sfp u-boot.img FORCE
	$(call if_changed,socnandboot)

endif

ifeq ($(CONFIG_MPC85XX_HAVE_RESET_VECTOR)$(CONFIG_OF_SEPARATE),yy)
u-boot-dtb.bin: u-boot-nodtb.bin u-boot.dtb u-boot-br.bin FORCE
	$(call if_changed,binman)

OBJCOPYFLAGS_u-boot-br.bin := -O binary -j .bootpg -j .resetvec
u-boot-br.bin: u-boot FORCE
	$(call if_changed,objcopy)
endif

quiet_cmd_ldr = LD      $@
cmd_ldr = $(LD) $(LDFLAGS_$(@F)) \
	       $(filter-out FORCE,$^) -o $@

ifdef CONFIG_X86
OBJCOPYFLAGS_u-boot-x86-start16.bin := -O binary -j .start16
u-boot-x86-start16.bin: u-boot FORCE
	$(call if_changed,objcopy)

OBJCOPYFLAGS_u-boot-x86-reset16.bin := -O binary -j .resetvec
u-boot-x86-reset16.bin: u-boot FORCE
	$(call if_changed,objcopy)

endif # CONFIG_X86

OBJCOPYFLAGS_u-boot-app.efi := $(OBJCOPYFLAGS_EFI)
u-boot-app.efi: u-boot FORCE
	$(call if_changed,zobjcopy)

u-boot.bin.o: u-boot.bin FORCE
	$(call if_changed,efipayload)

u-boot-payload.lds: $(LDSCRIPT_EFI) FORCE
	$(call if_changed_dep,cpp_lds)

# Rule to link the EFI payload which contains a stub and a U-Boot binary
quiet_cmd_u-boot_payload ?= LD      $@
      cmd_u-boot_payload ?= $(LD) $(LDFLAGS_EFI_PAYLOAD) -o $@ \
      -T u-boot-payload.lds arch/x86/cpu/call32.o \
      lib/efi/efi.o lib/efi/efi_stub.o u-boot.bin.o \
      $(addprefix arch/$(ARCH)/lib/,$(EFISTUB))

u-boot-payload: u-boot.bin.o u-boot-payload.lds FORCE
	$(call if_changed,u-boot_payload)

OBJCOPYFLAGS_u-boot-payload.efi := $(OBJCOPYFLAGS_EFI)
u-boot-payload.efi: u-boot-payload FORCE
	$(call if_changed,zobjcopy)

u-boot-img.bin: spl/u-boot-spl.bin u-boot.img FORCE
	$(call if_changed,cat)

#Add a target to create boot binary having SPL binary in PBI format
#concatenated with u-boot binary. It is need by PowerPC SoC having
#internal SRAM <= 512KB.
MKIMAGEFLAGS_u-boot-spl.pbl = -n $(srctree)/$(CONFIG_SYS_FSL_PBL_RCW:"%"=%) \
		-R $(srctree)/$(CONFIG_SYS_FSL_PBL_PBI:"%"=%) -T pblimage \
		-A $(ARCH) -a $(CONFIG_SPL_TEXT_BASE)

spl/u-boot-spl.pbl: spl/u-boot-spl.bin FORCE
	$(call if_changed,mkimage)

ifeq ($(ARCH),arm)
UBOOT_BINLOAD := u-boot.img
else
UBOOT_BINLOAD := u-boot.bin
endif

OBJCOPYFLAGS_u-boot-with-spl-pbl.bin = -I binary -O binary --pad-to=$(CONFIG_SPL_PAD_TO) \
			  --gap-fill=0xff

u-boot-with-spl-pbl.bin: spl/u-boot-spl.pbl $(UBOOT_BINLOAD) FORCE
	$(call if_changed,pad_cat)

quiet_cmd_u-boot-elf ?= LD      $@
	cmd_u-boot-elf ?= $(LD) u-boot-elf.o -o $@ \
	$(if $(CONFIG_SYS_BIG_ENDIAN),-EB,-EL) \
	-T u-boot-elf.lds --defsym=$(CONFIG_PLATFORM_ELFENTRY)=$(CONFIG_TEXT_BASE) \
	-Ttext=$(CONFIG_TEXT_BASE)
u-boot.elf: u-boot.bin u-boot-elf.lds
	$(Q)$(OBJCOPY) -I binary $(PLATFORM_ELFFLAGS) $< u-boot-elf.o
	$(call if_changed,u-boot-elf)

u-boot-elf.lds: arch/u-boot-elf.lds prepare FORCE
	$(call if_changed_dep,cpp_lds)

# MediaTek's ARM-based u-boot needs a header to contains its load address
# which is parsed by the BootROM.
# If the SPL build is enabled, the header will be added to the spl binary,
# and the spl binary and the u-boot.img will be combined into one file.
# Otherwise the header will be added to the u-boot.bin directly.

ifeq ($(CONFIG_SPL),y)
spl/u-boot-spl-mtk.bin: spl/u-boot-spl

u-boot-mtk.bin: u-boot-with-spl.bin
	$(call if_changed,copy)
else
MKIMAGEFLAGS_u-boot-mtk.bin = -T mtk_image \
	-a $(CONFIG_TEXT_BASE) -e $(CONFIG_TEXT_BASE) \
	-n "$(patsubst "%",%,$(CONFIG_MTK_BROM_HEADER_INFO))"

u-boot-mtk.bin: u-boot.bin FORCE
	$(call if_changed,mkimage)
endif

quiet_cmd_endian_swap = SWAP    $@
      cmd_endian_swap = $(srctree)/tools/endian-swap.py $< $@

u-boot-swap.bin: u-boot.bin FORCE
	$(call if_changed,endian_swap)

ARCH_POSTLINK := $(wildcard $(srctree)/arch/$(ARCH)/Makefile.postlink)

# Generate linker list symbols references to force compiler to not optimize
# them away when compiling with LTO
ifeq ($(LTO_ENABLE),y)
u-boot-keep-syms-lto := keep-syms-lto.o
u-boot-keep-syms-lto_c := $(patsubst %.o,%.c,$(u-boot-keep-syms-lto))

quiet_cmd_keep_syms_lto = KSL     $@
      cmd_keep_syms_lto = \
	$(srctree)/scripts/gen_ll_addressable_symbols.sh $(NM) $^ > $@

quiet_cmd_keep_syms_lto_cc = KSLCC   $@
      cmd_keep_syms_lto_cc = \
	$(CC) $(filter-out $(LTO_CFLAGS),$(c_flags)) -c -o $@ $<

$(u-boot-keep-syms-lto_c): $(u-boot-main)
	$(call if_changed,keep_syms_lto)
$(u-boot-keep-syms-lto): $(u-boot-keep-syms-lto_c)
	$(call if_changed,keep_syms_lto_cc)
else
u-boot-keep-syms-lto :=
endif

# Rule to link u-boot
# May be overridden by arch/$(ARCH)/config.mk
ifeq ($(LTO_ENABLE),y)
quiet_cmd_u-boot__ ?= LTO     $@
      cmd_u-boot__ ?=								\
		$(CC) -nostdlib -nostartfiles					\
		$(LTO_FINAL_LDFLAGS) $(c_flags)					\
		$(KBUILD_LDFLAGS:%=-Wl,%) $(LDFLAGS_u-boot:%=-Wl,%) -o $@	\
		-T u-boot.lds $(u-boot-init)					\
		-Wl,--whole-archive						\
			$(u-boot-main)						\
			$(u-boot-keep-syms-lto)					\
			$(PLATFORM_LIBS)					\
		-Wl,--no-whole-archive						\
		-Wl,-Map,u-boot.map;						\
		$(if $(ARCH_POSTLINK), $(MAKE) -f $(ARCH_POSTLINK) $@, true)
else
quiet_cmd_u-boot__ ?= LD      $@
      cmd_u-boot__ ?= $(LD) $(KBUILD_LDFLAGS) $(LDFLAGS_u-boot) -o $@		\
		-T u-boot.lds $(u-boot-init)					\
		--whole-archive							\
			$(u-boot-main)						\
		--no-whole-archive						\
		$(PLATFORM_LIBS) -Map u-boot.map;				\
		$(if $(ARCH_POSTLINK), $(MAKE) -f $(ARCH_POSTLINK) $@, true)
endif

quiet_cmd_smap = GEN     common/system_map.o
cmd_smap = \
	smap=`$(call SYSTEM_MAP,u-boot) | \
		awk '$$2 ~ /[tTwW]/ {printf $$1 $$3 "\\\\000"}'` ; \
	$(CC) $(c_flags) -DSYSTEM_MAP="\"$${smap}\"" \
		-c $(srctree)/common/system_map.c -o common/system_map.o

u-boot:	$(u-boot-init) $(u-boot-main) $(u-boot-keep-syms-lto) u-boot.lds FORCE
	+$(call if_changed,u-boot__)
ifeq ($(CONFIG_KALLSYMS),y)
	$(call cmd,smap)
	$(call cmd,u-boot__) common/system_map.o
endif

ifeq ($(CONFIG_RISCV),y)
	@tools/prelink-riscv $@
endif

quiet_cmd_sym ?= SYM     $@
      cmd_sym ?= $(OBJDUMP) -t $< > $@
u-boot.sym: u-boot FORCE
	$(call if_changed,sym)

# Environment processing
# ---------------------------------------------------------------------------

# Directory where we expect the .env file, if it exists
ENV_DIR := $(srctree)/board/$(BOARDDIR)

# Basename of .env file, stripping quotes
ENV_SOURCE_FILE := $(CONFIG_ENV_SOURCE_FILE:"%"=%)

# Filename of .env file
ENV_FILE_CFG := $(ENV_DIR)/$(ENV_SOURCE_FILE).env

# Default filename, if CONFIG_ENV_SOURCE_FILE is empty
ENV_FILE_BOARD := $(ENV_DIR)/$(CONFIG_SYS_BOARD:"%"=%).env

# Select between the CONFIG_ENV_SOURCE_FILE and the default one
ENV_FILE := $(if $(ENV_SOURCE_FILE),$(ENV_FILE_CFG),$(wildcard $(ENV_FILE_BOARD)))

# Run the environment text file through the preprocessor, but only if it is
# non-empty, to save time and possible build errors if something is wonky with
# the board.
# If there is no ENV_FILE, produce an empty output file, to prevent a previous
# build's file being used in the case of in-tree builds.
quiet_cmd_gen_envp = ENVP    $@
      cmd_gen_envp = \
	if [ -s "$(ENV_FILE)" ]; then \
		$(CPP) -P $(cpp_flags) -x assembler-with-cpp -undef \
			-D__ASSEMBLY__ \
			-D__UBOOT_CONFIG__ \
			-I . -I include -I $(srctree)/include \
			-include linux/kconfig.h -include include/config.h \
			-I$(srctree)/arch/$(ARCH)/include \
			$< -o $@; \
	else \
		rm -f $@; \
		touch $@ ; \
	fi
include/generated/env.in: include/generated/env.txt
	$(call cmd,gen_envp)

# Regenerate the environment if it changes
# We use 'wildcard' since the file is not required to exist (at present), in
# which case we don't want this dependency, but instead should create an empty
# file
# This rule is useful since it shows the source file for the environment
quiet_cmd_envc = ENVC    $@
      cmd_envc = \
	if [ -f "$<" ]; then \
		cat $< > $@; \
	elif [ -n "$(ENV_SOURCE_FILE)" ]; then \
		echo "Missing file $(ENV_FILE_CFG)"; \
	else \
		touch $@ ; \
	fi

include/generated/env.txt: $(wildcard $(ENV_FILE)) include/generated/autoconf.h
	$(call cmd,envc)

# Write out the resulting environment, converted to a C string
quiet_cmd_gen_envt = ENVT    $@
      cmd_gen_envt = \
	awk -f $(srctree)/scripts/env2string.awk $< >$@
$(env_h): include/generated/env.in
	$(call cmd,gen_envt)

# ---------------------------------------------------------------------------

# The actual objects are generated when descending,
# make sure no implicit rule kicks in
$(sort $(u-boot-init) $(u-boot-main)): $(u-boot-dirs) ;

# Handle descending into subdirectories listed in $(u-boot-dirs)
# Preset locale variables to speed up the build process. Limit locale
# tweaks to this spot to avoid wrong language settings when running
# make menuconfig etc.
# Error messages still appears in the original language

PHONY += $(u-boot-dirs)
$(u-boot-dirs): prepare scripts
	$(Q)$(MAKE) $(build)=$@

tools: prepare
# The "tools" are needed early
$(filter-out tools, $(u-boot-dirs)): tools
# The "examples" conditionally depend on U-Boot (say, when USE_PRIVATE_LIBGCC
# is "yes"), so compile examples after U-Boot is compiled.
examples: $(filter-out examples, $(u-boot-dirs))

# The setlocalversion script comes from linux and expects a
# KERNELVERSION variable in the environment for figuring out which
# annotated tags are relevant. Pass UBOOTVERSION.
define filechk_uboot.release
	KERNELVERSION=$(UBOOTVERSION) $(CONFIG_SHELL) $(srctree)/scripts/setlocalversion $(srctree)
endef

# Store (new) UBOOTRELEASE string in include/config/uboot.release
include/config/uboot.release: include/config/auto.conf FORCE
	$(call filechk,uboot.release)


# Things we need to do before we recursively start building the kernel
# or the modules are listed in "prepare".
# A multi level approach is used. prepareN is processed before prepareN-1.
# archprepare is used in arch Makefiles and when processed asm symlink,
# version.h and scripts_basic is processed / created.

# Listed in dependency order
PHONY += prepare archprepare prepare0 prepare1 prepare2 prepare3

# prepare3 is used to check if we are building in a separate output directory,
# and if so do:
# 1) Check that make has not been executed in the kernel src $(srctree)
prepare3: include/config/uboot.release
ifneq ($(KBUILD_SRC),)
	@$(kecho) '  Using $(srctree) as source for U-Boot'
	$(Q)if [ -f $(srctree)/.config -o -d $(srctree)/include/config ]; then \
		echo >&2 "  $(srctree) is not clean, please run 'make mrproper'"; \
		echo >&2 "  in the '$(srctree)' directory.";\
		/bin/false; \
	fi;
endif

# prepare2 creates a makefile if using a separate output directory
prepare2: prepare3 outputmakefile cfg

prepare1: prepare2 $(version_h) $(timestamp_h) $(dt_h) $(env_h) \
                   include/config/auto.conf
ifeq ($(wildcard $(LDSCRIPT)),)
	@echo >&2 "  Could not find linker script."
	@/bin/false
endif

ifeq ($(CONFIG_USE_DEFAULT_ENV_FILE),y)
prepare1: $(defaultenv_h)

envtools: $(defaultenv_h)
endif

archprepare: prepare1 scripts_basic

prepare0: archprepare FORCE
	$(Q)$(MAKE) $(build)=.

# All the preparing..
prepare: prepare0

# Generate some files
# ---------------------------------------------------------------------------

# Use sed to remove leading zeros from PATCHLEVEL to avoid using octal numbers
define filechk_version.h
	(echo \#define PLAIN_VERSION \"$(UBOOTRELEASE)\"; \
	echo \#define U_BOOT_VERSION \"U-Boot \" PLAIN_VERSION; \
	echo \#define U_BOOT_VERSION_NUM $(VERSION); \
	echo \#define U_BOOT_VERSION_NUM_PATCH $$(echo $(PATCHLEVEL) | \
		sed -e "s/^0*//"); \
	echo \#define HOST_ARCH $(HOST_ARCH); \
	echo \#define CC_VERSION_STRING \"$$(LC_ALL=C $(CC) --version | head -n 1)\"; \
	echo \#define LD_VERSION_STRING \"$$(LC_ALL=C $(LD) --version | head -n 1)\"; )
endef

# The SOURCE_DATE_EPOCH mechanism requires a date that behaves like GNU date.
# The BSD date on the other hand behaves different and would produce errors
# with the misused '-d' switch.  Respect that and search a working date with
# well known pre- and suffixes for the GNU variant of date.
define filechk_timestamp.h
	(if test -n "$${SOURCE_DATE_EPOCH}"; then \
		SOURCE_DATE="@$${SOURCE_DATE_EPOCH}"; \
		DATE=""; \
		for date in gdate date.gnu date; do \
			$${date} -u -d "$${SOURCE_DATE}" >/dev/null 2>&1 && DATE="$${date}"; \
		done; \
		if test -n "$${DATE}"; then \
			LC_ALL=C $${DATE} -u -d "$${SOURCE_DATE}" +'#define U_BOOT_DATE "%b %d %C%y"'; \
			LC_ALL=C $${DATE} -u -d "$${SOURCE_DATE}" +'#define U_BOOT_TIME "%T"'; \
			LC_ALL=C $${DATE} -u -d "$${SOURCE_DATE}" +'#define U_BOOT_TZ "%z"'; \
			LC_ALL=C $${DATE} -u -d "$${SOURCE_DATE}" +'#define U_BOOT_EPOCH %s'; \
		else \
			return 42; \
		fi; \
	else \
		LC_ALL=C date +'#define U_BOOT_DATE "%b %d %C%y"'; \
		LC_ALL=C date +'#define U_BOOT_TIME "%T"'; \
		LC_ALL=C date +'#define U_BOOT_TZ "%z"'; \
		LC_ALL=C date +'#define U_BOOT_EPOCH %s'; \
	fi)
endef

define filechk_defaultenv.h
	( { grep -v '^#' | grep -v '^$$' || true ; echo '' ; } | \
	 tr '\n' '\0' | \
	 sed -e 's/\\\x0\s*//g' | \
	 xxd -i ; )
endef

define filechk_dt.h
	(if test -n "$${DEVICE_TREE}"; then \
		echo \#define DEVICE_TREE \"$(DEVICE_TREE)\"; \
	else \
		echo \#define DEVICE_TREE CONFIG_DEFAULT_DEVICE_TREE; \
	fi)
endef

$(version_h): include/config/uboot.release FORCE
	$(call filechk,version.h)

$(timestamp_h): $(srctree)/Makefile FORCE
	$(call filechk,timestamp.h)

$(dt_h): $(srctree)/Makefile FORCE
	$(call filechk,dt.h)

$(defaultenv_h): $(CONFIG_DEFAULT_ENV_FILE:"%"=%) FORCE
	$(call filechk,defaultenv.h)

# ---------------------------------------------------------------------------
# Devicetree files

ifneq ($(wildcard $(srctree)/arch/$(SRCARCH)/boot/dts/),)
dtstree := arch/$(SRCARCH)/boot/dts
endif

ifneq ($(dtstree),)

%.dtb: prepare3 scripts_dtc
	$(Q)$(MAKE) $(build)=$(dtstree) $(dtstree)/$@

PHONY += dtbs dtbs_install
dtbs: prepare3 scripts_dtc
	$(Q)$(MAKE) $(build)=$(dtstree)

dtbs_install:
	$(Q)$(MAKE) $(dtbinst)=$(dtstree)

endif

# Check dtc and pylibfdt, if DTC is provided, else build them
PHONY += scripts_dtc
# 这行代码检查 $(DTC) 是否等于 $(DTC_INTREE)，即检查是否使用内置的 DTC
# 如果是，则调用 make 构建 dtc 目录中的内容
# 如果不是，则检查 DTC 是否可用，检查 DTC 的版本
# 检查 pylibfdt 是否可用
scripts_dtc: scripts_basic
	$(Q)if test "$(DTC)" = "$(DTC_INTREE)"; then \
		$(MAKE) $(build)=scripts/dtc; \
	else \
		if ! $(DTC) -v >/dev/null; then \
			echo '*** Failed to check dtc version: $(DTC)'; \
			false; \
		else \
			if test "$(call dtc-version)" -lt $(DTC_MIN_VERSION); then \
				echo '*** Your dtc is too old, please upgrade to dtc $(DTC_MIN_VERSION) or newer'; \
				false; \
			else \
				if [ -n "$(CONFIG_PYLIBFDT)" ]; then \
					if ! echo "import libfdt" | $(PYTHON3) 2>/dev/null; then \
						echo '*** pylibfdt does not seem to be available with $(PYTHON3)'; \
						false; \
					fi; \
				fi; \
			fi; \
		fi; \
	fi

# ---------------------------------------------------------------------------
quiet_cmd_cpp_lds = LDS     $@
cmd_cpp_lds = $(CPP) -Wp,-MD,$(depfile) $(cpp_flags) $(LDPPFLAGS) \
		-D__ASSEMBLY__ -x assembler-with-cpp -std=c99 -P -o $@ $<

u-boot.lds: $(LDSCRIPT) prepare FORCE
	$(call if_changed_dep,cpp_lds)

spl/u-boot-spl.bin: spl/u-boot-spl
	@:
	$(SPL_SIZE_CHECK)

spl/u-boot-spl-dtb.bin: spl/u-boot-spl
	@:

spl/u-boot-spl-dtb.hex: spl/u-boot-spl
	@:

spl/u-boot-spl: tools prepare $(if $(CONFIG_SPL_OF_CONTROL),dts/dt.dtb)
	$(Q)$(MAKE) obj=spl -f $(srctree)/scripts/Makefile.xpl all

spl/sunxi-spl.bin: spl/u-boot-spl
	@:

spl/sunxi-spl-with-ecc.bin: spl/sunxi-spl.bin
	@:

spl/u-boot-spl.sfp: spl/u-boot-spl
	@:

spl/boot.bin: spl/u-boot-spl
	@:

tpl/u-boot-tpl.bin: tpl/u-boot-tpl
	@:
	$(TPL_SIZE_CHECK)

tpl/u-boot-tpl: tools prepare $(if $(CONFIG_TPL_OF_CONTROL),dts/dt.dtb)
	$(Q)$(MAKE) obj=tpl -f $(srctree)/scripts/Makefile.xpl all

vpl/u-boot-vpl.bin: vpl/u-boot-vpl
	@:
	$(VPL_SIZE_CHECK)

vpl/u-boot-vpl: tools prepare $(if $(CONFIG_TPL_OF_CONTROL),dts/dt.dtb)
	$(Q)$(MAKE) obj=vpl -f $(srctree)/scripts/Makefile.xpl all

TAG_SUBDIRS := $(patsubst %,$(srctree)/%,$(u-boot-dirs) include)

FIND := find
FINDFLAGS := -L

tags ctags:
		ctags -w -o ctags `$(FIND) $(FINDFLAGS) $(TAG_SUBDIRS) \
						-name '*.[chS]' -print`
		ln -s ctags tags

etags:
		etags -a -o etags `$(FIND) $(FINDFLAGS) $(TAG_SUBDIRS) \
						-name '*.[chS]' -print`
cscope:
		$(FIND) $(FINDFLAGS) $(TAG_SUBDIRS) -name '*.[chS]' -print > \
						cscope.files
		@find $(TAG_SUBDIRS) -name '*.[chS]' -type l -print | \
			grep -xvf - cscope.files > cscope.files.no-symlinks; \
		mv cscope.files.no-symlinks cscope.files
		cscope -b -q -k

SYSTEM_MAP = \
		$(NM) $1 | \
		grep -v '\(compiled\)\|\(\.o$$\)\|\( [aUw] \)\|\(\.\.ng$$\)\|\(LASH[RL]DI\)' | \
		LC_ALL=C sort
System.map:	u-boot
		@$(call SYSTEM_MAP,$<) > $@

#########################################################################

# ARM relocations should all be R_ARM_RELATIVE (32-bit) or
# R_AARCH64_RELATIVE (64-bit).
checkarmreloc: u-boot
	@RELOC="`$(CROSS_COMPILE)readelf -r -W $< | cut -d ' ' -f 4 | \
		grep R_A | sort -u`"; \
	if test "$$RELOC" != "R_ARM_RELATIVE" -a \
		 "$$RELOC" != "R_AARCH64_RELATIVE"; then \
		echo "$< contains unexpected relocations: $$RELOC"; \
		false; \
	fi

tools/version.h: include/version.h
	$(Q)mkdir -p $(dir $@)
	$(call if_changed,copy)

envtools: u-boot-initial-env scripts_basic $(version_h) $(timestamp_h) tools/version.h
	$(Q)$(MAKE) $(build)=tools/env

tools-only: export TOOLS_ONLY=y
tools-only: scripts_basic $(version_h) $(timestamp_h) tools/version.h
	$(Q)$(MAKE) $(build)=tools

tools-all: export HOST_TOOLS_ALL=y
tools-all: envtools tools ;

cross_tools: export CROSS_BUILD_TOOLS=y
cross_tools: tools ;

.PHONY : CHANGELOG
CHANGELOG:
	git log --no-merges U-Boot-1_1_5.. | \
	unexpand -a | sed -e 's/\s\s*$$//' > $@

#########################################################################

###
# Cleaning is done on three levels.
# make clean     Delete most generated files
#                Leave enough to build external modules
# make mrproper  Delete the current configuration, and all generated files
# make distclean Remove editor backup files, patch leftover files and the like

# Directories & files removed with 'make clean'
CLEAN_DIRS  += $(MODVERDIR) \
	       $(foreach d, spl tpl vpl, $(patsubst %,$d/%, \
			$(filter-out include, $(shell ls -1 $d 2>/dev/null))))

CLEAN_FILES += include/autoconf.mk* include/bmp_logo.h include/bmp_logo_data.h \
	       include/config.h include/generated/env.* drivers/video/u_boot_logo.S \
	       tools/version.h u-boot* MLO* SPL System.map fit-dtb.blob* \
	       u-boot-ivt.img.log u-boot-dtb.imx.log SPL.log u-boot.imx.log \
	       lpc32xx-* bl31.c bl31.elf bl31_*.bin image.map tispl.bin* \
	       idbloader.img flash.bin flash.log defconfig keep-syms-lto.c \
	       mkimage-out.spl.mkimage mkimage.spl.mkimage imx-boot.map \
	       itb.fit.fit itb.fit.itb itb.map spl.map mkimage-out.rom.mkimage \
	       mkimage.rom.mkimage mkimage-in-simple-bin* rom.map simple-bin* \
	       idbloader-spi.img lib/efi_loader/helloworld_efi.S *.itb \
	       Test* capsule.*.efi-capsule capsule*.map

# Directories & files removed with 'make mrproper'
MRPROPER_DIRS  += include/config include/generated spl tpl vpl \
		  .tmp_objdiff doc/output include/asm

# Remove include/asm symlink created by U-Boot before v2014.01
MRPROPER_FILES += .config .config.old include/autoconf.mk* include/config.h \
		  ctags etags tags TAGS cscope* GPATH GTAGS GRTAGS GSYMS \
		  drivers/video/fonts/*.S include/asm *imx8mimage* *imx8mcst*

# clean - Delete most, but leave enough to build external modules
#
clean: rm-dirs  := $(CLEAN_DIRS)
clean: rm-files := $(CLEAN_FILES)

clean-dirs	:= $(foreach f,$(u-boot-alldirs),$(if $(wildcard $(srctree)/$f/Makefile),$f))

clean-dirs      := $(addprefix _clean_, $(clean-dirs))

PHONY += $(clean-dirs) clean archclean
$(clean-dirs):
	$(Q)$(MAKE) $(clean)=$(patsubst _clean_%,%,$@)

clean: $(clean-dirs)
	$(call cmd,rmdirs)
	$(call cmd,rmfiles)
	@find $(if $(KBUILD_EXTMOD), $(KBUILD_EXTMOD), .) $(RCS_FIND_IGNORE) \
		\( -name '*.[oas]' -o -name '*.ko' -o -name '.*.cmd' \
		-o -name '*.ko.*' -o -name '*.su' -o -name '*.pyc' \
		-o -name '*.dtb' -o -name '*.dtbo' \
		-o -name '*.dtb.S' -o -name '*.dtbo.S' \
		-o -name '.*.d' -o -name '.*.tmp' -o -name '*.mod.c' \
		-o -name '*.lex.c' -o -name '*.tab.[ch]' \
		-o -name '*.asn1.[ch]' \
		-o -name '*.symtypes' -o -name 'modules.order' \
		-o -name modules.builtin -o -name '.tmp_*.o.*' \
		-o -name 'dsdt_generated.aml' -o -name 'dsdt_generated.asl.tmp' \
		-o -name 'dsdt_generated.c' \
		-o -name 'generated_defconfig' \
		-o -name '*.efi' -o -name '*.gcno' -o -name '*.so' \) \
		-type f -print | xargs rm -f

# mrproper - Delete all generated files, including .config
#
mrproper: rm-dirs  := $(wildcard $(MRPROPER_DIRS))
mrproper: rm-files := $(wildcard $(MRPROPER_FILES))
mrproper-dirs      := $(addprefix _mrproper_,scripts)

PHONY += $(mrproper-dirs) mrproper archmrproper
$(mrproper-dirs):
	$(Q)$(MAKE) $(clean)=$(patsubst _mrproper_%,%,$@)

mrproper: clean $(mrproper-dirs)
	$(call cmd,rmdirs)
	$(call cmd,rmfiles)
	@rm -f arch/*/include/asm/arch

# distclean
#
PHONY += distclean

distclean: mrproper
	@find $(srctree) $(RCS_FIND_IGNORE) \
		\( -name '*.orig' -o -name '*.rej' -o -name '*~' \
		-o -name '*.bak' -o -name '#*#' -o -name '.*.orig' \
		-o -name '.*.rej' -o -name '*%' -o -name 'core' \
		-o -name '*.pyc' \) \
		-type f -print | xargs rm -f
	@rm -f boards.cfg CHANGELOG

# See doc/develop/python_cq.rst
PHONY += pylint pylint_err
PYLINT_BASE := scripts/pylint.base
PYLINT_CUR := pylint.cur
PYLINT_DIFF := pylint.diff
pylint:
	$(Q)echo "Running pylint on all files (summary in $(PYLINT_CUR); output in pylint.out/)"
	$(Q)mkdir -p pylint.out
	$(Q)rm -f pylint.out/out*
	$(Q)find tools test -name "*.py" \
		| xargs -n1 -P$(shell nproc 2>/dev/null || echo 1) \
			sh -c 'pylint --reports=y --exit-zero -f parseable --ignore-imports=yes $$@ > pylint.out/$$(echo $$@ | tr / _ | sed s/.py//)' _
	$(Q)rm -f $(PYLINT_CUR)
	$(Q)( cd pylint.out; for f in *; do \
		sed -ne "s/Your code has been rated at \([-0-9.]*\).*/$$f \1/p" $$f; \
	done ) | sort > $(PYLINT_CUR)
	$(Q)base=$$(mktemp) cur=$$(mktemp); cut -d' ' -f1 $(PYLINT_BASE) >$$base; \
		cut -d' ' -f1 $(PYLINT_CUR) >$$cur; \
		comm -3 $$base $$cur > $(PYLINT_DIFF); \
		if [ -s $(PYLINT_DIFF) ]; then \
			echo "Files have been added/removed. Try:\n\tcp $(PYLINT_CUR) $(PYLINT_BASE)"; \
			echo; \
			echo "Added files:"; \
			comm -13 $$base $$cur; \
			echo; \
			echo "Removed files:"; \
			comm -23 $$base $$cur; \
			false; \
		else \
			rm $$base $$cur $(PYLINT_DIFF); \
		fi
	$(Q)bad=false; while read base_file base_val <&3 && read cur_file cur_val <&4; do \
		if awk "BEGIN {exit !($$cur_val < $$base_val)}"; then \
			echo "$$base_file: Score was $$base_val, now $$cur_val"; \
			bad=true; fi; \
		done 3<$(PYLINT_BASE) 4<$(PYLINT_CUR); \
		if $$bad; then \
			echo "Some files have regressed, please fix"; \
			false; \
		else \
			echo "No pylint regressions"; \
		fi

# Check for errors only
pylint_err:
	$(Q)pylint -E  -j 0 --ignore-imports=yes \
		$(shell find tools test -name "*.py")

backup:
	F=`basename $(srctree)` ; cd .. ; \
	gtar --force-local -zcvf `LC_ALL=C date "+$$F-%Y-%m-%d-%T.tar.gz"` $$F

PHONY += _pip pip pip_release

pip_release: PIP_ARGS="--real"
pip_test: PIP_ARGS=""
pip: PIP_ARGS="-n"

pip pip_test pip_release: _pip

_pip:
	scripts/make_pip.sh u_boot_pylib ${PIP_ARGS}
	scripts/make_pip.sh patman ${PIP_ARGS}
	scripts/make_pip.sh buildman ${PIP_ARGS}
	scripts/make_pip.sh dtoc ${PIP_ARGS}
	scripts/make_pip.sh binman ${PIP_ARGS}

help:
	@echo  'Cleaning targets:'
	@echo  '  clean		  - Remove most generated files but keep the config'
	@echo  '  mrproper	  - Remove all generated files + config + various backup files'
	@echo  '  distclean	  - mrproper + remove editor backup and patch files'
	@echo  ''
	@echo  'Configuration targets:'
	@$(MAKE) -f $(srctree)/scripts/kconfig/Makefile help
	@echo  ''
	@echo  'Test targets:'
	@echo  ''
	@echo  '  check           - Run all automated tests that use sandbox'
	@echo  '  pcheck          - Run quick automated tests in parallel'
	@echo  '  qcheck          - Run quick automated tests that use sandbox'
	@echo  '  tcheck          - Run quick automated tests on tools'
	@echo  '  pylint          - Run pylint on all Python files'
	@echo  ''
	@echo  'Other generic targets:'
	@echo  '  all		  - Build all necessary images depending on configuration'
	@echo  '  tests		  - Build U-Boot for sandbox and run tests'
	@echo  '* u-boot	  - Build the bare u-boot'
	@echo  '  dir/            - Build all files in dir and below'
	@echo  '  dir/file.[oisS] - Build specified target only'
	@echo  '  dir/file.lst    - Build specified mixed source/assembly target only'
	@echo  '                    (requires a recent binutils and recent build (System.map))'
	@echo  '  tags/ctags	  - Generate ctags file for editors'
	@echo  '  etags		  - Generate etags file for editors'
	@echo  '  cscope	  - Generate cscope index'
	@echo  '  ubootrelease	  - Output the release version string (use with make -s)'
	@echo  '  ubootversion	  - Output the version stored in Makefile (use with make -s)'
	@echo  "  cfg		  - Don't build, just create the .cfg files"
	@echo  "  envtools	  - Build only the target-side environment tools"
	@echo  ''
	@echo  'PyPi / pip targets:'
	@echo  '  pip             - Check building of PyPi packages'
	@echo  '  pip_test        - Build PyPi pakages and upload to test server'
	@echo  '  pip_release     - Build PyPi pakages and upload to release server'
	@echo  ''
	@echo  'Static analysers'
	@echo  '  checkstack      - Generate a list of stack hogs'
	@echo  '  coccicheck      - Execute static code analysis with Coccinelle'
	@echo  ''
	@echo  'Documentation targets:'
	@$(MAKE) -f $(srctree)/doc/Makefile dochelp
	@echo  ''
	@echo  '  make V=0|1 [targets] 0 => quiet build (default), 1 => verbose build'
	@echo  '  make V=2   [targets] 2 => give reason for rebuild of target'
	@echo  '  make O=dir [targets] Locate all output files in "dir", including .config'
	@echo  '  make C=1   [targets] Check all c source with $$CHECK (sparse by default)'
	@echo  '  make C=2   [targets] Force check of all c source with $$CHECK'
	@echo  '  make RECORDMCOUNT_WARN=1 [targets] Warn about ignored mcount sections'
	@echo  '  make W=n   [targets] Enable extra gcc checks, n=1,2,3 where'
	@echo  '		1: warnings which may be relevant and do not occur too often'
	@echo  '		2: warnings which occur quite often but may still be relevant'
	@echo  '		3: more obscure warnings, can most likely be ignored'
	@echo  '		Multiple levels can be combined with W=12 or W=123'
	@echo  ''
	@echo  'Execute "make" or "make all" to build all targets marked with [*] '
	@echo  'For further info see the ./README file'

tests check:
	$(srctree)/test/run

pcheck:
	$(srctree)/test/run parallel

qcheck:
	$(srctree)/test/run quick

tcheck:
	$(srctree)/test/run tools

# Documentation targets
# ---------------------------------------------------------------------------
DOC_TARGETS := xmldocs latexdocs pdfdocs htmldocs epubdocs cleandocs \
	       linkcheckdocs dochelp refcheckdocs texinfodocs infodocs
PHONY += $(DOC_TARGETS)
$(DOC_TARGETS): scripts_basic FORCE
	$(Q)$(MAKE) $(build)=doc $@

PHONY += checkstack ubootrelease ubootversion

checkstack:
	$(OBJDUMP) -d u-boot $$(find . -name u-boot-spl) | \
	$(PERL) $(src)/scripts/checkstack.pl $(ARCH)

ubootrelease:
	@$(filechk_uboot.release)

ubootversion:
	@echo $(UBOOTVERSION)

# Single targets
# ---------------------------------------------------------------------------
# Single targets are compatible with:
# - build with mixed source and output
# - build with separate output dir 'make O=...'
# - external modules
#
#  target-dir => where to store outputfile
#  build-dir  => directory in kernel source tree to use

ifeq ($(KBUILD_EXTMOD),)
        build-dir  = $(patsubst %/,%,$(dir $@))
        target-dir = $(dir $@)
else
        zap-slash=$(filter-out .,$(patsubst %/,%,$(dir $@)))
        build-dir  = $(KBUILD_EXTMOD)$(if $(zap-slash),/$(zap-slash))
        target-dir = $(if $(KBUILD_EXTMOD),$(dir $<),$(dir $@))
endif

%.s: %.c prepare scripts FORCE
	$(Q)$(MAKE) $(build)=$(build-dir) $(target-dir)$(notdir $@)
%.i: %.c prepare scripts FORCE
	$(Q)$(MAKE) $(build)=$(build-dir) $(target-dir)$(notdir $@)
%.o: %.c prepare scripts FORCE
	$(Q)$(MAKE) $(build)=$(build-dir) $(target-dir)$(notdir $@)
%.lst: %.c prepare scripts FORCE
	$(Q)$(MAKE) $(build)=$(build-dir) $(target-dir)$(notdir $@)
%.s: %.S prepare scripts FORCE
	$(Q)$(MAKE) $(build)=$(build-dir) $(target-dir)$(notdir $@)
%.o: %.S prepare scripts FORCE
	$(Q)$(MAKE) $(build)=$(build-dir) $(target-dir)$(notdir $@)
%.symtypes: %.c prepare scripts FORCE
	$(Q)$(MAKE) $(build)=$(build-dir) $(target-dir)$(notdir $@)

# Modules
/: prepare scripts FORCE
	$(cmd_crmodverdir)
	$(Q)$(MAKE) KBUILD_MODULES=$(if $(CONFIG_MODULES),1) \
	$(build)=$(build-dir)
%/: prepare scripts FORCE
	$(cmd_crmodverdir)
	$(Q)$(MAKE) KBUILD_MODULES=$(if $(CONFIG_MODULES),1) \
	$(build)=$(build-dir)
%.ko: prepare scripts FORCE
	$(cmd_crmodverdir)
	$(Q)$(MAKE) KBUILD_MODULES=$(if $(CONFIG_MODULES),1)   \
	$(build)=$(build-dir) $(@:.ko=.o)
	$(Q)$(MAKE) -f $(srctree)/scripts/Makefile.modpost

quiet_cmd_genenv = GENENV  $@
cmd_genenv = \
	$(objtree)/tools/printinitialenv | \
	sed -e '/^\s*$$/d' | \
	sort -t '=' -k 1,1 -s -o $@

u-boot-initial-env: scripts_basic $(env_h) FORCE
	$(Q)$(MAKE) $(build)=tools $(objtree)/tools/printinitialenv
	$(call if_changed,genenv)

# Consistency checks
# ---------------------------------------------------------------------------

PHONY += coccicheck

coccicheck:
	$(Q)$(CONFIG_SHELL) $(srctree)/scripts/$@

# FIXME Should go into a make.lib or something
# ===========================================================================

quiet_cmd_rmdirs = $(if $(wildcard $(rm-dirs)),CLEAN   $(wildcard $(rm-dirs)))
      cmd_rmdirs = rm -rf $(rm-dirs)

quiet_cmd_rmfiles = $(if $(wildcard $(rm-files)),CLEAN   $(wildcard $(rm-files)))
      cmd_rmfiles = rm -f $(rm-files)

# read all saved command lines

cmd_files := $(wildcard .*.cmd)

ifneq ($(cmd_files),)
  $(cmd_files): ;	# Do not try to update included dependency files
  include $(cmd_files)
endif

endif    #ifeq ($(config-targets),1)
endif    #ifeq ($(mixed-targets),1)
endif	# skip-makefile

PHONY += FORCE
FORCE:

# 将 PHONY 变量的内容声明为 phony。 我们保留这一点信息，以便我们可以在 if_changed 和 Friends 中使用它。
.PHONY: $(PHONY)
