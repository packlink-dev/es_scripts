#!/bin/bash


SUFIX=$(date +%Y.%m.%d)
echo -e "\e[01;33mTODAY [${SUFIX}]\e[0m"

curl -s -XGET 192.168.5.9:9200/_cat/indices/*${SUFIX}*?h=dc,ss,i | sort -nr | tee /tmp/today.indices


for i in 1 2 3 4 5
do
	TIMESTAMP=$(date --date=@$(( $(date +%s ) - ( i * 84600 ) )) +%s)
	SUFIX=$(date --date=@${TIMESTAMP} +%Y.%m.%d)
	echo -e "\e[01;33m$(date --date=@${TIMESTAMP} +%A) [${SUFIX}]\e[0m"

	curl -s -XGET 192.168.5.9:9200/_cat/indices/*${SUFIX}*?h=dc,ss,i | sort -nr
done

# for I in $(awk '{print $3}' /tmp/today.indices)
# do
# 	curl -s -XGET 192.168.5.9:9200/${I} | jq .
# done
