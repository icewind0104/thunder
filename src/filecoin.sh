{% extends 'src/base.sh' %}

{% block coin %}
{% block model %}{% endblock %}
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
}
{% endblock %}
