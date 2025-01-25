# cli.c
## cli_init
- u_boot_hush_start();
```c
int u_boot_hush_start(void)
{
	if (top_vars == NULL) {
		top_vars = malloc(sizeof(struct variables));
		top_vars->name = "HUSH_VERSION";
		top_vars->value = "0.01";
		top_vars->next = NULL;
		top_vars->flg_export = 0;
		top_vars->flg_read_only = 1;
	}
	return 0;
}
```

## cli_process_fdt 从FDT中获取命令行参数
- 获取`bootcmd`和`bootsecure`参数
- configs/stm32h750-art-pi_defconfig
	```c
	CONFIG_BOOTCOMMAND="bootm 90080000"
	```
- include/env_default.h
	```c
	#ifdef	CONFIG_BOOTCOMMAND
		"bootcmd="	CONFIG_BOOTCOMMAND		"\0"
	#endif
	```
- cli_process_fdt
	```c
	bool cli_process_fdt(const char **cmdp)
	{
		/* Allow the fdt to override the boot command */
		const char *env = ofnode_conf_read_str("bootcmd");
		if (env)
			*cmdp = env;
		/*
		* If the bootsecure option was chosen, use secure_boot_cmd().
		* Always use 'env' in this case, since bootsecure requres that the
		* bootcmd was specified in the FDT too.
		*/
		return ofnode_conf_read_int("bootsecure", 0);
	}
	```

## run_command_list
- 以cli_simple_run_command_list进行分析
### cli_simple_run_command_list
- include/env_default.h
	```c
	#define CONFIG_BOOTCOMMAND "bootm 90080000"
	"bootcmd="	CONFIG_BOOTCOMMAND		"\0"
	```
- cli_simple_run_command_list
```c
int cli_simple_run_command_list(char *cmd, int flag)
{
	char *line, *next;
	int rcode = 0;

	/*
	 * Break into individual lines, and execute each line; terminate on
	 * error.
	 */
	next = cmd;
	line = cmd;
	//执行多条命令,以\n分隔
	while (*next) {
		if (*next == '\n') {
			*next = '\0';
			/* run only non-empty commands */
			if (*line) {
				debug("** exec: \"%s\"\n", line);
				if (cli_simple_run_command(line, 0) < 0) {
					rcode = 1;
					break;
				}
			}
			line = next + 1;
		}
		++next;
	}
	//执行最后一条命令或者唯一一条命令
	if (rcode == 0 && *line)
		rcode = (cli_simple_run_command(line, 0) < 0);

	return rcode;
}
```

### cli_simple_run_command
```c
int cli_simple_run_command(const char *cmd, int flag)
{
	char cmdbuf[CONFIG_SYS_CBSIZE];	/* working copy of cmd		*/
	char *token;			/* start of token in cmdbuf	*/
	char *sep;			/* end of token (separator) in cmdbuf */
	char finaltoken[CONFIG_SYS_CBSIZE];
	char *str = cmdbuf;
	char *argv[CONFIG_SYS_MAXARGS + 1];	/* NULL terminated	*/
	int argc, inquotes;
	int repeatable = 1;
	int rc = 0;


	while (*str) {
		//查找; 或者\; 进行分隔
		for (inquotes = 0, sep = str; *sep; sep++) {
			if ((*sep == '\'') &&
			    (*(sep - 1) != '\\'))
				inquotes = !inquotes;

			if (!inquotes &&
			    (*sep == ';') &&	/* separator		*/
			    (sep != str) &&	/* past string start	*/
			    (*(sep - 1) != '\\'))	/* and NOT escaped */
				break;
		}

		token = str;
		if (*sep) {
			str = sep + 1;	/*str = 下一条命令的开始*/
			*sep = '\0';
		} else {
			str = sep;	/*没有更多的命令 */
		}

		//替换环境变量,例如$USER等信息
		cli_simple_process_macros(token, finaltoken,
					  sizeof(finaltoken));

		//解析命令行,识别有多少个参数,并且存储到argv中
		argc = cli_simple_parse_line(finaltoken, argv);
		if (argc == 0) {
			rc = -1;	/* 没有命令参数 */
			continue;
		}

		if (cmd_process(flag, argc, argv, &repeatable, NULL))
			rc = -1;

		/* ctrl + c 停止执行 */
		if (had_ctrlc())
			return -1;	/* if stopped then not repeatable */
	}

	return rc ? rc : repeatable;
}
```

### cli_simple_process_macros
1. 函数初始化了一些变量，包括当前字符 c、前一个字符 prev、变量名的起始位置 varname_start、输入字符串的长度 inputcnt 和输出缓冲区的剩余大小 outputcnt。state 变量用于跟踪当前的解析状态，初始值为 0，表示等待 $ 符号。
2. 函数通过一个 while 循环遍历输入字符串中的每个字符。在循环中，根据当前的 state 值执行不同的操作：
3. state 为 0 时，函数等待未转义的 $ 符号。如果遇到单引号 '，则进入状态 3，表示在单引号内。如果遇到 $ 符号，则进入状态 1，表示等待 `(` 或` {` 符号。否则，将当前字符复制到输出缓冲区。
4. state 为 1 时，函数等待 `(` 或 `{ `符号。如果遇到这些符号，则进入状态 2，并记录变量名的起始位置。如果未遇到这些符号，则恢复到状态 0，并将 `$` 符号和当前字符复制到输出缓冲区。
5. state 为 2 时，函数等待` )` 或` }` 符号。如果遇到这些符号，函数将处理变量名并进行替换。

例如:
- 示例 1: 简单变量替换
	- 输入字符串为 "Hello $USER!", 并且环境变量 USER 的值为 "world", 则输出字符串为 "Hello world!"
- 带有转义字符
	- 输入字符串为 "Price is \$100", 输出字符串为 "Price is $100"
- 嵌套变量替换
	- 输入字符串为 "Path: $HOME/$USER/bin"，并且环境变量 HOME 的值为 "/home/user"，USER 的值为 "john"
	- 输出"Path: /home/user/john/bin"
- 单引号内的变量不替换
	- 输入字符串为 "This is '$USER'"，并且环境变量 USER 的值为 "john"
	- 输出字符串为 "This is '$USER'"

6. 环境变量值的查找
	- 通过 env_get() 函数获取环境变量的值。如果找到了环境变量，则将其值复制到输出缓冲区，并更新输出缓冲区的剩余大小 outputcnt。
	- 如果未找到环境变量，则将变量名复制到输出缓冲区，并更新输出缓冲区的剩余大小 outputcnt。

### cli_simple_parse_line
- 定义了一个名为 cli_simple_parse_line 的函数，用于解析命令行输入字符串，并将其分割成独立的参数。函数接收两个参数：line 是输入字符串，argv 是一个字符指针数组，用于存储解析后的参数。
```c
int cli_simple_parse_line(char *line, char *argv[])
{
    int nargs = 0; // 初始化参数计数器
    while (nargs < CONFIG_SYS_MAXARGS) { // 循环直到解析出的参数数量达到最大值
        while (isblank(*line)) // 跳过所有空白字符
            ++line;

        if (*line == '\0') {
            argv[nargs] = NULL; // 如果到达字符串末尾，将当前参数位置设置为 NULL
            return nargs;
        }

        argv[nargs++] = line;
        // 将当前非空白字符的位置赋值给 argv[nargs]，并增加参数计数器

        while (*line && !isblank(*line)) // 继续遍历字符串，直到遇到空白字符或字符串结束
            ++line;

        if (*line == '\0') {
            argv[nargs] = NULL;
            return nargs;
        }

        *line++ = '\0'; // 将当前字符设置为 '\0'，以终止当前参数字符串，并将指针移动到下一个字符
    }

    printf("** Too many args (max. %d) **\n", CONFIG_SYS_MAXARGS); // 如果参数数量超过最大值，输出错误信息
    return nargs; // 返回解析出的参数数量
}
```

