#!/bin/bash
## starter-vpn-proxy.sh

vpn_process="charon"
proxy_process="sockd"

# 定义函数检查进程是否存在
is_process_running() {
    local process_name="$1"
    # 使用pgrep查找进程, 如果找到则返回0（成功）, 否则返回非0（失败）
    pgrep "$process_name" > /dev/null 2>&1
    return $?
}

# 定义函数检查字符串是否为有效的IPv4地址
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

get_vpn_auth_code() {
    # echo "\$1: " $1
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

    # 检查进程是否存在
    if  is_process_running "$vpn_process"; then
        echo "Process $vpn_process is running, try rebooting..."
        sudo sed -i 's/: XAUTH.*/: XAUTH  '"$vpn_auth_code"'/g' /etc/ipsec.secrets
        # sudo ipsec restart --nofork | grep --color=auto authentication
        # sudo ipsec restart
        sudo systemctl restart strongswan-starter.service
        # 手工指定 DNS 解析服务器
        # sudo sed -i '1i\nameserver 172.16.9.3' /etc/resolv.conf
        echo -e "\033[32mVPN 重启成功, ଘ(੭ˊᵕˋ)੭* ੈ✩.\033[0m"
    else
        echo "Process $vpn_process is not running, try booting..."
        sudo sed -i 's/: XAUTH.*/: XAUTH  '"$vpn_auth_code"'/g' /etc/ipsec.secrets
        # sudo ipsec start --nofork | grep --color=auto authentication
        # sudo ipsec start
        sudo systemctl restart strongswan-starter.service
        # 手工指定 DNS 解析服务器
        # sudo sed -i '1i\nameserver 172.16.9.3' /etc/resolv.conf
        # echo "VPN 启动成功, Yଘ(੭ˊᵕˋ)੭* ੈ✩"
        echo -e "\033[32mVPN 启动成功, Yଘ(੭ˊᵕˋ)੭* ੈ✩.\033[0m"
    fi
}

vpn_stop() {
    # 获取进程id
    vpn_process_id=`ps aux | grep $vpn_process | grep -v grep | awk '{print$2}'`
    # 检查进程id是否存在, 若存在(非空)则停掉
    if [[ -n "$vpn_process_id" ]]; then
        echo "STOPPING VPN..."
        # sudo ipsec stop
        sudo systemctl stop strongswan-starter.service
        echo -e "\033[35m进程 $vpn_process 已停止。\033[0m"
    else
        echo -e "\033[35m进程 $vpn_process 未运行, 无需停止。\033[0m"
    fi
}

vpn_status() {
    echo "STATUS of VPN..."
    is_process_running "$vpn_process" && sudo ipsec status || echo -e "\033[35m进程 $vpn_process 未运行。\033[0m"
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

    # 检查 IPv4 地址是否有效，既非空且符合 IPv4 地址格式
    if [ -n "$IP_VPN" ] && check_ipv4 "$IP_VPN"; then
        # 检查进程是否存在
        if is_process_running "$proxy_process"; then
            echo "Process $proxy_process is running, try rebooting..."
            # proxy_stop && sleep 1 && sudo sockd -D
            sudo systemctl restart sockd.service
            echo -e "\033[32mPROXY 重启成功, ଘ(੭ˊᵕˋ)੭* ੈ✩.\033[0m"
        else
            echo "Process $proxy_process is not running, try booting..."
            # sudo sockd -D
            sudo sed -i "s/^external:.*/external: $IP_VPN/" /etc/sockd.conf
            sudo systemctl start sockd.service
            echo -e "\033[32mPROXY 启动成功, ଘ(੭ˊᵕˋ)੭* ੈ✩.\033[0m"
        fi
    else
        echo -e "\nIP address of VPN is not ok! Check the vpn_auth_code will help .^_^.\n"
        exit 1
    fi
}

proxy_stop() {
    # 获取进程id
    proxy_process_id=`ps aux | grep $proxy_process | grep -v grep | awk '{print$2}'`
    # 检查进程id是否存在, 若存在(非空)则停掉
    if [[ -n "$proxy_process_id" ]]; then
        echo "STOPPING PROXY..."
        # sudo kill -9 $proxy_process_id 2>/dev/null
        # sudo rm -f /var/run/sockd.pid
        sudo systemctl stop sockd.service
        echo -e "\033[35m进程 $proxy_process 已停止。\033[0m"
    else
        echo -e "\033[35m进程 $proxy_process 未运行, 无需停止。\033[0m"
    fi
}

proxy_status() {
    echo -e "STATUS of PROXY LOG..."
    # is_process_running "$proxy_process" && sudo tail -n 1 /var/log/sockd.log || echo -e "\033[35m进程 $proxy_process 未运行。\033[0m"
    # echo -e "\n"
    systemctl status sockd.service
    echo -e "\n"
}

read -p "请输入要执行的操作: start(1), stop(2), status(3), restart_vpn(4), restart_proxy(5): " action

case $action in
    start|1)
        get_vpn_auth_code $1;
        vpn_start;
        sleep 3
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
