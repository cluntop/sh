#!/bin/bash
# Issues https://clun.top
# bash <(curl -sL clun.top)

version="1.1.7"
version_test="182"

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
RESET='\033[0m'

sed -i '/^alias tcp=/d' ~/.bashrc > /dev/null 2>&1
sed -i '/^alias tcp=/d' ~/.profile > /dev/null 2>&1
sed -i '/^alias tcp=/d' ~/.bash_profile > /dev/null 2>&1
cp -f ./clun_tcp.sh ~/clun_tcp.sh > /dev/null 2>&1
cp -f ~/clun_tcp.sh /usr/local/bin/tcp > /dev/null 2>&1

size_mb=$(free -m | awk '/Mem:/ {print $2}')

tcp_low=$(echo "$size_mb * 1024 / 32" | bc)
tcp_mid=$(echo "$size_mb * 1024 / 16" | bc)
tcp_high=$(echo "$size_mb * 1024 / 8" | bc)

udp_low=$(echo "$size_mb * 1024 / 30" | bc)
udp_mid=$(echo "$size_mb * 1024 / 14" | bc)
udp_high=$(echo "$size_mb * 1024 / 6" | bc)

conntrack_max=$(echo "$size_mb * 65536 / 4" | bc)

tcp_dyjs=$(sudo dmidecode -t memory | grep -i "Size:" | sed -e '/No Module Installed/d' -e 's/.*Size: \([0-9]\+\).*/\1/')
tcp_dy=$(echo "$tcp_dyjs * 16 / 2" | bc)

break_end() {
    echo "操作完成"
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
      break_end
}

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

}

calculate_tcp() {
sed -i "s/#*net.ipv4.tcp_mem.*/net.ipv4.tcp_mem = $tcp_low $tcp_mid $tcp_high/" /etc/sysctl.conf
}

calculate_udp() {
sed -i "s/#*net.ipv4.udp_mem =.*/net.ipv4.udp_mem = $udp_low $udp_mid $udp_high/" /etc/sysctl.conf
}

cleaning_trash() {
curl -s https://gh.clun.top/raw.githubusercontent.com/cluntop/sh/refs/heads/main/trash.sh && chmod +x trash.sh && ./trash.sh
}

sysctl_p() {
sysctl -p >/dev/null 2>&1
sysctl --system >/dev/null 2>&1
}
Install_bbr() {
wget -O tcpx.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcpx.sh" && chmod +x tcpx.sh && ./tcpx.sh
}

kejilion_sh() {
curl -s -O https://gh.clun.top/raw.githubusercontent.com/kejilion/sh/main/kejilion.sh && chmod +x kejilion.sh && ./kejilion.sh
}

Install_All() {
Install_limits; Install_systemd; Install_sysctl; calculate_tcp; calculate_udp;
}

Install_sysctl() {

cat >/etc/sysctl.conf<<EOF

net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq_pie

net.ipv4.tcp_mem = $tcp_low $tcp_mid $tcp_high
net.ipv4.udp_mem = $udp_low $udp_mid $udp_high

# vm.max_map_count = 262144
# vm.nr_hugepages = $tcp_dy

# 控制 Linux 内核是否启用接收窗口的智能收缩机制
net.ipv4.tcp_shrink_window = 1

# 设置 TCP 接收缓冲区内存合并的最大字节数阈值
# net.ipv4.tcp_collapse_max_bytes = 6291456

# 设置 TCP 发送缓冲区中“未发送数据量”的低水位阈值
# net.ipv4.tcp_notsent_lowat = 131072

# 允许路由本地环回网络的流量
net.ipv4.conf.all.route_localnet = 1

# 启用 TCP 的早期重传机制
net.ipv4.tcp_early_retrans = 1

# 全局套接字默认接受缓冲区
# 212992 # 212992 #26214400
net.core.rmem_default = 262144
net.core.rmem_max = 536870912

# 全局套接字默认发送缓冲区
# 212992 # 212992 #26214400
net.core.wmem_default = 262144
net.core.wmem_max = 536870912

# 控制单个套接字（socket）
net.core.optmem_max = 262144

# 缓冲区相关配置均和内存相关 # 6291456
net.ipv4.tcp_rmem = 65536 699040 536870912
net.ipv4.tcp_wmem = 65536 524288 536870912
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_adv_win_scale = -2

# 半连接队列大小（SYN 队列）
net.ipv4.tcp_max_syn_backlog = 250000

# 网卡接收队列大小（所有协议数据包）
net.core.netdev_max_backlog = 131072

# 全连接队列大小（Accept 队列）
net.core.somaxconn = 65536

# 控制 TCP 连接队列溢出行为的核心参数
net.ipv4.tcp_abort_on_overflow = 0

# 所有网卡每次软中断最多处理的总帧数量
net.core.netdev_budget = 70000
net.core.netdev_budget_usecs = 1000

# TCP 自动窗口
# 要支持超过 64KB 的 TCP 窗口必须启用
net.ipv4.tcp_window_scaling = 1

# TCP 拥塞窗口会在一个 RTO 时间
net.ipv4.tcp_slow_start_after_idle = 0

# nf_conntrack 调优
net.nf_conntrack_max = $conntrack_max
net.netfilter.nf_conntrack_max = $conntrack_max
net.netfilter.nf_conntrack_buckets = 655360
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_established = 180

# 只对客户端生效, 服务器连接上游时也认为是客户端
net.ipv4.tcp_tw_reuse = 1

# 系统同时保持TIME_WAIT套接字的最大数量
# 如果超过这个数字 TIME_WAIT 套接字将立刻被清除
net.ipv4.tcp_max_tw_buckets = 1024000

# 启用选择应答
# 对于广域网通信应当启用
net.ipv4.tcp_sack = 1

# 启用转发应答
# 对于广域网通信应当启用
net.ipv4.tcp_fack = 1

# 开启F-RTO(针对TCP重传超时的增强的恢复算法).
net.ipv4.tcp_frto = 0

# 是一种用于在IP网络中传递拥塞信息的机制。
net.ipv4.tcp_ecn = 0

# TCP SYN 连接超时重传次数
net.ipv4.tcp_synack_retries = 5
net.ipv4.tcp_syn_retries = 4

# TCP SYN 连接超时时间, 设置为 5 约为 30s
# 放弃回应一个 TCP 连接请求前, 需要进行多少次重试
net.ipv4.tcp_retries1 = 5

# 在丢弃激活(已建立通讯状况)的 TCP 连接之前, 需要进行多少次重试
net.ipv4.tcp_retries2 = 8

# 开启 SYN 洪水攻击保护
net.ipv4.tcp_syncookies = 0

# 开启反向路径过滤
# Aliyun 负载均衡实例后端的 ECS 需要设置为 0
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.rp_filter = 1

# 减少处于 FIN-WAIT-2
# 连接状态的时间使系统可以处理更多的连接
net.ipv4.tcp_fin_timeout = 30

# unix socket 最大队列
net.unix.max_dgram_qlen = 65536

# 路由缓存刷新频率
net.ipv4.route.gc_timeout = 100

# 它用于控制是否忽略所有的ICMP Echo请求
net.ipv4.icmp_echo_ignore_all = 1

# 取消对广播 ICMP 包的回应
net.ipv4.icmp_echo_ignore_broadcasts = 1

# 控制 ICMP 错误消息的源地址选择逻辑
net.ipv4.icmp_errors_use_inbound_ifaddr = 1

# 开启恶意 ICMP 错误消息保护
net.ipv4.icmp_ignore_bogus_error_responses = 1

# TCP基础最大报文段大小 MSS
net.ipv4.tcp_base_mss = 1460

# 启用 MTU 探测，在链路上存在 ICMP 黑洞时候有用
net.ipv4.tcp_mtu_probing = 1
# net.ipv4.tcp_mtu_probe_floor = 576

# 控制是否保存 TCP 连接的度量值到路由缓存中
net.ipv4.tcp_no_metrics_save = 1

# 控制 TCP 初始拥塞窗口的大小
net.ipv4.tcp_init_cwnd = 96

# 控制 TCP 紧急指针的解释方式
net.ipv4.tcp_stdurg = 0

# 控制是否启用 路径 MTU 发现
net.ipv4.ip_no_pmtu_disc = 0

# 用于指定UDP接收缓冲区的最小大小
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384

# 处理无源路由的包
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# TCP KeepAlive 调优 # 最大闲置时间
net.ipv4.tcp_keepalive_time = 900

# 最大失败次数, 超过此值后将通知应用层连接失效
net.ipv4.tcp_keepalive_probes = 9

# 缩短 tcp keepalive 发送探测包的时间间隔
net.ipv4.tcp_keepalive_intvl = 60

# 参数规定了在系统尝试清除这些孤儿连接之前可以重试的次数。
net.ipv4.tcp_orphan_retries = 1

# 系统所能处理不属于任何进程的TCP sockets最大数量
# 系统中最多有多少个 TCP 套接字不被关联到任何一个用户文件句柄上
# net.ipv4.tcp_max_orphans = 65536

# arp_table的缓存限制优化
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv6.neigh.default.gc_stale_time = 120

net.ipv4.neigh.default.gc_thresh3 = 8192
net.ipv4.neigh.default.gc_thresh2 = 4096
net.ipv4.neigh.default.gc_thresh1 = 1024

net.ipv6.neigh.default.gc_thresh3 = 8192
net.ipv6.neigh.default.gc_thresh2 = 4096
net.ipv6.neigh.default.gc_thresh1 = 1024

net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2
# net.ipv4.conf.lo.arp_announce = 2

# 用于控制系统在响应 ARP 请求时的行为。
net.ipv4.conf.default.arp_ignore = 1
net.ipv4.conf.all.arp_ignore = 1

# 取消注释以下内容以停止控制台上的低级消息
kernel.printk = 3 4 1 3

# 设定程序core时生成的文件名格式
kernel.core_pattern = core_%e

# 控制内存“脏数据”（dirty data）积累的后台内存比例。
vm.dirty_background_ratio = 5

# 表示强制Linux VM最低保留多少空闲内存（Kbytes）
# vm.min_free_kbytes = 0

# 仅用10%做为系统cache
vm.dirty_ratio = 10
vm.swappiness = 10
vm.overcommit_memory = 1
vm.overcommit_ratio = 80

fs.nr_open = 1024000
fs.file-max = 1024000

# 设置 inotify 监视的最大用户监视器数量。
fs.inotify.max_user_watches = 524288

# 增加系统文件描述符限制
# Fix error: too many open files
fs.inotify.max_user_instances = 524288

kernel.pid_max = 65536

# 内核响应魔术键
kernel.sysrq = 0
kernel.panic = 0

# 优化 CPU 设置
kernel.sched_autogroup_enabled = 0

# IPv4 TCP 低延迟参数
net.ipv4.tcp_low_latency = 1
# 禁用 NUMA balancing
kernel.numa_balancing = 0

# 内存区域（Zone）回收策略
vm.zone_reclaim_mode = 0

# TCP FastOpen
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_fastopen_blackhole_timeout_sec = 300

# TCP 流中重排序的数据报最大数量
net.ipv4.tcp_reordering = 16

# 控制 TCP 协议在重传数据时的行为。
net.ipv4.tcp_retrans_collapse = 0

# 自动阻塞判断
net.ipv4.tcp_autocorking = 0

# TCP内存自动调整
net.ipv4.tcp_moderate_rcvbuf = 1

# 单个TSO段可消耗拥塞窗口的比例, 默认值为 3
net.ipv4.tcp_tso_win_divisor = 8

# 控制 TCP 协议在处理 TIME-WAIT 状态时的行为
net.ipv4.tcp_rfc1337 = 0

# 控制未解析（unresolved）的邻居（neighbor）项队列长度。
# net.ipv4.neigh.default.unres_qlen = 10
# net.ipv4.neigh.default.unres_qlen_bytes = 131072

#ARP缓存的过期时间（单位毫秒）
net.ipv4.neigh.default.base_reachable_time_ms = 120000

#在把记录标记为不可达之前，用多播/广播方式解析地址的最大次数
# net.ipv4.neigh.default.mcast_solicit = 10

# 重发一个ARP请求前等待毫秒数
# net.ipv4.neigh.default.retrans_time_ms = 2000

# 作用：收到dupACK时要去检查tcp stream
net.ipv4.tcp_thin_dupack = 1

# 作用：重传超时后要去检查tcp stream
net.ipv4.tcp_thin_linear_timeouts = 0

# TCP Pacing Rate 调整参数（BBR 专用）
net.ipv4.tcp_pacing_ca_ratio = 110

# 作用：UDP队列里数据报的最大个数
net.unix.max_dgram_qlen = 1024

# 作用：内核的随机地址保护模式
kernel.randomize_va_space = 1

# Linux 内核中用于控制系统信号量（Semaphore）的参数。
kernel.sem = 512 262144 300 1024

# 虚拟化优化（KVM 环境）
kernel.sched_min_granularity_ns = 10000000
kernel.sched_wakeup_granularity_ns = 15000000
vm.dirty_writeback_centisecs = 1500

# 安全设置
kernel.kptr_restrict = 2
kernel.perf_event_paranoid = 3
kernel.yama.ptrace_scope = 1
# vm.mmap_min_addr = 65536
# vm.mmap_min_addr = 16384

kernel.sched_cfs_bandwidth_slice_us = 5000
kernel.sched_child_runs_first = 0
kernel.sched_latency_ns = 12000000
kernel.sched_migration_cost_ns = 1000000
kernel.sched_min_granularity_ns = 2000000
kernel.sched_nr_migrate = 64
kernel.sched_rr_timeslice_ms = 100
kernel.sched_rt_period_us = 1000000
kernel.sched_rt_runtime_us = 900000
kernel.sched_schedstats = 0
kernel.sched_tunable_scaling = 1
kernel.sched_wakeup_granularity_ns = 3000000

EOF

file_sysctl="/etc/sysctl.d/99-sysctl.conf"
if [ ! -f "$file_sysctl" ]; then
    echo "$file_sysctl 文件不存在，开始执行 ln"
    ln -s /etc/sysctl.conf /etc/sysctl.d/99-sysctl.conf
else
    echo "99-sysctl.conf 文件存在，不执行 ln"
fi

sysctl_p
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
    echo "5. 优化TCP 6. 优化UDP"
    echo "---"
    echo "7. 清理垃圾 8. 命令参考"
    echo "9. 安装内核"
    echo "000. 科技 Lion 脚本工具箱"
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
      8) tcp_info ;;
      9) Install_bbr ;;
      000) kejilion_sh ;;
      00) update_script ;;
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
