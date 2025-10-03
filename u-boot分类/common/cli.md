---
title: cli
date: 2025-10-03 09:44:27
categories:
  - uboot
  - u-boot分类
  - common
tags:
  - uboot
  - u-boot分类
  - common
---
# CTL_CH 转换为控制字符
```c
#define CTL_CH(c)		((c) - 'a' + 1)
```
- 控制字符通常用于表示特定的控制操作，例如回车、换行、退格等。在 ASCII 码表中，控制字符的值通常在 1 到 31 之间。

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

## cli_loop 命令行循环
- 选择使用的命令行解释器
- GD_FLG_HUSH_MODERN_PARSER: 选择使用 Hush 解释器
- GD_FLG_HUSH_OLD_PARSER: 选择使用 Hush 解释器(旧版本)
- CONFIG_CMDLINE: 选择使用 U-Boot 命令行解释器
	- cli_simple_loop

## run_command_repeatable 执行命令并返回是否可重复执行
- 选择使用的命令行解释器

# cli_simple.c
## cli_simple_loop
```c
void cli_simple_loop(void)
{
	static char lastcommand[CONFIG_SYS_CBSIZE + 1] = { 0, };

	int len;
	int flag;
	int rc = 1;

	for (;;) {
		if (rc >= 0) {
			// 每次执行命令前重置超时时间
			bootretry_reset_cmd_timeout();
		}
		// 读取命令行,执行转义字符处理与控制字符处理
		len = cli_readline(CONFIG_SYS_PROMPT);

		flag = 0;	/* 假设暂时没有特殊标志 */
		if (len > 0)
			//保存处理后的命令
			strlcpy(lastcommand, console_buffer,
				CONFIG_SYS_CBSIZE + 1);
		else if (len == 0)
			flag |= CMD_FLAG_REPEAT;
#ifdef CONFIG_BOOT_RETRY_TIME
		else if (len == -2) {
			/* -2 表示超时，请重试自动启动
			 */
			puts("\nTimed out waiting for command\n");
# ifdef CONFIG_RESET_TO_RETRY
			/*  重启 */
			do_reset(NULL, 0, 0, NULL);
# else
			return;		/* retry autoboot */
# endif
		}
#endif

		if (len == -1)
			puts("<INTERRUPT>\n");
		else
			rc = run_command_repeatable(lastcommand, flag);

		if (rc <= 0) {
			/* invalid command or not repeatable （无效命令或不可重复），重置*/
			lastcommand[0] = 0;
		}
	}
}
```

## cli_simple_run_command_list
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

## cli_simple_run_command
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

## cli_simple_process_macros
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

## cli_simple_parse_line
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

# cli_readline.c
## cli_readline
## cli_readline_into_buffer 命令行读取
- 根据配置选择是否具有历史记录功能
```c
// prompt: 提示符,输出显示到终端;例如"U-Boot>"
int cli_readline_into_buffer(const char *const prompt, char *buffer,
			     int timeout)
{
	if (IS_ENABLED(CONFIG_CMDLINE_EDITING) && (gd->flags & GD_FLG_RELOC)) {
		if (!initted) {
			rc = hist_init();
			if (rc == 0)
				initted = 1;
		}

		if (prompt)
			puts(prompt);

		rc = cread_line(prompt, p, &len, timeout);
		return rc < 0 ? rc : len;

	} else {
		return cread_line_simple(prompt, p);
	}
}
```

## cread_line_simple 简单的命令行读取,没有历史记录功能
## cread_line 命令行读取
- 带有历史记录功能
- 命令行补全
- 具备编辑功能
```c
static int cread_line(const char *const prompt, char *buf, unsigned int *len,
		      int timeout)
{
	struct cli_ch_state s_cch, *cch = &s_cch;
	struct cli_line_state s_cls, *cls = &s_cls;
	char ichar;
	int first = 1;

	cli_ch_init(cch);	//memset(cch, '\0', sizeof(*cch));
	cli_cread_init(cls, buf, *len);	//初始化命令行
	cls->prompt = prompt;
	cls->history = true;
	cls->cmd_complete = true;

	while (1) {
		int ret;

		/* Check for saved characters */
		ichar = cli_ch_process(cch, 0);

		if (!ichar) {
			//阻塞检查是否有输入,阻塞时间为`CONFIG_BOOT_RETRY_TIME`秒
			if (bootretry_tstc_timeout())	
				return -2;	/* timed out */
			if (first && timeout) {
				u64 etime = endtick(timeout);

				while (!tstc()) {	/* while no incoming data */
					if (get_ticks() >= etime)
						return -2;	/* timed out */
					schedule();
				}
				first = 0;
			}

			ichar = getcmd_getch();	//获取输入字符
			ichar = cli_ch_process(cch, ichar);	//处理输入字符,返回转义后的字符
		}

		ret = cread_line_process_ch(cls, ichar);	//控制字符处理
		if (ret == -EINTR)	//按下^C中断输入
			return -1;
		else if (!ret)	//输入完成
			break;
	}
	*len = cls->eol_num;

	if (buf[0] && buf[0] != CREAD_HIST_CHAR)
		cread_add_to_hist(buf);		//添加命令到历史记录
	hist_cur = hist_add_idx;

	return 0;
}
```

## cli_cread_init 初始化命令行
```c
void cli_cread_init(struct cli_line_state *cls, char *buf, uint buf_size)
{
	int init_len = strlen(buf);	//获取bug字符串是否有内容

	memset(cls, '\0', sizeof(struct cli_line_state));
	cls->insert = true;
	cls->buf = buf;
	cls->len = buf_size;

	if (init_len)	//如果buf有内容,则进行添加
		cread_add_str(buf, init_len, 0, &cls->num, &cls->eol_num, buf,
			      buf_size);
}
```

## cread_line_process_ch 控制字符处理
```c
int cread_line_process_ch(struct cli_line_state *cls, char ichar)
{
	char *buf = cls->buf;

	/* ichar=0x0 when error occurs in U-Boot getc */
	if (!ichar)
		return -EAGAIN;

	if (ichar == '\n') {
		putc('\n');
		buf[cls->eol_num] = '\0';	/* terminate the string */
		return 0;
	}

	switch (ichar) {
	case CTL_CH('a'):	//^A 移动到行首,并删除之前的字符
	case CTL_CH('c'):	//^C 取消当前输入
	case CTL_CH('f'):	//^F 光标向右移动一个字符
	case CTL_CH('b'):	//^B 光标向左移动一个字符
	case CTL_CH('d'):	//^D 删除当前字符
	case CTL_CH('k'):	//^K 删除光标后的字符
	case CTL_CH('e'):	//^E 刷新从当前光标位置到行尾的显示内容
	case CTL_CH('o'):	//^O 插入一个新行
	case CTL_CH('w'):	//^W 删除光标前的单词
	case CTL_CH('x'):
	case CTL_CH('u'):	//^U 删除从当前光标位置到前一个单词的所有字符，并更新显示内容
	case DEL:
	case DEL7:
	case 8:				//删除当前字符
	case CTL_CH('p'):	//^P 上一个命令
	case CTL_CH('n'):	//^N 下一个命令
		if (cls->history) {
			char *hline;

			if (ichar == CTL_CH('p'))
				hline = hist_prev();
			else
				hline = hist_next();

			if (!hline) {
				getcmd_cbeep();
				break;
			}

			/* nuke the current line */
			/* first, go home */
			BEGINNING_OF_LINE();

			/* erase to end of line */
			ERASE_TO_EOL();

			/* copy new line into place and display */
			strcpy(buf, hline);
			cls->eol_num = strlen(buf);
			REFRESH_TO_EOL();
			break;
		}
		break;
	case '\t':	//TAB键 自动补全
		if (IS_ENABLED(CONFIG_AUTO_COMPLETE) && cls->cmd_complete) {
			int num2, col;

			/* do not autocomplete when in the middle */
			if (cls->num < cls->eol_num) {
				getcmd_cbeep();
				break;
			}

			buf[cls->num] = '\0';
			col = strlen(cls->prompt) + cls->eol_num;
			num2 = cls->num;
			if (cmd_auto_complete(cls->prompt, buf, &num2, &col)) {
				col = num2 - cls->num;
				cls->num += col;
				cls->eol_num += col;
			}
			break;
		}
		fallthrough;
	default:	//其他字符 添加字符
		cread_add_char(ichar, cls->insert, &cls->num, &cls->eol_num,
			       buf, cls->len);
		break;
	}

	buf[cls->eol_num] = '\0';

	return -EAGAIN;
}
```

## cread_add_str
## cread_add_char 添加字符
- 可以是插入模式,也可以是追加模式
```c
//num:当前光标位置,eol_num:缓冲区中的字符数
static void cread_add_char(char ichar, int insert, uint *num,
			   uint *eol_num, char *buf, uint len)
{
	uint wlen;

	//如果是插入模式 或者 光标在行尾
	if (insert || *num == *eol_num) {
		if (*eol_num > len - 1) {	//缓冲区已满
			getcmd_cbeep();		//发出警告声
			return;
		}
		(*eol_num)++;	//缓冲区字符数+1
	}

	if (insert) {
		wlen = *eol_num - *num;	//计算光标后的字符数
		if (wlen > 1)	//如果光标后有字符 则移动字符
			memmove(&buf[*num+1], &buf[*num], wlen-1);	//移动字符将光标后的字符向后移动

		buf[*num] = ichar;	//插入字符
		putnstr(buf + *num, wlen);//输出光标后的字符
		(*num)++;
		while (--wlen)
			getcmd_putch(CTL_BACKSPACE);	//将光标后面的字符向左移动一个位置
		//这样就实现了插入字符
	} else {
		/* echo the character */
		wlen = 1;
		buf[*num] = ichar;
		putnstr(buf + *num, wlen);	//直接输出最后一个字符
		(*num)++;
	}
}
```

## 历史记录功能
### hist_init
- hist_list:历史记录列表 保存命令数组的地址

### cread_add_to_hist
- 将命令添加到历史记录中
- 将当前添加索引加1,如果索引大于最大索引,则将索引置为0;覆盖掉最旧的命令
```c
static void cread_add_to_hist(char *line)
{
	strcpy(hist_list[hist_add_idx], line);

	if (++hist_add_idx >= HIST_MAX)
		hist_add_idx = 0;

	if (hist_add_idx > hist_max)
		hist_max = hist_add_idx;

	hist_num++;
}
```
### hist_next hist_prev
- 通过hist_cur索引hist_list中的命令

### cread_print_hist_list
- 打印历史记录列表,使用`history`命令

### cmd/history.c
- 调用`cread_print_hist_list`打印历史记录

# cli_getch.c
## cli_ch_process 转义处理程序
```c
int cli_ch_process(struct cli_ch_state *cch, int ichar)
{
	/*
	 * ichar=0x0 当 U-Boot getchar（） 出现错误时或当调用者
	 * 想要检查转义中是否保存了更多字符序列
	 */
	if (!ichar) {
		if (cch->emitting) {
			if (cch->emit_upto < cch->esc_len)
				return cch->esc_save[cch->emit_upto++];
			cch->emit_upto = 0;
			cch->emitting = false;
			cch->esc_len = 0;
		}
		return 0;
	} else if (ichar == -ETIMEDOUT) {
		/*
		 * 如果我们在转义序列中，但没有任何内容遵循
		 * 转义字符，则用户可能只是按下了
		 * 退出键。返回它并清除序列。
		 */
		if (cch->esc_len) {	//到目前为止读取的转义字符数
			cch->esc_len = 0;
			return '\e';
		}

		/* Otherwise there is nothing to return */
		return 0;
	}

	if (ichar == '\n' || ichar == '\r')
		return '\n';

	/* 处理标准 Linux xTerm ESC 序列，用于箭头键等 */
	if (cch->esc_len != 0) {
		enum cli_esc_state_t act;
		//处理转义字符 act:是否转义完成,ichar:转义后的字符
		ichar = cli_ch_esc(cch, ichar, &act);

		switch (act) {
		case ESC_SAVE:
			/* 保存此字符，不返回任何内容 */
			cch->esc_save[cch->esc_len++] = ichar;
			ichar = 0;
			break;
		case ESC_REJECT:
			/*
			 * 无效的转义序列 的 start 返回 其中的字符
			 */
			cch->esc_save[cch->esc_len++] = ichar;
			ichar = cch->esc_save[cch->emit_upto++];	//要从 esc_save 发出的下一个索引
			cch->emitting = true;	//是从 esc_save 发出的字符
			return ichar;
		case ESC_CONVERTED:
			/*有效的转义序列返回生成的 char*/
			cch->esc_len = 0;
			break;
		}
	}
	//检查变量 ichar 是否等于转义字符 '\e'
	if (ichar == '\e') {
		if (!cch->esc_len) {	//如果没有转义字符
			cch->esc_save[cch->esc_len] = ichar;	//保存转义字符
			cch->esc_len = 1;	//转义字符长度为1
		} else {
			puts("impossible condition #876\n");
			cch->esc_len = 0;
		}
		return 0;
	}

	return ichar;
}
```

## cli_ch_esc 处理转义字符
```c
/**
 * enum cli_esc_state_t - 指示如何处理转义字符
 *
 * @ESC_REJECT：转义序列无效，因此 esc_save[] 字符为
 * 从每次后续调用 cli_ch_esc（） 返回
 * @ESC_SAVE：字符应保存在 esc_save 中，直到我们有另一个字符
 * @ESC_CONVERTED：转义序列已完成，生成的
 * 字符可用
 */
enum cli_esc_state_t {
	ESC_REJECT,
	ESC_SAVE,
	ESC_CONVERTED
};
static int cli_ch_esc(struct cli_ch_state *cch, int ichar,
		      enum cli_esc_state_t *actp)
{
	enum cli_esc_state_t act = ESC_REJECT;

	switch (cch->esc_len) {
	case 1:
		if (ichar == '[' || ichar == 'O')
			act = ESC_SAVE;
		else
			act = ESC_CONVERTED
		break;
	case 2:
		switch (ichar) {
		case 'D':	/* <- key */
			ichar = CTL_CH('b');
			act = ESC_CONVERTED;
			break;	/* pass off to ^B handler */
		case 'C':	/* -> key */
			ichar = CTL_CH('f');
			act = ESC_CONVERTED;
			break;	/* pass off to ^F handler */
		case 'H':	/* Home key */
			ichar = CTL_CH('a');
			act = ESC_CONVERTED;
			break;	/* pass off to ^A handler */
		case 'F':	/* End key */
			ichar = CTL_CH('e');
			act = ESC_CONVERTED;
			break;	/* pass off to ^E handler */
		case 'A':	/* up arrow */
			ichar = CTL_CH('p');
			act = ESC_CONVERTED;
			break;	/* pass off to ^P handler */
		case 'B':	/* down arrow */
			ichar = CTL_CH('n');
			act = ESC_CONVERTED;
			break;	/* pass off to ^N handler */
		case '1':
		case '2':
		case '3':
		case '4':
		case '7':
		case '8':
			if (cch->esc_save[1] == '[') {
				/*看看下一个角色是不是 ~ */
				act = ESC_SAVE;
			}
			break;
		}
		break;
	case 3:
		switch (ichar) {
		case '~':
			switch (cch->esc_save[2]) {
			case '3':	/* Delete key */
				ichar = CTL_CH('d');
				act = ESC_CONVERTED;
				break;	/* pass to ^D handler */
			case '1':	/* Home key */
			case '7':
				ichar = CTL_CH('a');
				act = ESC_CONVERTED;
				break;	/* pass to ^A handler */
			case '4':	/* End key */
			case '8':
				ichar = CTL_CH('e');
				act = ESC_CONVERTED;
				break;	/* pass to ^E handler */
			}
			break;
		case '0':
			if (cch->esc_save[2] == '2')
				act = ESC_SAVE;
			break;
		}
		break;
	case 4:
		switch (ichar) {
		case '0':
		case '1':
			act = ESC_SAVE;
			break;		/* bracketed paste */
		}
		break;
	case 5:
		if (ichar == '~') {	/* bracketed paste */
			ichar = 0;
			act = ESC_CONVERTED;
		}
	}

	*actp = act;

	return ichar;
}
```