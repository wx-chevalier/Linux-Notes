# 函数分析

## int epoll_create(int size);

创建一个 epoll 的句柄，size 用来告诉内核这个监听的数目一共有多大。这个 参数不同于 select()中的第一个参数，给出最大监听的 fd+1 的值。需要注意的是，当创建好 epoll 句柄后，它就是会占用一个 fd 值，在 linux 下如果查看/proc/进程 id/fd/，是能够看到这个 fd 的，所以在使用完 epoll 后，必须调用 close()关闭，否则可能导致 fd 被 耗尽。

## int epoll_ctl(int epfd, int op, int fd, struct epoll_event \*event);

epoll 的事件注册函数，它不同与 select()是在监听事件时告诉内核要监听什么类型的事件，而是在这里先注册要监听的事件类型。第一个参数是 epoll_create()的返回值，第二个参数表示动作，用三个宏来表示：

- EPOLL_CTL_ADD：注册新的 fd 到 epfd 中；
- EPOLL_CTL_MOD：修改已经注册的 fd 的监听事件；
- EPOLL_CTL_DEL：从 epfd 中删除一个 fd；

第三个参数是需要监听的 fd，第四个参数是告诉内核需要监听什么事，struct epoll_event 结构如下：

```c
typedef union epoll_data {
    void *ptr;
    int fd;
    __uint32_t u32;
    __uint64_t u64;
} epoll_data_t;

struct epoll_event {
    __uint32_t events; /* Epoll events */
    epoll_data_t data; /* User data variable */
};
```

events 可以是以下几个宏的集合：

- EPOLLIN：表示对应的文件描述符可以读(包括对端 SOCKET 正常关闭)；
- EPOLLOUT：表示对应的文件描述符可以写；
- EPOLLPRI：表示对应的文件描述符有紧急的数据可读(这里应该表示有带外数据到来)；
- EPOLLERR：表示对应的文件描述符发生错误；
- EPOLLHUP：表示对应的文件描述符被挂断；
- EPOLLET: 将 EPOLL 设为边缘触发(Edge Triggered)模式，这是相对于水平触发(Level Triggered)来说的。
- EPOLLONESHOT：只监听一次事件，当监听完这次事件之后，如果还需要继续监听这个 socket 的话，需要再次把这个 socket 加入到 EPOLL 队列里

### int epoll_wait(int epfd, struct epoll_event \* events, int maxevents, int timeout);

等 待事件的产生，类似于 select()调用。参数 events 用来从内核得到事件的集合，maxevents 告之内核这个 events 有多大，这个 maxevents 的值不能大于创建 epoll_create()时的 size，参数 timeout 是超时时间(毫秒，0 会立即返回，-1 将不确定，也有 说法说是永久阻塞)。该函数返回需要处理的事件数目，如返回 0 表示已超时。

## 处理逻辑

使用 epoll 来实现服务端同时接受多客户端长连接数据时，的大体步骤如下：(1)使用 epoll_create 创建一个 epoll 的句柄，下例中我们命名为 epollfd。(2)使用 epoll_ctl 把服务端监听的描述符添加到 epollfd 指定的 epoll 内核事件表中，监听服务器端监听的描述符是否可读。(3)使用 epoll_wait 阻塞等待注册的服务端监听的描述符可读事件的发生。(4)当有新的客户端连接上服务端时，服务端监听的描述符可读，则 epoll_wait 返回，然后通过 accept 获取客户端描述符。(5)使用 epoll_ctl 把客户端描述符添加到 epollfd 指定的 epoll 内核事件表中，监听服务器端监听的描述符是否可读。(6)当客户端描述符有数据可读时，则触发 epoll_wait 返回，然后执行读取。

几乎所有的 epoll 模型编码都是基于以下模板：

```c
for( ; ; )
{
    // 阻塞式等待事件
    nfds = epoll_wait(epfd,events,20,500);
    for(i=0;i<nfds;++i)
    {
        if(events[i].data.fd==listenfd) //有新的连接
        {
            connfd = accept(listenfd,(sockaddr *)&clientaddr, &clilen); //accept这个连接
            ev.data.fd=connfd;
            ev.events=EPOLLIN|EPOLLET;
            epoll_ctl(epfd,EPOLL_CTL_ADD,connfd,&ev); //将新的fd添加到epoll的监听队列中
        }
        else if(events[i].events&EPOLLIN ) //接收到数据，读socket
        {
            n = read(sockfd, line, MAXLINE)) < 0    //读
            ev.data.ptr = md;     //md为自定义类型，添加数据
            ev.events=EPOLLOUT|EPOLLET;
            epoll_ctl(epfd,EPOLL_CTL_MOD,sockfd,&ev);//修改标识符，等待下一个循环时发送数据，异步处理的精髓
        }
        else if(events[i].events&EPOLLOUT) //有数据待发送，写socket
        {
            struct myepoll_data* md = (myepoll_data*)events[i].data.ptr;    //取数据
            sockfd = md->fd;
            send( sockfd, md->ptr, strlen((char*)md->ptr), 0 );        //发送数据
            ev.data.fd=sockfd;
            ev.events=EPOLLIN|EPOLLET;
            epoll_ctl(epfd,EPOLL_CTL_MOD,sockfd,&ev); //修改标识符，等待下一个循环时接收数据
        }
        else
        {
            //其他的处理
        }
    }
}
```
