#!/bin/bash

source snapshots.conf
declare -a DATA_NODES
declare -a BIND_NODES

data_nodes(){
	DATA_NODES=( $(curl -s -XGET "http://${HOST}:9200/_cat/nodes?h=r,n" | awk '/^d/ {print $2}' | xargs -i echo -n {}" ") )
}

bind_nodes(){
        BIND_NODES=( $( curl -s -XGET 192.168.5.13:9200/_nodes | \
                jq -r '.nodes | .[] | .http | .publish_address' | \
                grep -v 127.0.0.1 | sed -r 's:inet\[\/(.*)\]:\1:' ) )
}

master_node(){
	curl -s -XGET "http://${HOST}:9200/_cat/nodes?h=m,h" | awk '/^\*/ {print $2}'
}

random_data_node(){
	echo ${DATA_NODES[$(( ( RANDOM % 5 ) ))]}
}

optimize(){
	[ -z "${DATA_NODES}" ] && data_nodes
	NODES=$( curl -s -XGET 192.168.5.13:9200/_nodes | \
		jq -r '.nodes | .[] | .http | .publish_address' | \
		grep -v 127.0.0.1 | sed -r 's:inet\[\/(.*)\]:\1:' )
	for NODE in ${NODES}
	do
		echo -en "\t\e[01;46m${NODE}\e[00m\t"
		curl -s -XPOST "http://${NODE}/_optimize"
		echo -e "\e[00m"
	done
}

open_index(){
        local INDEX=${1}
        NODES=$( curl -s -XGET 192.168.5.13:9200/_nodes | \
                jq -r '.nodes | .[] | .http | .publish_address' | \
                grep -v 127.0.0.1 | sed -r 's:inet\[\/(.*)\]:\1:' )
        for NODE in ${NODES}
        do
                echo -en "\t\e[01;46m${NODE}\e[00m\t"
                curl -s -XPOST "http://${NODE}/${INDEX}/_open"
                echo -e "\e[00m"
        done
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


delete_index(){
        local INDEX=${1}
        NODES=$( curl -s -XGET 192.168.5.13:9200/_nodes | \
                jq -r '.nodes | .[] | .http | .publish_address' | \
                grep -v 127.0.0.1 | sed -r 's:inet\[\/(.*)\]:\1:' )
        for NODE in ${NODES}
        do
                echo -en "\t\e[01;46m${NODE}\e[00m\t"
		# Get index state ( open/close .. ) and remove all spaces
		STATE=$(curl -s -XGET "http://${NODE}/_cat/indices/${INDEX}?h=s" | sed -e 's/ //g')
		if [[ "${STATE}" == "close" ]]
		then
			echo -en "\e[01;34mdeleting... \e[00m"
	        	curl -s -XDELETE "http://${NODE}/${INDEX}"
		else
			echo -en "\e[01;37m ${STATE}\t\e[01;41mIndex is Not Closed\e[00m"
		fi
                echo -e "\e[00m"
		# sleep $(( (RANDOM % 3) + 1 ))
        done
}

relocate(){
	[ -z "${DATA_NODES}" ] && data_nodes
	[ ! -d relocate ] && mkdir -v relocate

	while read INDEX SHARD
	do
 	
	    NODE=""
	    while [[ -z ${NODE} ]]
	    do
		NODE=${DATA_NODES[$(( ( RANDOM % 5 ) ))]}
	    done

	    echo -e "\e[01;33mReallocating in \e[01;35m$NODE \e[01;37m[\e[01;36m ${INDEX} \e[01;37m]\e[00m"
	    curl -s -o relocate/${INDEX}.${SHARD}.${NODE}.json -XPOST "http://${HOST}:9200/_cluster/reroute" -d '{
		 "commands" : [ {
		       "allocate" : {
			   "index" : "'${INDEX}'", 
			   "shard" : '${SHARD}', 
			   "node" : "'${NODE}'", 
			   "allow_primary" : true
		       }
		     }
		 ]
	     }'
	    sleep ${DELAY}
	    # echo -e "\e[00m"
	done < <( curl -s -XGET http://${HOST}:9200/_cat/shards | grep -i unassigned | awk '{print $1,$2}' | sort )
	# Note!
	#  bash redirections:
	#  <
	#  <<
	#  <<<
	#  <( )
}

ACTION=${1}

case ${ACTION} in
	ls|LS)
		PATTERN=${2}
		echo -e "\e[01;33mindices: \e[01;35m${ACTION}\e[00m"
		curl -s -XGET http://${HOST}:9200/_cat/indices?h=i,s,dc,ss
		# "\e[01;37m[\e[01;36m ${INDICES} \e[01;37m]\e[00m"
		;;
		
	delete|DELETE)
		ARGS=(${@})
		INDICES=${ARGS[@]:1}
		[[ -z "${INDICES}" ]] && echo -e "\e[01;41mMissing Index\e[00m" && exit 1
		echo -e "\e[01;33mindices: \e[01;35m${ACTION} \e[01;37m[\e[01;36m ${INDICES} \e[01;37m]\e[00m"
		if [ ! -z "${INDICES}" ]
		then
			for INDEX in ${INDICES[@]}
			do
				delete_index ${INDEX}
			done
		fi
		;;
	optimize|OPTIMIZE)
		echo -e "\e[01;33mindices: \e[01;35m${ACTION}\e[00m"
		optimize		
		;;
	open|OPEN)
		ARGS=(${@})
		INDICES=${ARGS[@]:1}
		[[ -z "${INDICES}" ]] && echo -e "\e[01;41mMissing Index\e[00m" && exit 1
		echo -e "\e[01;33mindices: \e[01;35m${ACTION} \e[01;37m[\e[01;36m ${INDICES} \e[01;37m]\e[00m"
		if [ ! -z "${INDICES}" ]
		then
			for INDEX in ${INDICES[@]}
			do
				open_index ${INDEX}
			done
		fi
		;;
		# INDEX=${2}
		# [[ -z ${INDEX} ]] && echo -e "\e[01;41mMissing Index\e[00m" && exit 1
		# echo -e "\e[01;33mindices: \e[01;35m${ACTION} \e[01;37m[\e[01;36m ${INDEX} \e[01;37m]\e[00m"
		# open_index ${INDEX}
		# ;;
	close|CLOSE)
		ARGS=(${@})
		INDICES=${ARGS[@]:1}
		[[ -z "${INDICES}" ]] && echo -e "\e[01;41mMissing Index\e[00m" && exit 1
		echo -e "\e[01;33mindices: \e[01;35m${ACTION} \e[01;37m[\e[01;36m ${INDICES} \e[01;37m]\e[00m"
		if [ ! -z "${INDICES}" ]
		then
			for INDEX in ${INDICES[@]}
			do
				close_index ${INDEX}
			done
		fi
		;;
		# INDEX=${2}
		# [[ -z ${INDEX} ]] && echo -e "\e[01;41mMissing Index\e[00m" && exit 1
		# echo -e "\e[01;33mindices: \e[01;35m${ACTION} \e[01;37m[\e[01;36m ${INDEX} \e[01;37m]\e[00m"
		# close_index ${INDEX}
		# ;;
	relocate|RELOCATE)
		echo -e "\e[01;33mindices: \e[01;35m${ACTION}\e[00m"
		relocate
		;;
	check)
		echo -e "\e[01;33mindices: \e[01;35m${ACTION}\e[00m"
		echo -e "\t\e[01;43mdata_nodes\e[00m"
		curl -s -XGET http://${HOST}:9200/_cat/nodes | sed '1d' | sort
		echo -e "\t\e[01;46mdata_nodes\e[00m"
		data_nodes
		echo ${DATA_NODES[@]}
		echo -e "\t\e[01;45mmaster_node\e[00m"
		master_node
		echo -e "\t\e[01;44mrandom_data_node\e[00m"
		random_data_node
		;;
	*)
		echo "in progressss...."
		;;
esac
		
