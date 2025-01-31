[TOC]
# hash 哈希 散列
- [给定一个键，哈希表在常数时间内返回相应的值，无论哈希表中有多少个键](https://craftinginterpreters.com/hash-tables.html)
- 为了确定在多大数量以上哈希查找比线性查找和二分查找更快，我们需要考虑它们的时间复杂度和实际性能。

## 时间复杂度对比
- **哈希查找**：O(1)
- **线性查找**：O(n)
- **二分查找**：O(log n)

## 实际性能分析
- **哈希查找**：在理想情况下，哈希查找的时间复杂度是常数时间 O(1)，即无论哈希表中有多少个键，查找时间都是固定的。然而，哈希查找的性能也依赖于哈希函数的质量和哈希冲突的处理方式。
- **线性查找**：随着数据量的增加，查找时间线性增加。当数据量较小时，线性查找的性能可能还可以接受，但随着数据量的增加，性能会显著下降。
- **二分查找**：需要数据是有序的，查找时间随着数据量的增加而对数增加。对于较大的数据量，二分查找的性能优于线性查找，但不如哈希查找。

## 数量级对比
| 特性       | 哈希表       | 线性查找     | 二分查找     |
|------------|--------------|--------------|--------------|
| 插入时间   | O(1) 平均    | O(n)         | O(n)         |
| 删除时间   | O(1) 平均    | O(n)         | O(n)         |
| 修改时间   | O(1) 平均    | O(n)         | O(log n) 查找 + O(n) 修改 |
| 查找时间   | O(1) 平均    | O(n)         | O(log n)     |
| 内存占用   | 较大         | 较小         | 中等         |
| 代码量     | 较大         | 较小         | 中等         |

## 结论
- **哈希查找**：在数据量较大时（例如超过 100），哈希查找的性能明显优于线性查找和二分查找。
- **线性查找**：适用于数据量较小的场景，但随着数据量的增加，性能会显著下降。
- **二分查找**：适用于数据量较大且数据有序的场景，但不如哈希查找。

因此，当数据量超过 100 时，哈希查找通常会比线性查找和二分查找更快。

## 不同哈希表实现
1. GNU C Library (glibc) u_boot Linux Kernel
哈希表实现：hsearch 和 tsearch
选择的路径：使用开放寻址法
探测策略：线性探测
哈希函数：
负载因子：默认 0.75
增长率：动态调整
哈希表大小：通常使用质数。
原因：开放寻址法在内存占用和查找性能之间取得了平衡，适用于大多数通用场景。
2. Python (CPython)
哈希表实现：dict 和 set
选择的路径：使用开放寻址法
探测策略：二次探测
哈希函数：MurmurHash
负载因子：默认 0.66
增长率：2 倍增长
哈希表大小：通常使用 2 的幂次方。
原因：二次探测减少了哈希冲突，提高了查找和插入性能。适用于需要高效查找和插入的场景。
3. Java (OpenJDK)
哈希表实现：HashMap 和 HashSet
选择的路径：使用分离链接法
哈希函数 hashCode 
探测策略：链表和红黑树
负载因子：默认 0.75
增长率：2 倍增长
哈希表大小：通常使用 2 的幂次方。
原因：分离链接法在处理高负载因子和大量哈希冲突时表现良好，适用于需要高效查找和删除的场景。
4. Redis
哈希表实现：dict
选择的路径：使用分离链接法
哈希函数：MurmurHash 
探测策略：链表
负载因子：默认 1.0
增长率：2 倍增长
哈希表大小：通常使用 2 的幂次方。
原因：分离链接法在处理高负载因子和大量哈希冲突时表现良好，适用于需要高效查找和删除的场景。MurmurHash 提供了良好的哈希分布，减少了冲突。

## 增长策略
- **动态增长**：当哈希表中的键值对数量超过负载因子时，哈希表会动态增长，通常是 2 倍增长。动态增长可以减少哈希冲突，提高查找性能。
- **渐进式扩容**：在动态增长时，哈希表会逐步将键值对从旧表迁移到新表，避免一次性迁移导致的性能抖动。

## 负载因子
- **负载因子**：哈希表中键值对数量与表大小的比值。负载因子越大，哈希冲突越多，查找性能越低。

## 探测策略
- **线性探测**：当哈希冲突发生时，线性探测会逐个探测下一个位置，直到找到空槽或者查找到目标键值对。
- **二次探测**：二次探测会以二次方递增的步长探测下一个位置，减少哈希冲突。
- **链表探测**：当哈希冲突发生时，链表探测会将冲突的键值对链接在一起，形成链表。
- **红黑树探测**：当链表长度超过一定阈值时，链表会转换为红黑树，提高查找性能。

## 选择的路径
- **开放寻址法**：哈希表中的每个槽都可以存放键值对，当哈希冲突发生时，会探测下一个槽，直到找到空槽或者查找到目标键值对。
- **分离链接法**：哈希表中的每个槽都存放一个链表或者红黑树，当哈希冲突发生时，会将冲突的键值对链接在一起。

## 哈希表大小
- **哈希表大小**：哈希表中槽的数量，通常是质数。哈希表大小的选择会影响哈希冲突的发生和查找性能。
- **质数**：哈希表大小通常选择质数，可以减少哈希冲突的发生。
- **取模运算**：哈希表大小通常是 2 的幂次方，可以通过位运算替代取模运算，提高性能。

# lib/hashtable.c
## isprime 判断是否为素数
1. 质数的定义:质数是大于 1 的自然数，除了 1 和它本身外，不能被其他自然数整除。例如，2、3、5、7 和 11 都是质数。
2. div 从 3 开始，每次加 2，直到 div * div >= number时退出循环。

```c
/*
 * 对于使用的双哈希方法，表的大小必须是质数。为了
 * 校正用户给定的表大小，我们需要进行质数测试。这个简单的
 * 算法是足够的，因为
 * a) 代码（很可能）在每次程序运行时被调用几次，并且
 * b) 数字很小，因为表必须适合核心内存
 * */
// 适用于较小的数字 快速
static int isprime(unsigned int number)
{
	/* 不会传递偶数 */
	unsigned int div = 3;

    /*这个条件确保我们只检查小于 number 平方根的因数。
    这是因为如果 number 可以被一个大于其平方根的数整除，
    那么它必然也可以被一个小于其平方根的数整除。
    因此，只需要检查到平方根即可。
    number = a * b;
    如果(a > sqrt(number) && b > sqrt(number))
    那么 a * b > sqrt(number) * sqrt(number) = number
    所以a和b中至少有一个小于sqrt(number)
    因此，只需要检查到sqrt(number)即可。
    */
	while (div * div < number && number % div != 0)
		div += 2;

	return number % div != 0;
}
// 适用于较大的数字
static int isprime(unsigned int number)
{
    if (number <= 1) return 0;
    if (number <= 3) return 1;
    if (number % 2 == 0 || number % 3 == 0) return 0;

    unsigned int sqrt_number = (unsigned int)sqrt(number);
    for (unsigned int i = 5; i <= sqrt_number; i += 6) {
        if (number % i == 0 || number % (i + 2) == 0) {
            return 0;
        }
    }
    return 1;
}
```

## hcreate_r 创建哈希表
```c
int hcreate_r(size_t nel, struct hsearch_data *htab)
{
	/* 将 nel 更改为不小于 nel 的第一个质数. */
	nel |= 1;		/* 使奇数 */
	while (!isprime(nel))   //不是质数
		nel += 2;   //找到下一个质数

	htab->size = nel;
	htab->filled = 0;

	/*分配内存并归零 */
	htab->table = (struct env_entry_node *)calloc(htab->size + 1,
						sizeof(struct env_entry_node));
}
```

## hdestroy_r 销毁哈希表
```c
/* 使用哈希表后，必须将其销毁。可以释放已用内存，并将局部静态变量标记为未使用。
*/
void hdestroy_r(struct hsearch_data *htab)
{
	int i;
	for (i = 1; i <= htab->size; ++i) {
		if (htab->table[i].used > 0) {
			struct env_entry *ep = &htab->table[i].entry;

			free((void *)ep->key);
			free(ep->data);
		}
	}
	free(htab->table);
	htab->table = NULL;
}
```

## himport_r 键值对插入hash表
```c
1. 从输入数据中解析环境变量，将键值对插入哈希表。
2. 如果 crlf_is_lf 为 1，则将 CRLF 转换为 LF。
3. 如果 nvars 不为 0，则跳过不需要处理的变量。
4. 如果 flag 中包含 H_NOCLEAR，则不清除哈希表。
5. 如果 flag 中不包含 H_NOCLEAR，则销毁旧的哈希表，并创建新的哈希表。
6. 如果导入的环境中没有的变量将被删除。
7. 返回 1 表示插入成功，返回 0 表示插入失败。
/*
 * crlf_is_lf: 1 - 将CRLF转换为LF 0 - 不转换
 * nvars: 不要处理的键值对数
 * vars: 不要处理的键列表
 * 扩容策略：导入整个环境时,销毁旧的哈希表,创建新的哈希表;
*/
int himport_r(struct hsearch_data *htab,
		const char *env, size_t size, const char sep, int flag,
		int crlf_is_lf, int nvars, char * const vars[])
{
	char *data, *sp, *dp, *name, *value;
	char *localvars[nvars];
	int i;

	/* Test for correct arguments.  */
	if (htab == NULL) {
		__set_errno(EINVAL);
		return 0;
	}

	/* we allocate new space to make sure we can write to the array */
	if ((data = malloc(size + 1)) == NULL) {
		debug("himport_r: can't malloc %lu bytes\n", (ulong)size + 1);
		__set_errno(ENOMEM);
		return 0;
	}
	memcpy(data, env, size);
	data[size] = '\0';
	dp = data;

	/* make a local copy of the list of variables */
	if (nvars)
		memcpy(localvars, vars, sizeof(vars[0]) * nvars);

#if CONFIG_IS_ENABLED(ENV_APPEND)   //仅允许在环境变量中追加
	flag |= H_NOCLEAR;              //不允许删除环境变量
#endif
    //导入整个环境时,销毁旧的哈希表,创建新的哈希表
    //导入变量时,不销毁
	if ((flag & H_NOCLEAR) == 0 && !nvars) {
		/*销毁旧的哈希表（如果存在） */
		if (htab->table)
			hdestroy_r(htab);
	}

	/* 如果需要，创建新的哈希表。哈希表大小的计算基于启发式方法：
	在对一些70多个现有系统的样本中，我们发现环境中每个条目的平均大小为39+字节（对于整个键值对）。
	假设每个条目的大小为8（=安全系数约为5[负载因子0.2]）应该为任何现有的环境定义提供足够的安全边际，
	并且仍然允许足够多的动态添加,减少哈希冲突。
	请注意，“size”参数应该给出最大环境大小（CONFIG_ENV_SIZE）。
	这种启发式方法将导致对于大闪存环境（>8,000条目对于64 KB环境大小）来说不合理的大数字（以及内存占用），
	因此我们将其剪裁到一个合理的值。
    另一方面，当导入非常小的缓冲区时，我们需要添加一些条目以留出空闲空间。
	如果需要，这两个边界都可以在板配置文件中覆盖。*/
    //CONFIG_ENV_MIN_ENTRIES 预留的最小条目数
    //CONFIG_ENV_MAX_ENTRIES 最大条目数,
	if (!htab->table) {
		int nent = CONFIG_ENV_MIN_ENTRIES + size / 8;

		if (nent > CONFIG_ENV_MAX_ENTRIES)
			nent = CONFIG_ENV_MAX_ENTRIES;

		debug("Create Hash Table: N=%d\n", nent);

		if (hcreate_r(nent, htab) == 0) {
			free(data);
			return 0;
		}
    }
    //遍历输入数据，移除所有在换行字符（\n）前面的回车字符（\r），从而将 CRLF 序列转换为 LF 字符
	if(crlf_is_lf) {
		/*删除换行符前面的回车符*/
		unsigned ignored_crs = 0;
		for(;dp < data + size && *dp; ++dp) {
			if(*dp == '\r' &&
			   dp < data + size - 1 && *(dp+1) == '\n')
				++ignored_crs;
			else
				*(dp-ignored_crs) = *dp;
		}
		size -= ignored_crs;
		dp = data;
	}
	/* 解析环境;允许将 '\0' 和 'sep' 作为分隔符*/
	do {
		struct env_entry e, *rv;

		/*跳过前导空格*/
		while (isblank(*dp))
			++dp;

		/* 跳过注释行 */
		if (*dp == '#') {
			while (*dp && (*dp != sep))
				++dp;
			++dp;
			continue;
		}

		/* 解析名称*/
		for (name = dp; *dp != '=' && *dp && *dp != sep; ++dp)
			;

		/*处理 “name” 和 “name=” 条目 （删除 VAR） */
		if (*dp == '\0' || *(dp + 1) == '\0' ||
		    *dp == sep || *(dp + 1) == sep) {
			if (*dp == '=')
				*dp++ = '\0';
			*dp++ = '\0';	/* 终止名称*/

			debug("DELETE CANDIDATE: \"%s\"\n", name);
            //导入的环境中寻找该变量
			if (!drop_var_from_set(name, nvars, localvars))
				continue;

			if (hdelete_r(name, htab, flag))
				debug("DELETE ERROR ##############################\n");

			continue;
		}
		*dp++ = '\0';	/* terminate name */

		/* parse 值;处理转义字符 */
		for (value = sp = dp; *dp && (*dp != sep); ++dp) {
			if ((*dp == '\\') && *(dp + 1))
				++dp;
			*sp++ = *dp;
		}
		*sp++ = '\0';	/* terminate value */
		++dp;
        //没有键值对
		if (*name == 0) {
			debug("INSERT: unable to use an empty key\n");
			__set_errno(EINVAL);
			free(data);
			return 0;
		}
		/*跳过不应处理的变量 */
		if (!drop_var_from_set(name, nvars, localvars))
			continue;

		/*进入哈希表 */
		e.key = name;
		e.data = value;

		hsearch_r(e, ENV_ENTER, &rv, htab, flag);
#if !IS_ENABLED(CONFIG_ENV_WRITEABLE_LIST)  //没有定义仅可写链表的变量允许插入
		if (rv == NULL) {
			printf("himport_r: can't insert \"%s=%s\" into hash table\n",
				name, value);
		}
#endif

		debug("INSERT: table %p, filled %d/%d rv %p ==> name=\"%s\" value=\"%s\"\n",
			htab, htab->filled, htab->size,
			rv, name, value);
	} while ((dp < data + size) && *dp);	/* size check needed for text */
						/* without '\0' termination */
	debug("INSERT: free(data = %p)\n", data);
	free(data);

	if (flag & H_NOCLEAR)
		goto end;

	/* 导入的环境中没有的变量将被删除 */
	for (i = 0; i < nvars; i++) {
		if (localvars[i] == NULL)
			continue;
		//尝试从运行环境中删除变量
		if (hdelete_r(localvars[i], htab, flag))
			printf("WARNING: '%s' neither in running nor in imported env!\n", localvars[i]);
		else
			printf("WARNING: '%s' not in imported env, deleting it!\n", localvars[i]);
	}

end:
	debug("INSERT: done\n");
	return 1;		/* everything OK */
}
```

## hsearch_r 查找哈希表
```c
/*在内部哈希表中搜索与 item.key 匹配的条目。
如果操作是 ENV_FIND，则返回找到的条目或通过返回 NULL 来表示错误。
如果操作是 ENV_ENTER，则用 item.data 替换现有数据（如果有）。
*/
int hsearch_r(struct env_entry item, enum env_action action,
	      struct env_entry **retval, struct hsearch_data *htab, int flag)
{
	unsigned int hval;
	unsigned int count;
	unsigned int len = strlen(item.key);
	unsigned int idx;
	unsigned int first_deleted = 0;
	int ret;

	/*计算给定字符串的值。也许使用更好的方法。. */
	hval = len;
	count = len;
	while (count-- > 0) {
		hval <<= 4;
		hval += item.key[count];
	}

	/*
	 * 第一个哈希函数：
	 * 只取模但防止为零。
	 */
	hval %= htab->size;
	if (hval == 0)
		++hval;

	/* The first index tried. */
	idx = hval;
	//已经被使用,判定是墓碑还是正常使用
	if (htab->table[idx].used) {
		/*
		 * Further action might be required according to the
		 * action value.
		 */
		unsigned hval2;

		if (htab->table[idx].used == USED_DELETED)
			first_deleted = idx;
		//判定是否可以复写
		ret = _compare_and_overwrite_entry(item, action, retval, htab,
			flag, hval, idx);
		if (ret != -1)	//复写完成直接退出
			return ret;

		/*
		 * 第二个哈希函数：
		 * 如 [Knuth] 中所建议的那样
		 */
		hval2 = 1 + hval % (htab->size - 2);
		//探测序列:处理哈希冲突
		// 使用了双重哈希（Double Hashing）的方法来解决哈希冲突。双重哈希是一种开放地址法，通过使用两个不同的哈希函数来计算探测序列，从而减少冲突的概率。
		do {
			/*
			 * 因为 SIZE 是主要的，所以这保证了
			 * 逐步浏览所有可用的索引。
			 */
			if (idx <= hval2)
				idx = htab->size + idx - hval2;
			else
				idx -= hval2;

			/*
			 * 如果我们访问了所有条目，请离开循环
			 *失败。
			 */
			if (idx == hval)
				break;

			if (htab->table[idx].used == USED_DELETED
			    && !first_deleted)
				first_deleted = idx;

			//对找到的索引的键值对与需要插入的键值对进行比较
			ret = _compare_and_overwrite_entry(item, action, retval,
				htab, flag, hval, idx);
			if (ret != -1)	//找到了退出
				return ret;
		}
		//如果找到了空桶,则退出
		while (htab->table[idx].used != USED_FREE);
	}
	/* 发现了一个空桶。 */
	if (action == ENV_ENTER) {
		/*
		 * 如果表已满且需要输入另一个条目
		 * 返回错误。
		 */
		if (htab->filled == htab->size) {
			__set_errno(ENOMEM);
			*retval = NULL;
			return 0;
		}

		/*
		 * 创建新条目；
		 * 创建 item.key 和 item.data 的副本
		 */
		if (first_deleted)
			idx = first_deleted;

		htab->table[idx].used = hval;
		htab->table[idx].entry.key = strdup(item.key);
		htab->table[idx].entry.data = strdup(item.data);
		if (!htab->table[idx].entry.key ||
		    !htab->table[idx].entry.data) {
			__set_errno(ENOMEM);
			*retval = NULL;
			return 0;
		}

		++htab->filled;

		/* 这是一个新条目，因此请查找可能的回调 */
		env_callback_init(&htab->table[idx].entry);

		/* Also look for flags */
		env_flags_init(&htab->table[idx].entry);

		/* 检查权限 */
		if (htab->change_ok != NULL && htab->change_ok(
		    &htab->table[idx].entry, item.data, env_op_create, flag)) {
			debug("change_ok() rejected setting variable "
				"%s, skipping it!\n", item.key);
			_hdelete(item.key, htab, &htab->table[idx].entry, idx);
			__set_errno(EPERM);
			*retval = NULL;
			return 0;
		}

		/*如果有回调，请调用 */
		if (do_callback(&htab->table[idx].entry, item.key, item.data,
				env_op_create, flag)) {
			debug("callback() rejected setting variable "
				"%s, skipping it!\n", item.key);
			_hdelete(item.key, htab, &htab->table[idx].entry, idx);
			__set_errno(EINVAL);
			*retval = NULL;
			return 0;
        }
		/* return new entry */
		//如果中途不允许添加,则调用delete删除
		*retval = &htab->table[idx].entry;
		return 1;
	}

	__set_errno(ESRCH);
	*retval = NULL;
	return 0;
}
```

## hmatch_r 匹配哈希表
- 直接遍历哈希表，查找与 match 匹配的键值对。
```c
int hmatch_r(const char *match, int last_idx, struct env_entry **retval,
	     struct hsearch_data *htab)
{
	unsigned int idx;
	size_t key_len = strlen(match);

	for (idx = last_idx + 1; idx < htab->size; ++idx) {
		if (htab->table[idx].used <= 0)
			continue;
		if (!strncmp(match, htab->table[idx].entry.key, key_len)) {
			*retval = &htab->table[idx].entry;
			return idx;
		}
	}

	__set_errno(ESRCH);
	*retval = NULL;
	return 0;
}
```

## hdelete_r 删除哈希表中的键值对
1. 查找键值对是否存在
2. 如果存在，检查是否有权限删除
3. 如果有权限删除，检查是否有回调函数
4. 删除键值对,释放内存,并将标志设置为已删除(墓碑)
5. 但是条目仍然存在，因为可能有其他条目使用相同的哈希值
```c
/*
 * hdelete()
 */

/*
 * The standard implementation of hsearch(3) does not provide any way
 * to delete any entries from the hash table.  We extend the code to
 * do that.
 */

static void _hdelete(const char *key, struct hsearch_data *htab,
		     struct env_entry *ep, int idx)
{
	/* free used entry */
	debug("hdelete: DELETING key \"%s\"\n", key);
	free((void *)ep->key);
	free(ep->data);
	ep->flags = 0;
	htab->table[idx].used = USED_DELETED;

	--htab->filled;
}

int hdelete_r(const char *key, struct hsearch_data *htab, int flag)
{
	struct env_entry e, *ep;
	int idx;

	debug("hdelete: DELETE key \"%s\"\n", key);

	e.key = (char *)key;

	idx = hsearch_r(e, ENV_FIND, &ep, htab, 0);
	if (idx == 0) {
		__set_errno(ESRCH);
		return -ENOENT;	/* not found */
	}

	/* Check for permission */
	if (htab->change_ok != NULL &&
	    htab->change_ok(ep, NULL, env_op_delete, flag)) {
		debug("change_ok() rejected deleting variable "
			"%s, skipping it!\n", key);
		__set_errno(EPERM);
		return -EPERM;
	}

	/* If there is a callback, call it */
	if (do_callback(&htab->table[idx].entry, key, NULL,
			env_op_delete, flag)) {
		debug("callback() rejected deleting variable "
			"%s, skipping it!\n", key);
		__set_errno(EINVAL);
		return -EINVAL;
	}

	_hdelete(key, htab, ep, idx);

	return 0;
}
```

## hexport_r 导出哈希表
1. 遍历哈希表，将键值对导出为字符串。
2. 对键排序，以便输出结果一致。
3. 导出

```c
ssize_t hexport_r(struct hsearch_data *htab, const char sep, int flag,
		 char **resp, size_t size,
		 int argc, char *const argv[])
{
	struct env_entry *list[htab->size];
	char *res, *p;
	size_t totlen;
	int i, n;

	/* Test for correct arguments.  */
	if ((resp == NULL) || (htab == NULL)) {
		__set_errno(EINVAL);
		return (-1);
	}

	debug("EXPORT  table = %p, htab.size = %d, htab.filled = %d, size = %lu\n",
	      htab, htab->size, htab->filled, (ulong)size);
	/*
	 * 通行证 1：
	 * 搜索已使用的条目，
	 * 保存地址并计算总长度
	 */
	for (i = 1, n = 0, totlen = 0; i <= htab->size; ++i) {

		if (htab->table[i].used > 0) {
			struct env_entry *ep = &htab->table[i].entry;
			int found = match_entry(ep, flag, argc, argv);

			if ((argc > 0) && (found == 0))
				continue;

			if ((flag & H_HIDE_DOT) && ep->key[0] == '.')
				continue;

			list[n++] = ep;

			totlen += strlen(ep->key);

			if (sep == '\0') {
				totlen += strlen(ep->data);
			} else {	/* check if escapes are needed */
				char *s = ep->data;

				while (*s) {
					++totlen;
					/* add room for needed escape chars */
					if ((*s == sep) || (*s == '\\'))
						++totlen;
					++s;
				}
			}
			totlen += 2;	/* for '=' and 'sep' char */
		}
	}

#ifdef DEBUG
	/* Pass 1a: print unsorted list */
	printf("Unsorted: n=%d\n", n);
	for (i = 0; i < n; ++i) {
		printf("\t%3d: %p ==> %-10s => %s\n",
		       i, list[i], list[i]->key, list[i]->data);
	}
#endif

	/*按键排序列表 */
	qsort(list, n, sizeof(struct env_entry *), cmpkey);

	/* Check if the user supplied buffer size is sufficient */
	if (size) {
		if (size < totlen + 1) {	/* provided buffer too small */
			printf("Env export buffer too small: %lu, but need %lu\n",
			       (ulong)size, (ulong)totlen + 1);
			__set_errno(ENOMEM);
			return (-1);
		}
	} else {
		size = totlen + 1;
	}

	/* Check if the user provided a buffer */
	if (*resp) {
		/* yes; clear it */
		res = *resp;
		memset(res, '\0', size);
	} else {
		/* no, allocate and clear one */
		*resp = res = calloc(1, size);
		if (res == NULL) {
			__set_errno(ENOMEM);
			return (-1);
		}
	}
	/*
	 * 通行证 2：
	 * 导出结果数据的排序列表
	 */
	for (i = 0, p = res; i < n; ++i) {
		const char *s;

		s = list[i]->key;
		while (*s)
			*p++ = *s++;
		*p++ = '=';

		s = list[i]->data;

		while (*s) {
			if ((*s == sep) || (*s == '\\'))
				*p++ = '\\';	/* escape */
			*p++ = *s++;
		}
		*p++ = sep;
	}
	*p = '\0';		/* terminate result */

	return size;
}
```

## hwalk_r 对哈希表中的每个键值对执行回调
```c
/*
 * 遍历 hash 中的所有条目，为每个条目调用 callback。
 * 这允许对每个元素执行一些通用操作。
 */
int hwalk_r(struct hsearch_data *htab, int (*callback)(struct env_entry *entry))
{
	int i;
	int retval;

	for (i = 1; i <= htab->size; ++i) {
		if (htab->table[i].used > 0) {
			retval = callback(&htab->table[i].entry);
			if (retval)
				return retval;
		}
	}

	return 0;
}
```

## _compare_and_overwrite_entry 复写现有条目
1. 当前桶已经被使用，检查是否有相同的哈希码
2. 如果有相同的哈希码，检查是否有相同的键
3. 如果有不同的键，则释放旧的键和数据，替换为新的键和数据

## drop_var_from_set 判定name是否在vars[]中
```c
/*
 * 检查变量 'name' 是否在 vars[] 中，并通过将指针设置为 NULL 来删除所有实例
 * 检查变量 'name' 是否在 vars[] 中，如果是，则将指针设置为 NULL，以删除所有实例
 * 返回1表示找到了变量，返回0表示未找到
 */
static int drop_var_from_set(const char *name, int nvars, char * vars[])
{
	int i = 0;
	int res = 0;

	/* No variables specified means process all of them */
	if (nvars == 0)
		return 1;

	for (i = 0; i < nvars; i++) {
		if (vars[i] == NULL)
			continue;
		/* If we found it, delete all of them */
		if (!strcmp(name, vars[i])) {
			vars[i] = NULL;
			res = 1;
		}
	}
	if (!res)
		debug("Skipping non-listed variable %s\n", name);

	return res;
}
```
