#!/bin/bash

ACTION=${1}
REPO=${2}
DATE=${3}
REPODIR=/es_snapshots
INFODIR=/tmp

case $ACTION in
	packet)
		[[ $# < 3 ]] && echo "Wrong arguments" && $0 && exit 1
		su -l elasticsearch -c "cd ${REPODIR}; tar cz ${REPO} | split -b 4900MiB - ${REPO}_${DATE}.tgz."
		md5sum ${REPODIR}/${REPO}_${DATE}.tgz.* > ${INFODIR}/${REPO}_${DATE}.sum
		/root/es_scripts/snapshots.sh get ${REPO} all > ${INFODIR}/${REPO}_${DATE}.info
		;;
	upload)
		[[ $# < 3 ]] && echo "Wrong arguments" && $0 && exit 1
		bash racky.sh logger ${REPO} ${INFODIR} ${REPO}_${DATE}.sum
		bash racky.sh logger ${REPO} ${INFODIR} ${REPO}_${DATE}.sum
		for FILE in ${REPODIR}/${REPO}_${DATE}.tgz.*
		do
			FILE_NAME=$(basename ${FILE})
			echo ${FILE}
			bash racky.sh logger ${REPO} ${REPODIR} ${FILE_NAME}
		done
		;;
	remove)
		echo "RACKY REMOVE"
		;;
	purge)
		[[ $# < 3 ]] && echo "Wrong arguments" && $0 && exit 1
		echo "PURGE FILESYSTEM"
		cd ${INFODIR}
		rm -f ${REPO}_${DATE}.* 
		cd ${REPODIR}
		rm -rf ${REPO}_${DATE}.tgz.* ${REPO}
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
