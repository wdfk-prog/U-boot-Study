---
title: linker_list
date: 2025-10-03 09:44:27
categories:
  - uboot
  - u-boot分类
  - include
tags:
  - uboot
  - u-boot分类
  - include
---
# linker_lists.h

- [linker_lists api手册](https://docs.u-boot.org/en/stable/api/linker_lists.html)

```c
// 声明一个链接生成的条目,以__u_boot_list_2_XXX_2_YYY命名
#define ll_entry_declare(_type, _name, _list)				\
	_type _u_boot_list_2_##_list##_2_##_name __aligned(4)		\
			__attribute__((unused))				\
			__section("__u_boot_list_2_"#_list"_2_"#_name)

// 声明一个链接生成的列表,以__u_boot_list_2_XXX_2_YYY命名,但是是一个数组
#define ll_entry_declare_list(_type, _name, _list)			\
	_type _u_boot_list_2_##_list##_2_##_name[] __aligned(4)		\
			__attribute__((unused))				\
			__section("__u_boot_list_2_"#_list"_2_"#_name) 
// 声明一个段的开头,以__u_boot_list_2_XXX_1命名
#define ll_entry_start(_type, _list)					\
({									\
	static char start[0] __aligned(CONFIG_LINKER_LIST_ALIGN)	\
		__attribute__((unused))					\
		__section("__u_boot_list_2_"#_list"_1");			\
	_type * tmp = (_type *)&start;					\
	asm("":"+r"(tmp));						\
	tmp;								\
})
// 声明一个段的结尾,以__u_boot_list_2_XXX_3命名
#define ll_entry_end(_type, _list)					\
({									\
	static char end[0] __aligned(4) __attribute__((unused))		\
		__section("__u_boot_list_2_"#_list"_3");			\
	_type * tmp = (_type *)&end;					\
	asm("":"+r"(tmp));						\
	tmp;								\
})
// 计算段的数量
#define ll_entry_count(_type, _list)					\
	({								\
		_type *start = ll_entry_start(_type, _list);		\
		_type *end = ll_entry_end(_type, _list);		\
		unsigned int _ll_result = end - start;			\
		_ll_result;						\
	})
```
