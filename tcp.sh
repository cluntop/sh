#!/bin/bash
# Issues https://clun.top
# bash <(curl -sL clun.top)

version="1.1.9"
version_test="206"

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
RESET='\033[0m'

backup_bak="/etc/sysctl.conf.bak"
tmp_new="/tmp/sysctl.new"
sysctl_conf="/etc/sysctl.conf"
sysctl_url="https://raw.githubusercontent.com/cluntop/sh/main/conf.d/sysctl.conf"

sed -i '/^alias tcp=/d' ~/.bashrc > /dev/null 2>&1
sed -i '/^alias tcp=/d' ~/.profile > /dev/null 2>&1
sed -i '/^alias tcp=/d' ~/.bash_profile > /dev/null 2>&1
cp -f ./clun_tcp.sh ~/clun_tcp.sh > /dev/null 2>&1
cp -f ~/clun_tcp.sh /usr/local/bin/tcp > /dev/null 2>&1

PAGE_SIZE=$(getconf PAGESIZE)

size_mb=$(free -m | awk '/Mem:/ {print $2}')

tcp_low=$(echo "$size_mb * 16" | bc)
tcp_mid=$(echo "$size_mb * 32" | bc)
tcp_high=$(echo "$size_mb * 48" | bc)

udp_low=$(echo "$size_mb * 18" | bc)
udp_mid=$(echo "$size_mb * 36" | bc)
udp_high=$(echo "$size_mb * 54" | bc)


TOTAL_MEM=$(grep MemTotal /proc/meminfo | awk '{print $2}')

# TCP 内存计算
TCP_LOW=$((TOTAL_MEM * 2 / 3 / PAGE_SIZE))
TCP_THRESH=$((TOTAL_MEM * 3 / 4 / PAGE_SIZE))
TCP_HIGH=$((TOTAL_MEM * 9 / 10 / PAGE_SIZE))

# UDP 内存计算（TCP 60%）
UDP_LOW=$((TCP_LOW * 6 / 10))
UDP_THRESH=$((TCP_THRESH * 6 / 10))
UDP_HIGH=$((TCP_HIGH * 6 / 10))

conntrack_max=$(echo "$size_mb * 4096 / 8" | bc)

tcp_dyjs=$(sudo dmidecode -t memory | grep -i "Size:" | sed -e '/No Module Installed/d' -e 's/.*Size: \([0-9]\+\).*/\1/')
tcp_dy=$(echo "$tcp_dyjs * 128 / 4" | bc)

nic_list() {
    ip link show | awk -F': ' '/^[0-9]+: / && $2 != "lo" {print $2}'
}

break_end() {
    # echo "操作完成"
    echo "按任意键继续..."
    read -n 1 -s -r -p ""
    echo ""
    clear
}

update_script() {
local version_new=$(curl -s https://gh.clun.top/raw.githubusercontent.com/cluntop/sh/main/tcp.sh | grep -o 'version="[0-9.]*"' | cut -d '"' -f 2)

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
        curl -s https://gh.clun.top/raw.githubusercontent.com/cluntop/sh/main/tcp.sh -o clun_tcp.sh && chmod +x clun_tcp.sh
        cp -f ~/clun_tcp.sh /usr/local/bin/tcp > /dev/null 2>&1
        ;;
      *) clun_tcp ;;
    esac
      # break_end
}

Install_limits() {
cat >/etc/security/limits.conf<<EOF
* soft     nproc          2097152
* hard     nproc          2097152
* soft     nofile         2097152
* hard     nofile         2097152

root soft     nproc          2097152
root hard     nproc          2097152
root soft     nofile         2097152
root hard     nofile         2097152

bro soft     nproc          2097152
bro hard     nproc          2097152
bro soft     nofile         2097152
bro hard     nofile         2097152
EOF
}

Install_systemd() {

if grep -q 'pam_limits.so' /etc/pam.d/common-session-noninteractive; then
    echo "common-session-noninteractive  Existence ok."
else
    sed -i '/^session required pam_limits.so/d' /etc/pam.d/common-session-noninteractive
    echo "session required pam_limits.so" >> /etc/pam.d/common-session-noninteractive
fi

if grep -q 'pam_limits.so' /etc/pam.d/common-session; then
    echo "common-session Existence ok."
else
    sed -i '/^session required pam_limits.so/d' /etc/pam.d/common-session
    echo "session required pam_limits.so" >> /etc/pam.d/common-session
fi

echo never >/sys/kernel/mm/transparent_hugepage/enabled

}

cleaning_trash() {
curl -s https://gh.clun.top/raw.githubusercontent.com/cluntop/sh/refs/heads/main/trash.sh && chmod +x trash.sh && ./trash.sh
}

ethtool_sh() {
 local nic=$1

 ethtool -K $nic tx-checksumming on rx-checksumming on
 ethtool -K $nic tso on ufo on
 ethtool -K $nic rxvlan on

 local nics=$(nic_list)

 for nic in $nics; do
  ethtool_sh $nic
 done

}

sysctl_p() {
sysctl -p >/dev/null 2>&1
sysctl --system >/dev/null 2>&1
}

Install_bbr() {
wget -O tcpx.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcpx.sh" && chmod +x tcpx.sh && ./tcpx.sh
}

kejilion_sh() {
curl -s -O https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh && chmod +x kejilion.sh && ./kejilion.sh
}


joey_install() {
bash <(curl -l -s https://raw.githubusercontent.com/byJoey/Actions-bbr-v3/refs/heads/main/install.sh)
}

radical_sh() {
bash <(curl -Ls https://raw.githubusercontent.com/Shellgate/tcp_optimization_bbr/main/bbr.sh)
}

Install_All() {
Install_limits; Install_systemd; Install_sysctl; ethtool_sh; joey_install;
}

Install_sysctl() {

[[ -f "$backup_bak" ]] && rm -f "$backup_bak"
cp "$sysctl_conf" "$backup_bak"
echo -e "${GREEN}✓ 备份已保存至 $backup_bak${RESET}"

curl -s -o "$tmp_new" "$sysctl_url"

if [[ $? -ne 0 ]]; then
    echo -e "${RED}✗ 下载配置文件失败.${RESET}"
    exit 1
fi

cp "$tmp_new" "$sysctl_conf"
echo -e "${GREEN}✓ 配置已应用.${RESET}"

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

file_sysctl="/etc/sysctl.d/99-sysctl.conf"

if [ ! -f "$file_sysctl" ]; then
    echo "$file_sysctl 文件不存在，开始执行 ln"
    ln -s /etc/sysctl.conf /etc/sysctl.d/99-sysctl.conf
else
    echo "99-sysctl.conf 文件存在，不执行 ln"
fi

# sysctl -w net.ipv4.tcp_mem="$TCP_LOW $TCP_THRESH $TCP_HIGH"
# sysctl -w net.ipv4.udp_mem="$UDP_LOW $UDP_THRESH $UDP_HIGH"

ip tcp_metrics flush all > /dev/null 2>&1

sysctl_p

read -p "→ 现在重启系统吗? [y/N]: " confirm
[[ "$confirm" =~ ^[Yy]$ ]] && reboot
}

tcp_info() {
echo "---"
echo "以下是命令参考用例："
echo "启动脚本 tcp"
echo "优化内核 tcp tcp"
echo "优化内核任务 tcp sys"
}

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
    echo "11. 优化网卡 12. 内核脚本"
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
      11) ethtool_sh ; clear ; exit ;;
      12) joey_install ; clear ; exit ;;
      000) kejilion_sh ; clear ; exit ;;
      00) update_script ; clear ; exit ;;
      0) clear ; exit ;;
      *) echo "无效的输入!" ;;
    esac
      break_end
    echo
done
}

case $1 in
    "sys")
      # 设置定时任务字符串
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
