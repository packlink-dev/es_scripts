#!/bin/bash

ACTION=${1}
SNAPSHOT=${2}

source snapshots.conf

ls_snapshot_indexes(){
	local SNAPSHOT=${1}
	curl -s -XGET http://${HOST}:9200/_snapshot/${REPO}/${SNAPSHOT} | jq -r ' .snapshots | .[] | .indices | .[] ' | sort
}

ls_snapshots(){
	curl -s -XGET "http://${HOST}:9200/_snapshot/${REPO}/_all" | jq -r ' .snapshots | .[] | .snapshot' | sort
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

case ${ACTION} in
	status|STATUS)
		echo -e "\e[01;33msnapshot: \e[01;35m${ACTION}"
		[ ! -z ${SNAPSHOT} ] && \
			curl -s -XGET http://${HOST}:9200/_snapshot/${REPO}/${SNAPSHOT}/_status
		echo -e "\e[00m"
		;;
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
		for SNAPSHOT in $(curl -s -XGET "http://${HOST}:9200/_snapshot/${REPO}/_all" | jq -r ' .snapshots | .[] | .snapshot' | sort)
		do
			echo -e "\t\e[01;37m[\e[01;36m ${SNAPSHOT} \e[01;37m]\e[00m"
			[[ "${2}" == "all" ]] && \
			curl -s -XGET http://${HOST}:9200/_snapshot/${REPO}/${SNAPSHOT} | jq -r ' .snapshots | .[] | .indices | .[] ' | sort | xargs -i echo -en "\t\t\e[01;35m"{}"\e[00m\n"
		done
		echo -e "\e[00m"
		;;
	delete|DELETE)
		echo -e "\e[01;33msnapshot: \e[01;35m${ACTION} \e[01;37m[\e[01;36m ${SNAPSHOT} \e[01;37m]\e[00m"
		[ ! -z ${SNAPSHOT} ] && \
			curl -s -XDELETE "http://${HOST}:9200/_snapshot/${REPO}/${SNAPSHOT}"
		;;
	create|CREATE)
		ARGS=(${@})
		INDEX=${ARGS[@]:2}
		if [ ! -z "${INDEX}" ] && [ ! -z ${SNAPSHOT} ]
		then
			echo -e "\e[01;33msnapshot: \e[01;35m${ACTION} from ${INDEX} \e[01;37m[\e[01;36m ${SNAPSHOT} \e[01;37m]\e[00m"
			curl -s -XPUT "http://${HOST}:9200/_snapshot/${REPO}/${SNAPSHOT}?wait_for_completion=true" \
				-d '{"indices": "'${INDEX[@]// /,}'","ignore_unavailable": "true","include_global_state": false}' | jq .
		else
			echo "FAILLLLLLLLLLLLLLLLLL.. in ${ACTION}"
		fi
		;;
	restore|RESTORE)
		INDEX=${3}
		if [ ! -z ${SNAPSHOT} ]
		then
			if [ ! -z ${INDEX} ]
			then
				echo -e "\e[01;33msnapshot: \e[01;35m${ACTION} \e[01;37m[\e[01;36m ${SNAPSHOT} \e[01;37m]  \e[01;37m[\e[01;36m ${INDEX} \e[01;37m]\e[00m"
				curl -s -XPOST "http://${HOST}:9200/_snapshot/${REPO}/${SNAPSHOT}/_restore?wait_for_completion=true" \
					-d '{
							"indices": "'${INDEX}'",
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
				curl -s -XPOST "http://${HOST}:9200/_snapshot/${REPO}/${SNAPSHOT}/_restore?wait_for_completion=true" \
					-d '{
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
	*)
		echo "in progressss...."
		;;
esac
