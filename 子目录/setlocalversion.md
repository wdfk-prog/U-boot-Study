---
title: setlocalversion
date: 2025-10-03 09:44:27
categories:
  - uboot
  - 子目录
tags:
  - uboot
  - 子目录
---
[TOC]

```sh
KERNELVERSION="5.10.0"

# 变量默认值与传入赋值
no_local=false
if test "$1" = "--no-local"; then
	no_local=true
	shift
fi
# 变量默认值与传入赋值
srctree=.
if test $# -gt 0; then
	srctree=$1
	shift
fi
# 检查脚本输入参数>0或者$srctree路径不存在
if test $# -gt 0 -o ! -d "$srctree"; then
	usage
fi

scm_version()
{
	local short=false
	local no_dirty=false
	local tag

	while [ $# -gt 0 ];
	do
		case "$1" in
		--short)
			short=true;;
		--no-dirty)
			no_dirty=true;;
		esac
		shift
	done

	cd "$srctree"

	# 检查当前目录是否在一个 Git 仓库中。
	if test -n "$(git rev-parse --show-cdup 2>/dev/null)"; then
		return
	fi
	# 验证 Git 仓库的 HEAD 引用
	if ! head=$(git rev-parse --verify HEAD 2>/dev/null); then
		return
	fi

	# mainline kernel:  6.2.0-rc5  ->  v6.2-rc5
	# stable kernel:    6.1.7      ->  v6.1.7

    # 生成一个版本标签 version_tag
	version_tag=v$(echo "${KERNELVERSION}" | sed -E 's/^([0-9]+\.[0-9]+)\.0(.*)$/\1\2/')

	# 如果存在 localversion* 文件，并且存在相应的带注释的标记，并且它是 HEAD 的祖先，请使用它。在 linux-next 中就是这种情况。
	tag=${file_localversion#-}
	desc=
	if [ -n "${tag}" ]; then
		desc=$(git describe --match=$tag 2>/dev/null)
	fi

	# 否则，如果存在 localversion* 文件，并且通过将其附加到派生自
	# KERNELVERSION 存在并且是 HEAD 的祖先，请使用它。例如，在 linux-rt 中就是这种情况。
	if [ -z "${desc}" ] && [ -n "${file_localversion}" ]; then
		tag="${version_tag}${file_localversion}"
		desc=$(git describe --match=$tag 2>/dev/null)
	fi

	# 否则，默认为从 KERNELVERSION 派生的带注释的标记。
	if [ -z "${desc}" ]; then
		tag="${version_tag}"
		desc=$(git describe --match=$tag 2>/dev/null)
	fi

	# 如果我们在标记的提交中，我们会忽略它，因为版本定义明确。
	if [ "${tag}" != "${desc}" ]; then

		# 如果只请求简短版本，请不要费心运行进一步的 git 命令
		if $short; then
			echo "+"
			return
		fi
		# 如果我们超过了标记的提交，我们会漂亮地打印它。
		# （如 6.1.0-14595-g292a089d78d3）
		if [ -n "${desc}" ]; then
			echo "${desc}" | awk -F- '{printf("-%05d", $(NF-1))}'
		fi

		# 添加 -g 和恰好 12 个十六进制字符。
		printf '%s%s' -g "$(echo $head | cut -c1-12)"
	fi

	if ${no_dirty}; then
		return
	fi

	# 检查未提交的更改。
	# 此脚本必须避免对源树进行任何写入尝试，这可能是只读的。
	# 你不能使用 'git describe --dirty'，因为它会尝试创建
	# .git/index.lock 的 .
	# 首先，使用 git-status，但 --no-optional-locks 仅在 git >= 2.14 中受支持，因此如果失败，请回退到 git-diff-index。请注意，git-diff-index 不会刷新索引，因此可能会给出误导性的结果。
	# 参见 git-update-index（1）、git-diff-index（1） 和 git-status（1）。
	if {
		git --no-optional-locks status -uno --porcelain 2>/dev/null ||
		git diff-index --name-only HEAD
	} | read dummy; then
		printf '%s' -dirty
	fi
}

collect_files()
{
	local file res=

	for file; do
		# 用于检查文件名是否包含 ~ 字符。如果文件名包含 ~，则跳过该文件（通常表示临时文件或备份文件）
		case "$file" in
		*\~*)
			continue
			;;
		esac
		# 行代码检查文件是否存在。如果文件存在，则读取文件内容并将其追加到 res 变量中
		if test -e "$file"; then
			res="$res$(cat "$file")"
		fi
	done
	echo "$res"
}

if [ -z "${KERNELVERSION}" ]; then
	echo "KERNELVERSION is not set" >&2
	exit 1
fi

# localVersion* 文件位于 build 和 source 目录中
file_localversion="$(collect_files localversion*)"
# 检查 srctree 目录是否与当前目录不同，如果不同，则将当前目录下的 localversion* 文件内容追加到 file_localversion 变量中
if test ! "$srctree" -ef .; then
	file_localversion="${file_localversion}$(collect_files "$srctree"/localversion*)"
fi

if ${no_local}; then
	echo "${KERNELVERSION}$(scm_version --no-dirty)"
	exit 0
fi

if ! test -e include/config/auto.conf; then
	echo "Error: kernelrelease not valid - run 'make prepare' to update it" >&2
	exit 1
fi

# CONFIG_LOCALVERSION version 字符串
# 从配置文件 auto.conf 中提取版本字符串 CONFIG_LOCALVERSION
# 这里是空的
config_localversion=$(sed -n 's/^CONFIG_LOCALVERSION=\(.*\)$/\1/p' include/config/auto.conf | tr -d '"')

# scm 版本字符串（如果不在 kernel version 标记或 file_localversion

# 检查 auto.conf 文件中是否包含 CONFIG_LOCALVERSION_AUTO=y
if grep -q "^CONFIG_LOCALVERSION_AUTO=y$" include/config/auto.conf; then
	# 完整的 SCM 版本字符串
	scm_version="$(scm_version)"
elif [ "${LOCALVERSION+set}" != "set" ]; then
	# 如果未设置变量 LOCALVERSION，则如果存储库未处于干净的注释或签名标记状态，则附加一个加号（因为 git describe 仅查看已签名或已注释的标记 - git tag -a/-s）。
	# 如果设置了变量 LOCALVERSION（包括设置为空字符串），则我们不想附加加号。
	scm_version="$(scm_version --short)"
fi
# ${file_localversion}${config_localversion}${LOCALVERSION} 为空
echo "${KERNELVERSION}${file_localversion}${config_localversion}${LOCALVERSION}${scm_version}"
```