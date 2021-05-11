#!/bin/bash
set -e

export ENV_TITLE=yali
export ENV_REPO_IP=10.0.1.175
export ENV_LOG_PATH=/var/log/coin
export ENV_HOST_IP=`ip addr | grep inet | grep -E '10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/16' | awk '{print $2}' | cut -d '/' -f 1`



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


# show processes
function show() {
	ps -ef | grep 'lotusworker' | grep 'worker-repo' | grep -v grep
}

# stop service
function stop() {
	for each in `ps -ef | grep 'lotusworker' | grep 'worker-repo' | grep -v grep | awk '{print $2}'`;do
		kill $each
	done
}

# deploy
function deploy() {
    local MINER

	apt update
	apt install tree mesa-opencl-icd ocl-icd-opencl-dev gcc git bzr jq pkg-config curl clang build-essential hwloc libhwloc-dev -y && sudo apt upgrade -y

	# cpu
	apt-get install cpufrequtils -y
	CPU_P=`cat /proc/cpuinfo | grep processor | tail -n 1 | awk '{print $3}'`
	for each in `seq 0 $CPU_P`;do
		cpufreq-set -c $each -g performance
	done
	cpufreq-info | grep 'The governor'


	mount -t nfs $ENV_REPO_IP:/repo /mnt -o nolock
	[ ! -d "/var/tmp/filecoin-proof-parameters" ] && cp -r /mnt/filecoin-proof-parameters /var/tmp/
	[ ! -d "/root/dark" ] && cp -r /mnt/dark /root/
	[ ! -d "/root/yungo" ] && cp -r /mnt/yungo /root/
	cp /mnt/.bashrc /root/
	umount /mnt

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


function env() {
	# ssh
	sed 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' -i /etc/ssh/sshd_config
	sed 's/#StrictModes yes/StrictModes yes/g' -i /etc/ssh/sshd_config
	sed 's/#ClientAliveInterval 0/ClientAliveInterval 60/g' -i /etc/ssh/sshd_config
	sed 's/#ClientAliveCountMax 3/ClientAliveCountMax 3/g' -i /etc/ssh/sshd_config
	systemctl restart ssh

	# hostname
	HOSTNAME=$LOCATION-`echo $IP | cut -d '.' -f 3``echo $IP | cut -d '.' -f 4`
	hostnamectl set-hostname $HOSTNAME

	# nfs
	apt install nfs-common -y

	# ntp
	rm /etc/localtime
	ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
	apt install ntp -y

	# sync
	sync
}


# setup disk
function disk() {
	local NVME_COUNT=0
	local VOLUME
	local TYPE
	local UUIDI
	local PART
	local DEVICE
	local MOUNT_POINT	

	echo -n "" > /root/mount

	for DEVICE in `fdisk -l | grep Disk | grep /dev/ | awk '{print $2}' | cut -d ":" -f 1`;do
		VOLUME=$((`fdisk -s $DEVICE` / 1024 / 1024))

		if [ "`df | grep -E ' /$' | grep $DEVICE | wc -l`" == "1" ];then
			TYPE="OS"
		else
			if [[ "$DEVICE" =~ "nvme" ]];then
				TYPE="nvme"
				NVME_COUNT=$(($NVME_COUNT + 1))
			elif [ "$VOLUME" -gt "102400" ];then
				TYPE="hdd"
			else
				if [ "$VOLUME" -gt "100" ];then
					TYPE="ssd"
				else
					TYPE="other"
				fi
			fi
		fi

		if [ "$TYPE" != "other" -a "$TYPE" != "OS" ];then
			if [ "$TYPE" == "nvme" ];then
				PART=${DEVICE}p1
				MOUNT_POINT=/nvme${NVME_COUNT}
			elif [ "$TYPE" == "ssd" ];then
				PART=${DEVICE}1
				MOUNT_POINT=/ssd
			elif [ "$TYPE" == "hdd" ];then
				PART=${DEVICE}1
				MOUNT_POINT=/hdd
			fi

			if [ -n "${MOUNT_POINT}" ];then
				umount -q -A ${PART} || echo -n ""

				sgdisk --zap-all ${DEVICE}
				parted ${DEVICE} mklabel gpt
				parted ${DEVICE} mkpart primary 0% 100%

				while [ ! -b "${PART}" ];do
					sleep 1
				done

				mkfs.xfs -f ${PART}
				UUID=`blkid ${PART} | awk '{print $2}' | cut -d "\"" -f 2`
				[ ! -d "$MOUNT_POINT" ] && mkdir $MOUNT_POINT

				while [ ! -h "/dev/disk/by-uuid/$UUID" ];do
					sleep 1
				done

				mount /dev/disk/by-uuid/$UUID $MOUNT_POINT
				echo "mount /dev/disk/by-uuid/$UUID $MOUNT_POINT" >> /root/mount
				echo ${NVME_COUNT} >> $MOUNT_POINT/mount
			fi

		fi
	done
}

# nfs
function nfs() {
	if [ "`df | grep '/hdd' | grep '/dev/' | wc -l`" == "1" ];then
		apt install nfs-kernel-server -y
		chmod 777 /hdd
		if [ "`grep '/hdd' /etc/exports | wc -l`" == "0" ];then
			echo "/hdd *(insecure,rw,async,no_root_squash)" >> /etc/exports
		fi
		/etc/init.d/nfs-kernel-server restart
	fi
}

case $1 in
	start)
		shift; start $@;;
	clear)
		clear;;
	stop)
		shift; stop;;
	init)
		init;;
	sync)
		sync;;
	disk)
		disk;;
	nfs)
		nfs;;
	deploy)
		deploy $REPO;;
	env)
		env;;
	*)
		show;;
esac
