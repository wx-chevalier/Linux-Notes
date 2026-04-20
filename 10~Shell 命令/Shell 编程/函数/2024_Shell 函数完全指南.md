
# Shell 函数完全指南

## 1. 函数定义语法

Shell 提供了三种定义函数的语法：

```bash
# 1. POSIX 标准语法
name() {
    commands
}

# 2. KSH 风格语法
function name {
    commands
}

# 3. Bash 混合语法
function name() {
    commands
}
```

所有语法都是等效的，但推荐使用 POSIX 标准语法，因为它具有最好的兼容性。

## 2. 函数参数

### 2.1 参数访问

```bash
example_function() {
    echo "第一个参数: $1"
    echo "第二个参数: $2"
    echo "参数个数: $#"
    echo "所有参数: $@"
    echo "函数名: ${FUNCNAME[0]}"
}

# 调用函数
example_function "arg1" "arg2"
```

### 2.2 特殊参数变量

- `$1, $2, ...` - 位置参数
- `$#` - 参数个数
- `$@` - 所有参数（作为独立的单词）
- `$*` - 所有参数（作为单个字符串）
- `$FUNCNAME` - 当前函数名

## 3. 变量作用域

### 3.1 局部变量

```bash
my_function() {
    local local_var="局部变量"    # 只在函数内可见
    global_var="全局变量"         # 在整个脚本可见
}
```

### 3.2 全局变量

```bash
# 全局变量定义
GLOBAL_CONFIG="/etc/myapp.conf"

config_reader() {
    echo "读取配置: $GLOBAL_CONFIG"
}
```

## 4. 函数返回值

### 4.1 使用 return

```bash
is_number() {
    local num="$1"
    if [[ "$num" =~ ^[0-9]+$ ]]; then
        return 0    # 成功
    else
        return 1    # 失败
    fi
}

# 使用返回值
is_number "123"
if [ $? -eq 0 ]; then
    echo "是数字"
fi
```

### 4.2 使用输出捕获

```bash
get_timestamp() {
    echo "$(date '+%Y-%m-%d %H:%M:%S')"
}

# 捕获输出
current_time=$(get_timestamp)
```

## 5. 实际应用案例

### 5.1 NAS 挂载函数

```bash
mount_nas() {
    local NASMNT="/nas10"
    local NASSERVER="nas10.example.com"
    local NASUSER="admin"
    local NASPASSWORD="password"

    # 创建挂载点
    [ ! -d "$NASMNT" ] && mkdir -p "$NASMNT"

    # 检查是否已挂载
    if ! mount | grep -q "$NASMNT"; then
        mount -t cifs "//$NASSERVER/$NASUSER" \
            -o username="$NASUSER",password="$NASPASSWORD" "$NASMNT"
    fi
}

umount_nas() {
    local NASMNT="/nas10"
    mount | grep -q "$NASMNT" && umount "$NASMNT"
}
```

### 5.2 文件类型检查

```bash
check_file_type() {
    local file="$1"

    # 参数验证
    [ -z "$file" ] && { echo "错误: 未指定文件"; return 1; }

    # 检查文件类型
    [ -f "$file" ] && echo "$file 是普通文件"
    [ -d "$file" ] && echo "$file 是目录"
    [ -L "$file" ] && echo "$file 是符号链接"
    [ -x "$file" ] && echo "$file 是可执行文件"
}
```

## 6. 最佳实践

### 6.1 函数文档

```bash
#######################################
# 函数描述
# 参数:
#   $1 - 参数1的描述
#   $2 - 参数2的描述
# 返回值:
#   0 - 成功
#   1 - 失败
#######################################
function_name() {
    # 函数实现
}
```

### 6.2 参数验证

```bash
process_file() {
    # 验证参数数量
    if [ $# -lt 1 ]; then
        echo "错误: 缺少参数" >&2
        return 1
    fi

    # 验证文件存在
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "错误: 文件不存在: $file" >&2
        return 1
    fi
}
```

### 6.3 错误处理

```bash
handle_error() {
    echo "错误发生在 ${FUNCNAME[1]}, 行号 $1" >&2
    exit 1
}

trap 'handle_error $LINENO' ERR
```

## 7. 函数管理

### 7.1 函数移除

```bash
# 删除函数定义
unset -f function_name
```

### 7.2 函数列表

```bash
# 显示所有函数
declare -F

# 显示函数定义
declare -f function_name
```

通过遵循这些规范和最佳实践，可以编写出更加可靠和可维护的 Shell 函数。记住要始终进行适当的错误处理和参数验证，并为函数提供清晰的文档说明。
