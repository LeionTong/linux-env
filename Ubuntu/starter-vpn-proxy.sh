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

    echo "STARTING VPN..."
    sudo sed -i 's/: XAUTH.*/: XAUTH  '"$vpn_auth_code"'/g' /etc/ipsec.secrets
    # sudo ipsec start --nofork | grep --color=auto authentication
    # sudo ipsec start
    sudo systemctl start strongswan-starter.service
    ## 手工指定 DNS 解析服务器
    # sudo sed -i '1i\nameserver 172.16.9.3' /etc/resolv.conf
}

vpn_status() {
    echo "STATUS of VPN..."
    # sudo ipsec status
    systemctl status strongswan-starter.service
}

vpn_stop() {
    echo "STOPPING VPN..."
    # sudo ipsec stop
    sudo systemctl stop strongswan-starter.service
}

proxy_start() {
    echo "STARTING PROXY..."
    IP_VPN=`hostname -I | awk '{print$2}'`
    if [[ $IP_VPN != "" ]]; then
        sudo sed -i "s/^external:.*/external: $(hostname -I | awk '{print$2}')/" /etc/danted.conf
        sudo systemctl restart danted.service
    else
        echo -e "\nIP address of VPN is not exist! Check the vpn_auth_code will help .^_^.\n"
        proxy_stop;
        vpn_stop;
    fi
}

proxy_status() {
    echo "STATUS of PROXY..."
    systemctl status danted.service
    # echo -e "\n\nSTATUS of PROXY LOG..."
    # date_abbre_month=`date +"%b"` ; date_day=`date +"%d"` ; awk '$1~/'$date_abbre_month'/ && $2~/'$date_day'/ && /dante/ {print}' /var/log/syslog
    # awk -v date_abbre_month=`date +"%b"` -v date_day=`date +"%d"` '$1~date_abbre_month && $2~date_day && /dante/ {print}' /var/log/syslog
}

proxy_stop() {
    echo "STOPPING PROXY..."
    sudo systemctl stop danted.service
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
