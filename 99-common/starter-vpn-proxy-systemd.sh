#!/usr/bin/env bash
## starter-vpn-proxy-systemd.sh
## VPN and Proxy Management Script with systemd integration

set -euo pipefail

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Configuration
readonly VPN_PROCESS_NAME="charon"
readonly VPN_SECRET_FILE="/etc/ipsec.secrets"
readonly VPN_SERVICE_NAME="strongswan-starter.service"
readonly DNS_SERVER="10.18.103.6"
readonly RESOLV_CONF="/etc/resolv.conf"
readonly PROXY_PORT="1080"
readonly MAX_IP_ATTEMPTS=9
readonly RETRY_DELAY=1

PROXY_IP="127.0.0.1"
VPN_IP=""

# Detect proxy configuration
detect_proxy() {
    if command -v danted &> /dev/null; then
        readonly PROXY_PROCESS_NAME="danted"
        readonly PROXY_CONFIG_FILE="/etc/danted.conf"
        readonly PROXY_SERVICE_NAME="danted.service"
    elif command -v sockd &> /dev/null; then
        readonly PROXY_PROCESS_NAME="sockd"
        readonly PROXY_CONFIG_FILE="/etc/sockd.conf"
        readonly PROXY_SERVICE_NAME="sockd.service"
    else
        echo -e "${RED}错误: 未找到 danted 或 sockd 代理服务${NC}" >&2
        exit 1
    fi
}

detect_proxy

# Utility functions
log_info() {
    echo -e "${CYAN}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

is_process_running() {
    local process_name="$1"
    
    if [[ -z "$process_name" ]]; then
        log_error "进程名称参数缺失"
        return 1
    fi
    
    if sudo pgrep -x "$process_name" > /dev/null 2>&1; then
        log_info "进程 $process_name 正在运行"
        return 0
    else
        log_warning "进程 $process_name 未运行"
        return 1
    fi
}

validate_ipv4() {
    local ip="$1"
    local IFS='.'
    local -a octets
    
    read -ra octets <<< "$ip"
    
    # Check if we have exactly 4 octets
    [[ ${#octets[@]} -eq 4 ]] || return 1
    
    # Validate each octet
    for octet in "${octets[@]}"; do
        # Check if it's a number
        [[ "$octet" =~ ^[0-9]+$ ]] || return 1
        # Check range 0-255
        (( octet >= 0 && octet <= 255 )) || return 1
        # Check for leading zeros (except "0" itself)
        [[ ${#octet} -gt 1 && ${octet:0:1} == "0" ]] && return 1
    done
    
    return 0
}

nameserver_add() {
    if grep -q "^nameserver $DNS_SERVER" "$RESOLV_CONF"; then
        log_info "DNS 服务器 $DNS_SERVER 已存在"
        return 0
    fi
    
    sudo sed -i "1i\\nameserver $DNS_SERVER" "$RESOLV_CONF"
    log_success "DNS 服务器 $DNS_SERVER 已添加"
}

nameserver_del() {
    if ! grep -q "^nameserver $DNS_SERVER" "$RESOLV_CONF"; then
        log_info "DNS 服务器 $DNS_SERVER 不存在"
        return 0
    fi
    
    sudo sed -i "/^nameserver $DNS_SERVER/d" "$RESOLV_CONF"
    log_success "DNS 服务器 $DNS_SERVER 已删除"
}

get_vpn_auth_code() {
    local auth_code="$1"
    local attempt=0
    local max_attempts=3
    
    if [[ -n "$auth_code" ]]; then
        echo "$auth_code"
        return 0
    fi
    
    while (( attempt < max_attempts )); do
        ((attempt++))
        read -rp "请输入VPN授权码 (尝试 $attempt/$max_attempts): " auth_code
        if [[ -n "$auth_code" ]]; then
            echo "$auth_code"
            return 0
        fi
    done
    
    log_error "已达到最大尝试次数 ($max_attempts)，未输入授权码"
    return 1
}

vpn_start() {
    local auth_code
    
    # Try to get auth code
    if auth_code=$(get_vpn_auth_code "${1:-}") && [[ -n "$auth_code" ]]; then
        # Auth code provided, update the config file
        log_info "正在更新 VPN 授权码..."
        sudo sed -i "s/: XAUTH.*/: XAUTH  $auth_code/g" "$VPN_SECRET_FILE"
    else
        # No auth code provided, use existing one in config file
        log_info "未提供授权码，将使用配置文件中已有的授权码"
    fi
    
    log_info "正在启动 VPN..."
    
    if is_process_running "$VPN_PROCESS_NAME"; then
        log_info "VPN 进程已运行，正在重启..."
        sudo systemctl restart "$VPN_SERVICE_NAME"
    else
        log_info "VPN 进程未运行，正在启动..."
        sudo systemctl start "$VPN_SERVICE_NAME"
    fi
    
    sleep 2
    
    if is_process_running "$VPN_PROCESS_NAME"; then
        log_success "VPN 启动成功 ଘ(੭ˊᵕˋ)੭* ੈ✩"
        nameserver_add
        return 0
    else
        log_error "VPN 启动失败"
        return 1
    fi
}

vpn_stop() {
    log_info "正在停止 VPN..."
    
    sudo systemctl stop "$VPN_SERVICE_NAME"
    sleep 1
    
    if ! is_process_running "$VPN_PROCESS_NAME" &>/dev/null; then
        log_success "VPN 已停止"
        nameserver_del
        return 0
    else
        log_error "VPN 停止失败"
        return 1
    fi
}

vpn_status() {
    echo -e "\n${CYAN}=== VPN 状态 ===${NC}"
    
    if is_process_running "$VPN_PROCESS_NAME" &>/dev/null; then
        sudo ipsec status
    else
        log_warning "VPN 进程未运行"
    fi
    
    echo -e "\n${CYAN}=== Systemd 服务状态 ===${NC}"
    systemctl status "$VPN_SERVICE_NAME" --no-pager
    
    echo -e "\n${CYAN}=== DNS 配置 ===${NC}"
    cat "$RESOLV_CONF"
    echo ""
}

get_vpn_ip() {
    local attempt=0
    local ip
    
    log_info "正在获取 VPN IP 地址..."
    
    while (( attempt < MAX_IP_ATTEMPTS )); do
        ((attempt++))
        
        # Method 1: Get IP from ipsec status
        ip=$(sudo ipsec status | awk '/^ipsec-client/ && /===/ {getline; print $2}' | cut -d'/' -f1)
        
        # Alternative method (uncomment if needed):
        # local interface="wlan0"  # eth0|wlp4s0|wlan0|enp7s0|ens66
        # ip=$(ip -4 addr show "$interface" | awk '/inet / && ++count == 2 {split($2, a, "/"); print a[1]}')
        
        if validate_ipv4 "$ip"; then
            VPN_IP="$ip"
            log_success "第 $attempt 次尝试成功获取 VPN IP: ${YELLOW}$VPN_IP${NC}"
            return 0
        fi
        
        if (( attempt < MAX_IP_ATTEMPTS )); then
            log_warning "第 $attempt 次尝试未获取到有效 VPN IP，${RETRY_DELAY}秒后重试..."
            sleep "$RETRY_DELAY"
        fi
    done
    
    log_error "尝试 $MAX_IP_ATTEMPTS 次后仍无法获取有效的 VPN IP 地址"
    log_warning "请检查 VPN 连接状态和授权码是否正确"
    return 1
}

proxy_start() {
    log_info "正在启动代理服务..."
    
    # Update proxy configuration with VPN IP
    sudo sed -i "s/^external:.*/external: $PROXY_IP/" "$PROXY_CONFIG_FILE"
    
    if is_process_running "$PROXY_PROCESS_NAME"; then
        log_info "代理进程已运行，正在重启..."
        sudo systemctl restart "$PROXY_SERVICE_NAME"
    else
        log_info "代理进程未运行，正在启动..."
        sudo systemctl start "$PROXY_SERVICE_NAME"
    fi
    
    sleep 2
    
    if is_process_running "$PROXY_PROCESS_NAME"; then
        log_success "代理服务启动成功 (IP: $PROXY_IP:$PROXY_PORT)"
        return 0
    else
        log_error "代理服务启动失败"
        return 1
    fi
}

proxy_stop() {
    log_info "正在停止代理服务..."
    
    sudo systemctl stop "$PROXY_SERVICE_NAME"
    sleep 1
    
    if ! is_process_running "$PROXY_PROCESS_NAME" &>/dev/null; then
        log_success "代理服务已停止"
        return 0
    else
        log_error "代理服务停止失败"
        return 1
    fi
}

proxy_status() {
    echo -e "\n${CYAN}=== 代理服务状态 ===${NC}"
    
    if ! is_process_running "$PROXY_PROCESS_NAME" &>/dev/null; then
        log_warning "代理进程未运行"
    fi
    
    echo -e "\n${CYAN}=== Systemd 服务状态 ===${NC}"
    systemctl status "$PROXY_SERVICE_NAME" --no-pager
    
    echo -e "\n${CYAN}=== 今日服务日志 ===${NC}"
    journalctl -u "$PROXY_SERVICE_NAME" -b --since today --no-pager -n 50
    echo ""
}

show_usage() {
    echo -e "${CYAN}用法:${NC} $0 [操作] [VPN授权码]"
    echo ""
    echo -e "${CYAN}可用操作:${NC}"
    echo "  start, 1           - 启动 VPN 和代理服务"
    echo "  stop, 2            - 停止 VPN 和代理服务"
    echo "  restart_vpn, 3     - 重启 VPN 服务"
    echo "  restart_proxy, 4   - 重启代理服务"
    echo "  nameserver_add, 5  - 添加 DNS 服务器"
    echo "  nameserver_del, 6  - 删除 DNS 服务器"
    echo "  status, 7          - 查看服务状态"
    echo "  help, -h, --help   - 显示此帮助信息"
    echo ""
    echo -e "${CYAN}示例:${NC}"
    echo "  $0 start 123456        # 使用授权码启动服务"
    echo "  $0 stop                # 停止所有服务"
    echo "  $0 status              # 查看状态"
}

prompt_for_action() {
    # Display menu to stderr so it shows even when output is captured
    {
        echo ""
        echo "═══════════════════════════════════════════════════"
        echo "  请选择要执行的操作:"
        echo "═══════════════════════════════════════════════════"
        echo "  [1 | start]           启动 VPN 和代理服务"
        echo "  [2 | stop]            停止 VPN 和代理服务"
        echo "  [3 | restart_vpn]     重启 VPN 服务"
        echo "  [4 | restart_proxy]   重启代理服务"
        echo "  [5 | nameserver_add]  添加 DNS 服务器"
        echo "  [6 | nameserver_del]  删除 DNS 服务器"
        echo "  [7 | status]          查看服务状态"
        echo "  [h | help]            显示帮助信息"
        echo "  [q | quit]            退出"
        echo "═══════════════════════════════════════════════════"
        echo ""
    } >&2
    
    local choice
    read -rp "请输入选项: " choice >&2
    echo "$choice"
}

main() {
    local action="${1:-}"
    local auth_code="${2:-}"
    
    # Show usage if help requested
    if [[ "$action" =~ ^(-h|--help|help)$ ]]; then
        show_usage
        exit 0
    fi
    
    # Check if first argument is a valid operation
    if [[ -n "$action" ]] && ! [[ "$action" =~ ^(start|stop|restart_vpn|restart_proxy|nameserver_add|nameserver_del|status|[1-7])$ ]]; then
        # First argument is not a valid operation, treat it as auth code
        auth_code="$action"
        action=""
    fi
    
    # If no action, prompt for it
    if [[ -z "$action" ]]; then
        action=$(prompt_for_action)
        
        # Handle help and quit options
        case "$action" in
            h|help)
                show_usage
                exit 0
                ;;
            q|quit|exit)
                log_info "退出脚本"
                exit 0
                ;;
        esac
    fi
    
    case "$action" in
        start|1)
            vpn_start "$auth_code" || exit 1
            get_vpn_ip || exit 1
            PROXY_IP="$VPN_IP"
            proxy_start || exit 1
            log_success "所有服务已成功启动"
            ;;
        stop|2)
            proxy_stop
            vpn_stop
            log_success "所有服务已停止"
            ;;
        restart_vpn|3)
            vpn_start "$auth_code" || exit 1
            ;;
        restart_proxy|4)
            get_vpn_ip || exit 1
            PROXY_IP="$VPN_IP"
            proxy_start || exit 1
            ;;
        nameserver_add|5)
            nameserver_add
            ;;
        nameserver_del|6)
            nameserver_del
            ;;
        status|7)
            vpn_status
            proxy_status
            ;;
        *)
            log_error "无效的操作: $action"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
