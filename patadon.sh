#!/bin/bash
STEP=84600
END=$(date --date="2016-01-01" +%s)
URL="http://192.168.5.13:9200/_cat/indices"
TODAY=$( date +%s )
YESTERDAY=$(date --date=@$(( TODAY - ( STEP * 1 )  )) +%s)
# Today and 3 more days always in production
START=$(date --date=@$(( TODAY - ( STEP * 4 )  )) +%s)
LOG_FILE=/tmp/patadon.log

my_date(){
	local TIMESTAMP=${1}
	local FORMAT=${2:-%c} 
	date --date=@${TIMESTAMP} +${FORMAT}
}

slack(){
	local HOOK_URL="https://hooks.slack.com/services/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"
	local TEXT=${1}
	local ALERT=${2}
	local CHANNEL=${3:-sfrektest}
	local USERNAME=${4:-patadon}

	[ ! -z "${ALERT}" ] && ALERT="<!here> "

	TEXT="${ALERT}${TEXT}"

	curl -X POST \
		--data-urlencode "payload={
			\"channel\": \"#${CHANNEL}\", 
			\"username\": \"${USERNAME}\", 
			\"text\": \"${TEXT}\"}" \
		${HOOK_URL}
}

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

# [ date program started ] [ yesterday ] [ date counter start ] [ edge date to have a limit ]
echo "[ $(my_date $TODAY) ] [ $(my_date $YESTERDAY) ] [ $(my_date $START) ] [ $(my_date $END) ]" > ${LOG_FILE}

case $1 in
	execute)
		while read INDEX LIVE RETENTION ARCHIVING
		do
			slack "*$(basename $0)* *$1* \`${INDEX}\`"
			echo -e "${INDEX} [ $(date --date=@${TODAY} +%Y.%m.%d) ]" >> ${LOG_FILE}
			echo -e "\tSTART: $(date --date=@${START} +%Y.%m.%d)" >> ${LOG_FILE}

			LIVE_TIME=$(date --date=@$(( START - $(( LIVE  * 84600 )) )) +%s)
			echo -e "\tPRODUCTION: START - ${LIVE} $(date --date=@${LIVE_TIME} +%Y.%m.%d)" >> ${LOG_FILE}

			RETENTION_TIME=$(date --date=@$(( LIVE_TIME - ( RETENTION  * 84600 ) )) +%s)
			echo -e "\tRETENTION:  START - ${RETENTION} $(date --date=@${RETENTION_TIME} +%Y.%m.%d)" >> ${LOG_FILE}

			# Not Used
			ARCHIVING_TIME=$(date --date=@$(( LIVE_TIME - ( ARCHIVING  * 84600 ) )) +%s)
			echo -e "\tARCHIVING:  START - ${ARCHIVING} $(date --date=@${ARCHIVING_TIME} +%Y.%m.%d)" >> ${LOG_FILE}
			
			# snapshotting
			if (( ${ARCHIVING} > 0 ))
			then
				INDEX_LIST=( $(checked_index_list ${INDEX} ${YESTERDAY} ${ARCHIVING_TIME}) )
				LEN=$(( ${#INDEX_LIST[@]} - 1 ))
				slack "to _archive_ \`\`\`[ from: ${INDEX_LIST[0]} to: ${INDEX_LIST[$LEN]} ]\`\`\`"

				echo -e "\tTO ARCHIVE: ${#INDEX_LIST[@]} indices" >> ${LOG_FILE}
				(( ${#INDEX_LIST[@]} > 0 )) && \
					echo -e "\tFROM( ${INDEX_LIST[0]} ) TO( ${INDEX_LIST[${LEN}]} ) indices"  >> ${LOG_FILE} && \
					/root/es_scripts/snapshots.sh create ${INDEX} ${INDEX}-$(date --date=@${TODAY} +%Y%m%d) ${INDEX_LIST[@]}
			else
				slack "*archive no needed*"
				echo -e "\tNOTHING TO ARCHIVE" >> ${LOG_FILE}
			fi

			# deleting
			INDEX_LIST=( $(checked_index_list ${INDEX} ${RETENTION_TIME} ${END} ) )
			LEN=$(( ${#INDEX_LIST[@]} - 1 ))
			slack "to _delete_ \`\`\`[ from: ${INDEX_LIST[0]} to: ${INDEX_LIST[$LEN]} ]\`\`\`"

			echo -e "\tTO DELETE:  ${#INDEX_LIST[@]} indices" >> ${LOG_FILE}
			(( ${#INDEX_LIST[@]} > 0 )) && \
				echo -e "\tFROM( ${INDEX_LIST[0]} ) TO( ${INDEX_LIST[$LEN]} ) indices" >> ${LOG_FILE} && \
				/root/es_scripts/indices.sh delete ${INDEX_LIST[@]}

			# packet ${INDEX} $(date --date=@${TODAY} +%Y%m%d)
			# upload ${INDEX} $(date --date=@${TODAY} +%Y%m%d)
			# remove date - 3 in racky
			# purge file system ( /es_snapshots ). if is sunday ?

		done < <( awk '{print $1,$2,$3,$4}' archiving.list )

		slack "*$(basename $0)* $1 done" alert operations
	;;
	dry)
		while read INDEX LIVE RETENTION ARCHIVING
		do
			slack "*$(basename $0)* *$1* \`${INDEX}\`"
			echo -e "${INDEX} [ $(date --date=@${TODAY} +%Y.%m.%d) ]"
			echo -e "\tSTART: $(date --date=@${START} +%Y.%m.%d)"

			LIVE_TIME=$(date --date=@$(( START - $(( LIVE  * 84600 )) )) +%s)
			echo -e "\tPRODUCTION: START - ${LIVE} $(date --date=@${LIVE_TIME} +%Y.%m.%d)"

			RETENTION_TIME=$(date --date=@$(( LIVE_TIME - ( RETENTION  * 84600 ) )) +%s)
			echo -e "\tRETENTION:  START - ${RETENTION} $(date --date=@${RETENTION_TIME} +%Y.%m.%d)"

			# Not Used
			ARCHIVING_TIME=$(date --date=@$(( LIVE_TIME - ( ARCHIVING  * 84600 ) )) +%s)
			echo -e "\tARCHIVING:  START - ${ARCHIVING} $(date --date=@${ARCHIVING_TIME} +%Y.%m.%d)"
			
			# snapshotting
			if (( ${ARCHIVING} > 0 ))
			then
				INDEX_LIST=( $(checked_index_list ${INDEX} ${YESTERDAY} ${ARCHIVING_TIME}) )
				LEN=$(( ${#INDEX_LIST[@]} - 1 ))
				slack "to _archive_ \`\`\`[ from: ${INDEX_LIST[0]} to: ${INDEX_LIST[$LEN]} ]\`\`\`"

				echo -e "\tTO ARCHIVE: ${#INDEX_LIST[@]} indices"
				(( ${#INDEX_LIST[@]} > 0 )) && \
					echo -e "\tFROM( ${INDEX_LIST[0]} ) TO( ${INDEX_LIST[${LEN}]} ) indices" && \
					echo ${INDEX_LIST[@]}
			else
				slack "*archive no needed*"
				echo -e "\tNOTHING TO ARCHIVE"
			fi

			# deleting
			INDEX_LIST=( $(checked_index_list ${INDEX} ${RETENTION_TIME} ${END} ) )
			LEN=$(( ${#INDEX_LIST[@]} - 1 ))
			slack "to _delete_ \`\`\`[ from: ${INDEX_LIST[0]} to: ${INDEX_LIST[$LEN]} ]\`\`\`"

			echo -e "\tTO DELETE:  ${#INDEX_LIST[@]} indices"
			(( ${#INDEX_LIST[@]} > 0 )) && \
				echo -e "\tFROM( ${INDEX_LIST[0]} ) TO( ${INDEX_LIST[$L]} ) indices" && \
				echo ${INDEX_LIST[@]}

		done < <( awk '{print $1,$2,$3,$4}' archiving.list )
		
		slack "*$(basename $0)* $1 done" alert sfrektest escli
	;;
	manage)
		while read REPO LIVE RETENTION ARCHIVING
		do
			if (( ${ARCHIVING} > 0 ))
			then

			        echo "$REPO [ packet ]"
			        ./management_snapshots.sh packet $REPO 20170209
				echo "$REPO [ upload ]"
			        ./management_snapshots.sh upload $REPO 20170209
			        echo "$REPO [ purge ]"
			        ./management_snapshots.sh purge $REPO 20170209
				# mangement_snapshots.sh remove date - 3 in racky
				# mangement_snapshots.sh purge # file system ( /es_snapshots ). if is sunday ?
			fi
		done < <( awk '{print $1,$2,$3,$4}' archiving.list )
	;;
	restore)
		# restore with snapshost.sh 
		while read INDEX LIVE RETENTION ARCHIVING
		do
			echo -e "${INDEX} [ $(date --date=@${TODAY} +%Y.%m.%d) ]"
			echo -e "\tSTART: $(date --date=@${START} +%Y.%m.%d)"

			LIVE_TIME=$(date --date=@$(( START - $(( LIVE  * 84600 )) )) +%s)
			echo -e "\tPRODUCTION: START - ${LIVE} $(date --date=@${LIVE_TIME} +%Y.%m.%d)"

			RETENTION_TIME=$(date --date=@$(( LIVE_TIME - ( RETENTION  * 84600 ) )) +%s)
			echo -e "\tRETENTION:  START - ${RETENTION} $(date --date=@${RETENTION_TIME} +%Y.%m.%d)"

			# Not Used
			# ARCHIVING_TIME=$(date --date=@$(( LIVE_TIME - ( ARCHIVING  * 84600 ) )) +%s)
			# echo -e "\tARCHIVING:  START - ${ARCHIVING} $(date --date=@${ARCHIVING_TIME} +%Y.%m.%d)"
			
			# snapshotting
			if (( ${RETENTION} > 0 ))
			then
				curl -s -XGET "http://192.168.5.13:9200/_snapshot/${INDEX}/_all" | jq . # grep --color $(date --date=@${ARCHIVING_TIME} +%Y.%m.%d)
			fi


		done < <( awk '{print $1,$2,$3,$4}' archiving.list )
	;;
	*)
		echo "$(basename $0) [execute|dry|purge]"
	;;
esac

# [ date program finished ] [ yesterday ] [ date counter start ] [ edge date to have a limit ]
echo "[ $(date) ] [ $(my_date $YESTERDAY) ] [ $(my_date $START) ] [ $(my_date $END) ]" > ${LOG_FILE}
