# wdpass-tool.bash
# 
:<<!
Usage:
sudo bash -c /PATH/TO/THIS_SCRIPT.bash 
必须将 wdpass.bin 文件放置于该脚本同一目录。
!

#!/bin/bash

export Work_Dir=`dirname $0`
readonly Mount_Point=$HOME/WD_My_Passport_Ultra/

mkdir -p ${Mount_Point}

# 查找硬盘设备
function get_disk() {
    # 查找 WD My Passport 0820 的硬盘设备标识（/dev/sd*）
    DISK_ID=`lsblk | awk '$4 == "1.8T" && $6 == "disk" {print $1}'`
    # DISK_ID=`sudo dmesg | grep -i 'Attached SCSI disk' | tail -n 1 | awk -F '[][]' '{print $4}'`
    # DISK_ID=`sudo dmesg | grep -i scsi | grep -a7 "My Passport 0820" | awk '/Attached SCSI disk/ {a=$0} END {split(a, parts, /[][]/); print parts[4]}'`

    #如果成功取得硬盘设备标识且硬盘块设备真实存在，那么打印硬盘设备标识，否则打印错误信息并退出（退出码41）。
    DISK_DEV=/dev/"${DISK_ID}"
    if [[ -n "${DISK_ID}" && -b "${DISK_DEV}" ]]; then
        echo "[leion:]The disk is ${DISK_DEV}"
    elif [[ -z ${DISK_ID} || ! -b ${DISK_DEV} ]]; then
        echo "[leion:]"DISK_ID" not fond!"
        exit 41
    fi
}

# 解锁硬盘。
function unlock_disk() {
    #使用密文解锁硬盘。
    sudo sg_raw -s 40 -i ${Work_Dir}/wdpass.bin ${DISK_DEV} c1 e1 00 00 00 00 00 00 28 00
    #等待硬盘分区出现。
    PART_DEV=/dev/${DISK_ID}'1'
    until [[ -b ${PART_DEV} ]]
    do sleep 1 && echo "[leion:]waitting for ${PART_DEV}..."
    done
    #或者：
    # while [[ ! -b "${PART_DEV}" ]]
    # do sleep 1 && echo "[leion:]waitting for "${PART_DEV}"..."
    # done
    echo "[leion:]The disk ${DISK_DEV} is unlocked, the partition is ${PART_DEV}"
}

# 挂载硬盘分区。
function mount_part() {
    #检查挂载点是否存在。
    [[ ! -d "${Mount_Point}" ]] && echo "[leion:]The mount point ${Mount_Point} not exist!"
    #挂载硬盘分区。
    sudo mount "${PART_DEV}" "${Mount_Point}" 
    if [ $? == 0 ]; then
        echo "[leion:]The disk partition is mounted on ${Mount_Point}"
    else
        echo "[leion:]Something wrong?"
        fi
}

function main() {
    get_disk
    unlock_disk
    mount_part
}

main "$@"