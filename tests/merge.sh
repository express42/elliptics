#!/bin/bash

ioserv=../example/dnet_ioserv
log_mask=15
server_num=2

server_opt="-D"
daemon_start_string="$ioserv"
tmpdir="/tmp"
log=$tmpdir/log

function log()
{
	echo "$@" >> $log
}

function die()
{
	log $1 >&2
	if test x$2 = x; then
		log "No error status specified"
		exit -1
	else
		log "Error status $2"
		exit $2
	fi
}

function prepare_root()
{
	trap kill_servers EXIT
	tmpdir=`mktemp -d /tmp/elliptics-XXXXXX`
	#tmpdir=/tmp/elliptics-test
	#mkdir -p $tmpdir

	rm -rf $tmpdir/*

	for ((i=0; i<$server_num; ++i)); do
		mkdir -p $tmpdir/root$i
	done
	log=$tmpdir/log
}

function start_node()
{
	start_log=`$daemon_start_string $1`
	status=$?

	if test $status != 0; then
		die "Failed to start node, status: $status" $status
	fi

	base=`basename $ioserv`

	pid=`echo $start_log | grep "Daemon pid: " | awk -F ": " {'print $2'} | sed -e 's/\.//g'`
	pid_running=`ps ax | grep $pid | grep -c $base`

	if test $pid_running = 0; then
		die "No daemon is running, check the log" -17
	fi

	echo "$pid \"$1\"" >> $tmpdir/pids
}

function start_server()
{
	num=$2
	opt="-a $1 -d $tmpdir/root$num -j -l $tmpdir/log-server-$num -m $log_mask $3"

	log -en "Starting server: $daemon_start_string $opt ... "
	start_node "$opt"
	log "`tail -n1 $tmpdir/pids | awk {'print $1'}`"

	sleep 1
}

function kill_servers()
{
	if ! test -f $tmpdir/pids; then
		return
	fi

	for pid in `cat $tmpdir/pids | awk {'print $1'}`; do
		log "Killing $pid"
		kill $pid
	done

	rm -f $tmpdir/pids
}

function data_io()
{
	local addr=localhost:0:2

	local operation=$1
	local idx=$2
	local size=$3
	local offset=$4
	local serv=$5
	local test_file=$6

	local test_id=$7

	local opt="-W $test_file"

	if test $operation != "write"; then
		opt="-R $test_file"
		operation="read"
	fi

	if test x$test_id != x; then
		opt="$opt -I $test_id"
	fi

	#log "Starting client: $ioserv -a $addr -r $serv -l $tmpdir/log-client-$operation-$idx -m $log_mask -T sha1 -S $size -O $offset $opt ... "
	$ioserv -a $addr -r $serv -l $tmpdir/log-client-$operation-$idx -m $log_mask -T sha1 -S $size -O $offset $opt > /dev/null
	local status=$?

	if test $status != 0; then
		cat $tmpdir/log-client-$operation-$idx
		die "Failed to $operation file $test_file, offset: $offset, size: $size, status: $status" $status
	fi

	#log "done"
}

function read_data()
{
	data_io "read" $@
}

function write_data()
{
	data_io "write" $@
}

function setup_base_server_data()
{
	local serv=$1
	local test_file=$2
	local size=$3
	local cnt=$4
	local test_file_id=$5

	dd if=/dev/urandom of=$test_file bs=$size count=$cnt >> $log 2>&1

	start_server $base_serv 0 "$server_opt"
	for ((j=0; j<$cnt; ++j)); do
		local offset=`expr $j \* $size`
		write_data $j $size $offset $serv $test_file $test_file_id
	done
}

function kill_server()
{
	local pid=`grep $1 $tmpdir/pids | awk {'print $1'}`

	if test x$pid = x; then
		return
	fi

	grep -v $1 $tmpdir/pids > $tmpdir/pids.tmp
	mv $tmpdir/pids.tmp $tmpdir/pids

	log "Killing $1 ($pid)"
	kill $pid
}

function read_and_check_data()
{
	local id=$1
	local size=$2
	local offset=$3
	local servers=$4
	local test_file_id=$5

	local file=$tmpdir/test_file_result

	for serv in $servers; do
		read_data 0 $size $offset $serv $file $test_file_id
		md5sum $file $file.history
		rm -f $file
	done
}

function prepare_servers()
{
	local test_file_id=$1
	local base_serv=$2
	local joining_serv=$3

	local cnt=3
	local size=4096
	local total_size=`expr $size \* $cnt`
	local test_file=$tmpdir/test_file

	setup_base_server_data $base_serv $test_file $size $cnt $test_file_id

	start_server $joining_serv 1 "$server_opt -r $base_serv -i ff"

	kill_server $joining_serv

	dd if=/dev/urandom of=$test_file.tmp bs=$size count=1 >> $log 2>&1
	local offset=1024
	write_data 0 `expr $size \- $offset` $offset $base_serv $test_file.tmp $test_file_id

	start_server $joining_serv 1 "$server_opt -i ff"
	offset=2048
	write_data 0 `expr $size \- $offset` $offset $joining_serv $test_file.tmp $test_file_id
	kill_server $joining_serv
}

base_serv=localhost:1025:2
joining_serv=localhost:1030:2
test_file_id=ff

echo -en "Checking merge strategy: "
for ((merge=0; merge<4; ++merge)); do
	prepare_root
	prepare_servers $test_file_id $base_serv $joining_serv

	start_server $joining_serv 1 "$server_opt -r $base_serv -i ff -M $merge"

	cmpstr=""
	for ((i=0; i<$server_num; ++i)); do
		cmpstr="$cmpstr $tmpdir/root$i/$test_file_id/$test_file_id*.history"
	done

	cmp $cmpstr
	if test $? != 0; then
		die "Merge strategy $merge failed: histoies differ"
	fi

	echo -en "$merge "
	kill_servers
done

echo "done"
#read_and_check_data 0 $total_size 0 "$base_serv" $test_file_id

kill_servers

trap - EXIT

rm -rf $tmpdir