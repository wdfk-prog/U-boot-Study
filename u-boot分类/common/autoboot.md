---
title: autoboot
categories:
  - uboot
  - u-boot分类
  - common
tags:
  - uboot
  - u-boot分类
  - common
abbrlink: 2b4b5e53
date: 2025-10-03 09:44:27
---
# autoboot.c
## autoboot_command 自动启动命令
```c
void autoboot_command(const char *s)
{
    debug("### main_loop: bootcmd=\"%s\"\n", s ? s : "<UNDEFINED>");

    if (s //有bootcmd
    && (stored_bootdelay == -2 ||
        //有延迟时间,且没有按键中断
         (stored_bootdelay != -1 && !abortboot(stored_bootdelay)))) {
        bool lock;
        int prev;

        lock = autoboot_keyed() &&
            !IS_ENABLED(CONFIG_AUTOBOOT_KEYED_CTRLC);
        if (lock)
            prev = disable_ctrlc(1); /* disable Ctrl-C checking */

        run_command_list(s, -1, 0);

        if (lock)
            disable_ctrlc(prev);    /* restore Ctrl-C checking */
    }

    if (IS_ENABLED(CONFIG_AUTOBOOT_USE_MENUKEY) &&
        menukey == AUTOBOOT_MENUKEY) {
        s = env_get("menucmd");
        if (s)
            run_command_list(s, -1, 0);
    }
}
```

## abortboot 检查是否有按键中断
```c
static int abortboot(int bootdelay)
{
    int abort = 0;

    if (bootdelay >= 0) {
        if (autoboot_keyed())
            abort = abortboot_key_sequence(bootdelay);
        else
            abort = abortboot_single_key(bootdelay);
    }

    if (IS_ENABLED(CONFIG_SILENT_CONSOLE) && abort)
        gd->flags &= ~GD_FLG_SILENT;

    return abort;
}
```

## passwd_abort_key
- 输入`bootdelaykey`或者`bootstopkey`中的任意一个按键,则返回1;终止自动启动
- `bootdelaykey`的匹配字符串为env中的`bootdelaykey`的值,如果没有配置,则使用`CONFIG_AUTOBOOT_DELAY_STR`的值
- `bootstopkey`的匹配字符串为env中的`bootstopkey`的值,如果没有配置,则使用`CONFIG_AUTOBOOT_STOP_STR`的值
```c
static int passwd_abort_key(uint64_t etime)
{
    int abort = 0;
    struct {
        char *str;
        u_int len;
        int retry;
    }
    delaykey[] = {
        { .str = env_get("bootdelaykey"),  .retry = 1 },
        { .str = env_get("bootstopkey"),   .retry = 0 },
    };

    char presskey[DELAY_STOP_STR_MAX_LENGTH];
    //需要匹配的输入字符串,env中没有配置则宏定义的字符串
#  ifdef CONFIG_AUTOBOOT_DELAY_STR  //默认为"",即任意都不匹配
    if (delaykey[0].str == NULL)
        delaykey[0].str = CONFIG_AUTOBOOT_DELAY_STR;
#  endif
#  ifdef CONFIG_AUTOBOOT_STOP_STR   //默认为" ",即输入空格终止
    if (delaykey[1].str == NULL)
        delaykey[1].str = CONFIG_AUTOBOOT_STOP_STR;
#  endif

    do {
        //检查是否有按键输入
        if (tstc()) {
        }
        //获取按键输入并进行匹配
        for (i = 0; i < sizeof(delaykey) / sizeof(delaykey[0]); i++) {
            if (delaykey[i].len > 0 &&
                presskey_len >= delaykey[i].len &&
                memcmp(presskey + presskey_len -
                    delaykey[i].len, delaykey[i].str,
                    delaykey[i].len) == 0) {
                    debug_bootkeys("got %skey\n",
                        delaykey[i].retry ? "delay" :
                        "stop");

                /* don't retry auto boot */
                //如果是STOP按键,则不再重试
                if (!delaykey[i].retry)
                    bootretry_dont_retry(); //重试时间设置为-1,不在重试
                abort = 1;
            }
        }
        udelay(10000);
    } while (!abort && get_ticks() <= etime);

    return abort;
}
```

## abortboot_single_key
- 获取任意输入,就终止

## bootdelay_process
- 获取`bootdelay`的值,如果没有配置,则使用`CONFIG_BOOTDELAY`的值
```c
const char *bootdelay_process(void)
{
	char *s;
	int bootdelay;

	bootcount_inc();

	s = env_get("bootdelay");
	bootdelay = s ? (int)simple_strtol(s, NULL, 10) : CONFIG_BOOTDELAY;

	/*
	 * Does it really make sense that the devicetree overrides the user
	 * setting? It is possibly helpful for security since the device tree
	 * may be signed whereas the environment is often loaded from storage.
	 */
	if (IS_ENABLED(CONFIG_OF_CONTROL))
		bootdelay = ofnode_conf_read_int("bootdelay", bootdelay);

	debug("### main_loop entered: bootdelay=%d\n\n", bootdelay);

	if (IS_ENABLED(CONFIG_AUTOBOOT_MENU_SHOW))
		bootdelay = menu_show(bootdelay);
	bootretry_init_cmd_timeout();

#ifdef CONFIG_POST
	if (gd->flags & GD_FLG_POSTFAIL) {
		s = env_get("failbootcmd");
	} else
#endif /* CONFIG_POST */
	if (bootcount_error())
		s = env_get("altbootcmd");
	else
		s = env_get("bootcmd");

	if (IS_ENABLED(CONFIG_OF_CONTROL))
		process_fdt_options();
	stored_bootdelay = bootdelay;

	return s;
}
```