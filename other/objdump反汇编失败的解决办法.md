---
title: objdump反汇编失败的解决办法
date: 2025-10-03 11:00:03
categories:
  - uboot
  - other
tags:
  - uboot
  - other
---
![在这里插入图片描述](https://i-blog.csdnimg.cn/direct/04e777a8e38d49739fd37d4bcf1a180e.png)


# -m 显示添加目标架构
- 通常,objdump会自己识别目标架构;如果没有识别出来可以自行添加架构
# file命令查看.O文件的架构信息
- 查看后指定目标架构既可

# objdump -i 输出所支持的架构
- 用于选择-m 的参数要输入什么

# 交叉编译的使用
- 由于主机的objdump架构与编译目标的架构不同;
- 需要使用特定的objdump;
- 例如armv7m要使用arm-none-eabi-objdump 