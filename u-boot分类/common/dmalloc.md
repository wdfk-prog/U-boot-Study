---
title: dmalloc
categories:
  - uboot
  - u-boot分类
  - common
tags:
  - uboot
  - u-boot分类
  - common
abbrlink: f44ec884
date: 2025-10-03 09:44:27
---
# dlmalloc.c

dlmalloc 是 Doug Lea 实现的一种动态内存分配器，广泛用于嵌入式系统和操作系统中。它以其高效和灵活的内存管理机制而著称。以下是 dlmalloc 的工作原理和关键概念：

1. 内存池（Memory Pool）
dlmalloc 使用一个或多个内存池来管理内存。内存池是由操作系统分配的一大块连续内存区域，dlmalloc 在这个区域内进行内存分配和释放操作。

2. 空闲块和已分配块（Free and Allocated Blocks）
内存池被分割成多个块，每个块可以是空闲的或已分配的。每个块都有一个头部（header），包含块的大小和状态（空闲或已分配）。

3. 双向链表（Doubly Linked List）
空闲块通过双向链表链接在一起。每个空闲块的头部包含指向前一个和后一个空闲块的指针。这使得 dlmalloc 可以高效地插入和删除空闲块。

4. 分割和合并（Splitting and Coalescing）
分割：当请求的内存大小小于某个空闲块的大小时，dlmalloc 会将这个空闲块分割成两个块，一个满足请求大小，另一个继续作为空闲块。
合并：当释放一个块时，dlmalloc 会检查相邻的块是否也是空闲的。如果是，它们会被合并成一个更大的空闲块。这减少了内存碎片，提高了内存利用率。
5. 最佳适配（Best Fit）和首次适配（First Fit）
dlmalloc 使用最佳适配或首次适配策略来找到合适的空闲块：

最佳适配：在所有空闲块中找到最小的、但足够大的块来满足请求。这减少了内存碎片，但可能需要更多的时间来搜索。
首次适配：从头开始搜索，找到第一个足够大的块。这速度较快，但可能会增加内存碎片。
6. 扩展和收缩（Expansion and Contraction）
当内存池中的空闲块不足以满足请求时，dlmalloc 可以向操作系统请求更多的内存（扩展）。当内存使用减少时，它也可以将未使用的内存归还给操作系统（收缩）。

7. 内存对齐（Memory Alignment）
dlmalloc 确保分配的内存块是对齐的，以满足特定硬件或数据结构的要求。这通常通过调整块的起始地址来实现。

### mem_malloc_init
```c
ulong mem_malloc_start = 0;
ulong mem_malloc_end = 0;
ulong mem_malloc_brk = 0;

void mem_malloc_init(ulong start, ulong size)
{
    mem_malloc_start = (ulong)map_sysmem(start, size);
    mem_malloc_end = mem_malloc_start + size;
    mem_malloc_brk = mem_malloc_start;

#ifdef CONFIG_SYS_MALLOC_DEFAULT_TO_INIT
    malloc_init();
#endif

    debug("using memory %#lx-%#lx for malloc()\n", mem_malloc_start,
          mem_malloc_end);
#if CONFIG_IS_ENABLED(SYS_MALLOC_CLEAR_ON_INIT)
    memset((void *)mem_malloc_start, 0x0, size);
#endif
}
```