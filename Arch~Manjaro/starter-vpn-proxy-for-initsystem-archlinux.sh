#!/bin/bash
## starter-vpn-proxy.sh

# 定义函数来处理参数并打印结果
vpn_start() {
    # echo "\$1: " $1
    vpn_auth_code="$1"
    echo "vpn_auth_code: " $vpn_auth_code

    while [[ ! $vpn_auth_code ]]
    do
        read -p "请输入VPN授权码: " vpn_auth_code
        echo $vpn_auth_code
    done

    sudo echo "STARTING VPN..."
    sudo sed -i 's/: XAUTH.*/: XAUTH  '"$vpn_auth_code"'/g' /etc/ipsec.secrets
    # sudo ipsec restart --nofork | grep --color=auto authentication
    sudo ipsec restart
    # sudo systemctl restart strongswan-starter.service
    ## 手工指定 DNS 解析服务器
    # sudo sed -i '1i\nameserver 172.16.9.3' /etc/resolv.conf
}

vpn_status() {
    echo "STATUS of VPN..."
    sudo ipsec status
    # systemctl status strongswan-starter.service
}

vpn_stop() {
    sudo echo "STOPPING VPN..."
    sudo ipsec stop
    # sudo systemctl stop strongswan-starter.service
}

proxy_start() {
    echo "STARTING PROXY..."
    IP_VPN=`ip a | awk '/inet /{ip=$2} END{gsub(/\/.*$/, "", ip); print ip}'`
    if [[ $IP_VPN != "" ]]; then
        sudo sed -i "s/^external:.*/external: $IP_VPN/" /etc/sockd.conf
		sudo sockd -D
    else
        echo -e "\nIP address of VPN is not exist! Check the vpn_auth_code will help .^_^.\n"
        proxy_stop;
    fi
}

proxy_status() {
    # echo "STATUS of PROXY..."
    # systemctl status sockd.service
    echo -e "\n\nSTATUS of PROXY LOG..."
    sudo tail -f /var/log/sockd.log
}

proxy_stop() {
    echo "STOPPING PROXY..."
    sudo kill -9 `ps aux | grep sockd | awk '{print$2}'`
}


read -p "请输入要执行的操作: start(1), status(2), stop(3): " action

case $action in
    start|1)
        vpn_start $1;
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
        echo "你输入了无效操作! $action"
        echo "Usage: $0 {start, status, stop or 1, 2, 3}."
        ;;
esac
