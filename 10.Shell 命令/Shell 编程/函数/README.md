# Shell 函数

我们人类当然是一个聪明的物种。我们与他人合作，我们在共同的任务上相互依赖。例如，您依靠送牛奶员将牛奶装进牛奶瓶或纸箱中。此逻辑适用于包含 Shell 程序脚本的计算机程序。当脚本变得复杂时，您需要使用分而治之的技术。有时，Shell 脚本会变得复杂。为了避免使用大而复杂的脚本，请使用函数。您将大型脚本分为称为函数的小块/实体。函数使 Shell 脚本模块化并且易于使用。函数避免重复的代码。例如，is_root_user() 函数可以被各种 shell 脚本重用，以确定登录的用户是否是 root 用户。函数执行特定任务。例如，添加或删除用户帐户。使用的功能类似于普通命令。在其他高级编程语言中，功能也称为过程，方法，子例程或例程。

在 Shell 提示符下键入以下命令：

```sh
hello() { echo 'Hello world!' ; }

# 调用 hello 函数
hello
```

您可以将命令行参数传递给用户定义的函数。定义 hello 如下：

```sh
hello() { echo "Hello $1, let us be a friend." ; }
```

您可以使用 hello 函数并传递参数，如下所示：

```sh
hello Vivek

# Hello Vivek, let us be a friend.
```

{...} 中的一行函数必须以分号结尾。否则，您会在屏幕上看到错误：

```sh
xrpm() { rpm2cpio "$1" | cpio -idmv; }
```

# 函数枚举

要显示定义的函数名称，请使用 declare 命令。在 shell 提示符下键入以下命令：

```sh
declare -f
declare -f | less
declare  -f functioName
declare  -f xrpm

# Sample outputs
command_not_found_handle ()
{
    if [ -x /usr/lib/command-not-found ]; then
        /usr/bin/python /usr/lib/command-not-found -- $1;
        return $?;
    else
        return 127;
    fi
}
```
