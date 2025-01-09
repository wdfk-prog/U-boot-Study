[TOC]

# 执行

1. 输入make命令，执行Makefile文件中的第一个目标。如果没有指定目标，则执行Makefile文件中的第一个目标。

在 Makefile 中，如果你运行 make 而不带任何参数，make 将默认执行第一个目标。如果第一个目标是 __build，那么运行 make 将等同于执行 make __build.在 Makefile 中，第一个出现的目标通常被视为默认目标。如果你运行 make 而不带任何参数，make 将执行这个默认目标。

2. `$(KCONFIG_CONFIG) include/config/auto.conf.cmd: ;`
这条语句定义了一个目标，它包含两个文件：$(KCONFIG_CONFIG) 和 auto.conf.cmd。当这两个文件被调用时，执行一个空命令;这意味着这两个文件是一起作为一个目标的，只有在这两个文件都存在时，才会执行空命令

# 语法

## ifeq && ifneq 条件语句

- ifeq 比较两个条件（条件1 和 条件2）。
  - 如果两个条件相等，则执行 ifeq 块中的代码。
  - 如果两个条件不相等，并且存在 else 块，则执行 else 块中的代码。
- ifneq 比较两个条件（条件1 和 条件2）。
  - 如果两个条件不相等，则执行 ifneq 块中的代码。
  - 如果两个条件相等，并且存在 else 块，则执行 else 块中的代码。

## unexport && undefine 取消导出变量与取消定义变量

- 取消导出 `HOST_ARCH` 变量。这意味着在 Makefile 中定义的 `HOST_ARCH` 变量将不会传递给由 `make` 启动的任何子进程。

```makefile
unexport HOST_ARCH
```

## for 循环

- `for i in $(MAKECMDGOALS); do \：`定义一个循环变量 i，遍历 $(MAKECMDGOALS) 中的所有目标。`done：`结束循环。
- 双美元符号 $$：在 Makefile 中，`$$` 用于转义 `$` 符号，以避免与 Makefile 变量冲突。

## $(VAR:pattern=replacement)
```makefile
ARCH := $(CONFIG_SYS_ARCH:"%"=%)
```
- 这里使用了 make 的字符串替换语法 $(VAR:pattern=replacement)。在这个语法中，VAR 是要进行替换操作的变量，pattern 是要匹配的模式，replacement 是用来替换匹配模式的字符串。

# 选项

## -rR 不使用内置规则和变量

- `-r`：告诉 `make` 不要使用内置的隐含规则。这可以加快构建过程，因为 `make` 不会尝试使用默认的规则来构建目标。
- `-R`：告诉 `make` 不要使用内置的变量。这可以防止内置变量干扰你的 Makefile 中定义的变量。

```makefile
MAKEFLAGS += -rR
```

## -C 切换指定目录

- **切换目录** ： 当 `make` 遇到 `-C` 选项时，它会切换到指定的目录，然后在该目录中执行后续的命令。这意味着所有的相对路径和文件操作都会基于这个新目录，而不是原始的工作目录

```makefile
$(MAKE) -C $(KBUILD_OUTPUT) $(MAKECMDGOALS)`
```

## -f 用于指定一个特定的 Makefile 文件

指定 Makefile 文件： 当 make 遇到 -f 选项时，它会使用紧随其后的文件名作为 Makefile 文件，而不是默认的 Makefile 或 makefile 文件。这允许你灵活地指定不同的构建配置文件。

```makefile
$(MAKE) -f $(CURDIR)/Makefile
make -f ./scripts/Makefile.build obj=scripts/basic
```

## --include-dir 指定包含目录

## --no-print-directory 抑制 `make` 在进入和离开目录时打印的消息

- **`--no-print-directory` 选项** ： `--no-print-directory` 是 `make` 的一个命令行选项，用于抑制 `make` 在进入和离开目录时打印的消息。默认情况下，当 `make` 处理递归构建（即在子目录中调用 `make`）时，会打印类似于 `Entering directory '...'` 和 `Leaving directory '...'` 的消息。这些消息有助于调试和跟踪构建过程，但在某些情况下，它们可能会使输出变得冗长和难以阅读

## -Wall 启用所有常见的警告

## `-Wstrict-prototypes` 强制函数原型声明

## `-fomit-frame-pointer` 省略帧指针以优化性能

## -std 用于指定编译时应遵循的语言标准

* **`-std=c89`** 或  **`-std=iso9899:1990`** ：

  * 指定使用 ANSI C 标准（C89 或 C90）。
* **`-std=c99`** 或  **`-std=iso9899:1999`** ：

  * 指定使用 C99 标准，该标准引入了许多新特性，如变量声明可以在代码的任何位置、`inline` 函数、`long long` 类型等。
* **`-std=c11`** 或  **`-std=iso9899:2011`** ：

  * 指定使用 C11 标准，该标准引入了多线程支持、原子操作、泛型宏等。
* **`-std=c17`** 或  **`-std=iso9899:2017`** ：

  * 指定使用 C17 标准，这是 C11 的一个修订版本，主要是一些小的修正和改进。
* **`-std=gnu11`** ：

  * 指定使用 GNU 扩展的 C11 标准。
  * 这意味着代码将遵循 C11 标准，同时可以使用一些 GNU 编译器特有的扩展和特性。
* **`-std=c++98`** 或  **`-std=iso14882:1998`** ：

  * 指定使用 C++98 标准，这是第一个 C++ 标准。
* **`-std=c++03`** 或  **`-std=iso14882:2003`** ：

  * 指定使用 C++03 标准，这是 C++98 的一个修订版本，主要是一些小的修正和改进。
* **`-std=c++11`** 或  **`-std=iso14882:2011`** ：

  * 指定使用 C++11 标准，该标准引入了许多新特性，如 `auto` 关键字、`nullptr`、lambda 表达式、范围 `for` 循环等。
* **`-std=c++14`** 或  **`-std=iso14882:2014`** ：

  * 指定使用 C++14 标准，这是 C++11 的一个修订版本，主要是一些小的改进和新特性。
* **`-std=c++17`** 或  **`-std=iso14882:2017`** ：

  * 指定使用 C++17 标准，该标准引入了许多新特性，如结构化绑定、`if constexpr`、并行算法等。
* **`-std=c++20`** 或  **`-std=iso14882:2020`** ：

  * 指定使用 C++20 标准，该标准引入了概念（concepts）、协程（coroutines）、模块（modules）等

## -ansi 用于启用 ANSI C 标准（C89)

- `-ansi` 标志用于启用 ANSI C 标准（C89），并禁用所有 GNU 扩展。这在某些情况下可以提高代码的可移植性和兼容性，特别是在需要严格遵循 ANSI C 标准的环境中。

## `-Wall`：启用所有常见的警告。

## `-Wstrict-prototypes`：强制函数原型声明。

## `-Wno-format-security`：禁用格式安全警告。

## `-fno-builtin`：禁用内建函数。

## `-ffreestanding`：表示代码在独立环境中运行，不依赖标准库。

## `-fshort-wchar`：将 `wchar_t` 类型定义为短类型。

## `-fno-strict-aliasing`：禁用严格别名规则。

## -fno-PIE:禁用位置无关执行特性

- `-fno-PIE` 选项用于禁用位置无关执行特性，确保生成的可执行文件在固定地址运行，而不是在加载时随机化地址。

## -no-integrated-as 用于禁用编译器的集成汇编器

- `-no-integrated-as` 是一个编译器选项，用于禁用编译器的集成汇编器（integrated assembler）。集成汇编器是编译器内部的一部分，直接处理汇编代码，而不需要调用外部的汇编器工具。禁用集成汇编器可以强制编译器使用外部汇编器，这在某些情况下可能是必要的。

## -dM 选项用于生成宏定义列表
- 用于生成宏定义列表。这个选项告诉编译器只预处理源文件，并输出预处理后的结果。这样可以查看编译器在预处理阶段定义的所有宏。或者输出到文件中，然后查看文件内容。

## -DDO_DEPS_ONLY 选项用于生成依赖关系

## -T 选项用于指定链接脚本

# 环境变量 && 内置变量

## MAKECMDGOALS 包含在命令行中指定的所有目标

## CROSS_COMPILE 交叉编译器

- 输入: `CROSS_COMPILE=arm-none-eabi-`, 输出: `arm-none-eabi-`

  1. `echo $(CROSS_COMPILE)` 输出 `arm-none-eabi-`。
  2. `sed -n 's/^\(.*ccache\)\{0,1\}[[:space:]]*\([^\/]*\/\)*\([^-]*\)-[^[:space:]]*/\3/p'` 处理这个输出：

  - `^\(.*ccache\)\{0,1\}`：匹配可选的 `ccache` 前缀（在这里没有匹配到）。
  - `[[:space:]]*`：匹配零个或多个空白字符（在这里没有匹配到）。
  - `\([^\/]*\/\)*`：匹配零个或多个以 `/` 结尾的路径部分（在这里没有匹配到）。
  - `\([^-]*\)-`：匹配并捕获 `arm`，直到第一个 `-` 字符。
  - `[^[:space:]]*`：匹配后续的非空白字符（在这里匹配 `none-eabi-`）。

```makefile
ifeq ("", "$(CROSS_COMPILE)")	# 如果 CROSS_COMPILE(交叉编译器) 为空执行
  MK_ARCH="${shell uname -m}"	# 获取主机的体系结构
else							# 匹配输入的CROSS_COMPILE值
  MK_ARCH="${shell echo $(CROSS_COMPILE) | sed -n 's/^\(.*ccache\)\{0,1\}[[:space:]]*\([^\/]*\/\)*\([^-]*\)-[^[:space:]]*/\3/p'}"
endif
```

- `arm-none-eabi-` 是一个交叉编译工具链的前缀，用于指定目标架构和环境。具体来说：

  - 代表 ARM 32-bit 架构（通常是 ARMv7 或更早的架构）
  - `arm`：表示目标处理器架构是 ARM。
  - `none`：表示没有特定的操作系统（裸机环境）。
  - `eabi`：表示使用嵌入式应用二进制接口（Embedded Application Binary Interface）。
  - `arm-none-eabi-gcc`：ARM 交叉编译器。
  - `arm-none-eabi-ld`：ARM 交叉链接器。
  - `arm-none-eabi-as`：ARM 交叉汇编器。
- `aarch64` 是 ARMv8 架构的 64 位版本。因此，`aarch64-none-elf-` 是用于 ARMv8 架构的交叉编译工具链的前缀。

  - 代表 ARM 64-bit 架构（也称为 ARMv8-A 架构）。

## LC_ALL LC_COLLATE LC_NUMERIC

- `LC_ALL`：设置所有的本地化设置。
- `LC_COLLATE`：设置字符串比较和排序的本地化设置。
- `LC_NUMERIC`：设置数字格式的本地化设置。
- 例如，在c本地化环境中，字符串会按照ASCI 值进行排序，这意味着大写字母会排在小写字母之前，数字会排在字母之前。这种排序规则与特定语言的本地化排序规则不同，后者可能会根据语言的字母表顺序进行排序。

```makefile
LC_COLLATE=C
LC_NUMERIC=C
```

## GREP_OPTIONS 搜索文本模式选项

- `GREP OPTIONS` 是命令的默认选环境变量，用于配置 grep项。grep是一个常用的命令行工具，用于在文件中搜索文本模式

## CURDIR 当前目录

## MAKECMDGOALS 目标列表

- `MAKECMDGOALS` 是一个特殊的变量，用于存储用户在命令行中指定的所有目标。当你运行 `make` 命令并指定一个或多个目标时，这些目标会被保存到 `MAKECMDGOALS` 变量中。例如，如果你运行 `make clean all`，那么 `MAKECMDGOALS` 的值将是 `clean all`。

## MAKE

- 这是一个特殊的变量，通常等同于 `make` 命令本身。使用 `$(MAKE)` 而不是直接调用 `make` 的好处是，它会继承当前 `make` 的所有参数和选项。

## CDPATH 指定 `cd` 命令的搜索路径

## VPATH 指定 `make` 在搜索依赖文件时应该查找的目录列表

**定义 `VPATH` 变量**：

1. `VPATH` 变量的值是一个目录列表，目录之间用冒号 `:` 分隔。在Makefile 中，可以通过如下方式定义 `VPATH` 变量：

```makefile
   VPATH := src:include:lib
```

   在这个示例中，`VPATH` 变量指定了三个目录：`src`、`include` 和 `lib`。当 `make` 需要查找依赖文件时，它会依次在这些目录中搜索。

2. **搜索依赖文件**：
   当 `make` 处理规则并查找依赖文件时，如果在当前目录中找不到依赖文件，它会使用 `VPATH` 变量中指定的目录列表进行搜索。例如：

   ```makefile
   main.o: main.cpp
       g++ -c main.cpp -o main.o
   ```

   如果 `main.cpp` 文件不在当前目录中，`make` 会在 `VPATH` 变量中指定的目录列表中搜索 `main.cpp` 文件。

## 指定编译器

- `cc`，表示使用系统默认的 C 编译器。
- `c++`，表示使用系统默认的 C++ 编译器。

* `gcc`（GNU Compiler Collection）是一个广泛使用的开源编译器，支持多种编程语言，包括 C、C++、Fortran 等。
* `g++` 是 `gcc` 的 C++ 编译器前端，用于编译 C++ 代码。
* `clang` 是一个基于 LLVM 的编译器，支持 C、C++ 和 Objective-C 等语言。
* `clang++` 是 `clang` 的 C++ 编译器前端，用于编译 C++ 代码。
* `icc`（Intel C Compiler）是 Intel 提供的高性能 C 编译器。
* `icpc` 是 Intel 提供的高性能 C++ 编译器。
* 交叉编译工具链用于在一个平台上编译生成适用于另一个平台的可执行文件。
* 常见的交叉编译工具链包括 ARM、MIPS 等。

## **其他构建工具变量**

- `AS 定义汇编器`
  - **使用 `$(CROSS_COMPILE)` 变量前缀来支持交叉编译。`$(CROSS_COMPILE)` 通常包含目标平台的前缀，例如 `arm-none-eabi-`，以确保使用正确的工具链。
- **链接器 `LD`**
- **C 编译器 `CC`**
- **C 预处理器 `CPP`**

* `AR`：归档工具，用于创建静态库。
* `NM`：符号表工具，用于列出目标文件中的符号。
* `LDR`：加载器工具。
* `STRIP`：剥离工具，用于移除目标文件中的符号信息。
* `OBJCOPY`：对象复制工具，用于复制和转换目标文件。
* `OBJDUMP`：对象转储工具，用于显示目标文件的内容。
* `LEX` 和 `YACC`：词法分析器和语法分析器生成工具。
* `AWK`、`PERL`、`PYTHON`、`PYTHON2` 和 `PYTHON3`：脚本语言解释器，用于处理构建过程中的脚本。

## $(LD) 是 make 变量，表示链接器命令，通常是 ld 或 gcc

## 

# 函数

## findstring 查找字符串

- `findstring` 是 GNU `make` 中的一个函数，用于在一个字符串中查找另一个字符串。如果找到匹配的子字符串，则返回该子字符串；否则返回空字符串。

其语法如下：

```makefile
$(findstring <find>,<in>)
```

- `<find>`：要查找的子字符串。
- `<in>`：要在其中查找的字符串。

例如：

```makefile
RESULT := $(findstring arm, armv7a)
```

在这个例子中，`RESULT` 的值将是 `arm`，因为 `arm` 是 `armv7a` 的子字符串。

## filter-out 过滤字符串

- `filter-out` 是一个函数，用于从一个空格分隔的字符串列表中移除指定的模式。它的语法如下：

```makefile
$(filter-out pattern..., text)
```

- `pattern...`：要移除的模式，可以是一个或多个模式。
- `text`：要处理的字符串列表。

`filter-out` 函数会返回一个新的字符串列表，其中移除了所有匹配指定模式的元素。

例如：

```makefile
# 定义一个变量包含多个目标
TARGETS := clean build test

# 使用 filter-out 移除 'clean' 目标
RESULT := $(filter-out clean, $(TARGETS))

# 结果将是 'build test'
```

## origin

- `origin` 是一个内置函数，用于确定一个变量是如何定义的。它可以返回变量的定义来源，这对于调试和控制构建过程中的变量行为非常有用。

### 用法

`origin` 函数的语法如下：

```makefile
$(origin <variable>)
```

其中 `<variable>` 是你想要检查的变量名。

### 返回值

`origin` 函数可以返回以下几种值：

- `undefined`：变量未定义。
- `default`：变量是一个默认的内置变量。
- `environment`：变量是从环境中继承的。
- `environment override`：变量是从环境中继承的，并且使用 `-e` 选项覆盖了Makefile 中的定义。
- `file`：变量是在Makefile 中定义的。
- `command line`：变量是通过命令行定义的。
- `override`：变量是使用 `override` 指令在Makefile 中定义的。
- `automatic`：变量是一个自动变量，例如 `$@`、`$<` 等。

## addprefix 每个单词添加指定的前缀

### 语法

```makefile
$(addprefix prefix, names)
```

- `prefix`：要添加的前缀。
- `names`：一个或多个单词，通常是文件名或目标名。

## words 用于计算传递给它的字符串中的单词数量

## escsq 用于转义单引号

- escsq 函数的作用是将字符串中的单引号 ' 转义为 \'。这在处理包含单引号的字符串时非常有用，特别是在生成 shell 命令时。

```makefile
# 定义 escsq 函数，用于转义单引号
escsq = $(subst ','\'',$(1))
```

## strip 用于删除字符串前后的空格

```makefile
$(strip <string>)
```
- <string> 是要处理的字符串。
- $(strip <string>) 返回去除前导和尾随空白字符后的字符串。

### foreach 遍历列表
- `foreach` 函数用于遍历一个列表，并对列表中的每个元素执行指定的操作。它的语法如下：

```makefile
$(foreach <var>,<list>,<text>)
```
- `<var>`：循环变量，用于存储列表中的每个元素。
- `<list>`：要遍历的列表。
- `<text>`：对每个元素执行的操作。

## wildcard 用于扩展文件名模式匹配

```makefile
$(wildcard pattern)
```

- `pattern` 是文件名模式，可以包含通配符（如 `*` 和 `?`）。
- `$(wildcard pattern)` 返回符合模式的文件列表。

## patsubst 用于模式替换

- patsubst 是 make 的一个内置函数，用于模式替换。它的语法是 $(patsubst pattern,replacement,text)，其中 pattern 是要匹配的模式，replacement 是替换后的字符串，text 是要处理的文本。



# 目标

## PHONY 伪目标

- `PHONY` 是一个特殊的目标，用于声明伪目标（phony targets）。伪目标是指那些不直接对应于文件的目标，而是用于执行特定的命令或任务。通过将目标声明为伪目标，可以确保每次运行 `make` 时，这些目标都会被执行，而不会受到文件时间戳的影响。
- 伪目标的主要作用是避免与文件名冲突，并确保每次运行 `make` 时都执行相应的命令。例如，如果你有一个名为 `clean` 的目标用于删除生成的文件，你可以将其声明为伪目标，以确保每次运行 `make clean` 时都执行清理操作，而不会受到文件系统中是否存在名为 `clean` 的文件的影响。


## 依赖的优先级

- 在 Makefile 中，目标的依赖项是按顺序列出的，但它们的优先级并不是严格定义的。make 会根据依赖项的时间戳来决定哪些依赖项需要重新构建，并且会尽量并行地构建这些依赖项（如果可能）。不过，依赖项的顺序在某些情况下可能会影响构建过程，特别是当依赖项之间存在依赖关系时。

## FORCE 强制执行目标

- 定义 FORCE 目标的目的是为了强制执行依赖于它的规则。由于 FORCE 目标没有任何命令或依赖项，它总是被认为是“过时的”，因此任何依赖于 FORCE 的目标也总是会被重新构建。

# 符号 通配符

## @ 抑制命令的输出

- `@` 符号在Makefile中用于抑制命令的输出。通常，当 `make` 执行命令时，会在终端中显示该命令。如果在命令前加上 `@` 符号，`make` 将不会显示该命令，只会显示命令的输出结果。

## := 立即展开的赋值操作

- `:=` 是立即展开的赋值操作符，这意味着在定义时，变量的值就已经确定

## $ 引用变量或函数

1. **引用变量**：

   ```makefile
   VAR = value
   all:
       echo $(VAR)
   ```

   在这个例子中，`$(VAR)` 用于引用变量 `VAR` 的值，即 `value`。
2. **引用函数**：

Makefile 中有许多内置函数，可以通过 `$` 符号来调用。例如：

```makefile
   all:
       echo $(shell pwd)
```

   这里的 `$(shell pwd)` 调用了 `shell` 函数，执行 `pwd` 命令并返回当前目录。

3. **自动变量**：

Makefile 中有一些特殊的自动变量，用于在规则中引用目标和依赖项。例如：

```makefile
   target: dependency
       echo $@
       echo $<
```

- `$@` 引用当前规则的目标，即 `target`。
- `$<` 引用第一个依赖项，即 `dependency`。

4. **转义字符**：
   如果需要在Makefile 中使用字面上的 `$` 符号，可以使用 `$$` 来转义。例如：

```makefile
   all:
       echo $$
```

   这将输出一个 `$` 符号。

   5. **变量替换**：

    -  `$(VAR:old=new)` 用于将变量 `VAR` 中的 `old` 替换为 `new`。
    - `cmd = @$(echo-cmd) $(cmd_$(1))` 用于将 `cmd` 变量设置为一个命令，其中 `$(1)` 是一个参数，用于引用另一个变量 `cmd_$(1)`。

## ?= 变量未被定义或为空时，才会将其设置

- `?=` 是一个条件赋值运算符，表示只有在变量未被定义或为空时，才会将其设置。如果已经有值，则保持其原有值不变。

## % 匹配任意字符串

- %config:匹配所有以 `config` 结尾的目标

## include 包含其他 Makefile 文件

## -include 包含其他 Makefile 文件,但不存在时不会报错

## sinclude 包含其他 Makefile 文件,但不存在时不会报错
