安装方法
	1. 在本地创建 /nfs 目录并添加设备列表文件 mount, (示例: example/mount.example)
	2. 在本地安装 nfs 服务，将 /nfs 目录开放挂载

使用方法
	1. 根据配置文件里的机器型号，将脚本注入到目标设备的 /var/tmp 目录下
		./expect.sh <remote_host_ip>
	2. 使用注入脚本管理目标设备
		bash ./var/tmp/service.sh <command>