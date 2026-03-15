# 2024~Linux Shell 综合模板

```sh
#!/bin/bash
#====================================================
# 脚本名称: enterprise_shell_template.sh
# 脚本描述: 企业级 Shell 脚本模板
# 作者: Your Name
# 创建时间: YYYY-MM-DD
# 版本: 1.0
# 使用方法: ./enterprise_shell_template.sh [选项]
#====================================================

#====================================================
# 严格模式设置
#====================================================
set -e          # 发生错误时立即退出
set -u          # 使用未定义的变量时报错
set -o pipefail # 管道中的任何一个命令失败都会导致整个管道失败

#====================================================
# 全局变量定义
#====================================================
# 路径相关
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_PATH="${SCRIPT_DIR}/${SCRIPT_NAME}"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# 目录定义
readonly CONFIG_DIR="${SCRIPT_DIR}/config"
readonly LOG_DIR="${SCRIPT_DIR}/logs"
readonly BACKUP_DIR="${SCRIPT_DIR}/backup"
readonly TEMP_DIR="${SCRIPT_DIR}/temp"
readonly DATA_DIR="${SCRIPT_DIR}/data"

# 文件定义
readonly LOCK_FILE="/tmp/${SCRIPT_NAME}.lock"
readonly LOG_FILE="${LOG_DIR}/${SCRIPT_NAME%.*}.log"
readonly CONFIG_FILE="${CONFIG_DIR}/config.ini"

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# 状态码定义
readonly SUCCESS=0
readonly FAILURE=1
readonly INVALID_ARGS=2
readonly DEPENDENCY_ERROR=3
readonly PERMISSION_DENIED=4
readonly LOCK_ERROR=5
readonly CONFIG_ERROR=6
readonly NETWORK_ERROR=7

# 默认配置
readonly DEFAULT_TIMEOUT=30
readonly DEFAULT_RETRY=3
readonly DEFAULT_BATCH_SIZE=100
readonly DEFAULT_VERBOSE=false

#====================================================
# 日志函数
#====================================================
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $*"
    log_to_file "INFO" "$*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
    log_to_file "WARN" "$*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
    log_to_file "ERROR" "$*"
}

log_debug() {
    if [ "${verbose}" = true ]; then
        echo -e "${BLUE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') $*"
        log_to_file "DEBUG" "$*"
    fi
}

log_to_file() {
    local level="$1"
    shift
    local message="$*"

    ensure_dir "${LOG_DIR}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [${level}] ${message}" >> "${LOG_FILE}"
}

#====================================================
# 辅助函数
#====================================================
# 清理函数
cleanup() {
    local exit_code=$?
    log_info "开始清理..."

    # 删除锁文件
    if [ -f "${LOCK_FILE}" ]; then
        rm -f "${LOCK_FILE}"
        log_debug "已删除锁文件"
    fi

    # 清理临时文件
    if [ -d "${TEMP_DIR}" ]; then
        rm -rf "${TEMP_DIR}"/*
        log_debug "已清理临时文件"
    fi

    # 记录脚本结束状态
    if [ ${exit_code} -eq 0 ]; then
        log_info "脚本执行成功结束"
    else
        log_error "脚本执行失败，退出码: ${exit_code}"
    fi

    exit ${exit_code}
}

# 错误处理函数
error_handler() {
    local line_no=$1
    local error_code=$2
    log_error "错误发生在第 ${line_no} 行，错误码: ${error_code}"

    # 可选：发送错误通知
    if [ "${verbose}" = true ]; then
        send_mail_notification \
            "${SCRIPT_NAME} 执行错误" \
            "脚本在第 ${line_no} 行发生错误，错误码: ${error_code}"
    fi
}

# 检查目录并创建
ensure_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" || {
            log_error "无法创建目录: $dir"
            exit ${FAILURE}
        }
        log_debug "已创建目录: $dir"
    fi
}

# 检查是否为 root 用户
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "此脚本需要 root 权限运行"
        exit ${PERMISSION_DENIED}
    fi
}

# 检查依赖命令
check_dependencies() {
    local deps=("$@")
    local missing=()

    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        log_error "缺少依赖命令: ${missing[*]}"
        exit ${DEPENDENCY_ERROR}
    fi
}

# 获取配置值
get_config() {
    local key="$1"
    local default="$2"
    local value

    if [ -f "${CONFIG_FILE}" ]; then
        value=$(grep "^${key}=" "${CONFIG_FILE}" | cut -d'=' -f2-)
        echo "${value:-$default}"
    else
        echo "$default"
    fi
}

#====================================================
# 实用功能函数
#====================================================
# 备份文件
backup_file() {
    local file="$1"
    local backup_name="$(basename "$file").${TIMESTAMP}.bak"

    ensure_dir "${BACKUP_DIR}"
    if [ -f "$file" ]; then
        cp "$file" "${BACKUP_DIR}/${backup_name}" || {
            log_error "备份文件失败: $file"
            return ${FAILURE}
        }
        log_info "已备份文件: $file -> ${backup_name}"
        return ${SUCCESS}
    else
        log_warn "要备份的文件不存在: $file"
        return ${FAILURE}
    fi
}

# 压缩文件或目录
compress_files() {
    local target="$1"
    local output_file="${2:-${target%/}}.tar.gz"

    if [ -e "$target" ]; then
        tar -czf "$output_file" "$target" || {
            log_error "压缩失败: $target"
            return ${FAILURE}
        }
        log_info "已压缩: $target -> $output_file"
        return ${SUCCESS}
    else
        log_error "要压缩的目标不存在: $target"
        return ${FAILURE}
    fi
}

# 解压文件
extract_file() {
    local file="$1"
    local dest_dir="${2:-.}"

    ensure_dir "$dest_dir"

    case "$file" in
        *.tar.gz|*.tgz)     tar -xzf "$file" -C "$dest_dir" ;;
        *.tar.bz2|*.tbz2)   tar -xjf "$file" -C "$dest_dir" ;;
        *.tar)              tar -xf  "$file" -C "$dest_dir" ;;
        *.zip)              unzip    "$file" -d "$dest_dir" ;;
        *)
            log_error "不支持的文件格式: $file"
            return ${FAILURE}
            ;;
    esac

    if [ $? -eq 0 ]; then
        log_info "已解压: $file -> $dest_dir"
        return ${SUCCESS}
    else
        log_error "解压失败: $file"
        return ${FAILURE}
    fi
}

# 检查网络连接
check_network() {
    local host="${1:-8.8.8.8}"
    local timeout="${2:-5}"

    if ping -c 1 -W "$timeout" "$host" >/dev/null 2>&1; then
        log_debug "网络连接正常"
        return ${SUCCESS}
    else
        log_error "网络连接失败"
        return ${NETWORK_ERROR}
    fi
}

# 检查端口是否可用
check_port_available() {
    local port="$1"
    local host="${2:-localhost}"

    if netstat -tuln | grep -q ":${port} "; then
        log_debug "端口 ${port} 已被占用"
        return ${FAILURE}
    else
        log_debug "端口 ${port} 可用"
        return ${SUCCESS}
    fi
}

# 检查进程是否运行
check_process_running() {
    local process_name="$1"

    if pgrep -f "$process_name" >/dev/null; then
        log_debug "进程 ${process_name} 正在运行"
        return ${SUCCESS}
    else
        log_debug "进程 ${process_name} 未运行"
        return ${FAILURE}
    fi
}

# 等待进程结束
wait_for_process() {
    local process_name="$1"
    local timeout="${2:-30}"
    local interval="${3:-1}"
    local elapsed=0

    while check_process_running "$process_name"; do
        if [ "$elapsed" -ge "$timeout" ]; then
            log_error "等待进程 ${process_name} 超时"
            return ${FAILURE}
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done

    log_debug "进程 ${process_name} 已结束"
    return ${SUCCESS}
}

# 发送邮件通知
send_mail_notification() {
    local subject="$1"
    local message="$2"
    local recipient="${3:-root@localhost}"

    if command -v mail >/dev/null 2>&1; then
        echo "$message" | mail -s "$subject" "$recipient"
        log_info "已发送邮件通知至 $recipient"
        return ${SUCCESS}
    else
        log_warn "mail 命令不可用，无法发送邮件通知"
        return ${FAILURE}
    fi
}

# 执行命令并检查结果
execute_cmd() {
    local cmd="$1"
    local error_msg="${2:-命令执行失败}"
    local timeout="${3:-${DEFAULT_TIMEOUT}}"

    log_debug "执行命令: $cmd"

    if timeout "$timeout" bash -c "$cmd"; then
        log_debug "命令执行成功"
        return ${SUCCESS}
    else
        local exit_code=$?
        log_error "${error_msg} (退出码: ${exit_code})"
        return ${FAILURE}
    fi
}

# 重试执行命令
retry_cmd() {
    local cmd="$1"
    local max_attempts="${2:-${DEFAULT_RETRY}}"
    local wait_time="${3:-5}"
    local attempt=1

    while [ "$attempt" -le "$max_attempts" ]; do
        if execute_cmd "$cmd"; then
            return ${SUCCESS}
        else
            log_warn "第 ${attempt}/${max_attempts} 次尝试失败"
            if [ "$attempt" -lt "$max_attempts" ]; then
                log_info "等待 ${wait_time} 秒后重试..."
                sleep "$wait_time"
            fi
            attempt=$((attempt + 1))
        fi
    done

    log_error "达到最大重试次数 ${max_attempts}"
    return ${FAILURE}
}

# 获取脚本运行时间
get_runtime() {
    local start_time="$1"
    local end_time=$(date +%s)
    local runtime=$((end_time - start_time))

    printf '%02dh:%02dm:%02ds' $((runtime/3600)) $((runtime%3600/60)) $((runtime%60))
}

# 检查磁盘空间
check_disk_space() {
    local mount_point="${1:-/}"
    local min_space="${2:-10}" # 最小空间百分比

    local space_used
    space_used=$(df -h "$mount_point" | awk 'NR==2 {gsub(/%/,"",$5); print $5}')

    if [ "$space_used" -gt $((100 - min_space)) ]; then
        log_error "磁盘空间不足: ${mount_point} (已使用 ${space_used}%)"
        return ${FAILURE}
    else
        log_debug "磁盘空间充足: ${mount_point} (已使用 ${space_used}%)"
        return ${SUCCESS}
    fi
}

#====================================================
# 参数处理函数
#====================================================
show_usage() {
    cat << EOF
使用方法: ${SCRIPT_NAME} [选项]

选项:
    -h, --help              显示此帮助信息
    -v, --verbose          显示详细输出
    -c, --config FILE      指定配置文件
    -l, --log FILE         指定日志文件
    -t, --timeout SECONDS  设置超时时间 (默认: ${DEFAULT_TIMEOUT}秒)
    -r, --retry NUMBER     设置重试次数 (默认: ${DEFAULT_RETRY}次)
    -f, --force            强制执行
    -d, --dry-run          空运行模式
    --no-backup            不创建备份
    --no-color             禁用颜色输出

示例:
    ${SCRIPT_NAME} --verbose --config /path/to/config
    ${SCRIPT_NAME} --timeout 60 --retry 5
    ${SCRIPT_NAME} --dry-run

EOF
}

parse_arguments() {
    # 默认值设置
    verbose=${DEFAULT_VERBOSE}
    config_file="${CONFIG_FILE}"
    log_file="${LOG_FILE}"
    timeout=${DEFAULT_TIMEOUT}
    retry_count=${DEFAULT_RETRY}
    force_mode=false
    dry_run=false
    create_backup=true
    use_color=true

    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit ${SUCCESS}
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -c|--config)
                if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                    config_file=$2
                    shift 2
                else
                    log_error "错误: --config 需要一个参数"
                    exit ${INVALID_ARGS}
                fi
                ;;
            -l|--log)
                if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                    log_file=$2
                    shift 2
                else
                    log_error "错误: --log 需要一个参数"
                    exit ${INVALID_ARGS}
                fi
                ;;
            -t|--timeout)
                if [[ $2 =~ ^[0-9]+$ ]]; then
                    timeout=$2
                    shift 2
                else
                    log_error "错误: --timeout 需要一个数字参数"
                    exit ${INVALID_ARGS}
                fi
                ;;
            -r|--retry)
                if [[ $2 =~ ^[0-9]+$ ]]; then
                    retry_count=$2
                    shift 2
                else
                    log_error "错误: --retry 需要一个数字参数"
                    exit ${INVALID_ARGS}
                fi
                ;;
            -f|--force)
                force_mode=true
                shift
                ;;
            -d|--dry-run)
                dry_run=true
                shift
                ;;
            --no-backup)
                create_backup=false
                shift
                ;;
            --no-color)
                use_color=false
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_usage
                exit ${INVALID_ARGS}
                ;;
        esac
    done
}

#====================================================
# 初始化函数
#====================================================
initialize() {
    local start_time=$1

    # 检查是否已经运行
    if [ -f "${LOCK_FILE}" ]; then
        if kill -0 "$(cat "${LOCK_FILE}")" >/dev/null 2>&1; then
            log_error "脚本已在运行中"
            exit ${LOCK_ERROR}
        else
            log_warn "发现过期的锁文件，将删除"
            rm -f "${LOCK_FILE}"
        fi
    fi

    # 创建锁文件
    echo $$ > "${LOCK_FILE}"

    # 创建必要的目录
    ensure_dir "${CONFIG_DIR}"
    ensure_dir "${LOG_DIR}"
    ensure_dir "${BACKUP_DIR}"
    ensure_dir "${TEMP_DIR}"
    ensure_dir "${DATA_DIR}"

    # 检查配置文件
    if [ ! -f "${config_file}" ]; then
        log_warn "配置文件不存在: ${config_file}"
        if [ "${force_mode}" = false ]; then
            log_error "使用 --force 参数强制继续"
            exit ${CONFIG_ERROR}
        fi
    fi

    # 设置信号处理
    trap cleanup EXIT
    trap 'error_handler ${LINENO} $?' ERR

    # 检查依赖
    check_dependencies "awk" "sed" "grep" "tar" "gzip"

    # 检查系统要求
    check_disk_space "/" 10

    log_info "初始化完成"
}

#====================================================
# 主程序
#====================================================
main() {
    local start_time=$(date +%s)

    # 解析命令行参数
    parse_arguments "$@"

    # 初始化环境
    initialize "$start_time"

    # 显示运行参数
    if [ "${verbose}" = true ]; then
        log_info "运行参数:"
        log_info "  配置文件: ${config_file}"
        log_info "  日志文件: ${log_file}"
        log_info "  超时时间: ${timeout}秒"
        log_info "  重试次数: ${retry_count}次"
        log_info "  强制模式: ${force_mode}"
        log_info "  空运行模式: ${dry_run}"
    fi

    # 检查网络连接
    if ! check_network; then
        log_error "网络连接失败"
        exit ${NETWORK_ERROR}
    fi

    # 主要业务逻辑
    log_info "开始执行主要任务..."

    if [ "${dry_run}" = true ]; then
        log_info "空运行模式，跳过实际操作"
    else
        # 在这里添加你的业务逻辑
        # 示例：批量处理文件
        local files_to_process=(${DATA_DIR}/*)
        local total_files=${#files_to_process[@]}
        local processed=0

        for file in "${files_to_process[@]}"; do
            if [ -f "$file" ]; then
                processed=$((processed + 1))
                log_info "处理文件 ($processed/$total_files): $(basename "$file")"

                # 处理文件的具体逻辑
                if [ "${create_backup}" = true ]; then
                    backup_file "$file"
                fi

                # 这里添加实际的文件处理逻辑
                # ...
            fi
        done
    fi

    # 计算运行时间
    local runtime=$(get_runtime "$start_time")
    log_info "任务完成，运行时间: ${runtime}"

    return ${SUCCESS}
}

# 执行主程序
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```
