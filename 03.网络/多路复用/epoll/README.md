# epoll/kqueue

服务器的特点是经常维护着大量连接，但其中某一时刻读写的操作符数量却不多。epoll 先通过 epoll_ctl 注册一个描述符到内核中，并一直维护着而不像 poll 每次操作都将所有要监控的描述符传递给内核；在描述符读写就绪时，通过回掉函数将自己加入就绪队列中，之后 epoll_wait 返回该就绪队列。也就是说，epoll 基本不做无用的操作，时间复杂度仅与活跃的客户端数有关，而不会随着描述符数目的增加而下降。

## select 不足与 epoll 中的改进

select 与 poll 问题的关键在于无状态。对于每一次系统调用，内核不会记录下任何信息，所以每次调用都需要重复传递相同信息。总结而言，select/poll 模型存在的问题即是每次调用 select，都需要把 fd 集合从用户态拷贝到内核态，这个开销在 fd 很多时会很大并且每次都需要在内核遍历传递进来的所有的 fd，这个开销在 fd 很多时候也很大。讨论 epoll 对于 select/poll 改进的时候，epoll 和 select 和 poll 的调用接口上的不同，select 和 poll 都只提供了一个函数——select 或者 poll 函数。而 epoll 提供了三个函数，epoll_create,epoll_ctl 和 epoll_wait，epoll_create 是创建一个 epoll 句柄；epoll_ctl 是注册要监听的事件类型；epoll_wait 则是等待事件的产生。对于上面所说的 select/poll 的缺点，主要是在 epoll_ctl 中解决的，每次注册新的事件到 epoll 句柄中时(在 epoll_ctl 中指定 EPOLL_CTL_ADD)，会把所有的 fd 拷贝进内核，而不是在 epoll_wait 的时候重复拷贝。epoll 保证了每个 fd 在整个过程中只会拷贝一次。epoll 的解决方案不像 select 或 poll 一样每次都把 current 轮流加入 fd 对应的设备等待队列中，而只在 epoll_ctl 时把 current 挂一遍(这一遍必不可少)并为每个 fd 指定一个回调函数，当设备就绪，唤醒等待队列上的等待者时，就会调用这个回调函数，而这个回调函数会 把就绪的 fd 加入一个就绪链表)。epoll_wait 的工作实际上就是在这个就绪链表中查看有没有就绪的 fd(利用 schedule_timeout()实现睡一会，判断一会的效果，和 select 实现中的第 7 步是类似的)。

1. select，poll 实现需要自己不断轮询所有 fd 集合，直到设备就绪，期间可能要睡眠和唤醒多次交替。而 epoll 其实也需要调用 epoll_wait 不断轮询就绪链表，期间也可能多次睡眠和唤醒交替，但是它是设备就绪时，调用回调函数，把就绪 fd 放入就绪链表中，并唤醒在 epoll_wait 中进入睡眠的进程。虽然都要睡眠和交替，但是 select 和 poll 在“醒着”的时候要遍历整个 fd 集合，而 epoll 在“醒着”的时候只要判断一下就绪链表是否为空就行了，这节省了大量的 CPU 时间。这就是回调机制带来的性能提升。

2. select，poll 每次调用都要把 fd 集合从用户态往内核态拷贝一次，并且要把 current 往设备等待队列中挂一次，而 epoll 只要一次拷贝，而且把 current 往等待队列上挂也只挂一次(在 epoll_wait 的开始，注意这里的等待队列并不是设备等待队列，只是一个 epoll 内部定义的等待队列)。这也能节省不少的开销。
