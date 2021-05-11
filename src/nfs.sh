{% extends 'src/base.sh' %}

{% block coin %}
function start() {
	systemctl start nfs-kernel-server
}

function stop() {
	systemctl stop nfs-kernel-server
}

# deploy
function deploy() {
	if [ "`df | grep '/hdd' | grep '/dev/' | wc -l`" == "1" ];then
		apt install nfs-kernel-server -y
		chmod 777 /hdd
		if [ "`grep '/hdd' /etc/exports | wc -l`" == "0" ];then
			echo "/hdd *(insecure,rw,async,no_root_squash)" >> /etc/exports
		fi
		systemctl stop nfs-kernel-server
		systemctl disable nfs-kernel-server
	fi
}

# rewrite config file
function init() {
	echo "No init method."
}

{% endblock %}