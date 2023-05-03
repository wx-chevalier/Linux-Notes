# Linux IO 模型

在整个请求过程中，IO 设备数据输入至内核 buffer 需要时间，而从内核 buffer 复制数据至进程 Buffer 也需要时间。因此根据在这两段时间内等待方式的不同，IO 动作可以分为以下五种模式：

- 阻塞 IO (Blocking IO)
- 非阻塞 IO (Non-Blocking IO)
- IO 复用（IO Multiplexing)
- 信号驱动的 IO (Signal Driven IO)
- 异步 IO (Asynchrnous IO)

![IO 模型](https://s3.ax1x.com/2021/02/28/6CWFr6.png)

前四个模型之间的主要区别是第一阶段，四个模型的第二阶段是一样的，过程受阻在调用 recvfrom 当数据从内核拷贝到用户缓冲区。然而，异步 IO 处理两个阶段，与前四个不同。

## 阻塞 IO (Blocking IO)

当用户进程调用了 recvfrom 这个系统调用，内核就开始了 IO 的第一个阶段：等待数据准备。对于 network io 来说，很多时候数据在一开始还没有到达（比如，还没有收到一个完整的 UDP 包），这个时候内核就要等待足够的数据到来。而在用户进程这边，整个进程会被阻塞。当内核一直等到数据准备好了，它就会将数据从内核中拷贝到用户内存，然后内核返回结果，用户进程才解除 block 的状态，重新运行起来。所以，blocking IO 的特点就是在 IO 执行的两个阶段都被 block 了。（整个过程一直是阻塞的）

![Blocking IO](https://pic.imgdb.cn/item/60861c8cd1a9ae528f961d8a.png)

![Blocking IO 时序图](https://pic.imgdb.cn/item/60861c9dd1a9ae528f969830.png)

## 非阻塞 IO (Non-Blocking IO)

linux 下，可以通过设置 socket 使其变为 non-blocking。当对一个 non-blocking socket 执行读操作时，流程是如下图所示：

![non-blocking](https://assets.ng-tech.icu/item/20230417210357.png)

当用户进程调用 recvfrom 时，系统不会阻塞用户进程，而是立刻返回一个 ewouldblock 错误，从用户进程角度讲，并不需要等待，而是马上就得到了一个结果（这个结果就是 ewouldblock）。用户进程判断标志是 ewouldblock 时，就知道数据还没准备好，于是它就可以去做其他的事了，于是它可以再次发送 recvfrom，一旦内核中的数据准备好了。并且又再次收到了用户进程的 system call，那么它马上就将数据拷贝到了用户内存，然后返回。当一个应用程序在一个循环里对一个非阻塞调用 recvfrom，我们称为轮询。应用程序不断轮询内核，看看是否已经准备好了某些操作。这通常是浪费 CPU 时间。

## IO 复用（IO Multiplexing)

我们都知道，select/epoll 的好处就在于单个 process 就可以同时处理多个网络连接的 IO。它的基本原理就是 select/epoll 这个 function 会不断的轮询所负责的所有 socket，当某个 socket 有数据到达了，就通知用户进程。它的流程如图：

![IO Multiplexing](https://pic.imgdb.cn/item/6077cf498322e6675c51f93e.png)

Linux 提供 select/epoll，进程通过将一个或者多个 fd 传递给 select 或者 poll 系统调用，阻塞在 select 操作上，这样 select/poll 可以帮我们侦测多个 fd 是否处于就绪状态。select/poll 是顺序扫描 fd 是否就绪，而且支持的 fd 数量有限，因此它的使用受到一定的限制。Linux 还提供了一个 epoll 系统调用，epoll 使用基于事件驱动的方式代替顺序扫描，因此性能更高一些。

![epoll，进程通过将一个或者多个](https://assets.ng-tech.icu/item/20230417211906.png)

IO 复用模型具体流程：用户进程调用了 select，那么整个进程会被 block，而同时，内核会“监视”所有 select 负责的 socket，当任何一个 socket 中的数据准备好了，select 就会返回。这个时候用户进程再调用 read 操作，将数据从内核拷贝到用户进程。这个图和 blocking IO 的图其实并没有太大的不同，事实上，还更差一些。因为这里需要使用两个 system call (select 和 recvfrom)，而 blocking IO 只调用了一个 system call (recvfrom)。但是，用 select 的优势在于它可以同时处理多个 connection。

## 信号驱动的 IO (Signal Driven IO)

首先用户进程建立 SIGIO 信号处理程序，并通过系统调用 sigaction 执行一个信号处理函数，这时用户进程便可以做其他的事了，一旦数据准备好，系统便为该进程生成一个 SIGIO 信号，去通知它数据已经准备好了，于是用户进程便调用 recvfrom 把数据从内核拷贝出来，并返回结果。

![Signal Driven IO](https://assets.ng-tech.icu/item/20230417211922.png)

## 异步 IO

一般来说，这些函数通过告诉内核启动操作并在整个操作（包括内核的数据到缓冲区的副本）完成时通知我们。这个模型和前面的信号驱动 IO 模型的主要区别是，在信号驱动的 IO 中，内核告诉我们何时可以启动 IO 操作，但是异步 IO 时，内核告诉我们何时 IO 操作完成。

![异步 IO](https://s3.ax1x.com/2021/02/28/6CWyoF.png)

当用户进程向内核发起某个操作后，会立刻得到返回，并把所有的任务都交给内核去完成（包括将数据从内核拷贝到用户自己的缓冲区），内核完成之后，只需返回一个信号告诉用户进程已经完成就可以了。
