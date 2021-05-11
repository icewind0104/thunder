{% extends 'src/base.sh' %}

{% block coin %}
# stop service
function stop() {
	for each in `ps -ef| grep chia-blockchain | grep -v grep | awk '{print $2}'`;do
		kill $each
	done

	/root/chia-blockchain/venv/bin/chia stop all -d || echo "ignor error"
}

# show processes
function show() {
	ps -ef | grep chia | grep -v grep
}

# start service
function start() {
	clear
	
	if [ -f "/etc/init.d/nfs.sh" ];then
		__nfs_mount `cat /etc/init.d/nfs.sh`:/hdd /hdd
	fi
	
	# create log dir
	if [ ! -d "$ENV_LOG_PATH" ];then
		mkdir $ENV_LOG_PATH
	fi

	if [ ! "`ps -ef | grep chia_harvester | grep -v grep | wc -l`" == "1" ];then
		cd /root/chia-blockchain
		. ./activate
		/root/chia-blockchain/venv/bin/chia start harvester -r
		deactivate
	fi

	for each in `seq 1 18`;do
		taskset -c $(($each * 2 - 1)),$(($each * 2)) nohup /root/chia-blockchain/venv/bin/chia plots create -f 95608afc827be4730b1cd531ea2a6226f7f1f68352542d3852d38686fece2c9c6ac4c085de8dcc1a38a6a5237bcb4576 -p 903d09e2bc479a006056dea32695e7c5ec781e7cfb41fe6a320e374dc809949a941f17eac79bc4ac06375c46c233232f -k 32 -r 2 -n 100000 -t /nvme$((($each + 1) % 2 + 1)) -d /hdd >> $ENV_LOG_PATH/plots$each.log 2>&1 &
		sleep 300
	done
}

# remove useless files
function clear() {
	rm -f /nvme1/*
	rm -f /nvme2/*
}

# rewrite config file
function init() {
	__save_nfs_config
}

# get new scripts
function sync() {
	echo "No sync method."
}

# setup system enviroment
function deploy() {
	cd /root/

	if [ ! -d "/root/ca" -o ! -d "/root/chia-blockchain" ];then
		mount -t nfs 10.2.0.102:/nfs /mnt -o nolock
		[ ! -d "/root/ca" ] && cp -r /mnt/ca /root/
		[ ! -d "/root/chia-blockchain" ] && cp -r /mnt/chia-blockchain /root/
		umount /mnt
	fi

	apt-get update
	apt-get upgrade -y
	apt install git

	cd /root/chia-blockchain
	bash install.sh

	sleep 5

	. ./activate
	chia init

	sleep 5

	/root/chia-blockchain/venv/bin/chia stop all -d || echo "ignor error"

	sleep 5

	/root/chia-blockchain/venv/bin/chia init -c /root/ca/

	sleep 5

	/root/chia-blockchain/venv/bin/chia configure --set-farmer-peer 10.0.1.209:8447

	sleep 5

	/root/chia-blockchain/venv/bin/chia start harvester -r
}
{% endblock %}
