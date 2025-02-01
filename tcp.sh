#!/bin/bash
# Issues https://clun.top
# bash <(curl -sL clun.top)

version="1.0.2"

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
RESET='\033[0m'

if [[ $EUID -ne 0 ]]; then
    clear
    echo "Error: This script must be run as root!"
    echo "错误：此脚本必须以 root 身份运行!"
    exit 1
fi

sed -i '/^alias tcp=/d' ~/.bashrc > /dev/null 2>&1
sed -i '/^alias tcp=/d' ~/.profile > /dev/null 2>&1
sed -i '/^alias tcp=/d' ~/.bash_profile > /dev/null 2>&1
cp -f ./clun_tcp.sh ~/clun_tcp.sh > /dev/null 2>&1
cp -f ~/clun_tcp.sh /usr/local/bin/tcp > /dev/null 2>&1

# 获取系统内存大小（以 MB 为单位）
size_mb=$(grep MemTotal /proc/meminfo | awk '{print $2}')

tcp_low=$(echo "$size_mb * 4096 / 8" | bc)
tcp_mid=$(echo "$size_mb * 4096 / 4" | bc)
tcp_high=$(echo "$size_mb * 4096 / 2" | bc)

udp_low=$(echo "$size_mb * 2048 / 8" | bc)
udp_mid=$(echo "$size_mb * 2048 / 4" | bc)
udp_high=$(echo "$size_mb * 2048 / 2" | bc)

conntrack_max=$(echo "$size_mb * 1024 / 16384 / 2" | bc)

break_end() {
    echo "操作完成"
    echo "按任意键继续..."
    read -n 1 -s -r -p ""
    echo ""
    clear
}

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
        curl -o clun_tcp.sh https://raw.githubusercontent.com/cluntop/sh/main/tcp.sh && chmod +x clun_tcp.sh
        cp -f ~/clun_tcp.sh /usr/local/bin/tcp > /dev/null 2>&1
        ;;
      2)
        bash <(curl -sL clun.top)
	       ;;
      *) clun_tcp ;;
    esac
      break_end
}

Install_limits() {
cat >/etc/security/limits.conf<<EOF
* soft     nproc          1000000
* hard     nproc          1000000
* soft     nofile         1000000
* hard     nofile         1000000

root soft     nproc          1000000
root hard     nproc          1000000
root soft     nofile         1000000
root hard     nofile         1000000

bro soft     nproc          1000000
bro hard     nproc          1000000
bro soft     nofile         1000000
bro hard     nofile         1000000
EOF
}

Install_systemd() {

if grep -q 'pam_limits.so' /etc/pam.d/common-session-noninteractive; then
    echo "common-session-noninteractive  Existence ok."
else
    sed -i '/^session required pam_limits.so/d' /etc/pam.d/common-session-noninteractive
    echo "session required pam_limits.so" >> /etc/pam.d/common-session-noninteractive
fi

if grep -q 'DefaultLimitNOFILE=65536' /etc/systemd/system.conf; then
    echo "DefaultLimitNOFILE Existence ok."
else
    sed -i '/^DefaultLimitNOFILE=/d' /etc/systemd/system.conf
    echo "DefaultLimitNOFILE=65536" >> /etc/systemd/system.conf
fi

if grep -q 'pam_limits.so' /etc/pam.d/common-session; then
    echo "common-session Existence ok."
else
    sed -i '/^session required pam_limits.so/d' /etc/pam.d/common-session
    echo "session required pam_limits.so" >> /etc/pam.d/common-session
fi

}

calculate_tcp() {
sed -i "s/#*net.ipv4.tcp_mem.*/net.ipv4.tcp_mem = $tcp_low $tcp_mid $tcp_high/" /etc/sysctl.conf
}

calculate_udp() {
sed -i "s/#*net.ipv4.udp_mem =.*/net.ipv4.udp_mem = $udp_low $udp_mid $udp_high/" /etc/sysctl.conf
}

cleaning_trash() {
sudo apt-get clean; sudo apt-get autoclean; sudo apt-get autoremove; sudo journalctl --rotate; sudo journalctl --vacuum-time=1s; sudo dpkg -l | grep '^rc' | awk '{print $2}' | sudo xargs dpkg --purge; sudo rm -rf /tmp/*; sudo rm -rf /var/tmp/*; sudo apt-get autoremove --purge; docker system prune -a -f; docker volume prune -f; docker network prune -f; docker image prune -a -f; docker container prune -f; docker builder prune -f; rm -rf ~/Downloads/*; rm -rf ~/.cache/thumbnails/*; rm -rf ~/.mozilla/firefox/*.default-release/cache2/*; sudo apt-get clean; dpkg --list | grep linux-image | grep -v `uname -r` | awk '{print $2}' | xargs sudo apt-get remove --purge -y
}

sysctl_p() {
sysctl -p >/dev/null 2>&1
sysctl --system >/dev/null 2>&1
}

kejilion_sh() {
curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh && chmod +x kejilion.sh && ./kejilion.sh
}

Install_All() {
Install_limits; Install_systemd; Install_sysctl; calculate_tcp; calculate_udp;
}

Install_sysctl() {

cat >/etc/sysctl.conf<<EOF

#
# /etc/sysctl.conf - Configuration file for setting system variables
# See /etc/sysctl.d/ for additional system variables.
# See sysctl.conf (5) for information.
#

net.core.default_qdisc=fq_pie
net.ipv4.tcp_congestion_control=bbr2

net.ipv4.tcp_invalid_ratelimit = 10000

#kernel.domainname = example.com

# Uncomment the following to stop low-level messages on console
#kernel.printk = 3 4 1 3

###################################################################
# Functions previously found in netbase
#

# Uncomment the next two lines to enable Spoof protection (reverse-path filter)
# Turn on Source Address Verification in all interfaces to
# prevent some spoofing attacks
#net.ipv4.conf.default.rp_filter=1
#net.ipv4.conf.all.rp_filter=1

# Uncomment the next line to enable TCP/IP SYN cookies
# See http://lwn.net/Articles/277146/
# Note: This may impact IPv6 TCP sessions too
#net.ipv4.tcp_syncookies=1

# Uncomment the next line to enable packet forwarding for IPv4
#net.ipv4.ip_forward=1

# Uncomment the next line to enable packet forwarding for IPv6
#  Enabling this option disables Stateless Address Autoconfiguration
#  based on Router Advertisements for this host
#net.ipv6.conf.all.forwarding=1


###################################################################
# Additional settings - these settings can improve the network
# security of the host and prevent against some network attacks
# including spoofing attacks and man in the middle attacks through
# redirection. Some network environments, however, require that these
# settings are disabled so review and enable them as needed.
#
# Do not accept ICMP redirects (prevent MITM attacks)
#net.ipv4.conf.all.accept_redirects = 0
#net.ipv6.conf.all.accept_redirects = 0
# _or_
# Accept ICMP redirects only for gateways listed in our default
# gateway list (enabled by default)
# net.ipv4.conf.all.secure_redirects = 1
#
# Do not send ICMP redirects (we are not a router)
#net.ipv4.conf.all.send_redirects = 0
#
# Do not accept IP source route packets (we are not a router)
#net.ipv4.conf.all.accept_source_route = 0
#net.ipv6.conf.all.accept_source_route = 0
#
# Log Martian Packets
#net.ipv4.conf.all.log_martians = 1
#

###################################################################
# Magic system request Key
# 0=disable, 1=enable all, >1 bitmask of sysrq functions
# See https://www.kernel.org/doc/html/latest/admin-guide/sysrq.html
# for what other values do
#kernel.sysrq=438


# ------ 网络调优: 基本 ------
# TTL 配置, Linux 默认 64
# net.ipv4.ip_default_ttl = 64

# 参阅 RFC 1323. 应当启用.
# net.ipv4.tcp_timestamps = 0
# ------ END 网络调优: 基本 ------

# ------ 网络调优: 内核 Backlog 队列和缓存相关 ------
# Ref: https://www.starduster.me/2020/03/02/linux-network-tuning-kernel-parameter/
# Ref: https://blog.cloudflare.com/optimizing-tcp-for-high-throughput-and-low-latency/
# Ref: https://zhuanlan.zhihu.com/p/149372947
# https://github.com/torvalds/linux/blob/87d6aab2389e5ce0197d8257d5f8ee965a67c4cd/net/ipv4/tcp_output.c#L241-L248
#net.ipv4. tcp_mem = 65536 131072 12582912
#net.ipv4. udp_mem = 65536 131072 12582912

net.ipv4.tcp_mem = $tcp_low $tcp_mid $tcp_high
net.ipv4.udp_mem = $udp_low $udp_mid $udp_high

# 全局套接字默认接受缓冲区 # 212992
net.core.rmem_default = 65535
net.core.rmem_max = 536870912
# 全局套接字默认发送缓冲区 # 212992
net.core.wmem_default = 65535
net.core.wmem_max = 536870912

# 由左往右为 最小值 默认值 最大值
# 有条件建议依据实测结果调整 tcp_rmem, tcp_wmem 相关数值
# 个人实测差别不大, 可能是我网本来就比较好
# 缓冲区相关配置均和内存相关 # 6291456
net.ipv4.tcp_rmem = 65534 37500000 536870912
net.ipv4.tcp_wmem = 65534 37500000 536870912
net.ipv4.tcp_adv_win_scale = -2
# net.ipv4.tcp_collapse_max_bytes = 6291456
# net.ipv4.tcp_notsent_lowat = 131072
net.ipv4.ip_local_port_range = 1024 65535
# 每个网络接口接收数据包的速率比内核处理这些包的速率快时，允许送到队列的数据包的最大数目。
net.core.netdev_max_backlog = 102400
# 181920 listen 函数的 backlog 参数
net.ipv4.tcp_max_syn_backlog = 30720
net.core.somaxconn = 10240
# 配置TCP/IP协议栈。控制在TCP接收缓冲区溢出时的行为。
net.ipv4.tcp_abort_on_overflow = 0
# 所有网卡每次软中断最多处理的总帧数量
net.core.netdev_budget = 50000
net.core.netdev_budget_usecs = 5000
# TCP 自动窗口
# 要支持超过 64KB 的 TCP 窗口必须启用
net.ipv4.tcp_window_scaling = 1
# 开启后, TCP 拥塞窗口会在一个 RTO 时间
# 空闲之后重置为初始拥塞窗口 (CWND) 大小.
# 大部分情况下, 尤其是大流量长连接, 设置为 0.
# 对于网络情况时刻在相对剧烈变化的场景, 设置为 1.
net.ipv4.tcp_slow_start_after_idle = 0
# nf_conntrack 调优
# Add Ref: https://gist.github.com/lixingcong/0e13b4123d29a465e364e230b2e45f60
net.nf_conntrack_max = $conntrack_max
net.netfilter.nf_conntrack_max = $conntrack_max
net.netfilter.nf_conntrack_buckets = 655360
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_established = 36000
# TIME-WAIT 状态调优
# Ref: http://vincent.bernat.im/en/blog/2014-tcp-time-wait-state-linux.html
# Ref: https://www.cnblogs.com/lulu/p/4149312.html
# 4.12 内核中此参数已经永久废弃, 不用纠结是否需要开启
# net.ipv4.tcp_tw_recycle = 0
## 只对客户端生效, 服务器连接上游时也认为是客户端
net.ipv4.tcp_tw_reuse = 1
# 系统同时保持TIME_WAIT套接字的最大数量
# 如果超过这个数字 TIME_WAIT 套接字将立刻被清除
net.ipv4.tcp_max_tw_buckets = 100000
# ------ END 网络调优: 内核 Backlog 队列和缓存相关 ------

# ------ 网络调优: 其他 ------
# Ref: https://zhuanlan.zhihu.com/p/149372947
# Ref: https://www.starduster.me/2020/03/02/linux-network-tuning-kernel-parameter/\#netipv4tcp_max_syn_backlog_netipv4tcp_syncookies
# 启用选择应答
# 对于广域网通信应当启用
net.ipv4.tcp_sack = 1
# 启用转发应答
# 对于广域网通信应当启用
net.ipv4.tcp_fack = 1
# 它主要用于控制TCP连接在发生超时后的快速恢复策略。
net.ipv4.tcp_frto = 0
# 是一种用于在IP网络中传递拥塞信息的机制。
net.ipv4.tcp_ecn = 0
# TCP SYN 连接超时重传次数
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
# TCP SYN 连接超时时间, 设置为 5 约为 30s
# 在丢弃激活(已建立通讯状况)的 TCP 连接之前, 需要进行多少次重试
net.ipv4.tcp_retries2 = 5
# 开启 SYN 洪水攻击保护
net.ipv4.tcp_syncookies = 0

# Ref: https://linuxgeeks.github.io/2017/03/20/212135-Linux%E5%86%85%E6%A0%B8%E5%8F%82%E6%95%B0rp_filter/
# 开启反向路径过滤
# Aliyun 负载均衡实例后端的 ECS 需要设置为 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.all.rp_filter = 0

# 减少处于 FIN-WAIT-2
# 连接状态的时间使系统可以处理更多的连接
net.ipv4.tcp_fin_timeout = 15

# Ref: https://xwl-note.readthedocs.io/en/latest/linux/tuning.html
# 默认情况下一个 TCP 连接关闭后, 把这个连接曾经有的参数保存到dst_entry中
# 只要 dst_entry 没有失效, 下次新建立相同连接的时候就可以使用保存的参数来初始化这个连接.
# 通常情况下是关闭的, 高并发配置为 1.
net.ipv4.tcp_no_metrics_save = 1
# unix socket 最大队列
net.unix.max_dgram_qlen = 1024
# 路由缓存刷新频率
net.ipv4.route.gc_timeout = 100
# 它用于控制是否忽略所有的ICMP Echo请求。
net.ipv4.icmp_echo_ignore_all = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ref: https://gist.github.com/lixingcong/0e13b4123d29a465e364e230b2e45f60
# 启用 MTU 探测，在链路上存在 ICMP 黑洞时候有用（大多数情况是这样）
net.ipv4.tcp_mtu_probing = 0

# 用于指定UDP（用户数据报协议）接收缓冲区的最小大小。
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192

# No Ref
# 开启并记录欺骗, 源路由和重定向包
# net.ipv4.conf.all.log_martians = 1
# net.ipv4.conf.default.log_martians = 1
# 处理无源路由的包
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
# TCP KeepAlive 调优 # 最大闲置时间
net.ipv4.tcp_keepalive_time = 600
# 最大失败次数, 超过此值后将通知应用层连接失效
net.ipv4.tcp_keepalive_probes = 6
# 发送探测包的时间间隔
net.ipv4.tcp_keepalive_intvl = 60
# 放弃回应一个 TCP 连接请求前, 需要进行多少次重试
net.ipv4.tcp_retries1 = 3
# 参数规定了在系统尝试清除这些孤儿连接之前可以重试的次数。
net.ipv4.tcp_orphan_retries = 1
# 系统所能处理不属于任何进程的TCP sockets最大数量
# 系统中最多有多少个 TCP 套接字不被关联到任何一个用户文件句柄上
net.ipv4.tcp_max_orphans = 65535
# arp_table的缓存限制优化
# net.ipv4.neigh.default.gc_thresh1 = 128
# net.ipv4.neigh.default.gc_thresh2 = 512
# net.ipv4.neigh.default.gc_thresh3 = 1024
# net.ipv6.neigh.default.gc_thresh3 = 1024
# net.ipv6.neigh.default.gc_thresh2 = 512
# net.ipv6.neigh.default.gc_thresh1 = 128
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv6.neigh.default.gc_stale_time = 120
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2
# ------ END 网络调优: 其他 ------

# ------ 内核调优 ------

# Ref: Aliyun, etc
# 内核 Panic 后 1 秒自动重启
#kernel.panic = 0
# 允许更多的PIDs, 减少滚动翻转问题
# kernel.pid_max = 32768
# 内核所允许的最大共享内存段的大小（bytes）
# kernel.shmmax = 4294967296
# 在任何给定时刻, 系统上可以使用的共享内存的总量（pages）
# kernel.shmall = 1073741824
# 设定程序core时生成的文件名格式
kernel.core_pattern = core_%e
# 当发生oom时, 自动转换为panic
#vm.panic_on_oom = 0
# 控制内存“脏数据”（dirty data）积累的后台内存比例。
vm.dirty_background_ratio = 5
# 表示强制Linux VM最低保留多少空闲内存（Kbytes）
vm.min_free_kbytes = 128
# 该值高于100, 则将导致内核倾向于回收directory和inode cache
# vm.vfs_cache_pressure = 50
# 表示系统进行交换行为的程度, 数值（0-100）越高, 越可能发生磁盘交换
vm.swappiness = 10
# 仅用10%做为系统cache
vm.dirty_ratio = 10
vm.overcommit_memory = 1
# 增加系统文件描述符限制
# Fix error: too many open files
# fs.file-max = 1024000
fs.inotify.max_user_instances = 524288
# 设置 inotify 监视的最大用户监视器数量。
fs.inotify.max_user_watches = 524288
# fs.nr_open = 1024000
# 内核响应魔术键
kernel.sysrq = 1
# 优化 CPU 设置
kernel.sched_autogroup_enabled = 0
# 禁用 NUMA balancing
kernel.numa_balancing = 0
# IPv4 TCP 低延迟参数
net.ipv4.tcp_low_latency = 0

# Ref: https://gist.github.com/lixingcong/0e13b4123d29a465e364e230b2e45f60
# 当某个节点可用内存不足时, 系统会倾向于从其他节点分配内存. 对 Mongo/Redis 类 cache 服务器友好
vm.zone_reclaim_mode = 2

# Ref: Unknwon
# 开启F-RTO(针对TCP重传超时的增强的恢复算法).
# 在无线环境下特别有益处, 因为在这种环境下分组丢失典型地是因为随机无线电干扰而不是中间路由器阻塞
# net.ipv4.tcp_frto = 1
# TCP FastOpen
net.ipv4.tcp_fastopen = 3
# TCP 流中重排序的数据报最大数量
net.ipv4.tcp_reordering = 300
# 开启后, 在重传时会试图发送满大小的包. 这是对一些有 BUG 的打印机的绕过方式
net.ipv4.tcp_retrans_collapse = 0
# 自动阻塞判断
net.ipv4.tcp_autocorking = 0
# TCP内存自动调整
net.ipv4.tcp_moderate_rcvbuf = 1
# 单个TSO段可消耗拥塞窗口的比例, 默认值为 3
net.ipv4.tcp_tso_win_divisor = 3
# 对于在 RFC1337 中描述的 TIME-WAIT Assassination Hazards in TCP 问题的修复
net.ipv4.tcp_rfc1337 = 0
# 包转发. 出于安全考虑, Linux 系统默认禁止数据包转发
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv4.conf.default.forwarding = 1
net.ipv4.conf.all.route_localnet = 1
# 取消对广播 ICMP 包的回应
net.ipv4.icmp_echo_ignore_broadcasts = 1
# 开启恶意 ICMP 错误消息保护
net.ipv4.icmp_ignore_bogus_error_responses = 1

# 设置控制所有网络接口上 IPv6 地址的自动配置
net.ipv6.conf.all.autoconf = 1
net.ipv6.conf.eth0.autoconf = 1

# 控制所有接口是否接受路由器通告（Router Advertisements, RA）
net.ipv6.conf.all.accept_ra = 1
net.ipv6.conf.eth0.accept_ra = 1

# 1 = IPv4 优先 / 0 = 6 优先
# net.ipv6.conf.all.disable_ipv6 = 1

# 控制未解析（unresolved）的邻居（neighbor）项队列长度。
net.ipv4.neigh.default.unres_qlen = 1000
net.ipv4.neigh.default.unres_qlen_bytes = 16777216

#ARP缓存的过期时间（单位毫秒）
net.ipv4.neigh.default.base_reachable_time_ms = 600000

#在把记录标记为不可达之前，用多播/广播方式解析地址的最大次数
net.ipv4.neigh.default.mcast_solicit = 20

# 重发一个ARP请求前等待毫秒数
net.ipv4.neigh.default.retrans_time_ms = 280

# Linux内核中用于配置接收数据包导向（Receive Packet Steering，RPS）和接收流导向（Receive Flow Steering，RFS）功能
# net.core.rps_sock_flow_entries = 10000

EOF

file_sysctl="/etc/sysctl.d/99-sysctl.conf"
if [ ! -f "$file_sysctl" ]; then
    echo "$file_sysctl 文件不存在，开始执行 ln"
    ln -s /etc/sysctl.conf /etc/sysctl.d/99-sysctl.conf
else
    echo "$file_sysctl 文件存在，不执行 ln"
fi

sysctl_p
}

clun_tcp() {
while true; do
    clear
    echo "当前版本 v$version"
    echo "更新提交问题 t.me/clungit"
    echo "命令行输入 tcp 可快速启动脚本"
    echo "---"
    echo "1. 优化全部 2. 优化限制"
    echo "3. 优化安全 4. 优化内核"
    echo "5. 优化TCP 6. 优化UDP"
    echo "---"
    echo "7. 清理垃圾 8. 安装 科技lion"
    echo "---"
    echo "00. 更新脚本 0. 退出脚本"

    read -e -p "请输入你的选择: " choice

    case $choice in
      1) Install_All ;;
      2) Install_limits ;;
      3) Install_systemd ;;
      4) Install_sysctl ;;
      5) calculate_tcp ; sysctl_p ; clun_tcp ;;
      6) calculate_udp ; sysctl_p ; clun_tcp ;;
      7) cleaning_trash ;;
      8) kejilion_sh ;;
      00) update_script ;;
      0) clear ; exit ;;
      *) echo "无效的输入!" ;;
    esac
        break_end
    echo
done
}

case $1 in
    "tcp")
	  # 设置定时任务字符串
	  cron_clun="0 * * * * /bin/bash -c "bash <(curl -sL clun.top) tcp""
	  # 检查是否存在相同的定时任务
	  clun_cron=$(crontab -l 2>/dev/null | grep -F "$cron_clun")
	  # 如果不存在，则添加定时任务
	  if [ -z "$clun_cron" ]; then
	    (crontab -l 2>/dev/null; echo "$cron_clun") | crontab -
		echo "优化内核任务已添加"
	  fi
	  ;;
    *) clun_tcp ;;
esac

# sleep 1 && 
# clun_tcp
