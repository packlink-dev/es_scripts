#!/bin/bash

# START=$(date --date=@$(( $(date +%s) - 84600  )) +%s)
START=$(date +%s)

while read INDEX LIVE RETENTION ARCHIVING
do
	echo -e "\e[01;32m${INDEX}\e[00m"

	LIVE_TIME=$(date --date=@$(( START - $(( LIVE  * 84600 )) )) +%s)
	echo -e "\t\e[01;33m${LIVE} $(date --date=@${LIVE_TIME} +%Y.%m.%d)\e[00m"

	RETENTION_TIME=$(date --date=@$(( LIVE_TIME - ( RETENTION  * 84600 ) )) +%s)
	echo -e "\t\e[01;33m${RETENTION} $(date --date=@${RETENTION_TIME} +%Y.%m.%d)\e[00m"

	ARCHIVING_TIME=$(date --date=@$(( LIVE_TIME - ( ARCHIVING  * 84600 ) )) +%s)
	echo -e "\t\e[01;33m${ARCHIVING} $(date --date=@${ARCHIVING_TIME} +%Y.%m.%d)\e[00m"

	
	END=$(date --date="2016-10-01" +%s)
	STEP=84600
	URL="http://192.168.5.13:9200/_cat/indices"

	TIMESTAMP=${ARCHIVING_TIME}

		while (( $TIMESTAMP > $END ))
		do
			DATE=$(date --date=@$TIMESTAMP +%Y.%m.%d)
			STATUS=$(curl -s -XGET -o /dev/null -w %{http_code} "${URL}/${INDEX}-${DATE}")
			[[ "${STATUS}" == "200" ]] && \
				echo -e "\t\t\e[01;34m${INDEX}-${DATE}\e[00m" && \
				./indices.sh delete ${INDEX}-${DATE}
			TIMESTAMP=$(( TIMESTAMP - STEP ))
		done

done < <( awk '{print $1,$2,$3,$4}' archiving.list )
