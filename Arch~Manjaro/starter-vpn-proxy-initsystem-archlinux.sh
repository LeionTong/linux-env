#!/bin/bash
## starter-vpn-proxy-initsystem-archlinux.sh

vpn_process="charon"
proxy_process="sockd"

# 定义函数检查进程是否存在
is_process_running() {
    local process_name="$1"
    # 使用pgrep查找进程，如果找到则返回0（成功），否则返回非0（失败）
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
                    return 1 # 前导零，无效
                fi
            else
                return 1 # 超出范围，无效
            fi
        done
        return 0 # 所有条件满足，有效
    else
        return 1 # 正则不匹配，无效
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
    if is_process_running "$vpn_process"; then
        echo "进程 $vpn_process 正在运行，尝试重启..."
        sudo sed -i 's/: XAUTH.*/: XAUTH  '"$vpn_auth_code"'/g' /etc/ipsec.secrets
        # sudo ipsec restart --nofork | grep --color=auto authentication
        sudo ipsec restart
        # sudo systemctl restart strongswan-starter.service
        # 手工指定 DNS 解析服务器
        # sudo sed -i '1i\nameserver 172.16.9.3' /etc/resolv.conf
        echo "Succeed to restart vpn."
    else
        echo "进程 $vpn_process 未运行，尝试启动..."
        sudo sed -i 's/: XAUTH.*/: XAUTH  '"$vpn_auth_code"'/g' /etc/ipsec.secrets
        # sudo ipsec start --nofork | grep --color=auto authentication
        sudo ipsec start
        # sudo systemctl restart strongswan-starter.service
        # 手工指定 DNS 解析服务器
        # sudo sed -i '1i\nameserver 172.16.9.3' /etc/resolv.conf
        echo "Succeed to start vpn."
    fi
}

vpn_stop() {
    # 获取进程id
    vpn_process_id=`ps aux | grep $vpn_process | grep -v grep | awk '{print$2}'`
    # 检查进程id是否存在，若存在(非空)则停掉
    if [ -n "$vpn_process_id" ]; then
        echo "STOPPING VPN..."
        sudo ipsec stop
        # sudo systemctl stop strongswan-starter.service
        echo "Succeed to stop vpn."
    else
        echo "进程 $vpn_process 未运行，无需停止。"
    fi
}

vpn_status() {
    echo "STATUS of VPN..."
    sudo ipsec status
    # systemctl status strongswan-starter.service
}

proxy_start() {
    echo "STARTING PROXY..."

    # 获取本机VPN的IPv4地址
    IP_VPN=`ip a | awk 'NR==11 && /inet /{ip=$2} END{gsub(/\/.*$/, "", ip); print ip}'`
    # 检查 IPv4 地址是否有效
    if check_ipv4 "$IP_VPN"; then
        # 检查进程是否存在
        if is_process_running "$proxy_process"; then
            echo "进程 $proxy_process 正在运行，尝试重启..."
            proxy_stop;
            sudo sockd -D
            # systemctl restart danted.service
            echo "Succeed to restart proxy."
        else
            echo "进程 $proxy_process 未运行，尝试启动..."
            sudo sockd -D
            # systemctl start danted.service
            echo "Succeed to start proxy."
        fi
    else
        echo -e "\nIP address of VPN is not ok! Check the vpn_auth_code will help .^_^.\n"
        vpn_stop;
        proxy_stop;
    fi
}

proxy_stop() {
    # 获取进程id
    proxy_process_id=`ps aux | grep $proxy_process | grep -v grep | awk '{print$2}'`
    # 检查进程id是否存在，若存在(非空)则停掉
    if [ -n "$proxy_process_id" ]; then
        echo "STOPPING PROXY..."
        sudo kill -9 $proxy_process_id 2>/dev/null
        sudo rm -f /var/run/sockd.pid
        echo "Succeed to stop proxy." | sudo tee -a /var/log/sockd.log
        # sudo systemctl stop danted.service
        # echo "Succeed to stop proxy."
    else
        echo "进程 $proxy_process 未运行，无需停止。"
    fi
}

proxy_status() {
    # echo "STATUS of PROXY..."
    # systemctl status sockd.service
    echo -e "\n\nSTATUS of PROXY LOG..."
    sudo tail /var/log/sockd.log
}

read -p "请输入要执行的操作: start(1), status(2), stop(3): " action

case $action in
    start|1)
        get_vpn_auth_code $1;
        vpn_start;
        sleep 3
        proxy_start;
        ;;
    status|2)
        vpn_status;
        echo -e "\n"
        proxy_status;
        ;;
    stop|3)
        vpn_stop;
        proxy_stop;
        ;;
    *)
        echo "输入的操作无效! $action"
        echo "Usage: $0 {start, status, stop or 1, 2, 3}."
        ;;
esac
