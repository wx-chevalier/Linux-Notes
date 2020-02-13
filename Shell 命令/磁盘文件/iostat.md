# iostat

```sh
$ iostat -x -d 2

Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
vda               0.00     0.25    0.04    0.53     0.56     4.88    19.25     0.00    6.85    3.09    7.14   0.25   0.01
```

iostat 算是比较重要的查看块设备运行状态的工具，它数据的来源是 Linux 操作系统的/proc/diskstats。一般来说用法如下：`iostat -mtx 2`，即每 2 秒钟采集一组数据。假如我们对某块磁盘进行读写压测：

```sh
$ fio --name=randwrite --rw=randwrite --bs=4k --size=20G --runtime=1200 --ioengine=libaio --iodepth=64 --numjobs=1 --rate_iops=5000 --filename=/dev/sdf --direct=1 --group_reporting  
```

使用 iostat 可以查看如下结果：

![](https://ww1.sinaimg.cn/large/007rAy9hgy1g2104el9uaj30u00fi40h.jpg)

上图中，%util，即为磁盘 I/O 利用率，同 CPU 利用率一样，这个值也可能超过 100%（存在并行 I/O）；rkB/s 和 wkB/s 分别表示每秒从磁盘读取和写入的数据量，即吞吐量，单位为 KB；磁盘 I/O 处理时间的指标为 r_await 和 w_await 分别表示读/写请求处理完成的响应时间，svctm 表示处理 I/O 所需要的平均时间，该指标已被废弃，无实际意义。r/s + w/s 为 IOPS 指标，分别表示每秒发送给磁盘的读请求数和写请求数；aqu-sz 表示等待队列的长度。

- rrqm/s : 每秒合并读操作的次数，块设备有相应的调度算法。如果两个 IO 发生在相邻的数据块时，他们可以合并成 1 个 IO。

- wrqm/s: 每秒合并写操作的次数

- r/s：每秒读操作的次数

- w/s : 每秒写操作的次数

- rMB/s :每秒读取的 MB 字节数

- wMB/s: 每秒写入的 MB 字节数

- avgrq-sz：每个 IO 的平均扇区数，即所有请求的平均大小，以扇区（512 字节）为单位。

- avgqu-sz：平均为完成的 IO 请求数量，即平均意义山的请求队列长度，该值越大，表示排队等待处理的 io 越多。

- await：平均每个 IO 所需要的时间，包括在队列等待的时间，也包括磁盘控制器处理本次请求的有效时间。

- r_wait：每个读操作平均所需要的时间，不仅包括硬盘设备读操作的时间，也包括在内核队列中的时间。

- w_wait: 每个写操平均所需要的时间，不仅包括硬盘设备写操作的时间，也包括在队列中等待的时间。

- svctm：表面看是每个 IO 请求的服务时间，不包括等待时间，但是实际上，这个指标已经废弃。实际上，iostat 工具没有任何一输出项表示的是硬盘设备平均每次 IO 的时间。

- %util：工作时间或者繁忙时间占总时间的百分比。

值得关注的是，avgrq-sz 这个值反应了用户的 IO 模式，即用户过来的 IO 是大 IO 还是小 IO。如果我们 fio 命令设置的 bs 为 4k，那么 sdc 的 avgrq-sz 总是 8，即`8个扇区 = 8*512（Byte）= 4KB`。
