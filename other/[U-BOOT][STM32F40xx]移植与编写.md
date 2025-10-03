---
title: '[U-BOOT][STM32F40xx]移植与编写'
categories:
  - uboot
  - other
tags:
  - uboot
  - other
abbrlink: 933f970e
date: 2025-10-03 10:56:17
---
@[toc]
![在这里插入图片描述](https://i-blog.csdnimg.cn/direct/9930b1592746424484928bf47a510966.png)

> https://github.com/wdfk-prog/u-boot/tree/f4debug

# 参考
1. 参考uboot现有支持板子与芯片型号
```c
├── common
├── stih410-b2260
├── stm32f429-discovery
├── stm32f429-evaluation
├── stm32f469-discovery
├── stm32f746-disco
├── stm32h743-disco
├── stm32h743-eval
├── stm32h750-art-pi
├── stm32mp1
└── stm32mp2
```
2. 使用`stm32f429-discovery`作为模板配置使用

# 编译与修改
1. 编译
```sh
export CROSS_COMPILE=arm-none-eabi- ARCH=arm;make configs/stm32f429-discovery_defconfig
make -j12
```

2. 将编译后的.bin文件烧录到指定地址`CONFIG_TEXT_BASE=0x08000000`

3. 这个时候是看不到任何现象的,接入j-linkg debug排查

4. 参考如下commit修改.具体问题为u-boot仅支持stm32f429的RCC时钟配置,这个对于STM32F40X系统来说不适配
> https://github.com/wdfk-prog/u-boot/commit/b538e14c98ecc6534059da494eb4a9c6ce53cf4f
- F42X最高支持180Mhz系统时钟频率,而F40X仅到168MHZ.所以RCC驱动需要修改支持适配F40x系列
- 另外寄存器`regs->cr`的第28位`RCC_CR_PLLSAIRDY`在F40X中没有存在
- 这样串口就可以看到打印信息了,默认是串口1PA9 PA10哦.需要的自行修改dts

5. `使用内部ram作为内存`这一个可以不需要修改.如果有带着SRAM的支持的话,可以使用SRAM进行重定向既可.
- 我这里尝试使用自带RAM执行代码,没法正常运行
> https://github.com/wdfk-prog/u-boot/commit/7fee88894f5e59fca3192fb40f968e6c00dd6e72