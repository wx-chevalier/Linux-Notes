# mmap 的内核实现

# 延时分配

参考如下简单的 mmap 使用代码：

```c
#include <stdio.h>
#include <sys/mman.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
  void *p;
  sleep(5);

  p = mmap(NULL, 1, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (p == MAP_FAILED) {
    perror("mmap");
    return -1;
  }

  printf("%p\n", p);
  sleep(5);
  return 0;
}
```

执行该程序，输出 mmap 方法返回的内存地址，同时使用 pmap 命令输出该程序执行 mmap 之前以及之后的内存使用情况。mmap 方法返回的内存地址：

```sh
$ ./a.out
0x7f521d667000
```

pmap 命令的两次输出结果：

```sh
$ pmap -x $(pgrep a.out)
32408:   ./a.out
Address           Kbytes     RSS   Dirty Mode  Mapping
0000555bb0511000       4       4       0 r---- a.out
0000555bb0512000       4       4       0 r-x-- a.out
0000555bb0513000       4       0       0 r---- a.out
0000555bb0514000       4       4       4 r---- a.out
0000555bb0515000       4       4       4 rw--- a.out
00007f521d45e000     148     140       0 r---- libc-2.29.so
00007f521d483000    1320     628       0 r-x-- libc-2.29.so
00007f521d5cd000     292      64       0 r---- libc-2.29.so
00007f521d616000       4       0       0 ----- libc-2.29.so
00007f521d617000      12      12      12 r---- libc-2.29.so
00007f521d61a000      12      12      12 rw--- libc-2.29.so
00007f521d61d000      24      16      16 rw---   [ anon ]
00007f521d63e000       8       8       0 r---- ld-2.29.so
00007f521d640000     124     124       0 r-x-- ld-2.29.so
00007f521d65f000      32      32       0 r---- ld-2.29.so
00007f521d668000       4       4       4 r---- ld-2.29.so
00007f521d669000       4       4       4 rw--- ld-2.29.so
00007f521d66a000       4       4       4 rw---   [ anon ]
00007fffd1e55000     132      12      12 rw---   [ stack ]
00007fffd1f04000      12       0       0 r----   [ anon ]
00007fffd1f07000       4       4       0 r-x--   [ anon ]
---------------- ------- ------- -------
total kB            2156    1080      72

$ pmap -x $(pgrep a.out)
32408:   ./a.out
Address           Kbytes     RSS   Dirty Mode  Mapping
0000555bb0511000       4       4       0 r---- a.out
0000555bb0512000       4       4       0 r-x-- a.out
0000555bb0513000       4       4       0 r---- a.out
0000555bb0514000       4       4       4 r---- a.out
0000555bb0515000       4       4       4 rw--- a.out
0000555bb1b7a000     132       4       4 rw---   [ anon ]
00007f521d45e000     148     140       0 r---- libc-2.29.so
00007f521d483000    1320     948       0 r-x-- libc-2.29.so
00007f521d5cd000     292     128       0 r---- libc-2.29.so
00007f521d616000       4       0       0 ----- libc-2.29.so
00007f521d617000      12      12      12 r---- libc-2.29.so
00007f521d61a000      12      12      12 rw--- libc-2.29.so
00007f521d61d000      24      16      16 rw---   [ anon ]
00007f521d63e000       8       8       0 r---- ld-2.29.so
00007f521d640000     124     124       0 r-x-- ld-2.29.so
00007f521d65f000      32      32       0 r---- ld-2.29.so
00007f521d667000       4       0       0 rw---   [ anon ]
00007f521d668000       4       4       4 r---- ld-2.29.so
00007f521d669000       4       4       4 rw--- ld-2.29.so
00007f521d66a000       4       4       4 rw---   [ anon ]
00007fffd1e55000     132      12      12 rw---   [ stack ]
00007fffd1f04000      12       0       0 r----   [ anon ]
00007fffd1f07000       4       4       0 r-x--   [ anon ]
---------------- ------- ------- -------
total kB            2292    1472      76
```

在 pmap 命令的前后两次输出中，我们可以看到，第二次 pmap 输出多了一个 [anon] 内存段（第 47 行），而该内存段的起始地址正好是上面程序输出的地址。也就是说，该内存段就是操作系统为 mmap 系统调用新分配出来的区域。由 pmap 的输出可以看到，该内存段的大小是 4kb，实际物理内存占用（rss）是 0。

实际物理内存占用为什么是 0 呢？在我们向操作系统申请内存时，比如用 malloc 或 mmap 等方式，操作系统只是标记了我们拥有一段新的内存区域，如上 pmap 输出，而并没有实际分配给我们物理内存。当我们要使用该段内存时，比如读或写，会先触发 page fault，操作系统内部的 page fault handler 会检查触发 page fault 的地址是否是我们拥有的合法地址，如果是，则在此时真正为我们分配物理内存。

# 按页分配

再看下上面的源码，我们指定的内存长度明明是 1 字节，为什么 pmap 的显示是 4kb 呢？这个在下面的源码分析中会看到原因。看下 mmap 系统调用对应的内核源码：

```c
// arch/x86/kernel/sys_x86_64.c
SYSCALL_DEFINE6(mmap, unsigned long, addr, unsigned long, len,
                unsigned long, prot, unsigned long, flags,
                unsigned long, fd, unsigned long, off)
{
        long error;
        error = -EINVAL;
        if (off & ~PAGE_MASK)
                goto out;

        error = ksys_mmap_pgoff(addr, len, prot, flags, fd, off >> PAGE_SHIFT);
out:
        return error;
}
```

该方法调用了 ksys_mmap_pgoff 方法：

```c
// mm/mmap.c
unsigned long ksys_mmap_pgoff(unsigned long addr, unsigned long len,
                              unsigned long prot, unsigned long flags,
                              unsigned long fd, unsigned long pgoff)
{
        struct file *file = NULL;
        unsigned long retval;

        if (!(flags & MAP_ANONYMOUS)) {
                ...
                file = fget(fd);
                ...
        }
        ...
        retval = vm_mmap_pgoff(file, addr, len, prot, flags, pgoff);
        ...
        return retval;
}
```

该方法又调用了 vm_mmap_pgoff：

```c
// mm/util.c
unsigned  longvm_mmap_pgoff(struct file *file, unsigned long addr,
        unsigned long len, unsigned long prot,
        unsigned long flag, unsigned long pgoff)
{
        unsigned long ret;
        struct mm_struct *mm = current->mm;
        ...
        if (!ret) {
                ...
                ret = do_mmap_pgoff(file, addr, len, prot, flag, pgoff,
                                    &populate, &uf);
                ...
        }
        return ret;
}
```

该方法又调用了 do_mmap_pgoff：

```c
// include/linux/mm.h
static inline unsigned long
do_mmap_pgoff(struct file *file, unsigned long addr,
        unsigned long len, unsigned long prot, unsigned long flags,
        unsigned long pgoff, unsigned long *populate,
        struct list_head *uf)
{
        return do_mmap(file, addr, len, prot, flags, 0, pgoff, populate, uf);
}
```

该方法又调用了 do_mmap：

```c
// mm/mmap.c
unsigned long do_mmap(struct file *file, unsigned long addr,
                        unsigned long len, unsigned long prot,
                        unsigned long flags, vm_flags_t vm_flags,
                        unsigned long pgoff, unsigned long *populate,
                        struct list_head *uf)
{
        struct mm_struct *mm = current->mm;
        ...
        len = PAGE_ALIGN(len);
        ...
        addr = get_unmapped_area(file, addr, len, pgoff, flags);
        ...
        addr = mmap_region(file, addr, len, vm_flags, pgoff, uf);
        ...
        return addr;
}
```

该方法先用宏 PAGE_ALIGN，使 len 大小 page 对齐，在最开始的源码中，我们指定的 len 大小为 1，page 对其后为 4096，即 4kb，这也是为什么 pmap 输出的内存段大小为 4kb。其实，操作系统为进程分配的内存段都是以 page 为单位的。

之后，该方法又调用了 get_unmapped_area 来获取 mmap 的内存段的起始地址，这个方法就不详细看了。最后，该方法又调用了 mmap_region，继续执行 mmap 操作。

```c
// mm/mmap.c
unsigned long mmap_region(struct file *file, unsigned long addr,
                unsigned long len, vm_flags_t vm_flags, unsigned long pgoff,
                struct list_head *uf)
{
        struct mm_struct *mm = current->mm;
        struct vm_area_struct *vma, *prev;
        ...
        vma = vm_area_alloc(mm);
        ...
        vma->vm_start = addr;
        vma->vm_end = addr + len;
        vma->vm_flags = vm_flags;
        vma->vm_page_prot = vm_get_page_prot(vm_flags);
        vma->vm_pgoff = pgoff;

        if (file) {
                ...
                vma->vm_file = get_file(file);
                error = call_mmap(file, vma);
                ...
        } else if (vm_flags & VM_SHARED) {
                ...
        } else {
                vma_set_anonymous(vma);
        }

        vma_link(mm, vma, prev, rb_link, rb_parent);
        ...
        return addr;
        ...
}
```

该方法先调用 vm_area_alloc，分配一个类型为 struct vm_area_struct 的实例，并赋值给 vma，然后设置 vma 的起始地址、结束地址等信息。这个 vma 里包含的内容，就是上面 pmap 命令输出的内存段。之后，如果我们是想 mmap 一个 file，则调用 call_mmap：

```c
// include/linux/fs.h
static inline int call_mmap(struct file *file, struct vm_area_struct *vma)
{
        return file->f_op->mmap(file, vma);
}
```

该方法又调用了 file->f_op->mmap 指针指向的方法，以 ext4 文件系统为例，该方法为 ext4_file_mmap：

```c
// fs/ext4/file.c
static int ext4_file_mmap(struct file *file, struct vm_area_struct *vma)
{
        ...
        if (IS_DAX(file_inode(file))) {
                ...
        } else {
                vma->vm_ops = &ext4_file_vm_ops;
        }
        return 0;
}
```

该方法的作用是初始化 vma 的 vm_ops 字段，使其值为 ext4_file_vm_ops。再回到上面的 mmap_region 方法，如果我们 mmap 的是一块 anonymous 的内存区域，则会调用 vma_set_anonymous 方法：

```c
// include/linux/mm.h
static inline void vma_set_anonymous(struct vm_area_struct *vma)
{
        vma->vm_ops = NULL;
}
```

该方法将 vma->vm_ops 字段设置为 null，用此来表示，该 vma 代表的内存段为 anonymous 模式。再之后，mmap_region 方法会调用 vma_link 方法将新创建的 vma 链接到 struct mm_struct 的 mmap 字段和 mm_rb 字段，标识该进程拥有 vma 表示的这段内存区域。最后，mmap_region 方法返回该内存段的起始地址给用户。

# Page Fault

上文中提及，当我们向操作系统申请内存时，操作系统并不是直接分配给我们物理内存，而是只标记当前进程拥有该段内存，当真正使用这段段内存时才会分配。
