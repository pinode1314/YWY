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

# ----------------- 优化 2：系统架构（CPU Architecture）校验 -----------------
check_architecture() {
    local ARCH=$(uname -m)
    echo "=== 当前系统架构: ${ARCH} ==="
    if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "aarch64" ] && [ "$ARCH" != "arm64" ]; then
        printf "${YELLOW}⚠️ 检测到您处于非主流架构 (${ARCH})，部分一键脚本可能无法正常运行二进制文件，请知悉。\n${NC}"
    fi
}

# ----------------- 优化 1 & 5：前置依赖安装、锁清理与返回值强校验 -----------------
install_deps_with_robustness() {
    echo "=== 正在识别系统并发起前置依赖检查与安装 ==="

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    elif [ -f /etc/debian_version ]; then
        OS="debian"
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
    else
        OS="unknown"
    fi

    local common_deps=("wget" "curl" "tar" "ca-certificates" "iptables" "socat" "cron" "unzip" "git")

    case "$OS" in
        ubuntu|debian|raspbian)
            export DEBIAN_FRONTEND=noninteractive
            # 清理可能存在的 dpkg 锁，防止由于后台更新导致卡死
            echo "=== 正在检查并清理可能存在的 apt 锁文件 ==="
            rm -f /var/lib/dpkg/lock-frontend /var/cache/apt/archives/lock /var/lib/dpkg/lock >/dev/null 2>&1
            
            apt-get update -y
            apt-get install -y "${common_deps[@]}"
            ;;
        centos|rhel|fedora|rocky|almalinux)
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y "${common_deps[@]}"
            else
                yum install -y "${common_deps[@]}"
            fi
            ;;
        alpine)
            apk update
            apk add --no-cache "${common_deps[@]}"
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm --needed "${common_deps[@]}"
            ;;
        opensuse*|sles)
            zypper refresh
            zypper install -y "${common_deps[@]}"
            ;;
        *)
            printf "${YELLOW}⚠️ 未能完全自动识别当前系统类型，将跳过自动依赖安装。\n${NC}"
            return 1
            ;;
    esac

    # 优化 5：返回值状态码校验
    if [ $? -eq 0 ]; then
        echo "=== 前置依赖检查与安装成功完成 ==="
        return 0
    else
        printf "${YELLOW}⚠️ 部分依赖安装可能未完全成功，建议检查上方报错日志。\n${NC}"
        return 1
    fi
}

# ----------------- 优化 4：防火墙端口放行辅助函数 -----------------
auto_open_firewall_port() {
    local port=$1
    if [ -z "$port" ]; then
        return
    fi
    
    echo "=== 正在尝试自动放行防火墙端口: ${port} ==="
    # 检测并放行 UFW (Ubuntu/Debian 常用)
    if command -v ufw >/dev/null 2>&1; then
        if ufw status | grep -q "Status: active"; then
            ufw allow ${port}/tcp >/dev/null 2>&1
            ufw allow ${port}/udp >/dev/null 2>&1
            echo "=== 已通过 UFW 放行端口 ${port} ==="
        fi
    fi

    # 检测并放行 Firewalld (CentOS/RHEL 常用)
    if command -v firewall-cmd >/dev/null 2>&1; then
        if systemctl is-active --quiet firewalld; then
            firewall-cmd --zone=public --add-port=${port}/tcp --permanent >/dev/null 2>&1
            firewall-cmd --zone=public --add-port=${port}/udp --permanent >/dev/null 2>&1
            firewall-cmd --reload >/dev/null 2>&1
            echo "=== 已通过 Firewalld 放行端口 ${port} ==="
        fi
    fi
}

# 执行架构检查与健壮的依赖安装
check_architecture
install_deps_with_robustness

# 检查 OpenVPN 是否已安装
check_openvpn_installed() {
    if [ -d "/etc/openvpn/server" ] || [ -f "/etc/systemd/system/openvpn-server@server.service" ]; then
        return 0
    else
        return 1
    fi
}

# ----------------- OpenVPN 管理函数（安装, 新增, 卸载一体化） -----------------
do_openvpn_manager() {
    if ! check_openvpn_installed; then
        echo "=== 检测到未安装 OpenVPN，正在引导首次安装 ==="
        wget -O openvpn-install.sh https://git.io/vpn
        chmod +x openvpn-install.sh

        # 调用原版交互安装
        bash openvpn-install.sh

        # 默认 OpenVPN 常用端口一般为 1194，尝试自动放行防火墙
        auto_open_firewall_port 1194

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
    echo -e "${YELLOW}💡 提示：如果安装成功后无法连接，请注意检查云服务商后台的“安全组”及本地防火墙是否放行了对应端口。${NC}"
}

do_install_frp() {
    echo "=== 正在启动 FRP 一键安装脚本 ==="
    bash <(wget -qO- https://raw.githubusercontent.com/pinode1314/frp-script/main/frp.sh)
    echo -e "${YELLOW}💡 提示：请确保云服务器安全组已放行 FRP 客户端与服务端的通信端口。${NC}"
}

do_install_rinetd() {
    echo "=== 正在启动 Rinetd 一键脚本 ==="
    bash <(wget -qO- https://raw.githubusercontent.com/pinode1314/Rinetd/main/rinetd.sh)
}

do_install_softether() {
    echo "=== 正在启动 SoftEther 一键脚本 ==="
    bash <(wget -qO- https://raw.githubusercontent.com/pinode1314/SoftEther/main/SoftEther.sh)
    auto_open_firewall_port 443
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
