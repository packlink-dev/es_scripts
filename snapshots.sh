#!/bin/bash

ACTION=${1}
REPONAME=${2}
SNAPSHOT=${3}

HOST=$(netstat -ltpn | grep 9200 | awk '{print $4}' | awk -F':' '{print $1}')
[ -z ${HOST} ] && HOST=localhost
APP=$(basename $0)
APP=${APP%.sh}

ls_snapshot_indexes(){
	local SNAPSHOT=${1}
	curl -s -XGET http://${HOST}:9200/_snapshot/${REPONAME}/${SNAPSHOT} | jq -r ' .snapshots | .[] | .indices | .[] ' | sort
}

ls_snapshots(){
	curl -s -XGET "http://${HOST}:9200/_snapshot/${REPONAME}/_all" | jq -r ' .snapshots | .[] | .snapshot' | sort
}

ls_repos() {
	curl -s -XGET "http://${HOST}:9200/_snapshot" | jq -r 'keys | .[]'
}

close_index(){
	local INDEX=${1}
        NODES=$( curl -s -XGET 192.168.5.13:9200/_nodes | \
                jq -r '.nodes | .[] | .http | .publish_address' | \
                grep -v 127.0.0.1 | sed -r 's:inet\[\/(.*)\]:\1:' )
        for NODE in ${NODES}
        do
                echo -en "\t\e[01;46m${NODE}\e[00m\t"
                curl -s -XPOST "http://${NODE}/${INDEX}/_close"
                echo -e "\e[00m"
        done
}

index_cat_info(){
	local INDEX=${1}
	STATUS=$( curl -s -o /dev/null -w "%{http_code}" -XGET "http://${HOST}:9200/_cat/indices/${INDEX}" )
	if [ ${STATUS} -eq "200" ]
	then
		curl -s -XGET "http://${HOST}:9200/_cat/indices/${INDEX}?h=s,h,dc,ss"
  else 
		echo "missing"
	fi
}

[ ! -d ${REPONAME} ] && mkdir -p ${REPONAME}

case ${ACTION} in
	ls)
		echo -e "\e[01;33msnapshot: \e[01;35m${ACTION}  \e[01;37m[\e[01;36m ${SNAPSHOT} \e[01;37m]\e[00m"
		[ ! -z ${SNAPSHOT} ] && \
			ls_snapshot_indexes ${SNAPSHOT}
		echo -e "\e[00m"
		;;
	compare)
		echo -e "\e[01;33msnapshot: \e[01;35m${ACTION}  \e[01;37m[\e[01;36m ${SNAPSHOT} \e[01;37m]\e[00m"
		if [ ! -z ${SNAPSHOT} ]
		then
			for INDEX in $(ls_snapshot_indexes ${SNAPSHOT})
			do
				echo -en "\t\e[01;37m[\e[01;36m ${INDEX} \e[01;37m] \e[01;35m"
				index_cat_info ${INDEX}
			done
		fi
		echo -e "\e[00m"
		;;
	get|GET)
		echo -e "\e[01;33msnapshot: \e[01;35m${ACTION}"
		for SNAPSHOT in $(ls_snapshots)
		do
			echo -e "\t\e[01;37m[\e[01;36m ${SNAPSHOT} \e[01;37m]\e[00m"
			[[ "${3}" == "all" ]] && \
			ls_snapshot_indexes ${SNAPSHOT} | xargs -i echo -en "\t\t\e[01;35m"{}"\e[00m\n"
		done
		echo -e "\e[00m"
		;;
	delete|DELETE)
		echo -e "\e[01;33msnapshot: \e[01;35m${ACTION} \e[01;37m[\e[01;36m ${SNAPSHOT} \e[01;37m]\e[00m"
		[ ! -z ${SNAPSHOT} ] && \
			curl -s -XDELETE "http://${HOST}:9200/_snapshot/${REPONAME}/${SNAPSHOT}"
		echo -e "\e[00m"
		;;
	get_states)
		if [ ! -z "${REPONAME}" ]
		then
			if [ -z "${SNAPSHOT}" ]	
			then
				curl -s -XGET "http://${HOST}:9200/_snapshot/${REPONAME}/_all" | jq " .[] | .[] | [ .snapshot, .state ]"
			else
				CURL_STATUS=$( curl -s -XGET -w %{http_code} -o ${REPONAME}/${SNAPSHOT}.json "http://${HOST}:9200/_snapshot/${REPONAME}/${SNAPSHOT}" ) 
				JQ_STATE=$( cat ${REPONAME}/${SNAPSHOT}.json | jq -r " .[] | .[] | .state " 2>> /dev/null )
			fi
		fi
		echo ${JQ_STATE}
		;;
	state|STATE)
		if [ ! -z "${REPONAME}" ]
		then
			[ ! -d ${REPONAME} ] && mkdir -p ${REPONAME}
			if [ -z "${SNAPSHOT}" ]	
			then
				curl -s -XGET "http://${HOST}:9200/_snapshot/${REPONAME}/_all" | jq -r " .[] | .[] | .state"
			else
				CURL_STATUS=$( curl -s -XGET -w %{http_code} -o ${REPONAME}/${SNAPSHOT}.json "http://${HOST}:9200/_snapshot/${REPONAME}/${SNAPSHOT}" ) 
				JQ_STATE=$( cat ${REPONAME}/${SNAPSHOT}.json | jq -r " .[] | .[] | .state " 2>> /dev/null )
			fi
		fi
		echo ${JQ_STATE}
		;;
	create|CREATE)
		ARGS=(${@})
		INDEX=${ARGS[@]:3}
		CURL_COMMAND=${REPONAME}/${APP}_${1}_command.curl
		CURL_PAYLOAD=${REPONAME}/${APP}_${1}_payload.json
		CURL_RESULT=${REPONAME}/${APP}_${1}_response.json

		if [ ! -z "${REPONAME}" ] && [ ! -z "${INDEX}" ] && [ ! -z ${SNAPSHOT} ]
		then
			[ ! -d "${REPONAME}" ] && mkdir ${REPONAME}
			echo '{"indices": "'${INDEX[@]// /,}'","ignore_unavailable": "true","include_global_state": false}' > ${CURL_PAYLOAD}
			echo "curl -s -XPUT -o /dev/null -w %{http_code} 'http://${HOST}:9200/_snapshot/${REPONAME}/${SNAPSHOT}?wait_for_completion=true'" > ${CURL_COMMAND}
			echo -en "\e[01;33msnapshot: \e[01;35m${ACTION} ${REPONAME}/${SNAPSHOT} \e[01;37m[\e[01;36m ${INDEX} \e[01;37m]\e[00m "
			curl -s -XPUT -o ${CURL_RESULT} "http://${HOST}:9200/_snapshot/${REPONAME}/${SNAPSHOT}?wait_for_completion=true" \
				-d '{"indices": "'${INDEX[@]// /,}'","ignore_unavailable": "true","include_global_state": false}'

			RETURN=$(cat ${CURL_RESULT} | jq -r .snapshot.state 2>> /dev/null)
			# RETURN:
			# 	empty: error in jq ${CURL_RESULT} isn't a file
			#	'null': ${CURL_RESULT} is a json but it's a error response from elasticsearch
			#	'SUSCCESS|FAILED|STARTED': snapshot status
			echo "${RETURN}"
			[ -z "${RETURN}" ] && exit 3
			[ "${RETURN}" == "null" ] && exit 4
		else
			echo "FAILLLLLLLLLLLLLLLLLL.. in ${ACTION}"
			exit 1
		fi
		;;
	restore|RESTORE)
		INDEX=${3}
		if [ ! -z ${SNAPSHOT} ]
		then
			if [ ! -z ${INDEX} ]
			then
				echo -e "\e[01;33msnapshot: \e[01;35m${ACTION} \e[01;37m[\e[01;36m ${SNAPSHOT} \e[01;37m]  \e[01;37m[\e[01;36m ${INDEX} \e[01;37m]\e[00m"
				curl -s -XPOST "http://${HOST}:9200/_snapshot/${REPONAME}/${SNAPSHOT}/_restore?wait_for_completion=true" \
					-d '{
							"indices": "'${INDEX}'",
							"include_aliases": false,
							"include_global_state": false,
							"index_settings": {
								"index.nummber_of_shards": 1,
								"index.number_of_replicas": 0
							},
							"ignore_index_settings": [
								"index.refresh_interval"
							]
						}' | jq .
			else
				echo -e "\e[01;33msnapshot: \e[01;35m${ACTION} \e[01;37m[\e[01;36m ${SNAPSHOT} \e[01;37m]\e[00m"
				curl -s -XPOST "http://${HOST}:9200/_snapshot/${REPONAME}/${SNAPSHOT}/_restore?wait_for_completion=true" \
					-d '{
							"include_aliases": false,
							"include_global_state": false,
							"index_settings": {
								"index.nummber_of_shards": 1,
								"index.number_of_replicas": 0
							},
							"ignore_index_settings": [
								"index.refresh_interval"
							]
						}' | jq .
			fi
		else
			echo "FAILLLLLLLLLLLLLLLLLL.. in ${ACTION}"
		fi
		;;
	close) # _snapshoted_indices)
		echo -e "\e[01;33msnapshot: \e[01;35m${ACTION}\e[00m"
		for SNAPSHOT in $(ls_snapshots)
		do
			echo -e "\t\e[01;37m[\e[01;36m ${SNAPSHOT} \e[01;37m]\e[00m"
			for INDEX in $(ls_snapshot_indexes ${SNAPSHOT})
			do
				echo -e "\t\t\e[01;37m[\e[01;34m ${INDEX} \e[01;37m]\e[00m"
				close_index ${INDEX}
			done
		done
		;;
	repos)
		echo -e "\e[01;33msnapshot: \e[01;35m${ACTION}"
		ls_repos | xargs -i echo -en "\t\e[01;35m"{}"\e[00m\n"
		;;
	*)
		echo "$0 <action> [<repo name>] [extras]"
		echo "   action: [status|ls|compare|get|delete|create|restore|close]"
		echo "$0 $1 in progressss...."
		;;
esac
