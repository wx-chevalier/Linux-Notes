# select/poll 多路复用详解

## 1. 问题引入

让我们先看一个简单的服务器示例，来理解为什么需要多路复用：

```c
while (1) {
    clin_len = sizeof(clin_addr);
    cfd = accept(lfd, (struct sockaddr *)&clin_addr, &clin_len);

    while (len = read(cfd, recvbuf, BUFSIZE)) {
        write(STDOUT_FILENO, recvbuf, len);
        if (strncasecmp(recvbuf, "stop", 4) == 0) {
            close(cfd);
            break;
        }
    }
}
```

**存在的问题：**

- 当多个客户端连接时，服务器会阻塞在第一个客户端
- 直到第一个客户端发送"stop"，才能处理下一个客户端的请求

## 2. select 介绍

### 2.1 函数原型

```c
select(int nfds, fd_set *r, fd_set *w, fd_set *e, struct timeval *timeout)
```

### 2.2 主要参数

- `maxfdp1`: 描述符总数
- `fd_set`: 描述符集合（bitmap 结构）
- `timeout`: 等待超时时间
- r, w, e: 分别表示读、写、异常事件集合

### 2.3 select 的局限性

1. bitmap 大小限制（通常为 1024）
2. 每次调用需要重新设置集合
3. 返回后需要遍历整个集合
4. 内核需要遍历所有 fd 检查事件

## 3. poll 改进

### 3.1 函数原型

```c
poll(struct pollfd *fds, int nfds, int timeout)

struct pollfd {
    int fd;
    short events;    // 感兴趣的事件
    short revents;   // 实际发生的事件
}
```

### 3.2 相比 select 的改进

- 突破了文件描述符数量限制
- 分离了感兴趣事件和实际发生事件

## 4. 多路复用实现示例

关键实现逻辑：

```c
while (1) {
    // 1. 重置读集合
    read_set = read_set_init;

    // 2. 添加已连接的客户端fd
    for (i = 0; i < FD_SET_SIZE; ++i) {
        if (client[i] > 0) {
            FD_SET(client[i], &read_set);
        }
    }

    // 3. 等待事件发生
    retval = select(maxfd + 1, &read_set, NULL, NULL, NULL);

    // 4. 处理新连接
    if (FD_ISSET(lfd, &read_set)) {
        // 处理新客户端连接
    }

    // 5. 处理已连接客户端的数据
    for (i = 0; i < maxi; ++i) {
        if (client[i] < 0) continue;

        if (FD_ISSET(client[i], &read_set)) {
            // 处理客户端数据
        }
    }
}
```

## 5. 内核处理流程

1. 从用户空间复制 fd_set 到内核空间
2. 注册 pollwait 回调函数
3. 遍历所有 fd，调用对应的 poll 方法
4. 根据 poll 结果设置 fd_set
5. 必要时让进程睡眠等待事件
6. 将结果复制回用户空间
