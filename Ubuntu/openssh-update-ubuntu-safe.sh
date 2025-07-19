#!/bin/bash
#
########################################################################
# Function   :openssh update for Ubuntu 22.04
# Platform   :Ubuntu 22.04
# Date       :2025-07-11
# Description: 安全升级OpenSSH版本
# Features   :
#   在线升级: 支持在不中断现有连接的情况下进行升级
#   自动备份: 升级前自动备份原始二进制和配置文件
#   幂等性: 支持重复运行，不会重复安装
#   安全替换: 使用原子性操作替换二进制文件
#   连接保持: 确保现有SSH连接不会中断，升级后重新加载SSH服务配置（不重启）
########################################################################

clear
export LANG="en_US.UTF-8"

# 版本配置
zlib_version="zlib-1.3.1"
openssl_version="openssl-1.1.1w"
openssh_version="openssh-9.9p2"

# 安装包地址
file="/opt"
default="/usr/local"
date_time=`date +%Y-%m-%d—%H:%M`

# 安装目录
file_install="$file/openssh_install"
file_backup="$file/openssh_backup"
file_log="$file/openssh_log"

# 创建必要的目录
if [ ! -d "$file_install" ]; then
  mkdir -p "$file_install"
fi

if [ ! -d "$file_backup" ]; then
  mkdir -p "$file_backup"
fi

if [ ! -d "$file_log" ]; then
  mkdir -p "$file_log"
fi

if [ ! -d "$file_install/zlib" ]; then
  mkdir -p "$file_install/zlib"
fi

# 源码包链接
zlib_download="https://www.zlib.net/$zlib_version.tar.gz"
openssl_download="https://www.openssl.org/source/$openssl_version.tar.gz"
openssh_download="https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/$openssh_version.tar.gz"

# 检查现有SSH连接
check_ssh_connections() {
    echo -e "\033[33m 检查现有SSH连接...... \033[0m"
    current_connections=$(ss -tn state established | grep :22 | wc -l)
    echo -e "当前SSH连接数: $current_connections"
    
    if [ $current_connections -gt 0 ]; then
        echo -e "\033[33m 警告：检测到 $current_connections 个活跃SSH连接 \033[0m"
        echo -e "\033[33m 建议：请确保有备用连接方式（如控制台访问）\033[0m"
        read -p "是否继续升级？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "升级已取消"
            exit 1
        fi
    fi
}

setup_build_environment()
{
    # 检查是否为root用户
    if [ $(id -u) != "0" ]; then
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e " 当前用户为普通用户，必须使用root用户运行，脚本退出中......" "\033[31m Error\033[0m"
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo ""
        sleep 4
        exit
    fi

    # 更新包列表
    echo -e "\033[33m 正在更新包列表...... \033[0m"
    sleep 2
    echo ""
    apt update

    # 判断是否安装wget
    echo -e "\033[33m 正在安装Wget...... \033[0m"
    sleep 2
    echo ""
    if ! type wget >/dev/null 2>&1; then
        apt install -y wget
    else
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e " wget已经安装了：" "\033[32m Please continue\033[0m"
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo ""
    fi

    # 判断是否安装tar
    echo -e "\033[33m 正在安装TAR...... \033[0m"
    sleep 2
    echo ""
    if ! type tar >/dev/null 2>&1; then
        apt install -y tar
    else
        echo ""
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e " tar已经安装了：" "\033[32m Please continue\033[0m"
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
    fi
    echo ""

    # 安装相关依赖包 (Ubuntu版本)
    echo -e "\033[33m 正在安装依赖包...... \033[0m"
    sleep 3
    echo ""
    apt install -y build-essential gcc g++ make autoconf libtool pkg-config \
                   libssl-dev zlib1g-dev libpam0g-dev libaudit-dev \
                   libselinux1-dev libkrb5-dev libgssapi-krb5-2 \
                   libwrap0-dev libedit-dev libldap2-dev libsasl2-dev
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e " 安装软件依赖包成功 " "\033[32m Success\033[0m"
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
    else
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e " 安装依赖包失败，脚本退出中......" "\033[31m Error\033[0m"
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        sleep 4
        exit
    fi
    echo ""
}

create_backup_files()
{
    # 创建备份目录
    mkdir -p $file_install
    mkdir -p $file_backup
    mkdir -p $file_log
    mkdir -p $file_backup/zlib
    mkdir -p $file_backup/ssl
    mkdir -p $file_backup/ssh
    mkdir -p $file_log/zlib
    mkdir -p $file_log/ssl
    mkdir -p $file_log/ssh

    # 备份文件（检查是否已有备份）
    if [ -f "/usr/bin/openssl" ]; then
        # 检查是否已有任何OpenSSL备份
        if [ ! "$(ls -A $file_backup/ssl/openssl_*.bak 2>/dev/null)" ]; then
            cp -rf /usr/bin/openssl $file_backup/ssl/openssl_$date_time.bak
            echo -e "\033[33m 已备份 OpenSSL: $file_backup/ssl/openssl_$date_time.bak \033[0m"
        else
            echo -e "\033[32m OpenSSL备份文件已存在，跳过备份 \033[0m"
        fi
    fi
    
    if [ -f "/etc/ssh/sshd_config" ]; then
        # 检查是否已有任何SSH配置备份
        if [ ! "$(ls -A $file_backup/ssh/ssh_*.bak 2>/dev/null)" ]; then
            cp -rf /etc/ssh $file_backup/ssh/ssh_$date_time.bak
            echo -e "\033[33m 已备份 SSH配置: $file_backup/ssh/ssh_$date_time.bak \033[0m"
        else
            echo -e "\033[32m SSH配置备份已存在，跳过备份 \033[0m"
        fi
    fi
    
    if [ -f "/lib/systemd/system/ssh.service" ]; then
        # 检查是否已有任何SSH服务文件备份
        if [ ! "$(ls -A $file_backup/ssh/ssh_*.service.bak 2>/dev/null)" ]; then
            cp -rf /lib/systemd/system/ssh.service $file_backup/ssh/ssh_$date_time.service.bak
            echo -e "\033[33m 已备份 SSH服务文件: $file_backup/ssh/ssh_$date_time.service.bak \033[0m"
        else
            echo -e "\033[32m SSH服务文件备份已存在，跳过备份 \033[0m"
        fi
    fi
    
    if [ -f "/etc/pam.d/sshd" ]; then
        # 检查是否已有任何PAM配置备份
        if [ ! "$(ls -A $file_backup/ssh/sshd_*.pam.bak 2>/dev/null)" ]; then
            cp -rf /etc/pam.d/sshd $file_backup/ssh/sshd_$date_time.pam.bak
            echo -e "\033[33m 已备份 PAM配置: $file_backup/ssh/sshd_$date_time.pam.bak \033[0m"
        else
            echo -e "\033[32m PAM配置备份已存在，跳过备份 \033[0m"
        fi
    fi
    
    if [ -f "/usr/bin/ssh-copy-id" ]; then
        if [ ! -f "/root/ssh-copy-id" ]; then
            cp -rf /usr/bin/ssh-copy-id /root/ssh-copy-id
            echo -e "\033[33m 已备份 ssh-copy-id: /root/ssh-copy-id \033[0m"
        else
            echo -e "\033[32m ssh-copy-id备份已存在，跳过备份 \033[0m"
        fi
    fi

    # 备份当前SSH二进制文件（检查是否已有备份）
    # 检查是否已有任何sshd二进制文件备份
    if [ ! "$(ls -A $file_backup/ssh/sshd_binary_*.bak 2>/dev/null)" ]; then
        cp -rf /usr/sbin/sshd $file_backup/ssh/sshd_binary_$date_time.bak
        echo -e "\033[33m 已备份 sshd二进制文件: $file_backup/ssh/sshd_binary_$date_time.bak \033[0m"
    else
        echo -e "\033[32m sshd二进制文件备份已存在，跳过备份 \033[0m"
    fi
    
    # 检查是否已有任何ssh二进制文件备份
    if [ ! "$(ls -A $file_backup/ssh/ssh_binary_*.bak 2>/dev/null)" ]; then
        cp -rf /usr/bin/ssh $file_backup/ssh/ssh_binary_$date_time.bak
        echo -e "\033[33m 已备份 ssh二进制文件: $file_backup/ssh/ssh_binary_$date_time.bak \033[0m"
    else
        echo -e "\033[32m ssh二进制文件备份已存在，跳过备份 \033[0m"
    fi
    
    # 检查是否已有任何ssh-keygen二进制文件备份
    if [ ! "$(ls -A $file_backup/ssh/ssh-keygen_binary_*.bak 2>/dev/null)" ]; then
        cp -rf /usr/bin/ssh-keygen $file_backup/ssh/ssh-keygen_binary_$date_time.bak
        echo -e "\033[33m 已备份 ssh-keygen二进制文件: $file_backup/ssh/ssh-keygen_binary_$date_time.bak \033[0m"
    else
        echo -e "\033[32m ssh-keygen二进制文件备份已存在，跳过备份 \033[0m"
    fi
    
    # 检查是否已有任何scp二进制文件备份
    if [ ! "$(ls -A $file_backup/ssh/scp_binary_*.bak 2>/dev/null)" ]; then
        cp -rf /usr/bin/scp $file_backup/ssh/scp_binary_$date_time.bak
        echo -e "\033[33m 已备份 scp二进制文件: $file_backup/ssh/scp_binary_$date_time.bak \033[0m"
    else
        echo -e "\033[32m scp二进制文件备份已存在，跳过备份 \033[0m"
    fi
    
    # 检查是否已有任何sftp二进制文件备份
    if [ ! "$(ls -A $file_backup/ssh/sftp_binary_*.bak 2>/dev/null)" ]; then
        cp -rf /usr/bin/sftp $file_backup/ssh/sftp_binary_$date_time.bak
        echo -e "\033[33m 已备份 sftp二进制文件: $file_backup/ssh/sftp_binary_$date_time.bak \033[0m"
    else
        echo -e "\033[32m sftp二进制文件备份已存在，跳过备份 \033[0m"
    fi
    
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
    echo -e " 备份完成 " "\033[32m Success\033[0m"
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
    echo ""
}

download_source_packages()
{
    # 下载zlib
    echo -e "\033[33m 正在下载Zlib软件包...... \033[0m"
    sleep 3
    echo ""
    if [ -e $file/$zlib_version.tar.gz ]; then
        echo -e " 下载软件源码包已存在  " "\033[32m  Please continue\033[0m"
    else
        echo -e "\033[33m 未发现zlib本地源码包，链接检查获取中........... \033[0m "
        sleep 1
        echo ""
        cd $file
        wget --no-check-certificate $zlib_download
        echo ""
    fi

    # 下载openssl
    echo -e "\033[33m 正在下载Openssl软件包...... \033[0m"
    sleep 3
    echo ""
    if [ -e $file/$openssl_version.tar.gz ]; then
        echo -e " 下载软件源码包已存在  " "\033[32m  Please continue\033[0m"
    else
        echo -e "\033[33m 未发现openssl本地源码包，链接检查获取中........... \033[0m "
        echo ""
        sleep 1
        cd $file
        wget --no-check-certificate $openssl_download
        echo ""
    fi

    # 下载openssh
    echo -e "\033[33m 正在下载Openssh软件包...... \033[0m"
    sleep 3
    echo ""
    if [ -e $file/$openssh_version.tar.gz ]; then
        echo -e " 下载软件源码包已存在  " "\033[32m  Please continue\033[0m"
    else
        echo -e "\033[33m 未发现openssh本地源码包，链接检查获取中........... \033[0m "
        echo ""
        sleep 1
        cd $file
        wget --no-check-certificate $openssh_download
    fi
}

compile_and_install_zlib()
{
    # 检查是否已经安装
    if [ -e $default/$zlib_version/lib/libz.so ]; then
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e "  Zlib已安装，跳过编译安装步骤" "\033[32m Skipped\033[0m"
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo ""
        return 0
    fi

    echo -e "\033[33m 1.1-正在解压Zlib软件包...... \033[0m"
    sleep 3
    echo ""
    cd $file && mkdir -p $file_install
    
    # 幂等性：检查是否已经解压
    if [ ! -d $file_install/$zlib_version ]; then
        tar -xzf zlib*.tar.gz -C $file_install
    else
        echo -e "\033[32m Zlib源码已解压，跳过解压步骤 \033[0m"
    fi
    
    if [ -d $file_install/$zlib_version ]; then
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e "  zlib解压源码包成功" "\033[32m Success\033[0m"
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo ""
    else
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e "  zlib解压源码包失败，脚本退出中......" "\033[31m Error\033[0m"
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo ""
        sleep 4
        exit
    fi

    echo -e "\033[33m 1.2-正在编译安装Zlib服务.............. \033[0m"
    sleep 3
    echo ""
    cd $file_install/$zlib_version
    echo -e "当前目录: $(pwd)"
    ./configure --prefix=$default/$zlib_version > $file_log/zlib/zlib_configure_$date_time.txt
    if [ $? -eq 0 ]; then
        echo -e "\033[33m make... \033[0m"
        make > /dev/null 2>&1
        echo $?
        echo -e "\033[33m make test... \033[0m"
        make test > /dev/null 2>&1
        echo $?
        echo -e "\033[33m make install... \033[0m"
        make install > /dev/null 2>&1
        echo $?
    else
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e "  编译安装压缩库失败，脚本退出中..." "\033[31m Error\033[0m"
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo ""
        sleep 4
        exit
    fi

    if [ -e $default/$zlib_version/lib/libz.so ]; then
        # 幂等性：检查是否已经配置了库路径
        if ! grep -q "$default/$zlib_version/lib" /etc/ld.so.conf; then
            sed -i '/zlib/'d /etc/ld.so.conf
            echo "$default/$zlib_version/lib" >> /etc/ld.so.conf
        fi
        
        # 幂等性：检查是否已经创建了配置文件
        if [ ! -f "/etc/ld.so.conf.d/zlib.conf" ] || ! grep -q "$default/$zlib_version/lib" /etc/ld.so.conf.d/zlib.conf; then
            echo "$default/$zlib_version/lib" > /etc/ld.so.conf.d/zlib.conf
        fi
        
        ldconfig -v > $file_log/zlib/zlib_ldconfig_$date_time.txt > /dev/null 2>&1
        /sbin/ldconfig
    fi
}

compile_and_install_openssl()
{
    # 检查是否已经安装
    if [ -e $default/$openssl_version/bin/openssl ] && [ -L /usr/bin/openssl ]; then
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e "  OpenSSL已安装，跳过编译安装步骤" "\033[32m Skipped\033[0m"
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo ""
        return 0
    fi

    echo -e "\033[33m 2.1-正在解压Openssl...... \033[0m"
    sleep 3
    echo ""
    cd $file
    
    # 幂等性：检查是否已经解压
    if [ ! -d $file_install/$openssl_version ]; then
        tar -xvzf openssl*.tar.gz -C $file_install
    else
        echo -e "\033[32m OpenSSL源码已解压，跳过解压步骤 \033[0m"
    fi
    
    if [ -d $file_install/$openssl_version ]; then
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e "  OpenSSL解压源码包成功" "\033[32m Success\033[0m"
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
    else
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e "  OpenSSL解压源码包失败，脚本退出中......" "\033[31m Error\033[0m"
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo ""
        sleep 4
        exit
    fi
    echo ""

    echo -e "\033[33m 2.2-正在编译安装Openssl服务...... \033[0m"
    sleep 3
    echo ""
    cd $file_install/$openssl_version
    ./config shared zlib --prefix=$default/$openssl_version > $file_log/ssl/ssl_config_$date_time.txt
    if [ $? -eq 0 ]; then
        echo -e "\033[33m make clean... \033[0m"
        make clean > /dev/null 2>&1
        echo $?
        echo -e "\033[33m make -j 4... \033[0m"
        make -j 4 > /dev/null 2>&1
        echo $?
        echo -e "\033[33m make install... \033[0m"
        make install > /dev/null 2>&1
        echo $?
    else
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e "  编译安装OpenSSL失败，脚本退出中..." "\033[31m Error\033[0m"
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo ""
        sleep 4
        exit
    fi

    # 幂等性：备份原文件（如果存在且不是软链接）
    if [ -f /usr/bin/openssl ] && [ ! -L /usr/bin/openssl ]; then
        mv /usr/bin/openssl /usr/bin/openssl_$date_time.bak
    fi
    
    if [ -e $default/$openssl_version/bin/openssl ]; then
        # 幂等性：检查是否已经配置了库路径
        if ! grep -q "$default/$openssl_version/lib" /etc/ld.so.conf; then
            sed -i '/openssl/'d /etc/ld.so.conf
            echo "$default/$openssl_version/lib" >> /etc/ld.so.conf
        fi
        
        # 幂等性：创建软链接（如果不存在或指向错误位置）
        if [ ! -L /usr/bin/openssl ] || [ "$(readlink /usr/bin/openssl)" != "$default/$openssl_version/bin/openssl" ]; then
            ln -sf $default/$openssl_version/bin/openssl /usr/bin/openssl
        fi
        
        # 幂等性：创建库软链接
        if [ ! -L /usr/lib/x86_64-linux-gnu/libssl.so.1.1 ] || [ "$(readlink /usr/lib/x86_64-linux-gnu/libssl.so.1.1)" != "$default/$openssl_version/lib/libssl.so.1.1" ]; then
            ln -sf $default/$openssl_version/lib/libssl.so.1.1 /usr/lib/x86_64-linux-gnu/libssl.so.1.1
        fi
        
        if [ ! -L /usr/lib/x86_64-linux-gnu/libcrypto.so.1.1 ] || [ "$(readlink /usr/lib/x86_64-linux-gnu/libcrypto.so.1.1)" != "$default/$openssl_version/lib/libcrypto.so.1.1" ]; then
            ln -sf $default/$openssl_version/lib/libcrypto.so.1.1 /usr/lib/x86_64-linux-gnu/libcrypto.so.1.1
        fi
        
        ldconfig -v > $file_log/ssl/ssl_ldconfig_$date_time.txt > /dev/null 2>&1
        /sbin/ldconfig
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e " 编译安装OpenSSL " "\033[32m Success\033[0m"
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo ""

        echo -e "\033[33m 2.3-正在输出 OpenSSL 版本状态.............. \033[0m"
        sleep 3
        echo ""
        echo -e "\033[32m====================== OpenSSL version =====================  \033[0m"
        echo ""
        openssl version -a
        echo ""
        echo -e "\033[32m=======================================================  \033[0m"
        sleep 2
    else
        echo ""
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e " OpenSSL软连接失败，脚本退出中..." "\033[31m  Error\033[0m"
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
    fi
}

compile_and_install_openssh()
{
    # 检查是否已经安装
    if [ -e $default/$openssh_version/bin/ssh ] && [ -f /usr/bin/ssh ]; then
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e "  OpenSSH已安装，跳过编译安装步骤" "\033[32m Skipped\033[0m"
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo ""
        return 0
    fi

    echo -e "\033[33m 3.1-正在解压OpenSSH...... \033[0m"
    sleep 3
    echo ""
    cd $file
    
    # 幂等性：检查是否已经解压
    if [ ! -d $file_install/$openssh_version ]; then
        tar -xvzf openssh*.tar.gz -C $file_install
    else
        echo -e "\033[32m OpenSSH源码已解压，跳过解压步骤 \033[0m"
    fi
    
    if [ -d $file_install/$openssh_version ]; then
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e "  OpenSSH解压源码包成功" "\033[32m Success\033[0m"
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
    else
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e "  OpenSSH解压源码包失败，脚本退出中......" "\033[31m Error\033[0m"
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo ""
        sleep 4
        exit
    fi
    echo ""

    echo -e "\033[33m 3.2-正在编译安装OpenSSH服务...... \033[0m"
    sleep 3
    echo ""
    cd $file_install/$openssh_version
    ./configure --prefix=$default/$openssh_version --sysconfdir=/etc/ssh --with-ssl-dir=$default/$openssl_version --with-zlib=$default/$zlib_version --with-pam > $file_log/ssh/ssh_configure_$date_time.txt
    if [ $? -eq 0 ]; then
        echo -e "\033[33m make -j 4... \033[0m"
        make -j 4 > /dev/null 2>&1
        echo $?
        echo -e "\033[33m make install... \033[0m"
        make install > /dev/null 2>&1
        echo $?
    else
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e " 编译安装OpenSSH失败，脚本退出中......" "\033[31m Error\033[0m"
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo ""
        sleep 4
        exit
    fi

    echo ""
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
    echo -e " 编译安装OpenSSH " "\033[32m Success\033[0m"
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
    echo ""
    sleep 2
    echo -e "\033[32m==================== OpenSSH—file version =================== \033[0m"
    echo ""
    $default/$openssh_version/bin/ssh -V
    echo ""
    echo -e "\033[32m======================================================= \033[0m"
    sleep 3
    echo ""

    echo -e "\033[33m 3.3-正在安全迁移OpenSSH配置文件...... \033[0m"
    sleep 3
    echo ""

    # 安全替换二进制文件（保持现有连接）
    echo -e "\033[33m 正在安全替换SSH二进制文件...... \033[0m"
    
    # 幂等性：检查并创建临时文件
    if [ ! -f "/usr/sbin/sshd.new" ]; then
        cp -rf $default/$openssh_version/sbin/sshd /usr/sbin/sshd.new
    fi
    if [ ! -f "/usr/bin/ssh.new" ]; then
        cp -rf $default/$openssh_version/bin/ssh /usr/bin/ssh.new
    fi
    if [ ! -f "/usr/bin/ssh-keygen.new" ]; then
        cp -rf $default/$openssh_version/bin/ssh-keygen /usr/bin/ssh-keygen.new
    fi
    if [ ! -f "/usr/bin/scp.new" ]; then
        cp -rf $default/$openssh_version/bin/scp /usr/bin/scp.new
    fi
    if [ ! -f "/usr/bin/sftp.new" ]; then
        cp -rf $default/$openssh_version/bin/sftp /usr/bin/sftp.new
    fi
    
    # 设置权限
    chmod +x /usr/sbin/sshd.new
    chmod +x /usr/bin/ssh.new
    chmod +x /usr/bin/ssh-keygen.new
    chmod +x /usr/bin/scp.new
    chmod +x /usr/bin/sftp.new

    # 创建配置文件（不覆盖现有配置）
    if [ ! -d "/etc/ssh" ]; then
        mkdir -p /etc/ssh
    fi
    
    # 幂等性：备份现有配置（如果不存在备份）
    if [ -f "/etc/ssh/sshd_config" ] && [ ! -f "/etc/ssh/sshd_config.backup" ]; then
        cp -rf /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    fi
    
    # 生成新的SSH密钥（如果不存在）
    if [ ! -f "/etc/ssh/ssh_host_rsa_key" ]; then
        ssh-keygen -A
    fi

    # 幂等性：配置SSH服务（追加配置，不覆盖）
    if [ -f "/etc/ssh/sshd_config" ]; then
        if ! grep -q "PermitRootLogin yes" /etc/ssh/sshd_config; then
            echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
        fi
        
        if ! grep -q "HostKeyAlgorithms +ssh-rsa" /etc/ssh/sshd_config; then
            echo 'HostKeyAlgorithms +ssh-rsa' >> /etc/ssh/sshd_config
        fi
        
        if ! grep -q "KexAlgorithms +diffie-hellman-group1-sha1" /etc/ssh/sshd_config; then
            echo 'KexAlgorithms +diffie-hellman-group1-sha1' >> /etc/ssh/sshd_config
        fi
    fi

    # 原子性替换二进制文件
    echo -e "\033[33m 正在原子性替换SSH二进制文件...... \033[0m"
    mv /usr/sbin/sshd.new /usr/sbin/sshd
    mv /usr/bin/ssh.new /usr/bin/ssh
    mv /usr/bin/ssh-keygen.new /usr/bin/ssh-keygen
    mv /usr/bin/scp.new /usr/bin/scp
    mv /usr/bin/sftp.new /usr/bin/sftp

    # 重新加载SSH服务配置（不重启）
    echo -e "\033[33m 正在重新加载SSH服务配置...... \033[0m"
    systemctl reload ssh
    
    if [ $? -eq 0 ]; then
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e " 安全升级OpenSSH成功" "\033[32m Success\033[0m"
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo ""
        sleep 2
        
        # 幂等性：删除源码包（如果存在）
        if [ -f "$file/$zlib_version.tar.gz" ]; then
            rm -rf $file/$zlib_version.tar.gz
        fi
        if [ -f "$file/$openssl_version.tar.gz" ]; then
            rm -rf $file/$openssl_version.tar.gz
        fi
        if [ -f "$file/$openssh_version.tar.gz" ]; then
            rm -rf $file/$openssh_version.tar.gz
        fi

        echo -e "\033[33m 3.4-正在输出 OpenSSH 版本...... \033[0m"
        sleep 3
        echo ""
        echo -e "\033[32m==================== OpenSSH version =================== \033[0m"
        echo ""
        ssh -V
        echo ""
        echo -e "\033[32m======================================================== \033[0m"
    else
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e " 重新加载SSH服务失败，正在回滚......" "\033[31m Error\033[0m"
        echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        
        # 回滚二进制文件
        if [ -f "$file_backup/ssh/sshd_binary_$date_time.bak" ]; then
            cp -rf $file_backup/ssh/sshd_binary_$date_time.bak /usr/sbin/sshd
        else
            echo -e "\033[31m 警告：sshd备份文件不存在，无法回滚 \033[0m"
        fi
        if [ -f "$file_backup/ssh/ssh_binary_$date_time.bak" ]; then
            cp -rf $file_backup/ssh/ssh_binary_$date_time.bak /usr/bin/ssh
        else
            echo -e "\033[31m 警告：ssh备份文件不存在，无法回滚 \033[0m"
        fi
        systemctl reload ssh
        sleep 4
        exit
    fi
    echo ""
}

verify_installation()
{
    # sshd状态
    echo ""
    echo -e "\033[33m 输出sshd服务状态： \033[33m"
    sleep 2
    echo ""
    systemctl status ssh
    echo ""
    echo ""
    echo ""
    sleep 1

    echo -e "\033[33m==================== OpenSSH file =================== \033[0m"
    echo ""
    echo -e " Openssh升级安装目录请前往:  "
    cd $file_install && pwd
    cd ~
    echo ""
    echo -e " Openssh升级备份目录请前往:  " 
    cd $file_backup && pwd
    cd ~
    echo ""
    echo -e " Openssh升级日志目录请前往:  "
    cd $file_log && pwd
    cd ~
    echo ""
    echo -e "\033[33m======================================================= \033[0m"
    
    echo ""
    echo -e "\033[32m==================== 升级完成 =================== \033[0m"
    echo -e "\033[32m 现有SSH连接应该保持稳定 \033[0m"
    echo -e "\033[32m 新连接将使用升级后的OpenSSH版本 \033[0m"
    echo -e "\033[32m======================================================= \033[0m"
}

# 主执行流程
echo ""
echo ""
check_ssh_connections
setup_build_environment
create_backup_files
download_source_packages
compile_and_install_zlib
compile_and_install_openssl
compile_and_install_openssh
verify_installation 