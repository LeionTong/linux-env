# KVM网桥创建指南

## 概述

本指南提供了在KVM虚拟化环境中创建和管理网桥的完整方法。网桥允许虚拟机与外部网络通信，是KVM网络配置的重要组成部分。

## 当前系统状态

根据您的系统检查，发现以下网络配置：

- **物理网络接口**: enp3s0f0, enp3s0f1, enp3s0f2, enp3s0f3
- **当前活跃接口**: enp3s0f2 (IP: 10.86.32.14/24)
- **现有KVM网络**: default (virbr0, 192.168.122.0/24)
- **其他网桥**: 多个Docker和Incus网桥

## 网桥创建方法

### 方法1: 使用virsh创建虚拟网络网桥（推荐）

这是最简单和最安全的方法，适合大多数使用场景。

```bash
# 创建虚拟网络网桥
./create-kvm-bridge.sh -v kvm-net br-kvm 192.168.100.1 255.255.255.0
```

**特点:**
- 自动创建网桥接口
- 提供DHCP服务
- 支持NAT转发
- 易于管理

### 方法2: 创建桥接到物理网络的网桥

当虚拟机需要直接访问外部网络时使用。

```bash
# 创建桥接到物理网络的网桥
./create-kvm-bridge.sh -p kvm-physical br-physical enp3s0f0
```

**注意事项:**
- 需要选择一个未使用的物理接口
- 会暂时中断物理接口的网络连接
- 适合生产环境

### 方法3: 手动创建Linux网桥

提供最大的灵活性，适合高级用户。

```bash
# 创建Linux网桥
./create-kvm-bridge.sh -l br-manual 192.168.200.1 255.255.255.0
```

## 使用脚本

### 查看帮助信息
```bash
./create-kvm-bridge.sh -h
```

### 查看当前网络状态
```bash
./create-kvm-bridge.sh -s
```

### 创建虚拟网络网桥
```bash
./create-kvm-bridge.sh -v <网络名> <网桥名> <IP地址> <子网掩码>
```

### 创建物理网桥
```bash
./create-kvm-bridge.sh -p <网络名> <网桥名> <物理接口>
```

### 创建Linux网桥
```bash
./create-kvm-bridge.sh -l <网桥名> <IP地址> <子网掩码>
```

## 手动创建网桥的详细步骤

### 步骤1: 创建虚拟网络配置文件

```xml
<network>
  <name>kvm-bridge</name>
  <uuid>12345678-1234-1234-1234-123456789abc</uuid>
  <forward mode='bridge'/>
  <bridge name='br-kvm' stp='on' delay='0'/>
  <ip address='192.168.100.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.100.2' end='192.168.100.254'/>
    </dhcp>
  </ip>
</network>
```

### 步骤2: 定义并启动网络

```bash
# 定义网络
virsh net-define kvm-bridge.xml

# 设置自动启动
virsh net-autostart kvm-bridge

# 启动网络
virsh net-start kvm-bridge
```

### 步骤3: 验证网桥创建

```bash
# 查看网络列表
virsh net-list --all

# 查看网桥状态
ip link show type bridge

# 查看网桥详细信息
virsh net-dumpxml kvm-bridge
```

## 在虚拟机中使用网桥

### 创建虚拟机时指定网桥

```bash
virt-install \
  --name vm1 \
  --ram 2048 \
  --disk path=/var/lib/libvirt/images/vm1.qcow2,size=20 \
  --vcpus 2 \
  --os-type linux \
  --network bridge=br-kvm \
  --graphics vnc
```

### 修改现有虚拟机的网络

```bash
# 查看虚拟机网络配置
virsh domiflist vm1

# 修改网络接口
virsh attach-device vm1 network.xml
```

## 网络配置文件示例

### 虚拟网络配置 (kvm-bridge.xml)
```xml
<network>
  <name>kvm-bridge</name>
  <uuid>12345678-1234-1234-1234-123456789abc</uuid>
  <forward mode='bridge'/>
  <bridge name='br-kvm' stp='on' delay='0'/>
  <ip address='192.168.100.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.100.2' end='192.168.100.254'/>
    </dhcp>
  </ip>
</network>
```

### 物理网桥配置 (kvm-bridge-physical.xml)
```xml
<network>
  <name>kvm-bridge-physical</name>
  <uuid>87654321-4321-4321-4321-cba987654321</uuid>
  <forward mode='bridge'/>
  <bridge name='br-physical' stp='on' delay='0'/>
</network>
```

## 故障排除

### 常见问题

1. **网桥创建失败**
   ```bash
   # 检查KVM服务状态
   systemctl status libvirtd
   
   # 重启KVM服务
   systemctl restart libvirtd
   ```

2. **虚拟机无法连接网络**
   ```bash
   # 检查网桥状态
   ip link show br-kvm
   
   # 检查DHCP服务
   virsh net-dumpxml kvm-bridge
   ```

3. **物理网桥配置问题**
   ```bash
   # 检查物理接口状态
   ip link show enp3s0f0
   
   # 重新配置网桥
   brctl show br-physical
   ```

### 调试命令

```bash
# 查看所有网络接口
ip addr show

# 查看网桥信息
brctl show

# 查看KVM网络状态
virsh net-list --all

# 查看网络详细信息
virsh net-dumpxml <网络名>
```

## 安全注意事项

1. **网络隔离**: 为不同的虚拟机组创建独立的网桥
2. **访问控制**: 使用防火墙规则限制网桥访问
3. **监控**: 定期检查网桥流量和连接状态
4. **备份**: 备份网络配置文件

## 性能优化

1. **网桥参数调优**:
   ```bash
   # 禁用STP（如果不需要环路检测）
   brctl stp br-kvm off
   
   # 设置网桥优先级
   brctl setbridgeprio br-kvm 32768
   ```

2. **网络接口优化**:
   ```bash
   # 启用巨型帧（如果网络支持）
   ip link set br-kvm mtu 9000
   ```

## 总结

本指南提供了在KVM环境中创建和管理网桥的完整解决方案。建议根据具体需求选择合适的方法：

- **开发/测试环境**: 使用虚拟网络网桥
- **生产环境**: 使用物理网桥或虚拟网络网桥
- **高级用户**: 使用手动Linux网桥

使用提供的脚本可以简化网桥创建过程，同时确保配置的正确性和一致性。
