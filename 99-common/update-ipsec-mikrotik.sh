#!/bin/sh

if [ -z "$1" ]; then
    echo "用法: $0 <IPsec密码>" >&2
    exit 1
fi

PASSWORD="$1"
CMD="/ip ipsec identity set [find peer="mynet.sitechcloud.com"] password=$PASSWORD"

if ssh admin@192.168.11.1 "$CMD"; then
    echo "✅ IPsec 密码更新成功。"
else
    echo "❌ 更新失败：SSH 或远程命令执行出错。" >&2
    exit 1
fi
