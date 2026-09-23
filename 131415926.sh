#!/bin/bash

export LANG=en_US.UTF-8

# 确保以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    printf "❌ 请使用 root 权限运行此脚本！(例如: sudo bash menu.sh)\n"
    exit 1
fi

# 更加精确的智能依赖检测：完全静默且不重复触发
# 将自动安装的依赖全部标记为手动安装 (apt-mark manual)，防止其他脚本执行 autoremove 时误删依赖
if [ -x "$(command -v apt)" ]; then
    export DEBIAN_FRONTEND=noninteractive
    apt_deps=(
        curl wget procps qrencode openssl socat cron iptables iptables-persistent 
        netfilter-persistent build-essential gcc g++ make tar pkg-config autoconf 
        automake zlib1g-dev libssl-dev jq expect python3 git iproute2 iputils-ping 
        net-tools xxd
    )
    missing_apt_deps=()
    for pkg in "${apt_deps[@]}"; do
        # 使用 dpkg -s 检查，只有真正未安装时才加入队列
        if ! dpkg -s "$pkg" &>/dev/null; then
            missing_apt_deps+=("$pkg")
        fi
    done
    if [ ${#missing_apt_deps[@]} -gt 0 ]; then
        echo "=== 正在检测系统环境并自动安装缺失的必要依赖 ==="
        apt-get update -y
        # 使用 --no-install-recommends 保持环境干净，避免引入多余软依赖
        apt-get install -y --no-install-recommends "${missing_apt_deps[@]}"
        # 将所有补齐的依赖明确标记为“手动安装”，防止后续被 autoremove 误清理
        apt-mark manual "${apt_deps[@]}" &>/dev/null
        echo "=== 系统依赖安装完成 ==="
    fi
elif [ -x "$(command -v dnf)" ]; then
    dnf_deps=(
        curl wget procps qrencode openssl socat cronie iptables iptables-services 
        gcc g++ make tar pkgconfig autoconf automake zlib-devel openssl-devel 
        jq expect python3 git iproute2 iputils net-tools vim-common
    )
    missing_dnf_deps=()
    for pkg in "${dnf_deps[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            missing_dnf_deps+=("$pkg")
        fi
    done
    if [ ${#missing_dnf_deps[@]} -gt 0 ]; then
        echo "=== 正在检测系统环境并自动安装缺失的必要依赖 ==="
        dnf check-update -y &>/dev/null
        dnf install -y "${missing_dnf_deps[@]}"
        # 在 dnf 中将这些包标记为 userinstalled，防止被 autoremove 误卸载
        dnf mark install "${dnf_deps[@]}" &>/dev/null
        echo "=== 系统依赖安装完成 ==="
    fi
elif [ -x "$(command -v yum)" ]; then
    yum_deps=(
        curl wget procps qrencode openssl socat cronie iptables iptables-services 
        gcc g++ make tar pkgconfig autoconf automake zlib-devel openssl-devel 
        jq expect python3 git iproute2 iputils net-tools vim-common
    )
    missing_yum_deps=()
    for pkg in "${yum_deps[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            missing_yum_deps+=("$pkg")
        fi
    done
    if [ ${#missing_yum_deps[@]} -gt 0 ]; then
        echo "=== 正在检测系统环境并自动安装缺失的必要依赖 ==="
        yum check-update -y &>/dev/null
        yum install -y "${missing_yum_deps[@]}"
        # 如果系统中存在 yum-plugin-versionlock 或 yumdb，尝试保护手动安装标志
        if command -v yumdb &>/dev/null; then
            yumdb set reason user "${yum_deps[@]}" &>/dev/null
        fi
        echo "=== 系统依赖安装完成 ==="
    fi
else
    echo "⚠️ 未识别到支持的包管理器 (apt/dnf/yum)，跳过自动依赖安装，请确保已手动安装相关依赖。"
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
}

do_install_kejilion() {
    echo "=== 科技lion Linux服务器运维工具箱 ==="
    if command -v kejilion >/dev/null 2>&1; then
        kejilion
    else
        bash <(curl -sL kejilion.sh)
    fi
}

do_install_firewall() {
    echo "=== 正在启动防火墙管理脚本 ==="
    bash <(wget -qO- https://raw.githubusercontent.com/pinode1314/firewall/main/firewall.sh)
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
    echo " 7. 科技lion Linux服务器运维工具箱"
    echo " 8. 系统防火墙管理"
    echo " 0. 退出脚本"
    printf "${SKYBLUE}=========================================\n${NC}"
    read -p "请选择操作 [0-8]: " CHOICE

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
        8)
            do_install_firewall
            ;;
        0)
            echo "已安全退出脚本。"
            break
            ;;
        *)
            printf "${RED}❌ 无效的选项，请输入 0 到 8 之间的数字。\n${NC}"
            ;;
    esac
done
