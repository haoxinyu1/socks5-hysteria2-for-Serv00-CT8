#!/bin/bash

# 获取当前用户名
USER=$(whoami)
# 获取主机名
HOSTNAME=$(hostname)

# 应用程序路径设置，根据主机名来选择不同的路径
if [[ $HOSTNAME == *"ct8.pl"* ]]; then
    USER_PATH="/home/$USER/domains/$USER.ct8.pl"
    APP_PATH="/home/$USER/domains/$USER.ct8.pl/vless/app.js"
    FRP_PATH="/home/$USER/domains/${USER}.ct8.pl/frp"
    WEB_PATH="/home/$USER/domains/${USER}.ct8.pl/singbox"
    S5_PATH="/home/$USER/domains/${USER}.ct8.pl/socks5"
elif [[ $HOSTNAME == *"serv00.com"* ]]; then
    USER_PATH="/home/$USER/domains/$USER.serv00.net"
    APP_PATH="/home/$USER/domains/$USER.serv00.net/vless/app.js"
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

# 进程检查函数
is_running() {
    pgrep -f "$1" > /dev/null 2>&1
}

# 通用的进程启动函数
start_process() {
    local path="$1"           # 进程所在路径
    local exec_cmd="$2"       # 启动命令
    local process_name="$3"   # 进程名称

    echo "启动 $process_name..."
    cd "$path" || exit        # 切换到指定路径
    nohup $exec_cmd >/dev/null 2>&1 &  # 在后台启动进程并忽略输出
    sleep 5                   # 等待进程启动
    if is_running "$exec_cmd"; then
        echo "$process_name 启动成功"
    else
        echo "$process_name 启动失败"
    fi
}

# 启动或重启 vless 应用程序
manage_vless() {
    if [ -d "$(dirname "$APP_PATH")" ]; then
        if is_running "$APP_PATH"; then
            echo "vless 进程正在运行，重新启动..."
            pkill -f "$APP_PATH"
            sleep 2
        else
            echo "vless 进程未运行，启动..."
        fi
        start_process "$(dirname "$APP_PATH")" "node $APP_PATH" "vless"
    else
        echo "vless 目录不存在，跳过 vless 操作"
    fi
}

# 检查并启动或重启 frps 进程
manage_frps() {
    if [ -d "$FRP_PATH" ] && [ -f "$FRP_PATH/frps" ]; then
        if is_running "$FRPS_EXEC"; then
            echo "frps 进程已在运行，无需重新启动"
        else
            start_process "$FRP_PATH" "$FRPS_EXEC" "frps"
        fi
    else
        echo "frps 目录或程序文件不存在，跳过 frps 操作"
    fi
}

# 检查并启动 s5 进程
manage_s5() {
    if [ -d "$S5_PATH" ] && [ -f "$S5_PATH/s5" ]; then
        if is_running "$S5_EXEC"; then
            echo "s5 进程正在运行"
        else
            start_process "$S5_PATH" "$S5_EXEC" "s5"
        fi
    else
        echo "s5 目录或程序文件不存在，跳过 s5 操作"
    fi
}

# 检查并启动 web 进程
manage_web() {
    if [ -d "$WEB_PATH" ] && [ -f "$WEB_PATH/web" ]; then
        if is_running "$WEB_EXEC"; then
            echo "web 进程正在运行"
        else
            start_process "$WEB_PATH" "$WEB_EXEC" "web"
        fi
    else
        echo "web 目录或程序文件不存在，跳过 web 操作"
    fi
}

# 添加 crontab 守护进程任务
add_crontab_task() {
  # 备份现有的 crontab 任务到临时文件
  crontab -l > /tmp/crontab.bak 2>/dev/null
  
  # 定义要添加的任务
  new_task="*/12 * * * * nohup $USER_PATH/start_app.sh >/dev/null 2>&1"

  # 检查是否存在相同的任务
  if grep -Fxq "$new_task" /tmp/crontab.bak; then
    echo "相同的 crontab 任务已经存在，跳过添加"
  else
    # 如果存在类似的任务，先删除它，然后添加新任务
    grep -v "start_app.sh" /tmp/crontab.bak > /tmp/crontab.new
    echo "$new_task" >> /tmp/crontab.new
    
    # 重新加载 crontab 任务
    crontab /tmp/crontab.new
    rm /tmp/crontab.new

    echo -e "\e[1;32mCrontab 任务添加完成\e[0m"
  fi
  
  # 删除临时 crontab 文件
  rm /tmp/crontab.bak
}

# 主逻辑执行
manage_vless
manage_frps
manage_s5
manage_web
add_crontab_task

# 可选：调用 force_restart_frps 强制重启 frps
# force_restart_frps
