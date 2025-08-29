#!/bin/bash

# KVM网桥测试脚本
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

# 测试网桥功能
test_bridge() {
    local bridge_name=$1
    local network_name=$2
    
    log_info "测试网桥: $bridge_name"
    
    # 检查网桥是否存在
    if ! ip link show $bridge_name &> /dev/null; then
        log_error "网桥 $bridge_name 不存在"
        return 1
    fi
    
    # 检查网桥状态
    local bridge_state=$(ip link show $bridge_name | grep -o "state [A-Z]*" | cut -d' ' -f2)
    log_info "网桥状态: $bridge_state"
    
    # 检查KVM网络状态
    if virsh net-list --all | grep -q $network_name; then
        local net_state=$(virsh net-list --all | grep $network_name | awk '{print $2}')
        log_info "KVM网络状态: $net_state"
    else
        log_warning "KVM网络 $network_name 不存在"
    fi
    
    # 检查DHCP服务
    if virsh net-dumpxml $network_name &> /dev/null; then
        local dhcp_range=$(virsh net-dumpxml $network_name | grep -A2 "<dhcp>" | grep "range" | sed 's/.*start=.\([^"]*\).*end=.\([^"]*\).*/\1-\2/')
        log_info "DHCP范围: $dhcp_range"
    fi
    
    log_success "网桥 $bridge_name 测试完成"
}

# 创建测试虚拟机
create_test_vm() {
    local vm_name=$1
    local bridge_name=$2
    
    log_info "创建测试虚拟机: $vm_name"
    
    # 检查镜像文件是否存在
    if [[ ! -f "/root/kvm/cirros-0.6.3-x86_64-disk.img" ]]; then
        log_error "镜像文件不存在"
        return 1
    fi
    
    # 创建虚拟机
    virt-install \
        --name $vm_name \
        --ram 512 \
        --disk path=/root/kvm/cirros-0.6.3-x86_64-disk.img,device=disk,bus=ide \
        --vcpus 1 \
        --os-type linux \
        --network bridge=$bridge_name \
        --graphics vnc,port=-1 \
        --noautoconsole \
        --import
    
    log_success "测试虚拟机 $vm_name 创建成功"
}

# 测试网络连接
test_network_connectivity() {
    local vm_name=$1
    
    log_info "测试虚拟机网络连接: $vm_name"
    
    # 启动虚拟机
    virsh start $vm_name
    
    # 等待虚拟机启动
    sleep 10
    
    # 获取虚拟机IP
    local vm_ip=$(virsh domifaddr $vm_name | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
    
    if [[ -n "$vm_ip" ]]; then
        log_info "虚拟机IP: $vm_ip"
        
        # 测试ping
        if ping -c 3 $vm_ip &> /dev/null; then
            log_success "网络连接测试成功"
        else
            log_warning "网络连接测试失败"
        fi
    else
        log_warning "无法获取虚拟机IP"
    fi
    
    # 关闭虚拟机
    virsh destroy $vm_name
}

# 显示网桥统计信息
show_bridge_stats() {
    local bridge_name=$1
    
    log_info "网桥统计信息: $bridge_name"
    
    echo "=== 网桥接口信息 ==="
    brctl show $bridge_name 2>/dev/null || echo "网桥不存在或无法访问"
    
    echo ""
    echo "=== 网桥流量统计 ==="
    ip -s link show $bridge_name 2>/dev/null || echo "无法获取流量统计"
    
    echo ""
    echo "=== 连接的虚拟机 ==="
    virsh list --all | grep -E "(running|idle)" | while read line; do
        local vm_name=$(echo $line | awk '{print $2}')
        virsh domiflist $vm_name 2>/dev/null | grep $bridge_name && echo "  $vm_name -> $bridge_name"
    done
}

# 主函数
main() {
    case "${1:-}" in
        test)
            if [[ $# -lt 3 ]]; then
                log_error "用法: $0 test <网桥名> <网络名>"
                exit 1
            fi
            test_bridge "$2" "$3"
            ;;
        create-vm)
            if [[ $# -lt 3 ]]; then
                log_error "用法: $0 create-vm <虚拟机名> <网桥名>"
                exit 1
            fi
            create_test_vm "$2" "$3"
            ;;
        test-connectivity)
            if [[ $# -lt 2 ]]; then
                log_error "用法: $0 test-connectivity <虚拟机名>"
                exit 1
            fi
            test_network_connectivity "$2"
            ;;
        stats)
            if [[ $# -lt 2 ]]; then
                log_error "用法: $0 stats <网桥名>"
                exit 1
            fi
            show_bridge_stats "$2"
            ;;
        *)
            cat << EOF
KVM网桥测试脚本

用法: $0 [选项]

选项:
    test <网桥名> <网络名>          测试网桥功能
    create-vm <虚拟机名> <网桥名>   创建测试虚拟机
    test-connectivity <虚拟机名>    测试网络连接
    stats <网桥名>                 显示网桥统计信息

示例:
    $0 test br-kvm-test kvm-test
    $0 create-vm test-vm br-kvm-test
    $0 test-connectivity test-vm
    $0 stats br-kvm-test

EOF
            ;;
    esac
}

# 运行主函数
main "$@"
