# Shell 函数调用详解

Shell 函数是一组可重复使用的命令集合,本文详细介绍 Shell 函数的定义、调用方式以及参数传递等内容。

## 函数定义与基本调用

### 基本语法

Shell 函数有两种定义方式:

```sh
# 方式1: 使用 function 关键字
function function_name() {
    commands
}

# 方式2: 直接使用函数名
function_name() {
    commands
}
```

### 函数参数处理

函数可以接收参数,在函数内部通过特殊变量访问:

```sh
function example() {
    echo "第一个参数: $1"
    echo "第二个参数: $2"
    echo "参数个数: $#"
    echo "所有参数: $@"
    echo "所有参数: $*"  # 与 $@ 类似,但处理方式略有不同

    # 使用 shift 移动参数
    shift
    echo "移动后的第一个参数: $1"
}
```

### 函数返回值

Shell 函数可以通过两种方式返回值:

```sh
# 方式1: return 语句(仅支持 0-255 的整数)
function check_status() {
    [[ $1 -eq 0 ]] && return 0 || return 1
}

# 方式2: echo 输出(可返回任意字符串)
function get_name() {
    echo "John Doe"
}
name=$(get_name)  # 通过命令替换获取返回值
```

## 全局函数库

您可以将常用函数存储在函数库文件中以便复用。

### 创建函数库

创建一个名为 `functions.sh` 的函数库文件:

```sh
#!/bin/bash
# functions.sh - 通用函数库

# 常量定义
declare -r TRUE=0
declare -r FALSE=1

# 字符串转小写函数
function to_lower() {
    local str="$@"
    echo "${str,,}"
}

# 检查root用户
function is_root() {
    [ $(id -u) -eq 0 ] && return $TRUE || return $FALSE
}

# 错误处理函数
function die() {
    local message="$1"
    local code=${2:-1}
    echo "错误: $message" >&2
    exit "$code"
}
```

### 加载函数库

有两种方式加载函数库:

```sh
# 方式1: 使用 . 命令
. /path/to/functions.sh

# 方式2: 使用 source 命令
source /path/to/functions.sh [参数]
```

### 使用示例

```sh
#!/bin/bash
# 加载函数库
source ./functions.sh

# 定义局部变量
text="Hello World"

# 调用函数库中的函数
if is_root; then
    echo "当前用户是root"
else
    echo "当前用户不是root"
fi

# 转换字符串为小写
echo "原始文本: $text"
echo "转换结果: $(to_lower "$text")"

# 错误处理示例
[ -f "config.txt" ] || die "配置文件不存在" 2
```

## 递归函数

Shell 支持函数递归调用。下面是计算阶乘的示例:

```sh
function factorial() {
    local num=$1

    # 基本情况
    if [ $num -le 1 ]; then
        echo 1
        return
    fi

    # 递归调用
    local sub_result=$(factorial $(( num - 1 )))
    echo $(( num * sub_result ))
}

# 使用示例
result=$(factorial 5)
echo "5的阶乘是: $result"
```

## 后台函数调用

函数可以在后台执行,适用于需要并行处理的场景:

```sh
# 定义进度显示函数
function show_progress() {
    while true; do
        echo -n "."
        sleep 1
    done
}

# 定义主处理函数
function main_process() {
    sleep 10  # 模拟耗时操作
}

# 启动进度显示(后台运行)
show_progress &
progress_pid=$!

# 执行主要处理
main_process

# 完成后终止进度显示
kill $progress_pid
echo "完成!"
```

## 最佳实践

1. **局部变量**：总是使用 local 声明函数内的变量
2. **参数验证**：检查必要的参数是否存在
3. **返回值**：合理使用返回值表示函数执行状态
4. **错误处理**：实现适当的错误处理机制
5. **文档注释**：为函数添加清晰的注释

```sh
function process_file() {
    # 函数文档
    local usage="Usage: process_file <filename> [type]"

    # 参数验证
    [ $# -lt 1 ] && { echo "$usage"; return 1; }

    # 声明局部变量
    local file="$1"
    local type="${2:-default}"
    local status=0

    # 错误处理
    [ ! -f "$file" ] && { echo "Error: File not found"; return 1; }

    # 处理逻辑
    case "$type" in
        text)
            process_text "$file"
            status=$?
            ;;
        binary)
            process_binary "$file"
            status=$?
            ;;
        *)
            echo "Unknown type: $type"
            status=1
            ;;
    esac

    return $status
}
```

通过合理使用这些功能和最佳实践,可以编写出更加健壮和可维护的 Shell 脚本。
