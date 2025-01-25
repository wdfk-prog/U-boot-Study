# event.c

- [event](https://docs.u-boot.org/en/latest/api/event.html)

## 声明事件类型

```c
//复杂事件声明
#define EVENT_SPY_FULL(_type, _func) \
	__used ll_entry_declare(struct evspy_info, _type ## _3_ ## _func, \
		evspy_info) = _ESPY_REC(_type, _func)

//简单事件声明
#define EVENT_SPY_SIMPLE(_type, _func) \
	__used ll_entry_declare(struct evspy_info_simple, \
		_type ## _3_ ## _func, \
		evspy_info) = _ESPY_REC_SIMPLE(_type, _func)
```

## notify_static 以静态方式通知事件

```c
static int notify_static(struct event *ev)
{
	struct evspy_info *start = ll_entry_start(struct evspy_info, evspy_info);	//定义开始的段的位置
	const int n_ents = ll_entry_count(struct evspy_info, evspy_info);			//获取段的数量
	struct evspy_info *spy;
	//匹配则执行
	for (spy = start; spy != start + n_ents; spy++) {
		if (spy->type == ev->type) {
			int ret;

			log_debug("Sending event %x/%s to spy '%s'\n", ev->type,
				  event_type_name(ev->type), event_spy_id(spy));
			if (spy->flags & EVSPYF_SIMPLE) {
				const struct evspy_info_simple *simple;

				simple = (struct evspy_info_simple *)spy;
				ret = simple->func();
			} else {
				ret = spy->func(NULL, ev);
			}

			/*
			 * TODO: Handle various return codes to
			 *
			 * - claim an event (no others will see it)
			 * - return an error from the event
			 */
			if (ret)
				return log_msg_ret("spy", ret);
		}
	}

	return 0;
}
```

## notify_dynamic 以动态方式通知事件

- 需要配置EVENT_DYNAMIC
- 进行初始化与注册和释放
