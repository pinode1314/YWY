#!/bin/bash

export LANG=en_US.UTF-8

# 定义颜色变量
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
SKYBLUE='\033[1;36m'
NC='\033[0m' # 恢复默认颜色

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
    printf "${RED}❌ 请使用 root 权限运行此脚本！(例如: sudo bash menu.sh)\n${NC}"
    exit 1
fi

# 检查 OpenVPN 是否已安装
check_openvpn_installed() {
    if [ -d "/etc/openvpn/server" ] || [ -f "/etc/systemd/system/openvpn-server@server.service" ]; then
        return 0
    else
        return 1
    fi
}

# ----------------- OpenVPN 管理函数（安装、新增、卸载一体化） -----------------
do_openvpn_manager() {
    if ! check_openvpn_installed; then
        echo "=== 检测到未安装 OpenVPN，正在引导首次安装 ==="
        wget -O openvpn-install.sh https://git.io/vpn
        chmod +x openvpn-install.sh

        # 调用原版交互安装
        bash openvpn-install.sh

        # 安装完成后，自动补全多设备同证书在线(duplicate-cn)以及默认客户端固定IP
        echo "=== 正在为默认客户端配置固定 IP 及多设备共存策略 ==="
        FIRST_OVPN=$(ls ~/*.ovpn 2>/dev/null | head -n 1)
        if [ -n "$FIRST_OVPN" ]; then
            CLIENT_NAME=$(basename "$FIRST_OVPN" .ovpn)
        else
            CLIENT_NAME="client"
        fi

        mkdir -p /etc/openvpn/ccd
        cat << CCD > /etc/openvpn/ccd/${CLIENT_NAME}
ifconfig-push 10.8.0.2 255.255.255.0
CCD

        if ! grep -q "client-config-dir" /etc/openvpn/server/server.conf; then
            echo 'client-config-dir /etc/openvpn/ccd' >> /etc/openvpn/server/server.conf
        fi
        if ! grep -q "duplicate-cn" /etc/openvpn/server/server.conf; then
            echo 'duplicate-cn' >> /etc/openvpn/server/server.conf
        fi

        systemctl restart openvpn-server@server
        echo ""
        echo "=================================================="
        printf "${GREEN}OpenVPN 安装完毕，多设备同时在线功能已激活！\n${NC}"
        echo "=================================================="
    else
        echo "=== OpenVPN 已安装，正在打开原版管理菜单（可新增/删除用户/卸载） ==="
        if [ ! -f "openvpn-install.sh" ]; then
            wget -O openvpn-install.sh https://git.io/vpn
            chmod +x openvpn-install.sh
        fi

        # 直接拉起原版管理菜单
        bash openvpn-install.sh

        # 确保管理操作后多用户多设备配置不丢失
        if ! grep -q "client-config-dir" /etc/openvpn/server/server.conf; then
            echo 'client-config-dir /etc/openvpn/ccd' >> /etc/openvpn/server/server.conf
        fi
        if ! grep -q "duplicate-cn" /etc/openvpn/server/server.conf; then
            echo 'duplicate-cn' >> /etc/openvpn/server/server.conf
        fi
        systemctl restart openvpn-server@server >/dev/null 2>&1
    fi
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
    # 更加严谨的判断：必须同时存在快捷命令 sb 且核心二进制文件 /etc/s-box/sing-box 真实存在，才认为是已安装
    if [ -f /etc/s-box/sing-box ] && command -v sb >/dev/null 2>&1; then
        echo "=== 检测到 sing-box 已安装，正在打开管理菜单（可查看配置、卸载等） ==="
        sb
        return
    fi

    # 否则（说明刚卸载过或是初次安装），走完整安装和自动生成订阅流程
    echo "=== 正在启动 sing-box 五合一脚本安装 ==="
    bash <(wget -qO- https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)
    echo "=== 正在自动配置并生成本地IP订阅链接 ==="
    printf '3\n8\n1\n888988' | sb
}

do_install_kejilion() {
    echo "=== 正在启动 科技lion Linux服务器运维工具箱 ==="
    if command -v kejilion >/dev/null 2>&1; then
        kejilion
    else
        bash <(curl -sL kejilion.sh)
    fi
}

# ----------------- 主菜单循环 -----------------
while true; do
    echo ""
    printf "${SKYBLUE}=========================================\n${NC}"
    printf "${SKYBLUE}      ⚡ 【夜未央】 脚本工具箱 ⚡        \n${NC}"
    printf "${SKYBLUE}=========================================\n${NC}"
    echo " 1. 安装OpenVPN 服务端与客户端管理 "
    echo " 2. 安装 Hysteria 2"
    echo " 3. 安装 FRP 端口映射"
    echo " 4. 安装 Rinetd TCP端口映射"
    echo " 5. 安装 SoftEther VPN"
    echo " 6. sing-box 五合一脚本"
    echo " 7. 科技lion Linux服务器运维工具箱"
    echo " 0. 退出脚本"
    printf "${SKYBLUE}=========================================\n${NC}"
    read -p "请选择操作 [0-7]: " CHOICE

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
            do_install_kejilion
            ;;
        0)
            echo "已安全退出脚本。"
            break
            ;;
        *)
            printf "${RED}❌ 无效的选项，请输入 0 到 7 之间的数字。\n${NC}"
            ;;
    esac
done
