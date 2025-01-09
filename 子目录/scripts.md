[TOC]

# scripts 用于构建脚本的工具

- 参考[UBOOT全部目标的编译过程详解](./UBOOT编译---%20UBOOT全部目标的编译过程详解(九)%20-%20BSP-路人甲%20-%20博客园.mhtml)

# scripts_basic 用于构建基本脚本的工具
[参考](https://blog.csdn.net/weixin_42346852/article/details/131781340)

uboot 和 Linux kernel 的主 Makefile 里面，都有下面这段话：
```makefile
PHONY += scripts_basic
scripts_basic:
	$(Q)$(MAKE) $(build)=scripts/basic
	$(Q)rm -f .tmp_quiet_recordmcount
```
展开后就是：
```sh
make -f ./scripts/Makefile.build obj=scripts/basic
```

## $(build)的展开

主 Makefile 里面，有一个非常重要的 include：

```bash
include scripts/Kbuild.include
```

这是一个头文件，相当于把 `Kbuild.include` 的内容直接写到主 Makefile 里。
`Kbuild.include` 代码片段：

```bash
###
# Shorthand for $(Q)$(MAKE) -f scripts/Makefile.build obj=
# Usage:
# $(Q)$(MAKE) $(build)=dir
build := -f $(srctree)/scripts/Makefile.build obj
```

这句话的实质，是变量的字符串展开；就是说 build 被当做了 Kbuild 的一个保留的字符串变量。
所以 `$(Q)$(MAKE) $(build)=scripts/basic` 的展开，就是把`$(build)` 用 := 后的字符串替换

## Kbuild 为不同的编译目标生成编译规则。
Kbuild 中，几乎或者全部的 .o 都是由 Makefile.build 来完成编译的。
Makefile.build 会为不同类型的编译对象，指定不同的规则。类似于大家喜闻乐见的：
```makefile
gcc -c -o hello.o hello.c
```

但是 Kbuild 追求的是批量化编译，所以指定规则的过程很复杂，需要认真分析下。
这篇文章，只分析 hostprogs 相关的规则生成和编译。
hostprogs 是在编译过程中主机所用到的一些工具；hostprogs 编译的输出件是运行在主机上的，最后不会被链接到目标文件中。

过滤掉 Makefile.build 中和 hostprogs 无关的代码，得：
```makefile
src := $(obj)
# $(obj) 是传入的参数，即 scripts/basic
PHONY := __build
__build:
...
include scripts/Kbuild.include

kbuild-dir := $(if $(filter /%,$(src)),$(src),$(srctree)/$(src))
kbuild-file := $(if $(wildcard $(kbuild-dir)/Kbuild),$(kbuild-dir)/Kbuild,$(kbuild-dir)/Makefile)
include $(kbuild-file)

include scripts/Makefile.lib

hostprogs := $(sort $(hostprogs))
ifneq ($(hostprogs),)
include scripts/Makefile.host
endif
...
__build: $(if $(KBUILD_BUILTIN), $(targets-for-builtin)) \
	 $(if $(KBUILD_MODULES), $(targets-for-modules)) \
	 $(subdir-ym) $(always-y)
	@:

PHONY += FORCE
FORCE:
...
.PHONY: $(PHONY)

```

### 找到子目录中的 Makefile

关于 $(kbuild-file) 的分析
```makefile
# 文件名 Kbuild 优先于 Makefile
# 如果 src 是绝对路径，则使用 src 作为 kbuild-dir；否则，使用 $(srctree)/$(src) 作为 kbuild-dir
# 如果 $(kbuild-dir)/Kbuild 存在，则使用 $(kbuild-dir)/Kbuild 作为 kbuild-file；否则，使用 $(kbuild-dir)/Makefile 作为 kbuild-file
kbuild-dir := $(if $(filter /%,$(src)),$(src),$(srctree)/$(src))
kbuild-file := $(if $(wildcard $(kbuild-dir)/Kbuild),$(kbuild-dir)/Kbuild,$(kbuild-dir)/Makefile)
# 导入 kbuild-file的内容
# 例如 obj=scripts/basic srctree=. 则导入scripts/basic/Makefile文件
include $(kbuild-file)
```

这些语句，相当于 include 了scripts/basic/Makefile。
这个文件就一句话：
```makefile
# scripts/basic/Makefile
hostprogs-always-y	+= fixdep
```

### 使用 Makefile.lib 对编译目标进行分类和整理
scripts/Makefile.lib 会对各种编译目标进行转换、抽象和提取。
编译目标的种类有很多，这里只追踪 hostprogs 相关的。
```makefile
# scripts/Makefile.lib
hostprogs += $(hostprogs-always-y) $(hostprogs-always-m)
always-y += $(hostprogs-always-y) $(hostprogs-always-m)
always-y	:= $(addprefix $(obj)/,$(always-y))
```
这样，可以获得
```makefile
hostprogs = fixdep
always-y = scripts/basic/fixdep
```
是的，虽然 Makefile.build 这个文件很长，但是真正和 scripts/basic 相关的，就上面 3 行代码。

### Makefile.host 所做的工作
因为 hostprogs 不为空，所以引入了另一个包含
```makefile
# scripts/Makefile.build
ifneq ($(hostprogs),)
include scripts/Makefile.host
endif
```
`scripts/Makefile.host` 这个文件会将 `$(hostprogs)` 转换为` $(host-csingle)` `、$(host-cmulti)` 等目标。这里需要介绍下 `host-csingle`、h`ost-cmulti`、`host-cobjs`、`host-cxxmulti` 和 `host-cxxobjs` 这几个变量。这是 `Makefile.host` 所能处理的几类编译目标。`Makefile.host` 会为这几类目标生成编译规则。说到底，`Kbuild `的这一套机制，目的就是为不同的编译目标生成编译规则。

#### host-cobjs 实例
这里只是举例，在编译` scripts/basic` 时是不会用到 `host-cobjs `类型的目标的。介绍 host-cobjs，只是为后面分析 host-csingle 做铺垫。以 qconf 为例，scripts/kconfig/Makefile 中的代码段：
```makefile
# scripts/kconfig/Makefile
# object files used by all kconfig flavours
common-objs	:= confdata.o expr.o lexer.lex.o parser.tab.o preprocess.o \
		   symbol.o util.o
hostprogs	+= qconf
qconf-cxxobjs	:= qconf.o qconf-moc.o
qconf-objs	:= images.o $(common-objs)
```
然后可得：`hostprogs = qconf`，也许还有其他的，此处忽略;`qconf-objs = images.o confdata.o expr.o lexer.lex.o parser.tab.o preprocess.o symbol.o util.o`

Makefile.host 对 host-cobjs 的处理
```makefile
# scripts/Makefile.host
# Object (.o) files compiled from .c files
host-cobjs	:= $(sort $(foreach m,$(hostprogs),$($(m)-objs)))	# 语句1
host-cobjs	:= $(addprefix $(obj)/,$(host-cobjs))	# 语句2
````
foreach 的作用，是将 `$(hostprogs)` 中的变量逐个取出，然后带入到 `$($(m)-objs)) 中即得到`$(qconf-objs)`;注意，`$(qconf-objs) `还会被展开一次，即得到`images.o confdata.o expr.o lexer.lex.o parser.tab.o preprocess.o symbol.o util.o`
所以，语句1 的结果是：
```makefile
host-cobjs := images.o confdata.o expr.o lexer.lex.o parser.tab.o preprocess.o symbol.o util.o
```
语句2 是为上面的这些 .o 添加目录前缀。所以 `$(host-cobjs)` 实际上是若干 .c 对应的 .o 的集合。当为 `$(host-cobjs) `制定好规则以后，上面的 `images.o confdata.o ...` 所对应的 `images.c confdata.c ... `均会批量化的按照制定的规则进行编译。
```makefile
# 这里用到了“静态模式”的概念，暂不展开
$(host-cobjs): $(obj)/%.o: $(src)/%.c FORCE
	$(call if_changed_dep,host-cobjs)
```
`if_changed_dep`,的这个逗号后面，一定不要加空格什么的;或者说 call 的用法就这样，逗号后面不要加不相关的字符;另外，对应的 cmd_cpp_lds 等命令，一定用延时赋值“=”，而不是直接赋值“:=”，因为：如果命令中用到 `$@` 或者 `$<`时，延时赋值可以展开，直接赋值不会展开。一定要注意！！！！！

#### host-csingle 实例
```makefile
# scripts/Makefile.host
# C code
# Executables compiled from a single .c file
host-csingle	:= $(foreach m,$(hostprogs), \
			$(if $($(m)-objs)$($(m)-cxxobjs),,$(m)))	# 语句1
host-csingle	:= $(addprefix $(obj)/,$(host-csingle))	# 语句2
```
此处 `hostprogs = fixdep`，第一次带入得 `$(fixdep-objs)` 和 `$(fixdep-cxxobjs)`，因为它们两个展开后，均为空，所以语句1 的返回结果就是 `$host-csingle) = fixdep`;语句2 为 fixdep 添加了前缀，`$(host-csingle) = scripts/basic/fixdep`;所以，`$(host-csingle) `指的是那些由单个 .c 编译而成的可执行文件，比如说 `fixdep`;`Makefile.host` 为` host-csingle `制定了编译规则。
```makefile
# Create executable from a single .c file
# host-csingle -> Executable

# OSTCC 是一个变量，通常表示用于编译主机程序的编译器（例如 gcc）。
# $@ 是一个自动化变量，表示当前目标的名称。
# $(hostc_flags)：表示编译主机程序时使用的编译标志。
# $(KBUILD_HOSTLDFLAGS)：表示链接主机程序时使用的链接标志。
# -o $@：指定输出文件的名称，$@ 表示当前目标的名称。
# $<：表示第一个依赖文件的名称，通常是源文件。
# $(KBUILD_HOSTLDLIBS)：表示链接主机程序时使用的库文件。
# $(HOSTLDLIBS_$(@F))：表示特定目标文件的链接库，$(@F) 表示当前目标文件的文件名部分。
quiet_cmd_host-csingle 	= HOSTCC  $@
      cmd_host-csingle	= $(HOSTCC) $(hostc_flags) $(KBUILD_HOSTLDFLAGS) -o $@ $< \
	  	$(KBUILD_HOSTLDLIBS) $(HOSTLDLIBS_$(@F))
#用于编译目标文件夹下的所有.c文件
# 会执行例如cc -Wp,-MD,scripts/basic/.fixdep.d -Wall -Wstrict-prototypes -O2 -fomit-frame-pointer   -std=gnu11       -o scripts/basic/fixdep scripts/basic/fixdep.c的命令
$(host-csingle): $(obj)/%: $(src)/%.c FORCE
#调用if_changed_dep中会调用cmd_host-csingle
	$(call if_changed_dep,host-csingle)
```

### 再回到 scripts/Makefile.build
Makefile.host 为目标制定了规则。但是，制定规则不代表调用规则。
那 scripts_basic 的规则是怎么被调用的呢？
Makefile.build 的默认编译目标是 __build：
```makefile
# scripts/Makefile.build
PHONY := __build
__build:
...
__build: $(if $(KBUILD_BUILTIN), $(targets-for-builtin)) \
	 $(if $(KBUILD_MODULES), $(targets-for-modules)) \
	 $(subdir-ym) $(always-y)
	@:
```
其实，这里有个难以理解和追踪的地方了：
__build 中的有效依赖是 `$(always-y) `，但是搜索编整个 Makefile 工程都找不到对 `$(always-y)` 目标的编译——没有为` $(always-y)` 设计编译规则。
那么，目标是怎么被编译的呢？
前面 scripts/Makefile.host 中得到了` $(host-csingle) `，虽然 __build 中并没有包含 `$(host-csingle)` ，但是` $(always-y)` 和 `$(host-csingle) `包含了相同的目标 scripts/basic/fixdep。
所以 __build 对 `$(always-y)` 的依赖就是对 scripts/basic/fixdep 的依赖。
而 scripts/basic/fixdep 的编译规则已经被 `$(host-csingle) `制定了。

# scripts/dtc 用于生成设备树二进制文件


# 具体分析

- 输入命令行查看构建流程

```sh
$ make scripts V=1 CROSS_COMPILE=arm-none-eabi- ARCH=arm stm32h750-art-pi_defconfig
# scripts + stm32h750-art-pi_defconfig 误识别成混合目标了
set -e; \
for i in scripts stm32h750-art-pi_defconfig; do \
        make -f ./Makefile $i; \
done
# 等同于 make scripts;但是会先执行scripts_basic 和 include/config/auto.conf (include/config/%.conf:)
# 执行include/config/%.conf:
make -f ./Makefile syncconfig

# 执行scripts_basic,由于命令是$(Q)$(MAKE) $(build)=scripts/basic
# 所以执行的是make -f ./scripts/Makefile.build obj=scripts/basic
make -f ./scripts/Makefile.build obj=scripts/basic

# 在scripts/Makefile.build中由于输入make 没有带参数,所以执行了__build;
# __build: $(always) 依赖于 $(obj)/fixdep; $(always)从include $(kbuild-file)导入,即scripts/basic/Makefile
# scripts/basic/Makefile中定义了hostprogs-y	:= fixdep;  always		:= $(hostprogs-y)
# 而$(host-csingle) 指定了编译规则
# 执行构建fixdep程序
  cc -Wp,-MD,scripts/basic/.fixdep.d -Wall -Wstrict-prototypes -O2 -fomit-frame-pointer   -std=gnu11       -o scripts/basic/fixdep scripts/basic/fixdep.c
rm -f .tmp_quiet_recordmcount

# 执行include/config/%.conf:
make -f ./scripts/Makefile.build obj=scripts/kconfig syncconfig
# 执行include/config/auto.conf
scripts/kconfig/conf  --syncconfig Kconfig
make -f ./scripts/Makefile.autoconf || \
        { rm -f include/config/auto.conf; false; }

# 执行./scripts/Makefile.autoconf 由于依赖关系优先执行create_symlink
# 这里在arch/arm/include/asm/arch中创建了一个软链接arch-stm32h7
if [ -d arch/arm/mach-stm32h7/include/mach ]; then      \
        dest=../../mach-stm32h7/include/mach;                   \
else                                                            \
        dest=arch-stm32h7;                      \
fi;                                                             \
ln -fsn $dest arch/arm/include/asm/arch

# 执行./scripts/Makefile.autoconf 由于依赖关系优先执行filechk_config_h,创建include/config.h
# 首先执行了filechk,在执行了filechk_config_h
set -e; mkdir -p include/;      
# 执行了filechk_config_h 生成了include/config.h.tmp
(echo "/* Automatically generated - do not edit */"; echo \#define CFG_BOARDDIR board/st/stm32h750-art-pi; echo \#include \<configs/"stm32h750-art-pi".h\> ; echo \#include \<asm/config.h\>; echo \#include \<linux/kconfig.h\>; echo \#include \<config_fallbacks.h\>;) < scripts/Makefile.autoconf > include/config.h.tmp;
# 如果原文件存在且与临时文件内容相同，则删除临时文件;否则，将临时文件重命名为目标文件
 if [ -r include/config.h ] && cmp -s include/config.h include/config.h.tmp; then rm -f include/config.h.tmp; else : '  UPD     include/config.h'; mv -f include/config.h.tmp include/config.h; fi
# 执行./scripts/Makefile.autoconf 由于依赖关系优先执行u-boot.cfg: 即cmd_u_boot_cfg
# 编译u-boot.cfg 并将define CONFIG_中包含CONFIG_IS_ENABLED,CONFIG_IF_ENABLED_INT,CONFIG_VAL的宏定义剔除
  arm-none-eabi-gcc $(c_flags) -DDO_DEPS_ONLY -dM include/config.h > u-boot.cfg.tmp && { grep 'define CONFIG_' u-boot.cfg.tmp | sed '/define CONFIG_IS_ENABLED(/d;/define CONFIG_IF_ENABLED_INT(/d;/define CONFIG_VAL(/d;' > u-boot.cfg; rm u-boot.cfg.tmp; } || { rm u-boot.cfg.tmp; false; }
# 执行./scripts/Makefile.autoconf 由于依赖关系优先执行include/autoconf.mk 即cmd_autoconf
# 从u-boot.cfg中提取宏定义,匹配define2mk.sed中的规则,并将提取的宏定义写入include/autoconf.mk(用于 U-Boot 常规配置)
  sed -n -f ./tools/scripts/define2mk.sed u-boot.cfg | while read line; do if [ -n "" ] || ! grep -q "${line%=*}=" include/config/auto.conf; then echo "$line"; fi; done > include/autoconf.mk
# 执行include/config/%.conf: 由于依赖关系优先执行include/autoconf.mk.dep 即cmd_autoconf_dep
  arm-none-eabi-gcc -x c -DDO_DEPS_ONLY -M -MP $(c_flags) -MQ include/config/auto.conf include/config.h > include/autoconf.mk.dep || { rm include/autoconf.mk.dep; false; }

# 执行./scripts/Makefile.autoconf
touch include/config/auto.conf


make -f ./scripts/Makefile.build obj=scripts/basic
rm -f .tmp_quiet_recordmcount
# 执行scripts_dtc
if test "./scripts/dtc/dtc" = "./scripts/dtc/dtc"; then \
        make -f ./scripts/Makefile.build obj=scripts/dtc; \
else \
        if ! ./scripts/dtc/dtc -v >/dev/null; then \
                echo '*** Failed to check dtc version: ./scripts/dtc/dtc'; \
                false; \
        else \
                if test "010406" -lt 010406; then \
                        echo '*** Your dtc is too old, please upgrade to dtc 010406 or newer'; \
                        false; \
                else \
                        if [ -n "" ]; then \
                                if ! echo "import libfdt" | python3 2>/dev/null; then \
                                        echo '*** pylibfdt does not seem to be available with python3'; \
                                        false; \
                                fi; \
                        fi; \
                fi; \
        fi; \
fi

#执行 scripts
make -f ./scripts/Makefile.build obj=scripts
# 执行scripts_basic
make -f ./scripts/Makefile.build obj=scripts/basic
rm -f .tmp_quiet_recordmcount
```

## scripts/Kbuild 用于构建脚本的 Kbuild 文件

### echo-cmd 用于控制命令的回显

- 调用 escsq 函数，对 `$(quiet)cmd_$(1) `的内容进行转义处理
- $(echo-why) 是一个变量，通常用于附加额外的回显信息

```makefile
echo-cmd = $(if $($(quiet)cmd_$(1)),\
    echo '  $(call escsq,$($(quiet)cmd_$(1)))$(echo-why)';)
```

### filechk 用于检查文件是否改变
- 在dts/upstream/scripts/Kbuild.include中定义
- 规则的输出应写入标准输出，新文件的内容将与现有文件进行比较。如果文件不存在，则创建新文件；如果内容不同，则使用新文件；如果内容相同，则不进行更改，也不更新时间戳。

```makefile
# 设置命令执行时遇到错误即退出
# $(kecho) ' CHK $@';：打印检查文件的消息，$@ 表示目标文件
# mkdir -p $(dir $@);：创建目标文件所在的目录
# $(filechk_$(1)) < $< > $@.tmp;：执行文件检查命令，并将结果输出到临时文件
# 如果目标文件存在且与临时文件内容相同，则删除临时文件
# 否则，将临时文件重命名为目标文件
define filechk
	$(Q)set -e;				\
	$(kecho) '  CHK     $@';		\
	mkdir -p $(dir $@);			\
	$(filechk_$(1)) < $< > $@.tmp;		\
	if [ -r $@ ] && cmp -s $@ $@.tmp; then	\
		rm -f $@.tmp;			\
	else					\
		$(kecho) '  UPD     $@';	\
		mv -f $@.tmp $@;		\
	fi
endef

# filechk_$(1) 是一个宏，用于执行文件检查命令;
# 例如，filechk_config_h 宏用于检查配置文件。

# 如果 $(VENDOR) 变量存在，则使用 $(VENDOR)/，否则为空
# 如果 $(CONFIG_SYS_CONFIG_NAME) 变量存在，则包含配置文件，否则为空
define filechk_config_h
	(echo "/* Automatically generated - do not edit */";		\
	echo \#define CFG_BOARDDIR board/$(if $(VENDOR),$(VENDOR)/)$(BOARD);\
	$(if $(CONFIG_SYS_CONFIG_NAME),echo \#include \<configs/$(CONFIG_SYS_CONFIG_NAME).h\> ;) \
	echo \#include \<asm/config.h\>;				\
	echo \#include \<linux/kconfig.h\>;				\
	echo \#include \<config_fallbacks.h\>;)
endef
```

## fixdep 用于处理依赖关系的工具

- `fixdep` 是一个用于处理依赖关系的工具，通常在构建系统中使用。它解析依赖文件（`depfile`），生成目标文件（`target`）的依赖关系，并输出相应的命令行（`cmdline`）

### 调用流程
1. `if_changed_dep`：如果目标文件的依赖关系发生变化，则执行指定的命令行。
```makefile
# Execute the command and also postprocess generated .d dependencies file.

# $(strip $(any-prereq) $(arg-check) ) 去除 $(any-prereq) 和 $(arg-check) 中的空白字符，并检查它们是否非空
# 如果 $(any-prereq) 或 $(arg-check) 非空，则执行后续的命令。
# (echo-cmd) 是一个变量，通常用于控制命令的回显。$(cmd_$(1)) 是一个变量，表示具体的命令。$(1) 是一个占位符，表示传递给 if_changed_dep 宏的参数
# depfile  =  scripts/basic/.fixdep.d
#target  =  scripts/basic/fixdep
# cmdline  =  cc -Wp,-MD,scripts/basic/.fixdep.d -Wall -Wstrict-prototypes -O2 -fomit-frame-pointer  -std=gnu11     -o scripts/basic/fixdep scripts/basic/fixdep.c  
if_changed_dep = $(if $(strip $(any-prereq) $(arg-check) ),                  \
	@set -e;                                                             \
  	echo "cmd_$(1): $(cmd_$(1))";                                        \
	echo 'call fixdep: scripts/basic/fixdep $(depfile) $@ "$(make-cmd)"';\
	scripts/basic/fixdep $(depfile) $@ '$(make-cmd)' > $(dot-target).tmp;\
	rm -f $(depfile);                                                    \
	mv -f $(dot-target).tmp $(dot-target).cmd, @:)
```
- 调用打印如下

```shell
$ make scripts V=1 CROSS_COMPILE=arm-none-eabi- ARCH=arm stm32h750-art-pi_defconfig
#$(host-csingle) 指定了编译规则 在scripts/Makefile.host中定义了编译规则
#而$(always-y) 从include $(kbuild-file)导入,即scripts/basic/Makefile
cmd_host-csingle: cc -Wp,-MD,scripts/basic/.fixdep.d -Wall -Wstrict-prototypes -O2 -fomit-frame-pointer   -std=gnu11       -o scripts/basic/fixdep scripts/basic/fixdep.c   
  cc -Wp,-MD,scripts/basic/.fixdep.d -Wall -Wstrict-prototypes -O2 -fomit-frame-pointer   -std=gnu11       -o scripts/basic/fixdep scripts/basic/fixdep.c   
call fixdep: scripts/basic/fixdep scripts/basic/.fixdep.d scripts/basic/fixdep "cc -Wp,-MD,scripts/basic/.fixdep.d -Wall -Wstrict-prototypes -O2 -fomit-frame-pointer   -std=gnu11       -o scripts/basic/fixdep scripts/basic/fixdep.c   "
```

### 构建

```makefile

hostprogs-y	:= fixdep
always		:= $(hostprogs-y)

# 需要 fixdep 来编译其他主机程序
# 表示除了 fixdep 之外的所有目标都依赖于 fixdep
# 过滤掉 always 变量中的 fixdep，只保留其他目标。
# 为每个目标添加前缀 $(obj)/，表示目标文件的路径
# : $(obj)/fixdep 表示 fixdep 目标文件的路径。这意味着，除了 fixdep 之外的所有目标都依赖于 fixdep，即在构建这些目标之前，必须先构建 fixdep
$(addprefix $(obj)/,$(filter-out fixdep,$(always))): $(obj)/fixdep
```

### 使用方法

```plaintext
Usage: fixdep <depfile> <target> <cmdline>
```

- `<depfile>`：依赖文件，包含目标文件的依赖关系。
- `<target>`：目标文件，通常是需要编译的源文件。
- `<cmdline>`：命令行，用于编译目标文件的命令。

### 源代码

```c
/*
 * 在本程序的预期用途中，stdout 被重定向到 .*.cmd
 *文件。必须检查 printf（） 和 putchar（） 的返回值才能捕获
 * 任何错误，例如“No space left on device”。
 */
static void xprintf(const char *format, ...)
{
	va_list ap;
	int ret;

	va_start(ap, format);
	ret = vprintf(format, ap);
	if (ret < 0) {
		perror("fixdep");
		exit(1);
	}
	va_end(ap);
}

static void *read_file(const char *filename)
{
	struct stat st;
	int fd;
	char *buf;

	fd = open(filename, O_RDONLY);
	if (fd < 0) {
		fprintf(stderr, "fixdep: error opening file: ");  //输出错误信息到stderr流
		perror(filename); //在stderr流开头输出错误信息 filename:
		exit(2);  //退出程序,并返回2状态码
	}
	if (fstat(fd, &st) < 0) { // 读取文件的状态信息
		fprintf(stderr, "fixdep: error fstat'ing file: ");
		perror(filename);
		exit(2);
	}
	buf = malloc(st.st_size + 1); // 为buf分配内存,额外的 +1 字节通常用于存储字符串的终止符 \0，以确保缓冲区可以安全地用作字符串
	if (!buf) {
		perror("fixdep: malloc");
		exit(2);
	}
	if (read(fd, buf, st.st_size) != st.st_size) {
		perror("fixdep: read");
		exit(2);
	}
	buf[st.st_size] = '\0';
	close(fd);

	return buf;
}

/*
 * Important: The below generated source_foo.o and deps_foo.o variable
 * assignments are parsed not only by make, but also by the rather simple
 * parser in scripts/mod/sumversion.c.
 */
static void parse_dep_file(char *m, const char *target)
{
	char *p;
	int is_last, is_target;
	int saw_any_target = 0;
	int is_first_dep = 0;
	void *buf;

	while (1) {
		/* Skip any "white space" */
		while (*m == ' ' || *m == '\\' || *m == '\n')
			m++;

		if (!*m)
			break;

		/* Find next "white space" */
		p = m;
		while (*p && *p != ' ' && *p != '\\' && *p != '\n')
			p++;
		is_last = (*p == '\0');
		/* Is the token we found a target name? */
		is_target = (*(p-1) == ':');
		/* Don't write any target names into the dependency file */
		if (is_target) {
			/* The /next/ file is the first dependency */
			is_first_dep = 1;
		} else if (!is_ignored_file(m, p - m)) {
			*p = '\0';

			/*
			 * Do not list the source file as dependency, so that
			 * kbuild is not confused if a .c file is rewritten
			 * into .S or vice versa. Storing it in source_* is
			 * needed for modpost to compute srcversions.
			 */
      //第一次生成开头3 ~ 5行
			if (is_first_dep) {
				/*
				 * If processing the concatenation of multiple
				 * dependency files, only process the first
				 * target name, which will be the original
				 * source name, and ignore any other target
				 * names, which will be intermediate temporary
				 * files.
				 */
				if (!saw_any_target) {
					saw_any_target = 1;
          //第3行
					xprintf("source_%s := %s\n\n",
						target, m);
          //第5行开头
					xprintf("deps_%s := \\\n", target);
				}
				is_first_dep = 0;
			} else {
        //后续都是依赖文件导入
				xprintf("  %s \\\n", m);
			}

			buf = read_file(m);
      //例如输出:$(wildcard include/config/his/driver.h
      //会建立hash表,用于快速查找并不会重复导入
			parse_config_file(buf); //解析配置文件,并导入到cmd中
			free(buf);
		}

		if (is_last)
			break;

		/*
		 * Start searching for next token immediately after the first
		 * "whitespace" character that follows this token.
		 */
		m = p + 1;
	}

	if (!saw_any_target) {
		fprintf(stderr, "fixdep: parse error; no targets found\n");
		exit(1);
	}
  //生成末尾
	xprintf("\n%s: $(deps_%s)\n\n", target, target);
	xprintf("$(deps_%s):\n", target);
}

int main(int argc, char *argv[])
{
	const char *depfile, *target, *cmdline;
	void *buf;

	depfile = argv[1];
	target = argv[2];
	cmdline = argv[3];
  // 检查是否可以打印到.cmd文件,否则报错退出
	xprintf("cmd_%s := %s\n\n", target, cmdline);

	buf = read_file(depfile); //分配内存读取depfile文件,并返回指针
	parse_dep_file(buf, target);  //解析depfile文件并输出到cmd中
	free(buf);

	return 0;
}

```

## scripts/Makefile.autoconf 用于生成配置文件

1. 产生软链接 用于包含头文件
```shell
lrwxrwxrwx  1 embedsky embedsky     12 Jan  5 12:42 arch -> arch-stm32h7/
```
2. 生成include/config.h文件 用于配置文件
```c
/* Automatically generated - do not edit */
#define CFG_BOARDDIR board/st/stm32h750-art-pi
#include <configs/stm32h750-art-pi.h>
#include <asm/config.h>
#include <linux/kconfig.h>
#include <config_fallbacks.h>
```
3. 生成u-boot.cfg文件 用于提取宏定义
```c
#define CONFIG_ETH 1
#define CONFIG_CMD_FAT 1
#define CONFIG_TOOLS_SHA1 1
#define CONFIG_HAVE_TEXT_BASE 1
#define CONFIG_BOOTM_NETBSD 1
```
4. 生成include/autoconf.mk文件 用于U-Boot常规配置
```c
//空的
```
5. 生成include/autoconf.mk.dep文件 用于生成自动配置文件的依赖关系
```c
include/config/auto.conf: include/config.h include/linux/kconfig.h \
 include/generated/autoconf.h include/configs/stm32h750-art-pi.h \
 include/config.h arch/arm/include/asm/config.h include/linux/kconfig.h \
 include/config_fallbacks.h include/linux/sizes.h include/linux/const.h \
 include/config_distro_bootcmd.h

include/linux/kconfig.h:

include/generated/autoconf.h:

include/configs/stm32h750-art-pi.h:

include/config.h:

arch/arm/include/asm/config.h:

```

```makefile
# 编译执行__all;依赖于include/autoconf.mk include/autoconf.mk.dep
__all: include/autoconf.mk include/autoconf.mk.dep
# 判定是否需要重新生成autoconf.mk
ifeq ($(shell grep -q '^CONFIG_SPL=y' include/config/auto.conf 2>/dev/null && echo y),y)
__all: spl/include/autoconf.mk
endif

ifeq ($(shell grep -q '^CONFIG_TPL=y' include/config/auto.conf 2>/dev/null && echo y),y)
__all: tpl/include/autoconf.mk
endif

ifeq ($(shell grep -q '^CONFIG_VPL=y' include/config/auto.conf 2>/dev/null && echo y),y)
__all: vpl/include/autoconf.mk
endif

# -MQ 指定生成的依赖文件的目标
# 生成include/autoconf.mk.dep,用于生成自动配置文件的依赖关系
quiet_cmd_autoconf_dep = GEN     $@
      cmd_autoconf_dep = $(CC) -x c -DDO_DEPS_ONLY -M -MP $(c_flags) \
	-MQ include/config/auto.conf include/config.h > $@ || {	\
		rm $@; false;							\
	}

include/autoconf.mk.dep: include/config.h FORCE
	$(call cmd,autoconf_dep)

# 我们正在一点一点地从 board headers 迁移到 Kconfig。
# 在此期间，我们同时使用
#  - include/config/auto.conf （由 Kconfig 生成）
#  - include/autoconf.mk （用于 U-Boot 常规配置）
# 以下规则创建 include/config/auto.conf autoconf.mk 以避免相同的 CONFIG 宏重复

# 使用 sed 处理输入文件,使用/tools/scripts/define2mk.sed的规则,将宏定义转换为 make 文件格式
# 使用 while 循环读取 sed 命令的输出，并逐行处理。read line 读取每一行，并将其存储在 line 变量中
# 如果 KCONFIG_IGNORE_DUPLICATES 变量存在，或者 auto.conf 文件中不存在包含 line 变量的行，则将 line 变量的内容输出到目标文件 $@
# 将处理后的输出重定向到目标文件 $@
quiet_cmd_autoconf = GEN     $@
      cmd_autoconf = \
		sed -n -f $(srctree)/tools/scripts/define2mk.sed $< |			\
		while read line; do							\
			if [ -n "${KCONFIG_IGNORE_DUPLICATES}" ] ||			\
			   ! grep -q "$${line%=*}=" include/config/auto.conf; then	\
				echo "$$line";						\
			fi;								\
		done > $@

# 依赖与u-boot.cfg
# 生成include/autoconf.mk(用于 U-Boot 常规配置)
include/autoconf.mk: u-boot.cfg
	$(call cmd,autoconf)

# -dM 选项用于生成宏定义列表
# -DDO_DEPS_ONLY 选项用于生成依赖关系
# $2 是一个占位符，表示传递给 cmd_autoconf 宏的第二个参数 即
# 使用 grep 命令从临时文件 $@.tmp 中提取包含 define CONFIG_ 的行。
# 使用 sed 命令删除包含 CONFIG_IS_ENABLED(、CONFIG_IF_ENABLED_INT( 和 CONFIG_VAL( 的行。
# 处理后的结果重定向到目标文件  u-boot.cfg
# 删除临时文件  u-boot.cfg.tmp
quiet_cmd_u_boot_cfg = CFG     $@
      cmd_u_boot_cfg = \
	$(CPP) $(c_flags) $2 -DDO_DEPS_ONLY -dM include/config.h > $@.tmp && { \
		grep 'define CONFIG_' $@.tmp | \
			sed '/define CONFIG_IS_ENABLED(/d;/define CONFIG_IF_ENABLED_INT(/d;/define CONFIG_VAL(/d;' > $@; \
		rm $@.tmp;						\
	} || {								\
		rm $@.tmp; false;					\
	}

# 依赖于include/config/auto.conf
u-boot.cfg: include/config.h FORCE
	$(call cmd,u_boot_cfg)

# include/config.h
# Prior to Kconfig, it was generated by mkconfig. Now it is created here.
define filechk_config_h
	(echo "/* Automatically generated - do not edit */";		\
	echo \#define CFG_BOARDDIR board/$(if $(VENDOR),$(VENDOR)/)$(BOARD);\
	$(if $(CONFIG_SYS_CONFIG_NAME),echo \#include \<configs/$(CONFIG_SYS_CONFIG_NAME).h\> ;) \
	echo \#include \<asm/config.h\>;				\
	echo \#include \<linux/kconfig.h\>;				\
	echo \#include \<config_fallbacks.h\>;)
endef
# 依赖于create_symlink
include/config.h: scripts/Makefile.autoconf create_symlink FORCE
# 执行filechk_config_h
	$(call filechk,config_h)

# 符号链接
# 如果存在 arch/$（ARCH）/mach-$（SOC）/include/mach，则创建指向该目录的符号链接。
# 否则，请创建一个指向 arch/$（ARCH）/include/asm/arch-$（SOC） 的符号链接。
PHONY += create_symlink
create_symlink:
# 这行代码检查目录 arch/$(ARCH)/mach-$(SOC)/include/mach 是否存在
# 如果目录存在，则将 dest 变量设置为相对路径 ../../mach-$(SOC)/include/mach。
# 否则，将 dest 变量设置为 arch-$(if $(SOC),$(SOC),$(CPU))。
# 创建符号链接从 arch/$(ARCH)/include/asm/arch 到 dest。
ifdef CONFIG_CREATE_ARCH_SYMLINK # 如果CONFIG_CREATE_ARCH_SYMLINK存在
	$(Q)if [ -d arch/$(ARCH)/mach-$(SOC)/include/mach ]; then	\
		dest=../../mach-$(SOC)/include/mach;			\
	else								\
		dest=arch-$(if $(SOC),$(SOC),$(CPU));			\
	fi;								\
	ln -fsn $$dest arch/$(ARCH)/include/asm/arch
endif
```

```makefile
# 顶层Makefile
# Basic helpers built in scripts/
PHONY += scripts_basic
scripts_basic:
	$(Q)$(MAKE) $(build)=scripts/basic
# $(Q)$(MAKE) -f $(srctree)/scripts/Makefile.build obj=scripts/basic
	$(Q)rm -f .tmp_quiet_recordmcount
```
- `$(Q)$(MAKE) -f $(srctree)/scripts/Makefile.build obj=scripts/basic`解析
- 这是一种不指定目标的情况，由于未指定目标，这时会使用Makefile.build中的默认目标(第一个目标)__build。
- __build在Makefile.build中的构建规则为：
```makefile
# scripts/Makefile.build
__build: $(if $(KBUILD_BUILTIN),$(builtin-target) $(lib-target) $(extra-y)) \
	 $(if $(KBUILD_MODULES),$(obj-m) $(modorder-target)) \
	 $(subdir-ym) $(always)
	@:
```

# __build的变量解析与溯源

```makefile
# scripts/Makefile.build
__build: $(if $(KBUILD_BUILTIN),$(builtin-target) $(lib-target) $(extra-y)) \
	 $(if $(KBUILD_MODULES),$(obj-m) $(modorder-target)) \
	 $(subdir-ym) $(always)
	@:
```

- 语句`$(if $ (KBUILD_BUILTIN),$(builtin-target) $(lib-target) $(extra-y))`为空。
- `KBUILD_MODULES`在顶层makefile中为空,`$(if $(KBUILD_MODULES),$(obj-m) $(modorder-target))`执行为空
- 语句`$(subdir-ym)`为空

## $(KBUILD_BUILTIN)

```makefile
# 顶层Makefile
KBUILD_MODULES :=
KBUILD_BUILTIN := 1
include scripts/Kbuild.include
```

```makefile
# scripts/Makefile.build
$(if $(KBUILD_BUILTIN),$(builtin-target) $(lib-target) $(extra-y)) 
# 由于KBUILD_BUILTIN = 1 展开为
$(builtin-target) $(lib-target) $(extra-y)
```

## $(lib-target)
- 因为都是空的，所以lib-target 为空 不会执行
```makefile
#scripts/Makefile.build
lib-y :=
lib-m :=
#lib- 未定义
ifneq ($(strip $(lib-y) $(lib-m) $(lib-)),)
lib-target := $(obj)/lib.a
endif
```

## $(builtin-target​​​​​​​)
- 因为都是空的，所以builtin-target 为空 不会执行
```makefile
# scripts/Makefile.build

obj-y :=
obj-m :=
# obj- 未定义
subdir-m :=
# lib-target为空
ifneq ($(strip $(obj-y) $(obj-m) $(obj-) $(subdir-m) $(lib-target)),)
builtin-target := $(obj)/built-in.o
endif
```

## $(extra-y)
- 未定义为空

## $(subdir-ym)
- 在`scripts/Makefile.lib`中
```makefile
# note：scripts/Makefile.lib
# Subdirectories we need to descend into
subdir-ym	:= $(sort $(subdir-y) $(subdir-m))
......
subdir-ym	:= $(addprefix $(obj)/,$(subdir-ym))
```

- `$(subdir-y) $(subdir-m)`为空,`subdir-ym`为空

##  $(always) 重点关注
- 在scripts/Makefile.build有如下定义
```makefile
# note：scripts/Makefile.build
# The filename Kbuild has precedence over Makefile
kbuild-dir := $(if $(filter /%,$(src)),$(src),$(srctree)/$(src))
kbuild-file := $(if $(wildcard $(kbuild-dir)/Kbuild),$(kbuild-dir)/Kbuild,$(kbuild-dir)/Makefile)
include $(kbuild-file)
```

### src的定义
- 在scripts/Makefile.build有如下定义
```makefile
# note：scripts/Makefile.build
# Modified for U-Boot
prefix := vpl
src := $(patsubst $(prefix)/%,%,$(obj))
ifeq ($(obj),$(src))
prefix := tpl
src := $(patsubst $(prefix)/%,%,$(obj))
ifeq ($(obj),$(src))
prefix := spl
src := $(patsubst $(prefix)/%,%,$(obj))
ifeq ($(obj),$(src))
prefix := .
endif
endif
endif
```
- 在命令`make -f ./scripts/Makefile.build obj=scripts/basic`我们传入了`obj=scripts/basic`
所以`src = obj = scripts/basic, prefix := .`
