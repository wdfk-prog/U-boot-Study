## 设置编译引导加载程序
### VPL（Very Early Program Loader）

* **功能** ：VPL 是 U-Boot 的非常早期引导加载程序，通常用于在极其受限的环境中进行最基本的硬件初始化。
* **位置** ：VPL 通常位于存储设备的固定位置，类似于 SPL 和 TPL。
* **作用** ：VPL 的主要任务是加载并执行 TPL，以便进一步初始化系统并准备加载 SPL。

### SPL（Secondary Program Loader）

* **功能** ：SPL 是 U-Boot 的第二阶段引导加载程序，通常用于初始化基本的硬件资源，如内存控制器、时钟和电源管理等。
* **位置** ：SPL 通常位于存储设备的固定位置，如 NAND、NOR 闪存或 SD 卡的特定扇区。
* **作用** ：SPL 的主要任务是加载并执行 U-Boot 的主引导加载程序（即 U-Boot 本身），以便进一步初始化系统并启动操作系统。

### TPL（Tertiary Program Loader）

* **功能** ：TPL 是 U-Boot 的第三阶段引导加载程序，通常用于在资源受限的环境中进一步初始化硬件资源。
* **位置** ：TPL 通常位于存储设备的固定位置，类似于 SPL。
* **作用** ：TPL 的主要任务是加载并执行 SPL，以便进一步初始化系统并准备加载 U-Boot 主引导加载程序。

## 设置系统栈指针地址与长度
```c
CONFIG_HAS_CUSTOM_SYS_INIT_SP_ADDR=y
CONFIG_CUSTOM_SYS_INIT_SP_ADDR=0x24040000
CONFIG_ENV_SIZE=0x2000

#define CONFIG_SYS_MALLOC_F 1
#define CONFIG_SYS_MALLOC_F_LEN 0x2000
#define CONFIG_CUSTOM_SYS_INIT_SP_ADDR 0x24040000
```

## 事件功能 CONFIG_EVENT
### EVENT_DEBUG
### EVENT_DYNAMIC

## printf功能
```c
CONFIG_SYS_PBSIZE=282

#define CONFIG_PRINTF 1
#define CONFIG_SYS_PBSIZE 282
```

## 日志功能
```c
CONFIG_LOG=y
CONFIG_LOG_ERROR_RETURN=y
```

## 设备树
```c
CONFIG_OF_CONTROL=y
```
### OFNODE_MULTI_TREE 多设备树

### CONFIG_BLOBLIST 二进制设备树

### CONFIG_OF_LIVE 动态设备树

### CONFIG_OF_REAL 设备树

### CONFIG_OF_PLATDATA_INST 

### OF_PLATDATA_DRIVER_RT 

### OF_PLATDATA_RT 

### DM_SEQ_ALIAS  设备别名

## LIBCOMMON_SUPPORT 通用库支持

## CONFIG_TRACE_EARLY 提前跟踪

## CONFIG_DM_EVENT 驱动事件支持

## CONFIG_SYSINFO 系统信息

## CONFIG_MACH_TYPE
- 机器类型是一个唯一的标识符，用于区分不同的硬件平台。每个硬件平台都有一个唯一的机器类型编号，这个编号在 U-Boot 和 Linux 内核中用于识别和初始化特定的硬件平台。

## CONFIG_SYS_XTRACE
- 启用详细的跟踪信息输出

## CONFIG_CMD_BOOTD
- 当这个宏被定义时，表示在编译 U-Boot 时将包含 bootd 命令的实现。如果这个宏未被定义，则 bootd 命令的相关代码将不会被编译，从而减小 U-Boot 的体积。
- bootd 命令在 U-Boot 中用于启动默认的引导过程。它通常会从环境变量中读取引导配置，并根据这些配置启动操作系统或其他引导目标。以下是一个典型的 bootd 命令的使用示例：