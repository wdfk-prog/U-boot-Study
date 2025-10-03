---
title: u-boot_make
date: 2025-10-03 09:44:27
categories:
  - uboot
  - 子目录
tags:
  - uboot
  - 子目录
---
# _all: 第一个目标 执行这个

```makefile
# 这是我们的默认目标，当命令行上没有给出
PHONY := _all
_all:

# 如果构建外部模块，我们不关心 all： 规则
# 而是_all依赖于模块
PHONY += all
ifeq ($(KBUILD_EXTMOD),)
_all: all
else
_all: modules
endif
```

# all:

```makefile
# Timestamp 文件，以确保 binman 始终运行
.binman_stamp: $(INPUTS-y) FORCE
ifeq ($(CONFIG_BINMAN),y)
	$(call if_changed,binman)
endif
	@touch $@

all: .binman_stamp
```

- 依赖`$(INPUTS-y)`,优先执行

# 依赖 $(INPUTS-y) 导入特定规则

```makefile
-include include/autoconf.mk
-include include/autoconf.mk.dep
#如果.config比auto.conf新，则重新生成auto.conf
include config.mk
include arch/$(ARCH)/Makefile

# 始终附加 INPUTS，以便 arch config.mk 可以添加自定义 INPUTS
INPUTS-y += u-boot.srec u-boot.bin u-boot.sym System.map binary_size_check
# 如果在 board/cpu/soc 头文件中定义，则添加可选的构建目标
```

- 所以`INPUTS-y`在`arch/arm/config.mk`中导入

	```shell
	# makefile (从“arch/arm/config.mk”，行 131) 
	INPUTS-y = checkarmreloc
	```

	```makefile
	ifneq ($(CONFIG_XPL_BUILD),y)
	# Check that only R_ARM_RELATIVE relocations are generated.
	INPUTS-y += checkarmreloc
	endif
	```
- 所以`$INPUTS-y = checkarmreloc u-boot.srec u-boot.bin u-boot.sym System.map binary_size_check`
- checkarmreloc 检查ARM重定向 32或64位
- u-boot.srec 进行对u-boot文件进行空白填充0XFF处理
- u-boot.bin 生成u-boot.bin文件, 把u-boot-nodtb.bin和dts/dt.dtb打包成u-boot-dtb.bin,然后重命名为u-boot.bin
- u-boot.sym: 生成 u-boot.sym 文件，该文件包含 u-boot 二进制文件的符号表
```makefile
quiet_cmd_sym ?= SYM     $@
      cmd_sym ?= $(OBJDUMP) -t $< > $@
u-boot.sym: u-boot FORCE
	$(call if_changed,sym)
```
- System.map: 生成 System.map 文件，该文件包含 u-boot 二进制文件的符号表
```makefile
SYSTEM_MAP = \
		$(NM) $1 | \
		grep -v '\(compiled\)\|\(\.o$$\)\|\( [aUw] \)\|\(\.\.ng$$\)\|\(LASH[RL]DI\)' | \
		LC_ALL=C sort
System.map:	u-boot
		@$(call SYSTEM_MAP,$<) > $@
```
- binary_size_check:bin文件是否超过范围大小

# KCONFIG_CONFIG

```makefile
KCONFIG_CONFIG	?= .config
export KCONFIG_CONFIG
```

- `$(KCONFIG_CONFIG) include/config/auto.conf.cmd: ;`
- 这条语句定义了一个目标，它包含两个文件：$(KCONFIG_CONFIG) 和 auto.conf.cmd。当这两个文件被调用时，执行一个空命令;这意味着这两个文件是一起作为一个目标的，只有在这两个文件都存在时，才会执行空命令

# autoconf_is_old 判断autoconf有更新,导入规则文件

```makefile
# 我们只希望在 include/config/auto.conf 是最新的时才包含 arch/$（ARCH）/config.mk。
#当我们切换到不同的板子配amp;置amp;时，旧的 CONFIG 宏仍然保留在 include/config/auto.conf 中。如果没有以下噱头，错误 config.mk 将包含在导致令人讨厌的警告/错误。
ifneq ($(wildcard $(KCONFIG_CONFIG)),)  # KCONFIG_CONFIG = .config
ifneq ($(wildcard include/config/auto.conf),) # include/config/auto.conf不为空是第二次执行xxxdefconfig
# 查找 .config 是否比 include/config/auto.conf 新
# 如果不是更新的,则包含config.mk,否则不包含,重新生成
autoconf_is_old := $(shell find . -path ./$(KCONFIG_CONFIG) -newer \
						include/config/auto.conf)
ifeq ($(autoconf_is_old),)
include config.mk
include arch/$(ARCH)/Makefile
endif
endif
endif
```

# config.mk	-- 导入特定的规则 cpu,架构,board等特殊规则导入
- 从顶层makefile中导入
```makefile
#从顶层makefile
# Read in config
-include include/config/auto.conf

ifeq ($(autoconf_is_old),)
include config.mk
include arch/$(ARCH)/Makefile
endif

# config.mk
# (CONFIG_SYS_xxx 在include/config/auto.conf中定义
#替换CONFIG_SYS_ARCH中所有 " 替换为 
ARCH := $(CONFIG_SYS_ARCH:"%"=%)	#ARCH命令行传入arm
CPU := $(CONFIG_SYS_CPU:"%"=%)		#CPU = armv7m
BOARD := $(CONFIG_SYS_BOARD:"%"=%) 	#BOARD = stm32h750-art-pi
ifneq ($(CONFIG_SYS_VENDOR),)
VENDOR := $(CONFIG_SYS_VENDOR:"%"=%)# VENDOR = st
endif
ifneq ($(CONFIG_SYS_SOC),)
SOC := $(CONFIG_SYS_SOC:"%"=%)		# SOC = stm32h7
endif

# 一些架构 config.mk 文件需要知道 CPUDIR 的设置，因此在包含 ARCH/SOC/CPU config.mk 文件之前计算 CPUDIR。
# 检查 arch/$ARCH/cpu/$CPU 是否存在，否则假设 arch/$ARCH/cpu 包含
# 特定于 CPU 的代码。 
CPUDIR=arch/$(ARCH)/cpu$(if $(CPU),/$(CPU),)	# CPUDIR = arch/arm/cpu/armv7m
# 包含架构依赖规则
sinclude $（srctree）/arch/$（ARCH）/config.mk	# include ./arch/arm/config.mk
# 包含 CPU 特定规则
sinclude $（srctree）/$（CPUDIR）/config.mk		# include ./arch/arm/cpu/armv7m/config.mk

ifneq ($(BOARD),)
ifdef	VENDOR
BOARDDIR = $(VENDOR)/$(BOARD)	# BOARDDIR = st/stm32h750-art-pi
ENVDIR=${vendor}/env			# ENVDIR = st/env
endif
ifdef	BOARD
# 包含特定于板的规则
sinclude $（srctree）/board/$（BOARDDIR）/config.mk 	# include ./board/st/stm32h750-art-pi/config.mk
endif
```

# checkarmreloc 检查ARM重定向 32或64位

```makefile
# ARM 重定位应全部为 R_ARM_RELATIVE（32 位）或 R_AARCH64_RELATIVE（64 位）
checkarmreloc: u-boot
	@RELOC="`$(CROSS_COMPILE)readelf -r -W $< | cut -d ' ' -f 4 | \
		grep R_A | sort -u`"; \
	if test "$$RELOC" != "R_ARM_RELATIVE" -a \
		 "$$RELOC" != "R_AARCH64_RELATIVE"; then \
		echo "$< contains unexpected relocations: $$RELOC"; \
		false; \
	fi
```

# u-boot.srec 对u-boot文件进行空白填充0XFF处理 把u-boot中的指定段拷到u-boot.srec中
```makefile
u-boot.hex u-boot.srec: u-boot FORCE
	$(call if_changed,objcopy)

# Normally we fill empty space with 0xff
# 使用ojbcopy工具将u-boot文件使用0xff填充空白
cmd_objcopy = $(OBJCOPY) --gap-fill=0xff $(OBJCOPYFLAGS) \
	$(OBJCOPYFLAGS_$(@F)) $< $@
```

## objcopy工具
- objcopy 是一个用于处理目标文件的工具，通常用于转换、修改和提取二进制文件中的内容。它是 GNU Binutils 工具链的一部分，广泛应用于嵌入式系统开发和其他需要处理二进制文件的领域。

1. 格式转换：objcopy 可以将目标文件从一种格式转换为另一种格式。例如，可以将 ELF 格式的文件转换为纯二进制格式。
2. 提取和合并：objcopy 可以从目标文件中提取特定的段或节，也可以将多个目标文件合并为一个文件。
3. 修改内容：objcopy 可以修改目标文件的内容，例如填充空白区域、修改符号表、调整段的地址等。
4. 生成调试信息：objcopy 可以从目标文件中分离或添加调试信息。
- 常用选项
```shell
	-O：指定输出文件的格式。例如，-O binary 将输出文件转换为纯二进制格式。
	-I：指定输入文件的格式。
	--strip-debug：从目标文件中移除调试信息。
	--strip-unneeded：移除不必要的符号。
	--only-keep-debug：仅保留调试信息。
	--add-section：添加一个新的段到目标文件中。
	--remove-section：从目标文件中移除一个段。
	--gap-fill：指定填充空白区域的字节值。
```

- `-j sectionname , --only-section=sectionname` : 只将由 sectionname 指定的 section 拷贝到输出文件，可以多次指定，并且注意如果使用不当会导致输出文件不可用。
- `-O bfdname `：--output-target= bfdname 使用指定的格式来写输出文件（即目标文件），bfdname是BFD库中描述的标准格式名。

# $(OBJCOPYFLAGS)

- $(OBJCOPYFLAGS)定义在顶层config.mk和arch/ $(ARCH)/config.mk(arch/arm/config.mk)中

```makefile
# config.mk
OBJCOPYFLAGS :=
# arch/arm/config.mk
# limit ourselves to the sections we want in the .bin.
ifdef CONFIG_ARM64
OBJCOPYFLAGS += -j .text -j .secure_text -j .secure_data -j .rodata -j .data \
		-j __u_boot_list -j .rela.dyn -j .got -j .got.plt \
		-j .binman_sym_table -j .text_rest
else
OBJCOPYFLAGS += -j .text -j .secure_text -j .secure_data -j .rodata -j .hash \
		-j .data -j .got -j .got.plt -j __u_boot_list -j .rel.dyn \
		-j .binman_sym_table -j .text_rest
endif

# if a dtb section exists we always have to include it
# there are only two cases where it is generated
# 1) OF_EMBEDED is turned on
# 2) unit tests include device tree blobs
OBJCOPYFLAGS += -j .dtb.init.rodata

ifdef CONFIG_EFI_LOADER
OBJCOPYFLAGS += -j .efi_runtime -j .efi_runtime_rel
endif
```

# u-boot 生成u-boot文件
- 首先生成xxx_build-in.o 和 start.o 和 lds文件;然后链接生成u-boot文件
```makefile
#顶层 makefile
ifeq ($(autoconf_is_old),)
include config.mk
include arch/$(ARCH)/Makefile
endif

# arch/arm/Makefile
head-y := arch/arm/cpu/$(CPU)/start.o

#顶层 makefile
u-boot-init := $(head-y)
u-boot-main := $(libs-y)

u-boot:	$(u-boot-init) $(u-boot-main) $(u-boot-keep-syms-lto) u-boot.lds FORCE
	+$(call if_changed,u-boot__)

# 链接 u-boot 的规则
# 可以被 arch/$（ARCH）/config.mk 覆盖

# This is y if LTO is enabled for this build. See NO_LTO=1 to disable LTO
ifeq ($(NO_LTO),)
LTO_ENABLE=$(if $(CONFIG_LTO),y)
endif

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
else	#stm32h750-art-pi没有配置,所以走这个
quiet_cmd_u-boot__ ?= LD      $@
      cmd_u-boot__ ?= $(LD) $(KBUILD_LDFLAGS) $(LDFLAGS_u-boot) -o $@		\
		-T u-boot.lds $(u-boot-init)					\
		--whole-archive							\
			$(u-boot-main)						\
		--no-whole-archive						\
		$(PLATFORM_LIBS) -Map u-boot.map;				\
		$(if $(ARCH_POSTLINK), $(MAKE) -f $(ARCH_POSTLINK) $@, true)
endif
```

- `$(u-boot-init)` 为`arch/arm/cpu/armv7m/start.o`
- `$(u-boot-main)` 为`lib配置和厂家配置`各层驱动目录下build-in.o的集合
- `$(u-boot-keep-syms-lto)` 为`空`
- `u-boot.lds` 为 生成`u-boot.lds`

# $(xxx-y) 为xxx_config = y 时的变量

# $(libs-y)被定义为各层驱动目录下build-in.o的集合
```makefile
#顶层 makefile
# 将这些路径中的built-in.o文件路径添加到libs-y变量中,配置使能的一同添加
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
# 如果有板特定的目录，则添加它
libs-y += $(if $(wildcard $(srctree)/board/$(BOARDDIR)/Makefile),board/$(BOARDDIR)/)
# 排序目标
libs-y := $(sort $(libs-y))
# 将 libs-y 中的目录路径转换为相应的 built-in.o 文件路径
# 将$(libs-y 中匹配以 / 结尾的字符串，这通常表示目录路径, 将匹配的目录路径转换为以 built-in.o 结尾的文件路径。
libs-y		:= $(patsubst %/, %/built-in.o, $(libs-y))

# arch/arm/Makefile
machdirs := $(patsubst %,arch/arm/mach-%/,$(machine-y))	#arch/arm/mach-stm32/
libs-y += $(machdirs)
libs-y += arch/arm/cpu/$(CPU)/
libs-y += arch/arm/cpu/
libs-y += arch/arm/lib/
```

# machine-y machine厂家配置
```makefile
# arch/arm/Makefile
```Makefile
# Machine directory name.  This list is sorted alphanumerically
# by CONFIG_* macro name.
machine-$(CONFIG_ARCH_STM32)		+= stm32
```

# u-boot.lds 生成链接器脚本
- 调用原始的lds脚本生成需要的lds脚本
- 在预处理过程中，GCC 预处理器会移除注释。这是因为预处理器的主要任务是处理宏定义、条件编译指令和文件包含指令，而注释对于编译器来说是无关紧要的，因此会被移除。
- 预处理器的行为
	1. 宏展开：预处理器会展开所有的宏定义。例如，#define 指令定义的宏会被替换为其对应的值。
	2. 条件编译：预处理器会处理所有的条件编译指令，例如 #ifdef、#ifndef、#if、#else 和 #endif。
	3. 文件包含：预处理器会处理所有的文件包含指令，例如 #include，并将包含的文件内容插入到预处理后的文件中。
	4. 移除注释：预处理器会移除所有的注释，包括单行注释（）和多行注释（/* ... */）
- 预处理器通常不会根据文件后缀来决定是否对文件进行预处理，而是根据命令行选项和文件内容来决定如何处理文件。
- 所以使用了预处理器处理原始的lds脚本生成新的lds脚本
```makefile
# $@ 代表目标文件名u-boot.lds在顶层目录下
# $< 输入的文件 arch/arm/cpu/u-boot.lds
u-boot.lds: $(LDSCRIPT) prepare FORCE
	$(call if_changed_dep,cpp_lds)
cmd_cpp_lds = $(CPP) -Wp,-MD,$(depfile) $(cpp_flags) $(LDPPFLAGS) \
		-D__ASSEMBLY__ -x assembler-with-cpp -std=c99 -P -o $@ $<
```

# LDSCRIPT 找到链接器脚本路径
- arch/arm/cpu/u-boot.lds
- 如果没有定义LDSCRIPT和CONFIG_SYS_LDSCRIPT，则默认使用u-boot自带的lds文件，包括board/$ (BOARDDIR)和$ (CPUDIR)目录下定制的针对board或cpu的lds文件；如果没有定制的lds文件，则采用arch/$(ARCH)/cpu目录下默认的lds文件。
```makefile
# 如果板代码明确指定了 LDSCRIPT 或 CONFIG_SYS_LDSCRIPT，则使用它（如果没有，则失败）。 否则，请在标准位置搜索链接器脚本。
ifndef LDSCRIPT
	#LDSCRIPT := $(srctree)/board/$(BOARDDIR)/u-boot.lds.debug 这个是注释
	ifdef CONFIG_SYS_LDSCRIPT	#这里没有指定
		# need to strip off double quotes
		LDSCRIPT := $(srctree)/$(CONFIG_SYS_LDSCRIPT:"%"=%)
	endif
endif

# 如果没有指定的链接脚本，我们会在多个地方查找它
ifndef LDSCRIPT
	ifeq ($(wildcard $(LDSCRIPT)),)	# 板配置文件中指定
		LDSCRIPT := $(srctree)/board/$(BOARDDIR)/u-boot.lds
	endif
	ifeq ($(wildcard $(LDSCRIPT)),)	# CPU中指定
		LDSCRIPT := $(srctree)/$(CPUDIR)/u-boot.lds
	endif
	ifeq ($(wildcard $(LDSCRIPT)),)	# 架构中指定
		LDSCRIPT := $(srctree)/arch/$(ARCH)/cpu/u-boot.lds
	endif
endif
```

# prepare系列目标依赖
```makefile
# 顶层 makefile

# 在递归地开始构建内核或模块之前，我们需要做的事情列在 “prepare” 中。
# 使用多层次方法。prepareN 在 prepareN-1 之前处理。
# archprepare 用于 arch Makefile，处理后 asm symlink，
# version.h 和 scripts_basic 被处理/创建。

# 按依赖关系顺序列出
PHONY += prepare archprepare prepare0 prepare1 prepare2 prepare3

# prepare3 用于检查我们是否在单独的 output 目录中构建，
# 这段代码的目的是检查源代码树 $(srctree) 是否干净。如果检测到 .config 文件或 config 目录存在，则表示源代码树不干净，并提示用户运行 make mrproper 命令进行清理
prepare3: include/config/uboot.release
ifneq ($(KBUILD_SRC),)
	@$(kecho) '  Using $(srctree) as source for U-Boot'
	$(Q)if [ -f $(srctree)/.config -o -d $(srctree)/include/config ]; then \
		echo >&2 "  $(srctree) is not clean, please run 'make mrproper'"; \
		echo >&2 "  in the '$(srctree)' directory.";\
		/bin/false; \
	fi;
endif

# prepare2 如果使用单独的输出目录，则创建一个 makefile
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

# 所有的准备工作..
prepare: prepare0
```

# $(version_h) $(timestamp_h) $(dt_h) $(env_h)
```makefile
version_h := include/generated/version_autogenerated.h
timestamp_h := include/generated/timestamp_autogenerated.h
dt_h := include/generated/dt.h
env_h := include/generated/environment.h

# Generate some files
# ---------------------------------------------------------------------------

# 使用 sed 从 PATCHLEVEL 中删除前导零，以避免使用八进制数
# 将信息写入 version_autogenerated.h
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

# SOURCE_DATE_EPOCH机制要求日期的行为类似于 GNU 日期。
# 另一方面，BSD 日期的行为不同，并且会因误用 '-d' 开关而产生错误。 尊重这一点，并搜索带有众所周知的 pre- 和 suffix 的 date 的 GNU 变体的工作日期。
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


# $(version_h) = include/generated/version_autogenerated.h
$(version_h): include/config/uboot.release FORCE
	$(call filechk,version.h)
# $(timestamp_h) = include/generated/timestamp_autogenerated.h
$(timestamp_h): $(srctree)/Makefile FORCE
	$(call filechk,timestamp.h)
# $(dt_h) = include/generated/dt.h
$(dt_h): $(srctree)/Makefile FORCE
$(call filechk,dt.h)
# $(defaultenv_h) = include/generated/environment.h
$(defaultenv_h): $(CONFIG_DEFAULT_ENV_FILE:"%"=%) FORCE
	$(call filechk,defaultenv.h)
```

# include/config/uboot.release 生成版本号
- 使用[scripts/setlocalversion](./setlocalversion.md)工具来生成include/config/uboot.release
```makefile
# Store (new) UBOOTRELEASE string in include/config/uboot.release
include/config/uboot.release: include/config/auto.conf FORCE
	$(call filechk,uboot.release)

# setlocalversion 脚本来自 Linux，需要KERNELVERSION 变量，用于确定哪些带注释的标签是相关的。传递 UBOOTVERSION。
define filechk_uboot.release
	KERNELVERSION=$(UBOOTVERSION) $(CONFIG_SHELL) $(srctree)/scripts/setlocalversion $(srctree)
endef
```

# filechk_xxx Filechk 用于检查生成的文件内容是否更新
```makefile
# scripts/Kbuild.include
# Filechk 用于检查生成的文件内容是否更新。
# 示例用法：定义 filechk_sample echo $KERNELRELEASE endef version.h：Makefile
#	$（调用 filechk，sample）
# 定义的规则应将新文件的内容写入 stdout。
# 现有文件将与新文件进行比较。
# - 如果不存在文件，则会创建
# - 如果内容不同，则使用新文件
# - 如果它们相等，则无更改，无时间戳更新
# - stdin 是从第一个先决条件 （$<） 传入的，因此有
#   指定一个有效文件作为第一个先决条件（通常是 kbuild 文件）
define filechk
	$(Q)set -e;				\
	mkdir -p $(dir $@);			\
	$(filechk_$(1)) < $< > $@.tmp;		\
	if [ -r $@ ] && cmp -s $@ $@.tmp; then	\
		rm -f $@.tmp;			\
	else					\
		$(kecho) '  UPD     $@';	\
		mv -f $@.tmp $@;		\
	fi
endef
```

# if_changed 执行命令 if_changed_dep 用于生成依赖文件 .d
```makefile
ifneq ($(KBUILD_NOCMDDEP),1)
# 检查两个参数是否相同，包括它们的顺序。Result 为空;string 如果相等。用户可以使用 make KBUILD_NOCMDDEP=1 覆盖此检查
arg-check = $(filter-out $(subst $(space),$(space_escape),$(strip $(cmd_$@))), \
                         $(subst $(space),$(space_escape),$(strip $(cmd_$1))))
else
arg-check = $(if $(strip $(cmd_$@)),,1)
endif
# 查找比 target 更新或不存在的任何先决条件。
# 在这两种情况下都跳过了 PHONY 目标。
any-prereq = $(filter-out $(PHONY),$?) $(filter-out $(PHONY) $(wildcard $^),$^)
# 如果命令已更改或先决条件已更新，则执行命令。
if_changed = $(if $(strip $(any-prereq) $(arg-check)),                       \
	@set -e;                                                             \
	$(echo-cmd) $(cmd_$(1));                                             \
	printf '%s\n' 'cmd_$@ := $(make-cmd)' > $(dot-target).cmd, @:)

# 执行命令并后处理生成的 .d 依赖项文件。
if_changed_dep = $(if $(strip $(any-prereq) $(arg-check) ),                  \
	@set -e;                                                             \
	$(echo-cmd) $(cmd_$(1));                                             \
	scripts/basic/fixdep $(depfile) $@ '$(make-cmd)' > $(dot-target).tmp;\
	rm -f $(depfile);                                                    \
	mv -f $(dot-target).tmp $(dot-target).cmd, @:)
```

# u-boot.bin 把u-boot-dtb.bin 重命名为u-boot.bin
```makefile
# 根据配置依赖不同的文件
ifeq ($(CONFIG_MULTI_DTB_FIT),y)
u-boot.bin: u-boot-fit-dtb.bin FORCE
	$(call if_changed,copy)
else ifeq ($(CONFIG_OF_SEPARATE).$(CONFIG_OF_OMIT_DTB),y.)	#CONFIG_OF_SEPARATE=y和CONFIG_OF_OMIT_DTB为空执行
u-boot.bin: u-boot-dtb.bin FORCE
	$(call if_changed,copy)
else
u-boot.bin: u-boot-nodtb.bin FORCE
	$(call if_changed,copy)
endif
```

# u-boot-dtb.bin 把u-boot-nodtb.bin和dts/dt.dtb打包成u-boot-dtb.bin
- 把u-boot-nodtb.bin和dts/dt.dtb打包成u-boot-dtb.bin
```makefile
cmd_cat = cat $(filter-out $(PHONY), $^) > $@

ifneq ($(CONFIG_MPC85XX_HAVE_RESET_VECTOR)$(CONFIG_OF_SEPARATE),yy)
u-boot-dtb.bin: u-boot-nodtb.bin dts/dt.dtb FORCE
	$(call if_changed,cat)
endif

else ifeq ($(CONFIG_OF_SEPARATE).$(CONFIG_OF_OMIT_DTB),y.)

ifneq ($(CONFIG_MPC85XX_HAVE_RESET_VECTOR)$(CONFIG_OF_SEPARATE),yy)
u-boot-dtb.bin: u-boot-nodtb.bin dts/dt.dtb FORCE	#执行这个
	$(call if_changed,cat)
endif

ifeq ($(CONFIG_MPC85XX_HAVE_RESET_VECTOR)$(CONFIG_OF_SEPARATE),yy)
u-boot-dtb.bin: u-boot-nodtb.bin u-boot.dtb u-boot-br.bin FORCE
	$(call if_changed,binman)

OBJCOPYFLAGS_u-boot-br.bin := -O binary -j .bootpg -j .resetvec
u-boot-br.bin: u-boot FORCE
	$(call if_changed,objcopy)
endif
```

# u-boot-nodtb.bin 对u-boot文件进行空白填充0XFF处理 把u-boot中的指定段拷到u-boot-nodtb.bin
```makefile
# 静态应用 RELA 样式的重定位（目前仅限 arm64）
# 这对于 arm64 非常有用，其中需要对原始二进制文件执行静态重定位，但某些模拟器只接受 ELF 文件（但不执行重定位）。
ifneq ($(CONFIG_STATIC_RELA),)
# $(2) is u-boot ELF, $(3) is u-boot bin, $(4) is text base
quiet_cmd_static_rela = RELOC   $@
quiet_cmd_static_rela = RELOC   $@
cmd_static_rela = \
	tools/relocate-rela $(3) $(2)
else
quiet_cmd_static_rela =
cmd_static_rela =
endif

ifdef cmd_static_rela
cmd_objcopy_uboot = $(cmd_objcopy) && $(call shell_cmd,static_rela,$<,$@,$(CONFIG_TEXT_BASE)) || { rm -f $@; false; }
else
cmd_objcopy_uboot = $(cmd_objcopy)	#cmd_static_rela为空,执行这个
endif

ifneq ($(CONFIG_BOARD_SIZE_LIMIT),)
BOARD_SIZE_CHECK= @ $(call size_check,$@,$(CONFIG_BOARD_SIZE_LIMIT))
else
BOARD_SIZE_CHECK =
endif

u-boot-nodtb.bin: u-boot FORCE
	$(call if_changed,objcopy_uboot)
	$(BOARD_SIZE_CHECK)	#为空
```

# dts/dt.dtb 生成对应的dtb文件
```makefile
dtbs_prepare: prepare3	#检查是否在output目录中构建
dts/dt.dtb: dtbs_prepare u-boot
	$(Q)$(MAKE) $(build)=dts dtbs
```

- 指定目标dtbs，在Makefile.build中会引用dts目录下的Makefile。展开如下
```makefile
# dts/Makefile

# CONFIG_DEFAULT_DEVICE_TREE="stm32h750i-art-pi"
DEVICE_TREE ?= $(CONFIG_DEFAULT_DEVICE_TREE:"%"=%)

# arch/arm/dts / stm32h750i-art-pi.dtb
DTB := $(dt_dir)/$(DEVICE_TREE).dtb

$(obj)/dt.dtb: $(DTB) FORCE
	$(call if_changed,shipped)

$(DTB): arch-dtbs $(local_dtbos)
	$(Q)test -e $@ || (						\
	echo >&2;							\
	echo >&2 "Device Tree Source ($@) is not correctly specified.";	\
	echo >&2 "Please define 'CONFIG_DEFAULT_DEVICE_TREE'";		\
	echo >&2 "or build with 'DEVICE_TREE=<device_tree>' argument";	\
	echo >&2;							\
	/bin/false)

# Target for U-Boot proper
dtbs: $(obj)/dt.dtb
	@:
```

# arch-dtbs 生成scripts/dtc/dtc文件

```makefile
# dts/Makefile
arch-dtbs:
	$(Q)$(MAKE) $(build)=$(dt_dir) dtbs
```

- 规则就是执行：`make -f $(srctree)/scripts/Makefile.build obj=arch/arm/dts dtbs`命令。目标dtbs定义在scripts/Makefile.dts中
- 调用scripts/dtc/dtc 工具生成对应的dtb文件，同时生成*.d文件