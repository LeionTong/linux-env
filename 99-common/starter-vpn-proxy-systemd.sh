#!/bin/bash
## starter-vpn-proxy-systemd.sh

# set -xeuo pipefail

# 检查是否为root用户运行
# if [[ $EUID -ne 0 ]]; then
#    echo "请使用root权限运行此脚本" 
#    exit 1
# fi

vpn_process_name="charon"
vpn_secret_file="/etc/ipsec.secrets"
PROXY_IP=127.0.0.1
proxy_port="1080"
# 确定 PROXY 进程名称
if command -v danted &> /dev/null; then
    proxy_process_name="danted"
    proxy_config_file="/etc/danted.conf"
    proxy_log_file=/var/log/danted.log
    proxy_service_name="danted.service"
elif command -v sockd &> /dev/null; then
    proxy_process_name="sockd"
    proxy_config_file="/etc/sockd.conf"
    proxy_log_file=/var/log/sockd.log
    proxy_service_name="sockd.service"
fi

# 定义函数：检查进程是否存在
is_process_running() {
    local process_name="$1"
    
    # 检查参数是否提供
    if [ -z "$process_name" ]; then
        echo "错误：请提供进程名称作为参数"
        return 1
    fi
    
    # 使用pgrep查找进程
    if sudo pgrep "$process_name" > /dev/null 2>&1; then
        echo "$process_name is running."
        return 0
    else
        echo "$process_name is not running."
        return 1
    fi
}

# 定义函数：杀死进程
kill_process() {
    local process_name="$1"
    # 检查进程是否存在
    if is_process_running "$process_name"; then
        echo "Killing $process_name..."
        # 使用pkill命令杀死进程
        sudo pkill -x "$process_name"
        # 检查进程是否被成功杀死
        if is_process_running "$process_name" $>/dev/null; then
            echo "Failed to kill $process_name"
            return 1
        else
            echo "Succeed to kill $process_name"
        fi
    fi
}

# 定义函数：检查字符串是否为有效的IPv4地址
check_ipv4() {
    local ip=$1
    # 使用正则表达式匹配IPv4地址
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        # 分割IP地址并检查每个部分是否在0-255范围内且无前导零
        IFS='.' read -r -a ip_parts <<< "$ip"
        for part in "${ip_parts[@]}"; do
            if [[ $part -le 255 && $part -ge 0 ]]; then
                # 检查是否有前导零
                if [[ $part == 0* && $part != 0 ]]; then
                    return 1 # 前导零, 无效
                fi
            else
                return 1 # 超出范围, 无效
            fi
        done
        return 0 # 所有条件满足, 有效
    else
        return 1 # 正则不匹配, 无效
    fi
}

# 定义函数：从终端输入获取授权码
get_vpn_auth_code() {
    vpn_auth_code="$1"
    echo "vpn_auth_code: " $vpn_auth_code

    while [[ ! $vpn_auth_code ]]
    do
        read -p "请输入VPN授权码: " vpn_auth_code
        echo $vpn_auth_code
    done
}

vpn_start() {
    echo "STARTING VPN..."
    sudo sed -i 's/: XAUTH.*/: XAUTH  '"$vpn_auth_code"'/g' $vpn_secret_file

    # 检查进程是否存在
    if is_process_running "$vpn_process_name"; then
        echo "Process $vpn_process_name is running, try rebooting..."
        # sudo ipsec restart --nofork | grep --color=auto authentication
        # sudo ipsec restart
        sudo systemctl restart strongswan-starter.service
        sleep 1
        is_process_running "$vpn_process_name" && echo -e "\033[32mVPN 重启成功, ଘ(੭ˊᵕˋ)੭* ੈ✩.\033[0m"
    else
        echo "Process $vpn_process_name is not running, try booting..."
        # sudo ipsec start --nofork | grep --color=auto authentication
        # sudo ipsec start
        sudo systemctl start strongswan-starter.service
    fi

    sleep 1

    if is_process_running "$vpn_process_name"; then
        echo "Succeed to run '$vpn_process_name'."
    else
        echo "Failed to run '$vpn_process_name'."
    fi

    # 手工指定 DNS 解析服务器
    # sudo sed -i '1i\nameserver 10.18.103.6' /etc/resolv.conf
}

vpn_stop() {
    is_process_running "$vpn_process_name"
    echo "STOPPING VPN..."
    # sudo ipsec stop
    sudo systemctl stop strongswan-starter.service
    is_process_running "$vpn_process_name" &>/dev/null || echo -e "\033[32mSTOPPING VPN...Done!\033[0m"
}

vpn_status() {
    echo "STATUS of VPN..."
    is_process_running "$vpn_process_name" && sudo ipsec status || echo -e "\033[35m进程 $vpn_process_name 未运行。\033[0m"
    echo -e "\n"
    systemctl status strongswan-starter.service
    echo -e "\n"
    cat /etc/resolv.conf
    echo -e "\n"
}

get_vpn_ip() {
    local max_attempts=9
    local attempt=0
    local retry_delay=1  # 重试延迟时间(秒)，便于调整
    
    # 循环尝试获取并验证VPN IP
    while [[ $attempt -lt $max_attempts ]]; do
        attempt=$((attempt + 1))  # 先递增计数，从1开始更直观
        
        # 获取本机VPN的IPv4地址（两种获取方式可根据兼容性选用）
        # 方式1: 通过ipsec status获取
        VPN_IP=$(sudo ipsec status | awk '/^ipsec-client/ && /===/ {getline; print $2}' | cut -d'/' -f1)
        ## VPN_IP=`sudo ipsec status | awk '/ipsec-client\{1\}:/{getline; split($2, ip, "/"); print ip[1]}'`

        # 方式2: 通过网络接口获取（需要时取消注释并注释方式1）
        # INTERFACE_NAME=wlan0  # eth0|wlp4s0|wlan0|enp7s0|ens66|...
        # VPN_IP=$(ip a s $INTERFACE_NAME | awk '/inet / && ++count == 2 {split($2, ip, "/"); print ip[1]}')
        ## VPN_IP=`ip -o -4 addr show $INTERFACE_NAME | awk 'NR==2 {print $4}' | cut -d'/' -f1`
        ## VPN_IP=`ip -o -4 addr show $INTERFACE_NAME | awk 'NR==2 {split($4, a, "/"); print a[1]}'`

        # 验证IP有效性
        if check_ipv4 "$VPN_IP"; then
            echo -e "\033[1;32m第 $attempt 次尝试成功获取VPN IP\033[0m"
            echo -e "\033[1;33mVPN IP: $VPN_IP\033[0m"
            return 0  # 成功获取有效IP，返回0
        fi
        
        # 未获取到有效IP且未达最大尝试次数时提示并重试
        if [[ $attempt -lt $max_attempts ]]; then
            echo -e "\033[1;36m第 $attempt 次尝试未获取到有效VPN IP，将在 $retry_delay 秒后重试...\033[0m"
            sleep $retry_delay
        fi
    done
    
    # 达到最大尝试次数仍失败
    echo -e "\033[31m错误: 尝试 $max_attempts 次后依然无法获取到正确的VPN IP地址\033[0m"
    echo -e "\033[33m提示: 请检查VPN是否正常工作，查看vpn_auth_code可能会有帮助 ^_^\033[0m"
    # vpn_stop  # 根据实际需求决定是否启用
    return 1
}

proxy_start() {
    echo "STARTING PROXY..."

    sudo sed -i "s/^external:.*/external: $PROXY_IP/" $proxy_config_file

    if is_process_running "$proxy_process_name"; then
        echo "Process $proxy_process_name is running, try rebooting..."
        sudo systemctl restart $proxy_service_name
    else
        echo "Process $proxy_process_name is not running, try booting..."
        sudo systemctl start $proxy_service_name
    fi

    sleep 1

    if is_process_running "$proxy_process_name"; then
        echo "Succeed to run '$proxy_process_name'."
    else
        echo "Failed to run '$proxy_process_name'."
    fi
}

proxy_stop() {
    is_process_running "$proxy_process_name"
    echo "STOPPING PROXY..."
    sudo systemctl stop $proxy_service_name
    is_process_running "$proxy_process_name" &>/dev/null || echo -e "\033[32mSTOPPING PROXY...Done!\033[0m"
}

proxy_status() {
    echo "STATUS of PROXY..."
    is_process_running "$proxy_process_name" && sudo tail -n 1 $proxy_log_file || echo -e "\033[35m进程 $proxy_process_name 未运行。\033[0m"
    echo -e "\n"
    systemctl status $proxy_service_name
}

read -p "请输入要执行的操作: start(1), stop(2), restart_vpn(3), restart_proxy(4), dns_nameserver_add(5), dns_nameserver_remove(6), status(7): " action

case $action in
    start|1)
        get_vpn_auth_code $1
        vpn_start
        get_vpn_ip || exit 1
        PROXY_IP=$VPN_IP
        proxy_start
        ;;
    stop|2)
        vpn_stop
        proxy_stop
        ;;
    restart_vpn|3)
        get_vpn_auth_code $1
        vpn_start
        ;;
    restart_proxy|4)
        get_vpn_ip || exit 1
        PROXY_IP=$VPN_IP
        proxy_start
        ;;
    dns_nameserver_add|5)
        # 添加手工指定 DNS 解析服务器
        sudo sed -i '1i\nameserver 10.18.103.6' /etc/resolv.conf
        ;;
    dns_nameserver_remove|6)
        # 删除手工指定的 DNS 解析服务器
        sudo sed -i '/nameserver 10.18.103.6/d' /etc/resolv.conf
        ;;
    status|7)
        vpn_status
        proxy_status
        ;;
    *)
        echo "输入的操作无效! $action"
        echo "Usage: $0 {start, stop... or 1, 2...}."
        ;;
esac
