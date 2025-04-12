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

# 设置路径
if [ -n "$DOMAIN" ]; then
  custom_domain="$DOMAIN"
  keep_path="${HOME}/domains/${custom_domain}/public_nodejs"
  [ -d "$keep_path" ] || mkdir -p "$keep_path"
elif [ "$hona" = "serv00" ]; then
  address="serv00.net"
  keep_path="${HOME}/domains/${snb}.${USERNAME}.serv00.net/public_nodejs"
  [ -d "$keep_path" ] || mkdir -p "$keep_path"
else
  address="useruno.com"
  keep_path="${HOME}/domains/${snb}.${USERNAME}.${address}/public_nodejs"
  [ -d "$keep_path" ] || mkdir -p "$keep_path"
fi

create_nodejs_site() {
  green "开始安装Node.js网站，请稍等……"

  # 获取实际域名
  if [ -n "$DOMAIN" ]; then
    domain_to_use="$DOMAIN"
  else
    domain_to_use="${snb}.${USERNAME}.${hona}.net"
  fi

  # 删除和添加网站
  devil www del "$domain_to_use" > /dev/null 2>&1
  devil www add "$domain_to_use" nodejs /usr/local/bin/node18 > /dev/null 2>&1

  # 设置Node.js环境
  ln -fs /usr/local/bin/node18 ~/bin/node > /dev/null 2>&1
  ln -fs /usr/local/bin/npm18 ~/bin/npm > /dev/null 2>&1
  mkdir -p ~/.npm-global
  npm config set prefix '~/.npm-global'
  echo 'export PATH=~/.npm-global/bin:~/bin:$PATH' >> $HOME/.bash_profile && source $HOME/.bash_profile
  rm -rf $HOME/.npmrc > /dev/null 2>&1

  # 安装依赖
  cd "$keep_path"
  npm install basic-auth express dotenv axios --silent > /dev/null 2>&1

  # 清理默认索引文件
  rm $HOME/domains/"$domain_to_use"/public_nodejs/public/index.html > /dev/null 2>&1

  # 下载应用程序文件
  reading "是否要下载示例应用程序文件？[y/n]: " download_app
  if [[ "$download_app" == "y" || "$download_app" == "Y" ]]; then
    yellow "下载示例应用程序文件..."
    curl -sL https://raw.githubusercontent.com/haoxinyu1/sing-box-yg/main/app.js -o "$keep_path"/app.js
    green "应用程序文件已下载并配置"
  fi

  # 重启网站
  devil www restart "$domain_to_use"
  curl -sk "http://${domain_to_use}/up" > /dev/null 2>&1

  green "安装完毕，Node.js网站地址：http://${domain_to_use}"
  yellow "Node.js应用目录：$keep_path"
}

# 其余函数保持不变...

# install_vless 和 add_crontab_task 略...

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
