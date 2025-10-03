---
title: export
categories:
  - uboot
  - u-boot分类
  - common
tags:
  - uboot
  - u-boot分类
  - common
abbrlink: 428c1694
date: 2025-10-03 09:44:27
---
# exports.c

### jumptable_init
- malloc分配jt_funcs结构体,并将函数指针赋值给jt_funcs结构体
- jt_funcs结构体中的函数指针是在_exports.h中定义的
- 这些函数在u-boot中是代码段中的函数,在u-boot中是通过函数指针调用的
- jt跳转表包含指向导出函数的指针。指向跳转表将传递给独立应用程序。
```c
EXPORT_FUNC(get_version, unsigned long, get_version, void)
EXPORT_FUNC(getchar, int, getc, void)
EXPORT_FUNC(tstc, int, tstc, void)
EXPORT_FUNC(putc, void, putc, const char)
EXPORT_FUNC(puts, void, puts, const char *)

struct jt_funcs {
#define EXPORT_FUNC(impl, res, func, ...) res(*func)(__VA_ARGS__);
#include <_exports.h>
#undef EXPORT_FUNC
};

#define EXPORT_FUNC(f, a, x, ...)  gd->jt->x = f;

int jumptable_init(void)
{
    gd->jt = malloc(sizeof(struct jt_funcs));
#include <_exports.h>

    return 0;
}
```