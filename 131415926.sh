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
        echo "=== 系统依赖安装与保护标记完成 ==="
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
        echo "=== 系统依赖安装与保护标记完成 ==="
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
        echo "=== 系统依赖安装与保护标记完成 ==="
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

# ------------------------------------------------------------------
# ----------------- 第 8 项：系统防火墙管理子系统 -------------------
# ------------------------------------------------------------------
get_distro_and_fw() {
    hash -r 2>/dev/null

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        OS="unknown"
    fi

    if [ -x /usr/sbin/ufw ] || [ -x /sbin/ufw ]; then
        FW_TYPE="ufw"
        return
    fi

    if [ -x /usr/bin/firewall-cmd ] || [ -x /sbin/firewall-cmd ]; then
        FW_TYPE="firewalld"
        return
    fi

    if [ -x /usr/sbin/iptables ] || [ -x /sbin/iptables ]; then
        if [ -n "$(iptables -L INPUT -n 2>/dev/null)" ] || dpkg -l | grep -q iptables-persistent 2>/dev/null || rpm -q iptables-services &>/dev/null; then
            FW_TYPE="iptables"
            return
        fi
    fi

    FW_TYPE="none"
}

check_firewall_status() {
    get_distro_and_fw
    
    echo "=================================================="
    echo "=== 正在检测当前系统的防火墙状态与规则 ==="
    echo "系统类型: $OS | 当前防火墙: $FW_TYPE"
    echo "=================================================="

    case "$FW_TYPE" in
        ufw)
            if [ -x /usr/sbin/ufw ] || [ -x /sbin/ufw ]; then
                printf "${GREEN}✔ UFW 防火墙已安装\n${NC}"
                ufw status numbered | sed \
                    -e 's/Status: inactive/防火墙状态: 未激活 (已关闭)/g' \
                    -e 's/Status: active/防火墙状态: 已激活 (运行中)/g' \
                    -e 's/to/目标/g' \
                    -e 's/from/来自/g' \
                    -e 's/Anywhere/任何来源/g' \
                    -e 's/ALLOW/允许/g' \
                    -e 's/DENY/拒绝/g'
            else
                FW_TYPE="none"
                printf "${YELLOW}⚠️ 当前系统中未检测到任何可用的主流防火墙（已安全卸载或未安装）\n${NC}"
            fi
            ;;
        firewalld)
            if [ -x /usr/bin/firewall-cmd ] || [ -x /sbin/firewall-cmd ]; then
                printf "${GREEN}✔ Firewalld 防火墙已安装\n${NC}"
                systemctl status firewalld --no-pager
                echo "--- 已放行端口 ---"
                firewall-cmd --zone=public --list-ports 2>/dev/null
            else
                FW_TYPE="none"
                printf "${YELLOW}⚠️ 当前系统中未检测到任何可用的主流防火墙（已安全卸载或未安装）\n${NC}"
            fi
            ;;
        iptables)
            printf "${GREEN}✔ Iptables 防火墙已安装\n${NC}"
            iptables -L INPUT -n -v --line-numbers
            ;;
        none|*)
            printf "${YELLOW}⚠️ 当前系统中未检测到任何可用的主流防火墙（已安全卸载或未安装）\n${NC}"
            ;;
    esac
}

install_firewall() {
    get_distro_and_fw
    echo "请选择你要安装的防火墙类型："
    echo " 1. UFW (适用于 Ubuntu/Debian)"
    echo " 2. Firewalld (适用于 CentOS/RHEL/Fedora)"
    echo " 3. Iptables"
    echo " 0. 返回上一级菜单"
    read -p "请选择 [0-3]: " install_choice

    case "$install_choice" in
        1) TARGET_FW="ufw" ;;
        2) TARGET_FW="firewalld" ;;
        3) TARGET_FW="iptables" ;;
        0) echo "已取消安装，返回上一级菜单。"; return ;;
        *) printf "${RED}❌ 无效的选择。\n${NC}"; return ;;
    esac

    if [ "$FW_TYPE" != "none" ]; then
        if [ "$FW_TYPE" == "$TARGET_FW" ]; then
            printf "${YELLOW}⚠️ 检测到当前系统【已经安装】了 $TARGET_FW 防火墙，无需重复安装！\n${NC}"
            return
        else
            printf "${RED}❌ 检测到当前系统已存在 [$FW_TYPE] 防火墙。为避免冲突，请先通过第 6 项将其卸载，再安装新防火墙！\n${NC}"
            return
        fi
    fi

    echo "=== 正在开始安装 $TARGET_FW 防火墙 ==="
    case "$TARGET_FW" in
        ufw)
            export DEBIAN_FRONTEND=noninteractive
            apt-get install -y ufw
            ufw allow 22/tcp >/dev/null 2>&1
            ufw allow 80/tcp >/dev/null 2>&1
            ufw allow 443/tcp >/dev/null 2>&1
            systemctl enable ufw --now
            printf "${GREEN}✔ UFW 防火墙安装完成，并已自动放行默认基础端口 (22, 80, 443)。\n${NC}"
            ;;
        firewalld)
            apt-get install -y firewalld 2>/dev/null || yum install -y firewalld
            systemctl enable firewalld --now
            firewall-cmd --permanent --zone=public --add-port=22/tcp >/dev/null 2>&1
            firewall-cmd --permanent --zone=public --add-port=80/tcp >/dev/null 2>&1
            firewall-cmd --permanent --zone=public --add-port=443/tcp >/dev/null 2>&1
            firewall-cmd --reload >/dev/null 2>&1
            printf "${GREEN}✔ Firewalld 防火墙安装完成，并已自动放行默认基础端口 (22, 80, 443)。\n${NC}"
            ;;
        iptables)
            export DEBIAN_FRONTEND=noninteractive
            apt-get install -y iptables iptables-persistent 2>/dev/null || yum install -y iptables iptables-services
            iptables -A INPUT -p tcp --dport 22 -j ACCEPT
            iptables -A INPUT -p tcp --dport 80 -j ACCEPT
            iptables -A INPUT -p tcp --dport 443 -j ACCEPT
            if command -v netfilter-persistent &>/dev/null; then
                netfilter-persistent save >/dev/null 2>&1
            elif [ -d /etc/sysconfig ]; then
                iptables-save > /etc/sysconfig/iptables 2>/dev/null
            fi
            printf "${GREEN}✔ Iptables 安装完成，并已自动放行默认基础端口 (22, 80, 443)。\n${NC}"
            ;;
    esac
    hash -r 2>/dev/null
}

control_firewall() {
    get_distro_and_fw
    if [ "$FW_TYPE" == "none" ]; then
        printf "${RED}❌ 当前系统未检测到防火墙，请先通过第 2 项进行安装！\n${NC}"
        return
    fi

    case "$FW_TYPE" in
        ufw)
            if ufw status | grep -q "Status: active"; then
                read -p "防火墙运行中，是否将其【关闭】？[y/n]: " choice
                if [ "$choice" = "y" ]; then
                    ufw disable >/dev/null 2>&1
                    printf "${YELLOW}⚠️ 防火墙已关闭\n${NC}"
                fi
            else
                read -p "防火墙已关闭，是否将其【开启】？[y/n]: " choice
                if [ "$choice" = "y" ]; then
                    ufw allow 22/tcp >/dev/null 2>&1
                    ufw allow 80/tcp >/dev/null 2>&1
                    ufw allow 443/tcp >/dev/null 2>&1
                    ufw --force enable >/dev/null 2>&1
                    printf "${GREEN}✔ 防火墙已开启，并已自动安全放行默认基础端口 (22, 80, 443)\n${NC}"
                fi
            fi
            ;;
        firewalld)
            if systemctl is-active --quiet firewalld; then
                read -p "防火墙运行中，是否将其【关闭】？[y/n]: " choice
                if [ "$choice" = "y" ]; then
                    systemctl stop firewalld >/dev/null 2>&1
                    systemctl disable firewalld >/dev/null 2>&1
                    printf "${YELLOW}⚠️ 防火墙已关闭\n${NC}"
                fi
            else
                read -p "防火墙已关闭，是否将其【开启】？[y/n]: " choice
                if [ "$choice" = "y" ]; then
                    firewall-cmd --permanent --zone=public --add-port=22/tcp >/dev/null 2>&1
                    firewall-cmd --permanent --zone=public --add-port=80/tcp >/dev/null 2>&1
                    firewall-cmd --permanent --zone=public --add-port=443/tcp >/dev/null 2>&1
                    systemctl enable --now firewalld >/dev/null 2>&1
                    firewall-cmd --reload >/dev/null 2>&1
                    printf "${GREEN}✔ 防火墙已开启，并已自动安全放行默认基础端口 (22, 80, 443)\n${NC}"
                fi
            fi
            ;;
        iptables)
            RULE_COUNT=$(iptables -S INPUT 2>/dev/null | grep -v -- "-P INPUT ACCEPT" | wc -l)
            
            if [ "$RULE_COUNT" -gt 0 ]; then
                read -p "防火墙运行中，是否将其【关闭】？[y/n]: " choice
                if [ "$choice" = "y" ]; then
                    iptables -F
                    printf "${YELLOW}⚠️ 防火墙已关闭\n${NC}"
                fi
            else
                read -p "防火墙已关闭，是否将其【开启】？[y/n]: " choice
                if [ "$choice" = "y" ]; then
                    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
                    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
                    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
                    printf "${GREEN}✔ 防火墙已开启，并已自动安全放行默认基础端口 (22, 80, 443)\n${NC}"
                fi
            fi
            ;;
        *)
            printf "${RED}❌ 未知的防火墙类型。\n${NC}"
            ;;
    esac
}

allow_port() {
    get_distro_and_fw
    if [ "$FW_TYPE" == "none" ]; then
        printf "${RED}❌ 当前系统无防火墙，无法放行端口！\n${NC}"
        return
    fi

    read -p "请输入要放行的端口或范围 (例如 80 或 8000-8009): " PORT
    if [ -z "$PORT" ]; then
        printf "${RED}❌ 端口不能为空！\n${NC}"
        return
    fi

    if [[ "$PORT" =~ ^[0-9]+-[0-9]+$ ]]; then
        P_START=$(echo "$PORT" | cut -d'-' -f1)
        P_END=$(echo "$PORT" | cut -d'-' -f2)
        if [ "$P_START" -lt 1 ] || [ "$P_START" -gt 65535 ] || [ "$P_END" -lt 1 ] || [ "$P_END" -gt 65535 ] || [ "$P_START" -gt "$P_END" ]; then
            printf "${RED}❌ 错误：端口范围必须在 1 到 65535 之间，且起始端口不能大于结束端口！\n${NC}"
            return
        fi
    elif [[ "$PORT" =~ ^[0-9]+$ ]]; then
        if [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
            printf "${RED}❌ 错误：端口号必须在 1 到 65535 之间！\n${NC}"
            return
        fi
    else
        printf "${RED}❌ 错误：输入的端口格式无效！\n${NC}"
        return
    fi

    echo "请选择协议类型："
    echo " 1. TCP"
    echo " 2. UDP"
    echo " 3. TCP 和 UDP 同时放行"
    read -p "请选择 [1-3]: " proto_choice

    case "$proto_choice" in
        1) PROTO="tcp" ;;
        2) PROTO="udp" ;;
        3) PROTO="both" ;;
        *) printf "${RED}❌ 无效的选择，默认采用 TCP。\n${NC}"; PROTO="tcp" ;;
    esac

    if [ "$FW_TYPE" == "ufw" ] && ([ -x /usr/sbin/ufw ] || [ -x /sbin/ufw ]); then
        UFW_PORT=$(echo "$PORT" | tr '-' ':')
        if [ "$PROTO" == "both" ]; then
            ufw allow "$UFW_PORT"/tcp
            ufw allow "$UFW_PORT"/udp
            printf "${GREEN}✔ 端口 ${PORT} (TCP与UDP) 已成功放行！\n${NC}"
        else
            ufw allow "$UFW_PORT"/"$PROTO"
            printf "${GREEN}✔ 端口 ${PORT} (${PROTO^^}) 已成功放行！\n${NC}"
        fi
    elif [ "$FW_TYPE" == "firewalld" ]; then
        if [ "$PROTO" == "both" ]; then
            firewall-cmd --permanent --zone=public --add-port="$PORT"/tcp >/dev/null 2>&1
            firewall-cmd --permanent --zone=public --add-port="$PORT"/udp >/dev/null 2>&1
            firewall-cmd --reload >/dev/null 2>&1
            printf "${GREEN}✔ 端口 ${PORT} (TCP与UDP) 已成功放行！\n${NC}"
        else
            firewall-cmd --permanent --zone=public --add-port="$PORT"/"$PROTO" >/dev/null 2>&1
            firewall-cmd --reload >/dev/null 2>&1
            printf "${GREEN}✔ 端口 ${PORT} (${PROTO^^}) 已成功放行！\n${NC}"
        fi
    elif [ "$FW_TYPE" == "iptables" ]; then
        if [ "$PROTO" == "both" ]; then
            iptables -A INPUT -p tcp --dport "$PORT" -j ACCEPT
            iptables -A INPUT -p udp --dport "$PORT" -j ACCEPT
            printf "${GREEN}✔ 端口 ${PORT} (TCP与UDP) 已成功放行！\n${NC}"
        else
            iptables -A INPUT -p "$PROTO" --dport "$PORT" -j ACCEPT
            printf "${GREEN}✔ 端口 ${PORT} (${PROTO^^}) 已成功放行！\n${NC}"
        fi
    fi
}

delete_port() {
    get_distro_and_fw
    if [ "$FW_TYPE" == "none" ]; then
        printf "${RED}❌ 当前系统无防火墙！\n${NC}"
        return
    fi

    read -p "请输入要删除的端口或范围: " PORT
    if [ -z "$PORT" ]; then
        printf "${RED}❌ 端口不能为空！\n${NC}"
        return
    fi

    echo "请选择要删除的协议类型："
    echo " 1. TCP"
    echo " 2. UDP"
    echo " 3. TCP 和 UDP 都删除"
    read -p "请选择 [1-3]: " proto_choice

    case "$proto_choice" in
        1) PROTO="tcp" ;;
        2) PROTO="udp" ;;
        3) PROTO="both" ;;
        *) printf "${RED}❌ 无效的选择，默认操作 TCP。\n${NC}"; PROTO="tcp" ;;
    esac

    if [ "$FW_TYPE" == "ufw" ] && ([ -x /usr/sbin/ufw ] || [ -x /sbin/ufw ]); then
        UFW_PORT=$(echo "$PORT" | tr '-' ':')
        if [ "$PROTO" == "both" ]; then
            ufw delete allow "$UFW_PORT"/tcp >/dev/null 2>&1
            ufw delete allow "$UFW_PORT"/udp >/dev/null 2>&1
            printf "${GREEN}✔ 端口 ${PORT} (TCP与UDP) 规则已移除。\n${NC}"
        else
            ufw delete allow "$UFW_PORT"/"$PROTO" >/dev/null 2>&1
            printf "${GREEN}✔ 端口 ${PORT} (${PROTO^^}) 规则已移除。\n${NC}"
        fi
    elif [ "$FW_TYPE" == "firewalld" ]; then
        if [ "$PROTO" == "both" ]; then
            firewall-cmd --permanent --zone=public --remove-port="$PORT"/tcp >/dev/null 2>&1
            firewall-cmd --permanent --zone=public --remove-port="$PORT"/udp >/dev/null 2>&1
            firewall-cmd --reload >/dev/null 2>&1
            printf "${GREEN}✔ 端口 ${PORT} (TCP与UDP) 规则已移除。\n${NC}"
        else
            firewall-cmd --permanent --zone=public --remove-port="$PORT"/"$PROTO" >/dev/null 2>&1
            firewall-cmd --reload >/dev/null 2>&1
            printf "${GREEN}✔ 端口 ${PORT} (${PROTO^^}) 规则已移除。\n${NC}"
        fi
    elif [ "$FW_TYPE" == "iptables" ]; then
        if [ "$PROTO" == "both" ]; then
            iptables -D INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null
            iptables -D INPUT -p udp --dport "$PORT" -j ACCEPT 2>/dev/null
            printf "${GREEN}✔ 端口 ${PORT} (TCP与UDP) 规则已移除。\n${NC}"
        else
            iptables -D INPUT -p "$PROTO" --dport "$PORT" -j ACCEPT 2>/dev/null
            printf "${GREEN}✔ 端口 ${PORT} (${PROTO^^}) 规则已移除。\n${NC}"
        fi
    fi
}

uninstall_firewall() {
    get_distro_and_fw
    echo "=================================================="
    echo "=== 正在准备卸载防火墙 ==="
    echo "当前识别的防火墙类型: $FW_TYPE"
    echo "=================================================="

    if [ "$FW_TYPE" == "none" ]; then
        printf "${YELLOW}⚠️ 系统中当前没有安装任何可卸载的防火墙。\n${NC}"
        return
    fi

    read -p "⚠️ 确认要彻底卸载防火墙并清空规则吗？[y/N]: " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "操作已取消。"
        return
    fi

    case "$FW_TYPE" in
        ufw)
            ufw disable >/dev/null 2>&1
            export DEBIAN_FRONTEND=noninteractive
            apt-get purge -y ufw >/dev/null 2>&1
            apt-get autoremove -y >/dev/null 2>&1
            rm -f /usr/sbin/ufw /sbin/ufw
            rm -rf /etc/ufw /lib/ufw /etc/default/ufw
            printf "${GREEN}✔ UFW 防火墙已被完全卸载并深度清理残留！\n${NC}"
            ;;
        firewalld)
            systemctl disable --now firewalld >/dev/null 2>&1
            apt-get purge -y firewalld >/dev/null 2>&1 || yum remove -y firewalld >/dev/null 2>&1
            rm -rf /etc/firewalld
            printf "${GREEN}✔ Firewalld 防火墙已被完全卸载！\n${NC}"
            ;;
        iptables)
            iptables -F
            export DEBIAN_FRONTEND=noninteractive
            apt-get purge -y iptables iptables-persistent >/dev/null 2>&1 || yum remove -y iptables iptables-services >/dev/null 2>&1
            printf "${GREEN}✔ Iptables 已卸载！\n${NC}"
            ;;
    esac
    
    hash -r 2>/dev/null
    get_distro_and_fw
    echo "当前最新状态已重置为: $FW_TYPE"
}

do_firewall_manager() {
    while true; do
        echo ""
        printf "${SKYBLUE}=========================================\n${NC}"
        printf "${SKYBLUE}        🛡️ 多系统防火墙管理子菜单 🛡️         \n${NC}"
        printf "${SKYBLUE}=========================================\n${NC}"
        echo " 1. 检测系统防火墙安装、状态与端口规则"
        echo " 2. 安装指定防火墙 (带冲突检测)"
        echo " 3. 智能开启 / 关闭防火墙服务"
        echo " 4. 放行指定端口或范围 (支持 TCP/UDP 选择)"
        echo " 5. 删除指定端口或范围规则 (支持 TCP/UDP 选择)"
        echo " 6. 完全卸载当前防火墙服务"
        echo " 0. 返回大脚本主菜单"
        printf "${SKYBLUE}=========================================\n${NC}"
        read -p "请选择操作 [0-6]: " fw_choice

        case "$fw_choice" in
            1) check_firewall_status ;;
            2) install_firewall ;;
            3) control_firewall ;;
            4) allow_port ;;
            5) delete_port ;;
            6) uninstall_firewall ;;
            0) echo "已退出防火墙管理子菜单，返回主菜单。"; break ;;
            *) printf "${RED}❌ 无效选项，请输入 0 到 6 之间的数字。\n${NC}" ;;
        esac
    done
}

# ----------------- 主菜单循环 -----------------
while true; do
    echo ""
    printf "${SKYBLUE}=========================================\n${NC}"
    printf "${SKYBLUE}     ⚡ 【夜未央】 脚本工具箱 ⚡         \n${NC}"
    printf "${SKYBLUE}=========================================\n${NC}"
    echo " 1. 安装 OpenVPN 服务端与客户端管理"
    echo " 2. 安装 Hysteria 2"
    echo " 3. 安装 FRP 端口映射"
    echo " 4. 安装 Rinetd TCP端口映射"
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
            do_firewall_manager
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
