#!/bin/bash

# 获取当前用户名
USER=$(whoami)
# 获取主机名
HOSTNAME=$(hostname)

# 应用程序路径设置，根据主机名来选择不同的路径
if [[ $HOSTNAME == *"ct8.pl"* ]]; then
    FRP_PATH="/home/$USER/domains/${USER}.ct8.pl/frp"
    WEB_PATH="/home/$USER/domains/${USER}.ct8.pl/singbox"
    S5_PATH="/home/$USER/domains/${USER}.ct8.pl/socks5"
elif [[ $HOSTNAME == *"serv00.com"* ]]; then
    FRP_PATH="/home/$USER/domains/${USER}.serv00.net/frp"
    WEB_PATH="/home/$USER/domains/${USER}.serv00.net/singbox"
    S5_PATH="/home/$USER/domains/${USER}.serv00.net/socks5"
else
    echo "未知的主机名: $HOSTNAME"
    exit 1
fi

# 应用程序的可执行命令
WEB_EXEC="./web run -c config.json"
FRPS_EXEC="./frps -c frps.ini"
S5_EXEC="./s5 -c config.json"

# frps 进程检查函数
is_frps_running() {
    pgrep -f "$FRPS_EXEC" > /dev/null 2>&1
}

# s5 进程检查函数
is_s5_running() {
    pgrep -f "$S5_EXEC" > /dev/null 2>&1
}

# web 进程检查函数
is_web_running() {
    pgrep -f "$WEB_EXEC" > /dev/null 2>&1
}

# 通用的进程启动函数
start_process() {
    local path="$1"             # 进程所在路径
    local exec_cmd="$2"         # 启动命令
    local process_check_func="$3"  # 检查进程的函数
    local process_name="$4"     # 进程名称

    echo "启动 $process_name..."
    cd "$path" || exit          # 切换到指定路径
    nohup $exec_cmd >/dev/null 2>&1 &  # 在后台启动进程并忽略输出
    sleep 5                     # 等待进程启动
    if $process_check_func; then
        echo "$process_name 启动成功"
    else
        echo "$process_name 启动失败"
    fi
}

# 重启 frps 进程
restart_frps() {
    echo "检查 frps 进程..."
    if is_frps_running; then
        echo "frps 进程已在运行，无需重新启动"
    else
        echo "frps 进程未运行"
        start_process "$FRP_PATH" "$FRPS_EXEC" is_frps_running "frps"
    fi
}

# 强制重启 frps 进程
force_restart_frps() {
    echo "强制重启 frps 进程..."
    pkill -f "$FRPS_EXEC"       # 强制终止现有的 frps 进程
    sleep 2                     # 等待进程完全终止
    restart_frps                # 重新启动 frps 进程
}

# 检查并启动 frps 进程
if [ -d "$FRP_PATH" ]; then
    restart_frps
else
    echo "frps 目录不存在，跳过 frps 操作"
fi

# 检查并启动 s5 进程
if [ -d "$S5_PATH" ]; then
    if is_s5_running; then
        echo "s5 进程正在运行"
    else
        echo "s5 进程未运行"
        start_process "$S5_PATH" "$S5_EXEC" is_s5_running "s5"
    fi
else
    echo "s5 目录不存在，跳过 s5 操作"
fi

# 检查并启动 web 进程
if [ -d "$WEB_PATH" ]; then
    if is_web_running; then
        echo "web 进程正在运行"
    else
        echo "web 进程未运行"
        start_process "$WEB_PATH" "$WEB_EXEC" is_web_running "web"
    fi
else
    echo "web 目录不存在，跳过 web 操作"
fi

# 可以调用 force_restart_frps 强制重启 frps
# force_restart_frps
