#!/bin/bash

function USAGE
{
	echo "Usage: synchro.sh {start|stop} source-path" >&2
}

if [ "$#" -ne "2" ]; then
    USAGE
    exit 1
fi

SPOOL_BASE="/var/spool/synchro-seedbox-ng"
SOURCE_PATH=$2
SYNC_ID=`echo -n $2 | md5sum | cut -d' ' -f 1`
SYNC_SPOOL_SOURCE_PATH="$SPOOL_BASE/$SYNC_ID"
SYNC_FILELIST="$SYNC_SPOOL_SOURCE_PATH/file_list.log"
SYNC_LOG="$SYNC_SPOOL_SOURCE_PATH/sending.log"
LOCK_FILE="$SYNC_SPOOL_SOURCE_PATH/lock"

function browse_dir
{
local dir
local rel
local age
local i

if test $# -lt 1
then
dir=$SOURCE_PATH
rel=""
else
rel="$1/"
dir="$SOURCE_PATH$rel"
fi

echo "scanning $dir"

for i in "$dir"*
do
	if test -f "$i"
	then

		age=`stat -c %Y "$i"`
		echo "$age:${i//"$SOURCE_PATH/"/}" >> $SYNC_FILELIST
	else
	if test -d "$i"
	then
		browse_dir "${i//"$SOURCE_PATH"/}"
	fi
	fi
done

#Delete empty folder
rmdir "$dir/"* 2> /dev/null 
}

function update_list
{
	rm $SYNC_FILELIST 2> /dev/null
	browse_dir
}

function send_files
{
patern='*[0-9]:'
patern2='/*'

old_IFS=$IFS
IFS=$'\n'
for line in $(sort $SYNC_FILELIST)
do
	IFS=$old_IFS
	line1=${line##$patern}
#	echo $line1
	fic=${line1##"$SOURCE_PATH"}
#	echo $fic
	rel="${fic%$patern2}/"
#	echo $rel
	send_file_job "$line1"
	update_list
done
IFS=$old_IFS
}

function send_file_job
{
	echo "sending $1"
	echo "$SOURCE_PATH/$1" > $SYNC_LOG

	rsync -aPRL -p --chmod=ug+rwx --partial-dir=.tmp --temp-dir=.tmp --rsh=ssh --remove-sent-files --bwlimit=$bwlimit "$1" "$user_SSH"@"$IP":"$SYNC_DEST" >> $SYNC_LOG
}

. ./config/user.cfg

case "$1" in
	start)

		if test -f $LOCK_FILE
		then
			echo -e "Synchro for $2 already running"
			exit 3
		else
			if [ ! -d "$SYNC_SPOOL_SOURCE_PATH" ]; then
				mkdir $SYNC_SPOOL_SOURCE_PATH
			fi
			touch $LOCK_FILE
		fi

		update_list

		while test -f $SYNC_FILELIST
		do
			send_files
		done

		rm $LOCK_FILE
	;;
	stop)
		echo "not implemented yet"
	;;
	*)
		USAGE
        	exit 3
        ;;
esac
