# 系统进程

sar

是目前 Linux 上最为全面的系统性能分析工具之一，但可能没有预装。在 centos 上使用以下命令即可安装。

yum install sysstat -y
sar 主要的好处是可以看到历史，显示友好，可以对结果进行二次处理。sar 还有图形化工具，执行 sar -A 即可获得所有数据。

https://github.com/vlsi/ksar
针对于 CPU 方面，我们关注：
➊ sar -u 默认
➋ sar -P ALL 每颗 cpu 的使用状态信息
➌ sar -q cpu 队列的长度，runq-sz>cpu count 就表明有瓶颈了
➍ sar -w 每秒上下文交换

mpstat

还有 pidstat，包括彩色的 dstat，功能都差不多

load 为 1 代表的是啥

针对这个问题，误解还是比较多的。很多同学认为，load 达到 1，系统就到了瓶颈，这不完全正确。
load 的值和 cpu 核数息息相关：
➊ 单核的 cpu 达到 100%，load 约 1
➋ 双核的 cpu 都达到 100%，load 约 2
➌ 四核的 cpu 都达到 100%，load 约为 4

## CPU

CPU 利用率是业务系统利用到 CPU 的比率，因为往往一个系统上会有一些其他的线程，这些线程会和 CPU 竞争计算资源，那么此时留给业务的计算资源比例就会下降，典型的像，GC 线程的 GC 过程、锁的竞争过程都是消耗 CPU 的过程。甚至一些 IO 的瓶颈，也会导致 CPU 利用率下降(CPU 都在 Wait IO，利用率当然不高)。

## 内存

```sh
# 查看系统当前的内存
$ free -h
              total        used        free      shared  buff/cache   available
Mem:           7.8G        1.2G        627M         85M        6.0G        6.0G
Swap:            0B          0B          0B
```

上图中总内存与可用内存差值出现不一致性，是因为 OS 发现系统的物理内存有大量剩余时，为了提高 IO 的性能，就会使用多余的内存当做文件缓存。

## CPU 利用率详解

/proc/stat 存储的是系统的一些统计信息。

```sh
cpu  117450 5606 72399 476481991 1832 0 2681 0 0 0
cpu0 31054 90 19055 119142729 427 0 1706 0 0 0
cpu1 22476 3859 18548 119155098 382 0 272 0 0 0
cpu2 29208 1397 19750 119100548 462 0 328 0 0 0
cpu3 34711 258 15045 119083615 560 0 374 0 0 0

     (us)  (ni)    (sy)     (id)      (wa)   (hi)  (si)  (st) (guest) (guest_nice)
```

对于 CPU 利用率描述，Linux man-pages 用的都是 time（time running，time spent，time stolen）这个单词。这里的统计数据，其实就是 CPU 从系统启动至当前，各项（us, sy, ni, id, wa, hi, si, st）占用的时间，单位是 jiffies。通过 sysconf(\_SC_CLK_TCK) 可以获得 1 秒被分成多少个 jiffies。一般是 100，即 1 jiffies == 0.01 s。

计算 CPU 使用率的基本原理就是从 /proc/stat 进行采样和计算。最简单的方法，一秒采样一次 /proc/stat，如：
第 N 秒采样得到 cpu_total1 = us1 + ni1 + sy1 + id1 + wa1 + hi1 + si1 + st1 + guest1 + guest_nice1
第 N+1 秒采样得到 cpu_total2 = us2 + ni2 + sy2 + id2 + wa2 + hi2 + si2 + st2 + guest2 + guest_nice2
us 的占比为 (us2 - us1) / (cpu_total2 - cpu_total1)。

nice 是一个可以修改进程调度优先级的命令，在 Linux 中，一个进程有一个 nice 值，代表的是这个进程的调度优先级。越 nice（nice 值越大）的进程，调度优先级越低，越会“谦让”，所以它的获得 CPU 的机会就越低。ni 代表的是 niced 用户态进程消耗的 CPU。

如果 sy 过高，说明程序调用 Linux 系统调用的开销很大，不同的系统调用开销不一样，pthread_create 的开销比较大。

wa 高，不能说明系统的 IO 有问题。如果整个系统只有简单任务不停地进行 IO，此时的 wa 可能很高，而系统磁盘的 IO 也远远没达到上限。假设有个单核的系统。CPU 并不会真的“死等” IO。此时的 CPU 实际是 idle 的，如果有其它进程可以运行，则运行其它进程，此时 CPU 时间就不算入 iowait。如果此时系统没有其它进程需要运行，则 CPU 需要“等”这次 IO 完成才可以继续运行，此时“等待”的时间算入 iowait。wa 低，也不能说明系统的 IO 没问题。假设机器进行大量的 IO 任务把磁盘带宽打得慢慢的，同时还有计算任务把 CPU 也跑得满满的。此时 wa 很低，但系统 IO 压力很大。

系统调用会触发软中断，网卡收到数据包后，网卡驱动会通过软中断通知 CPU。

```sh
$ iperf -s -i 1  # 服务端

$ iperf -c 192.168.1.4 -i 1 -t 60 # 客户端，可以开几个 terminal 执行多个客户端，这样 si 的变化才会比较明显

%Cpu(s):  1.7 us, 74.1 sy,  0.0 ni,  8.0 id,  0.0 wa,  0.0 hi, 16.2 si,  0.0 st
```

st 和虚拟化相关，利用虚拟化技术，一台 32 CPU 核心的物理机，可以创建出几十上百个单 CPU 核心的虚拟机。这在公有云场景下，简称“超卖”。大部分情况下，物理服务器的资源有大量是闲置的。此时，“超卖”并不会造成明显影响。当很多虚拟机的 CPU 压力变大，此时物理机的资源明显不足，就会造成各个虚拟机之间相互竞争、相互等待。st 就是用来衡量被 Hypervisor “偷去” 给其它虚拟机使用的 CPU。这个值越高，说明这台物理服务器的资源竞争越激烈。
