# 存储与 IO 必知必会

![The Linux Storage Stack Diagram](https://assets.ng-tech.icu/item/20230622203509.png)

计算机的内存往往包括了 RAM 与 ROM，ROM 表示的是只读存储器，即：它只能读出信息，不能写入信息，计算机关闭电源后其内的信息仍旧保存，如计算机启动用的 BIOS 芯片。RAM 表示的是读写存储器，可其中的任一存储单元进行读或写操作，计算机关闭电源后其内的信息将不在保存，再次开机需要重新装入，通常用来存放操作系统，各种正在运行的软件、输入和输出数据、中间结果及与外存交换信息等，我们常说的内存主要是指 RAM。

所谓外存/辅存(Storage)，狭义上是讲的硬盘；准确地说，是外部存储器（需要通过 IO 系统与之交换数据，全称为辅助存储设备）。

计算机硬件性能在过去十年间的发展普遍遵循摩尔定律，通用计算机的 CPU 主频早已超过 3GHz，内存也进入了普及 DDR4 的时代。然而传统硬盘虽然在存储容量上增长迅速，但是在读写性能上并无明显提升，同时 SSD 硬盘价格高昂，不能在短时间内完全替代传统硬盘。传统磁盘的 IO 读写速度成为了计算机系统性能提高的瓶颈，制约了计算机整体性能的发展。

# 存储 IO 的耗时

### 计算机存储体系

![存储体系示意图](https://2836672763-files.gitbook.io/~/files/v0/b/gitbook-legacy-files/o/assets%2F-LMjQD5UezC9P8miypMG%2F-LY_HB8UaEfE1efciC8V%2F-LY_K0SNgM4yb-lsVBlJ%2FScreen%20Shot%202019-02-13%20at%201.28.29%20PM.jpg?alt=media&token=8cd28260-ebb5-4729-8a41-732675a64afc)

![不同存储器的数据获取时间对照表](https://2836672763-files.gitbook.io/~/files/v0/b/gitbook-legacy-files/o/assets%2F-LMjQD5UezC9P8miypMG%2F-LY_HB8UaEfE1efciC8V%2F-LY_Kgs6xp4XVNA9n-FF%2FScreen%20Shot%202019-02-13%20at%201.31.21%20PM.jpg?alt=media&token=f4dade9f-4870-4c87-83bb-bd419e087ce1)

```sh
L1 cache reference 0.5 ns

Branch mispredict 5 ns

L2 cache reference 7 ns

Mutex lock/unlock 25 ns

Main memory reference 100 ns

Compress 1K bytes with Zippy 3,000 ns

Send 2K bytes over 1 Gbps network 20,000 ns

Read 1 MB sequentially from memory 250,000 ns

Round trip within same datacenter 500,000 ns

Disk seek 10,000,000 ns

Read 1 MB sequentially from disk 20,000,000 ns

Send packet CA->Netherlands->CA 150,000,000 ns
```

# Links

- https://my.oschina.net/ericquan8/blog/1836953
