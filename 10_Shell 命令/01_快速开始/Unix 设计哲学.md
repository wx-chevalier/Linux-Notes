# Unix 设计哲学

## 核心理念的起源

Unix 管道的概念最初由道格·麦克罗伊（Doug McIlroy）在 1964 年提出："当我们需要将消息从一个程序传递另一个程序时，我们需要一种类似水管法兰的拼接程序的方式，I/O 应该也按照这种方式进行"。这个水管的类比至今仍然适用，并发展成为现在所称的 Unix 哲学。

## Unix 的基本原则

### 英文原则

- **Do one thing and do it well** - 编写专注于单一任务且能很好完成的程序，设计程序时考虑协同工作，使用文本流作为通用接口。
- **Everything is file** - 通过将硬件视为文件来提供易用性和安全性。
- **Small is beautiful**
- **Store data and configuration in flat text files** - 文本文件是通用接口，易于创建、备份和迁移。
- **Use shell scripts to increase leverage and portability** - 使用 shell 脚本在不同 Unix/Linux 系统间自动化常见任务。
- **Chain programs together to complete complex task** - 使用管道和过滤器链接小型工具来完成复杂任务。
- **Choose portability over efficiency**
- **Keep it Simple, Stupid (KISS)**

### 中文诠释

1. 专注性：每个程序只做好一件事，需要新功能时创建新程序，而不是使现有程序复杂化。
2. 组合性：程序的输出应该能作为另一个程序的输入，避免无关信息和严格的数据格式。
3. 快速迭代：尽早尝试，快速构建，勇于重构。
4. 工具优先：优先使用工具来简化编程任务，即使需要专门开发工具。

## Unix 设计的关键特性

### 统一接口

- 文件作为基本接口（文件描述符）
- 所有资源都表现为字节序列
- 统一接口使得不同组件易于连接
- ASCII 文本作为常用数据格式

### 逻辑与布线分离

- 标准输入（stdin）和标准输出（stdout）的设计
- 程序无需关心数据来源和去向
- 支持灵活的组件组合
- 通过管道实现程序间通信

### 透明度和实验性

- 输入文件通常不可变
- 随时可以检查管道输出
- 支持分段处理和调试
- 便于实验和优化

## 现代意义

这种设计方法与现代软件开发理念高度吻合：

- 自动化
- 快速原型
- 增量迭代
- 模块化
- 类似于现代敏捷开发和 DevOps 理念
