#!/bin/bash

ACTION=${1}
REPO=${2}
DATE=${3}
REPODIR=/es_snapshots
INFODIR=/tmp

case $ACTION in
	packet)
		cd ${REPODIR}
		su -l elasticsearch -c "tar cz ${REPO} | split -b 4900MiB - ${REPO}_${DATE}.tgz."
		md5sum ${REPO}_${DATE}.tgz.* > ${INFODIR}/${REPO}_${DATE}.sum
		/root/es_scripts/snapshots.sh get ${REPO} all > ${INFODIR}/${REPO}_${DATE}.info
		;;
	upload)
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
		echo "PURGE FILESYSTEM"
		cd ${INFODIR}
		rm -f ${REPO}_${DATE}.* 
		cd ${REPODIR}
		rm -rf ${REPO}_${DATE}.tgz.* ${REPO}
		;;
esac	
