#!/bin/bash
# Issues https://clun.top
# bash <(curl -sL clun.top)
# set -euo pipefail

version="1.2.7"
version_test="266"

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

# ==================== 日志辅助函数（原脚本缺失，已补全） ====================
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

# ==================== 内存硬件信息 ====================
# tcp_dyjs=$(sudo dmidecode -t memory | grep -i "Size:" | sed -e '/No Module Installed/d' -e 's/.*Size: \([0-9]\+\).*/\1/')
# tcp_dy=$(echo "$tcp_dyjs * 128 / 4" | bc 2>/dev/null)


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

        # 处理返回逻辑
        if [[ "$MODE" == "0" ]]; then
            return 0
        fi

        # 处理无效输入
        if [[ ! "$MODE" =~ ^[1-4]$ ]]; then
            echo "无效输入，请重新选择！"
            sleep 1
            continue
        fi

        # --- 只有选择 1-4 时才执行以下逻辑 ---

        # 1. 备份原配置
        local BACKUP_FILE="${CONF_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$CONF_FILE" "$BACKUP_FILE"
        echo "已备份原配置至 $BACKUP_FILE"

        # 2. 写入配置头部
        cat <<EOF > "$CONF_FILE"
[Journal]
EOF

        # 3. 根据模式追加参数
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

        # 4. 重启服务并提示
        systemctl restart systemd-journald
        echo "----------------------------------------"
        echo "配置已生效，systemd-journald 已重启。"
        echo "按任意键返回子菜单..."
        read -n 1
    done

}

# ==================== 通用函数 ====================
break_end() {
    # echo "操作完成"
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
cat >/etc/security/limits.conf<<EOF
root soft nproc unlimited
root hard nproc unlimited
root soft nofile unlimited
root hard nofile unlimited

* soft nproc unlimited
* hard nproc unlimited
* soft nofile unlimited
* hard nofile unlimited

* soft core 0
* hard core 0
EOF

    # PAM 限制模块
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
    # 透明大页 — 对高并发网络有益
    if [[ -f /sys/kernel/mm/transparent_hugepage/enabled ]]; then
        echo never >/sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
        echo never >/sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true
        echo 0 > /sys/kernel/mm/transparent_hugepage/khugepaged/defrag 2>/dev/null || true
    fi

    # CPU 性能模式 — 仅物理机
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

    # irqbalance — 虚拟化环境保持原状，物理机视情况
    if [[ "$IS_VIRTUALIZED" -eq 0 ]]; then
        if systemctl is-active --quiet irqbalance 2>/dev/null; then
            warn "物理机检测到 irqbalance 运行中。若已手动绑核，请自行停止。"
        fi
    fi

    # 磁盘调度器优化
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

    # 加载连接跟踪模块（现代内核）
    modprobe nf_conntrack 2>/dev/null || true

    # 进程 fd 限制（仅监听进程 + 已知高 fd 进程）
    if command -v prlimit &>/dev/null; then
        ss -anptl 2>/dev/null | grep -oP 'pid=\K[0-9]+' | sort -u | while read -r pid; do
            prlimit --pid "$pid" --nofile=1048576 2>/dev/null || true
        done
    fi

  sudo rmmod authencesn 2>/dev/null
  sudo rmmod algif_aead 2>/dev/null

}

# ==================== 内存参数计算 ====================
net_mem() {
    local size_mb avail_mb
    size_mb=$(free -m | awk '/Mem:/ {print $2}')
    avail_mb=$(awk '/MemAvailable:/ {print int($2/1024)}' /proc/meminfo 2>/dev/null)
    [[ -z "$avail_mb" ]] && avail_mb=$size_mb

    # 使用可用内存计算，避免 OOM
    local base=$avail_mb
    [[ "$base" -lt 512 ]] && base=$size_mb  # fallback

    # TCP mem (页): low=6%, mid=12%, high=18% of available
    local tcp_low=$((base * 15))
    local tcp_mid=$((base * 30))
    local tcp_high=$((base * 60))

    # 封顶保护 (16GB / 8GB pages)
    [[ $tcp_high -gt 4194304 ]] && { tcp_high=4194304; tcp_mid=2796202; tcp_low=1398101; }

    # 保底 (小内存)
    if [[ $avail_mb -lt 2048 ]]; then
        tcp_low=8192; tcp_mid=16384; tcp_high=32768
    fi

    # UDP mem: TCP 的 60%
    local udp_low=$((tcp_low * 6 / 10))
    local udp_mid=$((tcp_mid * 6 / 10))
    local udp_high=$((tcp_high * 6 / 10))
    [[ $udp_high -gt 2097152 ]] && { udp_high=2097152; udp_mid=1398101; udp_low=699050; }

    # 单连接上限: 与全局匹配，防止击穿
    # 高 BDP 场景允许较大缓冲，但封顶 64MB 防止单连接爆内存
    local tcp_rmem_max=$((tcp_high * 4096 / 32))
    [[ $tcp_rmem_max -lt 4194304 ]] && tcp_rmem_max=4194304
    [[ $tcp_rmem_max -gt 67108864 ]] && tcp_rmem_max=67108864

    local tcp_wmem_max=$tcp_rmem_max
    [[ $tcp_wmem_max -lt 4194304 ]] && tcp_wmem_max=4194304
    [[ $tcp_wmem_max -gt 67108864 ]] && tcp_wmem_max=67108864

    # 写入 sysctl
    updateSysctlParam "net.ipv4.tcp_mem" "$tcp_low $tcp_mid $tcp_high"
    updateSysctlParam "net.ipv4.udp_mem" "$udp_low $udp_mid $udp_high"
    # updateSysctlParam "net.core.rmem_max" "$tcp_rmem_max"
    # updateSysctlParam "net.core.wmem_max" "$tcp_wmem_max"

    # nf_conntrack: 64位经典公式 RAM/8192 bytes = MB*128
    local conntrack_max=$((size_mb * 128))
    local conntrack_buckets=$((conntrack_max / 4))
    updateSysctlParam "net.netfilter.nf_conntrack_max" "$conntrack_max"
    updateSysctlParam "net.netfilter.nf_conntrack_buckets" "$conntrack_buckets"
}

updateSysctlParam() {
  local paramKey="$1"
  local paramValue="$2"

  if grep -q "^[[:space:]]*${paramKey}\b" "$sysctlConfFile"; then
      sed -i "s|^[[:space:]]*${paramKey}\b.*|${paramKey} = ${paramValue}|" "$sysctlConfFile"
  else
      # 修复：如果目标文件末尾没有换行符（很多从 GitHub 下载的模板都这样），
      # 直接 >> 追加会把新内容和文件最后一行硬拼在一起，
      # 例如 "...reuse = 1net.netfilter.nf_conntrack_buckets = 62880" 这种语法损坏。
      # 追加前先确保文件以换行符结尾。
      if [[ -s "$sysctlConfFile" ]] && [[ -n "$(tail -c1 "$sysctlConfFile")" ]]; then
          printf '\n' >> "$sysctlConfFile"
      fi
      echo "${paramKey} = ${paramValue}" >> "$sysctlConfFile"
  fi
}

# updateSysctlParam "net.ipv4.tcp_mem" "$tcpMemString"
# updateSysctlParam "net.ipv4.udp_mem" "$udpMemString"
# updateSysctlParam "net.netfilter.nf_conntrack_max" "$conntrack_max"
# updateSysctlParam "net.netfilter.nf_conntrack_buckets" "$conntrack_buckets"

# print results（调试时取消注释）
# echo "size_mb=$size_mb"
# echo "net.ipv4.tcp_mem = $tcpMemString"
# echo "net.ipv4.udp_mem = $udpMemString"
# echo "net.netfilter.nf_conntrack_max = $conntrack_max"
# echo "net.netfilter.nf_conntrack_buckets = $conntrack_buckets"

# ==================== Sysctl 配置应用 ====================
sysctl_p() {

  net_mem

  sysctl -p >/dev/null 2>&1
  sysctl --system >/dev/null 2>&1
  sysctl -w net.ipv4.route.flush=1 >/dev/null 2>&1
  sysctl -w net.ipv6.route.flush=1 >/dev/null 2>&1
  sudo ip route flush cache >/dev/null 2>&1

  resolvectl flush-caches 2>/dev/null || true
  systemctl restart nscd 2>/dev/null || service nscd restart 2>/dev/null || true
  sudo nscd -i hosts 2>/dev/null || true
  ip neigh flush all 2>/dev/null || true

  sudo modprobe nf_conntrack 2>/dev/null || true
  MAX_CONN=$(sysctl -n net.netfilter.nf_conntrack_max 2>/dev/null || sysctl -n net.nf_conntrack_max 2>/dev/null)
  if [[ -n "$MAX_CONN" ]]; then
      HASHSIZE=$((MAX_CONN / 4))
      [[ -w /sys/module/nf_conntrack/parameters/hashsize ]] && echo "$HASHSIZE" > /sys/module/nf_conntrack/parameters/hashsize
  fi

  sysctl -w net.core.rps_sock_flow_entries=32768 >/dev/null 2>&1

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

# ==================== 全部优化安装 ====================
Install_All() {
Install_limits; Install_systemd; Install_sysctl;
}

# ==================== 内核参数配置 ====================
Install_sysctl() {

# 备份原配置
[[ -f "$backup_bak" ]] && rm -f "$backup_bak"
cp "$sysctl_conf" "$backup_bak"
echo -e "${GREEN}✓ 备份已保存至 $backup_bak${RESET}"

# 下载新配置
# 修复：curl 加 -f，遇到 HTTP 4xx/5xx 时直接返回非零，
# 避免把 "404: Not Found" 这类错误页面当成正常配置写入 /etc/sysctl.conf
curl -sf -o "$tmp_new" "$sysctl_url"

if [[ $? -ne 0 ]]; then
    echo -e "${RED}✗ 下载配置文件失败.${RESET}"
    exit 1
fi

# 应用新配置
cp "$tmp_new" "$sysctl_conf"
echo -e "${GREEN}✓ 配置已应用.${RESET}"

# 创建 sysctl.d 软链接
file_sysctl="/etc/sysctl.d/99-sysctl.conf"
if [ -L "$file_sysctl" ]; then
    mv -f "$file_sysctl" "${file_sysctl}.bak"
elif [ -f "$file_sysctl" ]; then
    mv -f "$file_sysctl" "${file_sysctl}.bak"
fi

ln -sf /etc/sysctl.conf /etc/sysctl.d/99-sysctl.conf

# 清理 TCP 指标缓存
ip tcp_metrics flush all > /dev/null 2>&1

# 应用 sysctl 配置
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

# 询问是否重启
read -p "→ 现在重启系统吗? [y/N]: " confirm
[[ "$confirm" =~ ^[Yy]$ ]] && reboot
}

# ==================== conf.d/test 配置选择与应用 ====================
# 从 https://github.com/cluntop/sh/tree/main/conf.d/test 拉取配置清单，
# 选择后下载替换 /etc/sysctl.conf 并加载
sysctl_select() {
    local list_file="/tmp/sysctl_remote.list"
    local api_url="https://api.github.com/repos/cluntop/sh/contents/conf.d/test"
    local choice entry sel_name sel_url diff_output confirm

    # 直接从 GitHub API 拉取最新文件清单（纯 curl 解析，不依赖 python）
    if ! curl -sf --connect-timeout 10 --max-time 20 -H "User-Agent: curl" "$api_url" -o /tmp/sysctl_dir.json; then
        echo -e "${RED}✗ 获取远程配置清单失败，请检查网络后重试${RESET}"
        echo -e "${GRAY}  $api_url${RESET}"
        read -n 1 -s -r -p "按任意键返回..."
        return 1
    fi

    # 用 grep/sed 提取 JSON 中的 name 与 download_url 字段，
    # 生成 "序号|文件名|下载地址" 清单（两次提取次序一致，与 API 返回逐项对应）
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

        # 备份当前配置
        [[ -f "$backup_bak" ]] && rm -f "$backup_bak"
        cp "$sysctl_conf" "$backup_bak"
        echo -e "${GREEN}✓ 备份已保存至 $backup_bak${RESET}"

        # 下载所选配置
        curl -sfL -o "$tmp_new" "$sel_url"
        if [[ $? -ne 0 ]]; then
            echo -e "${RED}✗ 下载配置文件失败: ${sel_name}${RESET}"
            sleep 1
            continue
        fi

        # 应用新配置
        cp "$tmp_new" "$sysctl_conf"
        echo -e "${GREEN}✓ 配置已应用: ${sel_name}${RESET}"

        # 创建 sysctl.d 软链接
        file_sysctl="/etc/sysctl.d/99-sysctl.conf"
        if [ -L "$file_sysctl" ]; then
            mv -f "$file_sysctl" "${file_sysctl}.bak"
        elif [ -f "$file_sysctl" ]; then
            mv -f "$file_sysctl" "${file_sysctl}.bak"
        fi
        ln -sf /etc/sysctl.conf /etc/sysctl.d/99-sysctl.conf

        # 清理 TCP 指标缓存
        ip tcp_metrics flush all > /dev/null 2>&1

        # 加载配置
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
        
         # conntrack hashsize
    modprobe nf_conntrack 2>/dev/null || true
    local max_conn
    max_conn=$(sysctl -n net.netfilter.nf_conntrack_max 2>/dev/null || sysctl -n net.nf_conntrack_max 2>/dev/null || echo "")
    if [[ -n "$max_conn" ]] && [[ -w /sys/module/nf_conntrack/parameters/hashsize ]]; then
        echo $((max_conn / 4)) > /sys/module/nf_conntrack/parameters/hashsize 2>/dev/null || true
    fi

        # 询问是否重启
        read -p "→ 现在重启系统吗? [y/N]: " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] && reboot

        echo ""
        echo "按任意键返回配置选择菜单..."
        read -n 1 -s -r -p ""
        echo ""
    done
}

# ==================== 网络诊断函数 ====================
# 修复：原来引用的 $nic_interface 从未被赋值，统一改用脚本前面已探测好的 $nic
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
    echo "000. 科技 Lion 脚本工具箱"
    echo "---"
    echo "00. 更新脚本 0. 退出脚本"

    read -e -p "请输入你的选择: " choice

    case $choice in
      # 修复：原来这两行把 ";" 误打成 ":"，导致 clear 从未真正执行
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
      18) bash <(curl -fsSL https://raw.githubusercontent.com/Kylin010/tcpfit/main/tcpfit.sh) ;;
      000) kejilion_sh ; clear ; exit ;;
      00) update_script ; clear ; exit ;;
      0) clear ; exit ;;
      *) echo "无效的输入!" ;;
    esac
      # break_end
    echo
done
}

# ==================== 命令行参数处理 ====================
case $1 in
    "sys")
      # 定时任务: 每小时执行一次内核优化
      cron_clun="0 * * * * curl -sL clun.top | bash -s -- sysctl"
      # 检查是否存在相同的定时任务
      clun_cron=$(crontab -l 2>/dev/null | grep -F "$cron_clun")
      # 如果不存在，则添加定时任务
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

# sleep 1 &&
# clun_tcp