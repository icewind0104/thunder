{% extends 'src/base.sh' %}

{% block coin %}
# stop service
function stop() {
	echo "No stop functions"
}

# show processes
function show() {
	ps -ef | grep lotus | grep -v grep
}

# start service
function start() {
	if [ "$1" == "miner" ];then
		nohup /root/dark/latest/lotus-miner run >> /root/logs/miner.log 2>&1 &
	fi

	if [ "$1" == "lotus" ];then
		nohup /root/dark/latest/lotus daemon >> /root/logs/lotus.log 2>&1 &
	fi
}

# remove useless files
function clear() {
	echo "No clear functions"
}

# rewrite config file
function init() {
	echo "No init functions"
}

# setup system enviroment
function deploy() {
	echo "No deploy functions"
}

function __task_check(){
#	JOBS=`/root/dark/latest/lotus-miner sealing jobs | tail -n +2`

	IFS_OLD=$IFS
	IFS=$'\x0A'

	for each in `/root/dark/latest/lotus-miner sealing jobs | tail -n +2 | head -n 10`;do
		if [ "`echo $each | awk '{print NF}'`" == "7" ];then
			TASK=`echo $each| awk '{print $5}'`
			TIME=`echo $each| awk '{print $7}'`
			H=`echo $TIME | sed 's/\(.*\)h.*/\1/g'`
			M=`echo $TIME | sed 's/.*h\(.*\)m.*/\1/g'`

			if [ "$TASK" == "PC1" -a "$H" -gt "8" ];then
				echo $each
			fi
			
			if [ "$TASK" == "PC2" -a "$H" -gt "2" ];then
				echo $each
			fi

			if [ "$TASK" == "C2" -a "$H" -gt "1" ];then
				echo $each
			fi
		else
			echo $each
		fi
	done

	IFS=$IFS_OLD
}

function __summary() {
	local JOBS=`/root/dark/latest/lotus-miner sealing jobs`
	local HOSTS=`echo -e "$JOBS"|tail -n +2 | awk '{print $4}' | cut -d ':' -f 1 | sort -u`

	local SUM_PC1=0
	local SUM_PC1_AS=0
	local SUM_PC2=0
	local SUM_C2=0
	local SUM_GET=0
	local SUM_AP=0

	echo -e "HOST\t\tPC1\tPC2\tC2\tGET\tAP"
	for each in $HOSTS;do
		PC1=`echo -e "$JOBS" | grep $each | grep running| grep PC1 |wc -l`
		PC1_AS=`echo -e "$JOBS" | grep $each | grep assigned| grep PC1 |wc -l`
		PC2=`echo -e "$JOBS" | grep $each |grep running| grep PC2 |wc -l`
		C2=`echo -e "$JOBS" | grep $each |grep running|  grep ' C2' |wc -l`
		GET=`echo -e "$JOBS" | grep $each |grep running| grep GET |wc -l`
		AP=`echo -e "$JOBS" | grep $each |grep running| grep AP |wc -l`

		SUM_PC1=$(($SUM_PC1+$PC1))
		SUM_PC1_AS=$(($SUM_PC1_AS+$PC1_AS))
		SUM_PC2=$(($SUM_PC2+$PC2))
		SUM_C2=$(($SUM_C2+$C2))
		SUM_GET=$(($SUM_GET+$GET))
		SUM_AP=$(($SUM_AP+$AP))
		
		if [ ! "$PC1_AS" == "0" ];then
			echo -e "$each:\t$PC1($PC1_AS)\t$PC2\t$C2\t$GET\t$AP"
		else
			echo -e "$each:\t$PC1\t$PC2\t$C2\t$GET\t$AP"
		fi
	done
	echo -e "SUM\t\t$SUM_PC1($SUM_PC1_AS)\t$SUM_PC2\t$SUM_C2\t$SUM_GET\t$SUM_AP"
}

function exec() {
	case $1 in
		summary)
			__summary;;
		info)
			/root/dark/latest/lotus-miner info;;
		worker)
			/root/dark/latest/lotus-miner sealing workers;;
		remove)
			/root/dark/latest/lotus-miner sectors remove --really-do-it $2;;
		find)
			/root/dark/latest/lotus-miner storage find $2;;
		recover)
			/root/dark/latest/lotus-miner proving check --only-bad $2;;
		abort)
			/root/dark/latest/lotus-miner sealing abort $2;;
		deadline)
			/root/dark/latest/lotus-miner proving deadlines;;
		terminate)
			/root/dark/latest/lotus-miner sectors remove --really-do-it $2;
			sleep 5;
			/root/dark/latest/lotus-shed sectors terminate --really-do-it=true $2;
			;;
		check)
			__task_check;;
		*)
			/root/dark/latest/lotus-miner sealing jobs;;
	esac
}
{% endblock %}
