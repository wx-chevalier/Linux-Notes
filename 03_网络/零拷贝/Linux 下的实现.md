# mmap 与 write

mmap 与 write 简单来说就是使用 mmap 替换了 read 与 write 中的 read 操作，减少了一次 CPU 的拷贝。mmap 主要实现方式是将读缓冲区的地址和用户缓冲区的地址进行映射，内核缓冲区和应用缓冲区共享，从而减少了从读缓冲区到用户缓冲区的一次 CPU 拷贝。

```c
tmp_buf = mmap(file, len);
write(socket, tmp_buf, len);
```

![mmap 示意图](https://pic.imgdb.cn/item/60545141524f85ce290ef203.jpg)

整个过程发生了 4 次用户态和内核态的上下文切换和 3 次拷贝，具体流程如下：

- 用户进程通过 mmap()方法向操作系统发起调用，上下文从用户态转向内核态
- DMA 控制器把数据从硬盘中拷贝到读缓冲区
- 上下文从内核态转为用户态，mmap 调用返回
- 用户进程通过 write()方法发起调用，上下文从用户态转为内核态
- CPU 将读缓冲区中数据拷贝到 socket 缓冲区
- DMA 控制器把数据从 socket 缓冲区拷贝到网卡，上下文从内核态切换回用户态，write()返回

使用 mmap 替代 read 很明显减少了一次拷贝，当拷贝数据量很大时，无疑提升了效率。但是使用 mmap 会有一些隐藏的陷阱，例如，当你的程序 map 了一个文件，但是当这个文件被另一个进程截断(truncate)时, write 系统调用会因为访问非法地址而被 SIGBUS 信号终止。SIGBUS 信号默认会杀死你的进程并产生一个 coredump，最终可能导致服务器的终止。通常我们使用以下解决方案避免这种问题：

- 为 SIGBUS 信号建立信号处理程序：当遇到 SIGBUS 信号时，信号处理程序简单地返回，write 系统调用在被中断之前会返回已经写入的字节数，并且 errno 会被设置成 success,但是这是一种糟糕的处理办法，因为你并没有解决问题的实质核心。
- 使用文件租借锁：通常我们使用这种方法，在文件描述符上使用租借锁，我们为文件向内核申请一个租借锁，当其它进程想要截断这个文件时，内核会向我们发送一个实时的 RT_SIGNAL_LEASE 信号，告诉我们内核正在破坏你加持在文件上的读写锁。这样在程序访问非法内存并且被 SIGBUS 杀死之前，你的 write 系统调用会被中断。write 会返回已经写入的字节数，并且置 errno 为 success。

我们应该在 mmap 文件之前加锁，并且在操作完文件后解锁：

```cpp
if(fcntl(diskfd, F_SETSIG, RT_SIGNAL_LEASE) == -1) {
    perror("kernel lease set signal");
    return -1;
}
/* l_type can be F_RDLCK F_WRLCK  加锁*/
/* l_type can be  F_UNLCK 解锁*/
if(fcntl(diskfd, F_SETLEASE, l_type)){
    perror("kernel lease set type");
    return -1;
}
```

# sendfile

在内核版本 2.1 中，引入了 sendfile 系统调用，以简化网络上和两个本地文件之间的数据传输。相比 mmap 来说，sendfile 同样减少了一次 CPU 拷贝，而且还减少了 2 次上下文切换。使用如下：

```cpp
#include<sys/sendfile.h>

ssize_t sendfile(int out_fd, int in_fd, off_t *offset, size_t count);
```

系统调用 sendfile()在代表输入文件的描述符 in_fd 和代表输出文件的描述符 out_fd 之间传送文件内容（字节）。描述符 out_fd 必须指向一个套接字，而 in_fd 指向的文件必须是可以 mmap 的。这些局限限制了 sendfile 的使用，使 sendfile 只能将数据从文件传递到套接字上，反之则不行。使用 sendfile 不仅减少了数据拷贝的次数，还减少了上下文切换，数据传送始终只发生在 kernel space。

![sendfile 示意图](https://pic.imgdb.cn/item/6054539b524f85ce29107de6.jpg)

整个过程发生了 2 次用户态和内核态的上下文切换和 3 次拷贝，具体流程如下：

- 用户进程通过 sendfile()方法向操作系统发起调用，上下文从用户态转向内核态
- DMA 控制器把数据从硬盘中拷贝到读缓冲区
- CPU 将读缓冲区中数据拷贝到 socket 缓冲区
- DMA 控制器把数据从 socket 缓冲区拷贝到网卡，上下文从内核态切换回用户态，sendfile 调用返回

sendfile 方法 IO 数据对用户空间完全不可见，所以只能适用于完全不需要用户空间处理的情况，比如静态文件服务器。此外，在我们调用 sendfile 时，如果有其它进程截断了文件会发生什么呢？假设我们没有设置任何信号处理程序，sendfile 调用仅仅返回它在被中断之前已经传输的字节数，errno 会被置为 success。如果我们在调用 sendfile 之前给文件加了锁，sendfile 的行为仍然和之前相同，我们还会收到 RT_SIGNAL_LEASE 的信号。

## sendfile+DMA Scatter/Gather

Linux2.4 内核版本之后对 sendfile 做了进一步优化，通过引入新的硬件支持，这个方式叫做 DMA Scatter/Gather 分散/收集功能。它将读缓冲区中的数据描述信息：内存地址和偏移量记录到 socket 缓冲区，由 DMA 根据这些将数据从读缓冲区拷贝到网卡，相比之前版本减少了一次 CPU 拷贝的过程。

![sendfile DMA Gather 示意图](https://pic.imgdb.cn/item/60545496524f85ce29110cfe.jpg)

整个过程发生了 2 次用户态和内核态的上下文切换和 2 次拷贝，其中更重要的是完全没有 CPU 拷贝，具体流程如下：

- 用户进程通过 sendfile()方法向操作系统发起调用，上下文从用户态转向内核态
- DMA 控制器利用 scatter 把数据从硬盘中拷贝到读缓冲区离散存储
- CPU 把读缓冲区中的文件描述符和数据长度发送到 socket 缓冲区
- DMA 控制器根据文件描述符和数据长度，使用 scatter/gather 把数据从内核缓冲区拷贝到网卡
- sendfile()调用返回，上下文从内核态切换回用户态

DMA gather 和 sendfile 一样数据对用户空间不可见，而且需要硬件支持，同时输入文件描述符只能是文件，但是过程中完全没有 CPU 拷贝过程，极大提升了性能。

# splice

sendfile 只适用于将数据从文件拷贝到套接字上，限定了它的使用范围。Linux 在 2.6.17 版本引入 splice 系统调用，用于在两个文件描述符中移动数据：

```cpp
#define _GNU_SOURCE         /* See feature_test_macros(7) */
#include <fcntl.h>
ssize_t splice(int fd_in, loff_t *off_in, int fd_out, loff_t *off_out, size_t len, unsigned int flags);
```

splice 调用在两个文件描述符之间移动数据，而不需要数据在内核空间和用户空间来回拷贝。他从 fd_in 拷贝 len 长度的数据到 fd_out，但是有一方必须是管道设备，这也是目前 splice 的一些局限性。flags 参数有以下几种取值：

- **SPLICE_F_MOVE**：尝试去移动数据而不是拷贝数据。这仅仅是对内核的一个小提示：如果内核不能从 pipe 移动数据或者 pipe 的缓存不是一个整页面，仍然需要拷贝数据。Linux 最初的实现有些问题，所以从 2.6.21 开始这个选项不起作用，后面的 Linux 版本应该会实现。
- **SPLICE_F_NONBLOCK**：splice 操作不会被阻塞。然而，如果文件描述符没有被设置为不可被阻塞方式的 IO，那么调用 splice 有可能仍然被阻塞。
- **SPLICE_F_MORE**：后面的 splice 调用会有更多的数据。

splice 调用利用了 Linux 提出的管道缓冲区机制，所以至少一个描述符要为管道。
