#!/bin/bash

# KVM网桥创建脚本
# 作者: KVM助手
# 版本: 1.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        exit 1
    fi
}

# 检查KVM是否安装
check_kvm() {
    log_info "检查KVM安装状态..."
    if ! command -v virsh &> /dev/null; then
        log_error "KVM未安装，请先安装KVM"
        exit 1
    fi
    log_success "KVM已安装"
}

# 显示当前网络状态
show_network_status() {
    log_info "当前网络状态:"
    echo "=== 物理网络接口 ==="
    ip link show | grep -E "^[0-9]+:" | grep -v "@"
    echo ""
    echo "=== 现有网桥 ==="
    ip link show type bridge
    echo ""
    echo "=== KVM虚拟网络 ==="
    virsh net-list --all
}

# 方法1: 创建虚拟网络网桥
create_virtual_bridge() {
    local network_name=$1
    local bridge_name=$2
    local ip_address=$3
    local netmask=$4
    
    log_info "创建虚拟网络网桥: $network_name"
    
    # 创建网络配置文件
    cat > /tmp/${network_name}.xml << EOF
<network>
  <name>${network_name}</name>
  <uuid>$(uuidgen)</uuid>
  <bridge name='${bridge_name}' stp='on' delay='0'/>
  <ip address='${ip_address}' netmask='${netmask}'>
    <dhcp>
      <range start='$(echo $ip_address | cut -d. -f1-3).2' end='$(echo $ip_address | cut -d. -f1-3).254'/>
    </dhcp>
  </ip>
</network>
EOF
    
    # 定义网络
    virsh net-define /tmp/${network_name}.xml
    virsh net-autostart ${network_name}
    virsh net-start ${network_name}
    
    log_success "虚拟网络网桥 $network_name 创建成功"
}

# 方法2: 创建桥接到物理网络的网桥
create_physical_bridge() {
    local network_name=$1
    local bridge_name=$2
    local physical_interface=$3
    
    log_info "创建桥接到物理网络的网桥: $network_name"
    
    # 检查物理接口是否存在
    if ! ip link show $physical_interface &> /dev/null; then
        log_error "物理接口 $physical_interface 不存在"
        return 1
    fi
    
    # 创建网络配置文件
    cat > /tmp/${network_name}.xml << EOF
<network>
  <name>${network_name}</name>
  <uuid>$(uuidgen)</uuid>
  <forward mode='bridge'/>
  <bridge name='${bridge_name}' stp='on' delay='0'/>
</network>
EOF
    
    # 定义网络
    virsh net-define /tmp/${network_name}.xml
    virsh net-autostart ${network_name}
    virsh net-start ${network_name}
    
    # 创建网桥并添加物理接口
    brctl addbr $bridge_name
    brctl addif $bridge_name $physical_interface
    ip link set $bridge_name up
    
    log_success "物理网桥 $network_name 创建成功"
}

# 方法3: 手动创建Linux网桥
create_linux_bridge() {
    local bridge_name=$1
    local ip_address=$2
    local netmask=$3
    
    log_info "创建Linux网桥: $bridge_name"
    
    # 创建网桥
    brctl addbr $bridge_name
    ip addr add $ip_address/$netmask dev $bridge_name
    ip link set $bridge_name up
    
    log_success "Linux网桥 $bridge_name 创建成功"
}

# 显示帮助信息
show_help() {
    cat << EOF
KVM网桥创建脚本

用法: $0 [选项]

选项:
    -v, --virtual <name> <bridge> <ip> <netmask>    创建虚拟网络网桥
    -p, --physical <name> <bridge> <interface>      创建桥接到物理网络的网桥
    -l, --linux <bridge> <ip> <netmask>            创建Linux网桥
    -s, --status                                     显示当前网络状态
    -h, --help                                       显示此帮助信息

示例:
    $0 -v kvm-net br-kvm 192.168.100.1 255.255.255.0
    $0 -p kvm-physical br-physical enp3s0f0
    $0 -l br-manual 192.168.200.1 255.255.255.0
    $0 -s

EOF
}

# 主函数
main() {
    check_root
    check_kvm
    
    case "${1:-}" in
        -v|--virtual)
            if [[ $# -lt 5 ]]; then
                log_error "虚拟网桥需要4个参数: 网络名 网桥名 IP地址 子网掩码"
                exit 1
            fi
            create_virtual_bridge "$2" "$3" "$4" "$5"
            ;;
        -p|--physical)
            if [[ $# -lt 4 ]]; then
                log_error "物理网桥需要3个参数: 网络名 网桥名 物理接口"
                exit 1
            fi
            create_physical_bridge "$2" "$3" "$4"
            ;;
        -l|--linux)
            if [[ $# -lt 4 ]]; then
                log_error "Linux网桥需要3个参数: 网桥名 IP地址 子网掩码"
                exit 1
            fi
            create_linux_bridge "$2" "$3" "$4"
            ;;
        -s|--status)
            show_network_status
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"
