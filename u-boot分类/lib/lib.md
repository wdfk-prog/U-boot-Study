---
title: lib
date: 2025-10-03 09:44:27
categories:
  - uboot
  - u-boot分类
  - lib
tags:
  - uboot
  - u-boot分类
  - lib
---
# initcall.c

## initcall_run_list 初始化调用列表

```c
int initcall_run_list(const init_fnc_t init_sequence[])
{
	ulong reloc_ofs;
	const init_fnc_t *ptr;
	enum event_t type;
	init_fnc_t func;
	int ret = 0;

	for (ptr = init_sequence; func = *ptr, func; ptr++) {
		reloc_ofs = calc_reloc_ofs();	//计算偏移
		type = initcall_is_event(func);	//判断是否是事件
		//执行函数 是事件执行事件通知函数,否则执行函数
		ret = type ? event_notify_null(type) : func();
		if (ret)
			break;
	}

	if (ret) {
		if (CONFIG_IS_ENABLED(EVENT)) {
			char buf[60];

			/* don't worry about buf size as we are dying here */
			if (type) {
				sprintf(buf, "event %d/%s", type,
					event_type_name(type));
			} else {
				sprintf(buf, "call %p",
					(char *)func - reloc_ofs);
			}

			printf("initcall failed at %s (err=%dE)\n", buf, ret);
		} else {
			printf("initcall failed at call %p (err=%d)\n",
			       (char *)func - reloc_ofs, ret);
		}

		return ret;
	}

	return 0;
}
```

## 事件声明

- 从.map中搜索 ` __u_boot_list_2_evspy_info`从 `_1`到 `_3`的段,并执行 `notify_static`函数

### boot/vbe_request.c

### boot/vbe_simple_os.c

## initcall_is_event 判断是否是事件

```c
#define INITCALL_IS_EVENT	GENMASK(BITS_PER_LONG - 1, 8)	//生成掩码从8到31都是1
#define INITCALL_EVENT_TYPE	GENMASK(7, 0)	//生成掩码从0到7都是1
//是事件返回事件类型,否则返回0
static int initcall_is_event(init_fnc_t func)
{
	ulong val = (ulong)func;

	if ((val & INITCALL_IS_EVENT) == INITCALL_IS_EVENT)
		return val & INITCALL_EVENT_TYPE;

	return 0;
}
```

# vsprintf.c

- vsnprintf_internal函数,用于格式化字符串
- 该文件内部自行实现了printf函数,并进行了对于u-boot的适配

## vprintf

- 需要配置CONFIG_PRINTF 和 CONFIG_SYS_PBSIZE

```c
#if CONFIG_IS_ENABLED(PRINTF)
int vprintf(const char *fmt, va_list args)
{
	uint i;
	char printbuffer[CONFIG_SYS_PBSIZE];

	/*
	 * For this to work, printbuffer must be larger than
	 * anything we ever want to print.
	 */
	i = vscnprintf(printbuffer, sizeof(printbuffer), fmt, args);

	/* Handle error */
	if (i <= 0)
		return i;
	/* Print the string */
	puts(printbuffer);
	return i;
}
#endif
```

# hang.c

```c
void hang(void)
{
#if !defined(CONFIG_XPL_BUILD) || \
		(CONFIG_IS_ENABLED(LIBCOMMON_SUPPORT) && \
		 CONFIG_IS_ENABLED(SERIAL))
	puts("### ERROR ### Please RESET the board ###\n");
#endif
	bootstage_error(BOOTSTAGE_ID_NEED_RESET);	//记录错误
	if (IS_ENABLED(CONFIG_SANDBOX))
		os_exit(1);
	for (;;)	//死循环
		;
}
```

# trace.c
```c
int notrace trace_early_init(void)
{
	int func_count = get_func_count();
	size_t buff_size = CONFIG_TRACE_EARLY_SIZE;
	size_t needed;

	if (func_count < 0)
		return func_count;
	/* We can ignore additional calls to this function */
	if (trace_enabled)
		return 0;

	hdr = map_sysmem(CONFIG_TRACE_EARLY_ADDR, CONFIG_TRACE_EARLY_SIZE);
	needed = sizeof(*hdr) + func_count * sizeof(uintptr_t);
	if (needed > buff_size) {
		printf("trace: buffer size is %zx bytes, at least %zx needed\n",
		       buff_size, needed);
		return -ENOSPC;
	}

	memset(hdr, '\0', needed);
	hdr->call_accum = (uintptr_t *)(hdr + 1);
	hdr->func_count = func_count;
	hdr->min_depth = INT_MAX;

	/* Use any remaining space for the timed function trace */
	hdr->ftrace = (struct trace_call *)((char *)hdr + needed);
	hdr->ftrace_size = (buff_size - needed) / sizeof(*hdr->ftrace);
	hdr->depth_limit = CONFIG_TRACE_EARLY_CALL_DEPTH_LIMIT;
	printf("trace: early enable at %08x\n", CONFIG_TRACE_EARLY_ADDR);

	trace_enabled = 1;

	return 0;
}
```

# qsort.c
- 使用[希尔排序](https://zh.wikipedia.org/wiki/%E5%B8%8C%E5%B0%94%E6%8E%92%E5%BA%8F)

```c