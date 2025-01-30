
# command.c
## U_BOOT_CMD
```c
#ifdef CONFIG_AUTO_COMPLETE
# define _CMD_COMPLETE(x) x,
#else
# define _CMD_COMPLETE(x)
#endif
#ifdef CONFIG_SYS_LONGHELP
# define _CMD_HELP(x) x,
#else
# define _CMD_HELP(x)
#endif
//cmd名称,最大参数个数,是否可重复,cmd调用函数,使用说明,帮助信息
#define U_BOOT_CMD(_name, _maxargs, _rep, _cmd, _usage, _help)      \
    U_BOOT_CMD_COMPLETE(_name, _maxargs, _rep, _cmd, _usage, _help, NULL)
//定义了cmd_tbl结构体的变量,存储在cmdlist中,赋值为U_BOOT_CMD_MKENT
//_name:cmd名称,_maxargs:最大参数个数,_rep:是否可重复,_cmd:cmd调用函数,_usage:使用说明,_help:帮助信息,_comp:自动补全函数
#define U_BOOT_CMD_COMPLETE(_name, _maxargs, _rep, _cmd, _usage, _help, _comp) \
    ll_entry_declare(struct cmd_tbl, _name, cmd) =          \
        U_BOOT_CMD_MKENT_COMPLETE(_name, _maxargs, _rep, _cmd,  \
                        _usage, _help, _comp)

struct cmd_tbl {
    char        *name;      /* Command Name         */
    int     maxargs;    /* maximum number of arguments  */
                    /*
                     * Same as ->cmd() except the command
                     * tells us if it can be repeated.
                     * Replaces the old ->repeatable field
                     * which was not able to make
                     * repeatable property different for
                     * the main command and sub-commands.
                     */
    int     (*cmd_rep)(struct cmd_tbl *cmd, int flags, int argc,
                   char *const argv[], int *repeatable);
                    /* Implementation function  */
    int     (*cmd)(struct cmd_tbl *cmd, int flags, int argc,
                   char *const argv[]);
    char        *usage;     /* Usage message    (short) */
#ifdef  CONFIG_SYS_LONGHELP
    const char  *help;      /* Help  message    (long)  */
#endif
#ifdef CONFIG_AUTO_COMPLETE
    // 对参数执行自动补全
    int     (*complete)(int argc, char *const argv[],
                    char last_char, int maxv, char *cmdv[]);
#endif
};

#define U_BOOT_CMD_MKENT_COMPLETE(_name, _maxargs, _rep, _cmd,      \
                _usage, _help, _comp)           \
        { #_name, _maxargs,                 \
         _rep ? cmd_always_repeatable : cmd_never_repeatable,   \
         _cmd, _usage, _CMD_HELP(_help) _CMD_COMPLETE(_comp) }

//可重复触发cmd命令
int cmd_always_repeatable(struct cmd_tbl *cmdtp, int flag, int argc,
              char *const argv[], int *repeatable)
{
    *repeatable = 1;

    return cmdtp->cmd(cmdtp, flag, argc, argv);
}
//仅能执行一次
int cmd_never_repeatable(struct cmd_tbl *cmdtp, int flag, int argc,
             char *const argv[], int *repeatable)
{
    *repeatable = 0;

    return cmdtp->cmd(cmdtp, flag, argc, argv);
}

struct cmd_tbl *find_cmd(const char *cmd);
struct cmd_tbl *find_cmd_tbl(const char *cmd, struct cmd_tbl *table,
			     int table_len); //查找命令表中的命令
```

## cmd_process
```c
enum command_ret_t cmd_process(int flag, int argc, char *const argv[],
                   int *repeatable, ulong *ticks)
{
    enum command_ret_t rc = CMD_RET_SUCCESS;
    struct cmd_tbl *cmdtp;
//启用宏并在env中设置为1,打印输入参数
#if defined(CONFIG_SYS_XTRACE)
    char *xtrace;

    xtrace = env_get("xtrace");
    if (xtrace) {
        puts("+");
        for (int i = 0; i < argc; i++) {
            puts(" ");
            puts(argv[i]);
        }
        puts("\n");
    }
#endif

    /* Look up command in command table */
    cmdtp = find_cmd(argv[0]);
    if (cmdtp == NULL) {
        printf("Unknown command '%s' - try 'help'\n", argv[0]);
        return 1;
    }

    /* found - check max args */
    if (argc > cmdtp->maxargs)
        rc = CMD_RET_USAGE;

#if defined(CONFIG_CMD_BOOTD)
    /* avoid "bootd" recursion */
    else if (cmdtp->cmd == do_bootd) {
        if (flag & CMD_FLAG_BOOTD) {
            puts("'bootd' recursion detected\n");
            rc = CMD_RET_FAILURE;
        } else {
            flag |= CMD_FLAG_BOOTD;
        }
    }
#endif

    /* If OK so far, then do the command */
    if (!rc) {
        int newrep;

        if (ticks)
            *ticks = get_timer(0);
        rc = cmd_call(cmdtp, flag, argc, argv, &newrep);
        if (ticks)
            *ticks = get_timer(*ticks);
        *repeatable &= newrep;
    }
    if (rc == CMD_RET_USAGE)
        rc = cmd_usage(cmdtp);
    return rc;
}
```

## cmd_auto_complete 自动补全
```c
int cmd_auto_complete(const char *const prompt, char *buf, int *np, int *colp)
{
	char tmp_buf[CONFIG_SYS_CBSIZE + 1];	/* copy of console I/O buffer */
	int n = *np, col = *colp;
	char *argv[CONFIG_SYS_MAXARGS + 1];		/* NULL terminated	*/
	char *cmdv[20];
	char *s, *t;
	const char *sep;
	int i, j, k, len, seplen, argc;
	int cnt;
	char last_char;
#ifdef CONFIG_CMDLINE_PS_SUPPORT
	const char *ps_prompt = env_get("PS1");
#else
	const char *ps_prompt = CONFIG_SYS_PROMPT;
#endif

	if (strcmp(prompt, ps_prompt) != 0)
		return 0;	/* not in normal console */

	cnt = strlen(buf);
	if (cnt >= 1)
		last_char = buf[cnt - 1];
	else
		last_char = '\0';

	/* copy to secondary buffer which will be affected */
	strcpy(tmp_buf, buf);

	// 识别空格分隔的参数数量
	argc = make_argv(tmp_buf, sizeof(argv)/sizeof(argv[0]), argv);

	//匹配$补全环境变量
	i = dollar_complete(argc, argv, last_char,
			    sizeof(cmdv) / sizeof(cmdv[0]), cmdv);
	if (!i) {
		/* 补全命令和子命令和环境变量,返回匹配的数量,补全的命令存放在cmdv中 */
		i = complete_cmdv(argc, argv, last_char,
				  sizeof(cmdv) / sizeof(cmdv[0]), cmdv);
	}

	/* 不匹配;响铃结束 */
	if (i == 0) {
		if (argc > 1)	/* 允许非命令的选项卡 */
			return 0;
		putc('\a');
		return 1;
	}

	s = NULL;
	len = 0;
	sep = NULL;
	seplen = 0;
	if (i == 1) { /* 只有一个匹配 */
		if (last_char != '\0' && !isblank(last_char))
			k = strlen(argv[argc - 1]); //最后一个参数的长度
		else
			k = 0;  //最后一个参数为空

		s = cmdv[0] + k;//字符串指针指向匹配的命令
		len = strlen(s);
		sep = " ";
		seplen = 1;
	} else if (i > 1 && (j = find_common_prefix(cmdv)) != 0) { /* more */
		if (last_char != '\0' && !isblank(last_char))
			k = strlen(argv[argc - 1]); //最后一个参数的长度
		else
			k = 0;  //最后一个参数为空

		j -= k;
		if (j > 0) {    //需要额外的字符显示
			s = cmdv[0] + k;
			len = j;
		}
	}

	if (s != NULL) {
		k = len + seplen;
		/*/当前光标位置 + 补全的命令长度 + 分隔符长度 > 最大长度*/
		if (n + k >= CONFIG_SYS_CBSIZE - 2) {
			putc('\a');
			return 1;
		}

		t = buf + cnt;  //指向字符串的末尾
		for (i = 0; i < len; i++)
			*t++ = *s++;    //将补全的命令拷贝到buf中
		if (sep != NULL)
			for (i = 0; i < seplen; i++)
				*t++ = sep[i];  //拷贝分隔符
		*t = '\0';  //字符串结束符
		n += k;     //光标位置
		col += k;   //缓存区字符数
		puts(t - k);    //打印补全的命令
		if (sep == NULL)
			putc('\a');
		*np = n;
		*colp = col;
	} else {
        //打印命令列表
		print_argv(NULL, "  ", " ", 78, cmdv);
        //打印提示符
		puts(prompt);
		//打印输入的命令与补全的命令
        puts(buf);
	}
	return 1;
}
```

## make_argv 识别传入字符串中的参数数量
- 识别空格分隔的参数数量

## complete_cmdv
## complete_subcmdv 自动补全子命令
```c
int complete_subcmdv(struct cmd_tbl *cmdtp, int count, int argc,
		     char *const argv[], char last_char,
		     int maxv, char *cmdv[])
{
#ifdef CONFIG_CMDLINE
	const struct cmd_tbl *cmdend = cmdtp + count;
	const char *p;
	int len, clen;
	int n_found = 0;
	const char *cmd;

	/* sanity? */
	if (maxv < 2)
		return -2;

	cmdv[0] = NULL;

	if (argc == 0) {    //tab键补全命令 没有任何字符,进行列表打印
		/* output full list of commands */
		for (; cmdtp != cmdend; cmdtp++) {
			if (n_found >= maxv - 2) {  //超过最大数量
				cmdv[n_found++] = "...";    //显示省略号
				break;
			}
			cmdv[n_found++] = cmdtp->name;
		}
		cmdv[n_found] = NULL;
		return n_found;
	}

	/*
        输入了多个参数。          `ls -l`
        输入了一个参数并按下空格。 `ls `
        输入了一个参数并按下回车。 `ls`
    */
	if (argc > 1 || last_char == '\0' || isblank(last_char)) {
		cmdtp = find_cmd_tbl(argv[0], cmdtp, count);
		if (cmdtp == NULL || cmdtp->complete == NULL) {
			cmdv[0] = NULL;
			return 0;
		}
        //调用子命令的自动补全函数,补全子命令的参数
		return (*cmdtp->complete)(argc, argv, last_char, maxv, cmdv);
	}

	cmd = argv[0];
	/*
	 * Some commands allow length modifiers (like "cp.b");
	 * compare command name only until first dot.
	 */
	p = strchr(cmd, '.');
	if (p == NULL)
		len = strlen(cmd);
	else
		len = p - cmd;

	// 遍历命令表,查找匹配的命令
	for (; cmdtp != cmdend; cmdtp++) {

		clen = strlen(cmdtp->name);
		if (clen < len)
			continue;

		if (memcmp(cmd, cmdtp->name, len) != 0)
			continue;

		/* too many! */
		if (n_found >= maxv - 2) {
			cmdv[n_found++] = "...";
			break;
		}

		cmdv[n_found++] = cmdtp->name;
	}

	cmdv[n_found] = NULL;
	return n_found;
#else
	return 0;
#endif
}
```

## find_common_prefix 查找匹配的命令的公共前缀
```c
static int find_common_prefix(char *const argv[])
{
	int i, len;
	char *anchor, *s, *t;

	if (*argv == NULL)
		return 0;

	/* begin with max */
	anchor = *argv++;
	len = strlen(anchor);
    //s:当前命令,t:下一个命令,在while中不断指向下一个命令
	while ((t = *argv++) != NULL) {
		s = anchor;
		for (i = 0; i < len; i++, t++, s++) {
            //比较命令的字符不相同,退出循环
			if (*t != *s)
				break;
		}
		len = s - anchor;   //记录公共前缀的长度,最后返回最小的公共前缀长度
	}
	return len;
}
```

## print_argv 打印命令列表
```c
/**
 * @banner: 在参数之前打印的字符串。
 * @leader: 在每个参数之前打印的字符串。
 * @sep: 在每个参数之间打印的字符串。
 * @linemax: 每行的最大字符数。
 *
 * 此函数以格式化的方式打印命令行参数。
 * 首先打印 @banner，然后每个参数前缀 @leader 并用 @sep 分隔。

 举例： print_argv("Command List", "> ", ", ", 20, (char *const []){"git", "status", "commit", "push", "pull", NULL});
    输出： Command List
          > git, status, commit, push, pull
 */
```

## cmd_usage
- 打印usage和help信息
- help信息使用`U_BOOT_LONGHELP`宏定义
    ```c
    #define U_BOOT_LONGHELP(_cmdname, text)                 \
    static __maybe_unused const char _cmdname##_help_text[] = text
    
    U_BOOT_CMD(
    bootm,  CONFIG_SYS_MAXARGS, 1,  do_bootm,
    "boot application image from memory", bootm_help_text
    );
    ```

```c
int cmd_usage(const struct cmd_tbl *cmdtp)
{
    printf("%s - %s\n\n", cmdtp->name, cmdtp->usage);

#ifdef  CONFIG_SYS_LONGHELP
    printf("Usage:\n%s ", cmdtp->name);

    if (!cmdtp->help) {
        puts ("- No additional help available.\n");
        return 1;
    }

    puts(cmdtp->help);
    putc('\n');
#endif  /* CONFIG_SYS_LONGHELP */
    return 1;
}
```