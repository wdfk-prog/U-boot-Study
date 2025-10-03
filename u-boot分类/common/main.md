---
title: main
categories:
  - uboot
  - u-boot分类
  - common
tags:
  - uboot
  - u-boot分类
  - common
abbrlink: bf28cd64
date: 2025-10-03 09:44:27
---
# main.c

```c
/* We come here after U-Boot is initialised and ready to process commands */
void main_loop(void)
{
  const char *s;
  bootstage_mark_name(BOOTSTAGE_ID_MAIN_LOOP, "main_loop");

  cli_init();
  s = bootdelay_process();   //获取启动延迟时间 

  //从FDT中获取命令行参数
  if (cli_process_fdt(&s))
​    //设置了bootsecure执行;
​    //不使用命令行,避免被攻击
​    cli_secure_boot_cmd(s);

  //自动启动命令
  autoboot_command(s);
  //命令行循环
  cli_loop();
  panic("No CLI available");
}
```