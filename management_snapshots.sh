#!/bin/bash

ACTION=${1}
REPO=${2}
DATE=${3}
REPODIR=/es_snapshots
INFODIR=/tmp


case $ACTION in
	packet)
		[[ $# < 3 ]] && echo "Wrong arguments" && $0 && exit 1
		logger -t "$(basename $0).packet" "start"
		su -l elasticsearch -s /bin/bash -c "cd ${REPODIR}; tar cz ${REPO} | split -b 4900MiB - ${REPO}_${DATE}.tgz."
		logger -t "$(basename $0).packet" "compressed ${REPO}"
		md5sum ${REPODIR}/${REPO}_${DATE}.tgz.* > ${INFODIR}/${REPO}_${DATE}.sum
		logger -t "$(basename $0).packet" "md5sum"
		/root/es_scripts/snapshots.sh get ${REPO} all > ${INFODIR}/${REPO}_${DATE}.info
		logger -t "$(basename $0).packet" "get ${REPO} info"
		logger -t "$(basename $0).packet" "finish"
		;;
	upload)
		[[ $# < 3 ]] && echo "Wrong arguments" && $0 && exit 1
		bash racky.sh upload logger ${REPO} ${INFODIR} ${REPO}_${DATE}.sum
		bash racky.sh upload logger ${REPO} ${INFODIR} ${REPO}_${DATE}.info
		for FILE in ${REPODIR}/${REPO}_${DATE}.tgz.*
		do
			FILE_NAME=$(basename ${FILE})
			echo ${FILE}
			bash racky.sh upload logger ${REPO} ${REPODIR} ${FILE_NAME}
		done
		;;
	remove)
		REPO=${2}
		DATES=( $(bash racky.sh list logger | grep ${REPO} | awk -F'/' '{print $2}' | sort | uniq | xargs echo) )
		if (( ${#DATES[@]} > 2 )) 
		then
			
			for OBJECT in $(bash racky.sh list logger | grep ${REPO}/${DATES[0]} )
			do 
				bash racky.sh remove logger ${OBJECT}
			done
		fi
		;;
	purge)
		[[ $# < 3 ]] && echo "Wrong arguments" && $0 && exit 1
		echo "PURGE FILESYSTEM"
		cd ${INFODIR}
		rm -f ${REPO}_${DATE}.* 
		su -l elasticsearch -s /bin/bash -c "cd ${REPODIR}; rm -rf ${REPO}_${DATE}.tgz.* ${REPO};mkdir ${REPO}"
		;;
	days)
		bash racky.sh list logger | awk -F'/' '{print $2}' | sort | uniq
		;;
	*)
		cat << __EOF__
$0 Usage:

$0 [packet|upload|remove|purge] <repo name> <date>

   Actions:
     packet: Create files to upload.
     upload: Upload files to rackspace.
     remove: Remove Rackspace containers.
     purge:  Remove snapshots from filesystem.

   Where:
     repo name: Repository name to compress and upload.
     date:      Normaly Today (date +%Y%m%d), it's used to create names and directories.

__EOF__
	;;
esac	
