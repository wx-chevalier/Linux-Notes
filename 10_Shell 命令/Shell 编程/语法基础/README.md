# Shell 语法基础

# Shebang

#! 脚本中使用的语法表示在 UNIX/Linux 操作系统下执行的解释器。大多数 Linux shell 和 perl/python 脚本以以下行开头：

```sh
#!/bin/bash
#!/usr/bin/perl
#!/usr/bin/python
#!/usr/bin/python3
#!/usr/bin/env bash
```

脚本中所有的语句都会使用首行声明的解释器来进行执行，绝大部分的脚本都是以 `#!/bin/bash` 开始，这就保证了不管该脚本在何解释器中运行都会被 Bash 来执行；如果我们不添加任何的 Shebang 行，那么会默认使用 `/bin/sh` 来执行。Shebang 由 Dennis Ritchie 在 7 版 Unix 和 8 版之间在 Bell Laboratories 推出。然后，它也被添加到伯克利的 BSD 系列中

## /bin/sh

sh 是系统的标准命令解释器。sh 的当前版本正在更改中，以符合 Shell 的 POSIX 1003.2 和 1003.2a 规范。典型的脚本如下：

```sh
#! /bin/sh
### BEGIN INIT INFO
# Provides:          policykit
# Required-Start:    $local_fs
# Required-Stop:     $local_fs
# Default-Start:     2 3 4 5
# Default-Stop:
# Short-Description: Create PolicyKit runtime directories
# Description:       Create directories which PolicyKit needs at runtime,
#                    such as /var/run/PolicyKit
### END INIT INFO

# Author: Martin Pitt <martin.pitt@ubuntu.com>

case "$1" in
  start)
        mkdir -p /var/run/PolicyKit
        chown root:polkituser /var/run/PolicyKit
        chmod 770 /var/run/PolicyKit
	;;
  stop|restart|force-reload)
	;;
  *)
	echo "Usage: $SCRIPTNAME {start|stop|restart|force-reload}" >&2
	exit 3
	;;
esac

:
```

## /usr/bin/env bash

`/usr/bin/env` 在修改后的环境中运行 bash 之类的程序。它使您的 bash 脚本具有可移植性。`＃/usr/bin/env bash` 的优点是它将使用运行用户的 `$PATH` 变量中首先出现的 bash 可执行文件。

```sh
#!/usr/bin/env bash
# Purpose: Mount glusterfs at boot time
#          Must run as root
# Author: Vivek Gite
# --------------------------------------
p='gfs01:/gvol01'

mount | grep -wq "^${p}"

if [ $? -ne 0 ]
then
	mount -t glusterfs "$p" /sharedwww/
fi
```

# 注释

Shell 中以 # 表示单行注释：

```sh
#!/bin/bash
# A Simple Shell Script To Get Linux Network Information
# Vivek Gite - 30/Aug/2009
echo "Current date : $(date) @ $(hostname)"
echo "Network configuration"
/sbin/ifconfig
```

以＃开头的单词或行会导致该单词和该行上的所有剩余字符被忽略。这些行不是要执行 bash 的语句。实际上，bash 完全忽略了它们。这些注释称为注释。只是关于脚本的解释性文字。它使源代码更易于理解。这些说明适用于人类和其他系统管理员。它可以帮助其他系统管理员理解您的代码，逻辑，并可以帮助他们修改您编写的脚本。

多行注释的定义方式如下：

```sh
#!/bin/bash
echo "Adding new users to LDAP Server..."
<<COMMENT1
    Master LDAP server : dir1.nixcraft.net.in
    Add user to master and it will get sync to backup server too
    Profile and active directory hooks are below
COMMENT1
echo "Searching for user..."
```
