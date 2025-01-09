[TOC]

# 编译器特性 && 选项 && 宏

## __va_arg_pack 用于处理可变参数函数

## __va_arg_pack_len 用于获取可变参数的数量

## `__fortify_function` 用于启用额外的安全检查，以防止常见的编程错误，如缓冲区溢出

## **`__LEAF`** 告诉编译器，该函数是一个叶函数（leaf function），即它不会调用其他函数

- 叶函数的属性允许编译器进行进一步的优化，例如减少函数调用的开销和栈空间的使用。

## `__error__` 属性告诉编译器，如果该函数被调用，则会触发编译错误，并输出指定的错误消息 `msg`

```c
# define __errordecl(name, msg) \
  extern void name (void) __attribute__((__error__ (msg)))
```

## __builtin_constant_p 检查 参数 是否为编译时常量

## `__attribute_malloc__ 用于标记函数返回一个新分配的内存块`

- 这有助于编译器进行优化，例如避免不必要的内存检查。

## `__attribute_alloc_size__` 用于指定分配的内存大小

- `attribute_alloc_size__ ((1))` 是另一个 GCC 特定的扩展，用于指定分配的内存大小。参数 `(1)` 表示第一个参数 `__size` 是分配的内存大小。这有助于编译器进行优化和静态分析

## __wur 表示函数的返回值不应被忽略

- `__wur` 是 `__attribute__ ((__warn_unused_result__))` 的缩写，表示函数的返回值不应被忽略。这有助于防止内存泄漏，因为调用者必须处理返回的指针

## __THROW && __NTH 声明函数不会抛出任何异常

## __nonnull 用于指示函数的某些参数不能为空指针

- 这有助于编译器进行静态分析，检测潜在的错误，并在编译时发出警告或错误信息，从而提高代码的安全性和可靠性。
- 语法为 `__attribute__((nonnull (arg_index1, arg_index2, ...)))`，其中 `arg_index` 是参数的索引，从 1 开始。

```c
extern int __lxstat (int __ver, const char *__filename,
		     struct stat *__stat_buf) __THROW __nonnull ((2, 3));
```

- **`__nonnull ((3))`** ：这表示 `__fxstat` 函数的第2和3个参数（即 `__stat_buf`）不能为空指针。如果在调用 `__fxstat` 函数时传递了空指针作为第三个参数，编译器会在编译时发出警告或错误信息。

## __errordecl 用于声明编译时错误信息

```c
# define __errordecl(name, msg) \
  extern void name (void) __attribute__((__error__ (msg)))
```

## __REDIRECT 将一个函数重定向到另一个函数

- 将openalias重定向到open函数

```c
extern int __REDIRECT (__open_alias, (const char *__path, int __oflag, ...),
            open) __nonnull ((1));
```

## `__builtin_object_size` 用于在编译时确定指针所指向对象的大小

- `__builtin_object_size` 是 GCC 编译器提供的一个内置函数，用于在编译时确定指针所指向对象的大小。

* 该函数接受两个参数：
  * 第一个参数是指针 `ptr`。
  * 第二个参数是一个常量整数，用于指定计算对象大小的方式。值 `0` 表示返回对象的最大已知大小

# 关键字

## __restrict 用于指示指针或引用所指向的内存区域在当前作用域内不会被其他指针或引用所别名

- 在 C99 标准中，`restrict` 是标准关键字。在某些编译器实现中，可能使用 `__restrict` 作为扩展。
- 通过使用 `__restrict`，开发人员可以告诉编译器，在当前作用域内，通过该指针访问的内存区域不会与其他指针访问的内存区域重叠。这使得编译器可以进行更激进的优化，例如更好地利用寄存器和减少内存访问，从而提高程序的性能。

# 全局变量

## `stderr` 标准错误输出流

- `stderr` 是标准错误输出流，通常用于输出错误和警告信息。在大多数操作系统中，`stderr` 是一个全局的文件流，默认情况下输出到控制台或终端。`stderr` 流的处理由操作系统和 C 标准库管理。通常，`stderr` 流是无缓冲的，这意味着每次写入操作都会立即输出到终端或控制台
- 多线程环境中的 `stderr` 处理在多线程环境中，如果多个线程同时向 `stderr` 流写入数据，可能会导致输出混乱。

# 函数

## exit

- 错误码参考include/linux/errno.h

## `perror` 接受一个字符串参数，并将该字符串作为前缀输出到标准错误流

```c
perror(filename);
```

`perror` 函数接受一个字符串参数，并将该字符串作为前缀输出到标准错误流（`stderr`），后面跟随一个冒号和一个空格，然后是与当前 `errno` 值对应的错误消息。

- `filename` 是传递给 `perror` 的字符串参数，通常表示发生错误的文件的名称。

1. **错误信息输出**：

   - 当文件操作失败时，例如打开文件、读取文件或写入文件失败，`errno` 会被设置为相应的错误代码。
   - `perror(filename)` 会输出类似于以下格式的错误信息：
     ```
     filename: No such file or directory
     ```
   - 其中，`filename` 是传递给 `perror` 的字符串，`No such file or directory` 是与 `errno` 值对应的错误消息。

## `fprintf` 将格式化的输出写入指定的文件流

- 它的功能类似于 `printf`，但 `fprintf` 允许你指定输出的目标文件流，而不仅仅是标准输出（stdout）。

### 函数原型

```c
int fprintf(FILE *stream, const char *format, ...);
```

- **`stream`**：目标文件流，指定输出的目标。例如，`stderr` 表示标准错误输出流。
- **`format`**：格式字符串，指定输出的格式。
- **`...`**：可变参数，根据格式字符串指定的格式，提供相应的值。

### 返回值

- 成功时，返回写入的字符数。
- 失败时，返回负值。

### 源码

- 定义了一个增强的 `fprintf` 函数版本，用于在编译时进行额外的安全检查。这段代码利用了编译器的特性来提高函数的安全性和可靠性。

```c
# ifdef __va_arg_pack //__va_arg_pack 是一个编译器特性，通常用于处理可变参数函数。
// __fortify_function 是一个编译器特性，用于启用额外的安全检查，以防止常见的编程错误，如缓冲区溢出
__fortify_function int
fprintf (FILE *__restrict __stream, const char *__restrict __fmt, ...)
{
  return __fprintf_chk (__stream, __USE_FORTIFY_LEVEL - 1, __fmt,
			__va_arg_pack ());
}
#endif
```

## fstat 获取文件描述符 `fd` 对应文件的状态信息

* `fstat` 函数返回 0 表示成功，返回 -1 表示失败并设置 `errno`。

## isalnum 检查字符是否为字母或数字

1. **函数声明**：

   ```c
   int isalnum(int c);
   ```

   - `isalnum` 函数接受一个整数参数 `c`，表示要检查的字符。
   - 返回值为非零值（通常为 1）表示字符是字母或数字，返回 0 表示字符不是字母或数字。
2. **用途**：

   - `isalnum` 函数用于判断字符是否属于字母（包括大写和小写字母）或数字（0-9）。
   - 这是一个常用的字符分类函数，在处理字符串和字符数据时非常有用。

## isatty 检查文件描述符是否指向一个终端设备

### 参数

* `fd`：一个整数，表示文件描述符。常见的文件描述符包括：
  * `0`：标准输入（stdin）
  * `1`：标准输出（stdout）
  * `2`：标准错误输出（stderr）

### 返回值

* 如果文件描述符指向一个终端设备，`isatty` 返回非零值（通常为 1）。
* 如果文件描述符不指向一个终端设备，`isatty` 返回 0。

## getopt_core.h

- `optarg` 是一个指向字符的指针，用于存储当前选项的参数值
- `optind` 是一个整数，表示下一个要扫描的 ARGV 元素的索引
- `opterr` 是一个整数，用于控制 `getopt` 函数是否打印未识别选项的错误消息
- `optopt` 是一个整数，用于存储未识别的选项字符

### getopt_long 处理长选项（即以双破折号 `--` 开头的选项）和短选项（即以单破折号 `-` 开头的选项）

1. **函数声明**：

   ```c
   int getopt_long(int argc, char *const argv[], const char *optstring,
                   const struct option *longopts, int *longindex);
   ```

   - `getopt_long` 函数接受五个参数：
     - `argc`：命令行参数的数量。
     - `argv`：命令行参数的数组。
     - `optstring`：一个字符串，包含短选项的字符。如果一个选项需要参数，其后应跟一个冒号 `:`。
     - `longopts`：一个指向 `struct option` 数组的指针，定义了长选项。
     - `longindex`：一个指向整数的指针，用于存储当前匹配的长选项在 `longopts` 数组中的索引。
2. **返回值** ：

- 当 `getopt_long` 无法匹配到命令行选项时，它会返回 `?`。
- 如果遇到未知选项或选项缺少必需的参数，`getopt_long` 也会返回 `?`。

4. **`struct option` 结构体**：

   ```c
   struct option {
       const char *name;
       int has_arg;
       int *flag;
       int val;
   };
   ```

   - `struct option` 结构体用于定义长选项：
     - `name`：长选项的名称。
     - `has_arg`：指示选项是否需要参数。取值可以是 `no_argument`、`required_argument` 或 `optional_argument`。
     - `flag`：如果为 `NULL`，则返回 `val` 作为选项的值；否则，将 `val` 存储在 `flag` 指向的变量中，并返回 0。
     - `val`：选项的值或标志。
5. **使用示例**：

   ```c
   int main(int argc, char *argv[]) {
       int opt;
       struct option longopts[] = {
           {"help", no_argument, NULL, 'h'},
           {"version", no_argument, NULL, 'v'},
           {"output", required_argument, NULL, 'o'},
           {0, 0, 0, 0}
       };
   
       while ((opt = getopt_long(argc, argv, "hvo:", longopts, NULL)) != -1) {
           switch (opt) {
           case 'h':
               printf("Usage: ...\n");
               break;
           case 'v':
               printf("Version: ...\n");
               break;
           case 'o':
               printf("Output: %s\n", optarg);
               break;
           default:
               fprintf(stderr, "Unknown option\n");
               exit(EXIT_FAILURE);
           }
       }
       return 0;
   }
   ```

## getenv **获取环境变量**

* `getenv` 是一个标准库函数，用于获取环境变量的值。
* `getenv` 函数接受一个字符串参数，表示环境变量的名称，并返回一个指向该环境变量值的指针。如果环境变量不存在，则返回 `NULL`。

```shell
echo $KCONFIG_SEED # 显示环境变量的值
```
