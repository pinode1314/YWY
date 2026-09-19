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

# ----------------- 系统架构（CPU Architecture）校验 -----------------
check_architecture() {
    local ARCH=$(uname -m)
    echo "=== 当前系统架构: ${ARCH} ==="
    if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "aarch64" ] && [ "$ARCH" != "arm64" ]; then
        printf "${YELLOW}⚠️ 检测到您处于非主流架构 (${ARCH})，部分一键脚本可能无法正常运行二进制文件，请知悉。\n${NC}"
    fi
}

# ----------------- 前置依赖安装、锁清理与返回值强校验 -----------------
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

    if [ $? -eq 0 ]; then
        echo "=== 前置依赖检查与安装成功完成 ==="
        return 0
    else
        printf "${YELLOW}⚠️ 部分依赖安装可能未完全成功，建议检查上方报错日志。\n${NC}"
        return 1
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

        bash openvpn-install.sh

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

        bash openvpn-install.sh

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
    if [ -f /etc/s-box/sing-box ] && command -v sb >/dev/null 2>&1; then
        echo "=== 检测到 sing-box 已安装，正在打开管理菜单（可查看配置、卸载等） ==="
        sb
        return
    fi

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

# ==============================================================================
# ----------------- 🛡️ 多系统防火墙管理子模块（集成开始） -----------------
# ==============================================================================

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
            apt-get update -y && apt-get install -y ufw
            ufw allow 22/tcp >/dev/null 2>&1
            ufw allow 80/tcp >/dev/null 2>&1
            ufw allow 443/tcp >/dev/null 2>&1
            systemctl enable ufw --now
            printf "${GREEN}✔ UFW 防火墙安装完成，并已自动放行默认基础端口 (22, 80, 443)。\n${NC}"
            ;;
        firewalld)
            apt-get update -y && apt-get install -y firewalld 2>/dev/null || yum install -y firewalld
            systemctl enable firewalld --now
            firewall-cmd --permanent --zone=public --add-port=22/tcp >/dev/null 2>&1
            firewall-cmd --permanent --zone=public --add-port=80/tcp >/dev/null 2>&1
            firewall-cmd --permanent --zone=public --add-port=443/tcp >/dev/null 2>&1
            firewall-cmd --reload >/dev/null 2>&1
            printf "${GREEN}✔ Firewalld 防火墙安装完成，并已自动放行默认基础端口 (22, 80, 443)。\n${NC}"
            ;;
        iptables)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -y && apt-get install -y iptables iptables-persistent 2>/dev/null || yum install -y iptables iptables-services
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

    # 校验端口是否在 1-65535 范围内
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

# 防火墙子菜单入口函数
firewall_menu() {
    while true; do
        echo ""
        printf "${SKYBLUE}=========================================\n${NC}"
        printf "${SKYBLUE}       🛡️ 多系统防火墙管理子脚本 🛡️        \n${NC}"
        printf "${SKYBLUE}=========================================\n${NC}"
        echo " 1. 检测系统防火墙安装、状态与端口规则"
        echo " 2. 安装指定防火墙 (带冲突检测)"
        echo " 3. 智能开启 / 关闭防火墙服务"
        echo " 4. 放行指定端口或范围 (支持 TCP/UDP 选择)"
        echo " 5. 删除指定端口或范围规则 (支持 TCP/UDP 选择)"
        echo " 6. 完全卸载当前防火墙服务"
        echo " 0. 返回综合工具箱主菜单"
        printf "${SKYBLUE}=========================================\n${NC}"
        read -p "请选择操作 [0-6]: " FW_CHOICE

        case "$FW_CHOICE" in
            1) check_firewall_status ;;
            2) install_firewall ;;
            3) control_firewall ;;
            4) allow_port ;;
            5) delete_port ;;
            6) uninstall_firewall ;;
            0) echo "已退出防火墙子菜单，返回主菜单。"; break ;;
            *) printf "${RED}❌ 无效选项，请输入 0 到 6 之间的数字。\n${NC}" ;;
        esac
    done
}
# ==============================================================================
# ----------------- 🛡️ 多系统防火墙管理子模块（集成结束） -----------------
# ==============================================================================

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
    echo " 8. 系统防火墙管理 (UFW / Firewalld / Iptables)"
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
            firewall_menu
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
