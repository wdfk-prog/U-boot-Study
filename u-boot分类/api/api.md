[TOC]

# 介绍
用于外部应用程序的 U-Boot 机器/独立于架构的 API

1. 主要假设

- API 只有一个入口点 （syscall）

- 根据当前的设计，syscall 是 U-Boot 中的 C 语言可调用函数text，它可能会演变成一个真正的 syscall using machine exception 陷阱,一旦此初始版本证明有效

- 使用者应用程序负责生成适当的上下文（调用 number 和参数）

- 进入后，系统调用将调用分派给其他（现有的）U-Boot功能区域，如网络或存储操作

- 消费者应用程序将通过搜索来识别 API 可用指定的（按照约定假定的）地址空间范围签名

- API 的 U-Boot 组成部分是精简且非侵入性的，将尽可能多的处理留给消费者应用程序端，例如，它不保留状态，而是依赖于来自应用程序的提示，并且以此类推

- 可选 （CONFIG_API）

2. 调用

- 控制台相关（GETC、PUTC、TSTC 等）
  - 系统（重置、平台信息）
  - 时间 （delay， current）
  - env vars （枚举所有、get、set）
  - 设备 （枚举所有、打开、关闭、读取、写入）;目前有两个等级的设备得到识别和支持：网络和存储（IDE、SCSI、USB 等）

3. 结构概述

- 核心 API，U-Boot 的组成部分，强制性
    - 实现单一入口点（模拟 UNIX 系统调用）

-胶
    - 消费者端的入口点，允许将 syscall 强制部分

- 辅助程序便捷包装器，以便使用者应用程序不必使用sys调用，但以更友好的方式（如 libc 调用）可选部件

- 消费者应用程序
    - 直接调用，或利用提供的 Glue 中间层

# api.c
## api_init
- 在common/board_r.c中调用,需要在`CONFIG_API`宏定义的情况下才会调用
```c
int api_init(void)
{
	struct api_signature *sig;

	debugf("API initialized with %d calls\n", calls_no);

	dev_stor_init();

	/*
	 * 生成签名，以便 API 使用者可以找到它
	 */
	sig = malloc(sizeof(struct api_signature));
	env_set_hex("api_address", (unsigned long)sig);
	memcpy(sig->magic, API_SIG_MAGIC, 8);
	sig->version = API_SIG_VERSION;
	sig->syscall = &syscall;
	sig->checksum = 0;
	sig->checksum = crc32(0, (unsigned char *)sig,
}
```

## syscall
```c
//call:调用号 retval:返回值 ap:参数列表
//成功返回1,失败返回0
int syscall(int call, int *retval, ...)
{
	va_list	ap;
	int rv;

	if (call < 0 || call >= calls_no) {
		debugf("invalid call #%d\n", call);
		return 0;
	}

	if (calls_table[call] == NULL) {
		debugf("syscall #%d does not have a handler\n", call);
		return 0;
	}
    //通过va_start获取参数
	va_start(ap, retval);
	rv = calls_table[call](ap);
	if (retval != NULL)
		*retval = rv;

	return 1;
}
```

## API_PUTC
```c
static int API_putc(va_list ap)
{
	char *c;
    //va_arg接收两个参数：一个是 va_list 类型的参数列表 ap,另一个是要获取的参数的类型
	if ((c = (char *)va_arg(ap, uintptr_t)) == NULL)
		return API_EINVAL;

	putc(*c);
	return 0;
}
```

## API_GET_SYS_INFO
- 通过`platform_set_mr`获取内存空间
- api/api_platform.c platform_sys_info

## API_DEV_ENUM 枚举网络设备和存储设备
```c
static int API_dev_enum(va_list ap)
{
	struct device_info *di;

	/* arg is ptr to the device_info struct we are going to fill out */
	di = (struct device_info *)va_arg(ap, uintptr_t);
	if (di == NULL)
		return API_EINVAL;

	if (di->cookie == NULL) {
		/* start over - clean up enumeration */
		dev_enum_reset();	/* XXX shouldn't the name contain 'stor'? */
		debugf("RESTART ENUM\n");

		/* net device enumeration first */
		if (dev_enum_net(di))
			return 0;
	}

	//除了网络设备外,还有存储设备
	if (!dev_enum_storage(di))
		di->cookie = NULL;

	return 0;
}
```

## API_ENV_ENUM
```c
//last:上一个环境变量的名字 next:下一个环境变量的名字
//返回0 还有环境变量,返回其他值没有环境变量,返回个数
static int API_env_enum(va_list ap)
```

# api_storage.c
## dev_enum_stor
```c
static int dev_enum_stor(int type, struct device_info *di)
{
	int found = 0, more = 0;

	if (di->cookie == NULL) {
		debugf("group%d - enum restart\n", type);

		//找到第一个可用的设备
		found = dev_stor_get(type, &more, di);
		specs[type].enum_started = 1;

	} else if (dev_is_stor(type, di)) {
		debugf("group%d - enum continued for the next device\n", type);

		if (specs[type].enum_ended) {
			debugf("group%d - nothing more to enum!\n", type);
			return 0;
		}

		/* 2a. Attempt to take a next available device in the group */
		found = dev_stor_get(type, &more, di);

	} else {
		if (specs[type].enum_ended) {
			debugf("group %d - already enumerated, skipping\n", type);
			return 0;
		}

		debugf("group%d - first time enum\n", type);

		if (specs[type].enum_started == 0) {
			/*
			 * 2b. 如果枚举此组中的设备没有
			 * 之前发生，则表示 cookie 指向
			 * 来自其他组（另一个存储）的设备
			 * 组或网络）;在这种情况下，请尝试将
			 * 我们集团的第一个可用设备
			 */
			specs[type].enum_started = 1;

			/*
			 * 尝试获取此组中的第一个设备：
			 *设置了“第一个元素”标志
			 */
			found = dev_stor_get(type, &more, di);
		} else {
            //乱序枚举
			errf("group%d - out of order iteration\n", type);
			found = 0;
			more = 0;
		}
	}

	/*
	 * 如果此组中没有更多设备，请考虑其枚举完成
	 */
	specs[type].enum_ended = (!more) ? 1 : 0;

	if (found)
		debugf("device found, returning cookie 0x%08x\n",
		       (u_int32_t)di->cookie);
	else
		debugf("no device found\n");

	return found;
}
```

## dev_stor_get 查找存储组中的下一个可用设备
```c
static int dev_stor_get(int type, int *more, struct device_info *di)
{
	struct blk_desc *dd;
	int found = 0;
	int found_last = 0;
	int i = 0;

	//api_init -> dev_stor_init -> specs[ENUM_MMC].name = "mmc";
    //跳过没有注册的设备
	if (specs[type].name == NULL)
		return 0;
    //cookie是设备的指针
	if (di->cookie != NULL) {
		// 找到上一次最后一个可用的设备
		for (i = 0; i < specs[type].max_dev; i++) {
			if (di->cookie ==
			    (void *)blk_get_dev(specs[type].name, i)) {
				i += 1;
				found_last = 1;
				break;
			}
		}

		if (!found_last)
			i = 0;
	}
    //找到下一个可用的设备
	for (; i < specs[type].max_dev; i++) {
		di->cookie = (void *)blk_get_dev(specs[type].name, i);

		if (di->cookie != NULL) {
			found = 1;
			break;
		}
	}
    //没有找到
	if (i == specs[type].max_dev)
		*more = 0;
	else    //找到
		*more = 1;
    //找到设备后,获取设备的信息
	if (found) {
		di->type = specs[type].type;

		dd = (struct blk_desc *)di->cookie;
		if (dd->type == DEV_TYPE_UNKNOWN) {
			debugf("device instance exists, but is not active..");
			found = 0;
		} else {
			di->di_stor.block_count = dd->lba;
			di->di_stor.block_size = dd->blksz;
		}
	} else {
		di->cookie = NULL;
	}

	return found;
}
```


## 其余API
- 直接看就完了,没什么好说的

# examples
- api/Kconfig中的配置有个`examples`,用于提供API的使用示例
- 根据`examples/api/Makefile`中可以看到会生成demo程序,可以在目标板上运行

## 执行流程
### examples/api/crt0.S
- 初始化`search_hint`为0,进入`main`函数
```asm
	.text
	.globl _start
_start:
	ldr	r0, =search_hint
	mov	r1, sp
	str	r1, [r0]
	b	main


	.globl syscall
syscall:
	ldr	r0, =syscall_ptr
	ldr	r0, [r0]
	bx	r0

.section .data

	.globl syscall_ptr
syscall_ptr:
	.align	8
	.long	0

	.globl search_hint
search_hint:
	.long	0
```

### main 
- examples/api/demo.c
- 通过`api_search_sig`函数搜索API的签名,所以直接运行这个demo程序是不会成功的
    ```c
        if (!api_search_sig(&sig))
            return -1;
    ```
    - 需要先有u-boot运行,并且配置了CONFIG_API,然后再运行这个demo程序
```c
int main(int argc, char *const argv[])
{
	int rv = 0, h, i, j, devs_no;
	struct api_signature *sig = NULL;
	ulong start, now;
	struct device_info *di;
	lbasize_t rlen;
	struct display_info disinfo;

	if (!api_search_sig(&sig))
		return -1;
    //sig->syscall = &syscall;
	syscall_ptr = sig->syscall; 
	if (syscall_ptr == NULL)
		return -2;

	if (sig->version > API_SIG_VERSION)
		return -3;

	/* console activities */
	ub_putc('B');

}
```

## examples/api/glue.c
### api_search_sig
- 通过`search_hint`来搜索API的签名
```c
int api_search_sig(struct api_signature **sig)
{
	unsigned char *sp;
	uintptr_t search_start = 0;
	uintptr_t search_end = 0;

	if (sig == NULL)
		return 0;

	if (search_hint == 0)
		search_hint = 255 * 1024 * 1024;

	search_start = search_hint & ~0x000fffff;   // 1M对齐
    //搜索到3MB的范围
	search_end = search_start + API_SEARCH_LEN - API_SIG_MAGLEN;

	sp = (unsigned char *)search_start;
	while ((sp + API_SIG_MAGLEN) < (unsigned char *)search_end) {
		if (!memcmp(sp, API_SIG_MAGIC, API_SIG_MAGLEN)) {
			*sig = (struct api_signature *)sp;
			if (valid_sig(*sig))    //crc32校验
				return 1;
		}
		sp += API_SIG_MAGLEN;
	}

	*sig = NULL;
	return 0;
}
```