#!/bin/bash
# Bookstore 服务管理脚本
# 用于构建、启动、停止、重启所有服务

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 项目路径
PROJECT_ROOT=$(cd "$(dirname "$0")" && pwd)
API_DIR="$PROJECT_ROOT/api"
ADD_RPC_DIR="$PROJECT_ROOT/rpc/add"
CHECK_RPC_DIR="$PROJECT_ROOT/rpc/check"

# PID 文件路径
PID_DIR="$PROJECT_ROOT/.pids"
API_PID="$PID_DIR/api.pid"
ADD_PID="$PID_DIR/add.pid"
CHECK_PID="$PID_DIR/check.pid"

# 日志文件路径
LOG_DIR="$PROJECT_ROOT/logs"

# 创建必要的目录
mkdir -p "$PID_DIR"
mkdir -p "$LOG_DIR"

# 打印彩色信息
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查服务是否运行
is_running() {
    local pid_file=$1
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        else
            rm -f "$pid_file"
            return 1
        fi
    fi
    return 1
}

# 构建服务
build() {
    print_info "=== 开始构建所有服务 ==="

    # 构建 API
    print_info "构建 API 服务..."
    cd "$API_DIR" || exit 1
    go build -o bookstore-api bookstore.go
    if [ $? -eq 0 ]; then
        print_info "✓ API 服务构建成功"
    else
        print_error "✗ API 服务构建失败"
        return 1
    fi

    # 构建 Add RPC
    print_info "构建 Add RPC 服务..."
    cd "$ADD_RPC_DIR" || exit 1
    go build -o add-rpc add.go
    if [ $? -eq 0 ]; then
        print_info "✓ Add RPC 服务构建成功"
    else
        print_error "✗ Add RPC 服务构建失败"
        return 1
    fi

    # 构建 Check RPC
    print_info "构建 Check RPC 服务..."
    cd "$CHECK_RPC_DIR" || exit 1
    go build -o check-rpc check.go
    if [ $? -eq 0 ]; then
        print_info "✓ Check RPC 服务构建成功"
    else
        print_error "✗ Check RPC 服务构建失败"
        return 1
    fi

    print_info "=== 所有服务构建完成 ==="
    cd "$PROJECT_ROOT"
}

# 启动 Add RPC 服务
start_add_rpc() {
    if is_running "$ADD_PID"; then
        print_warn "Add RPC 服务已在运行中 (PID: $(cat $ADD_PID))"
        return 0
    fi

    print_info "启动 Add RPC 服务..."
    cd "$ADD_RPC_DIR" || return 1
    nohup ./add-rpc -f etc/add.yaml > /dev/null 2>&1 &
    local pid=$!
    echo $pid > "$ADD_PID"
    sleep 2

    if is_running "$ADD_PID"; then
        print_info "✓ Add RPC 服务启动成功 (PID: $pid)"
    else
        print_error "✗ Add RPC 服务启动失败"
        if [ -f "$ADD_RPC_DIR/logs/rpc/add/error.log" ]; then
            tail -5 "$ADD_RPC_DIR/logs/rpc/add/error.log"
        fi
        return 1
    fi
}

# 启动 Check RPC 服务
start_check_rpc() {
    if is_running "$CHECK_PID"; then
        print_warn "Check RPC 服务已在运行中 (PID: $(cat $CHECK_PID))"
        return 0
    fi

    print_info "启动 Check RPC 服务..."
    cd "$CHECK_RPC_DIR" || return 1
    nohup ./check-rpc -f etc/check.yaml > /dev/null 2>&1 &
    local pid=$!
    echo $pid > "$CHECK_PID"
    sleep 2

    if is_running "$CHECK_PID"; then
        print_info "✓ Check RPC 服务启动成功 (PID: $pid)"
    else
        print_error "✗ Check RPC 服务启动失败"
        if [ -f "$CHECK_RPC_DIR/logs/rpc/check/error.log" ]; then
            tail -5 "$CHECK_RPC_DIR/logs/rpc/check/error.log"
        fi
        return 1
    fi
}

# 启动 API 服务
start_api() {
    if is_running "$API_PID"; then
        print_warn "API 服务已在运行中 (PID: $(cat $API_PID))"
        return 0
    fi

    print_info "启动 API 服务..."
    cd "$API_DIR" || return 1
    nohup ./bookstore-api -f etc/bookstore-api.yaml > /dev/null 2>&1 &
    local pid=$!
    echo $pid > "$API_PID"
    sleep 2

    if is_running "$API_PID"; then
        print_info "✓ API 服务启动成功 (PID: $pid)"
    else
        print_error "✗ API 服务启动失败"
        if [ -f "$API_DIR/logs/api/error.log" ]; then
            tail -5 "$API_DIR/logs/api/error.log"
        fi
        return 1
    fi
}

# 启动所有服务
start() {
    print_info "=== 开始启动所有服务 ==="

    # 按依赖顺序启动：先 RPC，后 API
    start_add_rpc
    start_check_rpc
    sleep 2
    start_api

    print_info "=== 所有服务启动完成 ==="
}

# 停止服务
stop_service() {
    local service_name=$1
    local pid_file=$2

    if is_running "$pid_file"; then
        local pid=$(cat "$pid_file")
        print_info "停止 $service_name (PID: $pid)..."
        kill "$pid" 2>/dev/null
        sleep 2

        # 如果进程仍在运行，强制杀死
        if ps -p "$pid" > /dev/null 2>&1; then
            print_warn "强制停止 $service_name..."
            kill -9 "$pid" 2>/dev/null
        fi

        rm -f "$pid_file"
        print_info "✓ $service_name 已停止"
    else
        print_warn "$service_name 未在运行"
    fi
}

# 停止所有服务
stop() {
    print_info "=== 开始停止所有服务 ==="

    # 按相反顺序停止：先 API，后 RPC
    stop_service "API 服务" "$API_PID"
    stop_service "Check RPC 服务" "$CHECK_PID"
    stop_service "Add RPC 服务" "$ADD_PID"

    print_info "=== 所有服务已停止 ==="
}

# 重启所有服务
restart() {
    print_info "=== 重启所有服务 ==="
    stop
    sleep 2
    start
}

# 查看服务状态
status() {
    print_info "=== 服务状态 ==="

    if is_running "$ADD_PID"; then
        echo -e "${GREEN}✓${NC} Add RPC 服务运行中 (PID: $(cat $ADD_PID))"
    else
        echo -e "${RED}✗${NC} Add RPC 服务未运行"
    fi

    if is_running "$CHECK_PID"; then
        echo -e "${GREEN}✓${NC} Check RPC 服务运行中 (PID: $(cat $CHECK_PID))"
    else
        echo -e "${RED}✗${NC} Check RPC 服务未运行"
    fi

    if is_running "$API_PID"; then
        echo -e "${GREEN}✓${NC} API 服务运行中 (PID: $(cat $API_PID))"
    else
        echo -e "${RED}✗${NC} API 服务未运行"
    fi

    echo ""
    print_info "=== 端口监听状态 ==="
    netstat -tuln 2>/dev/null | grep -E ':(8080|8081|8888)' || ss -tuln 2>/dev/null | grep -E ':(8080|8081|8888)' || echo "无法获取端口信息"
}

# 查看日志
logs() {
    local service=$1

    case $service in
        api)
            print_info "API 服务日志 (Ctrl+C 退出):"
            tail -f "$LOG_DIR/api/access.log" 2>/dev/null || print_error "日志文件不存在"
            ;;
        add)
            print_info "Add RPC 服务日志 (Ctrl+C 退出):"
            tail -f "$LOG_DIR/rpc/add/access.log" 2>/dev/null || print_error "日志文件不存在"
            ;;
        check)
            print_info "Check RPC 服务日志 (Ctrl+C 退出):"
            tail -f "$LOG_DIR/rpc/check/access.log" 2>/dev/null || print_error "日志文件不存在"
            ;;
        all)
            print_info "所有服务日志 (Ctrl+C 退出):"
            tail -f "$LOG_DIR/api/access.log" \
                     "$LOG_DIR/rpc/add/access.log" \
                     "$LOG_DIR/rpc/check/access.log" 2>/dev/null || print_error "日志文件不存在"
            ;;
        *)
            print_error "未知的服务: $service"
            echo "可用选项: api, add, check, all"
            ;;
    esac
}

# 清理日志
clean_logs() {
    print_info "清理日志文件..."
    rm -rf "$LOG_DIR"/*
    print_info "✓ 日志已清理"
}

# 显示帮助信息
help() {
    cat << EOF
Bookstore 服务管理脚本

用法: $0 <command> [options]

命令:
  build           构建所有服务
  start           启动所有服务
  stop            停止所有服务
  restart         重启所有服务
  status          查看服务状态
  logs <service>  查看日志 (api|add|check|all)
  clean           清理日志文件
  help            显示帮助信息

示例:
  $0 build              # 构建所有服务
  $0 start              # 启动所有服务
  $0 status             # 查看状态
  $0 logs api           # 查看 API 日志
  $0 logs all           # 查看所有日志
  $0 restart            # 重启所有服务
  $0 stop               # 停止所有服务

服务端口:
  - Add RPC:   127.0.0.1:8080
  - Check RPC: 127.0.0.1:8081
  - API:       0.0.0.0:8888

EOF
}

# 主函数
main() {
    case "$1" in
        build)
            build
            ;;
        start)
            start
            ;;
        stop)
            stop
            ;;
        restart)
            restart
            ;;
        status)
            status
            ;;
        logs)
            logs "$2"
            ;;
        clean)
            clean_logs
            ;;
        help|--help|-h|"")
            help
            ;;
        *)
            print_error "未知命令: $1"
            echo ""
            help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
