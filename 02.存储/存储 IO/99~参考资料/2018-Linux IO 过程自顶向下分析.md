### 前言

IO 是操作系统内核最重要的组成部分之一，它的概念很广，本文主要针对的是普通文件与设备文件的 IO 原理，采用自顶向下的方式，去探究从用户态的 fread,fwrite 函数到底层的数据是如何被读出和写入磁盘的的全过程。希望通过本文，能梳理出一条清晰的 linux io 过程的脉络。

### 文件与存储

普通文件与设备文件的 IO 集中解决了数据的存储与持久化的问题。正如进程是内核对 CPU 的抽象，虚拟内存是对物理内存的抽象，文件是对所有 IO 对象的抽象（在本文，则主要是指对磁盘的抽象）。为了解决数据存储与持久化问题，有很多不同类型的文件系统（ext2,ext3,ext4,xfs,…)，它们大多数是工作在内核态的，也有少数的用户态文件系统（fuse）。linux 为了便于管理这些不同的文件系统，提出了一个虚拟文件系统（VFS）的概念，对这些不同的文件系统提供了一套统一的对外接口。本文将会从虚拟文件系统说起，自顶向下地去阐述 io 的每一层的概念。

[![高速缓存交互](https://assets.ng-tech.icu/item/mmap.png)](https://assets.ng-tech.icu/item/mmap.png)

### linux io 体系结构

[![linux io体系结构](https://assets.ng-tech.icu/item/io-structure.png)](https://assets.ng-tech.icu/item/io-structure.png)

本文将按照上图的架构自顶向下依次分析每一层的要点。

### 从 Hello world 说起

```
#include "apue.h"

      #define BUFFSIZE        4096

      int
      main(void)
      {
              int             n;
              char    buf[BUFFSIZE];
              int fd1;
              int fd2;

              fd1 = open("helloworld.in", O_RONLY);
              fd2 = open("helloworld.out", O_WRONLY);
              while ((n = read(fd1, buf, BUFFSIZE)) > 0)
                     if (write(fd2, buf, n) != n)
                             err_sys("write error");

              if (n < 0)
                      err_sys("read error");

              exit(0);
     }
```

看一个简单的 hello world 程序，它的功能非常简单，就是在栈空间里分配 4096 个字节作为 buffer，从 helloworld.in 文件里读 4KB 到该 buffer 里，然后将该 buffer 的数据写到 helloworld.out 文件中。这个 hello world 进程是工作于用户态的，但由于操作系统的隔离性，用户态程序是无法直接操作硬件的，所以要通过 read,write 系统调用进入内核态，执行内核的相应代码。

现在我们看看 read,write 系统调用做了什么。

```
SYSCALL_DEFINE3(read, unsigned int, fd, char __user *, buf, size_t, count)
{
	struct fd f = fdget_pos(fd);
	ssize_t ret = -EBADF;

	if (f.file) {
		loff_t pos = file_pos_read(f.file);
		ret = vfs_read(f.file, buf, count, &pos);
		file_pos_write(f.file, pos);
		fdput_pos(f);
	}
	return ret;
}

SYSCALL_DEFINE3(write, unsigned int, fd, const char __user *, buf,
		size_t, count)
{
	struct fd f = fdget_pos(fd);
	ssize_t ret = -EBADF;

	if (f.file) {
		loff_t pos = file_pos_read(f.file);
		ret = vfs_write(f.file, buf, count, &pos);
		file_pos_write(f.file, pos);
		fdput_pos(f);
	}

	return ret;
}
```

我们可以很清楚地看到，read,write 系统调用实际上就是对 vfs_read 和 vfs_write 的一个封装，非常直接地进入了虚拟文件系统（VFS）这一层。

### 虚拟文件系统（VFS）

在深入 vfs_read 和 vfs_write 函数之前，必须先介绍一下 vfs 的基本知识。

先思考一个问题，如果我们自己要实现一个文件系统，需要做什么？先不管实现细节，对外我们总得定义自己的文件系统接口吧，只有有了相应的函数接口，用户程序才能进行读写操作。所以，最基本最基本我们也得有自己的读和写接口。

但是，如果每一家文件系统都定义自己的一套接口，对于上层应用来说就很难去管理。在这样的时代背景下，vfs 应运而生。vfs 为不同的文件系统提供了统一的对上层的接口，使得上层应用在调用的时候无需知道底层的具体文件系统，只有在真正执行读写操作的时候才调用相应文件系统的读写函数。这个思想与面向对象编程的多态思想是非常相似的。实际上，vfs 就是定义了 4 种类型的基本对象，不同的文件系统要做的工作就是去实现具体的这 4 种对象。下面介绍一下这 4 种对象。这 4 种对象分别是 superblock,inode,dentry 和 file。file 对象就是我们用户进程打开了一个文件所产生的，每个 file 对象对应一个唯一的 dentry 对象。dentry 代表目录项，是跟文件路径相关的，一个文件路径对应唯一的一个 dentry。dentry 与 inode 则是多对一的关系，inode 存放单个文件的元信息，由于文件可能存在链接，所以多个路径的文件可能指向同一个 inode。superblock 对象则是整个文件系统的元信息，它还负责存储空间的分配与管理。它们的关系可以用下图表示：

[![vfs对象模型](https://assets.ng-tech.icu/item/vfs-model.png)](https://assets.ng-tech.icu/item/vfs-model.png)

#### superblock 对象

superblock 对象定义了整个文件系统的元信息，它实际上是一个结构体。

```
struct super_block {
	struct list_head	s_list;		/* Keep this first */
	dev_t			s_dev;		/* search index; _not_ kdev_t */
	unsigned char		s_blocksize_bits;
	unsigned long		s_blocksize;
	loff_t			s_maxbytes;	/* Max file size */
	struct file_system_type	*s_type;
	const struct super_operations	*s_op;
	const struct dquot_operations	*dq_op;
	const struct quotactl_ops	*s_qcop;
	const struct export_operations *s_export_op;
	unsigned long		s_flags;
	unsigned long		s_magic;
	struct dentry		*s_root;
	struct rw_semaphore	s_umount;
	int			s_count;
	atomic_t		s_active;
#ifdef CONFIG_SECURITY
	void                    *s_security;
#endif
	const struct xattr_handler **s_xattr;

	struct list_head	s_inodes;	/* all inodes */
	struct hlist_bl_head	s_anon;		/* anonymous dentries for (nfs) exporting */
#ifdef __GENKSYMS__
#ifdef CONFIG_SMP
	struct list_head __percpu *s_files;
#else
	struct list_head	s_files;
#endif
#else
#ifdef CONFIG_SMP
	struct list_head __percpu *s_files_deprecated;
#else
	struct list_head	s_files_deprecated;
#endif
#endif
	struct list_head	s_mounts;	/* list of mounts; _not_ for fs use */
	/* s_dentry_lru, s_nr_dentry_unused protected by dcache.c lru locks */
	struct list_head	s_dentry_lru;	/* unused dentry lru */
	int			s_nr_dentry_unused;	/* # of dentry on lru */

	/* s_inode_lru_lock protects s_inode_lru and s_nr_inodes_unused */
	spinlock_t		s_inode_lru_lock ____cacheline_aligned_in_smp;
	struct list_head	s_inode_lru;		/* unused inode lru */
	int			s_nr_inodes_unused;	/* # of inodes on lru */

	struct block_device	*s_bdev;
	struct backing_dev_info *s_bdi;
	struct mtd_info		*s_mtd;
	struct hlist_node	s_instances;
	struct quota_info	s_dquot;	/* Diskquota specific options */

	struct sb_writers	s_writers;

	char s_id[32];				/* Informational name */
	u8 s_uuid[16];				/* UUID */

	void 			*s_fs_info;	/* Filesystem private info */
	unsigned int		s_max_links;
	fmode_t			s_mode;

	/* Granularity of c/m/atime in ns.
	   Cannot be worse than a second */
	u32		   s_time_gran;

	/*
	 * The next field is for VFS *only*. No filesystems have any business
	 * even looking at it. You had been warned.
	 */
	struct mutex s_vfs_rename_mutex;	/* Kludge */

	/*
	 * Filesystem subtype.  If non-empty the filesystem type field
	 * in /proc/mounts will be "type.subtype"
	 */
	char *s_subtype;

	/*
	 * Saved mount options for lazy filesystems using
	 * generic_show_options()
	 */
	char __rcu *s_options;
	const struct dentry_operations *s_d_op; /* default d_op for dentries */

	/*
	 * Saved pool identifier for cleancache (-1 means none)
	 */
	int cleancache_poolid;

	struct shrinker s_shrink;	/* per-sb shrinker handle */

	/* Number of inodes with nlink == 0 but still referenced */
	atomic_long_t s_remove_count;

	/* Being remounted read-only */
	int s_readonly_remount;

	/* AIO completions deferred from interrupt context */
	RH_KABI_EXTEND(struct workqueue_struct *s_dio_done_wq)
};
```

这里字段非常多，我们没必要一一解释，有个大概的感觉就行。有几个字段比较重要的这里提一下：

1. `s_list`该字段是双向循环链表相邻元素的指针，所有的 superblock 对象都以链表的形式链在一起。
2. `s_fs_info`字段指向属于具体文件系统的超级块信息。很多具体的文件系统，例如 ext2，在磁盘上有对应的 superblock 的数据块，为了访问效率，`s_fs_info`就是该数据块在内存中的缓存。这个结构里最重要的是用 bitmap 形式存放了所有磁盘块的分配情况，任何分配和释放磁盘块的操作都要修改这个字段。
3. `s_dirt`字段表示超级块是否是脏的，上面提到修改了`s_fs_info`字段后超级块就变成脏了，脏的超级块需要定期写回磁盘，所以当计算机掉电时候是有可能造成文件系统损坏的。
4. `s_dirty`字段引用了脏 inode 链表的首元素和尾元素。
5. `s_inodes`字段引用了该超级块的所有 inode 构成的链表的首元素和尾元素。
6. `s_op`字段封装了一些函数指针，这些函数指针就指向真实文件系统实现的函数，superblock 对象定义的函数主要是读、写、分配 inode 的操作。多态主要是通过函数指针指向不同的函数实现的。

#### inode 对象

inode 对象定义了单个文件的元信息，例如最后修改时间、最后访问时间等等，同时还定义了一连串函数指针，这些函数指针指向具体文件系统的对文件操作的函数，可以说文件系统最核心的功能全部由 inode 的函数指针提供接口，包括常见的 open,read,write,sync,close 等等文件操作，都在 inode 的`i_op`字段里定义了统一的接口函数。

```
struct inode {
	umode_t			i_mode;
	unsigned short		i_opflags;
	kuid_t			i_uid;
	kgid_t			i_gid;
	unsigned int		i_flags;

#ifdef CONFIG_FS_POSIX_ACL
	struct posix_acl	*i_acl;
	struct posix_acl	*i_default_acl;
#endif

	const struct inode_operations	*i_op;
	struct super_block	*i_sb;
	struct address_space	*i_mapping;

#ifdef CONFIG_SECURITY
	void			*i_security;
#endif

	/* Stat data, not accessed from path walking */
	unsigned long		i_ino;
	/*
	 * Filesystems may only read i_nlink directly.  They shall use the
	 * following functions for modification:
	 *
	 *    (set|clear|inc|drop)_nlink
	 *    inode_(inc|dec)_link_count
	 */
	union {
		const unsigned int i_nlink;
		unsigned int __i_nlink;
	};
	dev_t			i_rdev;
	loff_t			i_size;
	struct timespec		i_atime;
	struct timespec		i_mtime;
	struct timespec		i_ctime;
	spinlock_t		i_lock;	/* i_blocks, i_bytes, maybe i_size */
	unsigned short          i_bytes;
	unsigned int		i_blkbits;
	blkcnt_t		i_blocks;

#ifdef __NEED_I_SIZE_ORDERED
	seqcount_t		i_size_seqcount;
#endif

	/* Misc */
	unsigned long		i_state;
	struct mutex		i_mutex;

	unsigned long		dirtied_when;	/* jiffies of first dirtying */

	struct hlist_node	i_hash;
	struct list_head	i_wb_list;	/* backing dev IO list */
	struct list_head	i_lru;		/* inode LRU list */
	struct list_head	i_sb_list;
	union {
		struct hlist_head	i_dentry;
		struct rcu_head		i_rcu;
	};
	u64			i_version;
	atomic_t		i_count;
	atomic_t		i_dio_count;
	atomic_t		i_writecount;
	const struct file_operations	*i_fop;	/* former ->i_op->default_file_ops */
	struct file_lock	*i_flock;
	struct address_space	i_data;
#ifdef CONFIG_QUOTA
	struct dquot		*i_dquot[MAXQUOTAS];
#endif
	struct list_head	i_devices;
	union {
		struct pipe_inode_info	*i_pipe;
		struct block_device	*i_bdev;
		struct cdev		*i_cdev;
	};

	__u32			i_generation;

#ifdef CONFIG_FSNOTIFY
	__u32			i_fsnotify_mask; /* all events this inode cares about */
	struct hlist_head	i_fsnotify_marks;
#endif

#ifdef CONFIG_IMA
	atomic_t		i_readcount; /* struct files open RO */
#endif
	void			*i_private; /* fs or device private pointer */
};
```

除了`i_op`外，介绍几个重要的字段：

1. `i_state`表示 inode 的状态，主要是表示 inode 是否是脏的。一般的文件系统在磁盘上都有相应的 inode 数据块，内核的 inode 结构便是这个磁盘数据块的内存缓存，所以与 superblock 一样，也是需要定期写回磁盘的，否则会导致数据丢失。
2. `i_list`把操作系统里的某些 inode 用双向循环链表连接起来，该字段指向相应链表的前一个元素和后一个元素。内核中有好几个关于 inode 的链表，所有 inode 必定出现在其中的某个链表内。第一个链表是有效未使用链表，链表里的 inode 都是非脏的，并且没有被引用，仅仅是作为高速缓存存在。第二个链表是正在使用链表，inode 不为脏，但`i_count`字段为整数，表示被某些进程引用了。第三个链表是脏链表，由 superblock 的`s_dirty`字段引用。
3. `i_sb_list`存放了超级块对象的`s_inodes`字段引用的链表的前一个元素和后一个元素。
4. 所有的 inode 都存放在一个 inode_hashtable 的哈希表中，key 是 inode 编号和超级块对象的地址计算出来的，作为高速缓存。因为哈希表可能会存在冲突，`i_hash`字段也是维护了链表指针，就指向同一个哈希地址的前一个 inode 和后一个 inode。

#### dentry 对象

dentry 代表目录项，因为每一个文件必定存在于某个目录内，我们通过路径去查找一个文件，最终必定最终找到某个目录项。在 linux 里，目录与普通文件一样，往往都是存放在磁盘的数据块中，在查找目录的时候就读出该目录所在的数据块，然后去寻找其中的某个目录项。如果不存在硬链接，其实 dentry 是没有必要的，仅仅通过 inode 就能确定文件。但多个路径有可能指向同一个文件，所以 vfs 还抽象出了一个 dentry 的对象，一个或多个 dentry 对应一个 inode。

```
struct dentry {
	/* RCU lookup touched fields */
	unsigned int d_flags;		/* protected by d_lock */
	seqcount_t d_seq;		/* per dentry seqlock */
	struct hlist_bl_node d_hash;	/* lookup hash list */
	struct dentry *d_parent;	/* parent directory */
	struct qstr d_name;
	struct inode *d_inode;		/* Where the name belongs to - NULL is
					 * negative */
	unsigned char d_iname[DNAME_INLINE_LEN];	/* small names */

	/* Ref lookup also touches following */
	struct lockref d_lockref;	/* per-dentry lock and refcount */
	const struct dentry_operations *d_op;
	struct super_block *d_sb;	/* The root of the dentry tree */
	unsigned long d_time;		/* used by d_revalidate */
	void *d_fsdata;			/* fs-specific data */

	struct list_head d_lru;		/* LRU list */
	/*
	 * d_child and d_rcu can share memory
	 */
	union {
		struct list_head d_child;	/* child of parent list */
	 	struct rcu_head d_rcu;
	} d_u;
	struct list_head d_subdirs;	/* our children */
	struct hlist_node d_alias;	/* inode alias list */
};
```

介绍几个重要的字段：

1. `d_inode`指向该 dentry 对应的 inode，找到了 dentry 就可以通过它找到 inode。
2. 同一个 inode 的所有 dentry 都在一个链表内，`d_alias`指向该链表的前一个和后一个元素。
3. `d_op`定义了一些关于目录项的函数指针，指向具体文件系统的函数。

##### 目录项高速缓存

按照我们平时使用 linux 的经验，我们做的最常用的操作是什么？是执行各种 shell 命令，由于执行命令要通过该命令对应的可执行文件的路径找到该可执行文件，所以根据路径查找文件无处不在。前面提到，文件系统的目录数据与普通文件的数据一样，都是存放在磁盘数据块内，如果每一级路径都要读取磁盘，性能肯定非常低。因此，dentry 必须放在高速缓存中加速。

vfs 把所有的 dentry 都放到 dentry_hashtable 这个哈希表中，key 就是由目录项对象和文件名哈希产生。

同时，由于内存有限，不可能把所有查找过的 dentry 都放到缓存中，还必须有缓存释放的机制。目录项高速缓存采用 LRU 双向链表来进行缓存添加与释放。所有未使用的 dentry（没有引用，仅作为缓存）都会加到一个 LRU 双向链表中，从链表首部插入，一旦高速缓存的空间变小，就从尾部删除元素。与之对应，所有正在使用的 dentry 都会插入到相应 inode 的`i_dentry`字段所引用的链表中，`d_alias`字段则指向链表相邻的元素。

dentry_hashtable 的大小是与机器的内存成正比的，缺省是每 MB 内存有 256 个元素。

#### file 对象

作为应用程序的开发者或使用者，我们平时能接触到的 vfs 对象就只有 file 对象。我们平常说的打开文件，实际上就是让内核去创建一个 file 对象，并返回给我们一个文件描述符。出于隔离性的考虑，内核不可能把 file 对象的地址传给我们，我们只能通过文件描述符去间接地访问 file 对象。

```
struct file {
	/*
	 * fu_list becomes invalid after file_free is called and queued via
	 * fu_rcuhead for RCU freeing
	 */
	union {
		struct list_head	fu_list;
		struct rcu_head 	fu_rcuhead;
	} f_u;
	struct path		f_path;
#define f_dentry	f_path.dentry
	struct inode		*f_inode;	/* cached value */
	const struct file_operations	*f_op;

	/*
	 * Protects f_ep_links, f_flags.
	 * Must not be taken from IRQ context.
	 */
	spinlock_t		f_lock;
#ifdef __GENKSYMS__
#ifdef CONFIG_SMP
	int			f_sb_list_cpu;
#endif
#else
#ifdef CONFIG_SMP
	int			f_sb_list_cpu_deprecated;
#endif
#endif
	atomic_long_t		f_count;
	unsigned int 		f_flags;
	fmode_t			f_mode;
	loff_t			f_pos;
	struct fown_struct	f_owner;
	const struct cred	*f_cred;
	struct file_ra_state	f_ra;

	u64			f_version;
#ifdef CONFIG_SECURITY
	void			*f_security;
#endif
	/* needed for tty driver, and maybe others */
	void			*private_data;

#ifdef CONFIG_EPOLL
	/* Used by fs/eventpoll.c to link all the hooks to this file */
	struct list_head	f_ep_links;
	struct list_head	f_tfile_llink;
#endif /* #ifdef CONFIG_EPOLL */
	struct address_space	*f_mapping;
#ifdef CONFIG_DEBUG_WRITECOUNT
	unsigned long f_mnt_write_state;
#endif
#ifndef __GENKSYMS__
	struct mutex		f_pos_lock;
#endif
};
```

1. `f_inode`指向对应的 inode 对象。
2. `f_dentry`指向对应的 dentry 对象。
3. `f_pos`表示当前文件的偏移，可见文件偏移是每个 file 对象都有自己的独立的文件偏移量。
4. `f_op`表示当前文件相关的所有函数指针，实际上在文件 open 的时候`f_op`会全部赋值为`i_op`相应的函数指针。

由于 file 对象是由内核进程直接管理的，我们有必要了解一下进程如何管理打开的文件。

首先，每个进程有一个 fs_struc 的字段：

```
struct fs_struct {
	int users;
	spinlock_t lock;
	seqcount_t seq;
	int umask;
	int in_exec;
	struct path root, pwd;
};

struct path {
	struct vfsmount *mnt;
	struct dentry *dentry;
};
```

我们看到，每个进程都维护一个根目录和当前工作目录的信息，每一个目录由`vfsmount`和`dentry`组合唯一确定，`dentry`代表目录项前面已经说到，`vfsmount`则代表相应目录项所在文件系统的挂载信息，会在后面展开介绍一下。

然后，每个进程都有当前打开的文件表，存放在进程的 files_struct 结构中。

```
struct files_struct {
  /*
   * read mostly part
   */
	atomic_t count;
	struct fdtable __rcu *fdt;
	struct fdtable fdtab;
  /*
   * written part on a separate cache line in SMP
   */
	spinlock_t file_lock ____cacheline_aligned_in_smp;
	int next_fd;
	unsigned long close_on_exec_init[1];
	unsigned long open_fds_init[1];
	struct file __rcu * fd_array[NR_OPEN_DEFAULT];
};
```

我们只要关注一下 fd_array 这个数组就行，这个数组就存储了所有打开的 file 对象，我们应用程序拿到的文件描述符实际上就只是这个数组的索引。

#### vfs 管理文件系统的注册与挂载

前面介绍了 vfs 的 4 种对象，所有能在 linux 上使用的文件系统都必须实现这 4 种对象接口，实际上就是实现`s_op,i_op,d_op`这 3 组函数（`f_op`简单地复制`i_op`），这样 vfs 才能正常地使用文件系统进行工作。假设我们已经按照这个接口开发了一套文件系统，这时候又面临了一个问题，vfs 怎么去识别我们的文件系统呢？我们的文件系统是如何注册和挂载到 vfs 上的呢？

##### 文件系统注册

文件系统要么是固化在内核代码中的，要么是通过内核模块动态加载的，在内核代码中的随着操作系统启动会自动注册，而通过内核模块动态加载的也可以用操作系统的启动参数配置成自动注册，或者我们可以人为地执行类似这样的命令`insmod fuse.ko`去动态注册，这里的 fuse.ko 就是 fuse 文件系统编译链接出来的二进制文件。

```
struct file_system_type {
	const char *name;
	int fs_flags;
#define FS_REQUIRES_DEV		1
#define FS_BINARY_MOUNTDATA	2
#define FS_HAS_SUBTYPE		4
#define FS_USERNS_MOUNT		8	/* Can be mounted by userns root */
#define FS_USERNS_DEV_MOUNT	16 /* A userns mount does not imply MNT_NODEV */
#define FS_HAS_RM_XQUOTA	256	/* KABI: fs has the rm_xquota quota op */
#define FS_HAS_INVALIDATE_RANGE	512	/* FS has new ->invalidatepage with length arg */
#define FS_HAS_DIO_IODONE2	1024	/* KABI: fs supports new iodone */
#define FS_HAS_NEXTDQBLK	2048	/* KABI: fs has the ->get_nextdqblk op */
#define FS_HAS_DOPS_WRAPPER	4096	/* kabi: fs is using dentry_operations_wrapper. sb->s_d_op points to
dentry_operations_wrapper */
#define FS_RENAME_DOES_D_MOVE	32768	/* FS will handle d_move() during rename() internally. */
	struct dentry *(*mount) (struct file_system_type *, int,
		       const char *, void *);
	void (*kill_sb) (struct super_block *);
	struct module *owner;
	struct file_system_type * next;
	struct hlist_head fs_supers;

	struct lock_class_key s_lock_key;
	struct lock_class_key s_umount_key;
	struct lock_class_key s_vfs_rename_key;
	struct lock_class_key s_writers_key[SB_FREEZE_LEVELS];

	struct lock_class_key i_lock_key;
	struct lock_class_key i_mutex_key;
	struct lock_class_key i_mutex_dir_key;
};
```

在注册文件系统的时候，我们需要提交一个`file_system_type`,这个对象主要有一个`get_sb`（linux kernel 2.6）或者是`mount`（linux kernel 3.1）对象，这个是一个函数指针，主要是分配 superblock 的，每当该类型的文件系统挂载时，就会调用该函数分配 superblock 对象。`fs_supers`引用了所有属于该文件系统类型的 superblock 对象。内核把所有注册的文件系统类型维护成一个链表，`file_system_type`的`next`字段指向链表的下一个元素。

##### 文件系统挂载

正常情况下，操作系统启动后，常用的文件系统类型都是自动注册的，不需要用户干预。但一个块设备要以某文件系统的形式被操作系统识别的话，需要挂载到某个目录下，例如执行如下的挂载命令：

```
mount -t xfs /dev/sdb /var/cold-storage/
```

当执行这条命令以后，内核会首先分配一个`vfsmount`的对象，该对象唯一标识一个挂载的文件系统。

```
struct vfsmount {
	struct dentry *mnt_root;	/* root of the mounted tree */
	struct super_block *mnt_sb;	/* pointer to superblock */
	int mnt_flags;
};
```

`vfsmount`主要存放了该文件系统的 superblock 对象以及该文件系统根目录（上例的/var/cold-storage/）的 dentry 对象，一开始 superblock 对象是空的。

有可能这个文件系统会被挂载了多次，之前已经被挂载到其他目录上了，就意味着其 superblock 对象已经被分配，因此内核会先搜索`file_system_type`的`fs_supers`链表，如果找到，就直接用该 superblock 对象赋值给新的`vfsmount`对象的`mnt_sb`字段。

如果这个文件系统是第一次被挂载，则调用注册的`file_system_type`的`get_sb`或者`mount`函数，分配新的 superblock 对象。

当 superblock 对象确定了以后，该文件系统就被挂载成功，可以正常使用了。

所有的 vfsmount 都会存放在 mount_hashtable 的哈希表中，key 是 vfsmount 地址以及 dentry 地址计算出来的哈希值。

#### 以 open 系统调用为例小结 vfs 的基本知识

在继续探究`vfs_read`和`vfs_write`之前，先通过 open 系统调用去串连一下 vfs 层的 4 个对象，小结一下前面的内容。因为 open 调用仅仅涉及到 vfs 层，跟磁盘高速缓存以及具体文件系统的实现基本无关。

回忆一下前面的 hello world 例子，在进行文件拷贝前，先要 open 文件：

```
fd1 = open("helloworld.in", O_RONLY);
fd2 = open("helloworld.out", O_WRONLY);
```

这里核心的任务就是要通过传入的路径参数，最终创建出 vfs 的 file 对象。file 对象确定了以后，意味着对应的 inode,dentry 和 superblock 也确定了，4 大 vfs 对象全都准备后，可以接受读写请求了。最后返回其在内核进程的文件打开数组里的索引号给上层用户进程。

具体步骤如下：

##### 路径查找

首先进行路径查找，调用`path_lookup()`函数。该函数主要接受两个参数，一个是路径名，一个是 nameidata 类型的结构体,这个结构体有一个比较重要的字段是 path，主要分析这个字段，在路径查找的过程中会不断修改这个字段，最后这个字段就代表路径查找的最终结果。该字段利用`vfsmount`和`dentry`唯一确定了某个路径。

```
struct path {
	struct vfsmount *mnt;
	struct dentry *dentry;
};
```

1. 首先判断路径是绝对路径还是相对路径，决定用进程的 root 还是 pwd 字段去填充这个 path 结构体，作为起始参数。
2. 用/去划分路径，依次解析每一层路径，对于每一层路径，首先找出其目录项的 dentry 对象，大概率会在目录项高速缓存中命中，如果缓存中没有，则读取磁盘，然后放到缓存中，并更新 path 字段。
3. 检查该层目录的 dentry 是否是某文件系统的挂载点，如果是,则用当前 path 的`vfsmount`和`dentry`计算哈希值，找出 mount_hashtable 中的子文件系统的`vfsmount`和`dentry`，并更新 path 的`vfsmount`和`dentry`。
4. 直到把所有分路径都解析完成，获得了最后的 path。

##### 创建 file 对象

找到了目的路径的`vfsmount`和`dentry`，inode 和 superblock 对象也相应确定了，剩下的工作就是分配一个新的文件对象，并把相应的字段用 inode，dentry 和 vfsmount 的地址去填充。

把 file 对象插入到当前进程的 fd_array 中，返回文件描述符。

#### vfs_read, vfs_write

现在，我们已经有了足够的 vfs 知识，可以探索一下前面 hello_world 程序里的`vfs_read`和`vfs_write`函数了。

```
SYSCALL_DEFINE3(read, unsigned int, fd, char __user *, buf, size_t, count)
{
	struct fd f = fdget_pos(fd);
	ssize_t ret = -EBADF;

	if (f.file) {
		loff_t pos = file_pos_read(f.file);
		ret = vfs_read(f.file, buf, count, &pos);
		file_pos_write(f.file, pos);
		fdput_pos(f);
	}
	return ret;
}

SYSCALL_DEFINE3(write, unsigned int, fd, const char __user *, buf,
		size_t, count)
{
	struct fd f = fdget_pos(fd);
	ssize_t ret = -EBADF;

	if (f.file) {
		loff_t pos = file_pos_read(f.file);
		ret = vfs_write(f.file, buf, count, &pos);
		file_pos_write(f.file, pos);
		fdput_pos(f);
	}

	return ret;
}

ssize_t vfs_read(struct file *file, char __user *buf, size_t count, loff_t *pos)
{
	ssize_t ret;

	if (!(file->f_mode & FMODE_READ))
		return -EBADF;
	if (!file->f_op || (!file->f_op->read && !file->f_op->aio_read))
		return -EINVAL;
	if (unlikely(!access_ok(VERIFY_WRITE, buf, count)))
		return -EFAULT;

	ret = rw_verify_area(READ, file, pos, count);
	if (ret >= 0) {
		count = ret;
		if (file->f_op->read)
			ret = file->f_op->read(file, buf, count, pos);
		else
			ret = do_sync_read(file, buf, count, pos);
		if (ret > 0) {
			fsnotify_access(file);
			add_rchar(current, ret);
		}
		inc_syscr(current);
	}

	return ret;
}

ssize_t vfs_write(struct file *file, const char __user *buf, size_t count, loff_t *pos)
{
	ssize_t ret;

	if (!(file->f_mode & FMODE_WRITE))
		return -EBADF;
	if (!file->f_op || (!file->f_op->write && !file->f_op->aio_write))
		return -EINVAL;
	if (unlikely(!access_ok(VERIFY_READ, buf, count)))
		return -EFAULT;

	ret = rw_verify_area(WRITE, file, pos, count);
	if (ret >= 0) {
		count = ret;
		file_start_write(file);
		if (file->f_op->write)
			ret = file->f_op->write(file, buf, count, pos);
		else
			ret = do_sync_write(file, buf, count, pos);
		if (ret > 0) {
			fsnotify_modify(file);
			add_wchar(current, ret);
		}
		inc_syscw(current);
		file_end_write(file);
	}

	return ret;
}
```

可以看到，read，write 系统调用会根据文件描述符提取出 file 对象，这个 file 对象是在 Open 调用里已经创建好的。然后会在 file 对象中读取出当前的文件偏移量，读写都会从这个偏移量开始。然后把 file 对象，用户层 buffer 的地址，要读写的大小，以及文件偏移量作为参数传入`vfs_read`和`vfs_write`中。这两个函数主要是对 file 对象的相应文件系统的读写函数进行封装，因此，主要的逻辑就过渡到了具体文件系统上了。具体文件系统的实现逻辑各不相同，但都要以 vfs 的 4 大对象为对外的接口，然后再定义自己的数据结构与方法。

对于通用的磁盘文件系统，linux 提供了很多基本的函数，很多文件系统的核心功能都是以这些基本函数为基础，再封装一层而已。我们就以常用的 xfs 文件系统为例，去简单看看它的 read 和 write 函数干了什么。

```
const struct file_operations xfs_file_operations = {
	.llseek		= xfs_file_llseek,
	.read		= do_sync_read,
	.write		= do_sync_write,
	.aio_read	= xfs_file_aio_read,
	.aio_write	= xfs_file_aio_write,
	.splice_read	= xfs_file_splice_read,
	.splice_write	= xfs_file_splice_write,
	.unlocked_ioctl	= xfs_file_ioctl,
#ifdef CONFIG_COMPAT
	.compat_ioctl	= xfs_file_compat_ioctl,
#endif
	.mmap		= xfs_file_mmap,
	.open		= xfs_file_open,
	.release	= xfs_file_release,
	.fsync		= xfs_file_fsync,
	.fallocate	= xfs_file_fallocate,
};
```

这是 xfs 的 f_op 的函数指针表，可以看到，它的 read,write 函数竟然直接用了内核提供的函数，非常偷懒！

```
ssize_t do_sync_read(struct file *filp, char __user *buf, size_t len, loff_t *ppos)
{
	struct iovec iov = { .iov_base = buf, .iov_len = len };
	struct kiocb kiocb;
	ssize_t ret;

	init_sync_kiocb(&kiocb, filp);
	kiocb.ki_pos = *ppos;
	kiocb.ki_left = len;
	kiocb.ki_nbytes = len;

	ret = filp->f_op->aio_read(&kiocb, &iov, 1, kiocb.ki_pos);
	if (-EIOCBQUEUED == ret)
		ret = wait_on_sync_kiocb(&kiocb);
	*ppos = kiocb.ki_pos;
	return ret;
}

ssize_t do_sync_write(struct file *filp, const char __user *buf, size_t len, loff_t *ppos)
{
	struct iovec iov = { .iov_base = (void __user *)buf, .iov_len = len };
	struct kiocb kiocb;
	ssize_t ret;

	init_sync_kiocb(&kiocb, filp);
	kiocb.ki_pos = *ppos;
	kiocb.ki_left = len;
	kiocb.ki_nbytes = len;

	ret = filp->f_op->aio_write(&kiocb, &iov, 1, kiocb.ki_pos);
	if (-EIOCBQUEUED == ret)
		ret = wait_on_sync_kiocb(&kiocb);
	*ppos = kiocb.ki_pos;
	return ret;
}
```

这两个函数实际上调用了具体文件系统的 aio_read 和 aio_write 函数，而 xfs 文件系统的这两个函数是自定义的，`xfs_file_aio_read`和`xfs_file_aio_write`。

这两个函数的代码就有点复杂了，不过我们不需要细究 xfs 的实现细节，我们的目的是要通过 xfs 文件系统去找出通用的磁盘文件系统的共性，`xfs_file_aio_read`和`xfs_file_aio_write`虽然有很多 xfs 自己的实现细节，但其核心功能都是建立在内核提供的通用函数上的，例如`xfs_file_aio_read`最终会调用`generic_file_aio_read`函数，而`xfs_file_aio_write`则最终会调用`generic_perform_write`函数。这些通用函数是基本上所有文件系统的核心逻辑。

进入到这里，就开始涉及到高速缓存这一层了。我们先立足于 vfs 这一层，然后预热一下高速缓存层，先直接概括一下`generic_file_aio_read`函数做了什么事情，非常简单：

1. 根据文件偏移量计算出在要读的内容在高速缓存中的位置。
2. 搜索高速缓存，看看要读的内容是否在高速缓存中存在，若存在则直接返回，若不存在则触发读磁盘任务。若触发读磁盘任务，则判断当前是否顺序读，尽量预读取磁盘数据到高速缓存中，减少磁盘 io 的次数。
3. 数据读取后，拷贝到用户态的 buffer 中。

`generic_perform_write`的逻辑则是：

1. 根据文件偏移量计算出在要写的内容在高速缓存中的位置。
2. 搜索看看要写的内容是否已在高速缓存中分配了相应的数据结构，若没有，则分配相应内存空间。
3. 从用户态的 buffer 拷贝数据到高速缓存中。
4. 检查高速缓存中的空间是否用得太多，如果占用过多内存则唤醒后台的写回磁盘的线程，把高速缓存的部分内容写回到磁盘上，可能会造成不定时间的写阻塞。
5. 向上层返回写的结果。

可以看到，vfs 的读写很大程度上依赖于高速缓存的，实际上直接读写硬盘的机会可能没有我们想象的多。对于读任务，如果是顺序读的场景，我们的进程同步读取的数据正常情况下已经在高速缓存中存在了，我们直接从高速缓存中取出数据便返回上层，然后内核会异步地进行预读取；如果是写任务，则绝大部分时候是直接写到高速缓存中便返回，然后再异步地进行 writeback。除非高速缓存占用过多，才会同步地写回一部分数据。

[![高速缓存交互](https://assets.ng-tech.icu/item/mmap.png)](https://assets.ng-tech.icu/item/mmap.png)

### 高速缓存

在 linux 中高速缓存主要是用页的形式来组织的，也称为页高速缓存（page cache）。页高速缓存相当于把磁盘映像抽象成一个个固定大小的连续的 page，对于 vfs 层，只需要与 page 交互，而不需要管理底层硬盘是如何分配空间以及如何读写的。linux 的 page 大小是 4KB。

由于文件可能非常大，所以无论是读或者写 page，都要求能够快速地在高速缓存中寻找到相应的 page。这就需要一个高效的数据结构来管理缓存中的 page。linux 内核中采用 radix tree 来管理 page cache。

#### radix tree

前面我们提到 vfs 的 inode 对象，在每一个 inode 对象中都间接持有了一个 radix tree 的数据结构，所以 page cache 的查找是以文件为单位进行的。

[![radix tree](https://assets.ng-tech.icu/item/radix-tree.png)](https://assets.ng-tech.icu/item/radix-tree.png)

可以看到 radix tree 是分层组织的，每一层有 64 个元素，层数越多能够保存的 page 数目就越多，而 tree node 的分配与释放是根据文件大小来调整的。由于索引是 32 位的，所以 radix tree 最多有 6 层，且当树的深度为 6 时，最高层最多只有 4 个元素。

我们就以前面说的 vfs 层读写高速缓存为例子，去分析一下 radix tree 的增删改查。

##### 计算 page 编号

无论读写，都要根据文件偏移量计算 page 号，很简单，公式如下：

```
page索引=文件偏移 / 4KB
```

##### 查找 page

首先查看当前 radix tree 的高度能支持的最大索引号是否超过当前要查询的 page 号，如果是，则继续查找，否则 page 不存在。

根据基数的深度去解析索引，如果树只有 1 层，说明只有 64 个 slot，那么只解析最低的 6 位；如果有两层，则只解析低 12 位，高 6 位作为第一层的索引，低 6 位作为第二层的索引。

##### 插入新 page

假设我们的 vfs 层的读函数在高速缓冲中找不到相应的 page，那么就要新分配 page 了，如果新 page 的的索引比当前树深度能支持的最大索引号大，那么就直接沿着路径分配中间节点就行。

如果树的深度不够，那就在树的顶端分配适当数量的节点，增加深度，然后再沿着路径分配中间节点。

##### 修改 page

vfs 层的写函数有可能会修改原有的 page，只要查找到该 page，然后修改数据就行。

##### 删除 page

如果系统内存不足，可能会触发 page 写回磁盘，然后释放掉所有非脏非正在写回的 page，就需要在 radix tree 上删除页。

删除页就是要先在 radix tree 中自顶向下地查找相应的 page，然后沿着路径再自底而上地删除，删除了子节点时，判断一下如果父节点的子节点数目是 0，那么父节点也可以删除。

##### 标记脏页和正在写回的页

如果写 page 触发了写回磁盘，那么就要找出当前 radix tree 有哪些页是脏的，哪些页是正在被写回的。如果全局搜索那么就太慢了，因此 linux 会在 radix tree 的每个中间节点上统计脏页和正在写回页的数目，如果是 0 的话就可以跳过该节点的所有子树。

#### 预读

从 vfs 层的读写函数可以看到，写是异步的，一般情况下写到内存就返回了；读是同步的，缓存不命中的惩罚非常严重。因此，如果我们的读是顺序读的话，高速缓存其实可以预先异步读取当前的 page 后面的 page，这样相比于一页一页地读，就可以大幅度减小磁盘 io 的次数；而且等到用户发起下一次读请求时，当前的 page 已经在缓存中了，读进程就不会阻塞。

预读的基本逻辑是：

1. 维护两个窗口，一个是当前窗，一个是预读窗。当前窗的 page 是正在请求的页或者是预读的页，预读窗仅包含预读的页。
2. 预读窗紧挨着当前窗。
3. 理想情况下正在请求的页会落在当前窗，同时预读窗不断传送新的页；当进程请求的页落到预读窗时，预读窗会变为当前窗，然后分配新的预读窗，去预读后面的页。
4. 预读的大小是动态变化的，如果进程持续顺序读取文件，那么预读会持续增加，直到达到文件系统的上限（默认是 128KB）；如果出现随机访问，预读会逐渐减少直到完全禁止。
5. 当进程重复访问文件的很小一部分，预读就会停止。

[![read ahead](https://assets.ng-tech.icu/item/read-ahead.png)](https://assets.ng-tech.icu/item/read-ahead.png)

#### buffer cache

其实在 linux 最初几个版本，是没有 page cache 的，缓存是以 buffer 的形式存在的，buffer 对应的是一个个磁盘块，例如 superblock 就是一个磁盘块，inode 的磁盘映像也是一个磁盘块，还有文件的所有数据块都是磁盘块，每一个磁盘块对应一个 buffer。

但随着时代的发展，访问单独磁盘块的场景越来越少，page cache 慢慢占了主要地位，在 Linux kernel 2.4 以后，buffer cache 已经不单独实现了，而是建立在 page cache 的基础上。

在现代 linux 系统上，绝大部分的高速缓存都是以 Page cache 的形式存在，仅在以下情况下会用 buffer cache:

1. 文件 page 内的磁盘块不相邻，或者 page 内有洞。
2. 单独访问一个块，例如 superblock 或者 inode。

因此，仅仅在 page 内的 buffer 数目不足以填充整个页或者磁盘块不连续的条件下，才会用 buffer cache 来引用缓存数据。

我们来看一下 buffer cache 的数据结构：

```
struct buffer_head {
	unsigned long b_state;		/* buffer state bitmap (see above) */
	struct buffer_head *b_this_page;/* circular list of page's buffers */
	struct page *b_page;		/* the page this bh is mapped to */

	sector_t b_blocknr;		/* start block number */
	size_t b_size;			/* size of mapping */
	char *b_data;			/* pointer to data within the page */

	struct block_device *b_bdev;
	bh_end_io_t *b_end_io;		/* I/O completion */
 	void *b_private;		/* reserved for b_end_io */
	struct list_head b_assoc_buffers; /* associated with another mapping */
	struct address_space *b_assoc_map;	/* mapping this buffer is
						   associated with */
	atomic_t b_count;		/* users using this buffer_head */
};
```

1. `b_page`指向 buffer cache 所在的 page。
2. `b_this_page`指向同属于一个 page 的下一个 buffer cache。
3. `b_blocknr`buffer cache 在磁盘中的逻辑块号。
4. `b_size`buffer cache 的大小。
5. `b_data`指向 buffer cache 数据的地址，该地址必定在`b_page`指向的页内。
6. `b_bdev`代表该 buffer cache 所映射的块设备，该字段和`b_blocknr`，`b_size`一起唯一决定了该数据所在的磁盘位置。

[![buffer page](https://assets.ng-tech.icu/item/buffer-page.png)](https://assets.ng-tech.icu/item/buffer-page.png)

### 通用块层

前面说到，高速缓存这一层分为 page cache 和 buffer cache，buffer cache 是建立在 page cache 之上的。page cache 是面向文件的抽象，而 buffer cache 则是面向块设备的抽象。由于我们对文件的读写请求最终还是会转化成对磁盘（块设备）的读写请求，这种请求是要落到磁盘扇区的。

[![sector to block](https://assets.ng-tech.icu/item/sector-block.png)](https://assets.ng-tech.icu/item/sector-block.png)

从`buffer_head`的结构中可以看到，每一个 buffer cache 都有一个磁盘的逻辑块号，这个磁盘块是文件系统的块号，每一个磁盘块可以包含一个或多个扇区，这取决于 buffer cache 的大小（文件系统格式化时的块大小）。所以，buffer cache 的大小是连续分配磁盘大小的最小单位。但对于大多数情况，整个 page 都会映射到连续的磁盘区域，因此 page 的大小将成为一般情况下的连续分配磁盘的最小单位。

当从高速缓存中读某个 page 发现该页不存在时，就会从高速缓存层进入通用块层，向块设备去提交读磁盘的请求。通用块层就是起到了从高速缓存到块设备的桥梁作用。

#### 通用块层的核心–bio

掌握通用块层只需要掌握一个数据结构–bio,它是通用块层逻辑的核心，它描述了从高速缓存层提交的一次 IO 请求。

```
struct bio {
	sector_t		bi_sector;	/* device address in 512 byte
						   sectors */
	struct bio		*bi_next;	/* request queue link */
	struct block_device	*bi_bdev;
	unsigned long		bi_flags;	/* status, command, etc */
	unsigned long		bi_rw;		/* bottom bits READ/WRITE,
						 * top bits priority
						 */

	unsigned short		bi_vcnt;	/* how many bio_vec's */
	unsigned short		bi_idx;		/* current index into bvl_vec */

	/* Number of segments in this BIO after
	 * physical address coalescing is performed.
	 */
	unsigned int		bi_phys_segments;

	unsigned int		bi_size;	/* residual I/O count */

	/*
	 * To keep track of the max segment size, we account for the
	 * sizes of the first and last mergeable segments in this bio.
	 */
	unsigned int		bi_seg_front_size;
	unsigned int		bi_seg_back_size;

	bio_end_io_t		*bi_end_io;

	void			*bi_private;
#ifdef CONFIG_BLK_CGROUP
	/*
	 * Optional ioc and css associated with this bio.  Put on bio
	 * release.  Read comment on top of bio_associate_current().
	 */
	struct io_context	*bi_ioc;
	struct cgroup_subsys_state *bi_css;
#endif
#if defined(CONFIG_BLK_DEV_INTEGRITY)
	struct bio_integrity_payload *bi_integrity;  /* data integrity */
#endif

	/*
	 * Everything starting with bi_max_vecs will be preserved by bio_reset()
	 */

	unsigned int		bi_max_vecs;	/* max bvl_vecs we can hold */

	atomic_t		bi_cnt;		/* pin count */

	struct bio_vec		*bi_io_vec;	/* the actual vec list */

	struct bio_set		*bi_pool;

	/* FOR RH USE ONLY
	 *
	 * The following padding has been replaced to allow extending
	 * the structure, using struct bio_aux, while preserving ABI.
	 */
	RH_KABI_REPLACE(void *rh_reserved1, struct bio_aux *bio_aux)

	/*
	 * We can inline a number of vecs at the end of the bio, to avoid
	 * double allocations for a small number of bio_vecs. This member
	 * MUST obviously be kept at the very end of the bio.
	 */
	struct bio_vec		bi_inline_vecs[0];
};
```

1. `bi_sector`代表这次 IO 请求的的磁盘扇区号。对于 buffer cache，可以通过 b_blocknr \* b_size / 512 计算得到。如果是 page cache，则稍微复杂一点，不过 page 的第一个磁盘块的逻辑块号也能通过文件的元信息间接计算得到。
2. `bio_io_vec`记录了高速缓存层要提交给磁盘的数据。一个`bio_io_vec`可看作一个连续的内存段。
3. `bi_vcnt`代表内存段的数目。
4. `bi_idx`代表当前已经传输到哪个内存段了，这个字段会在传输过程中被修改。
5. `bi_bdev`表示该请求指向哪个块设备。
6. `bi_rw`表示是读还是写请求。

```
struct bio_vec {
/* pointer to the physical page on which this buffer resides */
struct page *bv_page;
/* the length in bytes of this buffer */
unsigned int bv_len;
/* the byte offset within the page where the buffer resides */
unsigned int bv_offset;
};
```

[![bio vec](https://assets.ng-tech.icu/item/bio-vec.png)](https://assets.ng-tech.icu/item/bio-vec.png)

不管是 buffer cache 还是 Page cache，它们要提交读写磁盘的请求时，都要把数据封装成`bio_vec`的形式，然后放到`bio`结构内。

#### 读 page 请求

回忆之前讲到的 vfs 层的读请求，是以 page 为单位读取高速缓存的。如果某个 page 不在高速缓存中，那么就会调用文件系统定义的 read_page 函数。

以下 xfs 定义的针对 page 一级的函数列表：

```
const struct address_space_operations xfs_address_space_operations = {
	.readpage		= xfs_vm_readpage,
	.readpages		= xfs_vm_readpages,
	.writepage		= xfs_vm_writepage,
	.writepages		= xfs_vm_writepages,
	.set_page_dirty		= xfs_vm_set_page_dirty,
	.releasepage		= xfs_vm_releasepage,
	.invalidatepage_range	= xfs_vm_invalidatepage,
	.write_begin		= xfs_vm_write_begin,
	.write_end		= xfs_vm_write_end,
	.bmap			= xfs_vm_bmap,
	.direct_IO		= xfs_vm_direct_IO,
	.migratepage		= buffer_migrate_page,
	.is_partially_uptodate  = block_is_partially_uptodate,
	.error_remove_page	= generic_error_remove_page,
};
```

xfs 的 read_page 函数是`xfs_vm_readpage`。我们不打算去探究该函数的代码细节，而是直接概括一下对于大部分文件系统，read_page 函数的核心业务是什么，`xfs_vm_readpage`也只是在这个核心业务的基础上再添加自己的逻辑而已。

1. 检查 page 的 PG_private 字段，如果是 1，则该页被用于 buffer cache，就会对该页的每一个 buffer cache 都生成一个 bio 结构，提交给下一层。
2. 如果该 page 是一般的 page，则根据文件元信息计算该 page 的第一个文件块的块号以及块数目。
3. 分配新的 bio 结构，用 page cache 或者 buffer cache 的元信息初始化`bi_sector`，`bi_size`，`bi_bdev`，`bi_io_vec`，`bi_rw`等字段。
4. 可能要对`bi_bdev`进行 remap，然后再将 bio 提交给下一层。

所谓的块设备 remap，是要进行块设备的逻辑分区到磁盘的映射。一个文件系统是安装在逻辑分区上，所以我们的读写请求所对应的逻辑扇区号都是相对于逻辑分区而言的。但是，块设备在进行读写的时候是相对于整个物理磁盘来寻址的，因此在构建 bio 的时候，要进行逻辑分区到物理磁盘的 remap。

`bi_bdev`指向的是 block_device 的结构，无论是逻辑分区还是物理磁盘都是用这个结构来表示。它主要有两个字段跟 remap 相关的，分别是`bi_contains`以及`bd_part`。`bi_contains`指向该分区所在的物理磁盘的`bi_bdev`，如果该分区是逻辑分区，那么可以通过该字段找到物理磁盘的`bi_bdev`结构。`bd_part`则保存了物理磁盘的分区描述符`hd_struct`，可以通过该结构完成逻辑分区扇区号到整个物理磁盘扇区号的映射。

可以看到，read_page 函数的核心逻辑非常简单。不过，高速缓存一般都是采用预读的策略来读 page 的，因此一次会读多个 page，此时一般会调用文件系统的 read_pages 函数，该函数会生成多个内存段的 bio，即带有多个`bio_io_vec`，把连续的磁盘块一次读出来，减少 io 次数。

[![block device](https://assets.ng-tech.icu/item/block-device.png)](https://assets.ng-tech.icu/item/block-device.png)

### IO 调度程序层

通用块层构建了 bio 之后，会提交给下一层，但这个下一层还并没有到达硬件，还需要经过一层 io 调度。通用块层实际上把 bio 请求提交给了 IO 调度层。IO 调度层的存在主要是为了减小磁盘 IO 的次数，增大磁盘整体的吞吐量。因为多个 bio 之间可能是访问的连续的磁盘空间，如果把这些 bio 不经过排序重组就提交给硬件驱动程序，可能会造成很严重的随机读写现象，造成吞吐量下降。因此，IO 调度层的任务就是要把 bio 进行排序和合并。linux 内核里有几种不同的 Io 调度机制，可供用户选择，它们都有不同的优缺点，适合不同的应用场景。

#### 请求队列与请求

linux 内核为每一个设备都维护了一个 IO 队列，这个队列用来填充上层提交的 IO 请求。在通用块层我们介绍了 bio 结构，每一个 bio 是高速缓存层提交的一个 IO 请求。而在 IO 调度层，则用 request 结构来表达 IO 请求。

```
struct request {
#ifdef __GENKSYMS__
	union {
		struct list_head queuelist;
		struct llist_node ll_list;
	};
#else
	struct list_head queuelist;
#endif
	union {
		struct call_single_data csd;
		RH_KABI_REPLACE(struct work_struct mq_flush_work,
			        unsigned long fifo_time)
	};

	struct request_queue *q;
	struct blk_mq_ctx *mq_ctx;

	u64 cmd_flags;
	enum rq_cmd_type_bits cmd_type;
	unsigned long atomic_flags;

	int cpu;

	/* the following two fields are internal, NEVER access directly */
	unsigned int __data_len;	/* total data len */
	sector_t __sector;		/* sector cursor */

	struct bio *bio;
	struct bio *biotail;

#ifdef __GENKSYMS__
	struct hlist_node hash;	/* merge hash */
#else
	/*
	 * The hash is used inside the scheduler, and killed once the
	 * request reaches the dispatch list. The ipi_list is only used
	 * to queue the request for softirq completion, which is long
	 * after the request has been unhashed (and even removed from
	 * the dispatch list).
	 */
	union {
		struct hlist_node hash;	/* merge hash */
		struct list_head ipi_list;
	};
#endif

	/*
	 * The rb_node is only used inside the io scheduler, requests
	 * are pruned when moved to the dispatch queue. So let the
	 * completion_data share space with the rb_node.
	 */
	union {
		struct rb_node rb_node;	/* sort/lookup */
		void *completion_data;
	};

	/*
	 * Three pointers are available for the IO schedulers, if they need
	 * more they have to dynamically allocate it.  Flush requests are
	 * never put on the IO scheduler. So let the flush fields share
	 * space with the elevator data.
	 */
	union {
		struct {
			struct io_cq		*icq;
			void			*priv[2];
		} elv;

		struct {
			unsigned int		seq;
			struct list_head	list;
			rq_end_io_fn		*saved_end_io;
		} flush;
	};

	struct gendisk *rq_disk;
	struct hd_struct *part;
	unsigned long start_time;
#ifdef CONFIG_BLK_CGROUP
	struct request_list *rl;		/* rl this rq is alloced from */
	unsigned long long start_time_ns;
	unsigned long long io_start_time_ns;    /* when passed to hardware */
#endif
	/* Number of scatter-gather DMA addr+len pairs after
	 * physical address coalescing is performed.
	 */
	unsigned short nr_phys_segments;
#if defined(CONFIG_BLK_DEV_INTEGRITY)
	unsigned short nr_integrity_segments;
#endif

	unsigned short ioprio;

	void *special;		/* opaque pointer available for LLD use */
	char *buffer;		/* kaddr of the current segment if available */

	int tag;
	int errors;

	/*
	 * when request is used as a packet command carrier
	 */
	unsigned char __cmd[BLK_MAX_CDB];
	unsigned char *cmd;
	unsigned short cmd_len;

	unsigned int extra_len;	/* length of alignment and padding */
	unsigned int sense_len;
	unsigned int resid_len;	/* residual count */
	void *sense;

	unsigned long deadline;
	struct list_head timeout_list;
	unsigned int timeout;
	int retries;

	/*
	 * completion callback.
	 */
	rq_end_io_fn *end_io;
	void *end_io_data;

	/* for bidi */
	struct request *next_rq;
};
```

1. `sector`代表要传送的扇区号。
2. `nr_sectors`代表整个请求要传送的扇区数。
3. `current_nr_sectors`代表当前 bio 还需传输的扇区数。
4. `bio`表示请求的第一个 bio 结构
5. `biotail`表示请求的最后一个 bio 结构。

上层提交的 bio 有可能会新分配一个 request 结构去存放，或者合并到现有的 request 结构中。

在请求被处理时，下层的设备驱动程序有可能会修改 request 结构，使得 bio 总是指向当前未传输的第一个 bio，并且会修改`nr_sectors`和`current_nr_sectors`字段。

#### The Linus Elevator

这个调度器是 linux kernel 2.4 的默认调度器，不过在 2.6 之后已经被淘汰了，不过其基本思想是其他调度器的基础，所以稍微介绍一下。

1. 新请求到达时，先看看能不能与队列内已有的请求合并，凡是在磁盘内连续的都可以合并。
2. 如果不能合并，则按照磁盘块的顺序插入到正确的位置，始终保持队列是有序的。
3. 为了防止请求饿死，当发现有请求在队列的时间过长，将不执行任何合并与排序的优化，而是直接插入到队列末尾。

优点：使得设备驱动器总是进行顺序读写，最大化了吞吐。
　　缺点：某些请求的延迟会较大，且有可能会饿死。虽然有一定的措施防止请求饿死，但策略还不完善，没有一个时间上的保证。

#### Deadline

这个是目前我们项目里采用的调度器。这个调度器在继承了 Linus Elevator 调度器的优点的同时，还回避了它的缺点。

[![deadline io scheduler](https://assets.ng-tech.icu/item/deadline.png)](https://assets.ng-tech.icu/item/deadline.png)

这个调度器维护了 4 个中间队列，其中 sorted queue 与 Linus Elevator 调度器的队列一样，根据磁盘块位置进行合并和排序, 不过对读写请求进行了区分，读请求和写请求分开排序，因此有两个排序队列。同时还另外增加了两个冗余队列，在请求插入 sorted queue 时，还会分别填充插入读请求或者写请求的超时队列。这两个冗余队列按照普通 FIFO 的逻辑，按时间排序。每一个请求都有一个超时时间，默认读请求的超时时间是 500ms，写请求是 5s。

在一般情况下，磁盘的执行队列会从 sorted queues 里取出请求，优先从读请求排序队列里取，除非写请求排序队列被放弃多次。如果有读请求或者写请求超时，此时从相应的超时队列中取请求。之所以读写请求要分开队列，是因为读请求一般是同步的，对延迟更敏感，因此超时时间设得很短，并且优先级更高；而写请求一般是异步的，所以超时时间会更长，优先级较低。

#### anticipatory

deadline 调度器有一个问题，就是它会在读写请求之间交互执行，并且优先读请求。这样当有读写混合负载时，会发生磁头来回抖动，大幅度降低吞吐。anticipatory 调度器就是解决这个问题。

这个调度器建立在 deadline 调度器的基础上，仍然有 4 个队列，核心逻辑都一样。不过在完成了一个读请求时，如果此时队列里还没有请求，则不会马上切换到写队列，而是停止一段时间（默认 6ms）。由于大概率会有相邻的读请求到达，因此会减少磁头抖动的现象，对整体吞吐有好处。不过如果这段停止的时间没有读请求到达，这样就纯粹是浪费时间，因此 anticipatory 会根据相应进程和文件系统以往的一些统计信息去预测会不会有读请求到达，如果预测会有才会停止处理原本要处理的写请求。

这个调度器是最复杂的，而且它的功能可以通过配置其他调度器达到相似的效果，因此在 linux 2.6.33 版本之后被删除了。

#### CFQ

叫做完全公平调度器。这个调度器的主要目标在于让磁盘带宽在所有进程中平均分配。该调度器使用多个排序队列（缺省 64），当请求到达时，会把请求根据进程 ID 哈希到不同的队列，最终的调度队列会以轮询的方式扫描每一个排序队列取出请求。

#### Noop

最简单的调度器，基本不做什么，不排序，但还是会合并。新请求一般都是插入队尾，跟普通的 FIFO 差不多。一般用于随机读写较多，或者用户层本身已经做了请求排序和合并等优化的场景。

### 设备驱动层

每一类块设备都有它的驱动程序，该驱动程序负责管理块设备的硬件读写，例如 ide，scsi 等设备都有自己的驱动程序，IO 调度层的每一个请求实际上都会交给相应的设备驱动程序，让它们去执行硬件指令。大部分的磁盘驱动程序都采用 DMA 的方式去进行数据传输，DMA 控制器自行在内存和 IO 设备间进行数据传送，当数据传送完成再通过中断通知 CPU。

#### scatter-gather 传送方式

DMA 传送必须满足传送的数据都是磁盘上相邻扇区的。老式的磁盘控制器还有一个限制，就是磁盘必须与内存中的连续的内存区域传送数据。新的磁盘控制器则支持 scatter-gather 传送方式，即磁盘区域必须要连续，但可以同时传输多段不连续的内存段。

设备驱动程序需要向磁盘控制器发送：

1. 要传输的起始磁盘扇区号以及总扇区数。
2. 内存区域链表，链表中的每项包含一个内存地址还有长度。

这种 scatter-gather 的传送方式与 bio 以及 request 结构对于内存片段的管理是一致的，实际上通用块层以及 IO 调度层正是为了适配设备驱动程序的这种 scatter-gather 传送方式而使用 bio 以及 request 结构进行管理。request 的请求的合并机制可以让一次 DMA 传送传输尽可能多的数据。

#### 策略例程

每一个请求队列都有自己的 request_fn 方法，该方法可以调用块设备驱动程序的函数进行数据传输，这些函数就叫做策略例程。

设备驱动程序顺序地处理请求队列中的每一个请求，并设置在数据传送完成时产生中断。当中断产生时，中断程序重新调用策略例程，如果当前请求还没有全部完成，则重新发起请求，否则在请求队列中删除该请求，并处理下一个请求。

如果块设备控制器支持 scatter-gather 的传送方式，那么设备驱动程序会一次提交整个 request，否则会遍历 request 中的每一个 bio，以及 bio 的每一个 bio_io_vec，一段一段地传送。

中断产生时，如果请求没有完全完成，设备驱动程序会修改以下字段：

1. 修改 bio 字段使其指向第一个未完成的 bio。
2. 修改未完成的 bio 结构，使其 bi_idx 字段指向第一个未完成的 bio_io_vec。
3. 修改 bio_io_vec 的 bv_offset 以及 bv_len，使其表示该内存段中仍需要传送的数据。

### 块设备文件

以上的讲述基本上是针对普通文件的读写，但还有一种特殊的文件需要关注，就是设备文件（/dev/sda,/dev/sdb）。

这些设备文件仍然由 VFS 进行管理，相当于一个特殊的文件系统。当进程访问设备文件时，将直接驱动设备驱动程序。缺省的块设备文件的函数表如下：

```
const struct file_operations def_blk_fops = {
	.open		= blkdev_open,
	.release	= blkdev_close,
	.llseek		= block_llseek,
	.read		= do_sync_read,
	.write		= do_sync_write,
	.aio_read	= blkdev_aio_read,
	.aio_write	= blkdev_aio_write,
	.mmap		= generic_file_mmap,
	.fsync		= blkdev_fsync,
	.unlocked_ioctl	= block_ioctl,
#ifdef CONFIG_COMPAT
	.compat_ioctl	= compat_blkdev_ioctl,
#endif
	.splice_read	= generic_file_splice_read,
	.splice_write	= generic_file_splice_write,
};
```

可以看到，VFS 隐藏了底层文件系统的实现细节，如果是块设备的话，则会激活设备驱动程序的函数。

每当文件系统被映射到磁盘或分区上，或者显式执行 open()调用时，都会打开设备文件。设备文件也有自己的 page cache，buffer cache。

### 写回机制

最后介绍一下最为复杂的写回机制。前面我们讲述从通用块层到设备驱动层的时候，主要是以 read 为例子，由于读是同步的，往往一次读的调用将贯穿 vfs 到设备驱动层的整个 IO 体系。而对于写操作，这一般是异步的，一般从 vfs 到高速缓存层就会返回。但是新写的 page 不可能永远停留在内存，始终还是要写回磁盘的。当满足以下条件时，会触发高速缓存层的写回：

1. 脏页缓存占用太多，内存空间不足。
2. 脏页存在的时间过长。
3. 用户强制刷新脏页。
4. write 写 page 时检查是否需要刷新。

在 Linux kernel 2.6 之前写回是全局性的，一个线程负责所有磁盘的写回任务，这样将无法利用全部的磁盘带宽。新内核为每一个磁盘都建立一个线程，负责该磁盘的写回任务。

#### 写回架构

[![writeback-structure](https://assets.ng-tech.icu/item/backing-device-info.png)](https://assets.ng-tech.icu/item/backing-device-info.png)

每一个磁盘都对应一个 backing_device_info 的结构,可以通过相应块设备的请求队列找到该结构。`work_list`存储了该设备的所有写回任务，每一个写回任务由`wb_writeback_work`定义，包括要写回多少页，写回哪些页，是否同步等等。`bdi_writeback`结构则定义了写回线程执行的函数，写回线程会在必要性被唤醒，然后执行写回逻辑。`bdi_writeback`主要有 3 个队列，其中每当有 inode 变脏，都会加入到`b_dirty`队列中，`b_io`则是所有需要写回的 inode，`wb_writeback_work`所定义的写回任务就是针对`b_io`定义的 inode。`b_more_io`则是保存所有需要再次写回的 inode，这个队列的元素往往是因为在处理写回任务时，发现某些在`b_io`中的 inode 被锁住而不能马上写回，而临时转移到到`b_more_io`中。

#### 定时写回

写回线程会被定时唤醒，检查每一个 inode 的变脏时间，把符合要求的 inode 从`b_dirty`队列移到`b_io`队列。定时写回的任务一般不会从`work_list`里面取，而是尽可能多的写回每一个 inode 的所有脏页，直到没有脏页或者单个 inode 写回的时间过长。

#### 内存空间不足

当内存空间不足时，内核会尝试释放 page cache，由于只有不为脏的页才能被释放，此时会先唤醒每一个 bdi 设备的写回线程，并且创建一个写 1024 页的任务插入 work_list 里。因此，所有脏的 inode 都会最多写 1024 页。

#### 用户强制刷新脏页

如果是 sync 单个文件，不会唤醒写回线程，也不会从 work_list 里面取任务，而是由写进程同步地去写回该文件的所有脏页；如果是 sync 整个文件系统，则唤醒所有设备的写回线程，并创建一个写所有脏页的任务插入每一个 bdi 的 work_list，并等待写回任务完成。

#### write 调用写 page 时检查是否需要刷新

每当用户写一个 page 到高速缓存层，则会检查该 page 所在 inode 是否为脏，如果首次变脏则把该 inode 加入 superblock 的 s_dirty 队列以及相应 bdi 结构的 b_dirty 队列。

为了防止写入速度过快，使得高速缓存占用过高，每写一定数量的 page（默认 32 页），则会检查当前是否需要写回。判断是否需要写回，受到两条水平线的限制，一条是 background_thresh, 一条是 dirty_thresh。这两条水平线一般会受整个操作系统所有脏页所占内存的影响。如果 bdi 设备配置了 strictlimit，则主要受每一个 bdi 设备所设置的 min ratio 和 max ratio 所限制，此时由全局统计信息以及单个 bdi 设备的统计信息同时计算出是否超过这两条水平线。如果超过 background_thresh，则唤醒写回线程执行写回任务。如果超过 dirty_thresh，则当前写进程会阻塞，减缓写入速度。

除了在写 page 时检查是否超出水平线，写回线程定时唤醒时也会检查是否超出 background_thresh，如果超出则即便 inode 变脏时间没有超时，仍然要执行写回。

如果写回线程被唤醒时 work_list 为空，则默认为每一个脏 inode 写回 1024 页。

#### writepages

具体的写回业务由具体操作系统的 writepages 方法执行。每一个写回任务都会转换成一次或多次 writepages 方法的调用。该方法与前面说到的 readpages 函数相似，都是构造 bio，把请求提交给下层，直到设备驱动程序用 DMA 的方式写入磁盘。

#### 写回 inode 本身

不仅是脏页需要写回，inode 携带的元信息也要被写回，基本上每执行一次 writepages 函数，写回一定数量的页，就会把 inode 也写回磁盘一次。由于 inode 一般存储在磁盘分区开始的地方，与数据的存储区域不连续，因此这里会造成随机写的情况。

#### delay allocation

传统的文件系统会选择则把 page 写到高速缓存层的时候，就为数据预先分配磁盘空间。由于这种策略使得磁盘空间分配与实际写回过程割裂，当多个文件并发写入磁盘时，容易造成严重的随机写现象。现代的文件系统，如 xfs，ext4，都是在写回的时候才进行磁盘空间的分配，如此能极大地提升写性能。

### open 系统调用的关键参数解析

前面讲的 linux io 其实主要是针对最常见的情况，也就是有缓存的同步阻塞 io。有缓存指的是读写都要经过高速缓存层，vfs 层实际上只负责与高速缓存（Page cache, buffer cache）打交道，而不直接与磁盘打交道。而同步阻塞 io 是 5 种 io 类型之一，具体的描述可参见之前的文章的开头部分[redis-浅析 IO 多路复用与事件处理](https://wjqwsp.github.io/2018/03/25/redis-浅析IO多路复用与事件处理/)

实际上，在 open 文件的时候我们可以加入一些特殊的参数，来改变 io 的方式。下面介绍几个关键参数。

#### O_NONBLOCK

该参数不能用于普通文件，加上该参数将以同步非阻塞方式读写文件。

#### O_SYNC

在写入高速缓存后不马上返回，而是要马上把高速缓存的数据以及文件元信息都写回到磁盘上，当磁盘写成功后返回。相当于每次写完之后调用一下 fsync。

这里的 fsync 跟 fflush 有区别，fflush 是把用户态的 buffer 全部写到 Kernel buffer，但不保证数据落盘；fsync 则是保证用户态和内核态的 buffer 全部刷新到磁盘上。

#### O_DSYNC

在写入高速缓存后不马上返回，而是要马上把高速缓存的数据写回到磁盘上，当磁盘写成功后返回。相当于每次写完之后调用一下 fdatasync。该参数与 O_SYNC 不同的是不保证文件元信息刷新到磁盘，但是，如果文件的元信息会影响之后的读取的话，则仍然会马上刷新到磁盘。例如最后修改时间，最后访问时间等不会刷到磁盘上，但文件大小发生改变的话则会发生文件元信息的刷新。

#### O_DIRECT

该参数会绕开高速缓存，而是直接由 vfs 层到通用块层，即直接构造用户态 buffer 到磁盘相应扇区的 bio。这种方式避免了在用户态和内核态的多次内存拷贝，这个参数一般适用于用户程序已经构建了用户态的磁盘缓存，而不想再经过一层操作系统的缓存，希望直接管理数据对磁盘的读写。但这个参数有一个限制，就是用户态 buffer 的首地址以及大小都必须是块大小的整数倍，要进行块大小对齐。

#### O_ASYNC

信号驱动 IO，而并非异步 IO。这里提一下 linux 的异步 IO。linux 对异步 IO 支持不是很好，异步 IO 可以分为用户态异步 IO 和内核态异步 IO。用户态异步 IO 由 glibc 提供的 aio_read,aio_write 函数完成，但评价不是很好，很多人都说有 bug，而且性能较差。内核态异步 IO 性能较好，但限制较大，只有当文件是 O_DIRECT 打开的时候，才可以进行内核态的异步 IO 调用。
