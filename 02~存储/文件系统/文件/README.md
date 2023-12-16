# 文件

在 Linux、BSD 这样的类 Unix 系统中，万物皆文件（Everything is a file）。想象一下像文字处理程序这样的上下文中的文件，我们可以在此虚构的字处理文件上使用两个基本操作：

- 读取它（来自字处理器的现有已保存数据）。
- 向其写入（来自用户的新数据）。

在计算器中，我们与读写这样文件基础操作相关的元素还包括：屏幕、键盘、打印机、CD-ROM 等。

![抽象](https://s2.ax1x.com/2020/01/25/1eOoRS.png)

屏幕和打印机都像只写文件，但是信息不是作为位存储在磁盘上，而是显示为屏幕上的点或页面上的线。键盘就像一个只读文件，其数据来自用户提供的击键。CD-ROM 也类似，但并非直接来自用户，而是将数据直接存储在磁盘上。因此，文件的概念是数据接收器或数据源的良好抽象，它是一个可以附加到计算机的所有设备的出色抽象。这种实现是 UNIX 的强大功能，并且在整个平台的设计中显而易见。向程序员提供这种硬件抽象是操作系统的基本角色之一。可以说，抽象是支撑所有现代计算的主要概念，这可能并不过分。从设计现代用户界面到现代 CPU 的内部工作原理，没人能理解所有内容，更不用说自己构建所有内容了。对于程序员而言，抽象是允许我们进行协作和发明的通用语言。

# 文件描述符

UNIX 中每个正在运行的程序都以三个已经打开的文件开始：

| Descriptive Name | Short Name | File Number | Description                 |
| ---------------- | ---------- | ----------- | --------------------------- |
| Standard In      | stdin      | 0           | Input from the keyboard     |
| Standard Out     | stdout     | 1           | Output to the console       |
| Standard Error   | stderr     | 2           | Error output to the console |

![Default Unix Files](https://s2.ax1x.com/2020/01/25/1eXtW8.png)

打开调用返回的值称为文件描述符，本质上是内核保存的打开文件数组的索引；换言之，文件描述符是通往内核底层硬件抽象的门户。

![File Descriptor](https://s2.ax1x.com/2020/01/25/1eXBes.md.png)

文件描述符是内核存储的文件描述符表的索引。内核响应打开调用而创建文件描述符，并将文件描述符与底层文件状对象的某种抽象相关联，这些对象是实际的硬件设备，文件系统或其他任何东西。因此，引用该文件描述符的进程的读取或写入调用将由内核路由到正确的位置，以最终做一些有用的事情。

# 硬件文件抽象

从最低级别开始，操作系统需要程序员来创建设备驱动程序，以便能够与硬件设备进行通信。这些设备驱动程序就是那些遵循着 Linux 系统 API 的软件程序。

```c
/**
 * virtio_driver - operations for a virtio I/O driver
 * @driver: underlying device driver (populate name and owner).
 * @id_table: the ids serviced by this driver.
 * @feature_table: an array of feature numbers supported by this driver.
 * @feature_table_size: number of entries in the feature table array.
 * @probe: the function to call when a device is found.  Returns 0 or -errno.
 * @remove: the function to call when a device is removed.
 * @config_changed: optional function to call when the device configuration
 *    changes; may be called in interrupt context.
 */
struct virtio_driver {
        struct device_driver driver;
        const struct virtio_device_id *id_table;
        const unsigned int *feature_table;
        unsigned int feature_table_size;
        int (*probe)(struct virtio_device *dev);
        void (*scan)(struct virtio_device *dev);
        void (*remove)(struct virtio_device *dev);
        void (*config_changed)(struct virtio_device *dev);
#ifdef CONFIG_PM
        int (*freeze)(struct virtio_device *dev);
        int (*restore)(struct virtio_device *dev);
#endif
};

```

在上面的简化示例中，我们可以看到驱动程序提供了读写功能，以响应文件描述符上的类似操作而被调用。设备驱动程序知道如何将这些通用请求转换为针对特定设备的特定请求或命令。

为了提供对用户空间的抽象，内核通过通常称为设备层的方式提供文件接口。主机上的物理设备由特殊文件系统（例如 /dev）中的文件表示。在类似 UNIX 的系统中，所谓的设备节点具有主要编号和次要编号，它们允许内核将特定节点与其底层驱动程序相关联。

```s
$ ls -l /dev/null /dev/zero /dev/tty
crw-rw-rw- 1 root root 1, 3 Aug 26 13:12 /dev/null
crw-rw-rw- 1 root root 5, 0 Sep  2 15:06 /dev/tty
crw-rw-rw- 1 root root 1, 5 Aug 26 13:12 /dev/zero
```

这将我们带到文件描述符，该文件描述符是用户空间用于与基础设备进行通信的句柄。从广义上讲，打开文件时发生的情况是内核正在使用路径信息将文件描述符与提供适当读写等 API 的内容进行映射。当此打开是针对设备的（上面的 / dev/sr0）时，打开的设备节点的主编号和次编号将提供内核找到正确的设备驱动程序并完成映射所需的信息。然后，内核将知道如何将进一步的调用（如读取）路由到设备驱动程序提供的基础功能。

尽管非设备文件之间存在更多的层，但其操作类似。这里的抽象是挂载点；挂载文件系统具有设置映射的双重目的，因此文件系统知道提供存储的底层设备，内核知道在该挂载点下打开的文件应定向到文件系统驱动程序。像设备驱动程序一样，文件系统被写入内核提供的特定通用文件系统 API。

实际上，实际上还有许多其他层使图片复杂化。例如，内核将竭尽全力在尽可能多的空闲内存中缓存来自磁盘的尽可能多的数据。这提供了许多速度优势。它还将尝试以最有效的方式组织设备访问；例如，即使没有按顺序到达请求，也要尝试命令磁盘访问以确保物理上靠在一起存储的数据被一起检索。此外，许多设备属于通用类，例如 USB 或 SCSI 设备，它们提供要写入的抽象层。因此，文件系统将直接穿过这些许多层，而不是直接写入设备。理解内核就是要理解这许多 API 是如何相互关联和共存的。

# Shell

Shell 是与操作系统进行交互的网关。无论是 bash，zsh，csh 还是许多其他 Shell 中的任何一个，它们基本上都只有一项主要任务-允许您执行程序（当我们谈论某些内部原理时，您将开始理解 Shell 实际是如何做到的）操作系统的版本）。但是，shell 所要做的不只是允许您简单地执行程序。它们具有强大的功能来重定向文件，允许您同时执行多个程序和编写完整程序的脚本。

## Redirection

很多时候我们并不希望输入输出的文件描述符指向默认的位置，譬如您可能希望将程序的所有输出捕获到磁盘上的文件中，或者让它从您之前准备的文件中读取命令；另一个有用的任务可能是希望将一个程序的输出传递给另一个程序的输入。

| Name               | Command               | Description                                                                                                                        | Example           |
| ------------------ | --------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ----------------- |
| Redirect to a file | `> filename`          | Take all output from standard out and place it into `filename`. Note using `>>` will append to the file, rather than overwrite it. | `ls > filename`   |
| Read from a file   | < `filename`          | Copy all data from the file to the standard input of the program                                                                   | `echo < filename` |
| Pipe               | `program1 | program2` | Take everything from standard out of `program1` and pass it to standard input of `program2`                                        | `ls | more`       |

## pipe 的实现

对于 `ls | more` 这样的实现也是典型的抽象的应用案例，其文件描述符没有指向标准输出的文件描述符与某种底层设备（例如控制台，用于输出到终端）相关联，而是指向内核提供的内存缓冲区，这里就是管道。这里的技巧是，另一个进程可以将其标准输入与此同一个缓冲区的另一侧相关联，并有效地消耗另一个进程的输出。

![A pipe in action](https://s2.ax1x.com/2020/01/25/1ejQpT.md.png)

内核将对管道的写入存储起来，直到从另一侧进行的相应读取耗尽了缓冲区。这是一个非常强大的概念，并且是类 UNIX 操作系统中进程间通信或 IPC 的基本形式之一。管道不仅仅允许数据传输；它可以充当信令通道。如果进程读取空管道，则默认情况下它将阻塞或进入休眠状态，直到有可用数据。

因此，两个进程可以使用管道来传达已通过写一个字节数据采取了某些措施除了实际数据并不重要之外，管道中仅存在任何数据就可以发出消息例如，一个进程要求另一个进程打印文件，这将花费一些时间这两个进程可以在它们之间建立一个管道，其中请求进程对空管道进行读取如果为空，则该调用将阻塞，并且该过程不会继续一旦完成打印，其他进程便可以在管道中写入一条消息，从而有效地唤醒请求进程并发出工作已完成的信号。
