#!/bin/bash
# Issues https://clun.top
# bash <(curl -sL clun.top)

version="1.2.6"
version_test="232"

# ==================== 颜色定义 ====================
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
RESET='\033[0m'

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

# ==================== 网络接口配置 ====================
nic_interface=$(ip addr | grep 'state UP' | awk '{print $2}' | sed 's/.$//')

# ==================== 文件路径配置 ====================
backup_bak="/etc/sysctl.conf.bak"
tmp_new="/tmp/sysctl.new"
sysctl_conf="/etc/sysctl.conf"
sysctl_url="https://raw.githubusercontent.com/cluntop/sh/main/conf.d/sysctl.conf"

# ==================== 脚本别名安装 ====================
sed -i '/^alias tcp=/d' ~/.bashrc > /dev/null 2>&1
sed -i '/^alias tcp=/d' ~/.profile > /dev/null 2>&1
sed -i '/^alias tcp=/d' ~/.bash_profile > /dev/null 2>&1
cp -f ./clun_tcp.sh ~/clun_tcp.sh > /dev/null 2>&1
cp -f ~/clun_tcp.sh /usr/local/bin/tcp > /dev/null 2>&1

# ==================== 内存参数计算 ====================
PAGE_SIZE=$(getconf PAGESIZE)

size_mb=$(free -m | awk '/Mem:/ {print $2}')

# TCP 内存阈值计算 (单位: 页)
tcp_low=$(echo "$size_mb * 16" | bc)
tcp_mid=$(echo "$size_mb * 32" | bc)
tcp_high=$(echo "$size_mb * 48" | bc)

# UDP 内存阈值计算 (单位: 页)
udp_low=$(echo "$size_mb * 18" | bc)
udp_mid=$(echo "$size_mb * 36" | bc)
udp_high=$(echo "$size_mb * 54" | bc)

# 基于总内存的 TCP/UDP 内存计算
TOTAL_MEM=$(grep MemTotal /proc/meminfo | awk '{print $2}')

# TCP 内存计算
TCP_LOW=$((TOTAL_MEM * 2 / 3 / PAGE_SIZE))
TCP_THRESH=$((TOTAL_MEM * 3 / 4 / PAGE_SIZE))
TCP_HIGH=$((TOTAL_MEM * 9 / 10 / PAGE_SIZE))

# UDP 内存计算（TCP 60%）
UDP_LOW=$((TCP_LOW * 6 / 10))
UDP_THRESH=$((TCP_THRESH * 6 / 10))
UDP_HIGH=$((TCP_HIGH * 6 / 10))

# 连接跟踪表最大值计算
conntrack_max=$(echo "$size_mb * 4096 / 8" | bc)

# ==================== 网络路由信息 ====================
GW=$(ip route show default | awk '/default/ {print $3; exit}')
DEV=$(ip route show default | awk '/default/ {print $5; exit}')

# ==================== 内存硬件信息 ====================
tcp_dyjs=$(sudo dmidecode -t memory | grep -i "Size:" | sed -e '/No Module Installed/d' -e 's/.*Size: \([0-9]\+\).*/\1/')
tcp_dy=$(echo "$tcp_dyjs * 128 / 4" | bc)

nic_list=$(ip link show | awk -F': ' '/^[0-9]+: / && $2 != "lo" {print $2}')

# ==================== 依赖检查与安装 ====================
# 在此添加脚本运行所需的命令，缺失将自动安装
REQUIRED_COMMANDS="sudo bc wget ethtool dmidecode ip ss"

check_and_install() {
    for cmd in $REQUIRED_COMMANDS; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${YELLOW}缺少命令: $cmd，正在安装...${RESET}"
            $PKG_INSTALL $cmd
        fi
    done
}

check_and_install


systemd_journald_optimize() {

# MODE=$1
CONF_FILE="/etc/systemd/journald.conf"
BACKUP_FILE="/etc/systemd/journald.conf.bak.$(date +%F_%T)"

if [[ ! "$MODE" =~ ^[1-4]$ ]]; then
  echo "用法: $0 [1|2|3|4]"
  echo "  1 - 不记录"
  echo "  2 - 经常用"
  echo "  3 - 低延迟 不压缩"
  echo "  4 - 低延迟 压缩"
  exit 1
fi

# 备份原配置
cp "$CONF_FILE" "$BACKUP_FILE"
echo "已备份原配置至 $BACKUP_FILE"

# 基础配置项 (清空旧的 [Journal] 部分)
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

# 重启服务应用更改
systemctl restart systemd-journald
echo "systemd-journald 服务已重启，配置生效。"

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
local version_new=$(curl -s https://raw.githubusercontent.com/cluntop/sh/main/tcp.sh | grep -o 'version="[0-9.]*"' | cut -d '"' -f 2)

if [ "$version" = "$version_new" ]; then
    echo "你已经是最新版本！"
else
    echo "发现新版本！"
    echo "当前版本 v$version 最新版本 v$version_new"
fi
    echo "1. 现在更新 0. 返回菜单"
    read -e -p "请输入你的选择: " choice
      case "$choice" in
      1)
        curl -s https://raw.githubusercontent.com/cluntop/sh/main/tcp.sh -o clun_tcp.sh && chmod +x clun_tcp.sh
        cp -f ~/clun_tcp.sh /usr/local/bin/tcp > /dev/null 2>&1
        ;;
      *) clun_tcp ;;
    esac
      # break_end
}

# ==================== 系统限制优化 ====================
Install_limits() {
cat >/etc/security/limits.conf<<EOF
* soft     nproc          1024000
* hard     nproc          1024000
* soft     nofile         1024000
* hard     nofile         1024000

root soft     nproc          1024000
root hard     nproc          1024000
root soft     nofile         1024000
root hard     nofile         1024000

bro soft     nproc          1024000
bro hard     nproc          1024000
bro soft     nofile         1024000
bro hard     nofile         1024000
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
  test -e /sys/devices/system/cpu/intel_pstate/no_turbo && echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo
  test -e /sys/devices/system/cpu/cpufreq/boost && echo 1 > /sys/devices/system/cpu/cpufreq/boost
  test -e /sys/devices/system/cpu/intel_pstate/max_perf_pct && echo 100 > /sys/devices/system/cpu/intel_pstate/max_perf_pct
  test -n "$(which auditctl)" && auditctl -a never,task >/dev/null 2>&1

  # 路由参数优化
  ip route change default via "$GW" dev "$DEV" initcwnd 32 initrwnd 32

  # 进程文件描述符限制
  ss -anptl | grep -oP 'pid=\K[0-9]+' | xargs -n1 -i sudo prlimit --pid {} --nofile=1048576

  # 网卡参数优化
  # ethtool -C $nic_interface rx-usecs 10 tx-usecs 10
  ethtool -K $nics sg on tx on rx on tso on gso on

  # 加载连接跟踪模块
  sudo modprobe ip_conntrack

  #  电源管理优化
  echo 0 > /sys/module/intel_idle/parameters/max_cstate
  echo "performance" > /sys/module/pcie_aspm/parameters/policy


  echo "install authencesn /bin/false" >> /etc/modprobe.d/security.conf

}

# ==================== 系统垃圾清理 ====================
cleaning_trash() {
sudo apt-get clean; sudo apt-get autoclean; sudo apt-get autoremove; sudo journalctl --rotate; sudo journalctl --vacuum-time=1s; sudo dpkg -l | grep '^rc' | awk '{print $2}' | sudo xargs dpkg --purge; sudo rm -rf /tmp/*; sudo rm -rf /var/tmp/*; sudo apt-get autoremove --purge; docker system prune -a -f; docker volume prune -f; docker network prune -f; docker image prune -a -f; docker container prune -f; docker builder prune -f; rm -rf ~/Downloads/*; rm -rf ~/.cache/thumbnails/*; rm -rf ~/.mozilla/firefox/*.default-release/cache2/*; sudo apt-get clean; dpkg --list | grep linux-image | grep -v `uname -r` | awk '{print $2}' | xargs sudo apt-get remove --purge -y
}

# ==================== Sysctl 配置应用 ====================
sysctl_p() {
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
  # sudo systemctl restart networking 2>/dev/null || true
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
curl -s -o "$tmp_new" "$sysctl_url"

if [[ $? -ne 0 ]]; then
    echo -e "${RED}✗ 下载配置文件失败.${RESET}"
    exit 1
fi

# 应用新配置
cp "$tmp_new" "$sysctl_conf"
echo -e "${GREEN}✓ 配置已应用.${RESET}"

# 显示配置变更
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
            echo -e "${WHITE:-\e[97m}$line${RESET}"
        fi
    done <<< "$diff_output"
fi

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

# 询问是否重启
read -p "→ 现在重启系统吗? [y/N]: " confirm
[[ "$confirm" =~ ^[Yy]$ ]] && reboot
}

# ==================== 网络诊断函数 ====================
lost_packet() {
ethtool -S $nic_interface | grep -e rx_no_buffer_count -e rx_missed_errors -e rx_fifo_errors -e rx_over_errors
}

check_buffer() {
ethtool -g $nic_interface
}

check_settings() {
ethtool -c $nic_interface
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
    echo "000. 科技 Lion 脚本工具箱"
    echo "---"
    echo "00. 更新脚本 0. 退出脚本"

    read -e -p "请输入你的选择: " choice

    case $choice in
      1) Install_All : clear ; exit ;;
      2) Install_limits ;;
      3) Install_systemd ;;
      4) Install_sysctl : clear ; exit ;;
      7) cleaning_trash : clear ; exit ;;
      8) tcp_info ;;
      9) Install_bbr ; clear ; exit ;;
      10) radical_sh ; clear ; exit ;;
      11)  clear ; exit ;;
      12) joey_install ; clear ; exit ;;
      13) lost_packet ;;
      14) check_buffer ;;
      15) check_settings ;;
      16) systemd_journald_optimize ;;
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