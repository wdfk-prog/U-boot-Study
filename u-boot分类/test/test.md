---
title: test
date: 2025-10-03 09:44:27
categories:
  - uboot
  - u-boot分类
  - test
tags:
  - uboot
  - u-boot分类
  - test
---
[TOC]

# test
## test.h
### UNIT_TEST
```c
//在段中定义一个测试用例函数
#define UNIT_TEST(_name, _flags, _suite)				\
	ll_entry_declare(struct unit_test, _name, ut_ ## _suite) = {	\
		.file = __FILE__,					\
		.name = #_name,						\
		.flags = _flags,					\
		.func = _name,						\
	}
```

## ut.c
- 单元测试相关函数
- 参考Unity测试框架,不在分析