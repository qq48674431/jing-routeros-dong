# RouterOS CHR v7.21.3 命令流程

本页内容汇总了在使用脚本完成 RouterOS (ROS) 安装并首次登入后，常常会碰到的一些进阶配置与管理命令，方便您进行快速复制与调整。

## 一、登录与基础维护验证

### 1. SSH 验证登录

如果在安装向导的一键脚本中使用了默认或者自定义的密码，重启后可以使用 SSH 尝试登录：

```bash
ssh admin@<你的IP地址>
# 输入一键安装脚本里配置的密码，例如: Admin112233
```

### 2. 查看当前网络验证

进入 RouterOS 命令行后，确认自动注入的网络是不是工作正常：

```routeros
# 查看 IP 地址是否被自动分配好
/ip address print

# 查看默认网关路由
/ip route print
```

### 3. 修改系统密码

如果有必要或者前期未修改密码，可以通过简便命令随时修改：

```routeros
/password
```

## 二、常用基础进阶配置命令

### 1. 端口与服务安全修改

对于通常的云主机，修改标准端口以防扫描往往是个好习惯。

```routeros
# 将 WinBox 的访问端口修改为你喜欢的隐秘端口 (例如取代默认的 8291)
/ip service set winbox port=18291

# 如果希望通过特定 IP 才允许访问 Winbox 和 SSH，可以附带 address 参数
# /ip service set winbox address=192.168.1.0/240
```

### 2. DNS 配置

为 ROS 系统配置公共的 DNS 服务器，这样路由器系统自身进行发包检测或者升级时就可以顺利解析到远端域名：

```routeros
/ip dns set servers=8.8.8.8,1.1.1.1 allow-remote-requests=yes
```

### 3. 时间与 NTP 同步配置

保持系统时间同步，对于日志排故与安全证书都非常重要：

```routeros
/system ntp client set enabled=yes
/system ntp client servers add address=pool.ntp.org
```

## 三、脚本核心安装自动注入执行的参考

下面这部分内容是一键脚本 `v7.21.3install.sh` 写入到系统底层离线分区里的一段代码。了解它有助于你知道系统“出厂”被设置成了什么样貌；如果有自定义的需要，您也可以举一反三在未来调整安装脚本：

```routeros
# 初始化管理员密码
/user set [find name=admin] password="<设定的密码>"

# 将默认的主网卡重命名为 wan
/interface ethernet set [ find default-name=ether1 ] name=wan

# 配置地址并加上路由网关
/ip address add address=<获取到的IP> interface=wan
/ip route add gateway=<获取到的网关>

# 关闭掉不需要的特权后门 telnet 功能，并确保 SSH(22)和 Winbox 开启
/ip service set telnet disabled=yes
/ip service set ssh disabled=no port=22
/ip service set winbox disabled=no
```

得益于这段命令在开机引导时的初始化，您的这台设备才可以做到即使云端硬装，结束后依然能够在公网立刻回连。
