#!/bin/bash
set -e

{% include 'config' %}

{% block coin %}{% endblock %}

function env() {
	local IP=`__get_self_ip`

	# ssh
	sed 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' -i /etc/ssh/sshd_config
	sed 's/#StrictModes yes/StrictModes yes/g' -i /etc/ssh/sshd_config
	sed 's/#ClientAliveInterval 0/ClientAliveInterval 60/g' -i /etc/ssh/sshd_config
	sed 's/#ClientAliveCountMax 3/ClientAliveCountMax 3/g' -i /etc/ssh/sshd_config
	systemctl restart ssh

	# hostname
	HOSTNAME=$ENV_TITLE-`echo $IP | cut -d '.' -f 3``echo $IP | cut -d '.' -f 4`
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

	[ "$1" == "force" ] && local FORCE=true

	echo "#!/bin/bash" > /etc/init.d/mount.sh
	chmod +x /etc/init.d/mount.sh

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
				# force reset
				if [ "$FORCE" == "true" ];then
					umount -q -A ${PART} || echo -n ""
					sgdisk --zap-all ${DEVICE}
				fi

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
				echo "mount /dev/disk/by-uuid/$UUID $MOUNT_POINT" >> /etc/init.d/mount.sh
				echo ${NVME_COUNT} >> $MOUNT_POINT/mount
			fi

		fi
	done

	# mount at reboot
cat > /etc/systemd/system/mount.service <<eof
[Unit]
Description=Auto mount after reboot

[Service]
ExecStart=/etc/init.d/mount.sh

[Install]
WantedBy=multi-user.target
eof

	systemctl enable mount.service
}

function __nfs_mount() {
	local MOUNT_FS=$1
	local MOUNT_POINT=$2

	local OUTPUT=`df -T -B1T $MOUNT_POINT|tail -n 1`
	local FILESYSTEM=`echo $OUTPUT|awk '{print $1}'`
	local TYPE=`echo $OUTPUT|awk '{print $2}'`
	local MOUNTED=`echo $OUTPUT|awk '{print $7}'`
	
	if [ "$MOUNTED" == "$MOUNT_POINT" ];then
		if [ "$TYPE" == "nfs4" ];then
			if [ ! "$FILESYSTEM" == "$MOUNT_FS" ];then
				umount $MOUNTED
				mount -t nfs $MOUNT_FS $MOUNT_POINT -o nolock
			fi
		else
			echo "Another filesystem has already mounted on $MOUNT_POINT" >&2
			exit 1
		fi
	else
		mount -t nfs $MOUNT_FS $MOUNT_POINT -o nolock
	fi
	
	# volume checking
	local OUTPUT=`df -T -B1T /hdd|tail -n 1`
	local VOLUME=`echo $OUTPUT|awk '{print $3}'`
	
	if [ ! "$VOLUME" -gt "1" ];then
		echo "There is not enough space in $MOUNT_POINT" >&2
		exit 1
	fi
}

function __save_nfs_config() {
	local NFS_IP
	local IP=`__get_self_ip`

	mount -t nfs 10.2.0.102:/nfs /mnt -o nolock
	NFS_IP=`cat /mnt/mount | grep $IP | awk '{print $3}'`
	if [ ! "$NFS_IP" == "none" ];then
		echo "$NFS_IP" > /etc/init.d/nfs.sh
	else
		rm -f /etc/init.d/nfs.sh
	fi
	umount /mnt
}

function __get_self_ip () {
	local IP=`ip addr | grep -E '^    inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d '/' -f 1`
	
	if [[ "$IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]];then
		echo $IP
	else
		echo "Failed to get local IP address" >&2
		exit 1
	fi
}

case $1 in
	start)
		shift; start $@;;
	clear)
		clear;;
	stop)
		shift; stop $@;;
	init)
		init;;
	disk)
		disk $2;;
	deploy)
		deploy;;
	env)
		env;;
	health)
		health;;
	setup)
		if [ "$2" == "force" ];then
			env; disk force; deploy; init;;
		else
			env; disk; deploy; init;;
		fi
	exec)
		shift; exec $@;;
	*)
		show;;
esac
