  - [1 01~进程与处理器 [8]](/01~进程与处理器/README.md)
    - [1.1 GPU](/01~进程与处理器/GPU/README.md)
      
    - [1.2 微处理器 [1]](/01~进程与处理器/微处理器/README.md)
      - [1.2.1 指令集](/01~进程与处理器/微处理器/指令集.md)
    - [1.3 总线](/01~进程与处理器/总线/README.md)
      
    - 1.4 系统服务 [3]
      - [1.4.1 BootLoader](/01~进程与处理器/系统服务/BootLoader.md)
      - [1.4.2 Systemd](/01~进程与处理器/系统服务/Systemd.md)
      - [1.4.3 服务与初始化](/01~进程与处理器/系统服务/服务与初始化.md)
    - [1.5 系统调用 [1]](/01~进程与处理器/系统调用/README.md)
      - [1.5.1 中断与异常](/01~进程与处理器/系统调用/中断与异常.md)
    - [1.6 设备管理](/01~进程与处理器/设备管理/README.md)
      
    - [1.7 进程与线程 [5]](/01~进程与处理器/进程与线程/README.md)
      - 1.7.1 01.用户态与内核态 [2]
        - [1.7.1.1 01.用户态与内核态](/01~进程与处理器/进程与线程/01.用户态与内核态/01.用户态与内核态.md)
        - 1.7.1.2 99~参考资料 [1]
          - [1.7.1.2.1 从根上理解用户态与内核态](/01~进程与处理器/进程与线程/01.用户态与内核态/99~参考资料/2021-从根上理解用户态与内核态.md)
      - [1.7.2 02.用户线程与内核线程](/01~进程与处理器/进程与线程/02.用户线程与内核线程.md)
      - [1.7.3 进程模型](/01~进程与处理器/进程与线程/进程模型.md)
      - [1.7.4 进程状态](/01~进程与处理器/进程与线程/进程状态.md)
      - [1.7.5 进程间通信](/01~进程与处理器/进程与线程/进程间通信.md)
    - [1.8 进程管理 [3]](/01~进程与处理器/进程管理/README.md)
      - [1.8.1 COW](/01~进程与处理器/进程管理/COW.md)
      - [1.8.2 Meltdown](/01~进程与处理器/进程管理/Meltdown.md)
      - [1.8.3 管理命令](/01~进程与处理器/进程管理/管理命令.md)
  - [2 02~存储 [5]](/02~存储/README.md)
    - 2.1 00~存储分层 [1]
      - [2.1.1 存储器的层次化结构](/02~存储/00~存储分层/存储器的层次化结构.md)
    - 2.2 01~内存管理 [7]
      - 2.2.1 99~参考资料 [1]
        - [2.2.1.1 一文帮小白搞懂操作系统之内存](/02~存储/01~内存管理/99~参考资料/2020-一文帮小白搞懂操作系统之内存.md)
      - [2.2.2 内存寻址](/02~存储/01~内存管理/内存寻址.md)
      - 2.2.3 段式存储管理 [1]
        - [2.2.3.1 段式存储管理](/02~存储/01~内存管理/段式存储管理/段式存储管理.md)
      - [2.2.4 物理内存分配与回收](/02~存储/01~内存管理/物理内存分配与回收.md)
      - [2.2.5 虚拟存储管理](/02~存储/01~内存管理/虚拟存储管理.md)
      - 2.2.6 页式存储管理 [4]
        - [2.2.6.1 mmap [1]](/02~存储/01~内存管理/页式存储管理/mmap/README.md)
          - [2.2.6.1.1 mmap 的内核实现](/02~存储/01~内存管理/页式存储管理/mmap/mmap%20的内核实现.md)
        - [2.2.6.2 请页式管理 [1]](/02~存储/01~内存管理/页式存储管理/请页式管理/README.md)
          - [2.2.6.2.1 Page Fault](/02~存储/01~内存管理/页式存储管理/请页式管理/Page%20Fault.md)
        - [2.2.6.3 页结构](/02~存储/01~内存管理/页式存储管理/页结构.md)
        - 2.2.6.4 预调式管理 [2]
          - [2.2.6.4.1 页缓存](/02~存储/01~内存管理/页式存储管理/预调式管理/页缓存.md)
          - [2.2.6.4.2 页面置换算法](/02~存储/01~内存管理/页式存储管理/预调式管理/页面置换算法.md)
      - [2.2.7 高速缓存](/02~存储/01~内存管理/高速缓存.md)
    - [2.3 DMA](/02~存储/DMA.md)
    - [2.4 存储 IO [2]](/02~存储/存储%20IO/README.md)
      - 2.4.1 99~参考资料 [2]
        - [2.4.1.1 Different IO Access Methods for Linux, What We Chose for ScyllaDB, and Why](/02~存储/存储%20IO/99~参考资料/2017-Different%20IO%20Access%20Methods%20for%20Linux,%20What%20We%20Chose%20for%20ScyllaDB,%20and%20Why.md)
        - [2.4.1.2 Linux IO 过程自顶向下分析](/02~存储/存储%20IO/99~参考资料/2018-Linux%20IO%20过程自顶向下分析.md)
      - [2.4.2 磁盘 IO [4]](/02~存储/存储%20IO/磁盘%20IO/README.md)
        - [2.4.2.1 AIO](/02~存储/存储%20IO/磁盘%20IO/AIO.md)
        - [2.4.2.2 SSD](/02~存储/存储%20IO/磁盘%20IO/SSD.md)
        - [2.4.2.3 块 IO 栈](/02~存储/存储%20IO/磁盘%20IO/块%20IO%20栈.md)
        - [2.4.2.4 数据存取](/02~存储/存储%20IO/磁盘%20IO/数据存取.md)
    - [2.5 文件系统 [3]](/02~存储/文件系统/README.md)
      - [2.5.1 分区与挂载](/02~存储/文件系统/分区与挂载.md)
      - [2.5.2 文件](/02~存储/文件系统/文件/README.md)
        
      - [2.5.3 文件检索](/02~存储/文件系统/文件检索.md)
  - [3 03~网络 [6]](/03~网络/README.md)
    - [3.1 Linux 网络 IO 模型](/03~网络/Linux%20网络%20IO%20模型/README.md)
      
    - 3.2 io_uring [1]
      - 3.2.1 99~参考资料 [1]
        - [3.2.1.1 io_uring：基本原理、程序示例与性能压测](/03~网络/io_uring/99~参考资料/io_uring：基本原理、程序示例与性能压测.md)
    - [3.3 多路复用 [2]](/03~网络/多路复用/README.md)
      - [3.3.1 epoll [2]](/03~网络/多路复用/epoll/README.md)
        - 3.3.1.1 99~参考资料 [2]
          - [3.3.1.1.1 深入浅出让你彻底理解 epoll](/03~网络/多路复用/epoll/99~参考资料/2020-深入浅出让你彻底理解%20epoll.md)
          - [3.3.1.1.2 十个问题理解 Linux epoll 工作原理](/03~网络/多路复用/epoll/99~参考资料/2021-十个问题理解%20Linux%20epoll%20工作原理.md)
        - [3.3.1.2 epoll 函数使用](/03~网络/多路复用/epoll/epoll%20函数使用.md)
      - [3.3.2 select](/03~网络/多路复用/select.md)
    - [3.4 网卡设备](/03~网络/网卡设备/README.md)
      
    - 3.5 网络操作系统 [1]
      - [3.5.1 TencentOS](/03~网络/网络操作系统/TencentOS.md)
    - [3.6 零拷贝 [1]](/03~网络/零拷贝/README.md)
      - [3.6.1 Linux 下的实现](/03~网络/零拷贝/Linux%20下的实现.md)
  - [4 04~eBPF [1]](/04~eBPF/README.md)
    - 4.1 99~参考资料 [2]
      - [4.1.1 从石器时代到成为“神”，一文讲透 eBPF 技术发展演进史](/04~eBPF/99~参考资料/2023-从石器时代到成为“神”，一文讲透%20eBPF%20技术发展演进史.md)
      - [4.1.2 无声的平台革命：eBPF 是如何从根本上改造云原生平台的](/04~eBPF/99~参考资料/2023-无声的平台革命：eBPF%20是如何从根本上改造云原生平台的.md)
  - [5 10~Shell 命令 [11]](/10~Shell%20命令/README.md)
    - 5.1 99~参考资料 [1]
      - [5.1.1 2021~《Bash 脚本教程》](/10~Shell%20命令/99~参考资料/2021~《Bash%20脚本教程》/README.md)
        
    - [5.2 CentOS](/10~Shell%20命令/CentOS/README.md)
      
    - [5.3 Nushell](/10~Shell%20命令/Nushell/README.md)
      
    - [5.4 Shell 编程 [5]](/10~Shell%20命令/Shell%20编程/README.md)
      - [5.4.1 交互式 Shell [2]](/10~Shell%20命令/Shell%20编程/交互式%20Shell/README.md)
        - [5.4.1.1 Funny Terminals](/10~Shell%20命令/Shell%20编程/交互式%20Shell/Funny%20Terminals.md)
        - [5.4.1.2 菜单与对话框](/10~Shell%20命令/Shell%20编程/交互式%20Shell/菜单与对话框.md)
      - [5.4.2 函数 [3]](/10~Shell%20命令/Shell%20编程/函数/README.md)
        - [5.4.2.1 函数定义](/10~Shell%20命令/Shell%20编程/函数/函数定义.md)
        - [5.4.2.2 函数调用](/10~Shell%20命令/Shell%20编程/函数/函数调用.md)
        - [5.4.2.3 局部变量与返回](/10~Shell%20命令/Shell%20编程/函数/局部变量与返回.md)
      - [5.4.3 文件操作](/10~Shell%20命令/Shell%20编程/文件操作/README.md)
        
      - [5.4.4 流程控制 [3]](/10~Shell%20命令/Shell%20编程/流程控制/README.md)
        - [5.4.4.1 循环](/10~Shell%20命令/Shell%20编程/流程控制/循环.md)
        - [5.4.4.2 条件判断](/10~Shell%20命令/Shell%20编程/流程控制/条件判断.md)
        - [5.4.4.3 条件选择](/10~Shell%20命令/Shell%20编程/流程控制/条件选择.md)
      - [5.4.5 语法基础 [4]](/10~Shell%20命令/Shell%20编程/语法基础/README.md)
        - [5.4.5.1 变量](/10~Shell%20命令/Shell%20编程/语法基础/变量.md)
        - [5.4.5.2 字符串](/10~Shell%20命令/Shell%20编程/语法基础/字符串.md)
        - [5.4.5.3 数值类型](/10~Shell%20命令/Shell%20编程/语法基础/数值类型.md)
        - [5.4.5.4 表达式](/10~Shell%20命令/Shell%20编程/语法基础/表达式.md)
    - [5.5 命令执行 [5]](/10~Shell%20命令/命令执行/README.md)
      - [5.5.1 参数与返回](/10~Shell%20命令/命令执行/参数与返回.md)
      - [5.5.2 执行环境](/10~Shell%20命令/命令执行/执行环境.md)
      - [5.5.3 管道与连接](/10~Shell%20命令/命令执行/管道与连接.md)
      - [5.5.4 输入与输出](/10~Shell%20命令/命令执行/输入与输出.md)
      - [5.5.5 重定向](/10~Shell%20命令/命令执行/重定向.md)
    - 5.6 快速开始 [2]
      - [5.6.1 Unix 设计哲学](/10~Shell%20命令/快速开始/Unix%20设计哲学.md)
      - [5.6.2 常用 Unix 命令的现代替代](/10~Shell%20命令/快速开始/常用%20Unix%20命令的现代替代.md)
    - [5.7 文本处理 [5]](/10~Shell%20命令/文本处理/README.md)
      - [5.7.1 Nano](/10~Shell%20命令/文本处理/Nano.md)
      - [5.7.2 Vim](/10~Shell%20命令/文本处理/Vim.md)
      - [5.7.3 awk](/10~Shell%20命令/文本处理/awk.md)
      - [5.7.4 sed](/10~Shell%20命令/文本处理/sed.md)
      - [5.7.5 文本检索](/10~Shell%20命令/文本处理/文本检索.md)
    - 5.8 用户权限 [3]
      - [5.8.1 权限控制](/10~Shell%20命令/用户权限/权限控制.md)
      - [5.8.2 用户管理](/10~Shell%20命令/用户权限/用户管理.md)
      - [5.8.3 系统权限](/10~Shell%20命令/用户权限/系统权限.md)
    - [5.9 磁盘文件 [2]](/10~Shell%20命令/磁盘文件/README.md)
      - [5.9.1 iostat](/10~Shell%20命令/磁盘文件/iostat.md)
      - [5.9.2 创建与读写](/10~Shell%20命令/磁盘文件/创建与读写.md)
    - [5.10 系统进程 [2]](/10~Shell%20命令/系统进程/README.md)
      - [5.10.1 进程控制](/10~Shell%20命令/系统进程/进程控制.md)
      - [5.10.2 进程查看](/10~Shell%20命令/系统进程/进程查看.md)
    - [5.11 网络 [6]](/10~Shell%20命令/网络/README.md)
      - [5.11.1 SSH](/10~Shell%20命令/网络/SSH.md)
      - [5.11.2 netstat](/10~Shell%20命令/网络/netstat.md)
      - [5.11.3 网卡配置](/10~Shell%20命令/网络/网卡配置.md)
      - [5.11.4 网络工具](/10~Shell%20命令/网络/网络工具.md)
      - [5.11.5 网络请求](/10~Shell%20命令/网络/网络请求.md)
      - [5.11.6 路由与映射](/10~Shell%20命令/网络/路由与映射.md)
  - [6 INTRODUCTION](/INTRODUCTION.md)