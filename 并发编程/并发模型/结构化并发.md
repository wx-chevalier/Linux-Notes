# 结构化并发

在多线程模型中，下面几个问题给程序员带来了更多复杂性和更重的心智负担。

- 这个任务什么时候开始，什么时候结束？
- 怎么做到当所有子任务都结束，主任务再结束？
- 假如某个子任务失败，主任务如何终止掉其他子任务？
- 如何保证所有子任务在某个特定的超时时间内返回，无论它成功还是失败？
- 更进一步，如何保证主任务在规定的时间内返回，无论其成功还是失败，同时终止掉它产生的所有子任务？
- 主任务已经结束了，子任务还在运行，是不是存在资源泄漏？

有没有一种编程范式，既可以解决这些问题，又具有相对比较低的认知门槛，同时也不需要像 Golang Context 那样侵入应用程序的接口？结构化并发(Structured Concurrency) 就是这样一种并发编程范式。

2016 年，ZerMQ 的作者 Martin Sústrik 在他的文章[5]中第一次形式化的提出结构化并发这个概念。2018 年 Nathaniel J. Smith (njs) 在 Python 中实现了这一范式 - trio[6]，并在 Notes on structured concurrency, or: Go statement considered harmful[7] 一文中进一步阐述了 Structured Concurrency。同时期，Roman Elizarov 也提出了相同的理念[8]，并在 Kotlin 中实现了大家熟知的 kotlinx.coroutine[9]。2019 年，OpenJDK loom project 也开始引入 structured concurrency，作为其轻量级线程和协程的一部分。

Structured Concurrency 核心在于通过一种 structured 的方法实现并发程序，用具有明确入口点和出口点的控制流结构来封装并发“线程”（可以是系统级线程也可以是用户级线程，也就是协程，甚至可以是进程）的执行，确保所有派生“线程”在出口之前完成。如下例：

```go
func main_func() {
  go myfunc()
  go anotherfunc()
  <rest of program>...
}
```

![](https://s2.ax1x.com/2020/02/20/3ZtNA1.png)

假设上图中的代码具有 structured concurrency 特性（这里用的是 golang 的语法来展示）。main_func 里，创建了两个子任务：myfunc(), anotherfunc()，这里的 func 是一个控制流结构，入口就是 func 调用开始，出口是 func 调用结束，派生出来的两个子任务需要在 main_func 调用结束之前先完成。当 main_func 结束，它涉及到的资源也都会被释放掉。外部调用者无法也无需感知 main_func 里面到底是串行的还是并行的，它只需要调用 main_func，然后等待它结束即可。这就是所谓的 Structured。
