#!/bin/bash

export LANG=en_US.UTF-8

# 确保以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    printf "❌ 请使用 root 权限运行此脚本！(例如: sudo bash menu.sh)\n"
    exit 1
fi

# 定义颜色变量
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
SKYBLUE='\033[1;36m'
NC='\033[0m' # 恢复默认颜色

# 检查 OpenVPN 是否已安装
check_openvpn_installed() {
    if [ -d "/etc/openvpn/server" ] || [ -f "/etc/systemd/system/openvpn-server@server.service" ]; then
        return 0
    else
        return 1
    fi
}

# ----------------- OpenVPN 管理函数（安装与客户端管理一体化） -----------------
do_openvpn_manager() {
    if [ ! -f "openvpn-install.sh" ]; then
        wget -O openvpn-install.sh https://git.io/vpn >/dev/null 2>&1
        chmod +x openvpn-install.sh
    fi

    if check_openvpn_installed; then
        echo ""
        echo "=================================================="
        printf "${GREEN}✅ 检测到 OpenVPN 服务端已安装！${NC}\n"
        printf "${GREEN}即将为您打开原版客户端与服务端管理菜单...${NC}\n"
        echo "=================================================="
        echo ""
        read -p "请按回车键继续进入管理菜单..."
    else
        echo "=== 正在下载并运行原版 OpenVPN 安装程序 ==="
    fi

    # 直接调用原版管理/安装脚本（保留原生交互，去掉多设备修改）
    bash openvpn-install.sh
}

# ----------------- 其他工具安装函数 -----------------
do_install_hy2() {
    echo "=== 正在启动 Hysteria 2 一键脚本 ==="
    bash <(wget -qO- https://raw.githubusercontent.com/pinode1314/hysteria2/main/hysteria2.sh)
}

do_install_frp() {
    echo "=== 正在启动 FRP 一键安装脚本 ==="
    bash <(wget -qO- https://raw.githubusercontent.com/pinode1314/frp-script/main/frp.sh)
}

do_install_rinetd() {
    echo "=== 正在启动 Rinetd 一键脚本 ==="
    bash <(wget -qO- https://raw.githubusercontent.com/pinode1314/Rinetd/main/rinetd.sh)
}

do_install_softether() {
    echo "=== 正在启动 SoftEther 一键脚本 ==="
    bash <(wget -qO- https://raw.githubusercontent.com/pinode1314/SoftEther/main/SoftEther.sh)
}

do_install_singbox() {
    echo "=== 正在启动五合一脚本 ==="
    bash <(wget -qO- https://raw.githubusercontent.com/pinode1314/5/main/5.sh)
    # 安装完成后自动执行指定命令生成订阅链接
    printf '3\n8\n1\n888988' | sb
}

do_install_system_tools() {
    echo "=== 正在启动 linux系统工具 ==="
    bash <(wget -qO- https://raw.githubusercontent.com/pinode1314/SSH/main/SSH.sh)
}

do_install_firewall() {
    echo "=== 正在启动防火墙管理脚本 ==="
    bash <(wget -qO- https://raw.githubusercontent.com/pinode1314/firewall/main/firewall.sh)
}

# ----------------- AmneziaWG 安装管理函数（全菜单深度汉化版） -----------------
do_install_amneziawg() {
    echo "=== 正在下载并准备 AmneziaWG 一键搭建与管理脚本 ==="
    
    # 强制重新下载最新脚本
    rm -f amneziawg-install.sh
    curl -sO https://raw.githubusercontent.com/wiresock/amneziawg-install/main/amneziawg-install.sh
    
    if [ -f "amneziawg-install.sh" ]; then
        # 主菜单及基础提示汉化
        sed -i 's#It looks like AmneziaWG is already installed.#检测到系统已安装 AmneziaWG。#g' amneziawg-install.sh
        sed -i 's#AmneziaWG server installer#AmneziaWG 服务端安装与管理工具#g' amneziawg-install.sh
        sed -i 's#What do you want to do?#请选择您想要进行的操作：#g' amneziawg-install.sh
        sed -i 's#1) Add a new user#1) 添加新用户#g' amneziawg-install.sh
        sed -i 's#2) List all users#2) 查看所有用户列表#g' amneziawg-install.sh
        sed -i 's#3) Revoke existing user#3) 吊销/删除现有用户#g' amneziawg-install.sh
        sed -i 's#4) Regenerate all client configs (using current server parameters)#4) 重新生成所有客户端配置（基于当前服务器参数）#g' amneziawg-install.sh
        sed -i 's#5) Change AWG protocol mode#5) 修改 AWG 协议混淆模式#g' amneziawg-install.sh
        sed -i 's#(current: #(当前: #g' amneziawg-install.sh
        sed -i 's#6) Uninstall AmneziaWG#6) 卸载 AmneziaWG#g' amneziawg-install.sh
        sed -i 's#7) Exit#7) 退出脚本#g' amneziawg-install.sh
        sed -i 's#Select an option#请选择一个选项#g' amneziawg-install.sh
        
        # 子菜单项：吊销用户相关提示汉化
        sed -i 's#Select the existing client you want to revoke#请选择您想要吊销/删除的客户端#g' amneziawg-install.sh
        sed -i 's#Select one client#请选择一个客户端#g' amneziawg-install.sh

        # 子菜单项：第 5 项协议修改菜单汉化
        sed -i 's#Current AmneziaWG protocol mode:#当前 AmneziaWG 协议模式：#g' amneziawg-install.sh
        sed -i 's#1) Enable AWG 3.0 (header protection)#1) 启用 AWG 3.0 (头部保护)#g' amneziawg-install.sh
        sed -i 's#2) Enable AWG 3.1 (header protection + RandomTrailers; DisableCookies stays off)#2) 启用 AWG 3.1 (头部保护 + 随机尾部；关闭禁用Cookie)#g' amneziawg-install.sh
        sed -i 's#3) Cancel#3) 取消#g' amneziawg-install.sh

        # 安装/添加用户等其他常见交互提示汉化
        sed -i 's#Public IPv4 address#请输入或确认您的 公网 IPv4 地址#g' amneziawg-install.sh
        sed -i 's#Server AmneziaWG port#请输入 AmneziaWG 服务监听端口#g' amneziawg-install.sh
        sed -i 's#Client name#请输入客户端名称#g' amneziawg-install.sh

        chmod +x amneziawg-install.sh
        sudo ./amneziawg-install.sh
    else
        printf "${RED}❌ 下载 AmneziaWG 脚本失败，请检查网络连接！\n${NC}"
    fi
}

# ----------------- 主菜单循环 -----------------
while true; do
    echo ""
    printf "${SKYBLUE}=========================================\n${NC}"
    printf "${SKYBLUE}     ⚡ 【夜未央】 脚本工具箱 ⚡         \n${NC}"
    printf "${SKYBLUE}=========================================\n${NC}"
    echo " 1. 安装 OpenVPN"
    echo " 2. 安装 Hysteria 2"
    echo " 3. 安装 frp 端口映射"
    echo " 4. 安装 rinetd TCP端口映射"
    echo " 5. 安装 SoftEther VPN"
    echo " 6. sing-box 五合一脚本"
    echo " 7. linux系统工具"
    echo " 8. 系统防火墙管理"
    echo " 9. 安装 AmneziaWG VPN"
    echo " 0. 退出脚本"
    printf "${SKYBLUE}=========================================\n${NC}"
    read -p "请选择操作 [0-9]: " CHOICE

    case "$CHOICE" in
        1)
            do_openvpn_manager
            ;;
        2)
            do_install_hy2
            ;;
        3)
            do_install_frp
            ;;
        4)
            do_install_rinetd
            ;;
        5)
            do_install_softether
            ;;
        6)
            do_install_singbox
            ;;
        7)
            do_install_system_tools
            ;;
        8)
            do_install_firewall
            ;;
        9)
            do_install_amneziawg
            ;;
        0)
            echo "已安全退出脚本。"
            break
            ;;
        *)
            printf "${RED}❌ 无效的选项，请输入 0 到 9 之间的数字。\n${NC}"
            ;;
    esac
done
