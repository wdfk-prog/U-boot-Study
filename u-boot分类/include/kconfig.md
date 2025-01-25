# linux/kconfig.h

## __count_args 计算可变参数宏的参数数

```c
/*
 * 计算可变参数宏的参数数。目前只需要
 * 它用于 1、2 或 3 个参数。
 */
#define __arg6(a1, a2, a3, a4, a5, a6, ...) a6
#define __count_args(...) __arg6(dummy, ##__VA_ARGS__, 4, 3, 2, 1, 0)
```

- 传递一个虚拟参数 `dummy`和参数传入,并返回第6个参数;
- 例如传入 `__count_args(a, b, c)`,则展开为 `__arg6(dummy, a, b, c, 4, 3, 2, 1, 0)`,则返回3
- `dummy` 是一个虚拟参数，用于确保宏展开时参数列表的长度一致。在 __count_args 宏中，dummy 被用作第一个参数，以确保即使没有传递任何参数，参数列表的长度也至少为 1。
- `##__VA_ARGS__` 是一个预处理器技巧，用于处理可变参数宏。__VA_ARGS__ 是一个特殊的宏参数，表示传递给宏的所有可变参数。## 是预处理器的连接运算符，用于将两个标识符连接在一起。

## CONFIG_VAL 拼接配置前缀与配置名

- 根据输入的配置名，返回对应的配置值。
- 配置了 `USE_HOSTCC`,则返回 `CONFIG_TOOLS_xxx`
- 配置了 `CONFIG_XPL_BUILD`,则返回 `CONFIG_xxx`
- 配置了 `CONFIG_SPL_BUILD`,则返回 `CONFIG_SPL_xxx`
- 配置了 `CONFIG_TPL_BUILD`,则返回 `CONFIG_TPL_xxx`
- 配置了 `CONFIG_VPL_BUILD`,则返回 `CONFIG_VPL_xxx`

```c
/*
 * U-Boot 附加组件：用于引用不同宏的辅助宏（前缀为
 * CONFIG_、CONFIG_SPL_、CONFIG_TPL_ 或 CONFIG_TOOLS_），具体取决于版本
 *上下文。
 */

#ifdef USE_HOSTCC
#define _CONFIG_PREFIX TOOLS_
#elif defined(CONFIG_TPL_BUILD)
#define _CONFIG_PREFIX TPL_
#elif defined(CONFIG_VPL_BUILD)
#define _CONFIG_PREFIX VPL_
#elif defined(CONFIG_SPL_BUILD)
#define _CONFIG_PREFIX SPL_
#else
#define _CONFIG_PREFIX
#endif

#define   config_val(cfg)       _config_val(_CONFIG_PREFIX, cfg)
#define  _config_val(pfx, cfg) __config_val(pfx, cfg)
#define __config_val(pfx, cfg) CONFIG_ ## pfx ## cfg

/*
 * CONFIG_VAL(FOO) evaluates to the value of
 *  CONFIG_TOOLS_FOO if USE_HOSTCC is defined,
 *  CONFIG_FOO if CONFIG_XPL_BUILD is undefined,
 *  CONFIG_SPL_FOO if CONFIG_SPL_BUILD is defined.
 *  CONFIG_TPL_FOO if CONFIG_TPL_BUILD is defined.
 *  CONFIG_VPL_FOO if CONFIG_VPL_BUILD is defined.
 */
#define CONFIG_VAL(option)  config_val(option)
```

## config_enabled 判断配置是否启用 返回1或0

- 如果我们有 `#define CONFIG_BOOGER 1`,且传入 `config_enabled(BOOGER, 0)`
- `__ARG_PLACEHOLDER_##value`展开为 `__ARG_PLACEHOLDER_1`,即 `0,`
- 所以如果配置为1,传入为 `(0, 1, 0)`;如果配置为0,传入为 `(... 1, 0)`
- 则最后1返回的是第二个参数,所以如果配置为1,返回1;  如果配置为0,返回0,因为第一个参数被忽略

```c
/*
 * 在 C/CPP 表达式中使用 CONFIG_ 选项的辅助宏。请注意，
 * 这些仅适用于 布尔 和 三态 选项。
 */
#define __ARG_PLACEHOLDER_1 0,
#define config_enabled(cfg, def_val) _config_enabled(cfg, def_val)
#define _config_enabled(value, def_val) __config_enabled(__ARG_PLACEHOLDER_##value, def_val)
#define __config_enabled(arg1_or_junk, def_val) ___config_enabled(arg1_or_junk 1, def_val)
#define ___config_enabled(__ignored, val, ...) val
```

## CONFIG_IS_ENABLED 判断配置是否启用并返回TRUE或FALSE

- 传入 `CONFIG_IS_ENABLED(FOO)`,则 `__count_args`计算为1,则展开为 `__CONFIG_IS_ENABLED_1(FOO)`
- `__CONFIG_IS_ENABLED_1(FOO)`展开为 `__CONFIG_IS_ENABLED_3(FOO, (1), (0))`
- `CONFIG_VAL`根据配置,是否拼接前缀,返回对应的配置值
- `config_enabled`根据配置值,返回是否启用,即1或0
- `__concat`拼接 `__unwrap`和 `config_enabled`返回的值,即 `__unwrap1`或 `__unwrap0`
- `__unwrap1`或 `__unwrap0`展开为 `__unwrap 1`或 `__unwrap 0`
- `__unwrap 1`或 `__unwrap 0`展开为 `1`或 `0`
- 所以如果配置为1,返回1;  如果配置为0,返回0

```c
#define __unwrap(...) __VA_ARGS__
#define __unwrap1(case1, case0) __unwrap case1
#define __unwrap0(case1, case0) __unwrap case0

#define __CONFIG_IS_ENABLED_1(option)        __CONFIG_IS_ENABLED_3(option, (1), (0))
#define __CONFIG_IS_ENABLED_2(option, case1) __CONFIG_IS_ENABLED_3(option, case1, ())
#define __CONFIG_IS_ENABLED_3(option, case1, case0) \
	__concat(__unwrap, config_enabled(CONFIG_VAL(option), 0)) (case1, case0)

#define CONFIG_IS_ENABLED(option, ...)					\
	__concat(__CONFIG_IS_ENABLED_, __count_args(option, ##__VA_ARGS__)) (option, ##__VA_ARGS__)
```

