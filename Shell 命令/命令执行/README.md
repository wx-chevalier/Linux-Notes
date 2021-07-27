# Shell 命令执行基础

# 执行环境

Shell 首先检查命令是否是内部命令，不是的话再检查是否是一个应用程序，这里的应用程序可以是 Linux 本身的实用程序，比如 ls rm，然后 Shell 试着在搜索路径(`$PATH`)里寻找这些应用程序。搜索路径是一个能找到可执行程序的目录列表。如果你键入的命令不是一个内部命令并且在路径里没有找到这个可执行文件，将会显示一条错误信息。而如果命令被成功的找到的话，Shell 的内部命令或应用程序将被分解为系统调用并传给 Linux 内核。

## 环境变量

默认的 Bourne Shell 会从 `~/.profile` 文件中读取并且执行命令。而 Bash 会从

~/.profile is the place to put stuff that applies to your whole session, such as programs that you want to start when you log in (but not graphical programs, they go into a different file), and environment variable definitions.

~/.bashrc is the place to put stuff that applies only to bash itself, such as alias and function definitions, shell options, and prompt settings. (You could also put key bindings there, but for bash they normally go into ~/.inputrc.)

~/.bash_profile can be used instead of ~/.profile, but it is read by bash only, not by any other shell. (This is mostly a concern if you want your initialization files to work on multiple machines and your login shell isn't bash on all of them.) This is a logical place to include ~/.bashrc if the shell is interactive. I recommend the following contents in ~/.bash_profile:

```sh
if [ -r ~/.profile ]; then . ~/.profile; fi

case "$-" in *i*) if [ -r ~/.bashrc ]; then . ~/.bashrc; fi;; esac
```

![](https://zwischenzugs.files.wordpress.com/2018/01/shell-startup-actual.png?w=840)

## 执行目录

`cd` 命令可以切换工作路径，输入 `cd ~` 可以进入 home 目录，`..` 返回上一级目录。要访问你的 home 目录中的文件，可以使用前缀 `~`(例如 `~/.bashrc`)。

在 Shell 脚本里则用环境变量 `$HOME` 指代 home 目录的路径。而在 Bash 脚本中，同样可以使用 `cd` 命令切换工作目录，但是对于那些需要临时切换目录的情景，我们可以使用小括号进行控制：

```sh
# do something in current dir
(cd /some/other/dir && other-command)
# continue in original dir
```

在 Shell 脚本的首部，我们经常会定位到脚本所在的目录：

```sh
#!/bin/bash
cd "$(dirname "$0")" # Go to the script's directory
```

# 历史记录

最常用的历史记录检索方式就是使用 `history`:

```sh
# 顺序查看
$ history | more
1  2008-08-05 19:02:39 service network restart
...

# 查看最新的命令
$ history | tail -3
```

反馈的命令记录中存在编号，我们可以根据编号来重复执行历史记录中的命令：

```sh
$ !4
cat /etc/redhat-release
Fedora release 9 (Sulphur)
```

使用 `history -c` 能够清除所有的历史记录，或者设置 HISTSIZE 环境变量以避免记录：

```sh
$ export HISTSIZE=0
$ history

# [Note that history did not display anything]
```

`history` 命令往往只会记录用户交互式的命令内容，更详细的操作记录可以使用 `more /var/log/messages` 查看记录文件。

# 输入辅助

使用 `ctrl-w` 删除最后一个单词，使用 `ctrl-u` 删除自光标处到行首的内容，使用 `ctrl-k` 删除自光标处到行末的内容；使用 `ctrl-b` 与 `ctrl-f` 按字母进行前后移动；使用 `ctrl-a` 将光标移动到行首，使用 `ctrl-e` 将光标移动到行末。

为了方便编辑长命令，我们可以设置自己的默认编辑器(系统默认是 Emacs)，`export EDITOR=vim`，使用 `ctrl-x ctrl-e` 会打开一个编辑器来编辑当前输入的命令。

对于较长的命令，可以使用 `alias` 创建常用命令的快捷方式，譬如 `alias ll = 'ls -latr'` 创建新的名为 `ll` 的快捷方式。也可以使用 `{...}` 来进行命令简写：

```sh
# 同时移动两个文件
$ mv foo.{txt,pdf} some-dir
# Copy 'filename' as 'filename.bak.
$ cp filename{,.bak}

# 会被扩展成 cp somefile somefile.bak
$ cp somefile{,.bak}

# 会被扩展成所有可能的组合，并创建一个目录树
$ mkdir -p test-{a,b,c}/subtest-{1,2,3}
```

我们也可以使用 Control+R 来进行交互式检索：

```sh
$ [Press Ctrl+R from the command prompt,
which will display the reverse-i-search prompt]
(reverse-i-search)`red': cat /etc/redhat-release
[Note: Press enter when you see your command,
which will execute the command from the history]
```

# 命令连接

如果我们希望仅在前一个命令执行成功之后执行后一个命令，则需要使用 && 命令连接符：

```sh
cd /my_folder && rm *.jar && svn co path to repo && mvn compile package install

# 也可以写为多行模式
cd /my_folder \
&& rm *.jar \
&& svn co path to repo \
&& mvn compile package install
```

如果我们希望能够无论前一个命令是否成功皆开始执行下一个命令，则可以使用 `;` 分隔符：

```sh
cd /my_folder; rm *.jar; svn co path to repo; mvn compile package install
```

## 管道

- `|` 一种管道，其左方是一个命令的 STNOUT，将作为管道右方的另一个命令的 STDIN。例如：echo ‘test text’ | wc -l

- `>` 大于号，作用是取一个命令 STDOUT 位于左方，并将其写入 / 覆写(overwrite)入右方的一个新文件。例如：ls > tmp.txt

- `>>` 两个大于号，作用是取一个命令 STDOUT 位于左方，并将其追加到右方的一个新的或现有文件中。例如：date >> tmp.txt

## 参数切割

使用 `xargs` 将长列表参数切分为可用的短列表，常用的命令譬如：

```sh
# 搜索名字中包含 Stock 的文件
$ find . -name "*.java" | xargs grep "Stock"

# 清除所有后缀名为 tmp 的临时文件
$ find /tmp -name "*.tmp" | xargs rm
```

## 后台运行

当用户注销 (logout) 或者网络断开时，终端会收到 HUP (hangup) 信号从而关闭其所有子进程；我们可以通过让进程忽略 HUP 信号，或者让进程运行在新的会话里从而成为不属于此终端的子进程来进行后台执行。

```sh
# nohup 方式
$ nohup ping www.ibm.com &

# screen 方式，创建并且连接到新的屏幕
# 创建新的伪终端
$ screen -dmS Urumchi

# 连接到当前伪终端
$ screen -r Urumchi
```

# Tmux

Tmux 是一个工具，用于在一个终端窗口中运行多个终端会话；还可以通过 Tmux 使终端会话运行于后台或是按需接入、断开会话。本部分是对于 [tmux shortcuts & cheatsheet](https://parg.co/UrT) 一文的总结提取

```sh
# 启动新会话
tmux

# 指定新 Session 的名称，并创建
tmux new -s myname

# 列举出所有的 Session
tmux ls

# 附着到某个 Session
tmux a  #  (or at, or attach)

# 根据指定的名称附着到 Session
tmux a -t myname

# 关闭某个 Session
tmux kill-session -t myname

# 关闭全部 Session
tmux ls | grep : | cut -d. -f1 | awk '{print substr($1, 0, length($1)-1)}' | xargs kill
```

在 Tmux 中，使用 `ctrl + b` 前缀，然后可以使用如下命令

```sh
# Sessions
:new<CR>  new session
s  list sessions
$  name session
[  view history
d  detach

# Windows (tabs)
c  create window
w  list windows
n  next window
p  previous window
f  find window
,  name window
&  kill window

# Panes (splits)
%  vertical split
"  horizontal split

o  swap panes
q  show pane numbers
x  kill pane
+  break pane into window (e.g. to select text by mouse to copy)
-  restore pane from window
⍽  space - toggle between layouts
<prefix> q (Show pane numbers, when the numbers show up type the key to goto that pane)
<prefix> { (Move the current pane left)
<prefix> } (Move the current pane right)
<prefix> z toggle pane zoom

# Resizing Panes
PREFIX : resize-pane -D (Resizes the current pane down)
PREFIX : resize-pane -U (Resizes the current pane upward)
PREFIX : resize-pane -L (Resizes the current pane left)
PREFIX : resize-pane -R (Resizes the current pane right)
PREFIX : resize-pane -D 20 (Resizes the current pane down by 20 cells)
PREFIX : resize-pane -U 20 (Resizes the current pane upward by 20 cells)
PREFIX : resize-pane -L 20 (Resizes the current pane left by 20 cells)
PREFIX : resize-pane -R 20 (Resizes the current pane right by 20 cells)
PREFIX : resize-pane -t 2 20 (Resizes the pane with the id of 2 down by 20 cells)
PREFIX : resize-pane -t -L 20 (Resizes the pane with the id of 2 left by 20 cells)
```
