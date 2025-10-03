---
title: U-BOOT CLANGD使用 + 避坑注意事项
date: 2025-10-03 11:00:19
categories:
  - uboot
  - other
tags:
  - uboot
  - other
---

![在这里插入图片描述](https://i-blog.csdnimg.cn/direct/0ecdaa8b351f4ad0a119c5b2bf904483.png)


# 步骤1
- 参考如下教程操作;安装clangd + bear
> https://blog.csdn.net/oushaojun2/article/details/129877412

# 步骤2
- 使用方式,看版本
> bear make 
- 或者
> bear
>  -- make

# 注意事项

1. 出现 Unknown argument: '-mword-relocations'
	-  根目录新建.clangd文件,写入Remove的选项
```json
CompileFlags:                     # Tweak the parse settings
  Add: [-xc++, -Wall]             # treat all files as C++, enable more warnings
  Remove: -W*                     # strip all other warning-related flags
  Compiler: clang++               # Change argv[0] of compile flags to `clang++`
```
>   Remove: [-fstack-usage, -mthumb-interwork, -mword-relocations]

2. 如果提示已存在.clangd文件夹或文件
	-  clangd版本过低,所以生成的索引文件保存在了.cangd目录;并且无法使用.clangd配置文件进行剔除未知参数;
	- 根据官网操作 > https://clangd.llvm.org/installation
```
Installing the clangd package will usually give you a slightly older version.

Try to install a packaged release (12.0):

sudo apt-get install clangd-12
If that’s not found, at least clangd-9 or clangd-8 should be available. Versions before 8 were part of the clang-tools package.

This will install clangd as /usr/bin/clangd-12. Make it the default clangd:

sudo update-alternatives --install /usr/bin/clangd clangd /usr/bin/clangd-12 100
```
	- 就可以配置.clangd文件了
3. .clangd文件配置后还是无效
> clangd:restart language server

	- 重启clangd 重新生成既可
