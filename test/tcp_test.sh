# ==================== 内存参数计算与应用 ====================
# 公式（单位：页，4KB/页）：
#   tcp_mem: low=RAM_MB*16, pres=RAM_MB*32, max=RAM_MB*64
#   换算成字节即 RAM/16, RAM/8, RAM/4
#   下限保护：low>=4096, pres>=8192, max>=16384
#   udp_mem: 按原脚本逻辑取 tcp_mem 的 60%，同样加下限
net_mem() {
    local size_mb
    size_mb=$(free -m | awk '/Mem:/ {print $2}')
    [[ -z "$size_mb" ]] && size_mb=1024
    [[ "$size_mb" -lt 128 ]] && size_mb=128

    # --- tcp_mem: RAM/16, RAM/8, RAM/4（单位页）---
    local tcp_low=$((size_mb * 16))
    local tcp_mid=$((size_mb * 32))
    local tcp_high=$((size_mb * 64))
    [[ $tcp_low  -lt 4096  ]] && tcp_low=4096
    [[ $tcp_mid  -lt 8192  ]] && tcp_mid=8192
    [[ $tcp_high -lt 16384 ]] && tcp_high=16384

    # --- udp_mem: UDP 改成 tcp_mem 相同 ---
    local udp_low=$tcp_low
    local udp_mid=$tcp_mid
    local udp_high=$tcp_high
    [[ $udp_low  -lt 4096  ]] && udp_low=4096
    [[ $udp_mid  -lt 8192  ]] && udp_mid=8192
    [[ $udp_high -lt 16384 ]] && udp_high=16384

    updateSysctlParam "net.ipv4.tcp_mem" "$tcp_low $tcp_mid $tcp_high"
    updateSysctlParam "net.ipv4.udp_mem" "$udp_low $udp_mid $udp_high"

    # info "总内存 = ${size_mb} MB"
    # info "tcp_mem = $tcp_low $tcp_mid $tcp_high  (页, RAM/16, RAM/8, RAM/4)"
    # info "udp_mem = $udp_low $udp_mid $udp_high  (页, TCP 的 60%)"

    # nf_conntrack: 经典公式 RAM*128
    local conntrack_max=$((size_mb * 128))
    local conntrack_buckets=$((conntrack_max / 4))
    updateSysctlParam "net.netfilter.nf_conntrack_max" "$conntrack_max"
    updateSysctlParam "net.netfilter.nf_conntrack_buckets" "$conntrack_buckets"

    # info "nf_conntrack_max     = $conntrack_max"
    # info "nf_conntrack_buckets = $conntrack_buckets"
}