---
title: Bison_Flex
categories:
  - uboot
  - 子目录
tags:
  - uboot
  - 子目录
abbrlink: e77f4712
date: 2025-10-03 09:44:27
---
[TOC]

# Flex（Fast Lexical Analyzer Generator） 于生成词法分析器的工具

- 词法分析器用于将输入文本分解成标记（tokens），这些标记是语法分析器（如由 Bison 生成的解析器）所使用的基本单位。Flex 是 Lex 的一个改进版本，广泛用于编译器和解释器的开发中。

## Flex 的作用

1. **生成词法分析器** ：

* Flex 从一个词法规则文件（通常以 `.l` 为扩展名）生成一个 C 语言的词法分析器源代码文件（通常是 `lex.yy.c`）。
* 词法分析器读取输入文本，并根据定义的词法规则将其分解成标记。

2. **处理输入文本** ：

* 词法分析器扫描输入文本，识别出符合词法规则的模式，并将其转换为标记。
* 每个标记可以包含类型和语义值，供语法分析器使用。

## Flex 文件的格式

- Flex 文件通常以 `.l` 为扩展名，包含词法规则和动作代码。以下是一个典型的 Flex 文件的结构：

Bison 是一个广泛使用的解析器生成器工具，用于从上下文无关文法（Context-Free Grammar，CFG）生成语法解析器。它通常用于编译器和解释器的开发中，用来解析编程语言的语法。Bison 是 GNU 项目的一部分，是 Yacc（Yet Another Compiler Compiler）的一个兼容实现。

# Bison 生成解析器 处理复杂语法 错误检测和恢复

1. **生成解析器**：
   - Bison 从一个描述语言语法的文法文件（通常以 `.y` 为扩展名）生成一个 C 或 C++ 语言的解析器。
   - 解析器可以读取输入（如源代码文件），并根据定义的语法规则解析输入，构建语法树或执行相应的动作。
2. **处理复杂语法**：
   - Bison 可以处理复杂的上下文无关文法，支持递归、嵌套和多种操作符优先级。
   - 它允许用户定义语法规则和关联的动作代码，以便在解析过程中执行特定操作。
3. **错误检测和恢复**：
   - Bison 生成的解析器能够检测语法错误，并提供错误恢复机制，以便继续解析后续输入。

### Bison 文件的格式

Bison 文件通常以 `.y` 为扩展名，包含语法规则和动作代码。以下是一个典型的 Bison 文件的结构：

# 自动生成

## `yylex` 词法分析函数，用于从输入中提取标记（tokens)

* **作用** ：`yylex` 是词法分析函数，用于从输入中提取标记（tokens）。
* **生成规则** ：`yylex` 函数通常由 Flex 或手写的词法分析器提供。Bison 依赖 `yylex` 函数来获取下一个标记。

## yyparse 用于解析输入并执行相应的语法规则和动作代码

### `yyparse` 函数的作用

1. **解析输入**：

   - `yyparse` 函数是由 Bison 根据定义的语法规则生成的解析器函数。
   - 它读取输入（通常是从文件或标准输入），并根据语法规则解析输入。
2. **执行动作代码**：

   - 在解析过程中，`yyparse` 函数会根据匹配的语法规则执行相应的动作代码。
   - 动作代码通常用于构建语法树、计算表达式、执行命令等。
3. **错误处理**：

   - `yyparse` 函数还负责处理语法错误，并调用错误处理函数（如 `yyerror`）输出错误信息。

## `yyerror`

* **作用** ：`yyerror` 是错误处理函数，用于在解析过程中报告语法错误。
* **生成规则** ：`yyerror` 函数通常由用户在 `.y` 文件中定义。Bison 在遇到语法错误时会调用 `yyerror` 函数

## `YYDEBUG`

* **作用** ：`YYDEBUG` 是一个宏，用于启用解析器的调试输出。
* **生成规则** ：`YYDEBUG` 宏在 Bison 生成的解析器代码中定义。用户可以在编译时定义 `YYDEBUG=1` 来启用调试输出。

## `yylval`

* **作用** ：`yylval` 是一个全局变量，用于存储当前标记的语义值。
* **生成规则** ：`yylval` 变量在 Bison 生成的解析器代码中定义。词法分析器通过设置 `yylval` 来传递标记的语义值。

## `yychar`

* **作用** ：`yychar` 是一个全局变量，用于存储当前标记的类型。
* **生成规则** ：`yychar` 变量在 Bison 生成的解析器代码中定义。解析器通过检查 `yychar` 来确定当前标记的类型。

## `yylloc`

* **作用** ：`yylloc` 是一个全局变量，用于存储当前标记的位置信息。
* **生成规则** ：`yylloc` 变量在 Bison 生成的解析器代码中定义。词法分析器通过设置 `yylloc` 来传递标记的位置信息。


# 示例

- scripts/kconfig/zconf.y中修改开启调试输出
```c
//开头添加
#define YYDEBUG 1

void conf_parse(const char *name)
{
    struct symbol *sym;
    int i;

    zconf_initscan(name);

    _menu_init();
    // 注释此处开启调试输出
    // if (getenv("ZCONF_DEBUG"))
        yydebug = 1;
    yyparse();
}
```

- 执行命令 生成解析器 执行配置操作输出日志到[Bisonoutput.log](./分析文件/Bisonoutput.log)
```shell
bison -d zconf.y
make CROSS_COMPILE=arm-none-eabi- ARCH=arm stm32h750-art-pi_defconfig > output.log 2>&1
```
