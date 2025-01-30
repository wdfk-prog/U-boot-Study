[TOC]

# common/button_cmd.c
- 在执行到这里的时候,按键必须已经按下;代码没有循环与延时
- 且只能处理一个按键,不支持多个按键同时按下
- 使用时,需要在env中设置`button_cmd_N_name`= 和`button_cmd_N`=`fastboot usb 0`(执行的CMD命令)
- 参考`test/dm/button.c`中的`button_cmd`测试的用法
```c
void process_button_cmds(void)
{
	struct button_cmd cmd = {0};
	int i = 0;

	while (get_button_cmd(i++, &cmd) && i < MAX_BTN_CMDS) {
		if (!cmd.pressed)
			continue;

		log_info("BTN '%s'> %s\n", cmd.btn_name, cmd.cmd);
		run_command(cmd.cmd, CMD_FLAG_ENV);
		/* Don't run commands for multiple buttons */
		return;
	}
}
```