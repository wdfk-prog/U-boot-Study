---
title: ubantu st-link 调试
date: 2025-10-03 10:58:55
categories:
  - uboot
  - other
tags:
  - uboot
  - other
---
@[toc]
![在这里插入图片描述](https://i-blog.csdnimg.cn/direct/f30d799e42a24aa4b52ba15cb20ba689.png)

# Linux如何安装/卸载.deb文件
> https://blog.csdn.net/vuipp/article/details/126031945
 - 安装.deb 只要输入“sudo dpkg -i 文件名”就可以了
# Ubuntu中gcc-arm-none-eabi的安装
> https://blog.csdn.net/qq_20016593/article/details/125343260
## 手动安装(推荐)
（1）官网下载：https://developer.arm.com/downloads/-/gnu-rm

```sh
pushd .
tar -jxf gcc-arm-none-eabi-6-2017-q2-update-linux.tar.bz2
sudo mv gcc-arm-none-eabi-6-2017-q2-update /opt
exportline="export PATH=/opt/gcc-arm-none-eabi-6-2017-q2-update/bin:\$PATH"
if grep -Fxq "$exportline" ~/.profile; then echo nothing to do ; else echo $exportline >> ~/.profile; fi
source ~/.profile
popd
```
- 检查交叉编译器是否安装成功
```sh
arm-none-eabi-gcc -v
```

# 设置arm-noneeabi-gdb
>https://askubuntu.com/questions/1243252/how-to-install-arm-none-eabi-gdb-on-ubuntu-20-04-lts-focal-fossa

```c
sudo ln -s /usr/share/gcc-arm-none-eabi-YOUR-VERSION/bin/arm-none-eabi-gcc /usr/bin/arm-none-eabi-gcc 
sudo ln -s /usr/share/gcc-arm-none-eabi-YOUR-VERSION/bin/arm-none-eabi-g++ /usr/bin/arm-none-eabi-g++
sudo ln -s /usr/share/gcc-arm-none-eabi-YOUR-VERSION/bin/arm-none-eabi-gdb /usr/bin/arm-none-eabi-gdb
sudo ln -s /usr/share/gcc-arm-none-eabi-YOUR-VERSION/bin/arm-none-eabi-size /usr/bin/arm-none-eabi-size
sudo ln -s /usr/share/gcc-arm-none-eabi-YOUR-VERSION/bin/arm-none-eabi-objcopy /usr/bin/arm-none-eabi-objcopy
```
# st-link 安装
> https://github.com/stlink-org/stlink/releases
- 根据日期选择适合自己版本的进行安装.

# 安装openocd
0. 安装依赖
```sh
sudo apt-get install build-essential pkg-config autoconf automake libtool libusb-dev libusb-1.0-0-dev libhidapi-dev
 
sudo apt-get install libtool libsysfs-dev
```

1. 克隆openocd 0.12.0源码
```sh
git clone git@github.com:openocd-org/openocd.git
```
2. 进入openocd目录：
```
cd openocd
```
3. git 子模块更新
```sh
git submodule init
git submodule update
```
4. 修改文件夹权限
```sh
sudo chmod -R +x openocd/
```
5. 修改换行符为LF
```sh
sudo apt-get install dos2unix
find /home/embedsky/share/openocd -type f -exec dos2unix {} \;
```
6. 运行编译脚本
```sh
sudo ./bootstrap
```
7. 进入jimtcl编译安装jimtcl
```sh
cd jimtcl/
sudo ./configure
make
sudo make install
```
8. 回到openocd根目录下执行
```sh
sudo ./configure
```
- 具有如下命令则编译成功
```sh
config.status: executing libtool commands


OpenOCD configuration summary
--------------------------------------------------
MPSSE mode of FTDI based devices        yes (auto)
ST-Link Programmer                      yes (auto)
TI ICDI JTAG Programmer                 yes (auto)
Keil ULINK JTAG Programmer              yes (auto)
ANGIE Adapter                           yes (auto)
Altera USB-Blaster II Compatible        yes (auto)
Bitbang mode of FT232R based devices    yes (auto)
Versaloon-Link JTAG Programmer          yes (auto)
TI XDS110 Debug Probe                   yes (auto)
CMSIS-DAP v2 Compliant Debugger         yes (auto)
OSBDM (JTAG only) Programmer            yes (auto)
eStick/opendous JTAG Programmer         yes (auto)
Olimex ARM-JTAG-EW Programmer           yes (auto)
Raisonance RLink JTAG Programmer        yes (auto)
USBProg JTAG Programmer                 yes (auto)
Espressif JTAG Programmer               yes (auto)
CMSIS-DAP Compliant Debugger            yes (auto)
Nu-Link Programmer                      yes (auto)
Cypress KitProg Programmer              yes (auto)
Altera USB-Blaster Compatible           no
ASIX Presto Adapter                     no
OpenJTAG Adapter                        no
Linux GPIO bitbang through libgpiod     no
SEGGER J-Link Programmer                no
Xilinx XVC/PCIe                         yes (auto)
Bus Pirate                              yes (auto)
Linux spidev driver                     yes (auto)
Dummy Adapter                           yes (auto)
Use Capstone disassembly framework      no
Collect coverage using gcov             no
```

- 验证版本
```sh
openocd --version
```
- 执行开启GDB服务器
```sh
st-info --probe# 查看接入的st-link版本信息
```
- `target/stm32f4x.cfg`选择目标芯片适配的文件
```sh
sudo openocd -f /usr/local/share/openocd/scripts/interface/stlink.cfg -f /usr/local/share/openocd/scripts/target/stm32h7x.cfg
```
- 使用 telnet 登录到这个服务器
```sh
telnet localhost 4444
```
输入 halt 命令，芯片停止运行。

```sh
halt
```
输入 reset 命令，芯片复位重启。
```sh
reset
```

# vscode 单步调试
> https://club.rt-thread.org/ask/question/9ae9f889db643afc.html

- 编辑 tasks.json 文件，添加如下三个任务：
	1. openocd server：用于开启 openocd GDB 服务器。
	2. rebuild：用于重新编译工程。
	3. build：用于编译工程。
```json
{
    // See https://go.microsoft.com/fwlink/?LinkId=733558
    // for the documentation about the tasks.json format
    "version": "2.0.0",
    "tasks": [
        {
            "label": "openocd stlink h7",
            "type": "shell",
            "command": "sudo openocd -f /usr/local/share/openocd/scripts/interface/stlink.cfg -f /usr/local/share/openocd/scripts/target/stm32h7x.cfg && exit"
        },
        {
            "label": "scons",
            "type": "shell",
            "command": "scons -c && scons -j4 && exit",
            "problemMatcher": []
        },
        {
            "label": "telnet localhost 4444",
            "type": "shell",
            "command": "telnet localhost 4444 && exit"
        }
    ]
}
```

- launch.json 文件内容如下：
```json
{
    // 使用 IntelliSense 了解相关属性。
    // 悬停以查看现有属性的描述。
    // 欲了解更多信息，请访问: https://go.microsoft.com/fwlink/?linkid=830387
    "version": "0.2.0",
    "configurations": [
        {
            "name": "debug Launch",
            "type": "cppdbg",
            "request": "launch",
            "targetArchitecture": "arm",
            "program": "stm32",
            "args": [""],
            "stopAtEntry": true,
            "cwd": "${workspaceFolder}",
            "environment": [],
            "externalConsole": true,
            "MIMode": "gdb",
            "miDebuggerPath": "/opt/gcc-arm-none-eabi-10.3-2021.10/bin/arm-none-eabi-gdb",
            "setupCommands": [
                {
                    "description": "Enable pretty-printing for gdb",
                    "text": "-enable-pretty-printing",
                    "ignoreFailures": true
                }
            ],
            "launchCompleteCommand": "None",
            "miDebuggerServerAddress": "localhost:3333",
            "customLaunchSetupCommands": [
                {
                    "text": "target remote :3333",
                    "description": "connect to server",
                    "ignoreFailures": false
                },
                {
                    "text": "file /home/embedsky/share/u-boot/u-boot.elf",
                    "description": "load file to gdb",
                    "ignoreFailures": false
                },
                {
                    "text": "load",
                    "description": "download file to MCU",
                    "ignoreFailures": false
                },
                {
                    "text": "monitor reset",
                    "description": "reset MCU",
                    "ignoreFailures": false
                },
                {
                    "text": "b main",
                    "description": "set breakpoints at main",
                    "ignoreFailures": false
                }
            ]
        }
    ]
}
```

# 问题排查
1. Error: couldn't bind tcl to socket on port 6666: Address already in use
服务器未关闭,查找线程并杀除
```sh
netstat -tulpn | grep 6666
$ tcp        0      0 127.0.0.1:6666          0.0.0.0:*               LISTEN      65776/openocd 
kill 65776#PID号

# 或者
killall -9 openocd 
```

2. auto-selecting first available session transport "dapdirect_swd". To override use 'transport select <transport>'.Error: open failed
- 没有接入st-link,接入后尝试
- 先用`st-info --probe`确保正常连接
