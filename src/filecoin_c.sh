{% extends 'src/filecoin.sh' %}

{% block model %}
# start service
function start() {
	source /root/.env

    # C2
	if [ "$1" == "c" ];then
		APP_PATH=/root/dark/latest

		if [ -z "$2" ];then
			if [ ! -d "/var/tmp-c2-0" ];then
				mkdir /var/tmp-c2-0
			fi

			if [ ! -d "/var/tmp-c2-1" ];then
				mkdir /var/tmp-c2-1
			fi

			env env TMPDIR=/var/tmp-c2-0 nohup $APP_PATH/lotus-worker --worker-repo=/data/.lotusworker-p2-0  run --gpu=0 --listen=$IP:$(($WORKER_PORT + 21))  --addpiece=false --precommit1=false --precommit2=false --commit=true > $ENV_LOG_PATH/worker-c2-0.log 2>&1 &
			env env TMPDIR=/var/tmp-c2-1 nohup $APP_PATH/lotus-worker --worker-repo=/data/.lotusworker-p2-1  run --gpu=1 --listen=$IP:$(($WORKER_PORT + 22))  --addpiece=false --precommit1=false --precommit2=false --commit=true > $ENV_LOG_PATH/worker-c2-1.log 2>&1 &
		else
			if [ "$2" == "0" ];then
				env env TMPDIR=/var/tmp-c2-0 nohup $APP_PATH/lotus-worker --worker-repo=/data/.lotusworker-p2-0  run --gpu=0 --listen=$IP:$(($WORKER_PORT + 21))  --addpiece=false --precommit1=false --precommit2=false --commit=true > $ENV_LOG_PATH/worker-c2-0.log 2>&1 &
			fi

			if [ "$2" == "1" ];then
				env env TMPDIR=/var/tmp-c2-1 nohup $APP_PATH/lotus-worker --worker-repo=/data/.lotusworker-p2-1  run --gpu=1 --listen=$IP:$(($WORKER_PORT + 22))  --addpiece=false --precommit1=false --precommit2=false --commit=true > $ENV_LOG_PATH/worker-c2-1.log 2>&1 &
			fi
		fi
	fi
}

function init(){
    local MINER

	# nfs
	mount -t nfs 10.2.0.102:/nfs /mnt -o nolock
	if [ "`cat /mnt/mount | grep $IP | wc -l`" == "1" ];then
		MINER=`cat /mnt/mount | grep $IP | awk '{print $2}'`
		cp /mnt/env/$MINER/.env /root/
	else
		echo "没有找到匹配的初始化信息"
		exit 0
	fi
	umount /mnt										
}

{% endblock %}