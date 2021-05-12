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
{% endblock %}
