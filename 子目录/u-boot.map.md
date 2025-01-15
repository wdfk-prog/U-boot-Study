[TOC]

- [u-boot.map](./学习芯片/ART-PI/u-boot.map)

# Archive member included to satisfy reference by file (symbol) 静态库链接成员
- Archive member：归档成员是指静态库（通常是 .a 文件）中的对象文件。静态库是由多个对象文件打包而成的归档文件。
- Included to satisfy reference：这部分信息表示链接器在链接过程中包含了某个归档成员，以满足其他文件中的符号引用。
- by file (symbol)：by file 表示引用该符号的文件。symbol 表示被引用的符号名称。

## (--whole-archive) 表示在链接过程中将整个归档文件包含在内
- 这是一个链接选项，表示在链接过程中将整个归档文件包含在内。--whole-archive 选项告诉链接器将指定的归档文件中的所有对象文件都包含在最终的可执行文件中，而不仅仅是那些被其他对象文件引用的符号。

# Discarded input sections 丢弃的输入段

- 在链接过程中，某些段可能会被丢弃，因为它们不需要包含在最终的可执行文件中。

# Memory Configuration 内存配置
```c
Memory Configuration
// 名称             起始地址        长度                    属性
Name             Origin             Length             Attributes
*default*        0x0000000000000000 0xffffffffffffffff
```

# Linker script and memory map 链接脚本和内存映射
- [u-boot.lds](../学习芯片/ART-PI/u-boot.lds)
```c
Linker script and memory map
//  .text 段的起始地址被设置为 0x90000000
Address of section .text set to 0x90000000
//这行表示当前地址被设置为 0x0。这通常是一个初始化操作，用于确保地址从零开始
0x0000000000000000                . = 0x0   
//这行表示地址被对齐到 4 字节的边界。对齐操作是为了确保内存访问的效率和正确性，因为某些处理器要求数据在特定的边界上对齐
0x0000000000000000                . = ALIGN (0x4)
//__image_copy_start 设置为 .text 段的地址，即 0x90000000。这个符号通常用于指示镜像复制的起始位置，可能在启动或加载过程中使用
0x0000000090000000                __image_copy_start = ADDR (.text)
```

# LOAD 
```c
LOAD arch/arm/lib/eabi_compat.o // 加载 eabi_compat.o 对象文件
LOAD arch/arm/lib/lib.a
// elf32-littlearm 表示生成的可执行文件是 32 位小端格式的 ELF 文件，适用于 ARM 架构。
OUTPUT(u-boot elf32-littlearm)  //指定输出文件的名称和格式。u-boot 是输出文件的名称;elf32-littlearm 是输出文件的格式。
//加载链接器存根（linker stubs）。链接器存根是一些小的代码片段，用于解决跨段调用或其他链接问题
LOAD linker stubs   // 加载链接器存根可以确保在链接过程中正确处理跨段调用和其他复杂的链接需求。
```