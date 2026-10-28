#!/bin/bash
# Issues https://clun.top
# bash <(curl -sL clun.top)
# set -euo pipefail

version="1.2.11"
version_test="285"

# ==================== 颜色定义 ====================
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m' 
GRAY='\033[90m'
WHITE='\033[97m'
RESET='\033[0m'

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误：此脚本需要 root 权限运行${RESET}"
    echo "请使用: sudo bash $0"
    exit 1
fi

# ==================== 日志辅助函数 ====================
info() { echo -e "${GREEN}[信息]${RESET} $*"; }
warn() { echo -e "${YELLOW}[警告]${RESET} $*"; }
skip() { echo -e "${GRAY}[跳过]${RESET} $*"; }

# ==================== 系统检测 ====================
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    OS_VERSION=$VERSION_ID
    OS_NAME=$PRETTY_NAME
elif [ -f /etc/redhat-release ]; then
    OS="rhel"
    OS_NAME=$(cat /etc/redhat-release)
else
    OS="unknown"
fi

# 虚拟化检测
IS_VIRTUALIZED=0
if command -v systemd-detect-virt >/dev/null 2>&1; then
    _virt=$(systemd-detect-virt 2>/dev/null)
    [ -n "$_virt" ] && [ "$_virt" != "none" ] && IS_VIRTUALIZED=1
fi

# ==================== 包管理器配置 ====================
case "$OS" in
    ubuntu|debian|linuxmint|pop)
        PKG_INSTALL="apt-get install -y"
        PKG_UPDATE="apt-get update"
        ;;
    centos|rhel|rocky|almalinux|fedora)
        if command -v dnf &> /dev/null; then
            PKG_INSTALL="dnf install -y"
        else
            PKG_INSTALL="yum install -y"
        fi
        ;;
    arch|manjaro)
        PKG_INSTALL="pacman -S --noconfirm"
        ;;
    alpine)
        PKG_INSTALL="apk add"
        ;;
    *)
        PKG_INSTALL="echo 'Unknown package manager'"
        ;;
esac

# ==================== 依赖检查 ====================
for cmd in curl wget ethtool ip awk sysctl; do
    if ! command -v "$cmd" &> /dev/null; then
        warn "缺少命令: $cmd，尝试安装..."
        $PKG_INSTALL "$cmd" 2>/dev/null || true
    fi
done

# ==================== 网络接口检测 ====================
nic=$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')
[[ -z "$nic" ]] && nic=$(ip link show | awk -F': ' '/^[0-9]+: / {print $2}' | grep -v -E '^(lo|docker|virbr|veth|br-|tun|wg)' | head -n1)

# ==================== 文件路径配置 ====================
backup_bak="/etc/sysctl.conf.bak"
tmp_new="/tmp/sysctl.new"
sysctl_conf="/etc/sysctl.conf"
sysctl_url="https://raw.githubusercontent.com/cluntop/sh/main/conf.d/sysctl.conf"

# ==================== 脚本别名安装 ====================
sed -i '/^alias tcp=/d' ~/.bashrc > /dev/null 2>&1
sed -i '/^alias tcp=/d' ~/.profile > /dev/null 2>&1
sed -i '/^alias tcp=/d' ~/.bash_profile > /dev/null 2>&1

if [[ -f "$0" && "$0" != /bin/bash && "$0" != /bin/sh && "$0" != /usr/bin/bash ]]; then
    cp -f "$0" ~/clun_tcp.sh >/dev/null 2>&1
    cp -f ~/clun_tcp.sh /usr/local/bin/tcp >/dev/null 2>&1
    chmod +x /usr/local/bin/tcp >/dev/null 2>&1
fi

# ==================== 网络路由信息 ====================
GW=$(ip route show default | awk '/default/ {print $3; exit}')
DEV=$(ip route show default | awk '/default/ {print $5; exit}')

# ==================== systemd-journald 优化 ====================
systemd_journald_optimize() {

    local CONF_FILE="/etc/systemd/journald.conf"

    while true; do
        clear
        echo "========================================"
        echo "      systemd-journald 优化子菜单"
        echo "========================================"
        echo "  1 - 不记录模式 (无日志)"
        echo "  2 - 经常用模式 (持久化, 1GB 限制)"
        echo "  3 - 低延迟模式 (内存存储, 不压缩)"
        echo "  4 - 低延迟模式 (内存存储, 开启压缩)"
        echo "----------------------------------------"
        echo "  0 - 返回上一级菜单"
        echo "========================================"

        read -e -p "请输入 [0-4]: " MODE

        if [[ "$MODE" == "0" ]]; then
            return 0
        fi

        if [[ ! "$MODE" =~ ^[1-4]$ ]]; then
            echo "无效输入，请重新选择！"
            sleep 1
            continue
        fi

        local BACKUP_FILE="${CONF_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$CONF_FILE" "$BACKUP_FILE"
        echo "已备份原配置至 $BACKUP_FILE"

        cat <<EOF > "$CONF_FILE"
[Journal]
EOF

        case $MODE in
          1)
            echo "正在应用: 模式 1 (不记录)"
            cat <<EOF >> "$CONF_FILE"
Storage=none
ForwardToSyslog=no
ForwardToKMsg=no
ForwardToConsole=no
ForwardToWall=no
EOF
            ;;
          2)
            echo "正在应用: 模式 2 (经常用)"
            cat <<EOF >> "$CONF_FILE"
Storage=persistent
Compress=yes
SystemMaxUse=1G
SystemKeepFree=2G
SystemMaxFileSize=100M
MaxRetentionSec=1month
SyncIntervalSec=5m
RateLimitIntervalSec=30s
RateLimitBurst=10000
EOF
            ;;
          3)
            echo "正在应用: 模式 3 (低延迟 不压缩)"
            cat <<EOF >> "$CONF_FILE"
Storage=persistent
Compress=no
RuntimeMaxUse=256M
RuntimeKeepFree=64M
RuntimeMaxFileSize=32M
SyncIntervalSec=0
ForwardToSyslog=no
ForwardToKMsg=no
ForwardToConsole=no
EOF
            ;;
          4)
            echo "正在应用: 模式 4 (低延迟 压缩)"
            cat <<EOF >> "$CONF_FILE"
Storage=persistent
SystemMaxUse=256M
RuntimeMaxUse=48M
SystemKeepFree=1G
MaxRetentionSec=2d
MaxFileSec=12h
Compress=yes
ForwardToSyslog=no
RateLimitIntervalSec=1s
RateLimitBurst=30
EOF
            ;;
        esac

        systemctl restart systemd-journald
        echo "----------------------------------------"
        echo "配置已生效，systemd-journald 已重启。"
        echo "按任意键返回子菜单..."
        read -n 1
    done

}

# ==================== 通用函数 ====================
break_end() {
    echo "按任意键继续..."
    read -n 1 -s -r -p ""
    echo ""
    clear
}

# ==================== 脚本更新函数 ====================
update_script() {
    echo "正在检查并下载最新版本..."
    curl -sf https://raw.githubusercontent.com/cluntop/sh/main/tcp.sh -o /tmp/clun_tcp.sh

    if [ ! -s /tmp/clun_tcp.sh ]; then
        echo "下载失败，请检查网络连接"
        return 1
    fi

    chmod +x /tmp/clun_tcp.sh
    cp -f /tmp/clun_tcp.sh /usr/local/bin/tcp
    cp -f /tmp/clun_tcp.sh ~/clun_tcp.sh

    echo "更新完成，正在启动新版本..."
    exec /usr/local/bin/tcp
}

# ==================== 系统限制优化 ====================
Install_limits() {
cat >> /etc/security/limits.conf <<EOF
root hard memlock unlimited
root soft memlock unlimited
root hard nproc 1048576
root hard nofile 1048576
root soft nproc 1048576
root soft nofile 1048576

* hard memlock unlimited
* soft memlock unlimited
* hard nproc 1048576
* hard nofile 1048576
* soft nproc 1048576
* soft nofile 1048576

root hard core 0
root soft core 0

* hard core 0
* soft core 0
EOF

    if [ -f /etc/pam.d/common-session ]; then
        if ! grep -q "pam_limits.so" /etc/pam.d/common-session; then
            echo "session required pam_limits.so" >> /etc/pam.d/common-session
        fi
    fi
    if [ -f /etc/pam.d/common-session-noninteractive ]; then
        if ! grep -q "pam_limits.so" /etc/pam.d/common-session-noninteractive; then
            echo "session required pam_limits.so" >> /etc/pam.d/common-session-noninteractive
        fi
    fi
    info "limits.conf 已配置"
}

# ==================== 系统服务优化 ====================
Install_systemd() {
    if [[ -f /sys/kernel/mm/transparent_hugepage/enabled ]]; then
        echo never >/sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
        echo never >/sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true
        echo 0 > /sys/kernel/mm/transparent_hugepage/khugepaged/defrag 2>/dev/null || true
    fi

    if [[ "$IS_VIRTUALIZED" -eq 0 ]]; then
        if [[ -f /sys/devices/system/cpu/cpufreq/scaling_governor ]]; then
            echo performance | tee /sys/devices/system/cpu/cpufreq/scaling_governor >/dev/null 2>&1 || true
        fi
        if [[ -f /sys/devices/system/cpu/cpufreq/boost ]]; then
            echo 1 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true
        fi
        if [[ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]]; then
            echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || true
        fi
        cpupower idle-set -D 1 &>/dev/null || true
    fi

    if [[ "$IS_VIRTUALIZED" -eq 0 ]]; then
        if systemctl is-active --quiet irqbalance 2>/dev/null; then
            warn "物理机检测到 irqbalance 运行中。若已手动绑核，请自行停止。"
        fi
    fi

    for disk in $(lsblk -d -o NAME,TYPE 2>/dev/null | awk '$2=="disk"{print $1}'); do
        SCH_FILE="/sys/block/${disk}/queue/scheduler"
        [[ -f "$SCH_FILE" ]] || continue
        ROTATIONAL=$(cat /sys/block/${disk}/queue/rotational 2>/dev/null || echo 1)
        if [[ "$ROTATIONAL" == "0" ]]; then
            if grep -q "\[none\]" "$SCH_FILE" 2>/dev/null; then
                echo none > "$SCH_FILE" 2>/dev/null || true
                echo 0 > /sys/block/${disk}/queue/read_ahead_kb 2>/dev/null || true
            elif grep -q "mq-deadline" "$SCH_FILE" 2>/dev/null; then
                echo mq-deadline > "$SCH_FILE" 2>/dev/null || true
            fi
            echo 2 > /sys/block/${disk}/queue/nomerges 2>/dev/null || true
        fi
        echo 64 > /sys/block/${disk}/queue/nr_requests 2>/dev/null || true
    done

    modprobe nf_conntrack 2>/dev/null || true

    if command -v prlimit &>/dev/null; then
        ss -anptl 2>/dev/null | grep -oP 'pid=\K[0-9]+' | sort -u | while read -r pid; do
            prlimit --pid "$pid" --nofile=1048576 2>/dev/null || true
        done
    fi

  sudo rmmod authencesn 2>/dev/null
  sudo rmmod algif_aead 2>/dev/null
}

# Fallback helper if updateSysctlParam is not defined in external scope
if ! declare -F updateSysctlParam >/dev/null 2>&1; then
    updateSysctlParam() {
        local paramName="$1"
        local paramValue="$2"
        sysctl -w "${paramName}=${paramValue}" >/dev/null 2>&1 || true
    }
fi

# ==================== 内存参数计算与应用 ====================
# 获取有效内存（MiB）：min(/proc/meminfo MemTotal, cgroup 限制)，兜底 1024MiB
# 优先级：cgroup 限制（容器/VM 配额） > MemTotal（系统可见内存） > 1024MiB 安全兜底
get_effective_mem_mb() {
    local memtotal_kb cg_bytes cg_kb effective_kb

    # 基础值：/proc/meminfo MemTotal（比 free -m 更底层、格式更稳定）
    memtotal_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null)
    [[ "$memtotal_kb" =~ ^[0-9]+$ ]] && [[ "$memtotal_kb" -gt 0 ]] || memtotal_kb=$((1024 * 1024))
    effective_kb=$memtotal_kb

    # cgroup v2：若限制小于 MemTotal，则以 cgroup 为准
    if [[ -r /sys/fs/cgroup/memory.max ]]; then
        cg_bytes=$(cat /sys/fs/cgroup/memory.max 2>/dev/null)
        if [[ "$cg_bytes" =~ ^[0-9]+$ ]]; then
            cg_kb=$((cg_bytes / 1024))
            [[ "$cg_kb" -gt 0 && "$cg_kb" -lt "$effective_kb" ]] && effective_kb=$cg_kb
        fi
    fi

    # cgroup v1：无限制时值为接近 2^63，需过滤
    if [[ -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]]; then
        cg_bytes=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null)
        if [[ "$cg_bytes" =~ ^[0-9]+$ ]] && [[ "$cg_bytes" -lt $((1 << 60)) ]]; then
            cg_kb=$((cg_bytes / 1024))
            [[ "$cg_kb" -gt 0 && "$cg_kb" -lt "$effective_kb" ]] && effective_kb=$cg_kb
        fi
    fi

    echo $((effective_kb / 1024))
}

net_mem() {
    local sizeMb
    sizeMb=$(get_effective_mem_mb)
    [[ -z "$sizeMb" || "$sizeMb" -le 0 ]] && sizeMb=1024

    # ---- V6 风格可调参数 ----
    local TARGET_BDP_MB=64          # 你期望覆盖的最大带宽延迟积（MB）
    local BDP_MULTIPLIER=2          # 单连接上限 = BDP × 倍数
    local MEM_RATIO_PERCENT=30      # tcp_mem 全局池占物理内存百分比
    local SOCKET_HARD_CAP_MB=512    # 单连接缓冲区绝对硬顶（参考 V6 量级）

    local SOCKET_MAX_MB=$((TARGET_BDP_MB * BDP_MULTIPLIER))
    [[ $SOCKET_MAX_MB -gt $SOCKET_HARD_CAP_MB ]] && SOCKET_MAX_MB=$SOCKET_HARD_CAP_MB

    local page_size_kb=4
    local total_pages=$((sizeMb * 1024 / page_size_kb))

    # ---- 1. tcp_mem / udp_mem：内存比例封顶 + 不低于单连接上限的 4 倍 ----
    local tcpHigh=$((total_pages * MEM_RATIO_PERCENT / 100))
    local socket_max_pages=$((SOCKET_MAX_MB * 1024 * 1024 / (page_size_kb * 1024)))
    local floor_pages=$((socket_max_pages * 4))
    [[ $tcpHigh -lt $floor_pages ]] && tcpHigh=$floor_pages

    local tcpMid=$((tcpHigh * 60 / 100))
    local tcpLow=$((tcpHigh * 40 / 100))

    [[ $tcpLow  -lt 32768  ]] && tcpLow=32768
    [[ $tcpMid  -lt 65536  ]] && tcpMid=65536
    [[ $tcpHigh -lt 131072 ]] && tcpHigh=131072

    updateSysctlParam "net.ipv4.tcp_mem" "${tcpLow} ${tcpMid} ${tcpHigh}"
    updateSysctlParam "net.ipv4.udp_mem" "${tcpLow} ${tcpMid} ${tcpHigh}"

    # ---- 2. 单连接缓冲区：BDP 驱动，受全局池份额约束 ----
    local socket_max_bytes=$((SOCKET_MAX_MB * 1024 * 1024))
    local tcp_high_bytes=$((tcpHigh * page_size_kb * 1024))
    local quarter_pool=$((tcp_high_bytes / 4))
    [[ $socket_max_bytes -gt $quarter_pool ]] && socket_max_bytes=$quarter_pool
    [[ $socket_max_bytes -lt 16777216  ]] && socket_max_bytes=16777216
    [[ $socket_max_bytes -gt 536870912 ]] && socket_max_bytes=536870912

    local rmem_default=$((socket_max_bytes / 16))
    local wmem_default=$((socket_max_bytes / 32))
    [[ $rmem_default -lt 131072  ]] && rmem_default=131072
    [[ $wmem_default -lt 65536   ]] && wmem_default=65536
    [[ $rmem_default -gt 8388608 ]] && rmem_default=8388608
    [[ $wmem_default -gt 4194304 ]] && wmem_default=4194304

    updateSysctlParam "net.ipv4.tcp_rmem" "8192 ${rmem_default} ${socket_max_bytes}"
    updateSysctlParam "net.ipv4.tcp_wmem" "4096 ${wmem_default} ${socket_max_bytes}"
    updateSysctlParam "net.core.rmem_max" "${socket_max_bytes}"
    updateSysctlParam "net.core.wmem_max" "${socket_max_bytes}"
    updateSysctlParam "net.core.rmem_default" "${rmem_default}"
    updateSysctlParam "net.core.wmem_default" "${wmem_default}"

    # ---- 3. conntrack / TW / orphan：沿用高并发保底逻辑 ----
    local conntrackMax=$((sizeMb * 1024 * 1024 / 400 * 125 / 1000))
    [[ $conntrackMax -lt 262144 ]] && conntrackMax=262144
    [[ $conntrackMax -gt 4194304 ]] && conntrackMax=4194304
    updateSysctlParam "net.netfilter.nf_conntrack_max" "${conntrackMax}"

    local tw_buckets=$((conntrackMax / 2))
    [[ $tw_buckets -lt 262144 ]] && tw_buckets=262144
    updateSysctlParam "net.ipv4.tcp_max_tw_buckets" "${tw_buckets}"

    local max_orphans=$((conntrackMax / 10))
    [[ $max_orphans -lt 32768 ]] && max_orphans=32768
    updateSysctlParam "net.ipv4.tcp_max_orphans" "${max_orphans}"

    # ---- 4. 队列与 optmem ----
    local somaxconn=$((sizeMb * 32))
    [[ $somaxconn -lt 65535 ]] && somaxconn=65535
    [[ $somaxconn -gt 524288 ]] && somaxconn=524288
    updateSysctlParam "net.core.somaxconn" "${somaxconn}"

    local netdev_backlog=$((sizeMb * 16))
    [[ $netdev_backlog -lt 32768 ]] && netdev_backlog=32768
    [[ $netdev_backlog -gt 262144 ]] && netdev_backlog=262144
    updateSysctlParam "net.core.netdev_max_backlog" "${netdev_backlog}"

    local optmem_max=$((sizeMb * 512))
    [[ $optmem_max -lt 131072 ]] && optmem_max=131072
    [[ $optmem_max -gt 2097152 ]] && optmem_max=2097152
    updateSysctlParam "net.core.optmem_max" "${optmem_max}"
}

# Automatically detect the primary egress network interface
getPrimaryInterface() {
    local detectedInterface
    # Primary lookup: query routing entry for default gateway
    detectedInterface=$(ip -4 route show default 2>/dev/null | awk '/default/ {print $5; exit}')

    # Fallback lookup: resolve interface via route lookup to public DNS
    if [[ -z "$detectedInterface" ]]; then
        detectedInterface=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}')
    fi

    # Fallback lookup: grab the first non-virtual physical link if routing is empty
    if [[ -z "$detectedInterface" ]]; then
        detectedInterface=$(ls /sys/class/net | grep -vE '^(lo|docker|veth|br-|virbr|tun|tap|wg)' | head -n1)
    fi

    echo "$detectedInterface"
}

# Configure RFS and interface-specific network parameters
configureRfs() {
    local targetInterface="$1"
    local totalEntries="${2:-131072}"

    if [[ -z "$targetInterface" || ! -d "/sys/class/net/${targetInterface}" ]]; then
        return 1
    fi

    # 1. Update global sysctl parameters via updateSysctlParam
    updateSysctlParam "net.core.rps_sock_flow_entries" "$totalEntries"

    # 2. Update interface-specific neighbor parameters directly into sysctl
    updateSysctlParam "net.ipv4.neigh.${targetInterface}.base_reachable_time_ms" "120000"
    updateSysctlParam "net.ipv4.neigh.${targetInterface}.retrans_time_ms" "256"
    updateSysctlParam "net.ipv4.neigh.${targetInterface}.mcast_solicit" "3"

    # 3. Detect available hardware/virtual RX queues
    local rxQueues
    rxQueues=$(ls -d /sys/class/net/"${targetInterface}"/queues/rx-* 2>/dev/null | wc -l)

    if [[ "$rxQueues" -eq 0 ]]; then
        return 0
    fi

    # 4. Calculate balanced flow entries per receive queue
    local perQueueEntries=$((totalEntries / rxQueues))

    # 5. Apply flow counts to sysfs attributes immediately
    for rxQueuePath in /sys/class/net/"${targetInterface}"/queues/rx-*; do
        if [[ -w "${rxQueuePath}/rps_flow_cnt" ]]; then
            echo "${perQueueEntries}" | tee "${rxQueuePath}/rps_flow_cnt" >/dev/null
        fi
    done

    # 6. Generate udev rule to persist sysfs rps_flow_cnt across system reboots
    local udevRulesFile="/etc/udev/rules.d/99-network-rps.rules"
    mkdir -p "$(dirname "$udevRulesFile")"
    cat <<EOF > "$udevRulesFile"
# Automatically generated udev rule for RFS queue persistence
SUBSYSTEM=="net", ACTION=="add|change", KERNEL=="${targetInterface}", RUN+="/bin/sh -c 'for q in /sys/class/net/%k/queues/rx-*/rps_flow_cnt; do [ -w \"\$\$q\" ] && echo ${perQueueEntries} > \"\$\$q\"; done'"
EOF
}

updateSysctlParam() {
    local paramKey="$1"
    local paramValue="$2"
    local targetFile="$sysctl_conf"

    # Ensure target configuration directory and file exist
    mkdir -p "$(dirname "$targetFile")"
    touch "$targetFile"

    if grep -qE "^[[:space:]]*#?[[:space:]]*${paramKey}\b" "$targetFile"; then
        sed -i -E "s|^[[:space:]]*#?[[:space:]]*${paramKey}\b.*|${paramKey} = ${paramValue}|" "$targetFile"
    else
        if [[ -s "$targetFile" ]] && [[ -n "$(tail -c1 "$targetFile")" ]]; then
            printf '\n' >> "$targetFile"
        fi
        echo "${paramKey} = ${paramValue}" >> "$targetFile"
    fi

    # Apply immediately to the running kernel
    sysctl -w "${paramKey}=${paramValue}" >/dev/null 2>&1 || true
}

# ==================== 路由窗口设置（仅运行时，不持久化） ====================
# 沿用全部 token，只增改 initcwnd/initrwnd，避免丢掉
# onlink / metric / proto / src 等服务商下发的属性。
# 不写任何 unit / hook / drop-in，重启后自动失效。

route_field() {
    local key="$1" line="${2-}"
    [ $# -ge 2 ] || line=$(ip -4 route show default 2>/dev/null | head -1)
    printf '%s\n' "$line" | awk -v k="$key" '{
        for(i=1;i<NF;i++) if($i==k){print $(i+1); exit}}'
}

route_set_initcwnd() {
    local n="$1" route token skip=0
    local -a args=() clean=()

    route=$(ip -4 route show default 2>/dev/null | head -1)
    [ -n "$route" ] || { warn "未找到默认路由，跳过 initcwnd"; return 1; }

    # 多路径路由第一行没有 dev/via，不能 replace
    [ -n "$(route_field dev "$route")" ] || { warn "多路径默认路由，跳过 initcwnd"; return 1; }

    read -r -a args <<< "$route"
    for token in "${args[@]}"; do
        if [ "$skip" = 1 ]; then skip=0; continue; fi
        case "$token" in
            initcwnd|initrwnd) skip=1 ;;
            *) clean+=("$token") ;;
        esac
    done
    [ "${#clean[@]}" -gt 1 ] || { warn "默认路由解析失败，跳过 initcwnd"; return 1; }

    if ip -4 route replace "${clean[@]}" initcwnd "$n" initrwnd "$n" 2>/dev/null; then
        info "initcwnd/initrwnd = $n 已设置（仅本次生效，重启后失效）"
        return 0
    else
        warn "initcwnd 设置失败（部分虚拟化平台不支持）"
        return 1
    fi
}

# ==================== 全部缓存清理 ====================
# 覆盖：TCP 指标 → 路由缓存 → ARP/NDP → DNS → conntrack → 页面缓存
# 顺序有讲究：先清协议栈层，再清系统层，最后才动 conntrack（会断连）
clear_all_caches() {
    echo
    echo "  ─────────────────────────────────────────────"
    echo "  清理缓存"
    echo "  ─────────────────────────────────────────────"
    echo

    # ---- 1. TCP 指标缓存 ----
    if ip tcp_metrics flush all >/dev/null 2>&1; then
        info "TCP 指标缓存 (ip tcp_metrics flush all)"
    else
        skip "TCP 指标缓存 (ip tcp_metrics 不可用)"
    fi
    ip -6 tcp_metrics flush all >/dev/null 2>&1 && info "IPv6 TCP 指标缓存" || true

    # ---- 2. 路由缓存 ----
    # 内核 3.6+ 已移除传统路由缓存，此命令在新内核上可能无实际效果，但无害
    if ip route flush cache >/dev/null 2>&1; then
        info "路由缓存 (ip route flush cache)"
    else
        skip "路由缓存 (新内核可能不支持)"
    fi
    ip -6 route flush cache >/dev/null 2>&1 && info "IPv6 路由缓存" || true

    # ---- 3. ARP / NDP 邻居缓存 ----
    if ip -s -s neigh flush all >/dev/null 2>&1; then
        info "ARP / NDP 邻居缓存 (ip -s -s neigh flush all)"
    else
        skip "邻居缓存 (ip neigh 不可用)"
    fi

    # ---- 4. DNS 缓存 ----
    # systemd-resolved（现代 Ubuntu/Debian 默认）
    if command -v resolvectl >/dev/null 2>&1; then
        resolvectl flush-caches >/dev/null 2>&1 && info "systemd-resolved DNS 缓存 (resolvectl flush-caches)"
    elif command -v systemd-resolve >/dev/null 2>&1; then
        systemd-resolve --flush-caches >/dev/null 2>&1 && info "systemd-resolved DNS 缓存 (systemd-resolve)"
    fi
    # nscd
    if command -v nscd >/dev/null 2>&1; then
        nscd -i hosts >/dev/null 2>&1 && info "nscd hosts 缓存 (nscd -i hosts)"
    fi
    # dnsmasq
    if systemctl is-active --quiet dnsmasq 2>/dev/null; then
        pkill -HUP dnsmasq >/dev/null 2>&1 && info "dnsmasq DNS 缓存 (SIGHUP)"
    fi
    # BIND
    if command -v rndc >/dev/null 2>&1 && systemctl is-active --quiet named 2>/dev/null; then
        rndc flush >/dev/null 2>&1 && info "BIND DNS 缓存 (rndc flush)"
    fi

    # ---- 5. conntrack 连接跟踪表 ----
    # 会中断所有已建立连接（包括 SSH），必须提醒
    echo
    warn "conntrack 清理会中断所有已建立的连接（包括 SSH）"
    if confirm "  是否清理 conntrack 表？" n; then
        if command -v conntrack >/dev/null 2>&1; then
            conntrack -F >/dev/null 2>&1 && info "conntrack 连接跟踪表 (conntrack -F)"
        else
            # 没有 conntrack 工具时，按状态清理 TIME_WAIT（较安全）
            if [ -w /proc/sys/net/netfilter/nf_conntrack_count ]; then
                skip "conntrack 工具未安装 (apt install conntrack)"
            else
                skip "nf_conntrack 未加载"
            fi
        fi
    else
        skip "conntrack 表 (按你的选择跳过)"
    fi

    # ---- 6. 系统页面 / inode / dentry 缓存 ----
    echo
    if confirm "  是否清理系统页面/inode 缓存？(drop_caches)" n; then
        sync
        if echo 3 > /proc/sys/vm/drop_caches 2>/dev/null; then
            info "页面 + dentry + inode 缓存 (drop_caches=3)"
        else
            warn "drop_caches 写入失败（只读文件系统？）"
        fi
    else
        skip "系统页面缓存 (按你的选择跳过)"
    fi

    echo
    echo "  ─────────────────────────────────────────────"
    echo "  缓存清理完成"
    echo "  ─────────────────────────────────────────────"
    echo
}

# ==================== Sysctl 配置应用 ====================
sysctl_p() {

  net_mem

  sysctl -p >/dev/null 2>&1
  sysctl --system >/dev/null 2>&1
  sysctl -w net.ipv4.route.flush=1 >/dev/null 2>&1
  sysctl -w net.ipv6.route.flush=1 >/dev/null 2>&1
  # ip route flush cache >/dev/null 2>&1

  resolvectl flush-caches 2>/dev/null || true
  systemctl restart nscd 2>/dev/null || service nscd restart 2>/dev/null || true
  # ip neigh flush all 2>/dev/null || true
  nscd -i hosts 2>/dev/null || true

  modprobe nf_conntrack 2>/dev/null || true
  MAX_CONN=$(sysctl -n net.netfilter.nf_conntrack_max 2>/dev/null || sysctl -n net.nf_conntrack_max 2>/dev/null)
  if [[ -n "$MAX_CONN" ]]; then
      HASHSIZE=$((MAX_CONN / 4))
      [[ -w /sys/module/nf_conntrack/parameters/hashsize ]] && echo "$HASHSIZE" > /sys/module/nf_conntrack/parameters/hashsize
  fi

  sysctl -w net.core.rps_sock_flow_entries=32768 >/dev/null 2>&1

  # === 修改：设置路由窗口，仅运行时，不持久化 ===
  #route_set_initcwnd 32

}

# ==================== BBR 内核安装 ====================
Install_bbr() {
wget -O tcpx.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcpx.sh" && chmod +x tcpx.sh && ./tcpx.sh
}

# ==================== 第三方脚本工具 ====================
kejilion_sh() {
curl -s -O https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh && chmod +x kejilion.sh && ./kejilion.sh
}

joey_install() {
bash <(curl -l -s https://raw.githubusercontent.com/byJoey/Actions-bbr-v3/refs/heads/main/install.sh)
}

radical_sh() {
bash <(curl -Ls https://raw.githubusercontent.com/Shellgate/tcp_optimization_bbr/main/bbr.sh)
}

up_cloudflared() {
curl --location --output cloudflared.deb "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$(dpkg --print-architecture).deb" && sudo dpkg -i cloudflared.deb && sudo systemctl restart cloudflared.service
}

# ==================== 全部优化安装 ====================
Install_All() {
Install_limits; Install_systemd; Install_sysctl;
}

# ==================== 内核参数配置 ====================
Install_sysctl() {

[[ -f "$backup_bak" ]] && rm -f "$backup_bak"
cp "$sysctl_conf" "$backup_bak"
echo -e "${GREEN}✓ 备份已保存至 $backup_bak${RESET}"

curl -sf -o "$tmp_new" "$sysctl_url"

if [[ $? -ne 0 ]]; then
    echo -e "${RED}✗ 下载配置文件失败.${RESET}"
    exit 1
fi

cp "$tmp_new" "$sysctl_conf"
echo -e "${GREEN}✓ 配置已应用.${RESET}"

file_sysctl="/etc/sysctl.d/99-sysctl.conf"
if [ -L "$file_sysctl" ]; then
    mv -f "$file_sysctl" "${file_sysctl}.bak"
elif [ -f "$file_sysctl" ]; then
    mv -f "$file_sysctl" "${file_sysctl}.bak"
fi

ln -sf /etc/sysctl.conf /etc/sysctl.d/99-sysctl.conf

ip tcp_metrics flush all > /dev/null 2>&1

sysctl_p

echo -e "${BLUE}→ 应用变更:${RESET}"
diff_output=$(diff -u "$backup_bak" "$sysctl_conf")
if [[ -z "$diff_output" ]]; then
    echo -e "${GRAY}(没有显示更新)${RESET}"
else
    while IFS= read -r line; do
        if [[ "$line" =~ ^\+ && ! "$line" =~ ^\+\+ ]]; then
            echo -e "${GREEN}$line${RESET}"
        elif [[ "$line" =~ ^\- && ! "$line" =~ ^\-\- ]]; then
            echo -e "${RED}$line${RESET}"
        else
            echo -e "${WHITE}$line${RESET}"
        fi
    done <<< "$diff_output"
fi

read -p "→ 现在重启系统吗? [y/N]: " confirm
[[ "$confirm" =~ ^[Yy]$ ]] && reboot
}

# ==================== conf.d/test 配置选择与应用 ====================
sysctl_select() {
    local list_file="/tmp/sysctl_remote.list"
    local api_url="https://api.github.com/repos/cluntop/sh/contents/conf.d/test"
    local choice entry sel_name sel_url diff_output confirm

    if ! curl -sf --connect-timeout 10 --max-time 20 -H "User-Agent: curl" "$api_url" -o /tmp/sysctl_dir.json; then
        echo -e "${RED}✗ 获取远程配置清单失败，请检查网络后重试${RESET}"
        echo -e "${GRAY}  $api_url${RESET}"
        read -n 1 -s -r -p "按任意键返回..."
        return 1
    fi

    grep -o '"name": *"[^"]*"' /tmp/sysctl_dir.json \
        | sed 's/.*"name": *"//; s/"$//' > /tmp/sysctl_names.tmp
    grep -o '"download_url": *"[^"]*"' /tmp/sysctl_dir.json \
        | sed 's/.*"download_url": *"//; s/"$//' > /tmp/sysctl_urls.tmp
    paste -d'|' /tmp/sysctl_names.tmp /tmp/sysctl_urls.tmp \
        | nl -w1 -s'|' > "$list_file"
    rm -f /tmp/sysctl_dir.json /tmp/sysctl_names.tmp /tmp/sysctl_urls.tmp

    if [[ ! -s "$list_file" ]]; then
        echo -e "${RED}✗ 未解析到 conf.d/test 中的配置文件${RESET}"
        read -n 1 -s -r -p "按任意键返回..."
        return 1
    fi

    while true; do
        clear
        echo "========================================"
        echo "     内核配置选择 (conf.d/test)"
        echo "========================================"
        while IFS='|' read -r idx name dl; do
            printf "  %s. %s\n" "$idx" "$name"
        done < "$list_file"
        echo "----------------------------------------"
        echo "  0. 返回上级菜单"
        echo "========================================"

        read -e -p "请输入配置编号 [0]: " choice

        if [[ "$choice" == "0" ]]; then
            return 0
        fi

        if [[ ! "$choice" =~ ^[0-9]+$ ]]; then
            echo "无效输入，请输入配置编号！"
            sleep 1
            continue
        fi

        entry=$(grep -E "^${choice}\|" "$list_file")
        if [[ -z "$entry" ]]; then
            echo "无效的配置编号，请重新选择！"
            sleep 1
            continue
        fi

        sel_name=$(echo "$entry" | cut -d'|' -f2)
        sel_url=$(echo "$entry" | cut -d'|' -f3-)

        echo ""
        echo "已选择: ${sel_name}"
        echo "下载: ${sel_url}"

        [[ -f "$backup_bak" ]] && rm -f "$backup_bak"
        cp "$sysctl_conf" "$backup_bak"
        echo -e "${GREEN}✓ 备份已保存至 $backup_bak${RESET}"

        curl -sfL -o "$tmp_new" "$sel_url"
        if [[ $? -ne 0 ]]; then
            echo -e "${RED}✗ 下载配置文件失败: ${sel_name}${RESET}"
            sleep 1
            continue
        fi

        cp "$tmp_new" "$sysctl_conf"
        echo -e "${GREEN}✓ 配置已应用: ${sel_name}${RESET}"

        file_sysctl="/etc/sysctl.d/99-sysctl.conf"
        if [ -L "$file_sysctl" ]; then
            mv -f "$file_sysctl" "${file_sysctl}.bak"
        elif [ -f "$file_sysctl" ]; then
            mv -f "$file_sysctl" "${file_sysctl}.bak"
        fi
        ln -sf /etc/sysctl.conf /etc/sysctl.d/99-sysctl.conf

        ip tcp_metrics flush all > /dev/null 2>&1

        sysctl_p

        echo -e "${BLUE}→ 应用变更:${RESET}"
        diff_output=$(diff -u "$backup_bak" "$sysctl_conf")
        if [[ -z "$diff_output" ]]; then
            echo -e "${GRAY}(没有显示更新)${RESET}"
        else
            while IFS= read -r line; do
                if [[ "$line" =~ ^\+ && ! "$line" =~ ^\+\+ ]]; then
                    echo -e "${GREEN}$line${RESET}"
                elif [[ "$line" =~ ^\- && ! "$line" =~ ^\-\- ]]; then
                    echo -e "${RED}$line${RESET}"
                else
                    echo -e "${WHITE}$line${RESET}"
                fi
            done <<< "$diff_output"
        fi

        modprobe nf_conntrack 2>/dev/null || true
        local max_conn
        max_conn=$(sysctl -n net.netfilter.nf_conntrack_max 2>/dev/null || sysctl -n net.nf_conntrack_max 2>/dev/null || echo "")
        if [[ -n "$max_conn" ]] && [[ -w /sys/module/nf_conntrack/parameters/hashsize ]]; then
            echo $((max_conn / 4)) > /sys/module/nf_conntrack/parameters/hashsize 2>/dev/null || true
        fi

        read -p "→ 现在重启系统吗? [y/N]: " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] && reboot

        echo ""
        echo "按任意键返回配置选择菜单..."
        read -n 1 -s -r -p ""
        echo ""
    done
}

# ==================== 网络诊断函数 ====================
lost_packet() {
    if [[ -n "$nic" ]] && command -v ethtool &>/dev/null; then
        ethtool -S "$nic" 2>/dev/null | grep -E "rx_no_buffer_count|rx_missed_errors|rx_fifo_errors|rx_over_errors" || info "无丢包计数"
    else
        warn "未检测到网卡或 ethtool 不可用"
    fi
}

check_buffer() {
    if [[ -n "$nic" ]] && command -v ethtool &>/dev/null; then
        ethtool -g "$nic" 2>/dev/null || warn "无法读取网卡缓冲"
    fi
}

check_settings() {
    if [[ -n "$nic" ]] && command -v ethtool &>/dev/null; then
        ethtool -c "$nic" 2>/dev/null || warn "无法读取网卡设置"
    fi
}

cleaning_trash() {
    warn "此脚本已移除危险的 rm -rf /tmp 和 docker prune"
    info "执行安全的包管理器清理..."
    case "$OS" in
        ubuntu|debian|linuxmint|pop)
            apt-get clean >/dev/null 2>&1 || true
            apt-get autoremove -y >/dev/null 2>&1 || true
            ;;
        centos|rhel|rocky|almalinux|fedora)
            if command -v dnf &>/dev/null; then
                dnf clean all >/dev/null 2>&1 || true
            else
                yum clean all >/dev/null 2>&1 || true
            fi
            ;;
    esac
    info "清理完成"
}

# ==================== 命令帮助信息 ====================
tcp_info() {
echo "---"
echo "以下是命令参考用例："
echo "启动脚本 tcp"
echo "优化内核 tcp tcp"
echo "优化内核任务 tcp sys"
echo "选择内核配置 tcp conf"
}

# ==================== 主菜单 ====================
clun_tcp() {
while true; do
    clear
    echo "当前版本 v$version($version_test)"
    echo "更新提交问题 t.me/clun_top"
    echo "命令行输入 tcp 可快速启动脚本"
    echo "---"
    echo "1. 优化全部 2. 优化限制"
    echo "3. 优化安全 4. 优化内核"
    echo "5. 内核配置选择"
    echo "---"
    echo "7. 清理垃圾 8. 命令参考"
    echo "9. 安装内核 10. 激进内核"
    echo "11. XXX 12. 内核脚本"
    echo "13. 丢失数据包 14. 检查缓冲"
    echo "15. 检查当前设置 18. TCP 调优"
    echo "16. systemd-journald 优化 "
    echo "17. sysctl 重新加载优化 "
    echo "18. 更新 cloudflared "
    echo "19. TCP 调优 20. 清理全部缓存"
    echo "000. 科技 Lion 脚本工具箱"
    echo "---"
    echo "00. 更新脚本 0. 退出脚本"

    read -e -p "请输入你的选择: " choice

    case $choice in
      1) Install_All ; clear ; exit ;;
      2) Install_limits ;;
      3) Install_systemd ;;
      4) Install_sysctl ; clear ; exit ;;
      5) sysctl_select ;;
      7) cleaning_trash ; clear ; exit ;;
      8) tcp_info ;;
      9) Install_bbr ; clear ; exit ;;
      10) radical_sh ; clear ; exit ;;
      11)  clear ; exit ;;
      12) joey_install ; clear ; exit ;;
      13) lost_packet ;;
      14) check_buffer ;;
      15) check_settings ;;
      16) systemd_journald_optimize ;;
      17) sysctl_p ; clear ; exit ;;
      18) up_cloudflared ;;
      19) bash <(curl -fsSL https://raw.githubusercontent.com/Kylin010/tcpfit/main/tcpfit.sh) ;;
      20) clear_all_caches ;;
      000) kejilion_sh ; clear ; exit ;;
      00) update_script ; clear ; exit ;;
      0) clear ; exit ;;
      *) echo "无效的输入!" ;;
    esac
    echo
done
}

# ==================== 命令行参数处理 ====================
case $1 in
    "sys")
      cron_clun="0 * * * * curl -sL clun.top | bash -s -- sysctl"
      clun_cron=$(crontab -l 2>/dev/null | grep -F "$cron_clun")
      if [ -z "$clun_cron" ]; then
        (crontab -l 2>/dev/null; echo "$cron_clun") | crontab -
        echo "优化内核任务已添加"
      else
        crontab -l 2>/dev/null | grep -Fv "$cron_clun" | crontab -
        echo "优化内核任务已删除"
      fi
    ;;
    "sysctl") Install_sysctl ;;
    "tcp") Install_sysctl ;;
    "conf") sysctl_select ;;
    *) sleep 1 && clun_tcp ;;
esac
