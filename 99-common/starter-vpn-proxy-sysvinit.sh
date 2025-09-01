#!/bin/bash
## starter-vpn-proxy-sysvinit.sh

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
elif command -v sockd &> /dev/null; then
    proxy_process_name="sockd"
    proxy_config_file="/etc/sockd.conf"
    proxy_log_file=/var/log/sockd.log
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
            echo "FAILED to kill $process_name"
            return 1
        else
            echo "SUCCEED to kill $process_name"
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
    if  is_process_running "$vpn_process_name"; then
        echo "try rebooting $vpn_process_name..."
        # sudo ipsec restart --nofork | grep --color=auto authentication
        sudo ipsec restart
        sleep 1
    else
        echo "try booting $vpn_process_name..."
        # sudo ipsec start --nofork | grep --color=auto authentication
        sudo ipsec start
        sleep 1
    fi

    sleep 1

    if is_process_running "$vpn_process_name"; then
        echo -e "\033[32mSUCCEED to run '$vpn_process_name'!\033[0m"
    else
        echo "FAILED to run '$vpn_process_name'."
    fi

    # 手工指定 DNS 解析服务器
    # sudo sed -i '1i\nameserver 10.18.103.6' /etc/resolv.conf
}

vpn_stop() {
    is_process_running "$vpn_process_name"
    echo "STOPPING VPN..."
    sudo ipsec stop
    is_process_running "$vpn_process_name" &>/dev/null || echo -e "\033[32mSTOPPING VPN...Done!\033[0m"

    # 删除手工指定的 DNS 解析服务器
    # sudo sed -i '/nameserver 10.18.103.6/d' /etc/resolv.conf
}

vpn_status() {
    echo "STATUS of VPN..."
    is_process_running "$vpn_process_name" && sudo ipsec status || echo -e "\033[35m进程 $vpn_process_name 未运行。\033[0m"
}

get_vpn_ip() {
    # 使用while循环不断尝试获取有效的VPN IP地址，直到成功为止
    local max_attempts=3
    local attempt=0
    while [[ $attempt -lt $max_attempts ]]
    do
        # 获取本机VPN的IPv4地址
        VPN_IP=$(sudo ipsec status | awk '/^ipsec-client/&&/===/{getline; print $2}' | cut -d'/' -f1)
        # VPN_IP=$(ip a s wlan0 | awk '/inet / && ++count == 2 {split($2, ip, "/"); print ip[1]}')
        if check_ipv4 "$VPN_IP"; then
            break
        fi
        ((attempt++))
        sleep 1
    done
    if [[ $attempt -eq $max_attempts ]]; then
        echo -e "\033[35m尝试 ${max_attempts} 秒后依然无法获取到正确的 VPN IP 地址。\033[0m"
        echo -e "\033[35m请检查 VPN 是否正常工作, Check the vpn_auth_code will help .^_^.\033[0m"
        # vpn_stop
        return 1
    fi
    echo -e "\033[1;33mVPN IP: $VPN_IP\033[0m"
}

proxy_start() {
    echo "STARTING PROXY..."

    sudo sed -i "s/^external:.*/external: $PROXY_IP/" $proxy_config_file

    if is_process_running "$proxy_process_name"; then
        echo "try rebooting $proxy_process_name..."
        proxy_stop && sleep 1 && sudo $proxy_process_name -D
    else
        echo "try booting $proxy_process_name..."
        sudo $proxy_process_name -D
    fi

    sleep 1

    if is_process_running "$proxy_process_name"; then
        echo -e "\033[32mSUCCEED to run '$proxy_process_name'.!\033[0m"
    else
        echo "FAILED to run '$proxy_process_name'."
    fi
}

proxy_stop() {
    is_process_running "$proxy_process_name"
    echo "STOPPING PROXY..."
    # kill_process $proxy_process_name
    sudo pkill -x $proxy_process_name
    sudo rm -f /var/run/sockd.pid
    is_process_running "$proxy_process_name" &>/dev/null || echo -e "\033[32mSTOPPING PROXY...Done!\033[0m"
}

proxy_status() {
    echo -e "STATUS of PROXY..."
    is_process_running "$proxy_process_name" && sudo tail -n 1 $proxy_log_file || echo -e "\033[35m进程 $proxy_process_name 未运行。\033[0m"
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
