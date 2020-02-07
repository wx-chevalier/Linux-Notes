# vmstat

使用 vmstat 命令，可以查看到「上下文切换次数」这个指标，如下表所示，每隔 1 秒输出 1 组数据：

```sh
$ vmstat 1
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 0  0      0 5921968 1536888 16818972    0    0     0    75    1    0  4  2 95  0  0
```

上表的 cs（context switch）就是每秒上下文切换的次数，按照不同场景，CPU 上下文切换还可以分为中断上下文切换、线程上下文切换和进程上下文切换三种，但是无论是哪一种，过多的上下文切换，都会把 CPU 时间消耗在寄存器、内核栈以及虚拟内存等数据的保存和恢复上，从而缩短进程真正运行的时间，导致系统的整体性能大幅下降。vmstat 的输出中 us、sy 分别用户态和内核态的 CPU 利用率，这两个值也非常具有参考意义。

vmstat 的输只给出了系统总体的上下文切换情况，要想查看每个进程的上下文切换详情（如自愿和非自愿切换），需要使用 pidstat，该命令还可以查看某个进程用户态和内核态的 CPU 利用率。

# dstat

```sh
--total-cpu-usage-- -dsk/total- -net/total- ---paging-- ---system--
usr sys idl wai stl| read  writ| recv  send|  in   out | int   csw
  4   1  95   0   0| 735B  592k|   0     0 |   0     0 |5465    33k
  8   3  90   0   0|   0   168k| 428k  429k|   0     0 |  10k   41k
  3   1  97   0   0|   0   208k| 128k  149k|   0     0 |8106    31k
```

# pidstat

```sh
Linux 4.15.0-58-generic (master) 	11/19/2019 	_x86_64_	(8 CPU)

01:58:10 PM   UID       PID    %usr %system  %guest   %wait    %CPU   CPU  Command
01:58:10 PM     0         1    0.34    0.23    0.00    0.00    0.57     0  systemd
01:58:10 PM     0         2    0.00    0.00    0.00    0.00    0.00     2  kthreadd
01:58:10 PM     0         7    0.00    0.01    0.00    0.01    0.01     0  ksoftirqd/0
```
