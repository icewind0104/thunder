{% extends 'src/filecoin.sh' %}

{% block model %}
# start service
function start() {
	source /root/.env

	if [ -z "$WORKER_PORT" ];then
		echo "Worker port number is not defined." >&2
		exit 1
	fi
	
	[ ! -d "$ENV_LOG_PATH" ] && mkdir $ENV_LOG_PATH

	# P1
	if [ "$1" == "p1" ];then
		COUNT=7
		APP=/root/dark/latest/lotus-worker

		if [ -z "$2" ];then
			# start all
			for each in `seq 1 $COUNT`;do
				taskset -c $(($each * 4 - 4)),$(($each * 4 - 3)),$(($each * 4 - 2)),$(($each * 4 - 1)) nohup $APP --worker-repo=/data/.lotusworker$each run --listen=$IP:$(($WORKER_PORT + $each)) --addpiece=true --precommit1=true --unseal=true --precommit2=false --commit=false $((($each - 1) * 4)) > $ENV_LOG_PATH/worker$each.log 2>&1 &
				sleep 3
			done
		else
			# start special
			if [ "$2" -gt "0" -a "$2" -lt "$(($COUNT + 1))" ];then
				taskset -c $(($2 * 4 - 4)),$(($2 * 4 - 3)),$(($2 * 4 - 2)),$(($2 * 4 - 1)) nohup $APP --worker-repo=/data/.lotusworker$2 run --listen=$IP:$(($WORKER_PORT + $2)) --addpiece=true --precommit1=true --unseal=true --precommit2=false --commit=false $((($2 - 1) * 4)) > $ENV_LOG_PATH/worker$2.log 2>&1 &
			else
				echo "invalid proc ID" >&2
				exit 1
			fi
		fi
	fi

	# P2
	if [ "$1" == "p2" ];then
		if [ ! -d "/var/tmp-p2-0" ];then
			mkdir /var/tmp-p2-0
		fi

		if [ ! -d "/var/tmp-p2-1" ];then
			mkdir /var/tmp-p2-1
		fi

		APP_PATH=/root/dark/latest
		CORE1="28,29,30,31,32,33,34,35,36,37,38,39,40,41"
		CORE2="42,43,44,45,46,47,48,49,50,51,52,53,54,55"

		if [ -z "$2" ];then
			# start all
			taskset -c $CORE1 env env  TMPDIR=/var/tmp-p2-0 nohup $APP_PATH/lotus-worker --worker-repo=/data/.lotusworker-p2-0  run --gpu=0 --listen=$IP:$(($WORKER_PORT + 13)) --addpiece=false --precommit1=false --unseal=true --precommit2=true --commit=false >> $ENV_LOG_PATH/worker-p2-0.log 2>&1 &
			sleep 3
			taskset -c $CORE2 env env  TMPDIR=/var/tmp-p2-1 nohup $APP_PATH/lotus-worker --worker-repo=/data/.lotusworker-p2-1 run --gpu=1 --listen=$IP:$(($WORKER_PORT + 14)) --addpiece=false --precommit1=false --unseal=true --precommit2=true --commit=false >> $ENV_LOG_PATH/worker-p2-1.log 2>&1 &
		else
			# start special
			if [ "$2" == "0" ];then
				taskset -c $CORE1 env env  TMPDIR=/var/tmp-p2-0 nohup $APP_PATH/lotus-worker --worker-repo=/data/.lotusworker-p2-0  run --gpu=0 --listen=$IP:$(($WORKER_PORT + 13)) --addpiece=false --precommit1=false --unseal=true --precommit2=true --commit=false >> $ENV_LOG_PATH/worker-p2-0.log 2>&1 &
			fi
			sleep 3
			if [ "$2" == "1" ];then
				taskset -c $CORE2 env env  TMPDIR=/var/tmp-p2-1 nohup $APP_PATH/lotus-worker --worker-repo=/data/.lotusworker-p2-1  run --gpu=1 --listen=$IP:$(($WORKER_PORT + 14)) --addpiece=false --precommit1=false --unseal=true --precommit2=true --commit=false >> $ENV_LOG_PATH/worker-p2-1.log 2>&1 &
			fi	
		fi
	fi
}

function clear() {
	for each in `ls -a /data/ | grep -E '^.lotusworker[0-9]{1,2}$'`;do
		[ -d "/data/$each/cache" ] && rm -rf /data/$each/cache/s-t*
		[ -d "/data/$each/sealed" ] && rm -f /data/$each/sealed/s-t*
		[ -d "/data/$each/unsealed" ] && rm -f /data}/$each/unsealed/s-t*
	done
}

function init(){
	local MINER
    local NFS
    local NFS_IP
    local WORKER_CEPH_PATH

	__save_nfs_config

	# env
	mount -t nfs 10.2.0.102:/nfs /mnt -o nolock
	MINER=`cat /mnt/mount | grep $IP | awk '{print $2}'`
	cp /mnt/env/$MINER/.env /root/
	umount /mnt

	# mount nfs
	NFS_IP=`cat /etc/init.d/nfs.sh`
	NFS="`echo $NFS_IP | cut -d '.' -f 3``echo $NFS_IP | cut -d '.' -f 4`"
	__mount_nfs $NFS_IP:/data /nfs/$NFS

	if [ "$NFS" == "2121" ];then
		WORKER_CEPH_PATH="/nfs/$NFS/storage-f0135551"
	elif [ "$NFS" == "2171" ];then
		WORKER_CEPH_PATH="/nfs/$NFS/storage-f0135885"
	else
		WORKER_CEPH_PATH="/nfs/$NFS"
	fi

	#umount /cephfs || echo "info: already umount."
	#mount -t ceph $CEPH_MON_1:6789,$CEPH_MON_2:6789,$CEPH_MON_3:6789:/ /cephfs -o name=admin,secret=$CEPH_SECRET

	if [ ! -d "$WORKER_CEPH_PATH/cache" ];then
		echo "error: \"$WORKER_CEPH_PATH/cache\", No such directory, Did you forget to mount the ceph partition?"
		#exit
	fi

	for each in `ls -a /data/ | grep -E 'lotusworker[0-9]'`;do

		if [ -f "/data/$each/storage.json" ];then
cat > /data/$each/storage.json <<eof
{
  "StoragePaths": [
    {
      "Path": "/data/$each"
    },
    {
      "Path": "$WORKER_CEPH_PATH/"
    }
  ]
}
eof
		fi
	done

	for each in `ls -a /data/ | grep -E 'lotusworker-p2-[0-9]'`;do

		if [ -f "/data/$each/sectorstore.json" ];then
			sed 's/"CanSeal": true/"CanSeal": false/g' -i /data/$each/sectorstore.json
		fi

cat > /data/$each/storage.json <<eof
{
  "StoragePaths": [
    {
      "Path": "/data/$each"
    },
    {
      "Path": "/data/.lotusworker1"
    },
    {
      "Path": "/data/.lotusworker2"
    },
    {
      "Path": "/data/.lotusworker3"
    },
    {
      "Path": "/data/.lotusworker4"
    },
    {
      "Path": "/data/.lotusworker5"
    },
    {
      "Path": "/data/.lotusworker6"
    },
    {
      "Path": "/data/.lotusworker7"
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