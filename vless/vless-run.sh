#!/bin/bash

# 定义添加 crontab 守护进程任务的函数
add_crontab_task() {
    # 进入用户目录
    cd "$USER_PATH"

    # 下载并设置脚本
    curl -Ls https://raw.githubusercontent.com/haoxinyu1/socks5-hysteria2-for-Serv00-CT8/main/serv00_singbox.sh -o serv00_singbox.sh && chmod +x serv00_singbox.sh
    curl -Ls https://raw.githubusercontent.com/haoxinyu1/socks5-hysteria2-for-Serv00-CT8/main/start_app.sh -o start_app.sh && chmod +x start_app.sh
    
    # 检查是否成功下载
    if [ ! -f "start_app.sh" ]; then
        echo "下载 start_app.sh 失败，退出"
        exit 1
    fi

    # 备份现有的 crontab 任务到临时文件
    crontab -l > /tmp/crontab.bak 2>/dev/null
    
    # 定义要添加的任务
    new_task="*/12 * * * * nohup $USER_PATH/start_app.sh >/dev/null 2>&1"

    # 检查是否已经存在任务
    if grep -Fxq "$new_task" /tmp/crontab.bak; then
        echo "相同的 crontab 任务已经存在，跳过添加"
    else
        # 删除旧任务，添加新任务
        grep -v "start_app.sh" /tmp/crontab.bak > /tmp/crontab.new
        echo "$new_task" >> /tmp/crontab.new
        
        # 更新 crontab 任务
        crontab /tmp/crontab.new
        rm /tmp/crontab.new

        echo -e "\e[1;32mCrontab 任务添加完成\e[0m"
    fi
    
    # 删除临时文件
    rm /tmp/crontab.bak
    
    # 等待2秒后执行 start_app.sh 脚本
    sleep 2
    ./start_app.sh
}

# 获取当前用户名
USERNAME=$(whoami)
# 获取当前主机名
HOSTNAME=$(hostname)
NAME=$(echo "$HOSTNAME" | cut -d'.' -f1)
# 设置用户目录路径
USER_PATH=$(pwd)

cd domains/$USERNAME.serv00.net/

# 下载 vless.zip
wget https://raw.githubusercontent.com/bin862324915/serv00-app/main/vless/vless.zip -O vless.zip

# 解压文件
unzip vless.zip

# 检查是否成功解压
if [ -f "vless/app.js" ]; then
    clear
    echo
    echo "vless 应用以及相关的依赖已经自动安装完成"
    echo

    # 设置 VLESS 节点端口
    read -p "请设置 vless 节点端口（例如 8080）： " vless_port
    echo "节点端口已设置为: $vless_port"
    echo

    # 设置 UUID
    read -p "请设置 UUID： " vless_uuid
    echo "UUID 已设置为: $vless_uuid"
    echo

    # 生成 app.js 配置文件
    cat > vless/app.js <<EOL
const net = require('net');
const WebSocket = require('ws');
const logcb = (...args) => console.log.bind(this, ...args);
const errcb = (...args) => console.error.bind(this, ...args);

const uuid = (process.env.UUID || '${vless_uuid}').replace(/-/g, '');
const port = process.env.PORT || ${vless_port};

const wss = new WebSocket.Server({ port }, logcb('listen:', port));

wss.on('connection', ws => {
    console.log("on connection");

    ws.once('message', msg => {
        const [VERSION] = msg;
        const id = msg.slice(1, 17);

        if (!id.every((v, i) => v === parseInt(uuid.substr(i * 2, 2), 16))) return;

        let i = msg.slice(17, 18).readUInt8() + 19;
        const targetPort = msg.slice(i, i += 2).readUInt16BE(0);
        const ATYP = msg.slice(i, i += 1).readUInt8();
        const host = ATYP === 1 ? msg.slice(i, i += 4).join('.') : // IPV4
            (ATYP === 2 ? new TextDecoder().decode(msg.slice(i + 1, i += 1 + msg.slice(i, i + 1).readUInt8())) : // domain
                (ATYP === 3 ? msg.slice(i, i += 16).reduce((s, b, i, a) => (i % 2 ? s.concat(a.slice(i - 1, i + 1)) : s), []).map(b => b.readUInt16BE(0).toString(16)).join(':') : '')); // IPV6

        logcb('conn:', host, targetPort);

        ws.send(new Uint8Array([VERSION, 0]));

        const duplex = WebSocket.createWebSocketStream(ws);

        net.connect({ host, port: targetPort }, function () {
            this.write(msg.slice(i));
            duplex.on('error', errcb('E1:')).pipe(this).on('error', errcb('E2:')).pipe(duplex);
        }).on('error', errcb('Conn-Err:', { host, port: targetPort }));
    }).on('error', errcb('EE:'));
});
EOL

    # 调用 add_crontab_task 函数
    add_crontab_task

    # 获取 ISP 信息
    ISP=$(curl -s https://speed.cloudflare.com/meta | awk -F\" '{print $26}' | sed -e 's/ /_/g')
    echo "app.js 已生成，使用的端口为: $vless_port，UUID 为: $vless_uuid"
    echo
    echo "节点连接为：vless://$vless_uuid@$USERNAME.serv00.net:$vless_port?encryption=none&security=none&type=ws&path=/#$USERNAME-$ISP-$NAME-VL"
    echo "加速节点连接为：vless://$vless_uuid@usa.visa.com:443?encryption=none&security=tls&sni=你的cf加速域名&pbk=SxBMcWxdxYBAh_IUSsiCDk6UHIf1NA1O8hUZ2hbRTFE&allowInsecure=1&type=ws&host=你的cf加速域名&path=/#$USERNAME-$ISP-$NAME-VL"
else
    echo
    echo "自动安装失败，请手动解压操作，并配置文件"
    echo
fi
