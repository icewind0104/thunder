{% extends 'src/filecoin.sh' %}

{% block model %}
# start service
function start() {
	source /root/.env
	local IP=`__get_self_ip`

	if [ -z "$WORKER_PORT" ];then
		echo "Worker port number is not defined." >&2
		exit 1
	fi

	[ ! -d "$ENV_LOG_PATH" ] && mkdir $ENV_LOG_PATH

	APP=/root/dark/latest/lotus-worker
	COUNT=11

	# P1
	if [ "$1" == "p1" ];then
		if [ -z "$2" ];then
			# start all
			for each in `seq 1 $COUNT`;do
				taskset -c $(($each * 4 - 4)),$(($each * 4 - 3)),$(($each * 4 - 2)),$(($each * 4 - 1)) nohup $APP --worker-repo=/nvme`expr $((each + 2)) / 3`/.lotusworker$each run --listen=$IP:$(($WORKER_PORT + $each)) --addpiece=true --precommit1=true --precommit2=false --commit=false $((($each - 1) * 4)) $((($each - 1) * 4)) >> $ENV_LOG_PATH/worker$each.log 2>&1 &
				sleep 3
			done
		else
			# start special
			if [ "$2" -gt "0" -a "$2" -lt "$(($COUNT + 1))" ];then
				taskset -c $(($2 * 4 - 4)),$(($2 * 4 - 3)),$(($2 * 4 - 2)),$(($2 * 4 - 1)) nohup $APP --worker-repo=/nvme`expr $((each + 2)) / 3`/.lotusworker$2 run --listen=$IP:$(($WORKER_PORT + $2)) --addpiece=false --precommit1=true --precommit2=false --commit=false $((($2 - 1) * 4)) $((($each - 1) * 4)) >> $ENV_LOG_PATH/worker$2.log 2>&1 &
			else
				echo "invalid proc ID"
			fi
		fi
	fi

	# P2
	if [ "$1" == "p2" ];then
		if [ ! -d "/var/tmp-p2-1" ];then
			mkdir /var/tmp-p2-1
		fi

		if [ ! -d "/var/tmp-p2-2" ];then
			mkdir /var/tmp-p2-2
		fi

		#if [ ! -d "/var/tmp-p2-2" ];then
		#	mkdir /var/tmp-p2-2
		#fi

		APP_PATH=/root/dark/latest
		CORE1="48,49,50,51"
		CORE2="52,53,54,55"
		#CORE3="56,57,58,59"

		if [ -z "$2" ];then
			# start all
			taskset -c $CORE1 env env  TMPDIR=/var/tmp-p2-1 nohup $APP_PATH/lotus-worker --worker-repo=/nvme1/.lotusworker-p2-1  run --gpu=0 --listen=$IP:$(($WORKER_PORT + 17)) --addpiece=false --precommit1=false --precommit2=true --commit=false >> $ENV_LOG_PATH/worker-p2-1.log 2>&1 &
			sleep 3
			taskset -c $CORE2 env env  TMPDIR=/var/tmp-p2-2 nohup $APP_PATH/lotus-worker --worker-repo=/nvme2/.lotusworker-p2-2  run --gpu=1 --listen=$IP:$(($WORKER_PORT + 18)) --addpiece=false --precommit1=false --precommit2=true --commit=false >> $ENV_LOG_PATH/worker-p2-2.log 2>&1 &
			#sleep 3
			#taskset -c $CORE3 env env  TMPDIR=/var/tmp-p2-2 nohup $APP_PATH/lotus-worker --worker-repo=/nvme2/.lotusworker-p2-2  run --gpu=2 --listen=$IP:$(($WORKER_PORT + 19)) --addpiece=false --precommit1=false --precommit2=true --commit=false >> logs/worker-p2-2.log 2>&1 &
		else
			# start special
			if [ "$2" == "1" ];then
				taskset -c $CORE1 env env  TMPDIR=/var/tmp-p2-1 nohup $APP_PATH/lotus-worker --worker-repo=/nvme1/.lotusworker-p2-1  run --gpu=0 --listen=$IP:$(($WORKER_PORT + 17)) --addpiece=false --precommit1=false --precommit2=true --commit=false >> $ENV_LOG_PATH/worker-p2-1.log 2>&1 &
			fi
			if [ "$2" == "2" ];then
				taskset -c $CORE2 env env  TMPDIR=/var/tmp-p2-2 nohup $APP_PATH/lotus-worker --worker-repo=/nvme2/.lotusworker-p2-2  run --gpu=1 --listen=$IP:$(($WORKER_PORT + 18)) --addpiece=false --precommit1=false --precommit2=true --commit=false >> $ENV_LOG_PATH/worker-p2-2.log 2>&1 &
			fi
			#if [ "$2" == "2" ];then	
			#	taskset -c $CORE3 env env  TMPDIR=/var/tmp-p2-2 nohup $APP_PATH/lotus-worker --worker-repo=/nvme2/.lotusworker-p2-2  run --gpu=2 --listen=$IP:$(($WORKER_PORT + 19)) --addpiece=false --precommit1=false --precommit2=true --commit=false >> logs/worker-p2-2.log 2>&1 &
			#fi
		fi
	fi
}

function clear() {
    for n in `seq 1 4`;do
		for each in `ls -a /nvme${n}/ | grep -E '^.lotusworker[0-9]{1,2}$'`;do
			[ -d "/nvme${n}/$each/cache" ] && rm -rf /nvme${n}/$each/cache/s-t*
			[ -d "/nvme${n}/$each/sealed" ] && rm -f /nvme${n}/$each/sealed/s-t*
			[ -d "/nvme${n}/$each/unsealed" ] && rm -f /nvme${n}/$each/unsealed/s-t*
		done
	done
}

function init(){
	local MINER
	local NFS
	local NFS_IP
	local WORKER_CEPH_PATH
	local IP=`__get_self_ip`

	__save_nfs_config

	# env
	mount -t nfs 10.2.0.102:/nfs /mnt -o nolock
	MINER=`cat /mnt/mount | grep $IP | awk '{print $2}'`
	cp /mnt/env/$MINER/.env /root/
	umount /mnt

	# umount nfs
	for each in `df -T | grep nfs4 | grep -E '/nfs/[0-9]{4}' | awk '{print $NF}'`;do
		umount $each
	done

	# mount nfs
	NFS_IP=`cat /etc/init.d/nfs.sh`
	NFS="`echo $NFS_IP | cut -d '.' -f 3``echo $NFS_IP | cut -d '.' -f 4`"
	__nfs_mount $NFS_IP:/hdd /nfs/$NFS

	if [ "$NFS" == "2121" ];then
		WORKER_CEPH_PATH="/nfs/$NFS/storage-f0135551"
	elif [ "$NFS" == "2171" ];then
		WORKER_CEPH_PATH="/nfs/$NFS/storage-f0135885"
	else
		WORKER_CEPH_PATH="/nfs/$NFS"
	fi

	if [ ! -d "$WORKER_CEPH_PATH/cache" ];then
		echo "error: \"$WORKER_CEPH_PATH/cache\", No such directory, Did you forget to mount the ceph partition?"
	fi

	 for each in `echo /nvme1/.lotusworker1 /nvme1/.lotusworker2 /nvme1/.lotusworker3 /nvme2/.lotusworker4 /nvme2/.lotusworker5 /nvme2/.lotusworker6 /nvme3/.lotusworker7 /nvme3/.lotusworker8 /nvme3/.lotusworker9 /nvme4/.lotusworker10 /nvme4/.lotusworker11 /nvme4/.lotusworker12`;do
		 if [ -f "$each/storage.json" ];then
cat > $each/storage.json <<eof
{
  "StoragePaths": [
    {
      "Path": "$each"
    },
    {
      "Path": "$WORKER_CEPH_PATH/"
    }
  ]
}
eof
		fi

	done

	for each in `echo /nvme1/.lotusworker-p2-1 /nvme2/.lotusworker-p2-2`;do
		if [ -f "$each/sectorstore.json" ];then
			sed 's/"CanSeal": true/"CanSeal": false/g' -i $each/sectorstore.json
		fi


cat > $each/storage.json <<eof
{
  "StoragePaths": [
    {
      "Path": "$each"
    },
    {
      "Path": "/nvme1/.lotusworker1"
    },
    {
      "Path": "/nvme1/.lotusworker2"
    },
    {
      "Path": "/nvme1/.lotusworker3"
    },
    {
      "Path": "/nvme2/.lotusworker4"
    },
    {
      "Path": "/nvme2/.lotusworker5"
    },
    {
      "Path": "/nvme2/.lotusworker6"
    },
    {
      "Path": "/nvme3/.lotusworker7"
    },
    {
      "Path": "/nvme3/.lotusworker8"
    },
    {
      "Path": "/nvme3/.lotusworker9"
    },
    {
      "Path": "/nvme4/.lotusworker10"
    },
    {
      "Path": "/nvme4/.lotusworker11"
    },
    {
      "Path": "$WORKER_CEPH_PATH/"
    }
  ]
}
eof
	done
}

{% endblock %}
