#!/bin/bash

# sudo sed -i '1i\nameserver 172.16.9.3' /etc/resolv.conf
CODE=$1
sudo sed -i 's/: XAUTH.*/: XAUTH  '"$CODE"'/g' /etc/ipsec.secrets
sudo ipsec start --nofork | grep --color=auto authentication


# sudo ipsec status
# systemctl status strongswan-starter.service
# sudo systemctl start strongswan-starter.service
# sudo systemctl stop strongswan-starter.service
