---
title: uboot 调试
date: 2025-10-03 10:58:55
categories:
  - uboot
  - other
tags:
  - uboot
  - other
---
@[toc]
![在这里插入图片描述](https://i-blog.csdnimg.cn/direct/cb100da7e2b84e7eb5d3d40f419b1049.png)

# 成功debug
> https://blog.csdn.net/qq_39665253/article/details/145641929
# u-boot 配置
> https://docs.u-boot.org/en/latest/develop/gdb.html

```config
CONFIG_CC_OPTIMIZE_FOR_DEBUG=y
CONFIG_LTO=n
 CONFIG_LOG_MAX_LEVEL=9
```
- 重新编译.得到u-boot的elf文件(不带后缀就是),可以使用`file u-boot`确认

# ST-LINK debug失败
```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Stlink-Debug",
            "cwd": "${workspaceFolder}",
            "executable": "./u-boot.elf",
            "request": "launch",
            "type": "cortex-debug",
            "runToEntryPoint": "main",
            "interface": "swd",
            "device": "STM32H750XBH6",
            // "miDebuggerPath":"/opt/gcc-arm-none-eabi-10.3-2021.10/bin/arm-none-eabi-gdb",
            "svdFile": "./svd/STM32H750.svd",
            "showDevDebugOutput": "both",
            "v1": false,
            "liveWatch": {
                "enabled": true,
                "samplesPerSecond": 1
            },
            // 使用 stutil 作为 gdbserver
            "servertype": "stutil",
            "serverpath": "/usr/bin/st-util",
            /*"servertype": "openocd",
            "configFiles": [
                "/usr/share/openocd/scripts/interface/stlink-v2-1.cfg",
                "/usr/share/openocd/scripts/target/stm32f4x.cfg"
            ]*/
        }
    ]
}
```

- openocd
```c
{
    // Use IntelliSense to learn about possible attributes.
    // Hover to view descriptions of existing attributes.
    // For more information, visit: https://go.microsoft.com/fwlink/?linkid=830387
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Cortex Debug",
            "cwd": "${workspaceRoot}",
            "executable": "u-boot.elf",
            "request": "launch",
            "type": "cortex-debug",
            "servertype": "openocd",
            "configFiles": [
                "interface/stlink.cfg",
                "target/stm32h7x.cfg"
            ],
            "armToolchainPath": "/opt/gcc-arm-none-eabi-10.3-2021.10/bin",
            "svdFile": "STM32H750.svd",
            // "preLaunchTask": "Build"
        }
    ]
}
```

- debug报错原因:挂载在外部FLAS
- H上的,0x9000000地址的无法打断点暂停调试
> https://github.com/stlink-org/stlink/blob/testing/doc/tutorial.md

```md
e) Note on setting hardware breakpoints for external bus (Example: STM32H735-DK)
GDB is setting breakpoints based on the XML memory map designation of rom or ram, which is hardcoded in st-util for a given processor. However the external bus can be RAM or ROM depending on design.

The STM32H735-DK has external FLASH at address 0x90000000. As a result, because the entire external memory range is ram as it could be either, software breakpoints (Z0) get sent when a breakpoint is created and they never get tripped as the memory area is read only.
```

# JLINK debug
1. JLINK DEBUG STM32F4
2. 注意使用`"request": "attach",`避免烧录elf文件造成错误
```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "cortex-debug",
            "request": "attach",
            "name": "Debug (J-Link)",
            "cwd": "${workspaceRoot}",
            "servertype": "jlink",
            "device": "stm32f407vg",
            "interface": "swd",
            "serialNumber": "", //If you have more than one J-Link probe, add the serial number here.
            // "jlinkscript":"${workspaceRoot}/BSP/SEGGER/K66FN2M0_emPower/Setup/Kinetis_K66_Target.js",
            "armToolchainPath": "/usr/bin/",
            "svdFile": "STM32H750.svd",
            // "preLaunchTask": "Download",
            "runToEntryPoint": "_main",
            "executable": "u-boot",
            // "loadFiles": [
            //     "u-boot",
            // ],
            // "preLaunchCommands": [
            //     "add-symbol-file u-boot",
            // ],
        }
    ]
}

```