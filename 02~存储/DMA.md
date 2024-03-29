# DMA

CPU 操作外设时，将外设的数据读到内部寄存器中，再将数据传送至内存中，之所以还要讲数据送到内存，在于 CPU 内部寄存器数量很少，一般都是靠 RAM 来临时存储大量的代码和数据的。CPU 工作的核心就是一个 PC 指针，PC 指针指向什么地址，CPU 就会把相应地址处的二进制数据送至内部译码器进行译码后运行，RAM 是一个临时存放代码和数据的地方，CPU 要执行代码时，就要到内存（RAM）中去取指令。

DMA：在现代操作系统中，外设有数据到来时，基本上都采用中断方式通知 CPU，操作系统响应中断，然后再从外设读取数据，这时，如果外设的数据比较频繁，那么是否每到一个数据都中断一次呢？？这样 CPU 就非常频繁地被外调中断打断，操作系统在处理中断时要浪费一定时间，而且 CPU 读外部 IO 速度也很慢，这样的话，大量时间被用在了响应中断上，而去调度其它任务的时间减少，让人感觉系统响应速度不够，也会影响外设的数据传输速度（如果外设传输速度太快，操作系统就有可能丢失部分数据），由此引出 DMA 的机制：

![image](https://assets.ng-tech.icu/item/47349756-de961500-d6e6-11e8-84b9-6ebb1c9ef901.png)

外设直接将一块数据放在了 RAM 中，然后再产生一次中断，这样操作系统直接将内存中的那块数据传给想要获取这块数据的一个任务（或者放在内存的另一空闲部分），此时，系统就少了频繁响应外设中断的开销，也少了读取外设 IO 的时间开销（读取 RAM 比读取外设 IO 要快很多）。
