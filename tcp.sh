#!/bin/bash
# Issues https://clun.top
# bash <(curl -sL clun.top)

version="1.2.7"
version_test="257"

# ==================== 颜色定义 ====================
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
GRAY='\033[90m'
WHITE='\033[97m'
RESET='\033[0m'

# ==================== 日志辅助函数（原脚本缺失，已补全） ====================
info() { echo -e "${GREEN}[信息]${RESET} $*"; }
skip() { echo -e "${YELLOW}[跳过]${RESET} $*"; }
warn() { echo -e "${YELLOW}[警告]${RESET} $*"; }

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
        PKG_MANAGER="apt"
        PKG_INSTALL="apt-get install -y"
        PKG_UPDATE="apt-get update"
        PKG_UPGRADE="apt-get upgrade -y"
        PKG_REMOVE="apt-get remove -y"
        PKG_CLEAN="apt-get autoremove -y"
        PKG_SEARCH="apt-cache search"
        PKG_LIST="dpkg -l"
        PKG_CHECK="dpkg -l | grep"
        ;;
    centos|rhel|rocky|almalinux)
        if command -v dnf &> /dev/null; then
            PKG_MANAGER="dnf"
            PKG_INSTALL="dnf install -y"
            PKG_UPDATE="dnf check-update"
            PKG_UPGRADE="dnf upgrade -y"
            PKG_REMOVE="dnf remove -y"
            PKG_CLEAN="dnf autoremove -y"
            PKG_SEARCH="dnf search"
            PKG_LIST="dnf list installed"
            PKG_CHECK="rpm -qa | grep"
        else
            PKG_MANAGER="yum"
            PKG_INSTALL="yum install -y"
            PKG_UPDATE="yum check-update"
            PKG_UPGRADE="yum update -y"
            PKG_REMOVE="yum remove -y"
            PKG_CLEAN="yum autoremove -y"
            PKG_SEARCH="yum search"
            PKG_LIST="yum list installed"
            PKG_CHECK="rpm -qa | grep"
        fi
        ;;
    fedora)
        PKG_MANAGER="dnf"
        PKG_INSTALL="dnf install -y"
        PKG_UPDATE="dnf check-update"
        PKG_UPGRADE="dnf upgrade -y"
        PKG_REMOVE="dnf remove -y"
        PKG_CLEAN="dnf autoremove -y"
        PKG_SEARCH="dnf search"
        PKG_LIST="dnf list installed"
        PKG_CHECK="rpm -qa | grep"
        ;;
    arch|manjaro|endeavouros)
        PKG_MANAGER="pacman"
        PKG_INSTALL="pacman -S --noconfirm"
        PKG_UPDATE="pacman -Sy"
        PKG_UPGRADE="pacman -Syu --noconfirm"
        PKG_REMOVE="pacman -R --noconfirm"
        PKG_CLEAN="pacman -Sc --noconfirm"
        PKG_SEARCH="pacman -Ss"
        PKG_LIST="pacman -Q"
        PKG_CHECK="pacman -Q | grep"
        ;;
    alpine)
        PKG_MANAGER="apk"
        PKG_INSTALL="apk add"
        PKG_UPDATE="apk update"
        PKG_UPGRADE="apk upgrade"
        PKG_REMOVE="apk del"
        PKG_CLEAN="apk cache clean"
        PKG_SEARCH="apk search"
        PKG_LIST="apk info"
        PKG_CHECK="apk info | grep"
        ;;
    opensuse*)
        PKG_MANAGER="zypper"
        PKG_INSTALL="zypper install -y"
        PKG_UPDATE="zypper refresh"
        PKG_UPGRADE="zypper update -y"
        PKG_REMOVE="zypper remove -y"
        PKG_CLEAN="zypper clean"
        PKG_SEARCH="zypper search"
        PKG_LIST="zypper se --installed-only"
        PKG_CHECK="rpm -qa | grep"
        ;;
    *)
        PKG_MANAGER="unknown"
        PKG_INSTALL="echo 'Unknown package manager'"
        ;;
esac

# ==================== 依赖检查与安装 ====================
REQUIRED_COMMANDS="sudo wget ethtool dmidecode tuned"

check_and_install() {
    for cmd in $REQUIRED_COMMANDS; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${YELLOW}缺少命令: $cmd，正在安装...${RESET}"
            $PKG_INSTALL $cmd
        fi
    done
}

check_and_install

# ==================== 网络接口配置 ====================
nic=$(ip link show | awk -F': ' '/^[0-9]+: / && $2 != "lo" {print $2}' | head -n1)

# ==================== 文件路径配置 ====================
backup_bak="/etc/sysctl.conf.bak"
tmp_new="/tmp/sysctl.new"
sysctl_conf="/etc/sysctl.conf"
sysctl_url="https://raw.githubusercontent.com/cluntop/sh/main/conf.d/sysctl.conf"

# ==================== 脚本别名安装 ====================
sed -i '/^alias tcp=/d' ~/.bashrc > /dev/null 2>&1
sed -i '/^alias tcp=/d' ~/.profile > /dev/null 2>&1
sed -i '/^alias tcp=/d' ~/.bash_profile > /dev/null 2>&1

cp -f "$0" ~/clun_tcp.sh > /dev/null 2>&1
cp -f ~/clun_tcp.sh /usr/local/bin/tcp > /dev/null 2>&1
chmod +x /usr/local/bin/tcp > /dev/null 2>&1

# ==================== 网络路由信息 ====================
GW=$(ip route show default | awk '/default/ {print $3; exit}')
DEV=$(ip route show default | awk '/default/ {print $5; exit}')

# ==================== 内存硬件信息 ====================
tcp_dyjs=$(sudo dmidecode -t memory | grep -i "Size:" | sed -e '/No Module Installed/d' -e 's/.*Size: \([0-9]\+\).*/\1/')
tcp_dy=$(echo "$tcp_dyjs * 128 / 4" | bc 2>/dev/null)


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
Storage=volatile
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
Storage=volatile
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
}

# ==================== 系统服务优化 ====================
Install_systemd() {

# 配置 PAM 限制模块
sed -i '/^session required pam_limits.so/d' /etc/pam.d/common-session-noninteractive 2>/dev/null
echo "session required pam_limits.so" >> /etc/pam.d/common-session-noninteractive

sed -i '/^session required pam_limits.so/d' /etc/pam.d/common-session 2>/dev/null
echo "session required pam_limits.so" >> /etc/pam.d/common-session

  # 透明大页设置
  echo never >/sys/kernel/mm/transparent_hugepage/enabled
  echo never >/sys/kernel/mm/transparent_hugepage/defrag

  # CPU 性能模式设置
  test -e /sys/devices/system/cpu/cpufreq/scaling_governor && echo performance | tee /sys/devices/system/cpu/cpufreq/scaling_governor
  test -e /sys/devices/system/cpu/cpufreq/policy0/scaling_governor && echo performance | tee /sys/devices/system/cpu/cpufreq/policy*/scaling_governor
  test -e /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor && echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

  test -e /sys/devices/system/cpu/cpufreq/boost && echo 1 > /sys/devices/system/cpu/cpufreq/boost
  test -e /sys/devices/system/cpu/intel_pstate/no_turbo && echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo
  test -e /sys/devices/system/cpu/intel_pstate/max_perf_pct && echo 100 > /sys/devices/system/cpu/intel_pstate/max_perf_pct
  test -n "$(which auditctl)" && auditctl -D && auditctl -a never,task >/dev/null 2>&1

  # 关闭 THP khugepaged 扫描（减少后台开销）
  echo 0 > /sys/kernel/mm/transparent_hugepage/khugepaged/defrag &>/dev/null
  cpupower idle-set -D 1 &>/dev/null

  for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
    for state in "$cpu"/cpuidle/state[2-9]; do
        [[ -f "$state/disable" ]] && echo 1 > "$state/disable"
    done
  done

  if systemctl is-active --quiet irqbalance 2>/dev/null; then
    systemctl stop irqbalance && systemctl disable irqbalance
    warn "已停止 irqbalance（手动绑定 NIC 中断，避免中断漂移）"
  fi

  PRIMARY_NIC=$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')
  CPU_COUNT=$(nproc)
  CPU_MASK=$(printf "%x" $(( (1 << CPU_COUNT) - 1 )))

  if [[ -n "$PRIMARY_NIC" ]]; then
                    # IRQ → 轮询绑核
                    IRQ_LIST=$(grep -w "${PRIMARY_NIC}" /proc/interrupts 2>/dev/null | awk -F: '{print $1}' | tr -d ' ')
                    i=0
                    for irq in $IRQ_LIST; do
                        mask=$(printf "%x" $((1 << (i % CPU_COUNT))))
                        echo "$mask" > /proc/irq/${irq}/smp_affinity 2>/dev/null || true
                        ((i++)) || true
                    done
                    [[ $i -gt 0 ]] && info "网卡 ${PRIMARY_NIC}: ${i} 个 IRQ 轮询绑定到 ${CPU_COUNT} 核" \
                                    || skip "未找到 ${PRIMARY_NIC} 的 IRQ 条目（可能是虚拟化网卡）"

                    # RPS: 软中断在所有 CPU 上分发（无多队列网卡时补充）
                    # 修复：部分虚拟化网卡（如单队列 virtio-net）的这几个 sysfs 属性
                    # 即使 -f 检测存在，实际 write() 也可能因为驱动限制而失败（ENOENT/EIO）。
                    # 这些都是尽力而为的优化项，写入失败不应该把报错刷到终端，统一吞掉。
                    for f in /sys/class/net/${PRIMARY_NIC}/queues/rx-*/rps_cpus; do
                        [[ -f "$f" ]] && { echo "$CPU_MASK" > "$f"; } 2>/dev/null
                    done

                    # XPS: 每个 TX 队列绑定对应 CPU
                    for f in /sys/class/net/${PRIMARY_NIC}/queues/tx-*/xps_cpus; do
                        [[ -f "$f" ]] && { echo "$CPU_MASK" > "$f"; } 2>/dev/null
                    done

                    # RPS flow limit（防止单核热点）
                    for f in /sys/class/net/${PRIMARY_NIC}/queues/rx-*/rps_flow_cnt; do
                        [[ -f "$f" ]] && { echo 4096 > "$f"; } 2>/dev/null
                    done
                    info "RPS/XPS flow → 全部 ${CPU_COUNT} 核（mask: 0x${CPU_MASK}）"
                else
                    skip "未检测到默认路由网卡，跳过 IRQ/RPS/XPS 配置"
         fi

         for disk in $(lsblk -d -o NAME,TYPE 2>/dev/null | awk '$2=="disk"{print $1}'); do
                    SCH_FILE="/sys/block/${disk}/queue/scheduler"
                    [[ -f "$SCH_FILE" ]] || continue

                    ROTATIONAL=$(cat /sys/block/${disk}/queue/rotational 2>/dev/null || echo 1)
                    if [[ "$ROTATIONAL" == "0" ]]; then
                        # SSD / NVMe: none（让硬件自己排队）或 mq-deadline
                        if grep -q "\[none\]\|none" "$SCH_FILE"; then
                            echo none > "$SCH_FILE"
                            echo 0 > /sys/block/${disk}/queue/read_ahead_kb 2>/dev/null || true
                            info "磁盘 ${disk} (SSD/NVMe) → scheduler: none, read_ahead: 0"
                        elif grep -q "mq-deadline" "$SCH_FILE"; then
                            echo mq-deadline > "$SCH_FILE"
                            echo 0 > /sys/block/${disk}/queue/read_ahead_kb 2>/dev/null || true
                            info "磁盘 ${disk} (SSD) → scheduler: mq-deadline"
                        fi
                        # 关闭合并（SSD 随机IO无需合并）
                        echo 2 > /sys/block/${disk}/queue/nomerges 2>/dev/null || true
                    else
                        # HDD: mq-deadline + 适当预读
                        if grep -q "mq-deadline" "$SCH_FILE"; then
                            echo mq-deadline > "$SCH_FILE"
                            echo 256 > /sys/block/${disk}/queue/read_ahead_kb 2>/dev/null || true
                            info "磁盘 ${disk} (HDD) → scheduler: mq-deadline, read_ahead: 256K"
                        fi
                    fi
                    # 队列深度（NVMe 硬件已很高，HDD 适当增大）
                    echo 64 > /sys/block/${disk}/queue/nr_requests 2>/dev/null || true
  done

# udev 规则持久化（重启后生效）
cat > /etc/udev/rules.d/99-io-scheduler.rules << 'EOF'
# SSD / NVMe → none
ACTION=="add|change", KERNEL=="sd[a-z]|nvme[0-9]n[0-9]", \
    ATTR{queue/rotational}=="0", \
    ATTR{queue/scheduler}="none", \
    ATTR{queue/read_ahead_kb}="0"
# HDD → mq-deadline
ACTION=="add|change", KERNEL=="sd[a-z]", \
    ATTR{queue/rotational}=="1", \
    ATTR{queue/scheduler}="mq-deadline", \
    ATTR{queue/read_ahead_kb}="256"
EOF

  [[ -n "$GW" && -n "$DEV" ]] && { ip route replace default via "$GW" dev "$DEV" initcwnd 32 initrwnd 32; } 2>/dev/null

  # 进程文件描述符限制
  ss -anptl 2>/dev/null | grep -oP 'pid=\K[0-9]+' | sort -u | xargs -r -I{} sudo prlimit --pid {} --nofile=1048576

  # 网卡参数优化
  # ethtool -C $nic rx-usecs 10 tx-usecs 10
  # ethtool -K $nic sg on tx on rx on tso on gso on >/dev/null 2>&1

  # ip link set dev $nic gso_max_size 16384

  # 加载连接跟踪模块
  # 修复：ip_conntrack 是 2.6.20 以前的旧模块名，现代内核（含 XanMod）已统一为 nf_conntrack
  sudo modprobe nf_conntrack 2>/dev/null || true

  #  电源管理优化
  { test -e /sys/module/intel_idle/parameters/max_cstate && echo 0 >/sys/module/intel_idle/parameters/max_cstate; } 2>/dev/null
  { test -e /sys/module/pcie_aspm/parameters/policy && echo "performance" >/sys/module/pcie_aspm/parameters/policy; } 2>/dev/null

  echo "install authencesn /bin/false" >> /etc/modprobe.d/security.conf

  # ensure debugfs is mounted
                if ! mountpoint -q /sys/kernel/debug; then
    mount -t debugfs none /sys/kernel/debug
  fi

  # define target slice in nanoseconds (e.g., 10ms for high throughput)
  baseSliceNs=3000000

  # check if the parameter exists in the current XanMod build and apply
  schedConfigPath="/sys/kernel/debug/sched/base_slice_ns"
  if [ -f "$schedConfigPath" ]; then
    echo $baseSliceNs > $schedConfigPath
  fi

  sudo rmmod authencesn 2>/dev/null
  sudo rmmod algif_aead 2>/dev/null

}

# ==================== 系统垃圾清理 ====================
cleaning_trash() {
sudo apt-get clean; sudo apt-get autoclean; sudo apt-get autoremove -y; sudo journalctl --rotate; sudo journalctl --vacuum-time=1s
sudo dpkg -l | awk '/^rc/{print $2}' | xargs -r sudo dpkg --purge
sudo rm -rf /tmp/*; sudo rm -rf /var/tmp/*; sudo apt-get autoremove --purge -y
command -v docker >/dev/null 2>&1 && { docker system prune -a -f; docker volume prune -f; docker network prune -f; docker image prune -a -f; docker container prune -f; docker builder prune -f; }
rm -rf ~/Downloads/* 2>/dev/null
rm -rf ~/.cache/thumbnails/* 2>/dev/null
rm -rf ~/.mozilla/firefox/*.default-release/cache2/* 2>/dev/null
sudo apt-get clean
dpkg --list 2>/dev/null | grep linux-image | grep -v "$(uname -r)" | awk '{print $2}' | xargs -r sudo apt-get remove --purge -y
}

# ==================== 内存/连接跟踪参数计算与应用 ====================
net_mem() {

sysctlConfFile="/etc/sysctl.conf"

# 实际物理内存（MB）
size_mb=$(free -m | awk '/Mem:/ {print $2}')

# ---- TCP/UDP 内存阈值（单位：页，1页=4096字节）----
tcp_low=$((size_mb * 16))
tcp_mid=$((size_mb * 32))
tcp_high=$((size_mb * 48))

udp_low=$((size_mb * 18))
udp_mid=$((size_mb * 36))
udp_high=$((size_mb * 54))

tcpMemString="$tcp_low $tcp_mid $tcp_high"
udpMemString="$udp_low $udp_mid $udp_high"

# ---- nf_conntrack_max（64位系统经典公式：RAM字节 / 8192）----
# 换算成 size_mb 表达式：size_mb * 1024 * 1024 / 8192 = size_mb * 128
conntrack_max=$((size_mb * 128))
conntrack_buckets=$((conntrack_max / 4))

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

updateSysctlParam "net.ipv4.tcp_mem" "$tcpMemString"
updateSysctlParam "net.ipv4.udp_mem" "$udpMemString"
updateSysctlParam "net.netfilter.nf_conntrack_max" "$conntrack_max"
updateSysctlParam "net.netfilter.nf_conntrack_buckets" "$conntrack_buckets"

# print results（调试时取消注释）
# echo "size_mb=$size_mb"
# echo "net.ipv4.tcp_mem = $tcpMemString"
# echo "net.ipv4.udp_mem = $udpMemString"
# echo "net.netfilter.nf_conntrack_max = $conntrack_max"
# echo "net.netfilter.nf_conntrack_buckets = $conntrack_buckets"

}

# ==================== Sysctl 配置应用 ====================
sysctl_p() {

  net_mem

  sysctl -p >/dev/null 2>&1
  sysctl --system >/dev/null 2>&1
  sysctl -w net.ipv4.route.flush=1 >/dev/null 2>&1
  sysctl -w net.ipv6.route.flush=1 >/dev/null 2>&1
  ip route flush cache >/dev/null 2>&1

  # 针对 systemd-resolved (Debian/Ubuntu 常用)
  resolvectl flush-caches 2>/dev/null || true
  # 刷新 nscd 缓存
  systemctl restart nscd 2>/dev/null || service nscd restart 2>/dev/null || true
  # 针对旧版 nscd
  sudo nscd -i hosts 2>/dev/null || true

  # 或者直接通过重启网络服务来刷新内核 DNS 状态
  sudo systemctl restart networking 2>/dev/null || true

  # 清理全部 ARP 缓存
  ip neigh flush all 2>/dev/null || true

  MAX_CONN=$(sysctl -n net.netfilter.nf_conntrack_max 2>/dev/null || sysctl -n net.nf_conntrack_max 2>/dev/null)
  if [[ -n "$MAX_CONN" ]]; then
      HASHSIZE=$((MAX_CONN / 4))
      [[ -w /sys/module/nf_conntrack/parameters/hashsize ]] && echo "$HASHSIZE" > /sys/module/nf_conntrack/parameters/hashsize
  fi
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

# ==================== 网络诊断函数 ====================
# 修复：原来引用的 $nic_interface 从未被赋值，统一改用脚本前面已探测好的 $nic
lost_packet() {
ethtool -S "$nic" | grep -e rx_no_buffer_count -e rx_missed_errors -e rx_fifo_errors -e rx_over_errors
}

check_buffer() {
ethtool -g "$nic"
}

check_settings() {
ethtool -c "$nic"
}

# ==================== 命令帮助信息 ====================
tcp_info() {
echo "---"
echo "以下是命令参考用例："
echo "启动脚本 tcp"
echo "优化内核 tcp tcp"
echo "优化内核任务 tcp sys"
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
    echo "---"
    echo "7. 清理垃圾 8. 命令参考"
    echo "9. 安装内核 10. 激进内核"
    echo "11. XXX 12. 内核脚本"
    echo "13. 丢失数据包 14. 检查缓冲"
    echo "15. 检查当前设置 "
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
    *) sleep 1 && clun_tcp ;;
esac

# sleep 1 &&
# clun_tcp
