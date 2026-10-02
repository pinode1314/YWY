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

# ----------------- AmneziaWG 安装管理函数（含自动汉化） -----------------
do_install_amneziawg() {
    echo "=== 正在下载并准备 AmneziaWG 一键搭建与管理脚本 ==="
    
    # 下载官方原版脚本
    curl -sO https://raw.githubusercontent.com/wiresock/amneziawg-install/main/amneziawg-install.sh
    
    if [ -f "amneziawg-install.sh" ]; then
        # 自动对脚本内部的提示文字进行中文汉化替换
        sed -i 's/It looks like AmneziaWG is already installed./检测到 AmneziaWG 已经安装。/g' amneziawg-install.sh
        sed -i 's/AmneziaWG server installer/AmneziaWG 服务端安装程序/g' amneziawg-install.sh
        sed -i 's/What do you want to do?/请选择您想要进行的操作：/g' amneziawg-install.sh
        sed -i 's/Add a new user/添加新用户/g' amneziawg-install.sh
        sed -i 's/List all users/查看所有用户列表/g' amneziawg-install.sh
        sed -i 's/Revoke existing user/吊销/删除现有用户/g' amneziawg-install.sh
        sed -i 's/Regenerate all client configs (using current server parameters)/重新生成所有客户端配置（使用当前服务端参数）/g' amneziawg-install.sh
        sed -i 's/Change AWG protocol mode/修改 AWG 协议混淆模式/g' amneziawg-install.sh
        sed -i 's/Uninstall AmneziaWG/卸载 AmneziaWG/g' amneziawg-install.sh
        sed -i 's/Exit/退出/g' amneziawg-install.sh
        sed -i 's/Select an option/请选择一个选项/g' amneziawg-install.sh
        
        # 常见安装过程中的英文提示汉化
        sed -i 's/Public IPv4 address/请输入或确认您的 公网 IPv4 地址/g' amneziawg-install.sh
        sed -i 's/Public IPv6 address/请输入或确认您的 公网 IPv6 地址/g' amneziawg-install.sh
        sed -i 's/Default interface/默认网络接口/g' amneziawg-install.sh
        sed -i 's/AmneziaWG interface name/AmneziaWG 虚拟网卡名称/g' amneziawg-install.sh
        sed -i 's/Server AmneziaWG IPv4/服务器 AmneziaWG 内网 IPv4 地址/g' amneziawg-install.sh
        sed -i 's/Server AmneziaWG IPv6/服务器 AmneziaWG 内网 IPv6 地址/g' amneziawg-install.sh
        sed -i 's/Server AmneziaWG port/AmneziaWG 服务监听端口/g' amneziawg-install.sh
        sed -i 's/Client name/客户端名称/g' amneziawg-install.sh
        sed -i 's/Client AmneziaWG IPv4/客户端 AmneziaWG 内网 IPv4 地址/g' amneziawg-install.sh
        sed -i 's/Client AmneziaWG IPv6/客户端 AmneziaWG 内网 IPv6 地址/g' amneziawg-install.sh

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
