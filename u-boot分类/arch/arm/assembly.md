---
title: assembly
categories:
  - uboot
  - u-boot分类
  - arch
  - arm
tags:
  - uboot
  - u-boot分类
  - arch
  - arm
abbrlink: 1a09ef0b
date: 2025-10-03 09:44:27
---
[TOC]

# 声明
## .globl 声明全局符号
- 使其在链接过程中可以被其他文件引用

## .long 用于定义一个32位的整数

## .type  声明符号类型
- `.type reset, %function`指令指定reset是一个函数类型的符号

## 段定义与操作
### .section 用于定义代码段
- 通过使用 .section 指令，开发者可以明确地指定代码和数据在内存中的布局，从而更好地控制程序的结构和行为。

### pushsection 用于定义代码段并且设置段属性
- pushsection 指令用于定义一个新的代码段，并且可以设置段属性。它的语法如下：
    ```assembly
    pushsection section_name, flags
    ```
    - `section_name` 是新的代码段的名称。
    - `flags` 是段属性，可以是以下值之一：
        - `awx`：表示代码段，可读、可写、可执行。
        - `a`：表示代码段，可读。
        - `w`：表示代码段，可写。
        - `x`：表示代码段，可执行。

### .text 指定了代码段为 .text

## .macro 定义宏
`.macro` 指令用于在汇编代码中定义一个宏。宏是一段可以重复使用的代码块，可以带有参数。定义宏后，可以在代码中多次调用它，每次调用时可以传递不同的参数。

- 语法如下：
    ```assembly
    .macro macro_name, param1, param2, ...
        code
    .endm
    ```
    - `macro_name` 是宏的名称。
    - `param1, param2, ...` 是宏的参数。
    - `code` 是宏的主体代码，可以使用参数。
- 在汇编宏中，除了使用 \c 这种特殊情况外，还可以使用其他类似的转义字符来处理宏参数。以下是一些常见的情况：
    - 普通参数：直接使用宏参数名，例如 \param。
    - 带有条件码的参数：使用 \c 这种形式来表示条件码。
    - 带有寄存器的参数：使用 \reg 这种形式来表示寄存器。

## .irp .endr 用于重复生成代码
- .rept 和 .endr 是汇编语言中的伪指令，用于重复生成代码或数据。
- .rept 指令用于指定重复的次数。
- .endr 指令用于结束重复块。
- 在 .rept 和 .endr 之间的代码或数据将被重复指定的次数。

- GNU汇编器（GAS）中的一个宏指令
- 它允许你定义一个循环宏，循环变量会依次取指定的值，并在每次循环中生成相应的代码。
- 语法如下：
    ```assembly
    .irp variable, value1, value2, ..., valueN
        code
    .endr
    ```
    - variable 是循环变量的名称。
    - value1, value2, ..., valueN 是循环变量依次取的值。
    - code 是在每次循环中生成的代码，可以使用循环变量。
- 例如：
    ```assembly
    .irp reg, r0, r1, r2, r3
        mov \reg, #0
    .endr
    ```
    - 这段代码会生成如下指令：
    ```assembly
        mov r0, #0
        mov r1, #0
        mov r2, #0
        mov r3, #0
    ```

## .syntax 语法模式
- .syntax 指令用于指定汇编器的语法模式。它的语法如下：
    ```assembly
    .syntax syntax_mode
    ```
    - `syntax_mode` 是汇编器的语法模式，可以是以下值之一：
        - `unified`：表示统一语法模式。
        - `divided`：表示分离语法模式。

## .thumb 指定汇编器使用 Thumb 指令集
## .thumb_func 指定函数使用 Thumb 指令集

# 寄存器

## pc 程序计数器
- pc寄存器存储的是当前指令的地址

## lr 链接寄存器
- lr寄存器存储的是函数调用的返回地址

## sp 堆栈指针寄存器
- 它用于指向当前堆栈的顶部，管理函数调用和局部变量的存储。堆栈通常用于保存函数的返回地址、局部变量和临时数据

## r0 - r12 通用寄存器(General Purpose Registers）
- r0 到 r3：这些寄存器通常用于函数调用时传递参数和返回值。在 ARM 的调用约定中，前四个参数通过 r0 到 r3 传递，函数的返回值也通过 r0 返回。
- r4 到 r11：这些寄存器通常用于保存局部变量和中间计算结果。它们在函数调用过程中需要保存和恢复，以确保调用者和被调用者之间的数据一致性。
- r12（也称为 IP，Intra-Procedure-call scratch register）：这个寄存器通常用作临时寄存器，在函数调用过程中可以被自由使用，不需要保存和恢复。

# 指令
## 数据操作指令
### bic 按位清零（Bit Clear）
- bic 指令的工作原理是将源寄存器的值与立即数或另一个寄存器的按位取反值进行按位与运算。结果存储在目标寄存器中。
- 语法如下：
    ```assembly
    bic dest_reg, src_reg, imm
    ```
    - `dest_reg` 是目标寄存器，存储运算结果。
    - `src_reg` 是源寄存器，存储要清零的值。
    - `imm` 是立即数或另一个寄存器的值，用于按位取反。

### ands 按位与并设置条件码
- ands 是 ARM 汇编语言中的一条指令，表示 "AND with Update Status"。它用于将两个操作数进行按位与运算，并更新条件标志寄存器（CPSR）。ands 指令不仅执行按位与运算，还会根据结果更新条件标志寄存器中的标志位。
- 语法如下：
    ```assembly
    ands dest_reg, src_reg, operand2
    ```
    - `dest_reg` 是目标寄存器，存储运算结果。
    - `src_reg` 是源寄存器，存储要进行按位与运算的值。
    - `operand2` 是第二个操作数，可以是立即数、寄存器或寄存器移位后的值。

### orr 按位或
- orr 指令用于将两个操作数进行按位或运算。它的语法如下：
```assembly
orr dest_reg, src_reg, operand2
```
- `dest_reg` 是目标寄存器，存储运算结果。
- `src_reg` 是源寄存器，存储要进行按位或运算的值。
- `operand2` 是第二个操作数，可以是立即数、寄存器或寄存器移位后的值。


### lsl 逻辑左移（Logical Shift Left）
- lsl 是 ARM 汇编语言中的一条指令，表示逻辑左移（Logical Shift Left）。它用于将寄存器中的值按指定的位数向左移动，并在右边用零填充。逻辑左移操作可以用于快速乘以 2 的幂次。位操作会在右边用零填充。

- 语法如下：
    ```assembly
    lsl dest_reg, src_reg, shift_amount
    ```
    - `dest_reg` 是目标寄存器，存储移位后的值。
    - `src_reg` 是源寄存器，存储要移位的值。
    - `shift_amount` 是移位的位数。

### lsr 逻辑右移（Logical Shift Right）

### mov 数据搬运
#### mov pc, lr  用于从子程序返回
#### mov r0, #0  用于将0传送到r0寄存器

### movs 搬运并设置条件码
- movs 是 ARM 汇编语言中的一条指令，用于将一个值从一个寄存器或立即数传送到另一个寄存器，并更新条件标志寄存器（CPSR）。movs 指令的全称是 "Move with Update Status"，它不仅执行数据搬运操作，还会根据结果更新条件标志寄存器中的标志位。
```asm
movs <Rd>, <operand2>
```
-  <Rd>：目标寄存器，用于存储传送的值。
-  <operand2>：要传送的值，可以是立即数、寄存器或寄存器移位后的值。
-   movs 指令将 <operand2> 的值搬运到 <Rd> 寄存器中，并更新条件标志寄存器（CPSR）。更新的标志位包括 ：
    - N（负标志）：如果结果为负数，则设置该标志。
    - Z（零标志）：如果结果为零，则设置该标志。
    - C（进位标志）：如果操作产生了进位，则设置该标志。
    - V（溢出标志）：如果操作产生了溢出，则设置该标志。

## 数据加法指令
### add 加法

### adds 加法并设置条件码

## 数据减法指令

### rsb 反向减法
- rsb 指令用于执行反向减法运算。它的语法如下：
```assembly
rsb dest_reg, src_reg, operand2
```
- `dest_reg` 是目标寄存器，存储运算结果。
- `src_reg` 是源寄存器，存储被减数。
- `operand2` 是减数，可以是立即数、寄存器或寄存器移位后的值。
- 等效于 dest_reg = operand2 - src_reg

### subs 比较并减法
- subs 是 ARM 汇编语言中的一条指令，用于执行减法运算，并更新条件标志寄存器（CPSR）。subs 指令的全称是 "Subtract with Update Status"，它不仅执行减法运算，还会根据结果更新条件标志寄存器中的标志位。
    - N（负标志）：如果结果为负数，则设置该标志。
    - Z（零标志）：如果结果为零，则设置该标志。
    - C（进位标志）：如果没有发生借位，则设置该标志。
    - V（溢出标志）：如果发生溢出，则设置该标志。
```asm
subs <Rd>, <Rn>, <operand2>
```
- <Rd>：目标寄存器，用于存储运算结果。
- <Rn>：第一个操作数寄存器。
- <operand2>：第二个操作数，可以是立即数、寄存器或寄存器移位后的值。

## 数据加载指令
- ldmfd：用于从堆栈中加载多个寄存器的值，并递增基地址，常用于函数返回时恢复寄存器状态。
- ldm：用于从任意内存地址加载多个寄存器的值，适用于需要一次性加载多个寄存器的场景。
- ldr：用于从任意内存地址加载单个寄存器的值，适用于需要加载单个寄存器的场景。
- ldrbxx：用于从任意内存地址加载寄存器,并且根据条件码cond判断是否执行abort的标签
- ldmia：用于从任意内存地址加载多个寄存器的值，并递增基地址，适用于需要一次性加载多个寄存器的场景。

### ldr 从内存中加载数据
- 不带括号与带()括号的 ldr 指令用于加载立即数或符号地址到寄存器中。
```asm
ldr r1, =0x1000  // 将立即数 0x1000 加载到寄存器 r1 中
ldr r0, =CONFIG_TEXT_BASE  // 将 CONFIG_TEXT_BASE 的值加载到寄存器 r0 中
```

- 带[]括号的 ldr 指令用于从内存地址加载数据到寄存器中
```asm
ldr r1, =0x1000  // 将立即数 0x1000 加载到寄存器 r1 中
ldr r0, [r1]  // 将内存地址 0x1000 中的值加载到寄存器 r0 中
```
- 等效于 r0 = *[r1],将r1指向的内存地址的值加载到r0寄存器中

### ldm 从内存中加载多个寄存器的值
- ldm（Load Multiple）指令用于从内存中加载多个寄存器的内容。它的语法如下：
```assembly
ldm {address}, {registers}
```
- {address}：内存地址，可以是一个寄存器或寄存器加偏移量。
- {registers}：要加载的寄存器列表。

### ldmfd 从内存中加载多个寄存器的值 并且递增基地址
- ldmfd 是 ARM 汇编语言中的一条指令，表示 "Load Multiple Increment After"。它用于从内存中加载多个寄存器的值，并在加载之后递增基址寄存器的值。ldmfd 指令通常用于函数返回时恢复寄存器的状态，特别是在堆栈操作中。

### ldrbxx 指令
- cond 参数用于指定条件码，控制指令的执行条件。在 ARM 汇编语言中，条件码用于决定指令是否执行。

- cond = al,标识默认情况下无条件执行
```asm
	//加载ptr指针的值到reg寄存器中,并且根据条件码cond判断是否执行abort的标签
	.macro ldr1b ptr reg cond=al abort
	ldrb\cond\() \reg, [\ptr], #1
	.endm
```

- ldrne 指令用于在条件码为 ne 时从内存中加载数据到寄存器中。
- ldrcs 指令用于在条件码为 cs 时从内存中加载数据到寄存器中。

### ldmia 从内存中加载多个寄存器的值 并且递增基地址

## 数据存储指令
- str：用于将寄存器的值保存到内存中。
- stm：用于将多个寄存器的内容保存到内存中。
- stmdb：用于将多个寄存器的内容保存到内存中，并在保存之前递减基址寄存器的值。
- push：用于将多个寄存器的值保存到堆栈中。
- strbxx：用于将寄存器的值保存到内存中，并根据条件码 cond 判断是否执行 abort 的标签。

### str 保存数据到内存
- str 指令用于将寄存器的值保存到内存中。它的语法如下：
```assembly
str reg, [address]
```
- `reg` 是要保存到内存的寄存器。
- `address` 是内存地址，可以是一个寄存器或寄存器加偏移量。
- 等效于 *address = reg,将address指向的内存地址的值设置为reg寄存器的值

### stm 存储多个寄存器的值
- stm（Store Multiple）指令用于将多个寄存器的内容存储到内存中。它的语法如下：
```assembly
stm {address}, {registers}
```
- {address}：内存地址，可以是一个寄存器或寄存器加偏移量。
- {registers}：要存储的寄存器列表。

### stmdb 存储多个寄存器的值 并且递减基地址
- stmdb 是 ARM 汇编语言中的一条指令，表示 "Store Multiple Decrement Before"。它用于将多个寄存器的值存储到内存中，并在存储之前递减基址寄存器的值。stmdb 指令通常用于函数调用时保存寄存器的状态，特别是在堆栈操作中。
- 语法如下：
```assembly
stmdb base_reg!, {registers}
```
- `base_reg` 是基址寄存器，用于存储存储操作的起始地址。
- `!：` 表示更新基址寄存器的值。
- `registers` 是要存储的寄存器列表。

- 递减堆栈指针：sp 的值会根据寄存器列表中的寄存器数量递减。例如，如果有 4 个寄存器要存储，sp 会递减 16（每个寄存器占用 4 字节）。

#### push 压入堆栈
- ` push {r4, lr}` 将r4和lr寄存器的值压入堆栈;这通常用于在函数调用时保存寄存器的值，以便在函数返回时恢复。
- 在 ARM 汇编语言中，push 是一个伪指令（pseudo-instruction），因为它并不是处理器本身直接支持的原生指令，而是汇编器提供的一种简化写法，用于提高代码的可读性和编写效率。伪指令通常会被汇编器转换为一个或多个实际的机器指令。
- push 伪指令用于将一个或多个寄存器的值保存到堆栈中。它实际上是 stmdb sp!, {register_list} 指令的简写形式。

### strbxx 保存寄存器到内存并且根据条件码cond判断是否执行abort的标签

## 跳转指令
### bl 调用子程序
- bl 指令用于调用子程序。它的语法如下：
```assembly
bl subroutine
```
- `subroutine` 是要调用的子程序的名称。

### bx 跳转到寄存器中的地址
- bx 指令用于跳转到寄存器中的地址。它的语法如下：
```assembly
bx reg
```
- `reg` 是包含要跳转的地址的寄存器。

### ret 返回指令
- ret lr：这条指令用于将程序计数器（PC）设置为链接寄存器（LR）的值，从而返回到调用函数。ret 指令在 ARM 汇编语言中用于实现函数返回。

### reteq 条件相等返回
- 在 ARM 汇编语言中，ret 指令用于从函数返回，而 eq 是一个条件码，表示 "equal"（相等）。当条件码为 eq 时，指令仅在条件标志寄存器（CPSR）的零标志（Z）被设置时执行。零标志通常在上一次比较操作结果为零时被设置。
- reteq lr 指令的含义是：如果零标志被设置（即上一次比较操作结果为零），则从函数返回，并将程序计数器（PC）设置为链接寄存器（LR）的值。链接寄存器通常保存函数调用返回地址，因此这条指令会将程序控制权返回给调用函数。

## 条件比较指令
### 条件码:
- eq：等于（Zero flag set）
- ne：不等于（Zero flag clear）
- cs：进位设置（Carry flag set）
- cc：进位清除（Carry flag clear）
- mi：负数（Negative flag set）
- pl：非负数（Negative flag clear）
- al：无条件执行（Always）
- gt：大于（Greater Than）
- lt：小于（Less Than）
- ge：大于等于（Greater than or Equal）
- le：小于等于（Less than or Equal）
- hi：高于（Higher）
- ls：低于等于（Lower or Same）
- vs：溢出（Overflow flag set）
- vc：无溢出（Overflow flag clear）

### cmp 比较指令
- cmp 指令用于比较两个操作数的值。它的语法如下：
```assembly
cmp reg1, reg2
```
- `reg1` 和 `reg2` 是要比较的寄存器。

### bne 不相等跳转指令
- bne 指令在零标志未设置时执行跳转。零标志通常在上一次比较操作结果不为零时未设置
- 语法如下：
```assembly
bne label
```
- `label` 是要跳转的标签。

### beq 相等时跳转

### b 无条件分支
- b.w 用于指示宽分支指令
- b.条件码，用于指示条件分支指令

### blt 小于时跳转
- blt 指令用于在条件标志寄存器中的负标志（N）被设置时进行分支跳转。
```assembly
blt label
```

### bge 大于等于时跳转
- bge：这是 ARM 汇编语言中的一条条件分支指令，表示 "Branch if Greater or Equal"。它根据条件标志寄存器（CPSR）的负标志（N）和溢出标志（V）进行分支跳转。具体来说，当 N 和 V 相等时（即结果为正或零），指令会执行跳转

## 宏
### pld 预取数据
- pld 指令用于预取数据，提前将数据加载到高速缓存中，以加快后续的访问速度。pld 指令的全称是 "Preload Data"，它可以用于预取内存中的数据，以减少访问延迟。
- 语法如下：
    ```assembly
    pld [address]
    ```
    - `address` 是要预取数据的内存地址。
- arch/arm/include/asm/assembler.h
    ```asm
    // 定义 PLD 宏，用于根据 CPU 架构选择是否启用 pld 指令
    #if defined(__ARM_ARCH_5E__) || defined(__ARM_ARCH_5TE__) || \
        defined(__ARM_ARCH_6__) || defined(__ARM_ARCH_6J__) || \
        defined(__ARM_ARCH_6T2__) || defined(__ARM_ARCH_6Z__) || \
        defined(__ARM_ARCH_6ZK__) || defined(__ARM_ARCH_7A__) || \
        defined(__ARM_ARCH_7R__)
    #define PLD(code...)	code
    #else
    #define PLD(code...)
    #endif
    ```

### CALGN 对齐
```asm
/*
 * Cache aligned, used for optimized memcpy/memset
 * In the kernel this is only enabled for Feroceon CPU's...
 * We disable it especially for Thumb builds since those instructions
 * are not made in a Thumb ready way...
 */
#if CONFIG_IS_ENABLED(SYS_THUMB_BUILD)
#define CALGN(code...)
#else
#define CALGN(code...) code
#endif
```

### retxx 条件返回
/*
 * Use 'bx lr' everywhere except ARMv4 (without 'T') where only 'mov pc, lr'
 * works
 */
	.irp	c,,eq,ne,cs,cc,mi,pl,vs,vc,hi,ls,ge,lt,gt,le,hs,lo
	.macro	ret\c, reg

	/* ARMv4- don't know bx lr but the assembler fails to see that */
#ifdef __ARM_ARCH_4__
	mov\c	pc, \reg
#else
	.ifeqs	"\reg", "lr"
	bx\c	\reg
	.else
	mov\c	pc, \reg
	.endif
#endif
	.endm
	.endr