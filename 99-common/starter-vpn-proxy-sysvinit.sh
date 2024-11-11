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
proxy_port="1080"
# 确定 PROXY 进程名称
if command -v danted &> /dev/null; then
    proxy_process_name="danted"
    proxy_config_file="/etc/danted.conf"
    # proxy_service_name="danted.service"
elif command -v sockd &> /dev/null; then
    proxy_process_name="sockd"
    proxy_config_file="/etc/sockd.conf"
    # proxy_service_name="sockd.service"
fi

# 定义函数：检查进程是否存在
is_process_running() {
    local process_name="$1"
    # 使用pgrep查找进程, 如果找到则返回0（成功）, 否则返回非0（失败）
    pgrep "$process_name" > /dev/null 2>&1
    return $?
}

# 定义函数：kill进程
kill_process() {
    local process_name="$1"
    # 检查进程是否存在
    if is_process_running "$process_name"; then
        echo "Killing $process_name..."
        # 使用pkill命令杀死进程
        pkill "$process_name"
        # 检查进程是否被成功杀死
        if is_process_running "$process_name"; then
            echo "Failed to kill $process_name"
            exit 1
        fi
    else
        echo "$process_name is not running"
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
        echo "Process $vpn_process_name is running, try rebooting..."
        # sudo ipsec restart --nofork | grep --color=auto authentication
        sudo ipsec restart
        sleep 1
    else
        echo "Process $vpn_process_name is not running, try booting..."
        # sudo ipsec start --nofork | grep --color=auto authentication
        sudo ipsec start
        sleep 1
    fi

    sleep 1

    if is_process_running "$vpn_process_name"; then
        echo "Process '$vpn_process_name' is running."
    else
        echo "Process '$vpn_process_name' is not running."
    fi

    # 手工指定 DNS 解析服务器
    # sudo sed -i '1i\nameserver 172.16.9.3' /etc/resolv.conf
}

vpn_stop() {
    # 获取进程id
    # vpn_process_id=`ps aux | grep $vpn_process_name | grep -v grep | awk '{print$2}'`
    # 检查进程id是否存在, 若存在(非空)则停掉
    # if [[ -n "$vpn_process_id" ]]; then
        echo "STOPPING VPN..."
        sudo ipsec stop
    # fi
    is_process_running "$vpn_process_name" || echo -e "\033[32mSTOPPING VPN...Done!\033[0m"

    # 删除手工指定的 DNS 解析服务器
    # sudo sed -i '/nameserver 172.16.9.3/d' /etc/resolv.conf
}

vpn_status() {
    echo "STATUS of VPN..."
    is_process_running "$vpn_process_name" && sudo ipsec status || echo -e "\033[35m进程 $vpn_process_name 未运行。\033[0m"
    echo -e "\n"
}

get_vpn_ip() {
    # 使用while循环不断尝试获取有效的VPN IP地址，直到成功为止
    local max_attempts=3
    local attempt=0
    while [[ $attempt -lt $max_attempts ]]
    do
        # 获取本机VPN的IPv4地址
        IP_VPN=$(sudo ipsec status | awk '/^ipsec-client/&&/===/{getline; print $2}' | cut -d'/' -f1)
        if check_ipv4 "$IP_VPN"; then
            break
        fi
        ((attempt++))
        sleep 1
    done
    if [[ $attempt -eq $max_attempts ]]; then
        echo -e "\033[35m尝试 ${max_attempts} 秒后依然无法获取到正确的 VPN IP 地址。\033[0m"
        echo -e "\033[35m请检查 VPN 是否正常工作, Check the vpn_auth_code will help .^_^.\033[0m"
        # vpn_stop
        exit 1
    fi
    echo -e "\033[1;33mVPN IP: $IP_VPN\033[0m"
}

proxy_start() {
    echo "STARTING PROXY..."

    if is_process_running "$proxy_process_name"; then
        echo "Process $proxy_process_name is running, try rebooting..."
        proxy_stop && sleep 1 && sudo sockd -D
    else
        echo "Process $proxy_process_name is not running, try booting..."
        sudo $proxy_process_name -D
    fi

    sleep 1

    if is_process_running "$proxy_process_name"; then
        echo "Process '$proxy_process_name' is running."
    else
        echo "Process '$proxy_process_name' is not running."
    fi
}

proxy_stop() {
    # 检查进程是否存在, 若存在则停掉
    # if is_process_running "$proxy_process_name"; then
        echo "STOPPING PROXY..."
        proxy_process_id=`ps aux | grep $proxy_process_name | grep -v grep | awk '{print$2}'`
        sudo kill -9 $proxy_process_id 2>/dev/null
        sudo rm -f /var/run/sockd.pid
    # fi
    is_process_running "$proxy_process_name" || echo -e "\033[32mSTOPPING PROXY...Done!\033[0m"
}

proxy_status() {
    echo -e "STATUS of PROXY LOG..."
    is_process_running "$proxy_process_name" && sudo tail -n 1 /var/log/sockd.log || echo -e "\033[35m进程 $proxy_process_name 未运行。\033[0m"
    echo -e "\n"
}

read -p "请输入要执行的操作: start(1), stop(2), status(3), restart_vpn(4), restart_proxy(5): " action

case $action in
    start|1)
        get_vpn_auth_code $1
        vpn_start;
        get_vpn_ip
        sudo sed -i "s/^external:.*/external: $IP_VPN/" $proxy_config_file
        proxy_start;
        ;;
    stop|2)
        vpn_stop;
        proxy_stop;
        ;;
    status|3)
        vpn_status;
        proxy_status;
        ;;
    restart_vpn|4)
        get_vpn_auth_code $1
        vpn_start;
        ;;
    restart_proxy|5)
        proxy_start;
        ;;
    *)
        echo "输入的操作无效! $action"
        echo "Usage: $0 {start, stop... or 1, 2...}."
        ;;
esac
