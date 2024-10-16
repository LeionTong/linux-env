#!/bin/bash
## starter-vpn-proxy-systemd.sh

# set -xeuo pipefail

# 检查是否为root用户运行
# if [[ $EUID -ne 0 ]]; then
#    echo "请使用root权限运行此脚本" 
#    exit 1
# fi

vpn_secret_file="/etc/ipsec.secrets"
vpn_process_name="charon"
proxy_port="1080"
# 确定 PROXY 进程名称
if command -v danted &> /dev/null; then
    proxy_process_name="danted"
    proxy_config_file="/etc/danted.conf"
    proxy_service_name="danted.service"
elif command -v sockd &> /dev/null; then
    proxy_process_name="sockd"
    proxy_config_file="/etc/sockd.conf"
    proxy_service_name="sockd.service"
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
        sleep 1
        is_process_running "$vpn_process_name" && echo -e "\033[32mVPN 启动成功, Yଘ(੭ˊᵕˋ)੭* ੈ✩.\033[0m"
    fi
    # 手工指定 DNS 解析服务器
    # sudo sed -i '1i\nameserver 172.16.9.3' /etc/resolv.conf
}

vpn_stop() {
    # 获取进程id
    vpn_process_id=`ps aux | grep $vpn_process_name | grep -v grep | awk '{print$2}'`
    # 检查进程id是否存在, 若存在(非空)则停掉
    if [[ -n "$vpn_process_id" ]]; then
        echo "STOPPING VPN..."
        # sudo ipsec stop
        sudo systemctl stop strongswan-starter.service
        is_process_running "$vpn_process_name" || echo -e "\033[35m进程 $vpn_process_name 已停止。\033[0m"
    else
        echo -e "\033[35m进程 $vpn_process_name 未运行, 无需停止。\033[0m"
    fi
}

vpn_status() {
    echo "STATUS of VPN..."
    is_process_running "$vpn_process_name" && sudo ipsec status || echo -e "\033[35m进程 $vpn_process_name 未运行。\033[0m"
    echo -e "\n"
    systemctl status strongswan-starter.service
    echo -e "\n"
}

proxy_start() {
    echo "STARTING PROXY..."

    # 获取本机VPN的IPv4地址
    IP_VPN=`sudo ipsec status | awk '/^ipsec-client\{1\}:/{getline; print $2}' | cut -d'/' -f1`
    # IP_VPN=`sudo ipsec status | awk '/ipsec-client\{1\}:/{getline; split($2, ip, "/"); print ip[1]}'`
    # INTERFACE_NAME=wlp4s0  # eth0|wlp4s0|enp7s0|ens66|...
    # IP_VPN=`ip -o -4 addr show $INTERFACE_NAME | awk 'NR==2 {print $4}' | cut -d'/' -f1`
    # IP_VPN=`ip -o -4 addr show $INTERFACE_NAME | awk 'NR==2 {split($4, a, "/"); print a[1]}'`
    sudo sed -i "s/^external:.*/external: $IP_VPN/" $proxy_config_file

    # 检查 IPv4 地址是否有效，既非空且符合 IPv4 地址格式
    if [ -n "$IP_VPN" ] && check_ipv4 "$IP_VPN"; then
        # 检查进程是否存在
        if is_process_running "$proxy_process_name"; then
            echo "Process $proxy_process_name is running, try rebooting..."
            # proxy_stop && sleep 1 && sudo sockd -D
            sudo systemctl restart $proxy_service_name
            is_process_running "$proxy_process_name" && echo -e "\033[32mPROXY 重启成功, ଘ(੭ˊᵕˋ)੭* ੈ✩.\033[0m"
        else
            echo "Process $proxy_process_name is not running, try booting..."
            # sudo $proxy_process_name -D
            sudo systemctl start $proxy_service_name
            is_process_running "$proxy_process_name" && echo -e "\033[32mPROXY 启动成功, ଘ(੭ˊᵕˋ)੭* ੈ✩.\033[0m"
        fi
    else
        echo -e "\nIP address of VPN is not ok! Check the vpn_auth_code will help .^_^.\n"
        exit 1
    fi
}

proxy_stop() {
    # 获取进程id
    proxy_process_id=`ps aux | grep $proxy_process_name | grep -v grep | awk '{print$2}'`
    # 检查进程id是否存在, 若存在(非空)则停掉
    if [[ -n "$proxy_process_id" ]]; then
        echo "STOPPING PROXY..."
        # sudo kill_process $proxy_process_id && sudo rm -f /var/run/sockd.pid
        sudo systemctl stop $proxy_service_name
        is_process_running "$proxy_process_name" || echo -e "\033[35m进程 $proxy_process_name 已停止。\033[0m"
    else
        echo -e "\033[35m进程 $proxy_process_name 未运行, 无需停止。\033[0m"
    fi
}

proxy_status() {
    echo -e "STATUS of PROXY LOG..."
    # is_process_running "$proxy_process_name" && sudo tail -n 1 /var/log/sockd.log || echo -e "\033[35m进程 $proxy_process_name 未运行。\033[0m"
    # echo -e "\n"
    systemctl status $proxy_service_name
    echo -e "\n"
}

read -p "请输入要执行的操作: start(1), stop(2), status(3), restart_vpn(4), restart_proxy(5): " action

case $action in
    start|1)
        get_vpn_auth_code $1
        vpn_start;
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
