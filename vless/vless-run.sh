#!/bin/bash
red="\033[1;91m"
green="\e[1;32m"
yellow="\e[1;33m"
purple="\e[1;35m"
red() { echo -e "\e[1;91m$1\033[0m"; }
green() { echo -e "\e[1;32m$1\033[0m"; }
yellow() { echo -e "\e[1;33m$1\033[0m"; }
purple() { echo -e "\e[1;35m$1\033[0m"; }
reading() { read -p "$(red "$1")" "$2"; }

export DOMAIN=${DOMAIN:-''}
					
USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')
snb=$(hostname | cut -d. -f1)
HOSTNAME=$(hostname)
hona=$(hostname | cut -d. -f2)

			  
if [ -n "$DOMAIN" ]; then
					  
  keep_path="${HOME}/domains/${DOMAIN}/public_nodejs"
  mkdir -p "$keep_path"
else
  if [ "$hona" = "serv00" ]; then
    address="serv00.net"
  else
    address="useruno.com"
  fi
  keep_path="${HOME}/domains/${snb}.${USERNAME}.${address}/public_nodejs"
  mkdir -p "$keep_path"
fi

						   
create_nodejs_site() {
  green "开始安装Node.js网站，请稍等……"

  if [ -n "$DOMAIN" ]; then
    domain_to_use="$DOMAIN"
  else
    domain_to_use="${snb}.${USERNAME}.${hona}.net"
  fi

  devil www del "$domain_to_use" > /dev/null 2>&1
  devil www add "$domain_to_use" nodejs /usr/local/bin/node18 > /dev/null 2>&1

					   
  ln -fs /usr/local/bin/node18 ~/bin/node > /dev/null 2>&1
  ln -fs /usr/local/bin/npm18 ~/bin/npm > /dev/null 2>&1
  mkdir -p ~/.npm-global
  npm config set prefix '~/.npm-global'
  echo 'export PATH=~/.npm-global/bin:~/bin:$PATH' >> $HOME/.bash_profile && source $HOME/.bash_profile
  rm -rf $HOME/.npmrc > /dev/null 2>&1

				
  cd "$keep_path"
  npm install basic-auth express dotenv axios --silent > /dev/null 2>&1

							
  rm "$HOME/domains/${domain_to_use}/public_nodejs/public/index.html" > /dev/null 2>&1

							
  reading "是否要下载示例应用程序文件？[y/n]: " download_app
  if [[ "$download_app" == "y" || "$download_app" == "Y" ]]; then
    yellow "下载示例应用程序文件..."
    curl -sL https://raw.githubusercontent.com/haoxinyu1/sing-box-yg/main/app.js -o "$keep_path"/app.js
    green "应用程序文件已下载并配置"
  fi

				
  devil www restart "$domain_to_use"
  curl -sk "http://${domain_to_use}/up" > /dev/null 2>&1

  green "安装完毕，Node.js网站地址：http://${domain_to_use}"
  yellow "Node.js应用目录：$keep_path"
}

				   
# 安装VLESS应用
install_vless() {
  green "开始安装VLESS应用，请稍等……"
  
  # 设置用户目录路径
  USER_PATH=$(pwd)
  
  # 进入用户域名目录
  cd domains/${USERNAME}.${address}/
  
  # 下载vless.zip
  wget https://raw.githubusercontent.com/bin862324915/serv00-app/main/vless/vless.zip -O vless.zip
  
  # 解压文件
  unzip -o vless.zip
  
  # 检查是否成功解压
  if [ -f "vless/app.js" ]; then
    clear
    echo
    green "VLESS应用以及相关的依赖已经自动安装完成"
    echo
    
    # 设置VLESS节点端口
    reading "请设置VLESS节点端口（例如8080）: " vless_port
    green "节点端口已设置为: $vless_port"
    echo
    
    # 设置UUID
    reading "请设置UUID（留空自动生成）: " vless_uuid
    if [[ -z "$vless_uuid" ]]; then
      vless_uuid=$(uuidgen -r)
    fi
    green "UUID已设置为: $vless_uuid"
    echo
    
    # 设置CF加速域名
    reading "请输入你的CF加速域名（留空将显示占位符）: " cf_domain
    if [[ -z "$cf_domain" ]]; then
      cf_domain="你的cf加速域名"
    fi
    green "CF加速域名已设置为: $cf_domain"
    echo
    
    # 生成app.js配置文件
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
    
    # 添加crontab守护进程任务
    add_crontab_task
    
    # 获取ISP信息
    ISP=$(curl -s https://speed.cloudflare.com/meta | awk -F\" '{print $26}' | sed -e 's/ /_/g')
    
    # 显示节点连接信息
    echo
    green "app.js已生成，使用的端口为: $vless_port，UUID为: $vless_uuid"
    echo
    yellow "节点连接为：vless://$vless_uuid@$USERNAME.${address}:$vless_port?encryption=none&security=none&type=ws&path=/#$USERNAME-$ISP-$snb-VL"
    yellow "加速节点连接为：vless://$vless_uuid@usa.visa.com:443?encryption=none&security=tls&sni=$cf_domain&pbk=SxBMcWxdxYBAh_IUSsiCDk6UHIf1NA1O8hUZ2hbRTFE&allowInsecure=1&type=ws&host=$cf_domain&path=/#$USERNAME-$ISP-$snb-VL"
  else
    red "自动安装失败，请手动解压操作，并配置文件"
  fi
  
  # 返回初始目录
  cd $USER_PATH
}

# 定义添加crontab守护进程任务的函数
add_crontab_task() {
  # 当前目录应该是domains/${USERNAME}.${address}/
  
  # 下载并设置脚本
  curl -Ls https://raw.githubusercontent.com/haoxinyu1/socks5-hysteria2-for-Serv00-CT8/main/serv00_singbox.sh -o serv00_singbox.sh && chmod +x serv00_singbox.sh
  curl -Ls https://raw.githubusercontent.com/haoxinyu1/socks5-hysteria2-for-Serv00-CT8/main/start_app.sh -o start_app.sh && chmod +x start_app.sh
  
  # 检查是否成功下载
  if [ ! -f "start_app.sh" ]; then
    red "下载start_app.sh失败，退出"
    return 1
  fi
  
  # 备份现有的crontab任务到临时文件
  crontab -l > /tmp/crontab.bak 2>/dev/null
  
  # 定义要添加的任务
  new_task="*/12 * * * * nohup $(pwd)/start_app.sh >/dev/null 2>&1"
  
  # 检查是否已经存在任务
  if grep -Fxq "$new_task" /tmp/crontab.bak; then
    yellow "相同的crontab任务已经存在，跳过添加"
  else
    # 删除旧任务，添加新任务
    grep -v "start_app.sh" /tmp/crontab.bak > /tmp/crontab.new
    echo "$new_task" >> /tmp/crontab.new
    
    # 更新crontab任务
    crontab /tmp/crontab.new
    rm /tmp/crontab.new
    
    green "Crontab任务添加完成"
  fi
  
  # 删除临时文件
  rm /tmp/crontab.bak
  
  # 等待2秒后执行start_app.sh脚本
  sleep 2
  ./start_app.sh
}

# 菜单
menu() {
  clear
  echo "============================================================"
  green "Node.js & VLESS应用创建脚本"
  echo "============================================================"
  green "1. 创建Node.js网站"
  green "2. 安装VLESS应用"
  red   "0. 退出脚本"
  echo "============================================================"
  
  reading "请输入选择【0-2】: " choice
  echo
  
  case "${choice}" in
    1) create_nodejs_site ;;
    2) install_vless ;;
    0) exit 0 ;;
    *) red "无效的选项，请输入 0-2" && menu ;;
  esac
}

# 运行菜单
menu
