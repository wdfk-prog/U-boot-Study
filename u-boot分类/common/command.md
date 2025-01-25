
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

## find_cmd
```c
/* find command table entry for a command */
struct cmd_tbl *find_cmd_tbl(const char *cmd, struct cmd_tbl *table,
                 int table_len)
{
#ifdef CONFIG_CMDLINE
    struct cmd_tbl *cmdtp;
    struct cmd_tbl *cmdtp_temp = table; /* Init value */
    const char *p;
    int len;
    int n_found = 0;

    if (!cmd)
        return NULL;
    /*
     * Some commands allow length modifiers (like "cp.b");
     * compare command name only until first dot.
     */
    len = ((p = strchr(cmd, '.')) == NULL) ? strlen (cmd) : (p - cmd);

    for (cmdtp = table; cmdtp != table + table_len; cmdtp++) {
        if (strncmp(cmd, cmdtp->name, len) == 0) {
            if (len == strlen(cmdtp->name))
                return cmdtp;   /* full match */

            cmdtp_temp = cmdtp; /* abbreviated command ? */
            n_found++;
        }
    }
    if (n_found == 1) {         /* exactly one match */
        return cmdtp_temp;
    }
#endif /* CONFIG_CMDLINE */

    return NULL;    /* not found or ambiguous command */
}

struct cmd_tbl *find_cmd(const char *cmd)
{
    struct cmd_tbl *start = ll_entry_start(struct cmd_tbl, cmd);
    const int len = ll_entry_count(struct cmd_tbl, cmd);
    return find_cmd_tbl(cmd, start, len);
}
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