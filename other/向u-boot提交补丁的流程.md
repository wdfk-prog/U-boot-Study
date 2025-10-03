---
title: 向u-boot提交补丁的流程
date: 2025-10-03 10:58:55
categories:
  - uboot
  - other
tags:
  - uboot
  - other
---

@[toc]
![在这里插入图片描述](https://i-blog.csdnimg.cn/direct/9b1f5b2a1ac844ba83301a5eef97734a.png)

# 首先需要订阅一下，地址在此https://lists.denx.de/listinfo/u-boot，使邮箱地址对应有一个成员名称，才能向uboot社区发送补丁，否则会收到Post by non-member to a members-only list

    2. 注册完毕即可发送补丁，发送完之后即可在https://patchwork.ozlabs.org/project/uboot/list/看到了(首次贡献的话发送完补丁后需要等待至少12个小时才会将发送的补丁显示在patchwork上)。

3. 观看如下文档的步骤使用patman工具
> https://docs.u-boot.org/en/latest/develop/sending_patches.html

4. pip install patch-manager
5. git config sendemail.aliasesfile doc/git-mailrc
	- 使用`git config --list | grep sendemail`检查是否生效
6. `patman send -n`试运行,并不会真的发出去
7. 根据报错信息进行检测修改
	- 例如 error 和 waring
	- 添加标签信息到commit中;主要是`Series-to: `和`Reviewed-by: `
8. 注意git的全局config中需要带有user和email信息
	- 使用`vim ~/.gitconfig` 设置
9.  使用`patman send`进行发送邮件
	- 如果报错SMTP,则检查 `git sendemail`的配置是否具有和有效
	- 参考 如下
	> https://blog.csdn.net/weixin_45175803/article/details/118604992
	- qq邮箱参考如下
> https://laowangblog.com/qq-mail-smtp-service.html

10. patch格式注意
- **注意**:可以参考该补丁的信息,例如第一次和被审阅之后怎么发送的格式
> https://lore.kernel.org/u-boot/20241220222612.1757884-1-trini@konsulko.com/T/#me93a6e7f1307c05e355fa8405eaa18713026a544

- 开头会自动帮忙填充[PATCH /*//*],
- form后面的发件人,只需要名称,不需要邮箱地址,避免接收钓鱼邮件
```c
* [PATCH 0/6] Rework the BLK symbol usage in Kconfig
@ 2024-12-20 22:22 Tom Rini
  2024-12-20 22:22 ` [PATCH 1/6] drivers/mmc/Kconfig: Remove extraneous BLK dependencies Tom Rini
                   ` (6 more replies)
  0 siblings, 7 replies; 37+ messages in thread
From: Tom Rini @ 2024-12-20 22:22 UTC (permalink / raw)
  To: u-boot

Hey all,

One problem we have today is how the BLK symbol is set and used in
Kconfig files. Part of the challenge is that we use it as a gating
symbol for "we have a block device" and also for "enable block device
library code". What this series does is move to always use "select BLK"
by block drivers (a few were and a few others had it the inverse) and
then "depends on BLK" for functionality that needs a block device
present. The end result of this series is that a number of platforms
which had disabled EFI_LOADER now don't ask for it (they have no block
device) and espresso7420 has a regression about MMC support fixed.

-- 
Tom
```
-  **注意**:不要手动将review -by添加到提交日志中,是需要被review过了再添加该标签;
	-	在上述邮件中,第一次patch并没有review - by信息

- 下面这个是审阅者的回复,才需要加上Reviewed-by:信息
```c
* Re: [PATCH 3/6] efi_loader: Depend on BLK
  2024-12-20 22:22 ` [PATCH 3/6] efi_loader: Depend on BLK Tom Rini
@ 2024-12-20 22:50   ` Heinrich Schuchardt
  0 siblings, 0 replies; 37+ messages in thread
From: Heinrich Schuchardt @ 2024-12-20 22:50 UTC (permalink / raw)
  To: Tom Rini, u-boot; +Cc: Ilias Apalodimas

Am 20. Dezember 2024 23:22:19 MEZ schrieb Tom Rini <trini@konsulko.com>:
>In reworking the BLK usage in Kconfig, I found there's a few issues with
>EFI_LOADER=y and BLK=n. In general, we can easily say that
>lib/efi_loader/efi_file.c also should only be built with CONFIG_BLK.
>That however leaves the bootmgr code, eficonfig code and then parts of
>efi_device_path.c, efi_boottime.c and efi_setup.c which functionally
>depend on BLK. While these calls can be if'd out, I'm unsure if the
>result is usable. So rather than leave that buildable and imply that it
>is, I'm leaving that combination non-buildable and commenting that
>EFI_LOADER depends on BLK in the Kconfig currently.

EFI booting using only PXE or HTTP should be possible. But I admit we did not work on support for diskless devices, yet.


>
>Signed-off-by: Tom Rini <trini@konsulko.com>

Reviewed-by: Heinrich Schuchardt <xypron.glpk@gmx.de>
```
- 这样再后续的邮件中就可以带上了Reviewed-by信息
```c
From: Tom Rini @ 2025-01-15  1:22 UTC (permalink / raw)
  To: u-boot; +Cc: Heinrich Schuchardt

In reworking the BLK usage in Kconfig, I found there's a few issues with
EFI_LOADER=y and BLK=n. In general, we can easily say that
lib/efi_loader/efi_file.c also should only be built with CONFIG_BLK.
That however leaves the bootmgr code, eficonfig code and then parts of
efi_device_path.c, efi_boottime.c and efi_setup.c which functionally
depend on BLK. While these calls can be if'd out, I'm unsure if the
result is usable. So rather than leave that buildable and imply that it
is, I'm leaving that combination non-buildable and commenting that
EFI_LOADER depends on BLK in the Kconfig currently.

Signed-off-by: Tom Rini <trini@konsulko.com>
Reviewed-by: Heinrich Schuchardt <xypron.glpk@gmx.de>
---
```

- **注意**:如果特定需要某人审核该补丁,使用cc标签代替


 11. 发送成功后可以在自己的邮箱收到这个pr的信息
![在这里插入图片描述](https://i-blog.csdnimg.cn/direct/159d2ea22cba42cea093e2ac44bd640d.png)
![在这里插入图片描述](https://i-blog.csdnimg.cn/direct/f3ddffc0af794886b6a40f323b7665a4.png)
# 在收到评论或修改意见后提交更新补丁的流程
1. [参考流程](https://docs.u-boot.org/en/latest/develop/patman.html#example-work-flow)
2. 看看 patchwork 并找出该系列的 URL。这将类似于http://patchwork.ozlabs.org/project/uboot/list/?series=187331 将其添加到顶部提交中的标签中：
Series-links: 187331
3. 在https://patchwork.ozlabs.org/project/uboot/list/?order=submitter中的Submitter 搜索自己,找出需要修改的补丁
![在这里插入图片描述](https://i-blog.csdnimg.cn/direct/08df899ee47d4e25b0844124a00de941.png)
4. 点击Series进入查看网站
![在这里插入图片描述](https://i-blog.csdnimg.cn/direct/2aff7e67bb1d4cd18fe84c8669885940.png)
5. 将数字复制填入commit中;例如:Series-links: 187331
![在这里插入图片描述](https://i-blog.csdnimg.cn/direct/cace2465119f41ee8317dca139e08aeb.png)
6. 可以额外的操作
然后您可以使用 patman 将 Acked-by 标签收集到正确的提交，为 us-cmd 创建一个新的“版本 2”分支：

patman status -d us-cmd2
git checkout us-cmd2
You can look at the comments in Patchwork or with:
您可以查看 Patchwork 中的评论或使用：

patman status -C
Then you can resync with upstream:
然后您可以与上游重新同步：

git fetch origin        # or whatever upstream is called
git rebase origin/master

7. 填写Series-changes
最后，您需要向您更改的两个提交添加更改日志。您将更改日志添加到发生更改的每个单独提交中，如下所示：

Series-changes: 2
- Updated the command decoder to reduce code size
- Wound the torque propounder up a little more
(note the blank line at the end of the list)
（注意列表末尾的空行）

8. 填写Series-version
9. 进行发送既可,注意patch中具有[PATCH V]的标志,没有是错误的

# review 之后的流程
- 补丁提交到社区后，就可以在邮件列表中收到。若补丁发出后一至两周或者更长时间没有回复，可回复“ping”提醒一下，注意不要频繁 ping。
- 有人 review 或者 ack，补丁不需要继续操作，等 Maintainer 合入即可。
# 注意事项
1. gitconfig 中的 from必须要有邮箱地址 
2. patman 有警告或者错误,但是想强制发送
```sh
patman send --ignore-errors
```