#!/bin/bash
STEP=84600
END=$(date --date="2016-01-01" +%s)
URL="http://192.168.5.13:9200/_cat/indices"
TODAY=$( date +%s )
YESTERDAY=$(date --date=@$(( TODAY - ( STEP * 1 )  )) +%s)
# Today and 3 more days always in production
START=$(date --date=@$(( TODAY - ( STEP * 4 )  )) +%s)

generate_index_list() {
	local INDEX_PREFIX=${1}
	local START_DATE=${2}
	local END_DATE=${3}
	
	while (( $START_DATE > $END_DATE ))
	do
		INDEX_NAME=${INDEX_PREFIX}-$(date --date=@${START_DATE} +%Y.%m.%d)
		START_DATE=$(( START_DATE - STEP ))
		echo -en "${INDEX_NAME} "
	done
}

checked_index_list() {
	local INDEX_PREFIX=${1}
	local START_DATE=${2}
	local END_DATE=${3}

	local GENERATE_INDEX_LIST=( $(generate_index_list ${INDEX_PREFIX} ${START_DATE} ${END_DATE}) )

	for INDEX_NAME in ${GENERATE_INDEX_LIST[@]}
	do
		STATUS=$( curl -s -XGET -o /dev/null -w %{http_code} "${URL}/${INDEX_NAME}" )
		(( $STATUS == 200 )) && echo -en "${INDEX_NAME} "
	done
}

case $1 in
	execute)
		while read INDEX LIVE RETENTION ARCHIVING
		do
			echo -e "\e[01;32m${INDEX} [ $(date --date=@${TODAY} +%Y.%m.%d) ]\e[00m"
			echo -e "\t\e[01;33mSTART: $(date --date=@${START} +%Y.%m.%d)\e[00m"

			LIVE_TIME=$(date --date=@$(( START - $(( LIVE  * 84600 )) )) +%s)
			echo -e "\t\e[01;33mPRODUCTION: START - ${LIVE} $(date --date=@${LIVE_TIME} +%Y.%m.%d)\e[00m"

			RETENTION_TIME=$(date --date=@$(( LIVE_TIME - ( RETENTION  * 84600 ) )) +%s)
			echo -e "\t\e[01;33mRETENTION:  START - ${RETENTION} $(date --date=@${RETENTION_TIME} +%Y.%m.%d)\e[00m"

			# Not Used
			ARCHIVING_TIME=$(date --date=@$(( LIVE_TIME - ( ARCHIVING  * 84600 ) )) +%s)
			echo -e "\t\e[01;33mARCHIVING:  START - ${ARCHIVING} $(date --date=@${ARCHIVING_TIME} +%Y.%m.%d)\e[00m"
			
			# snapshotting
			if (( ${ARCHIVING} > 0 ))
			then
				INDEX_LIST=( $(checked_index_list ${INDEX} ${YESTERDAY} ${ARCHIVING_TIME}) )
				LEN=$(( ${#INDEX_LIST[@]} - 1 ))
				echo -e "\t\e[01;34mTO ARCHIVE: ${#INDEX_LIST[@]} indices\e[00m"
				(( ${#INDEX_LIST[@]} > 0 )) && \
					echo -e "\t\e[01;34mFROM( ${INDEX_LIST[0]} ) TO( ${INDEX_LIST[${LEN}]} ) indices\e[00m" && \
					/root/es_scripts/snapshots.sh create ${INDEX} ${INDEX}-$(date --date=@${TODAY} +%Y%m%d) ${INDEX_LIST[@]}
			else
				echo -e "\t\e[01;35mNOTHING TO ARCHIVE\e[00m"
			fi

			# deleting
			INDEX_LIST=( $(checked_index_list ${INDEX} ${RETENTION_TIME} ${END} ) )
			LEN=$(( ${#INDEX_LIST[@]} - 1 ))
			echo -e "\t\e[01;34mTO DELETE:  ${#INDEX_LIST[@]} indices\e[00m"
			(( ${#INDEX_LIST[@]} > 0 )) && \
				echo -e "\t\e[01;34mFROM( ${INDEX_LIST[0]} ) TO( ${INDEX_LIST[$L]} ) indices\e[00m" && \
				/root/es_scripts/indices.sh delete ${INDEX_LIST[@]}

			# packet ${INDEX} $(date --date=@${TODAY} +%Y%m%d)
			# upload ${INDEX} $(date --date=@${TODAY} +%Y%m%d)
			# remove date - 3 in racky
			# purge file system ( /es_snapshots ). if is sunday ?

		done < <( awk '{print $1,$2,$3,$4}' archiving.list )
	;;
	dry)
		while read INDEX LIVE RETENTION ARCHIVING
		do
			echo -e "\e[01;32m${INDEX} [ $(date --date=@${TODAY} +%Y.%m.%d) ]\e[00m"
			echo -e "\t\e[01;33mSTART: $(date --date=@${START} +%Y.%m.%d)\e[00m"

			LIVE_TIME=$(date --date=@$(( START - $(( LIVE  * 84600 )) )) +%s)
			echo -e "\t\e[01;33mPRODUCTION: START - ${LIVE} $(date --date=@${LIVE_TIME} +%Y.%m.%d)\e[00m"

			RETENTION_TIME=$(date --date=@$(( LIVE_TIME - ( RETENTION  * 84600 ) )) +%s)
			echo -e "\t\e[01;33mRETENTION:  START - ${RETENTION} $(date --date=@${RETENTION_TIME} +%Y.%m.%d)\e[00m"

			# Not Used
			ARCHIVING_TIME=$(date --date=@$(( LIVE_TIME - ( ARCHIVING  * 84600 ) )) +%s)
			echo -e "\t\e[01;33mARCHIVING:  START - ${ARCHIVING} $(date --date=@${ARCHIVING_TIME} +%Y.%m.%d)\e[00m"
			
			# snapshotting
			if (( ${ARCHIVING} > 0 ))
			then
				INDEX_LIST=( $(checked_index_list ${INDEX} ${YESTERDAY} ${ARCHIVING_TIME}) )
				LEN=$(( ${#INDEX_LIST[@]} - 1 ))
				echo -e "\t\e[01;34mTO ARCHIVE: ${#INDEX_LIST[@]} indices\e[00m"
				(( ${#INDEX_LIST[@]} > 0 )) && \
					echo -e "\t\e[01;34mFROM( ${INDEX_LIST[0]} ) TO( ${INDEX_LIST[${LEN}]} ) indices\e[00m" && \
					echo ${INDEX_LIST[@]}
			else
				echo -e "\t\e[01;35mNOTHING TO ARCHIVE\e[00m"
			fi

			# deleting
			INDEX_LIST=( $(checked_index_list ${INDEX} ${RETENTION_TIME} ${END} ) )
			LEN=$(( ${#INDEX_LIST[@]} - 1 ))
			echo -e "\t\e[01;34mTO DELETE:  ${#INDEX_LIST[@]} indices\e[00m"
			(( ${#INDEX_LIST[@]} > 0 )) && \
				echo -e "\t\e[01;34mFROM( ${INDEX_LIST[0]} ) TO( ${INDEX_LIST[$L]} ) indices\e[00m" && \
				echo ${INDEX_LIST[@]}

		done < <( awk '{print $1,$2,$3,$4}' archiving.list )
	;;
	purge)
		while read INDEX LIVE RETENTION ARCHIVING
		do
			echo -e "\e[01;32m${INDEX} [ $(date --date=@${TODAY} +%Y.%m.%d) ]\e[00m"
			echo -e "\t\e[01;33mSTART: $(date --date=@${START} +%Y.%m.%d)\e[00m"

			LIVE_TIME=$(date --date=@$(( START - $(( LIVE  * 84600 )) )) +%s)
			echo -e "\t\e[01;33mPRODUCTION: START - ${LIVE} $(date --date=@${LIVE_TIME} +%Y.%m.%d)\e[00m"

			RETENTION_TIME=$(date --date=@$(( LIVE_TIME - ( RETENTION  * 84600 ) )) +%s)
			echo -e "\t\e[01;33mRETENTION:  START - ${RETENTION} $(date --date=@${RETENTION_TIME} +%Y.%m.%d)\e[00m"

			# Not Used
			ARCHIVING_TIME=$(date --date=@$(( LIVE_TIME - ( ARCHIVING  * 84600 ) )) +%s)
			echo -e "\t\e[01;33mARCHIVING:  START - ${ARCHIVING} $(date --date=@${ARCHIVING_TIME} +%Y.%m.%d)\e[00m"
			
			# snapshotting
			if (( ${ARCHIVING} > 0 ))
			then
				curl -s -XGET "http://192.168.5.13:9200/_snapshot/${INDEX}/_all" | jq . # grep --color $(date --date=@${ARCHIVING_TIME} +%Y.%m.%d)
			fi


		done < <( awk '{print $1,$2,$3,$4}' archiving.list )
	;;
	*)
		echo "$0 [execute|dry|purge]"
	;;
	upload)
		while read INDEX LIVE RETENTION ARCHIVING
		do
			if (( ${ARCHIVING} > 0 ))
			then
				mangement_snapshots.sh packet ${INDEX} $(date --date=@${TODAY} +%Y%m%d)
				mangement_snapshots.sh upload ${INDEX} $(date --date=@${TODAY} +%Y%m%d)
				# mangement_snapshots.sh remove date - 3 in racky
				# mangement_snapshots.sh purge # file system ( /es_snapshots ). if is sunday ?
			fi
		done < <( awk '{print $1,$2,$3,$4}' archiving.list )
	;;
esac
