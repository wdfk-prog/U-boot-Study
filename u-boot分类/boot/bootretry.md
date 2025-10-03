---
title: bootretry
date: 2025-10-03 09:44:27
categories:
  - uboot
  - u-boot分类
  - boot
tags:
  - uboot
  - u-boot分类
  - boot
---
[TOC]

# BOOT_RETRY
- 允许 U-Boot 命令提示符超时并尝试以再次启动。 如果找到环境变量 “bootretry”，则使用其值，否则重试超时为CONFIG_BOOT_RETRY_TIME。
- CONFIG_BOOT_RETRY_MIN 是可选的，并且默认为 CONFIG_BOOT_RETRY_TIME。所有时间均以秒为单位。
- 如果重试超时为负数，则 U-Boot 命令提示符永不超时。否则，它将被强制为至少CONFIG_BOOT_RETRY_MIN 秒。如果没有有效的 U-Boot 命令在指定时间之前输入，则引导延迟序列为重新启动。U-Boot 执行的每个命令都会重新启动超时。
- 如果CONFIG_BOOT_RETRY_TIME < 0，则该功能存在，但除非环境变量 “bootretry” >= 0，否则不会执行任何操作。

# bootretry_init_cmd_timeout
- 从env中获取`bootretry`的值,如果没有配置,则使用`CONFIG_BOOT_RETRY_TIME`的值
- 如果0 < `CONFIG_BOOT_RETRY_TIME` < `CONFIG_BOOT_RETRY_MIN`,则`CONFIG_BOOT_RETRY_TIME` = `CONFIG_BOOT_RETRY_MIN`

# bootretry_reset_cmd_timeout
- 每个命令获取的开始计算超时时间

# bootretry_tstc_timeout
- 阻塞检查是否有输入,阻塞时间为`CONFIG_BOOT_RETRY_TIME`秒

# bootretry_dont_retry
- 设置`CONFIG_BOOT_RETRY_TIME`为-1,即不再重试