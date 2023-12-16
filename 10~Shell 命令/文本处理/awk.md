# awk

awk 是一种可以处理数据、产生格式化报表的语言。awk 的工作方式是读取数据文件，将每一行数据视为一条记录，每条记录以分隔符分成若干字段，然后输出。awk 常用的格式：

1. awk '样式' 文件，把符合样式的数据显示出来。
2. awk '{操作}' 文件，对每一行都执行｛｝中的操作。
3. awk '样式{操作}' 文件，对符合样式的数据进行括号里的操作。

```sh
$ echo 'BEGIN' | awk '{print $0 "\nline one\nline two\nline three"}'
BEGIN
line one
line two
line three

# 输出指定分割参数
$ route -n | awk '/UG[ \t]/{print $2}'

# 计算文件中的数值和
$ awk '{s+=$1} END {printf "%.0f", s}' mydatafile
# 显示含 La 的数据行
awk '/La/' 1.log
# 显示每一行的第1和第2个字段
awk '{print $1, $2}' 1.log
# 将含有 La 关键词的数据行的第 1 以及第 2 个字段显示出来
awk '/La/{print $1, $2}' 1.log

# EGIN 后紧跟的操作，在 awk 命令开始匹配第一行时执行，END 后面紧跟的操作在处理完后执行
$ awk 'BEGIN {count=0}{count++} END{print count}' /etc/passwd
$ awk -F ':' 'BEGIN {count=0;} {name[count] = $1;count++;}; END{for (i = 0; i < NR; i++) print i, name[i]}' /etc/passwd
# 仅显示前 5 行
$ awk -F : 'NR > 1 && NR <=5 {print $1}' /etc/passwd
# 移除重复行
$ awk '!visited[$0]++' your_file > deduplicated_file
# 显示与 root 相关的用户
$ awk -F : '/^root/{print $1, $2}'  /etc/passwd
```

awk 也常用于与其他系统命令的协同操作：

```sh
# NF 表示的是浏览记录的域的个数，$NF 表示的最后一个Field（列），即输出最后一个字段的内容
$ free -m | grep buffers\/ | awk '{print $NF}'

$ ps aux | awk '{print $2}'  #获取所有进程PID
```

## 内置变量

```sh
ARGC               命令行参数个数
ARGV               命令行参数排列
ENVIRON            支持队列中系统环境变量的使用
FILENAME           awk浏览的文件名
FNR                浏览文件的记录数
FS                 设置输入域分隔符，等价于命令行 -F选项
NF                 浏览记录的域的个数
NR                 已读的记录数
OFS                输出域分隔符
ORS                输出记录分隔符
RS                 控制记录分隔符
```
