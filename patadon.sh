#!/bin/bash

TODAY=$( date +%s )
# Today and Yesterday always in production
START=$(date --date=@$(( TODAY - ( 84600 * 4 )  )) +%s)

while read INDEX LIVE RETENTION ARCHIVING
do
	echo -e "\e[01;32m${INDEX} [ $(date --date=@${TODAY} +%Y.%m.%d) ]\e[00m"
	echo -e "\t\e[01;33mSTART: $(date --date=@${START} +%Y.%m.%d)\e[00m"

	LIVE_TIME=$(date --date=@$(( START - $(( LIVE  * 84600 )) )) +%s)
	echo -e "\t\e[01;33mPRODUCTION: ${LIVE} $(date --date=@${LIVE_TIME} +%Y.%m.%d)\e[00m"

	RETENTION_TIME=$(date --date=@$(( LIVE_TIME - ( RETENTION  * 84600 ) )) +%s)
	echo -e "\t\e[01;33mRETENTION:  ${RETENTION} $(date --date=@${RETENTION_TIME} +%Y.%m.%d)\e[00m"

	# Not Used
	ARCHIVING_TIME=$(date --date=@$(( LIVE_TIME - ( ARCHIVING  * 84600 ) )) +%s)
	echo -e "\t\e[01;33mARCHIVING:  ${ARCHIVING} $(date --date=@${ARCHIVING_TIME} +%Y.%m.%d)\e[00m"
	
	# snapshotting
	echo ./snapshots.sh create ${INDEX} ${INDEX}-$(date --date=@${TODAY} +%Y%m%d) ${INDEX}-*

	END=$(date --date="2016-01-01" +%s)
	STEP=84600
	URL="http://192.168.5.13:9200/_cat/indices"

	TIMESTAMP=${RETENTION_TIME}

	while (( $TIMESTAMP > $END ))
	do
		DATE=$(date --date=@$TIMESTAMP +%Y.%m.%d)
		STATUS=$(curl -s -XGET -o /dev/null -w %{http_code} "${URL}/${INDEX}-${DATE}")
		[[ "${STATUS}" == "200" ]] && \
			echo -e "\t\t\e[01;34m${INDEX}-${DATE}\e[00m" && \
			echo ./indices.sh delete ${INDEX}-${DATE}
		TIMESTAMP=$(( TIMESTAMP - STEP ))
	done

done < <( awk '{print $1,$2,$3,$4}' archiving.list )
